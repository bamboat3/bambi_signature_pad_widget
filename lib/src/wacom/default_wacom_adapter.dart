import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'wacom_adapter.dart';

/// Internal singleton implementation of [WacomAdapter].
///
/// Communicates with the native Wacom STU plugin via the platform channels
/// `wacom_stu_channel` (MethodChannel) and `wacom_stu_events` (EventChannel).
/// The native side is provided by the `wacom_stu_plugin` in the host app.
///
/// Only one instance ever exists — guaranteed by the private constructor and
/// the static [instance] field. Any part of the package that calls
/// [DefaultWacomAdapter.instance] receives the same object, so connection
/// state is shared and there is never more than one active device session.
class DefaultWacomAdapter extends WacomAdapter {
  DefaultWacomAdapter._();

  /// The single shared instance.
  static final DefaultWacomAdapter instance = DefaultWacomAdapter._();

  static const MethodChannel _method = MethodChannel('wacom_stu_channel');
  static const EventChannel  _event  = EventChannel('wacom_stu_events');

  bool _connected = false;
  Map<String, dynamic>? _caps;

  // Lazily created, broadcast, and reused for the lifetime of the singleton.
  late final Stream<Map<String, dynamic>> _penStream =
      _event.receiveBroadcastStream().map<Map<String, dynamic>>((event) {
    if (event is Map) {
      return {
        'x':        (event['x']        as num).toDouble(),
        'y':        (event['y']        as num).toDouble(),
        'pressure': (event['pressure'] as num).toDouble(),
        'sw':       event['sw'] as int,
      };
    }
    throw Exception('WacomAdapter: invalid pen event format');
  });

  @override
  bool get isConnected => _connected;

  @override
  Map<String, dynamic>? get capabilities => _caps;

  @override
  Stream<Map<String, dynamic>> get penEvents => _penStream;

  @override
  Future<void> connect() async {
    if (_connected) return; // already connected — no new instance
    try {
      final result = await _method.invokeMethod<Map>('connect');
      if (result != null) {
        _caps = {
          'maxX':         (result['maxX']         as num).toDouble(),
          'maxY':         (result['maxY']         as num).toDouble(),
          'screenWidth':  (result['screenWidth']  as num?)?.toDouble() ?? 800.0,
          'screenHeight': (result['screenHeight'] as num?)?.toDouble() ?? 480.0,
        };
        _connected = true;
        notifyListeners();
      }
    } on PlatformException catch (e) {
      throw Exception('Wacom connect failed: ${e.message}');
    }
  }

  @override
  Future<void> disconnect() async {
    if (!_connected) return;
    try {
      await _method.invokeMethod('disconnect');
    } on PlatformException catch (e) {
      debugPrint('Wacom disconnect error: ${e.message}');
    } finally {
      _connected = false;
      _caps = null;
      notifyListeners();
    }
  }

  @override
  Future<void> setScreen(Uint8List rgbBytes, int mode) async {
    try {
      await _method.invokeMethod('setSignatureScreen', {
        'data': rgbBytes,
        'mode': mode,
      });
    } catch (e) {
      debugPrint('Wacom setScreen error: $e');
    }
  }

  @override
  Future<void> clearScreen() async {
    try {
      await _method.invokeMethod('clearScreen');
    } catch (e) {
      debugPrint('Wacom clearScreen error: $e');
    }
  }
}
