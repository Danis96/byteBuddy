import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../helpers/utils/layout_metrics.dart';
import '../../../../helpers/utils/metric_formatters.dart';
import '../../../provider/hardware_monitor_provider.dart';

class MetricGrid extends StatelessWidget {
  const MetricGrid({super.key, required this.monitor, required this.lm});

  final HardwareMonitorProvider monitor;
  final LayoutMetrics lm;

  @override
  Widget build(BuildContext context) {
    final cards = _cardConfigs(monitor, lm.narrow);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cards.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: lm.columns,
        childAspectRatio: lm.gridAspectRatio,
        mainAxisSpacing: lm.spacing,
        crossAxisSpacing: lm.spacing,
      ),
      itemBuilder: (_, i) => MetricCard(config: cards[i]),
    );
  }

  static List<MetricCardConfig> _cardConfigs(
      HardwareMonitorProvider monitor, bool narrow) {
    return [
      MetricCardConfig(
        color: const Color(0xFF4F7EFF),
        icon: Icons.memory_rounded,
        value: formatPercent(monitor.cpuUsage),
        label: 'CPU USAGE',
        progress: safeUnit((monitor.cpuUsage ?? 0) / 100),
        ringLabel: formatCompactPercent(monitor.cpuUsage),
        compact: narrow,
      ),
      MetricCardConfig(
        color: const Color(0xFFFFB133),
        icon: Icons.battery_5_bar_rounded,
        value: formatBattery(monitor.batteryLevel),
        label: 'BATTERY',
        progress: safeUnit((monitor.batteryLevel ?? 0) / 100),
        ringLabel: formatCompactBattery(monitor.batteryLevel),
        compact: narrow,
      ),
      MetricCardConfig(
        color: const Color(0xFF58D68D),
        icon: Icons.storage_rounded,
        value: formatMemory(monitor.memoryUsage),
        label: 'MEMORY',
        progress: memoryProgress(monitor.memoryUsage),
        ringLabel: formatMemoryPercent(monitor.memoryUsage),
        compact: narrow,
      ),
      MetricCardConfig(
        color: const Color(0xFFB05BFF),
        icon: Icons.mode_fan_off_rounded,
        value: formatFanValue(monitor.fanSpeed),
        label: 'FAN SPEED',
        progress: fanProgress(monitor.fanSpeed),
        ringLabel: formatFanPercent(monitor.fanSpeed),
        compact: narrow,
      ),
      MetricCardConfig(
        color: const Color(0xFFFF5D73),
        icon: Icons.device_thermostat_rounded,
        value: formatTemperature(monitor.cpuTemp),
        label: 'TEMPERATURE',
        progress: tempProgress(monitor.cpuTemp),
        ringLabel: formatTempPercent(monitor.cpuTemp),
        compact: narrow,
      ),
      MetricCardConfig(
        color: const Color(0xFF58D7FF),
        icon: Icons.wifi_tethering_rounded,
        value: monitor.error == null ? 'Active' : 'Issue',
        label: 'CONNECTION',
        progress: monitor.error == null ? 1.0 : 0.24,
        ringLabel: monitor.error == null ? '100%' : '24%',
        subtitle: monitor.error,
        compact: narrow,
      ),
    ];
  }
}

class MetricCardConfig {
  const MetricCardConfig({
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
}

class MetricCard extends StatelessWidget {
  const MetricCard({super.key, required this.config});

  final MetricCardConfig config;

  @override
  Widget build(BuildContext context) {
    final ringSize = config.compact ? 76.0 : 88.0;

    return Container(
      padding: EdgeInsets.fromLTRB(
        config.compact ? 14 : 18,
        config.compact ? 14 : 18,
        config.compact ? 14 : 18,
        config.compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: [
            config.color.withValues(alpha: 0.18),
            config.color.withValues(alpha: 0.10),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: config.color.withValues(alpha: 0.10),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                RingGauge(
                  color: config.color,
                  icon: config.icon,
                  progress: config.progress,
                  label: config.ringLabel,
                  size: ringSize,
                  compact: config.compact,
                ),
                SizedBox(width: config.compact ? 12 : 16),
                Expanded(
                  child: _MetricCardLabels(config: config),
                ),
              ],
            ),
          ),
          SizedBox(height: config.compact ? 8 : 10),
          BottomProgressBar(color: config.color, progress: config.progress),
        ],
      ),
    );
  }
}


class _MetricCardLabels extends StatelessWidget {
  const _MetricCardLabels({required this.config});

  final MetricCardConfig config;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          config.value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: config.compact ? 20 : 23,
            letterSpacing: -0.8,
          ),
        ),
        SizedBox(height: config.compact ? 4 : 6),
        Text(
          config.label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.56),
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
            fontSize: config.compact ? 12 : null,
          ),
        ),
        if (config.subtitle != null && config.subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            config.subtitle!,
            maxLines: config.compact ? 1 : 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.44),
            ),
          ),
        ],
      ],
    );
  }
}

class RingGauge extends StatelessWidget {
  const RingGauge({
    super.key,
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
              painter: RingPainter(color: color, progress: progress),
            ),
          ),
          _RingGaugeContent(
            icon: icon,
            label: label,
            color: color,
            compact: compact,
          ),
        ],
      ),
    );
  }
}

class _RingGaugeContent extends StatelessWidget {
  const _RingGaugeContent({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

class RingPainter extends CustomPainter {
  const RingPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    const strokeWidth = 7.0;
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.width - strokeWidth) / 2;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.12)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );

    final startAngle = -math.pi / 2;
    final sweepAngle = math.pi * 2 * progress;
    final deflated = rect.deflate(strokeWidth / 2);

    canvas.drawArc(
      deflated,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..color = color.withValues(alpha: 0.22)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 2
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.drawArc(
      deflated,
      startAngle,
      sweepAngle,
      false,
      Paint()
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: (math.pi * 2) - (math.pi / 2),
          colors: [color.withValues(alpha: 0.20), color, color],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant RingPainter old) =>
      old.color != color || old.progress != progress;
}


class BottomProgressBar extends StatelessWidget {
  const BottomProgressBar({
    super.key,
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
          Container(height: 6, color: Colors.white.withValues(alpha: 0.12)),
          FractionallySizedBox(
            widthFactor: progress,
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: color,
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.42), blurRadius: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}