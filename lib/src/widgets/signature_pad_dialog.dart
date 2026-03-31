import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../wacom/wacom_adapter.dart';

/// A modal dialog containing a finger/mouse/Wacom-drawable signature pad.
///
/// All content is centre-aligned. When a connected [WacomAdapter] is supplied
/// the tablet display is configured and pen strokes are captured from the
/// hardware device; falls back to finger/mouse otherwise.
///
/// Returns a [Uint8List] PNG of the drawn signature, or `null` if cancelled.
class SignaturePadDialog extends StatefulWidget {
  /// URL of the brand logo shown in the dialog header.
  final String? brandLogoUrl;

  /// Title shown in the dialog header.
  final String? signatureTitle;

  /// Wacom adapter (already connected singleton from [DefaultWacomAdapter]).
  final WacomAdapter? wacomAdapter;

  const SignaturePadDialog({
    super.key,
    this.brandLogoUrl,
    this.signatureTitle,
    this.wacomAdapter,
  });

  /// Shows the dialog and returns the PNG bytes, or `null` if cancelled.
  static Future<Uint8List?> show(
    BuildContext context, {
    String? brandLogoUrl,
    String? signatureTitle,
    WacomAdapter? wacomAdapter,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignaturePadDialog(
        brandLogoUrl: brandLogoUrl,
        signatureTitle: signatureTitle,
        wacomAdapter: wacomAdapter,
      ),
    );
  }

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

// ─────────────────────────────────────────────────────────────────────────────

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  static const double _canvasW = 440.0;
  static const double _canvasH = 220.0;

  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _penColor = const Color(0xFF1E293B);

  StreamSubscription<Map<String, dynamic>>? _penSub;
  bool _wacomScreenActive = false;
  bool _isClosing = false;

  bool get _hasInk => _strokes.isNotEmpty || _currentStroke.isNotEmpty;

