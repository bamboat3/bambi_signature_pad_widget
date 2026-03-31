# bambi_signature_pad_widget

A Flutter package that lets users view a PDF loaded from a URL, place one or more signature boxes anywhere on the document, draw their signature with a finger or mouse, and save the signed PDF to the device.

Designed to be used as a **FlutterFlow Custom Widget**.

---

## Features

- Loads PDF from any HTTP/HTTPS URL
- Split-pane layout — PDF viewer on the left, control panel on the right
- Click-and-drag to draw signature boxes anywhere on the PDF
- Signature pad dialog with finger/mouse drawing, pen colour picker, clear and cancel
- Custom brand logo (URL) and title inside the signature pad dialog
- Saves the signed PDF to the device's documents directory
- Returns `true` / `false` via callback so you can continue your DB logic

---

## Package info

| Field   | Value                       |
|---------|-----------------------------|
| Name    | `bambi_signature_pad_widget` |
| Version | `0.1.0`                     |

---

## Parameters

| Parameter        | Type     | Required | Description                                                         |
|------------------|----------|----------|---------------------------------------------------------------------|
| `pdfUrl`         | `String` | Yes      | HTTP(S) URL of the PDF to load and display                          |
| `outputFilename` | `String` | Yes      | File name to save the signed PDF as (`.pdf` is appended if missing) |
| `brandLogoUrl`   | `String` | No       | URL of a logo image shown in the signature pad header               |
| `signatureTitle` | `String` | No       | Custom title in the signature pad header (default: *Draw your signature*) |
| `onSaveComplete` | Action   | No       | FlutterFlow action called after save — read `signatureSaveResult` from App State to get `true`/`false` |

---

### Step 1 — Add the package as a dependency in FlutterFlow

1. Open your FlutterFlow project.
2. Click the **Settings** icon (gear ⚙️) in the left sidebar.
3. Go to **Pubspec Dependencies**.
4. Click **+ Add Dependency**.
5. Choose **Git** as the source.
6. Enter:
   - **URL:** `https://github.com/YOUR_USERNAME/bambi_signature_pad_widget.git`
   - **Ref:** `main` (or the commit SHA / tag you want to pin to)
7. Click **Save** and wait for FlutterFlow to resolve the dependency.

> **Tip — pub.dev alternative:** If you publish the package to pub.dev later, simply enter  
> `bambi_signature_pad_widget` as the package name and `0.1.0` as the version instead of using the git option.

---

### Step 2 — Add an App State variable for the save result

The widget returns `true` or `false` after saving. The cleanest way to read this in FlutterFlow is via an App State variable.

1. Go to **App State** (database icon in the left sidebar).
2. Click **+ Add Field**.
3. Set:
   - **Name:** `signatureSaveResult`
   - **Type:** `Boolean`
   - **Initial value:** `false`
4. Click **Save**.

---

### Step 3 — Create the Custom Widget

1. Go to **Custom Code** in the left sidebar.
2. Click **+ Add** → **Widget**.
3. Name it `BambiSignaturePad`.
4. Delete the placeholder code and paste the following:

```dart
// Automatic FlutterFlow imports
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/custom_code/widgets/index.dart';
import '/flutter_flow/custom_functions.dart';
import 'package:flutter/material.dart';
// Begin custom widget code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:bambi_signature_pad_widget/bambi_signature_pad_widget.dart';

class BambiSignaturePad extends StatefulWidget {
  const BambiSignaturePad({
    super.key,
    this.width,
    this.height,
    required this.pdfUrl,
    required this.outputFilename,
    this.brandLogoUrl,
    this.signatureTitle,
    this.onSaveComplete,
  });

  final double? width;
  final double? height;
  final String pdfUrl;
  final String outputFilename;
  final String? brandLogoUrl;
  final String? signatureTitle;
  final Future Function()? onSaveComplete;

  @override
  State<BambiSignaturePad> createState() => _BambiSignaturePadState();
}

class _BambiSignaturePadState extends State<BambiSignaturePad> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: PdfSignWidget(
        pdfUrl: widget.pdfUrl,
        outputFilename: widget.outputFilename,
        brandLogoUrl: widget.brandLogoUrl,
        signatureTitle: widget.signatureTitle,
        onSaveComplete: (bool success) async {
          // Write result to App State so FlutterFlow actions can read it
          FFAppState().update(() {
            FFAppState().signatureSaveResult = success;
          });
          // Trigger the FlutterFlow action chain
          await widget.onSaveComplete?.call();
        },
      ),
    );
  }
}
```

