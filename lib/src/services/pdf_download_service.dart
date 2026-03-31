import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Downloads a PDF from [url] into a temporary file and returns it.
Future<File> downloadPdfToTemp(String url) async {
  final uri = Uri.parse(url.trim());

  final response = await http.get(uri);
  if (response.statusCode != 200) {
    throw HttpException(
      'Failed to download PDF (HTTP ${response.statusCode})',
      uri: uri,
    );
  }

  final bytes = response.bodyBytes;
  return _writeTempPdf(bytes);
}

Future<File> _writeTempPdf(Uint8List bytes) async {
  final tempDir = await getTemporaryDirectory();
  final ts = DateTime.now().millisecondsSinceEpoch;
  final file = File('${tempDir.path}${Platform.pathSeparator}pdf_sign_$ts.pdf');
  return file.writeAsBytes(bytes, flush: true);
}

/// Saves [bytes] to the app-documents directory with [filename].
/// Returns the resulting [File].
Future<File> savePdfToDocuments(Uint8List bytes, String filename) async {
  final dir = await getApplicationDocumentsDirectory();
  String name = filename.trim();
  if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';
  final file = File('${dir.path}${Platform.pathSeparator}$name');
  return file.writeAsBytes(bytes, flush: true);
}

/// Deletes [file] silently – used to clean up the temp download on dispose.
Future<void> deleteTempFile(File file) async {
  try {
    if (await file.exists()) await file.delete();
  } catch (_) {
    debugPrint('[pdf_sign_widget] Could not delete temp file: ${file.path}');
  }
}
