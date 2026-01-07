import 'package:flutter/material.dart';

/// Screen type enumeration for responsive layouts
enum ScreenType { mobile, tablet, desktop }

/// Responsive layout helper widget for different screen sizes
/// Use this to adapt UI for mobile, tablet, and desktop/web
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  /// Breakpoints for different screen sizes
  static const double mobileBreakpoint = 600;
  static const double tabletBreakpoint = 900;
  static const double desktopBreakpoint = 1200;

  /// Get the current screen type based on width
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= desktopBreakpoint) return ScreenType.desktop;
    if (width >= tabletBreakpoint) return ScreenType.tablet;
    return ScreenType.mobile;
  }

  /// Check if current screen is mobile
  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < mobileBreakpoint;

  /// Check if current screen is tablet or larger
  static bool isTabletOrLarger(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletBreakpoint;

  /// Check if current screen is desktop or larger
  static bool isDesktopOrLarger(BuildContext context) =>
      MediaQuery.of(context).size.width >= desktopBreakpoint;

  /// Get responsive value based on screen type
  static T value<T>(
    BuildContext context, {
    required T mobile,
    T? tablet,
    T? desktop,
  }) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }

  /// Get responsive padding based on screen size
  static EdgeInsets responsivePadding(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.desktop:
        return const EdgeInsets.symmetric(horizontal: 48, vertical: 24);
      case ScreenType.tablet:
        return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
      case ScreenType.mobile:
        return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
    }
  }

  /// Get max content width for different screen sizes
  static double maxContentWidth(BuildContext context) {
    final screenType = getScreenType(context);
    switch (screenType) {
      case ScreenType.desktop:
        return 1200;
      case ScreenType.tablet:
        return 800;
      case ScreenType.mobile:
        return double.infinity;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenType = getScreenType(context);

    switch (screenType) {
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.mobile:
        return mobile;
    }
  }
}

/// Centered content wrapper with max width constraint
/// Useful for keeping content readable on large screens
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;

  const CenteredContent({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth ?? ResponsiveLayout.maxContentWidth(context),
        ),
        child: child,
      ),
    );
  }
}

/// Responsive grid that adapts columns based on screen size
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int mobileColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.mobileColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 16,
    this.runSpacing = 16,
  });

  @override
  Widget build(BuildContext context) {
    final columns = ResponsiveLayout.value(
      context,
      mobile: mobileColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(width: itemWidth, child: child);
          }).toList(),
        );
      },
    );
  }
}
