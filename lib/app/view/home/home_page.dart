import 'package:bb/app/view/home/widgets/home_page_buddy_orb.dart';
import 'package:bb/app/view/home/widgets/home_page_metric_grid.dart';
import 'package:bb/app/view/home/widgets/home_page_status_banner.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import '../../../helpers/utils/layout_metrics.dart';
import '../../../helpers/utils/mood_colors.dart';
import '../../provider/companion_provider.dart';
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
  void onTrayIconMouseDown() async => _toggleWindow();

  Future<void> _toggleWindow() async {
    final isVisible = await windowManager.isVisible();
    if (isVisible) {
      await windowManager.hide();
      return;
    }
    final mousePosition = await screenRetriever.getCursorScreenPoint();
    await windowManager.setSize(_windowSize);
    await windowManager.setPosition(Offset(
      mousePosition.dx - (_windowSize.width / 2),
      mousePosition.dy + 14,
    ));
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
    return Consumer2<HardwareMonitorProvider, CompanionProvider>(
      builder: (context, monitor, companion, _) {
        return Scaffold(
          backgroundColor: const Color(0xFF1D2438),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final lm = LayoutMetrics.from(constraints);
              return _HomeShell(
                lm: lm,
                child: _HomeBody(
                  monitor: monitor,
                  companion: companion,
                  statusColor: statusColorForMood(companion.moodKey),
                  lm: lm,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.lm, required this.child});

  final LayoutMetrics lm;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF20283D), Color(0xFF1B2337)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SafeArea(
        minimum: EdgeInsets.all(lm.horizontalInset),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF20283D),
            borderRadius: BorderRadius.circular(lm.compact ? 22 : 28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              lm.shellPadding,
              lm.compact ? 16 : 18,
              lm.shellPadding,
              lm.compact ? 16 : 18,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _HomeBody extends StatelessWidget {
  const _HomeBody({
    required this.monitor,
    required this.companion,
    required this.statusColor,
    required this.lm,
  });

  final HardwareMonitorProvider monitor;
  final CompanionProvider companion;
  final Color statusColor;
  final LayoutMetrics lm;

  @override
  Widget build(BuildContext context) {
    final column = _HomeColumn(
      monitor: monitor,
      companion: companion,
      statusColor: statusColor,
      lm: lm,
    );

    if (lm.allowScroll) return SingleChildScrollView(child: column);
    return SizedBox.expand(child: column);
  }
}


class _HomeColumn extends StatelessWidget {
  const _HomeColumn({
    required this.monitor,
    required this.companion,
    required this.statusColor,
    required this.lm,
  });

  final HardwareMonitorProvider monitor;
  final CompanionProvider companion;
  final Color statusColor;
  final LayoutMetrics lm;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StatusBanner(
          title: companion.moodKey.toUpperCase(),
          message: companion.message,
          color: statusColor,
          isLoading: monitor.isLoading,
          onRefresh: () => monitor.refreshStats(),
          onHide: windowManager.hide,
          compact: lm.compact,
        ),
        SizedBox(height: lm.compact ? 18 : 22),
        BuddyOrb(
          color: statusColor,
          size: lm.orbSize,
          mood: companion.mood,
        ),
        SizedBox(height: lm.compact ? 18 : 24),
        MetricGrid(monitor: monitor, lm: lm),
        const SizedBox(height: 10),
        _SectionDivider(),
        const SizedBox(height: 12),
        _FooterLabel(compact: lm.compact),
      ],
    );
  }
}

class _SectionDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(height: 1, color: Colors.white.withValues(alpha: 0.08));
  }
}

class _FooterLabel extends StatelessWidget {
  const _FooterLabel({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Monitoring system health in real-time · Updated every 2 seconds',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Colors.white.withValues(alpha: 0.28),
        fontWeight: FontWeight.w700,
        fontSize: compact ? 11 : 12,
      ),
    );
  }
}