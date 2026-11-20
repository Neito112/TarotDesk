import 'package:flutter/material.dart';

enum AppBreakpoint { phone, tablet, desktop }

class Responsive {
  static const double phoneMaxWidth = 600;
  static const double tabletMaxWidth = 1024;

  static AppBreakpoint breakpointOf(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < phoneMaxWidth) return AppBreakpoint.phone;
    if (width <= tabletMaxWidth) return AppBreakpoint.tablet;
    return AppBreakpoint.desktop;
  }

  static bool isPhone(BuildContext context) =>
      breakpointOf(context) == AppBreakpoint.phone;
  static bool isTablet(BuildContext context) =>
      breakpointOf(context) == AppBreakpoint.tablet;
  static bool isDesktop(BuildContext context) =>
      breakpointOf(context) == AppBreakpoint.desktop;

  static double maxContentWidth(BuildContext context) {
    switch (breakpointOf(context)) {
      case AppBreakpoint.phone:
        return 480;
      case AppBreakpoint.tablet:
        return 720;
      case AppBreakpoint.desktop:
        return 1080;
    }
  }

  static int gridColumns(BuildContext context) {
    switch (breakpointOf(context)) {
      case AppBreakpoint.phone:
        return 2;
      case AppBreakpoint.tablet:
        return 3;
      case AppBreakpoint.desktop:
        return 4;
    }
  }

  static double cardWidth(BuildContext context) {
    switch (breakpointOf(context)) {
      case AppBreakpoint.phone:
        return 160;
      case AppBreakpoint.tablet:
        return 200;
      case AppBreakpoint.desktop:
        return 220;
    }
  }
}

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const ResponsiveCenter({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: Responsive.maxContentWidth(context),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
