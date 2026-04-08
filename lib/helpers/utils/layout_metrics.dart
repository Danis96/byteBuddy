import 'package:flutter/material.dart';

/// Centralises every responsive breakpoint / derived value so that
/// [MyHomePage] only asks "what layout am I in?" rather than scattering
/// magic numbers across the build method.
class LayoutMetrics {
  LayoutMetrics._({
    required this.width,
    required this.height,
    required this.compact,
    required this.narrow,
    required this.columns,
    required this.shellPadding,
    required this.orbSize,
    required this.gridAspectRatio,
    required this.horizontalInset,
    required this.spacing,
    required this.allowScroll,
  });

  factory LayoutMetrics.from(BoxConstraints constraints) {
    final width = constraints.maxWidth;
    final height = constraints.maxHeight;

    final compact = width < 520;
    final narrow = width < 430;
    final columns = width >= 760 ? 3 : (compact ? 1 : 2);
    final shellPadding = width < 440 ? 14.0 : 20.0;
    final orbSize = narrow ? 92.0 : (width < 620 ? 108.0 : 114.0);
    final gridAspectRatio =
    columns == 1 ? 1.9 : (width > 700 ? 1.28 : 1.42);
    final horizontalInset = width < 380 ? 10.0 : 14.0;
    final spacing = width < 420 ? 12.0 : 14.0;
    final allowScroll = height < 760 || columns == 1;

    return LayoutMetrics._(
      width: width,
      height: height,
      compact: compact,
      narrow: narrow,
      columns: columns,
      shellPadding: shellPadding,
      orbSize: orbSize,
      gridAspectRatio: gridAspectRatio,
      horizontalInset: horizontalInset,
      spacing: spacing,
      allowScroll: allowScroll,
    );
  }

  final double width;
  final double height;

  /// True when the window is narrow enough to collapse to a single column
  /// and stack banner controls vertically (< 520 px).
  final bool compact;

  /// True when the window is very narrow and text/icons need extra shrinkage
  /// (< 430 px).
  final bool narrow;

  /// Number of metric-card grid columns: 1, 2, or 3.
  final int columns;

  /// Horizontal padding inside the shell container.
  final double shellPadding;

  /// Diameter of the buddy orb, in logical pixels.
  final double orbSize;

  /// Aspect ratio passed to [SliverGridDelegateWithFixedCrossAxisCount].
  final double gridAspectRatio;

  /// SafeArea minimum inset on all sides.
  final double horizontalInset;

  /// Gap between grid cells (main and cross axis).
  final double spacing;

  /// Whether the content column should be wrapped in a [SingleChildScrollView].
  final bool allowScroll;
}