import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bb/app/repository/hardware_monitor_repository.dart';

class HardwareMonitorProvider extends ChangeNotifier {
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;
  String? _error;

  // Stream subscription replaces the old polling Timer
  StreamSubscription<Map<String, dynamic>>? _streamSubscription;

  // ─────────────────────────────────────────────
  // Getters
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // Companion state
  // ─────────────────────────────────────────────
  String get companionMood {
    if (_stats.isEmpty) return 'waiting';
    if ((batteryLevel ?? 100) <= 15) return 'sleepy';
    if ((cpuTemperature ?? 0) >= 80 || (cpuUsage ?? 0) >= 85) {
      return 'overheated';
    }
    if ((cpuUsage ?? 0) >= 60) return 'busy';
    return 'chill';
  }

  String get companionMessage {
    switch (companionMood) {
      case 'sleepy':
        return 'Battery is low, ByteBuddy wants a charger.';
      case 'overheated':
        return 'System is toasty. Time to cool things down.';
      case 'busy':
        return 'Your machine is hustling right now.';
      case 'chill':
        return 'Everything feels smooth and balanced.';
      default:
        return 'Waiting for the first health check.';
    }
  }

  String get companionFace {
    switch (companionMood) {
      case 'sleepy':
        return '(-.-)Zzz';
      case 'overheated':
        return '(o_o;)';
      case 'busy':
        return '(>_<)';
      case 'chill':
        return '(^_^)';
      default:
        return '(._.)';
    }
  }

  // ─────────────────────────────────────────────
  // Stream lifecycle
  // ─────────────────────────────────────────────

  /// Start listening to the native EventChannel stream.
  /// [intervalMs] controls how often native pushes a new snapshot.
  void startMonitoring({int intervalMs = 2000}) {
    stopMonitoring(); // cancel any existing subscription first

    _isLoading = true;
    _error = null;
    notifyListeners();

    _streamSubscription = HardwareMonitor.statsStream(intervalMs: intervalMs)
        .listen(
          _onStatsReceived,
          onError: _onStreamError,
          cancelOnError: false, // keep stream alive on transient errors
        );
  }

  void stopMonitoring() {
    _streamSubscription?.cancel();
    _streamSubscription = null;
  }

  // ─────────────────────────────────────────────
  // On-demand fetches (MethodChannel — still available)
  // ─────────────────────────────────────────────

  /// Fetch all stats in one call.
  Future<void> fetchSystemStats() async {
    await _fetchOnce(useCombinedEndpoint: true);
  }

  /// Fetch each stat individually and merge.
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

  // ─────────────────────────────────────────────
  // Stream callbacks
  // ─────────────────────────────────────────────
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

  // ─────────────────────────────────────────────
  // Dispose
  // ─────────────────────────────────────────────
  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
