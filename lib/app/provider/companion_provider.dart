import 'package:flutter/foundation.dart';
import 'package:bb/app/provider/hardware_monitor_provider.dart';

enum CompanionMood {
  waiting,
  chill,
  busy,
  overheated,
  sleepy,
  hungry,
  bored,
  relieved,
}

class CompanionProvider extends ChangeNotifier {
  CompanionProvider(this._hardwareProvider) {
    _hardwareProvider.addListener(_handleHardwareChanged);
    _syncFromHardware();
  }

  final HardwareMonitorProvider _hardwareProvider;

  CompanionMood _mood = CompanionMood.waiting;
  CompanionMood _previousMood = CompanionMood.waiting;
  DateTime? _lastMoodChangedAt;

  // --- Bored: tracks how long CPU has been idle ---
  DateTime? _idleSince;
  static const _boredThresholdMinutes = 5;
  static const _boredCpuThreshold = 15.0;

  // --- Relieved: duration after crisis clears ---
  static const _relievedDurationSeconds = 30;
  static const _crisisMoods = {
    CompanionMood.overheated,
    CompanionMood.hungry,
  };

  CompanionMood get mood => _mood;
  CompanionMood get previousMood => _previousMood;
  DateTime? get lastMoodChangedAt => _lastMoodChangedAt;

  bool get isWaiting    => _mood == CompanionMood.waiting;
  bool get isChill      => _mood == CompanionMood.chill;
  bool get isBusy       => _mood == CompanionMood.busy;
  bool get isOverheated => _mood == CompanionMood.overheated;
  bool get isSleepy     => _mood == CompanionMood.sleepy;
  bool get isHungry     => _mood == CompanionMood.hungry;
  bool get isBored      => _mood == CompanionMood.bored;
  bool get isRelieved   => _mood == CompanionMood.relieved;

  String get moodKey => _mood.name;

  String get message {
    switch (_mood) {
      case CompanionMood.sleepy:
        return 'Battery is low, ByteBuddy wants a charger.';
      case CompanionMood.overheated:
        return 'System is toasty. Time to cool things down.';
      case CompanionMood.hungry:
        return 'RAM is nearly full. ByteBuddy is starving for memory.';
      case CompanionMood.busy:
        return 'Your machine is hustling right now.';
      case CompanionMood.relieved:
        return 'Phew! Crisis over. ByteBuddy is catching its breath.';
      case CompanionMood.bored:
        return 'Nothing to do... ByteBuddy is twiddling its bits.';
      case CompanionMood.chill:
        return 'Everything feels smooth and balanced.';
      case CompanionMood.waiting:
        return 'Waiting for the first health check.';
    }
  }

  String get face {
    switch (_mood) {
      case CompanionMood.sleepy:    return '(-.-)Zzz';
      case CompanionMood.overheated: return '(o_o;)';
      case CompanionMood.hungry:    return '(@_@)';
      case CompanionMood.busy:      return '(>_<)';
      case CompanionMood.relieved:  return "(^_^')";
      case CompanionMood.bored:     return '(-_-)';
      case CompanionMood.chill:     return '(^_^)';
      case CompanionMood.waiting:   return '(._.)';
    }
  }

  String get animationKey {
    switch (_mood) {
      case CompanionMood.sleepy:     return 'sleep';
      case CompanionMood.overheated: return 'panic';
      case CompanionMood.hungry:     return 'hungry';
      case CompanionMood.busy:       return 'work';
      case CompanionMood.relieved:   return 'relieved';
      case CompanionMood.bored:      return 'bored';
      case CompanionMood.chill:      return 'idle';
      case CompanionMood.waiting:    return 'waiting';
    }
  }

  Map<String, dynamic> get stats => _hardwareProvider.stats;

  double? get cpuUsage =>
      (_hardwareProvider.stats['cpuUsage'] as num?)?.toDouble();

  int? get batteryLevel =>
      (_hardwareProvider.stats['batteryLevel'] as num?)?.toInt();

  int? get memoryUsage =>
      (_hardwareProvider.stats['memoryUsage'] as num?)?.toInt();

  int? get fanSpeed =>
      (_hardwareProvider.stats['fanSpeed'] as num?)?.toInt();

  double? get cpuTemperature =>
      ((_hardwareProvider.stats['cpuTemperature'] as num?) ??
          (_hardwareProvider.stats['cpuTemp'] as num?))
          ?.toDouble();

  bool get hasStats       => _hardwareProvider.hasStats;
  bool get isHardwareLoading => _hardwareProvider.isLoading;
  String? get hardwareError  => _hardwareProvider.error;

  void _handleHardwareChanged() => _syncFromHardware();

  void _syncFromHardware() {
    _updateIdleTracker();
    final nextMood = _resolveMood();

    if (nextMood != _mood) {
      _previousMood = _mood;
      _mood = nextMood;
      _lastMoodChangedAt = DateTime.now();
    }

    notifyListeners();
  }

  void _updateIdleTracker() {
    final cpu = cpuUsage ?? 0;
    if (cpu < _boredCpuThreshold) {
      _idleSince ??= DateTime.now();
    } else {
      _idleSince = null;
    }
  }

  CompanionMood _resolveMood() {
    final currentStats = _hardwareProvider.stats;
    if (currentStats.isEmpty) return CompanionMood.waiting;

    final battery  = batteryLevel ?? 100;
    final cpu      = cpuUsage ?? 0;
    final temp     = cpuTemperature ?? 0;
    final ram      = memoryUsage ?? 0;
    final now      = DateTime.now();

    // Sleepy — battery critical
    if (battery <= 15) return CompanionMood.sleepy;

    // Overheated — thermal / CPU meltdown
    if (temp >= 80 || cpu >= 85) return CompanionMood.overheated;

    // Hungry — RAM overloaded
    // memoryUsage comes in as MB; 80% of 16 GB = 13107 MB
    final ramPercent = (ram / 16384 * 100).clamp(0, 100);
    if (ramPercent >= 80) return CompanionMood.hungry;

    // Busy — elevated CPU
    if (cpu >= 60) return CompanionMood.busy;

    // Relieved — recovering from a crisis mood within the window
    final wasCrisis = _crisisMoods.contains(_previousMood);
    final sinceChange = _lastMoodChangedAt != null
        ? now.difference(_lastMoodChangedAt!).inSeconds
        : 999;
    if (wasCrisis && sinceChange < _relievedDurationSeconds) {
      return CompanionMood.relieved;
    }

    // Bored — CPU has been idle for long enough
    if (_idleSince != null) {
      final idleMinutes = now.difference(_idleSince!).inMinutes;
      if (idleMinutes >= _boredThresholdMinutes) return CompanionMood.bored;
    }

    // 7. Default
    return CompanionMood.chill;
  }

  @override
  void dispose() {
    _hardwareProvider.removeListener(_handleHardwareChanged);
    super.dispose();
  }
}