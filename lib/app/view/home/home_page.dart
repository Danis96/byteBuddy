import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../provider/hardware_monitor_provider.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TrayListener {
  static const _windowSize = Size(596, 768);
  HardwareMonitorProvider? _monitor;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    _setupTray();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _monitor = context.read<HardwareMonitorProvider>();
      _monitor?.startMonitoring();
    });
  }

  Future<void> _setupTray() async {
    await trayManager.setIcon('assets/images/app_tray_icon.png');
    await trayManager.setToolTip('ByteBuddy');
  }

  @override
  void onTrayIconMouseDown() async {
    await _toggleWindow();
  }

  Future<void> _toggleWindow() async {
    final isVisible = await windowManager.isVisible();

    if (isVisible) {
      await windowManager.hide();
      return;
    }

    final mousePosition = await screenRetriever.getCursorScreenPoint();
    final adjustedPosition = Offset(
      mousePosition.dx - (_windowSize.width / 2),
      mousePosition.dy + 14,
    );

    await windowManager.setSize(_windowSize);
    await windowManager.setPosition(adjustedPosition);
    await windowManager.show();
    await windowManager.focus();
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    _monitor?.stopMonitoring();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<HardwareMonitorProvider>(
      builder: (context, monitor, child) {
        final statusColor = _statusColor(monitor.companionMood);

        return Scaffold(
          backgroundColor: const Color(0xFF1D2438),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;
              final compact = width < 520;
              final narrow = width < 430;
              final columns = width >= 760 ? 3 : (compact ? 1 : 2);
              final shellPadding = width < 440 ? 14.0 : 20.0;
              final orbSize = narrow ? 92.0 : (width < 620 ? 108.0 : 114.0);
              final gridAspectRatio = columns == 1 ? 1.9 : (width > 700 ? 1.28 : 1.42);
              final horizontalInset = width < 380 ? 10.0 : 14.0;
              final spacing = width < 420 ? 12.0 : 14.0;
              final allowScroll = height < 760 || columns == 1;

              final cards = [
                _MetricCard(
                  color: const Color(0xFF4F7EFF),
                  icon: Icons.memory_rounded,
                  value: _formatPercent(monitor.cpuUsage),
                  label: 'CPU USAGE',
                  progress: _safeUnit((monitor.cpuUsage ?? 0) / 100),
                  ringLabel: _formatCompactPercent(monitor.cpuUsage),
                  compact: narrow,
                ),
                _MetricCard(
                  color: const Color(0xFFFFB133),
                  icon: Icons.battery_5_bar_rounded,
                  value: _formatBattery(monitor.batteryLevel),
                  label: 'BATTERY',
                  progress: _safeUnit((monitor.batteryLevel ?? 0) / 100),
                  ringLabel: _formatCompactBattery(monitor.batteryLevel),
                  compact: narrow,
                ),
                _MetricCard(
                  color: const Color(0xFF58D68D),
                  icon: Icons.storage_rounded,
                  value: _formatMemory(monitor.memoryUsage),
                  label: 'MEMORY',
                  progress: _memoryProgress(monitor.memoryUsage),
                  ringLabel: _formatMemoryPercent(monitor.memoryUsage),
                  compact: narrow,
                ),
                _MetricCard(
                  color: const Color(0xFFB05BFF),
                  icon: Icons.mode_fan_off_rounded,
                  value: _formatFanValue(monitor.fanSpeed),
                  label: 'FAN SPEED',
                  progress: _fanProgress(monitor.fanSpeed),
                  ringLabel: _formatFanPercent(monitor.fanSpeed),
                  compact: narrow,
                ),
                _MetricCard(
                  color: const Color(0xFFFF5D73),
                  icon: Icons.device_thermostat_rounded,
                  value: _formatTemperature(monitor.cpuTemp),
                  label: 'TEMPERATURE',
                  progress: _tempProgress(monitor.cpuTemp),
                  ringLabel: _formatTempPercent(monitor.cpuTemp),
                  compact: narrow,
                ),
                _MetricCard(
                  color: const Color(0xFF58D7FF),
                  icon: Icons.wifi_tethering_rounded,
                  value: monitor.error == null ? 'Active' : 'Issue',
                  label: 'CONNECTION',
                  progress: monitor.error == null ? 1 : 0.24,
                  ringLabel: monitor.error == null ? '100%' : '24%',
                  subtitle: monitor.error,
                  compact: narrow,
                ),
              ];

              Widget content = Column(
                children: [
                  _StatusBanner(
                    title: monitor.companionMood.toUpperCase(),
                    message: monitor.companionMessage,
                    color: statusColor,
                    isLoading: monitor.isLoading,
                    onRefresh: monitor.refreshStats,
                    onHide: windowManager.hide,
                    compact: compact,
                  ),
                  SizedBox(height: compact ? 18 : 22),
                  _BuddyOrb(color: statusColor, size: orbSize),
                  SizedBox(height: compact ? 18 : 24),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: cards.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      childAspectRatio: gridAspectRatio,
                      mainAxisSpacing: spacing,
                      crossAxisSpacing: spacing,
                    ),
                    itemBuilder: (context, index) => cards[index],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    height: 1,
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Monitoring system health in real-time · Updated every 2 seconds',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.28),
                      fontWeight: FontWeight.w700,
                      fontSize: compact ? 11 : 12,
                    ),
                  ),
                ],
              );

              if (allowScroll) {
                content = SingleChildScrollView(child: content);
              }

              return Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF20283D), Color(0xFF1B2337)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
                child: SafeArea(
                  minimum: EdgeInsets.all(horizontalInset),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF20283D),
                      borderRadius: BorderRadius.circular(compact ? 22 : 28),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        shellPadding,
                        compact ? 16 : 18,
                        shellPadding,
                        compact ? 16 : 18,
                      ),
                      child: allowScroll
                          ? content
                          : SizedBox.expand(child: content),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _statusColor(String mood) {
    switch (mood) {
      case 'sleepy':
        return const Color(0xFFFFB133);
      case 'overheated':
        return const Color(0xFFFF5D73);
      case 'busy':
        return const Color(0xFFB05BFF);
      case 'chill':
        return const Color(0xFF58D7FF);
      default:
        return const Color(0xFF58D7FF);
    }
  }

  String _formatPercent(double? value) {
    if (value == null || value < 0) {
      return '--';
    }
    return '${value.toStringAsFixed(1)}%';
  }

  String _formatCompactPercent(double? value) {
    if (value == null || value < 0) {
      return '--';
    }
    return '${value.round()}%';
  }

  String _formatBattery(int? value) {
    if (value == null || value < 0) {
      return '--';
    }
    return '$value%';
  }

  String _formatCompactBattery(int? value) {
    if (value == null || value < 0) {
      return '--';
    }
    return '$value%';
  }

  String _formatMemory(int? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    final gb = value / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  String _formatMemoryPercent(int? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return '${(_memoryProgress(value) * 100).round()}%';
  }

  String _formatFanValue(int? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return '$value';
  }

  String _formatFanPercent(int? value) {
    if (value == null || value <= 0) {
      return '--';
    }
    return '${(_fanProgress(value) * 100).round()}%';
  }

  String _formatTemperature(double? value) {
    if (value == null || value < 0) {
      return '--';
    }
    return '${value.toStringAsFixed(1)}°C';
  }

  String _formatTempPercent(double? value) {
    if (value == null || value < 0) {
      return '--';
    }
    return '${(_tempProgress(value) * 100).round()}%';
  }

  double _memoryProgress(int? value) {
    if (value == null || value <= 0) {
      return 0;
    }
    return _safeUnit(value / 16384);
  }

  double _fanProgress(int? value) {
    if (value == null || value <= 0) {
      return 0;
    }
    return _safeUnit(value / 5000);
  }

  double _tempProgress(double? value) {
    if (value == null || value < 0) {
      return 0;
    }
    return _safeUnit(value / 100);
  }

  double _safeUnit(num value) {
    return value.clamp(0, 1).toDouble();
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.title,
    required this.message,
    required this.color,
    required this.isLoading,
    required this.onRefresh,
    required this.onHide,
    required this.compact,
  });

  final String title;
  final String message;
  final Color color;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onHide;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 14 : 16, compact ? 14 : 16, compact ? 14 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF284A6B), Color(0xFF2B3F66)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFF45C9FF).withValues(alpha: 0.55)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.24),
            blurRadius: 18,
            spreadRadius: 1,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _BannerStatusIcon(compact: compact),
                    const SizedBox(width: 12),
                    Expanded(child: _BannerText(title: title, message: message, compact: compact)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    _BannerButton(
                      icon: isLoading ? null : Icons.refresh_rounded,
                      isLoading: isLoading,
                      onTap: isLoading ? null : onRefresh,
                    ),
                    const SizedBox(width: 8),
                    _BannerButton(
                      icon: Icons.close_rounded,
                      isLoading: false,
                      onTap: onHide,
                    ),
                  ],
                ),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _BannerStatusIcon(compact: compact),
                const SizedBox(width: 14),
                Expanded(
                  child: _BannerText(title: title, message: message, compact: compact),
                ),
                const SizedBox(width: 12),
                Column(
                  children: [
                    _BannerButton(
                      icon: isLoading ? null : Icons.refresh_rounded,
                      isLoading: isLoading,
                      onTap: isLoading ? null : onRefresh,
                    ),
                    const SizedBox(height: 8),
                    _BannerButton(
                      icon: Icons.close_rounded,
                      isLoading: false,
                      onTap: onHide,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _BannerStatusIcon extends StatelessWidget {
  const _BannerStatusIcon({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final size = compact ? 24.0 : 28.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD9F7FF), width: 2),
      ),
      child: Icon(
        Icons.check_rounded,
        size: compact ? 16 : 18,
        color: const Color(0xFFD9F7FF),
      ),
    );
  }
}

