import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class HardwareMonitor {
  static const _methodChannel = MethodChannel('com.bytebuddy/hardware_stats');

  static const _eventChannel = EventChannel('com.bytebuddy/hardware_stats_stream');

  static Stream<Map<String, dynamic>> statsStream({int intervalMs = 2000}) {
    return _eventChannel
        .receiveBroadcastStream(intervalMs)
        .map((event) => Map<String, dynamic>.from(event as Map));
  }

  static Future<Map<String, dynamic>> getSystemStats() =>
      _invokeMapMethod('getSystemStats');

  static Future<Map<String, dynamic>> getCpuUsage() =>
      _invokeMapMethod('getCpuUsage');

  static Future<Map<String, dynamic>> getBatteryLevel() =>
      _invokeMapMethod('getBatteryLevel');

  static Future<Map<String, dynamic>> getMemoryUsage() =>
      _invokeMapMethod('getMemoryUsage');

  static Future<Map<String, dynamic>> getFanSpeed() =>
      _invokeMapMethod('getFanSpeed');

  static Future<Map<String, dynamic>> getCpuTemperature() =>
      _invokeMapMethod('getCpuTemperature');

  static Future<Map<String, dynamic>> getCpuTemp() => getCpuTemperature();

  static Future<Map<String, dynamic>> _invokeMapMethod(String method) async {
    try {
      final result = await _methodChannel.invokeMethod(method);
      if (result == null) return {};
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint("HardwareMonitor: '$method' failed — ${e.message}");
      return {};
    }
  }
}
