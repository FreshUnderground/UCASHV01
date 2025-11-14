import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Système de containers responsive UCASH
/// Tailles et espacements fluides pour une interface adaptative
class UcashContainers {
  
  /// Container principal de page
  static Widget pageContainer(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: ResponsiveUtils.getMaxContainerWidth(context),
      ),
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      child: child,
    );
  }

  /// Card responsive avec padding adaptatif
  static Widget adaptiveCard(BuildContext context, {
    required Widget child,
    Color? color,
    double? elevation,
    EdgeInsets? margin,
  }) {
    return Container(
      margin: margin ?? EdgeInsets.all(context.fluidSpacing(mobile: 8, tablet: 12, desktop: 16)),
      child: Card(
        elevation: elevation ?? context.fluidSpacing(mobile: 2, tablet: 4, desktop: 6),
        color: color ?? Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
          ),
        ),
        child: Padding(
          padding: context.fluidPadding(
            mobile: const EdgeInsets.all(16),
            tablet: const EdgeInsets.all(20),
            desktop: const EdgeInsets.all(24),
          ),
          child: child,
        ),
      ),
    );
  }

  /// Container de statistique avec taille fluide
  static Widget statContainer(BuildContext context, {
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(20),
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 12, desktop: 16),
        ),
        border: Border.all(
          color: borderColor ?? Colors.grey.shade300,
          width: context.fluidSpacing(mobile: 1, tablet: 1.5, desktop: 2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: context.fluidSpacing(mobile: 4, tablet: 6, desktop: 8),
            offset: Offset(0, context.fluidSpacing(mobile: 2, tablet: 3, desktop: 4)),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Container de bouton avec hauteur adaptative
  static Widget buttonContainer(BuildContext context, {
    required Widget child,
    Color? backgroundColor,
    VoidCallback? onTap,
    bool isOutlined = false,
  }) {
    final height = ResponsiveUtils.getFluidHeight(context, mobile: 44, tablet: 48, desktop: 52);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(
        ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
      ),
      child: Container(
        height: height,
        padding: context.fluidPadding(
          mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
        decoration: BoxDecoration(
          color: isOutlined ? Colors.transparent : (backgroundColor ?? const Color(0xFFDC2626)),
          borderRadius: BorderRadius.circular(
            ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
          ),
          border: isOutlined ? Border.all(
            color: backgroundColor ?? const Color(0xFFDC2626),
            width: context.fluidSpacing(mobile: 1.5, tablet: 2, desktop: 2),
          ) : null,
        ),
        child: Center(child: child),
      ),
    );
  }

  /// Container de header avec padding adaptatif
  static Widget headerContainer(BuildContext context, {
    required Widget child,
    Color? backgroundColor,
    bool withShadow = true,
  }) {
    return Container(
      width: double.infinity,
      padding: context.fluidPadding(
        mobile: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        tablet: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        desktop: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        boxShadow: withShadow ? [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: context.fluidSpacing(mobile: 4, tablet: 6, desktop: 8),
            offset: Offset(0, context.fluidSpacing(mobile: 2, tablet: 3, desktop: 4)),
          ),
        ] : null,
      ),
      child: child,
    );
  }

  /// Container de navigation avec taille adaptative
  static Widget navContainer(BuildContext context, {
    required Widget child,
    bool isSelected = false,
  }) {
    return Container(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tablet: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        desktop: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      decoration: BoxDecoration(
        color: isSelected ? const Color(0xFFDC2626).withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
        ),
        border: isSelected ? Border.all(
          color: const Color(0xFFDC2626).withOpacity(0.3),
          width: context.fluidSpacing(mobile: 1, tablet: 1.5, desktop: 2),
        ) : null,
      ),
      child: child,
    );
  }

  /// Container de badge avec taille minimale
  static Widget badgeContainer(BuildContext context, {
    required Widget child,
    Color? backgroundColor,
    Color? textColor,
  }) {
    return Container(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        tablet: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        desktop: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      constraints: BoxConstraints(
        minHeight: context.fluidSpacing(mobile: 20, tablet: 24, desktop: 28),
      ),
      decoration: BoxDecoration(
        color: backgroundColor ?? const Color(0xFFDC2626),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 14),
        ),
      ),
      child: child,
    );
  }

  /// Container de formulaire avec largeur maximale
  static Widget formContainer(BuildContext context, {required Widget child}) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: context.isSmallScreen ? double.infinity : 600,
      ),
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(16),
        tablet: const EdgeInsets.all(20),
        desktop: const EdgeInsets.all(24),
      ),
      child: child,
    );
  }

  /// Container de grille avec colonnes adaptatives
  static Widget gridContainer(BuildContext context, {
    required List<Widget> children,
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
    double? aspectRatio,
  }) {
    final columns = ResponsiveUtils.getGridColumns(
      context,
      mobile: mobileColumns ?? 1,
      mobileLarge: mobileColumns ?? 2,
      tablet: tabletColumns ?? 3,
      desktop: desktopColumns ?? 4,
    );

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
      mainAxisSpacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
      childAspectRatio: aspectRatio ?? ResponsiveUtils.getCardAspectRatio(context),
      children: children,
    );
  }

  /// Espaceur vertical adaptatif
  static Widget verticalSpace(BuildContext context, {
    double mobile = 16,
    double tablet = 20,
    double desktop = 24,
  }) {
    return SizedBox(
      height: context.fluidSpacing(mobile: mobile, tablet: tablet, desktop: desktop),
    );
  }

  /// Espaceur horizontal adaptatif
  static Widget horizontalSpace(BuildContext context, {
    double mobile = 16,
    double tablet = 20,
    double desktop = 24,
  }) {
    return SizedBox(
      width: context.fluidSpacing(mobile: mobile, tablet: tablet, desktop: desktop),
    );
  }
}

