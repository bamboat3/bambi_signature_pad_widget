import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/painting.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Embeds [signatures] into [pdfFile] and returns the resulting PDF bytes.
///
/// Each entry in [signatures] must have:
///   - `image`     : Uint8List  – PNG bytes of the signature
///   - `x`         : double     – left edge in PDF page points
///   - `y`         : double     – top edge in PDF page points
///   - `width`     : double     – box width in PDF page points
///   - `height`    : double     – box height in PDF page points
///   - `pageIndex` : int        – **1-based** page number
Future<Uint8List> embedSignaturesIntoPdf({
  required File pdfFile,
  required List<Map<String, dynamic>> signatures,
}) async {
  final inputBytes = await pdfFile.readAsBytes();
  final document = PdfDocument(inputBytes: inputBytes);

  try {
    for (final sig in signatures) {
      final Uint8List imgBytes = sig['image'] as Uint8List;
      final double x = (sig['x'] as num).toDouble();
      final double y = (sig['y'] as num).toDouble();
      final double w = (sig['width'] as num).toDouble();
      final double h = (sig['height'] as num).toDouble();
      final int pageOneBased = (sig['pageIndex'] as int);

      final int pageIdx =
          (pageOneBased - 1).clamp(0, document.pages.count - 1);
      final PdfPage page = document.pages[pageIdx];
      final Size pageSize = page.getClientSize();

      // Clamp to page bounds
      final double finalX = x.clamp(0.0, pageSize.width - w);
      final double finalY = y.clamp(0.0, pageSize.height - h);

      page.graphics.drawImage(
        PdfBitmap(imgBytes),
        Rect.fromLTWH(finalX, finalY, w, h),
      );
    }

    final List<int> saved = await document.save();
    return Uint8List.fromList(saved);
  } finally {
    document.dispose();
  }
}
