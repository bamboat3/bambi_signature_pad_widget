import 'dart:typed_data';
import 'package:flutter/painting.dart';

/// Represents a single signature box placed on the PDF.
class SignatureBoxModel {
  final String id;

  /// Position and size in PDF page coordinates (unscaled).
  Rect pdfRect;

  /// The drawn signature as a PNG image, or null if not yet signed.
  Uint8List? image;

  /// 0-based page index within the document.
  int pageIndex;

  SignatureBoxModel({
    required this.id,
    required this.pdfRect,
    this.image,
    required this.pageIndex,
  });

  bool get isSigned => image != null;
}
