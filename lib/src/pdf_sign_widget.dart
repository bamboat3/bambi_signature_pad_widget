import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' show PdfDocument;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:uuid/uuid.dart';

import 'models/signature_box_model.dart';
import 'services/pdf_download_service.dart';
import 'services/pdf_embed_service.dart';
import 'widgets/signature_box_overlay.dart';
import 'widgets/signature_pad_dialog.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Public widget
// ─────────────────────────────────────────────────────────────────────────────

/// A two-pane widget:
///   • **Left** – Syncfusion PDF viewer with draggable / resizable signature boxes.
///   • **Right** – Control panel with "Add Signature Box" and "Save Document" buttons.
///
/// ### Parameters
/// | Name               | Type                  | Description                                               |
/// |--------------------|-----------------------|-----------------------------------------------------------|
/// | [pdfUrl]           | `String`              | HTTP(S) URL of the PDF to display.                        |
/// | [outputFilename]   | `String`              | File name (with or without .pdf) to save as.              |
/// | [brandLogoUrl]     | `String?`             | URL of a logo image shown in the signature pad header.    |
/// | [signatureTitle]   | `String?`             | Custom title shown in the signature pad header.           |
/// | [onSaveComplete]   | `void Function(bool)` | Called with `true` on success, `false` on error.          |
///
/// ### FlutterFlow custom-widget usage
/// ```dart
/// PdfSignWidget(
///   pdfUrl: 'https://example.com/document.pdf',
///   outputFilename: 'signed_contract',
///   brandLogoUrl: 'https://example.com/logo.png',
///   signatureTitle: 'Sign the Agreement',
///   onSaveComplete: (success) {
///     if (success) { /* proceed with DB logic */ }
///   },
/// )
/// ```
class PdfSignWidget extends StatefulWidget {
  /// The HTTP(S) URL of the PDF document to load and display.
  final String pdfUrl;

  /// The file name (with or without `.pdf`) used when saving the signed document.
  ///
  /// The file is written to the app documents directory. A `.pdf` extension is
  /// appended automatically if not already present.
  final String outputFilename;

  /// URL of the brand logo shown in the signature pad dialog header.
  ///
  /// Pass an empty string or omit to show the default pen icon.
  final String? brandLogoUrl;

  /// Title text shown in the signature pad dialog header.
  ///
  /// Falls back to `'Draw your signature'` when null or empty.
  final String? signatureTitle;

  /// Called with `true` when the signed PDF is saved successfully,
  /// or `false` if an error occurs during saving.
  final void Function(bool success)? onSaveComplete;

  /// Creates a [PdfSignWidget].
  ///
  /// [pdfUrl] and [outputFilename] are required.
  /// [brandLogoUrl], [signatureTitle], and [onSaveComplete] are optional.
  const PdfSignWidget({
    super.key,
    required this.pdfUrl,
    required this.outputFilename,
    this.brandLogoUrl,
    this.signatureTitle,
    this.onSaveComplete,
  });

  @override
  State<PdfSignWidget> createState() => _PdfSignWidgetState();
}

// ─────────────────────────────────────────────────────────────────────────────
// State
// ─────────────────────────────────────────────────────────────────────────────

class _PdfSignWidgetState extends State<PdfSignWidget> {
  // PDF viewer
  final PdfViewerController _controller = PdfViewerController();

  // Download / load state
  File? _tempFile;
  String? _loadError;
  bool _isLoading = true;

  // PDF page metadata (needed for coordinate conversion)
  List<Size>? _pageSizes;
  Size? _viewportSize;

  // Signature boxes
  final List<SignatureBoxModel> _boxes = [];
  final _uuid = const Uuid();

  // Draw-mode: user drag-draws a box rectangle on the viewer
  bool _drawMode = false;
  Offset? _dragStart;
  Offset? _dragCurrent;
  int? _dragPageIndex;

  // Saving state
  bool _isSaving = false;

  // Scroll poller – triggers rebuilds so overlays stay glued to pages
  Timer? _scrollPoller;

  // ── Constant matching SfPdfViewer default ─────────────────────────────────
  static const double _pageSpacing = 8.0;
  static const double _panelWidth = 240.0;

  // ── Colours ────────────────────────────────────────────────────────────────
  static const Color _primary = Color(0xFF4F46E5);
  static const Color _surface = Color(0xFFF8FAFC);
  static const Color _border = Color(0xFFE2E8F0);
  static const Color _textPrimary = Color(0xFF0F172A);
  static const Color _textSecondary = Color(0xFF64748B);
  static const Color _errorColor = Color(0xFFEF4444);

