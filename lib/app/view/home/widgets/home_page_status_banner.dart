import 'package:flutter/material.dart';

class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
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
      padding: EdgeInsets.fromLTRB(
        compact ? 14 : 18,
        compact ? 14 : 16,
        compact ? 14 : 16,
        compact ? 14 : 16,
      ),
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
          ? _BannerCompactLayout(
        title: title,
        message: message,
        compact: compact,
        isLoading: isLoading,
        onRefresh: onRefresh,
        onHide: onHide,
      )
          : _BannerWideLayout(
        title: title,
        message: message,
        compact: compact,
        isLoading: isLoading,
        onRefresh: onRefresh,
        onHide: onHide,
      ),
    );
  }
}

class _BannerCompactLayout extends StatelessWidget {
  const _BannerCompactLayout({
    required this.title,
    required this.message,
    required this.compact,
    required this.isLoading,
    required this.onRefresh,
    required this.onHide,
  });

  final String title;
  final String message;
  final bool compact;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            BannerStatusIcon(compact: compact),
            const SizedBox(width: 12),
            Expanded(
              child: BannerText(title: title, message: message, compact: compact),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            BannerButton(
              icon: isLoading ? null : Icons.refresh_rounded,
              isLoading: isLoading,
              onTap: isLoading ? null : onRefresh,
            ),
            const SizedBox(width: 8),
            BannerButton(
              icon: Icons.close_rounded,
              isLoading: false,
              onTap: onHide,
            ),
          ],
        ),
      ],
    );
  }
}

class _BannerWideLayout extends StatelessWidget {
  const _BannerWideLayout({
    required this.title,
    required this.message,
    required this.compact,
    required this.isLoading,
    required this.onRefresh,
    required this.onHide,
  });

  final String title;
  final String message;
  final bool compact;
  final bool isLoading;
  final Future<void> Function() onRefresh;
  final Future<void> Function() onHide;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BannerStatusIcon(compact: compact),
        const SizedBox(width: 14),
        Expanded(
          child: BannerText(title: title, message: message, compact: compact),
        ),
        const SizedBox(width: 12),
        Column(
          children: [
            BannerButton(
              icon: isLoading ? null : Icons.refresh_rounded,
              isLoading: isLoading,
              onTap: isLoading ? null : onRefresh,
            ),
            const SizedBox(height: 8),
            BannerButton(
              icon: Icons.close_rounded,
              isLoading: false,
              onTap: onHide,
            ),
          ],
        ),
      ],
    );
  }
}

class BannerStatusIcon extends StatelessWidget {
  const BannerStatusIcon({super.key, required this.compact});

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

class BannerText extends StatelessWidget {
  const BannerText({
    super.key,
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

class BannerButton extends StatelessWidget {
  const BannerButton({
    super.key,
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
      onTap: onTap == null ? null : () => onTap!(),
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