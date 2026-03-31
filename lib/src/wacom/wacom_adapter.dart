import 'package:flutter/foundation.dart';

/// Abstract interface for Wacom STU tablet integration.
///
/// Extend this class in your app using your `wacom_stu_plugin`,
/// then pass the instance to [PdfSignWidget.wacomAdapter].
///
/// The widget listens to this object as a [ChangeNotifier], so call
/// [notifyListeners] whenever [isConnected] or [capabilities] change.
///
/// ### Minimal implementation example
/// ```dart
/// class MyWacomAdapter extends WacomAdapter {
///   final _service = WacomService();
///   bool _connected = false;
///   Map<String, dynamic>? _caps;
///
///   @override bool get isConnected => _connected;
///   @override Map<String, dynamic>? get capabilities => _caps;
///   @override Stream<Map<String, dynamic>> get penEvents => _service.penEvents;
///
///   @override
///   Future<void> connect() async {
///     _caps = await _service.connect();
///     _connected = true;
///     notifyListeners();
///   }
///
///   @override
///   Future<void> disconnect() async {
///     await _service.disconnect();
///     _connected = false;
///     _caps = null;
///     notifyListeners();
///   }
///
///   @override
///   Future<void> setScreen(Uint8List rgbBytes, int mode) =>
///       _service.setSignatureScreen(rgbBytes, mode);
///
///   @override
///   Future<void> clearScreen() => _service.clearScreen();
/// }
/// ```
abstract class WacomAdapter extends ChangeNotifier {
  /// Whether the tablet is currently connected.
  bool get isConnected;

  /// Device capabilities returned after a successful [connect] call.
  ///
  /// Expected keys:
  /// - `screenWidth`  – tablet display width in pixels (double)
  /// - `screenHeight` – tablet display height in pixels (double)
  /// - `maxX`         – maximum raw pen X coordinate (double)
  /// - `maxY`         – maximum raw pen Y coordinate (double)
  Map<String, dynamic>? get capabilities;

  /// Broadcast stream of raw pen events from the tablet.
  ///
  /// Each event map must contain:
  /// - `x`        – double, raw pen X coordinate
  /// - `y`        – double, raw pen Y coordinate
  /// - `pressure` – double, pen pressure (0 = lifted)
  /// - `sw`       – int,    side-switch state
  Stream<Map<String, dynamic>> get penEvents;

  /// Attempts to connect to the Wacom tablet.
  /// Must call [notifyListeners] after updating [isConnected].
  Future<void> connect();

  /// Disconnects the Wacom tablet.
  /// Must call [notifyListeners] after updating [isConnected].
  Future<void> disconnect();

  /// Sends a raw 24-bit BGR image to the tablet display.
  /// [mode] is typically `4` for 24-bit colour.
  Future<void> setScreen(Uint8List rgbBytes, int mode);

  /// Clears the tablet display.
  Future<void> clearScreen();
}
