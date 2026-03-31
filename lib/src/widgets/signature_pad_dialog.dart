import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// A modal dialog containing a finger/mouse-drawable signature pad.
///
/// Optionally shows a branded logo and custom title in the header.
/// Returns a [Uint8List] PNG of the drawn signature, or null if cancelled.
class SignaturePadDialog extends StatefulWidget {
  /// URL of the brand logo image shown in the dialog header.
  /// If null, a default pen icon is shown instead.
  final String? brandLogoUrl;

  /// Title text shown in the dialog header.
  /// Defaults to 'Draw your signature' when null or empty.
  final String? signatureTitle;

  const SignaturePadDialog({
    super.key,
    this.brandLogoUrl,
    this.signatureTitle,
  });

  /// Convenience helper: shows the dialog and returns the PNG bytes (or null).
  static Future<Uint8List?> show(
    BuildContext context, {
    String? brandLogoUrl,
    String? signatureTitle,
  }) {
    return showDialog<Uint8List>(
      context: context,
      barrierDismissible: false,
      builder: (_) => SignaturePadDialog(
        brandLogoUrl: brandLogoUrl,
        signatureTitle: signatureTitle,
      ),
    );
  }

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  static const double _canvasW = 420.0;
  static const double _canvasH = 210.0;

  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  Color _penColor = const Color(0xFF1E293B);

  bool get _hasInk => _strokes.isNotEmpty || _currentStroke.isNotEmpty;

  String get _resolvedTitle =>
      (widget.signatureTitle?.trim().isNotEmpty == true)
          ? widget.signatureTitle!
          : 'Draw your signature';

  void _clear() => setState(() {
        _strokes.clear();
        _currentStroke = [];
      });

  Future<void> _apply() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(
      recorder,
      Rect.fromLTWH(0, 0, _canvasW, _canvasH),
    );

    final paint = Paint()
      ..color = _penColor
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void drawStrokes(List<List<Offset>> strokes) {
      for (final s in strokes) {
        if (s.length < 2) continue;
        final path = Path()..moveTo(s.first.dx, s.first.dy);
        for (var i = 1; i < s.length; i++) {
          path.lineTo(s[i].dx, s[i].dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    drawStrokes(_strokes);
    if (_currentStroke.length >= 2) drawStrokes([_currentStroke]);

    final picture = recorder.endRecording();
    final img = await picture.toImage(_canvasW.toInt(), _canvasH.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    if (mounted) {
      Navigator.of(context).pop(byteData?.buffer.asUint8List());
    }
  }

  // ── Header logo widget ───────────────────────────────────────────────────
  // Shows the network logo when brandLogoUrl is provided, otherwise falls
  // back to the default pen icon. The logo is contained in a fixed 36×36 box
  // so the rest of the header layout stays consistent.
  Widget _buildLogoBox() {
    final url = widget.brandLogoUrl?.trim();

    if (url != null && url.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          // Show the default icon while loading or on error
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : _defaultIconBox(),
          errorBuilder: (_, __, ___) => _defaultIconBox(),
        ),
      );
    }

    return _defaultIconBox();
  }

  Widget _defaultIconBox() {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.draw_rounded, color: Color(0xFF4F46E5), size: 20),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            Row(
              children: [
                _buildLogoBox(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _resolvedTitle,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Use your finger or mouse to sign',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Signature canvas ─────────────────────────────────────────
            Container(
              width: _canvasW,
              height: _canvasH,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 2),
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0D000000),
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    if (!_hasInk)
                      const Center(
                        child: Text(
                          'Sign here',
                          style: TextStyle(
                            color: Color(0xFFCBD5E1),
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
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
                          _strokes,
                          _currentStroke,
                          _penColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Pen colour + action buttons ──────────────────────────────
            Row(
              children: [
                _ColorSwatch(
                  color: const Color(0xFF1E293B),
                  selected: _penColor == const Color(0xFF1E293B),
                  onTap: () =>
                      setState(() => _penColor = const Color(0xFF1E293B)),
                ),
                const SizedBox(width: 8),
                _ColorSwatch(
                  color: const Color(0xFF2563EB),
                  selected: _penColor == const Color(0xFF2563EB),
                  onTap: () =>
                      setState(() => _penColor = const Color(0xFF2563EB)),
                ),
                const SizedBox(width: 8),
                _ColorSwatch(
                  color: const Color(0xFFDC2626),
                  selected: _penColor == const Color(0xFFDC2626),
                  onTap: () =>
                      setState(() => _penColor = const Color(0xFFDC2626)),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _clear,
                  child: const Text(
                    'Clear',
                    style: TextStyle(color: Color(0xFF64748B)),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(null),
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
                    backgroundColor: const Color(0xFF4F46E5),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black, width: 2.5) : null,
          boxShadow: selected
              ? const [BoxShadow(color: Color(0x33000000), blurRadius: 4)]
              : null,
        ),
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  final List<List<Offset>> strokes;
  final List<Offset> current;
  final Color color;

  const _StrokePainter(this.strokes, this.current, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    void draw(List<Offset> pts) {
      if (pts.length < 2) return;
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) {
      draw(s);
    }
    draw(current);
  }

  @override
  bool shouldRepaint(covariant _StrokePainter old) => true;
}
