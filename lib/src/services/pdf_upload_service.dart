import 'package:http/http.dart' as http;

/// Uploads [pdfBytes] to [uploadUrl] as a multipart POST request.
///
/// The request body contains two fields:
/// - `filename` — the value of [filename] (`.pdf` appended if missing)
/// - `file`     — the signed PDF as a binary stream
///
/// Returns `true` when the server responds with HTTP 2xx, `false` otherwise.
/// Throws on network-level errors (no connectivity, DNS failure, etc.).
Future<bool> uploadSignedPdf({
  required List<int> pdfBytes,
  required String uploadUrl,
  required String filename,
}) async {
  final uri = Uri.parse(uploadUrl.trim());

  String name = filename.trim();
  if (!name.toLowerCase().endsWith('.pdf')) name = '$name.pdf';

  final request = http.MultipartRequest('POST', uri)
    ..fields['filename'] = name
    ..files.add(
      http.MultipartFile.fromBytes(
        'file',
        pdfBytes,
        filename: name,
      ),
    );

  final streamed = await request.send();
  return streamed.statusCode >= 200 && streamed.statusCode < 300;
}
