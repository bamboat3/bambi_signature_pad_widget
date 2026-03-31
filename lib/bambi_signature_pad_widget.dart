/// PDF viewer and signature pad widget for Flutter and FlutterFlow.
///
/// Import this library to access [PdfSignWidget], which provides a
/// split-pane UI for loading a PDF from a URL, placing draggable signature
/// boxes, drawing signatures with a finger or mouse, and saving the signed
/// PDF to the device's documents directory.
///
/// ```dart
/// import 'package:bambi_signature_pad_widget/bambi_signature_pad_widget.dart';
///
/// PdfSignWidget(
///   pdfUrl: 'https://example.com/contract.pdf',
///   outputFilename: 'signed_contract',
///   brandLogoUrl: 'https://example.com/logo.png',
///   signatureTitle: 'Sign the Agreement',
///   onSaveComplete: (success) {
///     if (success) { /* proceed with DB logic */ }
///   },
/// )
/// ```
library;

export 'src/pdf_sign_widget.dart';
export 'src/wacom/wacom_adapter.dart';
