import 'package:flutter/services.dart';

/// 无边框窗口的标题栏控制（调用 Windows 原生窗口控制）。
class WindowController {
  static const _channel = MethodChannel('ffconverter/window');

  static Future<void> close() => _channel.invokeMethod('close');
  static Future<void> minimize() => _channel.invokeMethod('minimize');
  static Future<void> maximize() => _channel.invokeMethod('maximize');
  static Future<bool> isMaximized() async =>
      (await _channel.invokeMethod<bool>('isMaximized')) ?? false;
  static Future<void> startDrag() => _channel.invokeMethod('drag');
}
