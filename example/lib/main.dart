import 'package:bambi_signature_pad_widget/bambi_signature_pad_widget.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bambi Signature Pad Example',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: const SignaturePage(),
    );
  }
}

class SignaturePage extends StatefulWidget {
  const SignaturePage({super.key});

  @override
  State<SignaturePage> createState() => _SignaturePageState();
}

class _SignaturePageState extends State<SignaturePage> {
  bool? _uploadResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Result banner shown after save attempt
          if (_uploadResult != null)
            MaterialBanner(
              content: Text(
                _uploadResult!
                    ? 'Document uploaded successfully!'
                    : 'Upload failed — please try again.',
              ),
              backgroundColor: _uploadResult!
                  ? Colors.green.shade50
                  : Colors.red.shade50,
              leading: Icon(
                _uploadResult! ? Icons.check_circle : Icons.error,
                color: _uploadResult! ? Colors.green : Colors.red,
              ),
              actions: [
                TextButton(
                  onPressed: () => setState(() => _uploadResult = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),

          // Widget fills the remaining screen space
          Expanded(
            child: PdfSignWidget(
              // PDF to display
              pdfUrl: 'https://www.w3.org/WAI/WCAG21/wcag-2.1.pdf',

              // API endpoint — receives multipart POST with fields:
              //   "filename" (text)  and  "file" (binary stream)
              uploadUrl: 'https://api.example.com/upload-signed-pdf',

              // Sent as the "filename" field in the POST body
              outputFilename: 'signed_document',

              // Optional branding in the signature pad dialog
              brandLogoUrl: 'https://www.w3.org/Icons/w3c_home.png',
              signatureTitle: 'Sign the Document',

              // true  → server returned HTTP 2xx
              // false → non-2xx response or network error
              onSaveComplete: (bool success) {
                setState(() => _uploadResult = success);
              },
            ),
          ),
        ],
      ),
    );
  }
}