class _BannerText extends StatelessWidget {
  const _BannerText({
    required this.title,
    required this.message,
    required this.compact,
  });

  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: const Color(0xFFDFF9FF),
            fontWeight: FontWeight.w900,
            letterSpacing: 0.2,
            fontSize: compact ? 18 : 20,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$message Polling every few seconds from the native desktop layer.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.72),
            fontWeight: FontWeight.w700,
            height: 1.3,
            fontSize: compact ? 13 : null,
          ),
        ),
      ],
    );
  }
}

class _BuddyOrb extends StatelessWidget {
  const _BuddyOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dotSize = size * 0.08;
    final eyeGap = size * 0.16;
    final mouthWidth = size * 0.22;
    final mouthHeight = size * 0.09;

    return Center(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [Color(0xFF304968), Color(0xFF273B56)],
            radius: 0.95,
          ),
          border: Border.all(
            color: const Color(0xFF45C9FF).withValues(alpha: 0.65),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.32),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _FaceDot(size: dotSize),
                SizedBox(width: eyeGap),
                _FaceDot(size: dotSize),
              ],
            ),
            SizedBox(height: size * 0.12),
            _SmileLine(width: mouthWidth, height: mouthHeight),
          ],
        ),
      ),
    );
  }
}

class _FaceDot extends StatelessWidget {
  const _FaceDot({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF9BE9C4),
      ),
    );
  }
}

