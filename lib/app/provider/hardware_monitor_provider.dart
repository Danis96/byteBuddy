import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bb/app/repository/hardware_monitor_repository.dart';

class HardwareMonitorProvider extends ChangeNotifier {
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;

  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  Map<String, dynamic> get stats => _stats;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasStats => _stats.isNotEmpty;

  double? get cpuUsage => (_stats['cpuUsage'] as num?)?.toDouble();
  int? get batteryLevel => (_stats['batteryLevel'] as num?)?.toInt();
  int? get memoryUsage => (_stats['memoryUsage'] as num?)?.toInt();
  int? get fanSpeed => (_stats['fanSpeed'] as num?)?.toInt();
  double? get cpuTemperature =>
      (_stats['cpuTemperature'] as num? ?? _stats['cpuTemp'] as num?)
          ?.toDouble();
  double? get cpuTemp => cpuTemperature;

  void startMonitoring({int intervalMs = 2000}) {
    stopMonitoring();

    _isLoading = true;
    _error = null;
    notifyListeners();

    _streamSubscription = HardwareMonitor.statsStream(intervalMs: intervalMs)
        .listen(
      _onStatsReceived,
      onError: _onStreamError,
      cancelOnError: false,
    );
  }

  void stopMonitoring() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  Future<void> fetchSystemStats() async {
    await _fetchOnce(useCombinedEndpoint: true);
  }

  Future<void> refreshStats({bool useCombinedEndpoint = false}) async {
    await _fetchOnce(useCombinedEndpoint: useCombinedEndpoint);
  }

  Future<void> _fetchOnce({bool useCombinedEndpoint = false}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final result = useCombinedEndpoint
          ? await HardwareMonitor.getSystemStats()
          : await _fetchIndividualStats();

      if (result.isEmpty) {
        _error = 'No hardware stats were returned.';
      } else {
        _stats = {..._stats, ...result};
      }
    } catch (e, st) {
      _error = 'Failed to fetch system stats.';
      debugPrint('HardwareMonitorProvider error: $e');
      debugPrintStack(stackTrace: st);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>> _fetchIndividualStats() async {
    final results = await Future.wait([
      HardwareMonitor.getCpuUsage(),
      HardwareMonitor.getBatteryLevel(),
      HardwareMonitor.getMemoryUsage(),
      HardwareMonitor.getFanSpeed(),
      HardwareMonitor.getCpuTemperature(),
    ]);
    return {for (final r in results) ...r};
  }

  void _onStatsReceived(Map<String, dynamic> incoming) {
    _stats = {..._stats, ...incoming};
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  void _onStreamError(Object error, StackTrace st) {
    _error = 'Stream error: $error';
    _isLoading = false;
    debugPrint('HardwareMonitorProvider stream error: $error');
    debugPrintStack(stackTrace: st);
    notifyListeners();
  }

  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}