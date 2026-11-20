import 'package:flutter/services.dart';

abstract interface class AccessibilityShortcutClient {
  void setShortcutRequestHandler(VoidCallback? handler);

  Future<bool> consumePendingShortcut();

  Future<void> openAccessibilitySettings();

  Future<void> openAppSettings();
}

class MethodChannelAccessibilityShortcutClient
    implements AccessibilityShortcutClient {
  static const MethodChannel _defaultChannel = MethodChannel(
    'dailybrief/accessibility_shortcut',
  );

  final MethodChannel _channel;

  MethodChannelAccessibilityShortcutClient({MethodChannel? channel})
    : _channel = channel ?? _defaultChannel;

  @override
  void setShortcutRequestHandler(VoidCallback? handler) {
    _channel.setMethodCallHandler(
      handler == null
          ? null
          : (call) async {
              if (call.method == 'shortcutRequested') handler();
              return null;
            },
    );
  }

  @override
  Future<bool> consumePendingShortcut() async =>
      await _channel.invokeMethod<bool>('consumePendingShortcut') ?? false;

  @override
  Future<void> openAccessibilitySettings() =>
      _channel.invokeMethod<void>('openAccessibilitySettings');

  @override
  Future<void> openAppSettings() =>
      _channel.invokeMethod<void>('openAppSettings');
}