  String get _resolvedTitle =>
      widget.signatureTitle?.trim().isNotEmpty == true
          ? widget.signatureTitle!
          : 'Draw your signature';

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _initWacom();
  }

  @override
  void dispose() {
    _penSub?.cancel();
    _resetWacomScreen();
    super.dispose();
  }

  // ── Wacom ──────────────────────────────────────────────────────────────────

  Future<void> _initWacom() async {
    final a = widget.wacomAdapter;
    if (a == null || !a.isConnected || a.capabilities == null) return;

    await _drawWacomScreen(a);
    await Future.delayed(const Duration(milliseconds: 400));

    _penSub = a.penEvents.listen(
      (e) { if (mounted) _handlePen(e, a.capabilities!); },
    );
  }

  Future<void> _resetWacomScreen() async {
    if (!_wacomScreenActive) return;
    final a = widget.wacomAdapter;
    if (a == null || !a.isConnected) return;
    try { await a.clearScreen(); } catch (_) {}
    _wacomScreenActive = false;
  }

  Future<void> _drawWacomScreen(WacomAdapter a) async {
    final caps = a.capabilities!;
    final int w = (caps['screenWidth']  as double).toInt();
    final int h = (caps['screenHeight'] as double).toInt();

    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    // Background
    c.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()..color = const Color(0xFFF8FAFC));

    // Title — centred
    _drawText(c, _resolvedTitle,
        const TextStyle(color: Color(0xFF0F172A), fontSize: 26,
            fontWeight: FontWeight.w700),
        Offset(w / 2, h * 0.10), center: true);

    // Sign box
    final box = Rect.fromLTWH(w * 0.06, h * 0.18, w * 0.88, h * 0.44);
    c.drawRect(box, Paint()..color = Colors.white);
    c.drawRect(box, Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5);
    _drawText(c, 'Please sign in the box',
        const TextStyle(color: Color(0xFF94A3B8), fontSize: 18),
        box.center, center: true);

    // Buttons (bottom 20%)
    final bH = h * 0.2, bY = h - bH, bW = w / 3.0;
    _drawBtn(c, 'Clear',  Rect.fromLTWH(0,      bY, bW, bH),
        const Color(0xFFE2E8F0), const Color(0xFF0F172A));
    _drawBtn(c, 'Cancel', Rect.fromLTWH(bW,     bY, bW, bH),
        const Color(0xFFF1F5F9), const Color(0xFF0F172A));
    _drawBtn(c, 'Apply',  Rect.fromLTWH(bW * 2, bY, bW, bH),
        const Color(0xFF059669), Colors.white);

    // Convert RGBA → BGR and push to device
    final img = await rec.endRecording().toImage(w, h);
    final bd  = await img.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (bd == null) return;
    final rgba = bd.buffer.asUint8List();
    final rgb  = Uint8List(w * h * 3);
    for (int i = 0; i < w * h; i++) {
      rgb[i * 3]     = rgba[i * 4 + 2];
      rgb[i * 3 + 1] = rgba[i * 4 + 1];
      rgb[i * 3 + 2] = rgba[i * 4];
    }
    await a.setScreen(rgb, 4);
    _wacomScreenActive = true;
  }

  void _drawText(Canvas c, String text, TextStyle style, Offset pos,
      {bool center = false}) {
    final tp = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    tp.paint(c,
        center ? Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2) : pos);
  }

  void _drawBtn(Canvas c, String label, Rect r, Color bg, Color fg) {
    c.drawRect(r, Paint()..color = bg);
    c.drawRect(r, Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);
    _drawText(c, label,
        TextStyle(color: fg, fontSize: 20, fontWeight: FontWeight.w700),
        r.center, center: true);
  }

  // ── Pen event ──────────────────────────────────────────────────────────────

  void _handlePen(Map<String, dynamic> e, Map<String, dynamic> caps) {
    if (!_wacomScreenActive) return;
    final double x   = e['x'] as double, y   = e['y'] as double;
    final double p   = e['pressure'] as double;
    final int    sw  = e['sw'] as int;
    final double mX  = caps['maxX'] as double, mY = caps['maxY'] as double;
    final double sW  = caps['screenWidth'] as double;
    final double sH  = caps['screenHeight'] as double;
    final double mpX = (x / mX) * sW, mpY = (y / mY) * sH;

    // Button area (bottom 20%)
    if (mpY >= sH * 0.8 && p > 0) {
      if (_isClosing) return;
      final bW = sW / 3.0;
      if (mpX < bW) {
        _clear();
        _drawWacomScreen(widget.wacomAdapter!);
      } else if (mpX < bW * 2) {
        _closeDialog(null);
      } else {
        _apply();
      }
      return;
    }

    // Signature area
    setState(() {
      if (p > 0 || sw != 0) {
        _currentStroke.add(Offset((x / mX) * _canvasW, (y / mY) * _canvasH));
      } else if (_currentStroke.isNotEmpty) {
        _strokes.add(List.from(_currentStroke));
        _currentStroke = [];
      }
    });
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  void _clear() => setState(() { _strokes.clear(); _currentStroke = []; });

  Future<void> _apply() async {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec, Rect.fromLTWH(0, 0, _canvasW, _canvasH));
    final paint = Paint()
      ..color = _penColor ..strokeWidth = 2.4 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round;

    void drawList(List<List<Offset>> list) {
      for (final s in list) {
        if (s.length < 2) continue;
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (var i = 1; i < s.length; i++) { path.lineTo(s[i].dx, s[i].dy); }
        c.drawPath(path, paint);
      }
    }
    drawList(_strokes);
    if (_currentStroke.length >= 2) drawList([_currentStroke]);

    final img = await rec.endRecording()
        .toImage(_canvasW.toInt(), _canvasH.toInt());
    final bd  = await img.toByteData(format: ui.ImageByteFormat.png);
    _closeDialog(bd?.buffer.asUint8List());
  }

  Future<void> _closeDialog(Uint8List? result) async {
    if (_isClosing) return;
    _isClosing = true;
    await _penSub?.cancel();
    await _resetWacomScreen();
    if (mounted) Navigator.of(context).pop(result);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final bool usingWacom = widget.wacomAdapter?.isConnected == true;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [

            // ── Logo ──────────────────────────────────────────────────
            _buildLogoBox(),
            const SizedBox(height: 12),

            // ── Title ─────────────────────────────────────────────────
            Text(
              _resolvedTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              usingWacom
                  ? 'Sign using the Wacom tablet'
                  : 'Use your finger or mouse to sign',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),

            // ── Wacom badge ───────────────────────────────────────────
            if (usingWacom) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.usb_rounded, size: 14,
                        color: Color(0xFF16A34A)),
                    SizedBox(width: 4),
                    Text('Wacom Active',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF16A34A))),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 20),

            // ── Canvas ────────────────────────────────────────────────
            Container(
              width: _canvasW,
              height: _canvasH,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x0D000000),
                      blurRadius: 8, offset: Offset(0, 4)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Stack(
                  children: [
                    if (!_hasInk)
                      Center(
                        child: Text(
                          usingWacom ? 'Sign on the tablet' : 'Sign here',
                          style: const TextStyle(
                              color: Color(0xFFCBD5E1),
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanStart: (d) =>
                          setState(() => _currentStroke = [d.localPosition]),
                      onPanUpdate: (d) =>
                          setState(() => _currentStroke.add(d.localPosition)),
                      onPanEnd: (_) => setState(() {
                        if (_currentStroke.isNotEmpty) {
                          _strokes.add(List.from(_currentStroke));
                          _currentStroke = [];
                        }
                      }),
                      child: CustomPaint(
                        size: const Size(_canvasW, _canvasH),
                        painter: _StrokePainter(
                            _strokes, _currentStroke, _penColor),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Colour swatches ───────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _ColorSwatch(
                  color: const Color(0xFF1E293B),
                  selected: _penColor == const Color(0xFF1E293B),
                  onTap: () =>
                      setState(() => _penColor = const Color(0xFF1E293B)),
                ),
                const SizedBox(width: 10),
                _ColorSwatch(
                  color: const Color(0xFF2563EB),
                  selected: _penColor == const Color(0xFF2563EB),
                  onTap: () =>
                      setState(() => _penColor = const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 10),
                _ColorSwatch(
                  color: const Color(0xFFDC2626),
                  selected: _penColor == const Color(0xFFDC2626),
                  onTap: () =>
                      setState(() => _penColor = const Color(0xFFDC2626)),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Action buttons ────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: _clear,
                  child: const Text('Clear',
                      style: TextStyle(color: Color(0xFF64748B))),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _closeDialog(null),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    foregroundColor: const Color(0xFF64748B),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _hasInk ? _apply : null,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF4F46E5)),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Logo box ───────────────────────────────────────────────────────────────

  Widget _buildLogoBox() {
    final url = widget.brandLogoUrl?.trim();
    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url, width: 56, height: 56, fit: BoxFit.contain,
          loadingBuilder: (_, child, p) =>
              p == null ? child : _defaultIcon(),
          errorBuilder: (_, __, ___) => _defaultIcon(),
        ),
      );
    }
    return _defaultIcon();
  }

  Widget _defaultIcon() => Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFEEF2FF),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.draw_rounded,
            color: Color(0xFF4F46E5), size: 28),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch(
      {required this.color, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: selected
                ? Border.all(color: Colors.white, width: 3)
                : Border.all(color: Colors.black12),
            boxShadow: selected
                ? [const BoxShadow(color: Color(0x44000000), blurRadius: 6)]
                : null,
          ),
        ),
      );
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final Color color;

  const _StrokePainter(this.strokes, this.current, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color ..strokeWidth = 2.4 ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round ..strokeJoin = StrokeJoin.round;

    void draw(List<Offset> pts) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) { path.lineTo(pts[i].dx, pts[i].dy); }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) { draw(s); }
    draw(current);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}