---

### Step 4 — Define the widget parameters in FlutterFlow

Still on the Custom Widget editor, scroll to the **Parameters** panel and add:

| Name               | Type    | Required |
|--------------------|---------|----------|
| `pdfUrl`           | String  | Yes      |
| `outputFilename`   | String  | Yes      |
| `brandLogoUrl`     | String  | No       |
| `signatureTitle`   | String  | No       |

Then in the **Actions** panel add one action callback:

| Name             | Type   |
|------------------|--------|
| `onSaveComplete` | Action |

Click **Save Widget**.

---

### Step 5 — Place the widget on a page

1. Open the page where you want to show the PDF signer.
2. In the widget tree, click **+** and search for `BambiSignaturePad`.
3. Drop it onto the page — set its **width** and **height** (e.g. fill the full screen).
4. In the **Properties** panel on the right, bind the parameters:

| Parameter        | Where to bind                                           |
|------------------|---------------------------------------------------------|
| `pdfUrl`         | A page variable, Firestore field, or hardcoded URL      |
| `outputFilename` | A page variable or hardcoded string e.g. `signed_form`  |
| `brandLogoUrl`   | Your company logo URL, or an App State / Firestore field |
| `signatureTitle` | Hardcoded text e.g. `Sign the Employment Contract`      |

---

### Step 6 — Handle the save result with an action

1. In **Properties → Actions**, click **+ Add Action** next to `onSaveComplete`.
2. Add a **Conditional Action**:
   - **Condition:** `signatureSaveResult` (App State) `== true`
   - **True branch:** your DB write logic (e.g. update Firestore, show success snackbar, navigate to next page)
   - **False branch:** show an error snackbar or retry prompt

---

## Dart / non-FlutterFlow usage

```dart
import 'package:bambi_signature_pad_widget/bambi_signature_pad_widget.dart';

PdfSignWidget(
  pdfUrl: 'https://example.com/contract.pdf',
  outputFilename: 'signed_contract',
  brandLogoUrl: 'https://example.com/logo.png',
  signatureTitle: 'Sign the Contract',
  onSaveComplete: (bool success) {
    if (success) {
      // proceed with DB logic
    } else {
      // handle error
    }
  },
)
```

---

## Dependencies

| Package                        | Version  | Purpose                         |
|--------------------------------|----------|---------------------------------|
| `syncfusion_flutter_pdfviewer` | ^32.2.5  | PDF rendering and viewer        |
| `syncfusion_flutter_pdf`       | ^32.2.5  | Embed signature images into PDF |
| `path_provider`                | ^2.1.5   | Resolve device documents path   |
| `uuid`                         | ^4.3.3   | Unique IDs for signature boxes  |
| `http`                         | ^1.2.0   | Download PDF from URL           |

> **Syncfusion licence:** Syncfusion packages are free for companies with revenue under $1 million USD/year. See [syncfusion.com/products/communitylicense](https://www.syncfusion.com/products/communitylicense).

---

## Saved file location

The signed PDF is saved to the **app documents directory** with the name you pass as `outputFilename`. On each platform:

| Platform | Path                                            |
|----------|-------------------------------------------------|
| Android  | `/data/data/<app>/files/<outputFilename>.pdf`   |
| iOS      | `<app>/Documents/<outputFilename>.pdf`          |
| Windows  | `C:\Users\<user>\Documents\<outputFilename>.pdf` |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| PDF fails to load | Check the URL is publicly accessible and returns `Content-Type: application/pdf` |
| Logo not showing in signature pad | Verify `brandLogoUrl` is a direct image URL (not a redirect). A broken URL silently falls back to the pen icon |
| `onSaveComplete` never fires | Make sure `signatureSaveResult` App State field exists and is of type Boolean |
| Dependency not found in FlutterFlow | Re-check the GitHub repo URL and that `pubspec.yaml` name is exactly `bambi_signature_pad_widget` |
