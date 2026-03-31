import 'dart:typed_data';
import 'package:flutter/material.dart';

/// An overlay widget that renders a single signature box on top of the PDF viewer.
/// Supports drag-to-move, resize (bottom-right handle), tap-to-sign, and delete.
class SignatureBoxOverlay extends StatefulWidget {
  /// Screen-space rectangle for this box (updated externally via setState).
  final Rect rect;

  /// Called with the screen-delta when the box is dragged.
  final void Function(Offset delta) onDrag;

  /// Called when the box is tapped (open signature dialog).
  final VoidCallback onTap;

  /// Called when the delete button is pressed.
  final VoidCallback onDelete;

  /// The PNG signature image, or null if unsigned.
  final Uint8List? signatureImage;

  const SignatureBoxOverlay({
    super.key,
    required this.rect,
    required this.onDrag,
    required this.onTap,
    required this.onDelete,
    this.signatureImage,
  });

  @override
  State<SignatureBoxOverlay> createState() => _SignatureBoxOverlayState();
}

class _SignatureBoxOverlayState extends State<SignatureBoxOverlay> {
  static const double _handleSize = 28.0;
  static const double _inset = 10.0;

  late Offset _position;
  late Size _size;

  @override
  void initState() {
    super.initState();
    _position = widget.rect.topLeft;
    _size = widget.rect.size;
  }

  @override
  void didUpdateWidget(SignatureBoxOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rect != widget.rect) {
      _position = widget.rect.topLeft;
      _size = widget.rect.size;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF4F46E5);
    const errorColor = Color(0xFFEF4444);

    return Positioned(
      left: _position.dx - _inset,
      top: _position.dy - _inset,
      child: SizedBox(
        width: _size.width + _inset * 2,
        height: _size.height + _inset * 2,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // ── Main box ────────────────────────────────────────────────
            Positioned(
              left: _inset,
              top: _inset,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  setState(() => _position += d.delta);
                  widget.onDrag(d.delta);
                },
                onTap: widget.onTap,
                child: Container(
                  width: _size.width,
                  height: _size.height,
                  decoration: BoxDecoration(
                    color: widget.signatureImage != null
                        ? Colors.transparent
                        : primaryColor.withAlpha(20),
                    border: Border.all(color: primaryColor, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: widget.signatureImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.memory(
                            widget.signatureImage!,
                            fit: BoxFit.contain,
                          ),
                        )
                      : const Center(
                          child: Text(
                            'Tap to sign',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            // ── Delete button (top-left) ─────────────────────────────────
            Positioned(
              left: 0,
              top: 0,
              child: GestureDetector(
                onTap: widget.onDelete,
                child: Container(
                  width: _handleSize,
                  height: _handleSize,
                  decoration: const BoxDecoration(
                    color: errorColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.close_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),

            // ── Resize handle (bottom-right) ─────────────────────────────
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (d) {
                  setState(() {
                    _size = Size(
                      (_size.width + d.delta.dx).clamp(80.0, 600.0),
                      (_size.height + d.delta.dy).clamp(40.0, 400.0),
                    );
                  });
                },
                child: Container(
                  width: _handleSize,
                  height: _handleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1A000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.open_in_full_rounded,
                    color: Color(0xFF64748B),
                    size: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
