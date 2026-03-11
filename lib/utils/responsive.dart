// lib/utils/responsive.dart
import 'package:flutter/material.dart';

/// Breakpoints
///  mobile  : width < 600
///  tablet  : 600 <= width < 1024
///  desktop : width >= 1024
class Responsive {
  final double width;
  final double height;

  const Responsive._(this.width, this.height);

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Responsive._(size.width, size.height);
  }

  // ── Type checks ───────────────────────────────────────────
  bool get isMobile  => width < 600;
  bool get isTablet  => width >= 600 && width < 1024;
  bool get isDesktop => width >= 1024;
  bool get isWide    => width >= 600; // tablet or desktop

  // ── Adaptive values ───────────────────────────────────────
  /// Returns one of three values depending on screen size.
  T when<T>({required T mobile, required T tablet, required T desktop}) {
    if (isDesktop) return desktop;
    if (isTablet)  return tablet;
    return mobile;
  }

  /// Returns mobile value on phones, tablet/desktop value on larger screens.
  T adaptive<T>({required T mobile, required T wide}) =>
      isWide ? wide : mobile;

  // ── Common spacings ───────────────────────────────────────
  double get pagePadding  => when(mobile: 16, tablet: 24, desktop: 32);
  double get cardPadding  => when(mobile: 14, tablet: 18, desktop: 22);
  double get sectionGap   => when(mobile: 16, tablet: 20, desktop: 28);
  double get itemGap      => when(mobile: 10, tablet: 12, desktop: 14);

  // ── Typography ────────────────────────────────────────────
  double get titleFontSize    => when(mobile: 20, tablet: 24, desktop: 28);
  double get headingFontSize  => when(mobile: 16, tablet: 18, desktop: 20);
  double get bodyFontSize     => when(mobile: 13, tablet: 14, desktop: 15);
  double get captionFontSize  => when(mobile: 11, tablet: 12, desktop: 13);

  // ── Layout ────────────────────────────────────────────────
  int get dashboardColumns => when(mobile: 2, tablet: 3, desktop: 3);
  int get listColumns      => when(mobile: 1, tablet: 2, desktop: 3);
  double get cardAspect    => when(mobile: 1.1, tablet: 1.2, desktop: 1.3);

  // ── Form max width (center on large screens) ──────────────
  double get formMaxWidth  => when(mobile: double.infinity, tablet: 480, desktop: 520);

  // ── Button height ─────────────────────────────────────────
  double get buttonHeight => when(mobile: 48, tablet: 52, desktop: 54);

  // ── AppBar title size ─────────────────────────────────────
  double get appBarTitleSize => when(mobile: 17, tablet: 19, desktop: 21);

  // ── Avatar radius ─────────────────────────────────────────
  double get avatarRadius => when(mobile: 22, tablet: 26, desktop: 30);

  // ── Icon size ─────────────────────────────────────────────
  double get iconSize => when(mobile: 20, tablet: 22, desktop: 24);

  // ── Chip font size ────────────────────────────────────────
  double get chipFontSize => when(mobile: 11, tablet: 12, desktop: 13);
}

/// Centers content with [maxWidth] on wide screens and adds horizontal padding.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets? padding;

  const ResponsiveCenter({
    super.key,
    required this.child,
    this.maxWidth = 900,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final r   = Responsive.of(context);
    final pad = padding ?? EdgeInsets.symmetric(horizontal: r.pagePadding);
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: pad, child: child),
      ),
    );
  }
}

/// Two-column layout on tablet/desktop, single column on mobile.
class ResponsiveTwoColumn extends StatelessWidget {
  final Widget left;
  final Widget right;
  final double spacing;

  const ResponsiveTwoColumn({
    super.key,
    required this.left,
    required this.right,
    this.spacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    if (r.isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          SizedBox(width: spacing),
          Expanded(child: right),
        ],
      );
    }
    return Column(children: [left, SizedBox(height: spacing), right]);
  }
}