  // ─────────────────────────────────────────────────────────────────────────
  // Lifecycle
  // ─────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _downloadPdf();
    _scrollPoller = Timer.periodic(const Duration(milliseconds: 32), (_) {
      if (mounted && _pageSizes != null) setState(() {});
    });
  }

  @override
  void dispose() {
    _scrollPoller?.cancel();
    if (_tempFile != null) deleteTempFile(_tempFile!);
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PDF download + metadata
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _downloadPdf() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    try {
      final file = await downloadPdfToTemp(widget.pdfUrl);
      final bytes = await file.readAsBytes();
      final doc = PdfDocument(inputBytes: bytes);
      final sizes = <Size>[];
      for (var i = 0; i < doc.pages.count; i++) {
        sizes.add(doc.pages[i].getClientSize());
      }
      doc.dispose();

      if (!mounted) return;
      setState(() {
        _tempFile = file;
        _pageSizes = sizes;
        _isLoading = false;
      });

      // Auto-fit zoom after layout
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _viewportSize == null || sizes.isEmpty) return;
        final maxW = sizes.map((s) => s.width).reduce(
              (a, b) => a > b ? a : b,
            );
        if (maxW > 0 && maxW > _viewportSize!.width) {
          _controller.zoomLevel = (_viewportSize!.width - 16) / maxW;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoading = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Coordinate helpers
  // ─────────────────────────────────────────────────────────────────────────

  /// Effective pixels-per-PDF-point at the current zoom.
  double get _zoom {
    if (_viewportSize == null || _pageSizes == null || _pageSizes!.isEmpty) {
      return 1.0;
    }
    final maxW = _pageSizes!.map((s) => s.width).reduce((a, b) => a > b ? a : b);
    if (maxW == 0) return 1.0;
    return (_viewportSize!.width / maxW) * _controller.zoomLevel;
  }

  /// Converts a [SignatureBoxModel]'s PDF-space rect to screen-space rect.
  Rect _toScreenRect(SignatureBoxModel model) {
    if (_pageSizes == null) return Rect.zero;
    final zoom = _zoom;
    final scroll = _controller.scrollOffset;

    double pageTop = 0;
    for (var i = 0; i < model.pageIndex; i++) {
      pageTop += _pageSizes![i].height * zoom + _pageSpacing;
    }

    double marginLeft = 0;
    if (_viewportSize != null) {
      final pw = _pageSizes![model.pageIndex].width * zoom;
      if (pw < _viewportSize!.width) {
        marginLeft = (_viewportSize!.width - pw) / 2;
      }
    }

    return Rect.fromLTWH(
      model.pdfRect.left * zoom + marginLeft - scroll.dx,
      model.pdfRect.top * zoom + pageTop - scroll.dy,
      model.pdfRect.width * zoom,
      model.pdfRect.height * zoom,
    );
  }

  /// Converts a screen-space [Rect] (within a specific page) to PDF-space.
  Rect _toPdfRect(Rect screenRect, int pageIndex) {
    final zoom = _zoom;
    final scroll = _controller.scrollOffset;

    double pageTop = 0;
    for (var i = 0; i < pageIndex; i++) {
      pageTop += _pageSizes![i].height * zoom + _pageSpacing;
    }

    double marginLeft = 0;
    if (_viewportSize != null) {
      final pw = _pageSizes![pageIndex].width * zoom;
      if (pw < _viewportSize!.width) {
        marginLeft = (_viewportSize!.width - pw) / 2;
      }
    }

    return Rect.fromLTWH(
      (screenRect.left + scroll.dx - marginLeft) / zoom,
      (screenRect.top + scroll.dy - pageTop) / zoom,
      screenRect.width / zoom,
      screenRect.height / zoom,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Box drag
  // ─────────────────────────────────────────────────────────────────────────

  void _handleBoxDrag(SignatureBoxModel model, Offset screenDelta) {
    if (_pageSizes == null) return;
    final zoom = _zoom;
    final dx = screenDelta.dx / zoom;
    final dy = screenDelta.dy / zoom;

    setState(() {
      model.pdfRect = Rect.fromLTWH(
        model.pdfRect.left + dx,
        model.pdfRect.top + dy,
        model.pdfRect.width,
        model.pdfRect.height,
      );

      // Cross-page boundary detection (move down)
      if (model.pageIndex < _pageSizes!.length - 1) {
        final pageH = _pageSizes![model.pageIndex].height;
        if (model.pdfRect.top > pageH) {
          model.pageIndex++;
          model.pdfRect = Rect.fromLTWH(
            model.pdfRect.left,
            model.pdfRect.top - pageH,
            model.pdfRect.width,
            model.pdfRect.height,
          );
        }
      }
      // Cross-page boundary detection (move up)
      if (model.pageIndex > 0 && model.pdfRect.top < 0) {
        model.pageIndex--;
        final prevH = _pageSizes![model.pageIndex].height;
        model.pdfRect = Rect.fromLTWH(
          model.pdfRect.left,
          prevH + model.pdfRect.top,
          model.pdfRect.width,
          model.pdfRect.height,
        );
      }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Signature assignment
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _openSignaturePad(SignatureBoxModel model) async {
    if (!mounted) return;
    final Uint8List? result = await SignaturePadDialog.show(
      context,
      brandLogoUrl: widget.brandLogoUrl,
      signatureTitle: widget.signatureTitle,
    );
    if (!mounted) return;
    if (result != null) {
      setState(() => model.image = result);
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Draw mode
  // ─────────────────────────────────────────────────────────────────────────

  void _toggleDrawMode() {
    setState(() {
      _drawMode = !_drawMode;
      _dragStart = null;
      _dragCurrent = null;
      _dragPageIndex = null;
    });
  }

  void _finishDraw() {
    if (_dragStart == null ||
        _dragCurrent == null ||
        _dragPageIndex == null ||
        _pageSizes == null) { return; }

    final rawRect = Rect.fromPoints(_dragStart!, _dragCurrent!);

    if (rawRect.width < 30 || rawRect.height < 20) {
      // Too small – cancel
      setState(() {
        _dragStart = null;
        _dragCurrent = null;
      });
      return;
    }

    final pdfRect = _toPdfRect(rawRect, _dragPageIndex!);
    final model = SignatureBoxModel(
      id: _uuid.v4(),
      pdfRect: pdfRect,
      pageIndex: _dragPageIndex!,
    );

    setState(() {
      _boxes.add(model);
      _drawMode = false;
      _dragStart = null;
      _dragCurrent = null;
      _dragPageIndex = null;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { _openSignaturePad(model); }
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Save
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _saveDocument() async {
    if (_tempFile == null) return;

    final signed = _boxes.where((b) => b.isSigned).toList();
    if (signed.isEmpty) {
      _showSnack('Please place and sign at least one signature box.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      final pdfBytes = await embedSignaturesIntoPdf(
        pdfFile: _tempFile!,
        signatures: signed
            .map((b) => {
                  'image': b.image!,
                  'x': b.pdfRect.left,
                  'y': b.pdfRect.top,
                  'width': b.pdfRect.width,
                  'height': b.pdfRect.height,
                  'pageIndex': b.pageIndex + 1, // service expects 1-based
                })
            .toList(),
      );

      final savedFile =
          await savePdfToDocuments(pdfBytes, widget.outputFilename);

      if (!mounted) return;
      _showSnack('Saved to: ${savedFile.path}');
      widget.onSaveComplete?.call(true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Error saving: $e');
      widget.onSaveComplete?.call(false);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _surface,
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _buildLoader();
    if (_loadError != null) return _buildError();

    return Row(
      children: [
        // ── Left: PDF viewer ───────────────────────────────────────────
        Expanded(child: _buildViewerPane()),

        // ── Divider ────────────────────────────────────────────────────
        Container(width: 1, color: _border),

        // ── Right: Control panel ───────────────────────────────────────
        SizedBox(width: _panelWidth, child: _buildControlPanel()),
      ],
    );
  }

  // ── Loader ──────────────────────────────────────────────────────────────

  Widget _buildLoader() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: _primary),
          SizedBox(height: 16),
          Text(
            'Loading PDF…',
            style: TextStyle(color: _textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  // ── Error ────────────────────────────────────────────────────────────────

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: _errorColor, size: 48),
            const SizedBox(height: 12),
            const Text(
              'Failed to load PDF',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ?? 'Unknown error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _downloadPdf,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(backgroundColor: _primary),
            ),
          ],
        ),
      ),
    );
  }

  // ── PDF viewer pane ──────────────────────────────────────────────────────

  Widget _buildViewerPane() {
    return NotificationListener<ScrollNotification>(
      onNotification: (_) {
        setState(() {});
        return true;
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          _viewportSize = constraints.biggest;

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // PDF
              SfPdfViewer.file(
                _tempFile!,
                controller: _controller,
                pageSpacing: _pageSpacing,
                enableDoubleTapZooming: !_drawMode,
                onPageChanged: (_) => setState(() {}),
                onZoomLevelChanged: (_) => setState(() {}),
              ),

              // Signature box overlays
              if (_pageSizes != null)
                ..._boxes.map((model) {
                  final rect = _toScreenRect(model);
                  return SignatureBoxOverlay(
                    key: ValueKey(model.id),
                    rect: rect,
                    signatureImage: model.image,
                    onDrag: (delta) => _handleBoxDrag(model, delta),
                    onTap: () => _openSignaturePad(model),
                    onDelete: () => setState(() => _boxes.remove(model)),
                  );
                }),

              // Draw-mode gesture layer
              if (_drawMode)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => setState(() {
                      _dragStart = d.localPosition;
                      _dragCurrent = d.localPosition;
                      _dragPageIndex = _controller.pageNumber > 0
                          ? _controller.pageNumber - 1
                          : 0;
                    }),
                    onPanUpdate: (d) =>
                        setState(() => _dragCurrent = d.localPosition),
                    onPanEnd: (_) => _finishDraw(),
                    child: Stack(
                      children: [
                        // Draw-mode tint
                        Positioned.fill(
                          child: Container(
                            color: _primary.withAlpha(10),
                          ),
                        ),
                        // Live selection rectangle
                        if (_dragStart != null && _dragCurrent != null)
                          Positioned(
                            left: _dragStart!.dx < _dragCurrent!.dx
                                ? _dragStart!.dx
                                : _dragCurrent!.dx,
                            top: _dragStart!.dy < _dragCurrent!.dy
                                ? _dragStart!.dy
                                : _dragCurrent!.dy,
                            width: (_dragCurrent!.dx - _dragStart!.dx).abs(),
                            height: (_dragCurrent!.dy - _dragStart!.dy).abs(),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: _primary,
                                  width: 2,
                                  strokeAlign: BorderSide.strokeAlignOutside,
                                ),
                                color: _primary.withAlpha(30),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Right control panel ──────────────────────────────────────────────────

  Widget _buildControlPanel() {
    final signedCount = _boxes.where((b) => b.isSigned).length;
    final totalCount = _boxes.length;

    return Container(
      color: _surface,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──────────────────────────────────────────────────
          const Text(
            'Signature Tools',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add boxes on the PDF, then sign each one.',
            style: TextStyle(fontSize: 12, color: _textSecondary),
          ),

          const SizedBox(height: 20),

          // ── Add Signature Box button ─────────────────────────────────
          _PanelButton(
            label: _drawMode ? 'Cancel Drawing' : 'Add Signature Box',
            icon: _drawMode ? Icons.close_rounded : Icons.draw_outlined,
            color: _drawMode ? _errorColor : _primary,
            onPressed: _toggleDrawMode,
          ),

          if (_drawMode) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _primary.withAlpha(15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _primary.withAlpha(60)),
              ),
              child: const Text(
                'Click and drag on the PDF to draw a signature box.',
                style: TextStyle(
                  fontSize: 11,
                  color: _primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // ── Placed-boxes list ────────────────────────────────────────
          if (_boxes.isNotEmpty) ...[
            Text(
              'Placed boxes ($signedCount/$totalCount signed)',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: ListView.separated(
                itemCount: _boxes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (_, i) {
                  final box = _boxes[i];
                  return _BoxTile(
                    index: i + 1,
                    isSigned: box.isSigned,
                    onSign: () => _openSignaturePad(box),
                    onDelete: () => setState(() => _boxes.remove(box)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ] else
            const Spacer(),

          // ── Save Document button ─────────────────────────────────────
          const Divider(color: _border),
          const SizedBox(height: 8),

          _isSaving
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: CircularProgressIndicator(
                      color: _primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                )
              : _PanelButton(
                  label: 'Save Document',
                  icon: Icons.save_rounded,
                  color: signedCount > 0
                      ? const Color(0xFF059669)
                      : const Color(0xFFCBD5E1),
                  onPressed: signedCount > 0 ? _saveDocument : null,
                ),

          if (signedCount == 0 && _boxes.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Sign at least one box to save.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: _textSecondary),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _PanelButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const _PanelButton({
    required this.label,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontSize: 13)),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2E8F0),
          disabledForegroundColor: const Color(0xFF94A3B8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _BoxTile extends StatelessWidget {
  final int index;
  final bool isSigned;
  final VoidCallback onSign;
  final VoidCallback onDelete;

  const _BoxTile({
    required this.index,
    required this.isSigned,
    required this.onSign,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF059669);
    const amber = Color(0xFFF59E0B);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSigned ? green.withAlpha(80) : amber.withAlpha(80),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isSigned ? Icons.check_circle_rounded : Icons.pending_rounded,
            size: 18,
            color: isSigned ? green : amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Box $index – ${isSigned ? 'Signed' : 'Unsigned'}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
          if (!isSigned)
            GestureDetector(
              onTap: onSign,
              child: const Text(
                'Sign',
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4F46E5),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