class _SmileLine extends StatelessWidget {
  const _SmileLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFF9BE9C4), width: 3),
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.color,
    required this.icon,
    required this.value,
    required this.label,
    required this.progress,
    required this.ringLabel,
    required this.compact,
    this.subtitle,
  });

  final Color color;
  final IconData icon;
  final String value;
  final String label;
  final double progress;
  final String ringLabel;
  final bool compact;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final ringSize = compact ? 76.0 : 88.0;

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 14 : 18, compact ? 14 : 18, compact ? 14 : 18, compact ? 12 : 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.18),
            color.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.10),
            blurRadius: 16,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _RingGauge(
                  color: color,
                  icon: icon,
                  progress: progress,
                  label: ringLabel,
                  size: ringSize,
                  compact: compact,
                ),
                SizedBox(width: compact ? 12 : 16),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: compact ? 20 : 23,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: compact ? 4 : 6),
                      Text(
                        label,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.56),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          fontSize: compact ? 12 : null,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          subtitle!,
                          maxLines: compact ? 1 : 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.44),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: compact ? 8 : 10),
          _BottomProgressBar(color: color, progress: progress),
        ],
      ),
    );
  }
}

class _BannerButton extends StatelessWidget {
  const _BannerButton({
    required this.icon,
    required this.isLoading,
    required this.onTap,
  });

  final IconData? icon;
  final bool isLoading;
  final Future<void> Function()? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap == null ? null : () => onTap!.call(),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Icon(icon, color: Colors.white.withValues(alpha: 0.92), size: 18),
        ),
      ),
    );
  }
}

class _RingGauge extends StatelessWidget {
  const _RingGauge({
    required this.color,
    required this.icon,
    required this.progress,
    required this.label,
    required this.size,
    required this.compact,
  });

  final Color color;
  final IconData icon;
  final double progress;
  final String label;
  final double size;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(
                color: color,
                progress: progress,
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: compact ? 21 : 24),
              SizedBox(height: compact ? 3 : 4),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.76),
                  fontWeight: FontWeight.w800,
                  fontSize: compact ? 11 : 13,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BottomProgressBar extends StatelessWidget {
  const _BottomProgressBar({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Stack(
        children: [
          Container(
            height: 6,
            color: Colors.white.withValues(alpha: 0.12),
          ),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.42),
                    blurRadius: 8,
                    spreadRadius: 0,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.color,
    required this.progress,
  });

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - strokeWidth) / 2;

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth + 2
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);

    final progressPaint = Paint()
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: (math.pi * 2) - (math.pi / 2),
        colors: [
          color.withValues(alpha: 0.20),
          color,
          color,
        ],
      ).createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    final startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress;

    canvas.drawArc(rect.deflate(strokeWidth / 2), startAngle, sweepAngle, false, glowPaint);
    canvas.drawArc(rect.deflate(strokeWidth / 2), startAngle, sweepAngle, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.progress != progress;
  }
}
