import 'package:flutter/material.dart';

/// Widget de card responsive qui s'adapte à toutes les tailles d'écran
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;
  final double? elevation;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;
  final double? minHeight;
  final double? maxWidth;
  final bool adaptivePadding;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.backgroundColor,
    this.elevation,
    this.borderRadius,
    this.boxShadow,
    this.minHeight,
    this.maxWidth,
    this.adaptivePadding = true,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    final isMobile = size.width <= 768;
    final isSmallMobile = size.width < 600; // Nouveau seuil pour très petits écrans

    // Padding adaptatif selon la taille d'écran
    EdgeInsetsGeometry effectivePadding = padding ?? 
      (adaptivePadding 
        ? EdgeInsets.all(isDesktop ? 24 : isTablet ? 20 : isSmallMobile ? 12 : 16)
        : const EdgeInsets.all(16));

    // Margin adaptatif
    EdgeInsetsGeometry effectiveMargin = margin ?? 
      EdgeInsets.symmetric(
        horizontal: isDesktop ? 8 : isTablet ? 6 : isSmallMobile ? 2 : 4,
        vertical: isDesktop ? 8 : isTablet ? 6 : isSmallMobile ? 3 : 4,
      );

    return Container(
      constraints: BoxConstraints(
        minHeight: minHeight ?? 0,
        maxWidth: maxWidth ?? double.infinity,
      ),
      margin: effectiveMargin,
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: borderRadius ?? BorderRadius.circular(isDesktop ? 16 : isTablet ? 14 : isSmallMobile ? 10 : 12),
        boxShadow: boxShadow ?? [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: isDesktop ? 8 : isTablet ? 6 : isSmallMobile ? 3 : 4,
            offset: Offset(0, isDesktop ? 4 : isTablet ? 3 : isSmallMobile ? 1 : 2),
          ),
        ],
      ),
      child: Padding(
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

/// Layout responsive pour organiser les cards
class ResponsiveLayout extends StatelessWidget {
  final List<Widget> children;
  final int desktopColumns;
  final int tabletColumns;
  final int mobileColumns;
  final double spacing;
  final double runSpacing;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;

  const ResponsiveLayout({
    super.key,
    required this.children,
    this.desktopColumns = 4,
    this.tabletColumns = 2,
    this.mobileColumns = 1,
    this.spacing = 16,
    this.runSpacing = 16,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 1024;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    int columns = isDesktop ? desktopColumns : isTablet ? tabletColumns : mobileColumns;
    
    if (columns == 1) {
      // Layout en colonne pour mobile
      return Column(
        mainAxisAlignment: mainAxisAlignment,
        crossAxisAlignment: crossAxisAlignment,
        children: children.map((child) => 
          Padding(
            padding: EdgeInsets.only(bottom: runSpacing),
            child: child,
          )
        ).toList(),
      );
    } else {
      // Layout en grille pour desktop/tablet
      return Wrap(
        spacing: spacing,
        runSpacing: runSpacing,
        children: children.map((child) => 
          SizedBox(
            width: (size.width - (spacing * (columns + 1))) / columns,
            child: child,
          )
        ).toList(),
      );
    }
  }
}

/// Grid responsive avec tailles flexibles
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? forceColumns;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.forceColumns,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    
    int columns;
    if (forceColumns != null) {
      columns = forceColumns!;
    } else if (size.width > 1200) {
      columns = 4;
    } else if (size.width > 900) {
      columns = 3;
    } else if (size.width > 600) {
      columns = 2;
    } else {
      columns = 1;
    }

    // Si une seule colonne, utiliser Column pour éviter les problèmes de layout
    if (columns == 1) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children.map((child) => 
          Padding(
            padding: EdgeInsets.only(bottom: runSpacing),
            child: child,
          )
        ).toList(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Vérifier que les contraintes sont valides
        if (!constraints.hasBoundedWidth || constraints.maxWidth == double.infinity) {
          // Fallback: utiliser Column si pas de largeur bornée
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children.map((child) => 
              Padding(
                padding: EdgeInsets.only(bottom: runSpacing),
                child: child,
              )
            ).toList(),
          );
        }
        
        final itemWidth = (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) => 
            SizedBox(
              width: itemWidth > 0 ? itemWidth : constraints.maxWidth,
              child: child,
            )
          ).toList(),
        );
      },
    );
  }
}

/// Breakpoints pour la responsivité
class ResponsiveBreakpoints {
  static const double mobile = 768;
  static const double tablet = 1024;
  static const double desktop = 1200;
  static const double largeDesktop = 1440;

  static bool isMobile(BuildContext context) {
    return MediaQuery.of(context).size.width <= mobile;
  }

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width > mobile && width <= tablet;
  }

  static bool isDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > tablet;
  }

  static bool isLargeDesktop(BuildContext context) {
    return MediaQuery.of(context).size.width > largeDesktop;
  }
}

/// Helper pour obtenir des valeurs responsives
class ResponsiveValue<T> {
  final T mobile;
  final T? tablet;
  final T? desktop;
  final T? largeDesktop;

  const ResponsiveValue({
    required this.mobile,
    this.tablet,
    this.desktop,
    this.largeDesktop,
  });

  T getValue(BuildContext context) {
    final size = MediaQuery.of(context).size.width;
    
    if (size > ResponsiveBreakpoints.largeDesktop && largeDesktop != null) {
      return largeDesktop!;
    } else if (size > ResponsiveBreakpoints.tablet && desktop != null) {
      return desktop!;
    } else if (size > ResponsiveBreakpoints.mobile && tablet != null) {
      return tablet!;
    } else {
      return mobile;
    }
  }
}

/// Extension pour faciliter l'utilisation
extension ResponsiveExtension on BuildContext {
  bool get isMobile => ResponsiveBreakpoints.isMobile(this);
  bool get isTablet => ResponsiveBreakpoints.isTablet(this);
  bool get isDesktop => ResponsiveBreakpoints.isDesktop(this);
  bool get isLargeDesktop => ResponsiveBreakpoints.isLargeDesktop(this);
  
  double get screenWidth => MediaQuery.of(this).size.width;
  double get screenHeight => MediaQuery.of(this).size.height;
}
