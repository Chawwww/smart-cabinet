// lib/utils/responsive_layout.dart
//
// Single source of truth for all breakpoints and layout decisions.
// Use this everywhere instead of hardcoding MediaQuery values.

import 'package:flutter/material.dart';

enum AppLayout { mobile, tablet, desktop }

class Responsive {
  // ── Breakpoints ────────────────────────────────────────
  static const double mobileMaxWidth  = 599;
  static const double tabletMaxWidth  = 1199;
  // desktop = 1200+

  static AppLayout layoutOf(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    if (w <= mobileMaxWidth)  return AppLayout.mobile;
    if (w <= tabletMaxWidth)  return AppLayout.tablet;
    return AppLayout.desktop;
  }

  static bool isMobile(BuildContext context) =>
      layoutOf(context) == AppLayout.mobile;

  static bool isTablet(BuildContext context) =>
      layoutOf(context) == AppLayout.tablet;

  static bool isDesktop(BuildContext context) =>
      layoutOf(context) == AppLayout.desktop;

  static bool isWide(BuildContext context) =>
      layoutOf(context) != AppLayout.mobile;

  // ── Grid cross-axis count ──────────────────────────────
  static int gridCols(BuildContext context) {
    switch (layoutOf(context)) {
      case AppLayout.mobile:  return 2;
      case AppLayout.tablet:  return 3;
      case AppLayout.desktop: return 4;
    }
  }

  // ── Content max width (keeps text readable on wide screens)
  static double contentMaxWidth(BuildContext context) {
    switch (layoutOf(context)) {
      case AppLayout.mobile:  return double.infinity;
      case AppLayout.tablet:  return 800;
      case AppLayout.desktop: return 1100;
    }
  }

  // ── Nav sidebar width (desktop) ────────────────────────
  static const double sidebarWidth        = 260;
  static const double sidebarCollapsed    = 72;

  // ── Padding ────────────────────────────────────────────
  static double pagePadding(BuildContext context) {
    switch (layoutOf(context)) {
      case AppLayout.mobile:  return 16;
      case AppLayout.tablet:  return 24;
      case AppLayout.desktop: return 32;
    }
  }

  // ── Font scale ─────────────────────────────────────────
  static double titleFontSize(BuildContext context) =>
      isDesktop(context) ? 28 : isTablet(context) ? 24 : 20;

  // ── Build helper: switch between layouts ───────────────
  static Widget builder({
    required BuildContext context,
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    switch (layoutOf(context)) {
      case AppLayout.mobile:
        return mobile;
      case AppLayout.tablet:
        return tablet ?? mobile;
      case AppLayout.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}