import 'package:bambi_signature_pad_widget/bambi_signature_pad_widget.dart';
import 'package:flutter/material.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Signature Pad Example',
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
  bool? _saveResult;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Result banner
          if (_saveResult != null)
            MaterialBanner(
              content: Text(
                _saveResult!
                    ? 'Document saved successfully!'
                    : 'Save failed — please try again.',
              ),
              backgroundColor:
                  _saveResult! ? Colors.green.shade50 : Colors.red.shade50,
              actions: [
                TextButton(
                  onPressed: () => setState(() => _saveResult = null),
                  child: const Text('Dismiss'),
                ),
              ],
            ),

          // Widget takes up remaining space
          Expanded(
            child: PdfSignWidget(
              pdfUrl: 'https://www.w3.org/WAI/WCAG21/wcag-2.1.pdf',
              outputFilename: 'signed_document',
              brandLogoUrl: 'https://www.w3.org/Icons/w3c_home.png',
              signatureTitle: 'Sign the Document',
              onSaveComplete: (bool success) {
                setState(() => _saveResult = success);
              },
            ),
          ),
        ],
      ),
    );
  }
}
