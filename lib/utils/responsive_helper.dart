import 'package:flutter/material.dart';

class ResponsiveHelper {
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  static double getDevicePixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  static bool isMobile(BuildContext context) {
    return getScreenWidth(context) < 600;
  }

  static bool isTablet(BuildContext context) {
    return getScreenWidth(context) >= 600 && getScreenWidth(context) < 1024;
  }

  static bool isDesktop(BuildContext context) {
    return getScreenWidth(context) >= 1024;
  }

  // Adapta fonte baseado em largura E DPI
  static double getResponsiveFontSize(BuildContext context, double baseSize) {
    final width = getScreenWidth(context);
    final textScaleFactor = MediaQuery.of(context).textScaleFactor;
    double sizeFactor = 1.0;
    
    if (width < 360) {
      sizeFactor = 0.9;
    } else if (width > 600) {
      sizeFactor = 1.1;
    }
    
    // Limita o scale factor para não ficar muito grande
    final limitedScale = textScaleFactor > 1.3 ? 1.3 : textScaleFactor;
    return baseSize * sizeFactor * limitedScale;
  }

  static EdgeInsets getResponsivePadding(BuildContext context, {double multiplier = 1.0}) {
    final width = getScreenWidth(context);
    double basePadding = 16;
    
    if (width < 360) {
      basePadding = 12;
    } else if (width >= 600 && width < 1024) {
      basePadding = 20;
    } else if (width >= 1024) {
      basePadding = 24;
    }
    
    return EdgeInsets.all(basePadding * multiplier);
  }

  static double getResponsiveImageHeight(BuildContext context, double baseHeight) {
    final height = getScreenHeight(context);
    final scaledHeight = (baseHeight / 800) * height;
    return scaledHeight.clamp(baseHeight * 0.8, baseHeight * 1.5);
  }

  static double getResponsiveWidth(BuildContext context, double percentage) {
    return getScreenWidth(context) * (percentage / 100);
  }

  static double getResponsiveHeight(BuildContext context, double percentage) {
    return getScreenHeight(context) * (percentage / 100);
  }

  static double getResponsiveSpacing(BuildContext context, double baseSpacing) {
    final width = getScreenWidth(context);
    if (width < 360) return baseSpacing * 0.8;
    if (width > 600) return baseSpacing * 1.2;
    return baseSpacing;
  }

  static double getResponsiveIconSize(BuildContext context, double baseSize) {
    final width = getScreenWidth(context);
    if (width < 360) return baseSize * 0.9;
    if (width > 600) return baseSize * 1.1;
    return baseSize;
  }
}
