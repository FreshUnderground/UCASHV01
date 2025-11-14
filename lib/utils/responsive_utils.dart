import 'package:flutter/material.dart';

/// Utilitaires pour la responsivité UCASH
/// Système de design adaptatif avec tailles fluides
class ResponsiveUtils {
  
  /// Breakpoints standardisés UCASH
  static const double mobileBreakpoint = 480;
  static const double tabletBreakpoint = 768;
  static const double desktopBreakpoint = 1024;
  static const double largeDesktopBreakpoint = 1440;

  /// Détection du type d'écran
  static ScreenType getScreenType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    
    if (width < mobileBreakpoint) return ScreenType.mobile;
    if (width < tabletBreakpoint) return ScreenType.mobileLarge;
    if (width < desktopBreakpoint) return ScreenType.tablet;
    if (width < largeDesktopBreakpoint) return ScreenType.desktop;
    return ScreenType.largeDesktop;
  }

  /// Taille de police fluide basée sur la largeur d'écran
  static double getFluidFontSize(BuildContext context, {
    double mobile = 14,
    double tablet = 16,
    double desktop = 18,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width <= mobileBreakpoint) {
      return mobile;
    } else if (width <= tabletBreakpoint) {
      // Interpolation linéaire entre mobile et tablet
      final progress = (width - mobileBreakpoint) / (tabletBreakpoint - mobileBreakpoint);
      return mobile + (tablet - mobile) * progress;
    } else if (width <= desktopBreakpoint) {
      // Interpolation linéaire entre tablet et desktop
      final progress = (width - tabletBreakpoint) / (desktopBreakpoint - tabletBreakpoint);
      return tablet + (desktop - tablet) * progress;
    }
    
    return desktop;
  }

  /// Padding fluide basé sur la largeur d'écran
  static EdgeInsets getFluidPadding(BuildContext context, {
    EdgeInsets mobile = const EdgeInsets.all(12),
    EdgeInsets tablet = const EdgeInsets.all(16),
    EdgeInsets desktop = const EdgeInsets.all(24),
  }) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
      case ScreenType.mobileLarge:
        return mobile;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return desktop;
    }
  }

  /// Espacement fluide
  static double getFluidSpacing(BuildContext context, {
    double mobile = 8,
    double tablet = 12,
    double desktop = 16,
  }) {
    final width = MediaQuery.of(context).size.width;
    
    if (width <= mobileBreakpoint) {
      return mobile;
    } else if (width <= tabletBreakpoint) {
      final progress = (width - mobileBreakpoint) / (tabletBreakpoint - mobileBreakpoint);
      return mobile + (tablet - mobile) * progress;
    } else if (width <= desktopBreakpoint) {
      final progress = (width - tabletBreakpoint) / (desktopBreakpoint - tabletBreakpoint);
      return tablet + (desktop - tablet) * progress;
    }
    
    return desktop;
  }

  /// Taille d'icône fluide
  static double getFluidIconSize(BuildContext context, {
    double mobile = 20,
    double tablet = 24,
    double desktop = 28,
  }) {
    return getFluidFontSize(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  /// Hauteur de container fluide
  static double getFluidHeight(BuildContext context, {
    double mobile = 48,
    double tablet = 56,
    double desktop = 64,
  }) {
    return getFluidFontSize(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  /// Border radius fluide
  static double getFluidBorderRadius(BuildContext context, {
    double mobile = 8,
    double tablet = 12,
    double desktop = 16,
  }) {
    return getFluidFontSize(context, mobile: mobile, tablet: tablet, desktop: desktop);
  }

  /// Largeur maximale de container
  static double getMaxContainerWidth(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.mobileLarge:
        return 600;
      case ScreenType.tablet:
        return 800;
      case ScreenType.desktop:
        return 1200;
      case ScreenType.largeDesktop:
        return 1400;
    }
  }

  /// Nombre de colonnes pour grilles
  static int getGridColumns(BuildContext context, {
    int mobile = 1,
    int mobileLarge = 2,
    int tablet = 3,
    int desktop = 4,
    int largeDesktop = 5,
  }) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.mobileLarge:
        return mobileLarge;
      case ScreenType.tablet:
        return tablet;
      case ScreenType.desktop:
        return desktop;
      case ScreenType.largeDesktop:
        return largeDesktop;
    }
  }

  /// Ratio d'aspect pour cards
  static double getCardAspectRatio(BuildContext context) {
    final screenType = getScreenType(context);
    
    switch (screenType) {
      case ScreenType.mobile:
        return 1.2; // Plus haut sur mobile
      case ScreenType.mobileLarge:
        return 1.1;
      case ScreenType.tablet:
        return 1.0; // Carré sur tablet
      case ScreenType.desktop:
      case ScreenType.largeDesktop:
        return 0.9; // Plus large sur desktop
    }
  }
}

/// Types d'écrans supportés
enum ScreenType {
  mobile,        // < 480px
  mobileLarge,   // 480px - 768px
  tablet,        // 768px - 1024px
  desktop,       // 1024px - 1440px
  largeDesktop,  // > 1440px
}

/// Extension pour faciliter l'utilisation
extension ResponsiveContext on BuildContext {
  ScreenType get screenType => ResponsiveUtils.getScreenType(this);
  
  bool get isMobile => screenType == ScreenType.mobile;
  bool get isMobileLarge => screenType == ScreenType.mobileLarge;
  bool get isTablet => screenType == ScreenType.tablet;
  bool get isDesktop => screenType == ScreenType.desktop;
  bool get isLargeDesktop => screenType == ScreenType.largeDesktop;
  
  bool get isSmallScreen => isMobile || isMobileLarge;
  bool get isLargeScreen => isDesktop || isLargeDesktop;
  
  double fluidFont({double mobile = 14, double tablet = 16, double desktop = 18}) {
    return ResponsiveUtils.getFluidFontSize(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
  
  double fluidSpacing({double mobile = 8, double tablet = 12, double desktop = 16}) {
    return ResponsiveUtils.getFluidSpacing(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
  
  double fluidIcon({double mobile = 20, double tablet = 24, double desktop = 28}) {
    return ResponsiveUtils.getFluidIconSize(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
  
  EdgeInsets fluidPadding({
    EdgeInsets mobile = const EdgeInsets.all(12),
    EdgeInsets tablet = const EdgeInsets.all(16),
    EdgeInsets desktop = const EdgeInsets.all(24),
  }) {
    return ResponsiveUtils.getFluidPadding(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
  
  double fluidBorderRadius({double mobile = 8, double tablet = 12, double desktop = 16}) {
    return ResponsiveUtils.getFluidBorderRadius(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
  
  double getMaxContainerWidth(BuildContext context) {
    return ResponsiveUtils.getMaxContainerWidth(context);
  }
  
  double fluidWidth({double mobile = 100, double tablet = 120, double desktop = 140}) {
    return ResponsiveUtils.getFluidFontSize(this, mobile: mobile, tablet: tablet, desktop: desktop);
  }
  
}
