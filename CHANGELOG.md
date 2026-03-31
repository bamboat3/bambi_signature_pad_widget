## 0.3.0

* Added `uploadUrl` parameter — signed PDF is POSTed to your API as multipart/form-data with `filename` and `file` fields instead of saving locally
* Built-in Wacom STU tablet support via internal singleton (`DefaultWacomAdapter`) — no adapter wiring needed by the caller
* Signature pad dialog redesigned with fully centred layout
* Wacom connection indicator added to the right control panel
* Example app updated to reflect all new parameters

## 0.2.0

* Added `brandLogoUrl` parameter — display a custom logo in the signature pad header
* Added `signatureTitle` parameter — display a custom title in the signature pad header
* Improved public API dartdoc coverage
* Added example app

## 0.1.0

* Initial release
* PDF viewer loaded from a URL with split-pane layout
* Click-and-drag signature box placement on any page
* Finger/mouse signature pad dialog with pen colour picker
* Custom brand logo URL and title in the signature pad header
* Saves signed PDF to the app documents directory
* Returns true/false via callback for downstream DB logic
* Designed for use as a FlutterFlow custom widget