/// Extension pour faciliter l'utilisation des containers
extension UcashContainerExtensions on BuildContext {
  Widget pageContainer({required Widget child}) => UcashContainers.pageContainer(this, child: child);
  
  Widget adaptiveCard({
    required Widget child,
    Color? color,
    double? elevation,
    EdgeInsets? margin,
  }) => UcashContainers.adaptiveCard(this, child: child, color: color, elevation: elevation, margin: margin);
  
  Widget statContainer({
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
  }) => UcashContainers.statContainer(this, child: child, backgroundColor: backgroundColor, borderColor: borderColor);
  
  Widget buttonContainer({
    required Widget child,
    Color? backgroundColor,
    VoidCallback? onTap,
    bool isOutlined = false,
  }) => UcashContainers.buttonContainer(this, child: child, backgroundColor: backgroundColor, onTap: onTap, isOutlined: isOutlined);
  
  Widget verticalSpace({double mobile = 16, double tablet = 20, double desktop = 24}) => 
    UcashContainers.verticalSpace(this, mobile: mobile, tablet: tablet, desktop: desktop);
  
  Widget horizontalSpace({double mobile = 16, double tablet = 20, double desktop = 24}) => 
    UcashContainers.horizontalSpace(this, mobile: mobile, tablet: tablet, desktop: desktop);
  
  Widget badgeContainer({
    required Widget child,
    Color? backgroundColor,
    Color? textColor,
  }) => UcashContainers.badgeContainer(this, child: child, backgroundColor: backgroundColor, textColor: textColor);
  
  Widget gridContainer({
    required List<Widget> children,
    int? mobileColumns,
    int? tabletColumns,
    int? desktopColumns,
    double? aspectRatio,
  }) => UcashContainers.gridContainer(this, children: children, mobileColumns: mobileColumns, tabletColumns: tabletColumns, desktopColumns: desktopColumns, aspectRatio: aspectRatio);
}
