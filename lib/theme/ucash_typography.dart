import 'package:flutter/material.dart';
import '../utils/responsive_utils.dart';

/// Système de typographie responsive UCASH
/// Tailles fluides qui s'adaptent automatiquement à l'écran
class UcashTypography {
  
  /// Couleurs de texte UCASH
  static const Color primaryText = Color(0xFF1F2937);
  static const Color secondaryText = Color(0xFF6B7280);
  static const Color accentText = Color(0xFFDC2626);
  static const Color lightText = Color(0xFF9CA3AF);
  static const Color whiteText = Colors.white;

  /// Titre principal (H1) - Fluide
  static TextStyle h1(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 24, tablet: 28, desktop: 32),
      fontWeight: FontWeight.bold,
      color: primaryText,
      height: 1.2,
      letterSpacing: -0.5,
    );
  }

  /// Titre secondaire (H2) - Fluide
  static TextStyle h2(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 20, tablet: 24, desktop: 28),
      fontWeight: FontWeight.bold,
      color: primaryText,
      height: 1.3,
      letterSpacing: -0.3,
    );
  }

  /// Titre tertiaire (H3) - Fluide
  static TextStyle h3(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 18, tablet: 20, desktop: 24),
      fontWeight: FontWeight.w600,
      color: primaryText,
      height: 1.3,
    );
  }

  /// Titre quaternaire (H4) - Fluide
  static TextStyle h4(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 16, tablet: 18, desktop: 20),
      fontWeight: FontWeight.w600,
      color: primaryText,
      height: 1.4,
    );
  }

  /// Titre UCASH avec couleur accent
  static TextStyle titleAccent(BuildContext context) {
    return h2(context).copyWith(color: accentText);
  }

  /// Corps de texte principal
  static TextStyle body(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 14, tablet: 16, desktop: 16),
      fontWeight: FontWeight.normal,
      color: primaryText,
      height: 1.5,
    );
  }

  /// Corps de texte secondaire
  static TextStyle bodySecondary(BuildContext context) {
    return body(context).copyWith(color: secondaryText);
  }

  /// Texte de légende/caption
  static TextStyle caption(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 12, tablet: 13, desktop: 14),
      fontWeight: FontWeight.normal,
      color: lightText,
      height: 1.4,
    );
  }

  /// Texte de bouton
  static TextStyle button(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 14, tablet: 15, desktop: 16),
      fontWeight: FontWeight.w600,
      color: whiteText,
      height: 1.2,
      letterSpacing: 0.5,
    );
  }

  /// Texte de label/étiquette
  static TextStyle label(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 12, tablet: 14, desktop: 14),
      fontWeight: FontWeight.w500,
      color: secondaryText,
      height: 1.3,
    );
  }

  /// Texte de statistique (gros chiffres)
  static TextStyle statValue(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 20, tablet: 24, desktop: 28),
      fontWeight: FontWeight.bold,
      color: accentText,
      height: 1.1,
    );
  }

  /// Texte de statistique (label)
  static TextStyle statLabel(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 10, tablet: 12, desktop: 14),
      fontWeight: FontWeight.w500,
      color: secondaryText,
      height: 1.2,
    );
  }

  /// Texte de navigation
  static TextStyle navigation(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 12, tablet: 14, desktop: 16),
      fontWeight: FontWeight.w500,
      color: primaryText,
      height: 1.2,
    );
  }

  /// Texte d'erreur
  static TextStyle error(BuildContext context) {
    return body(context).copyWith(color: Colors.red);
  }

  /// Texte de succès
  static TextStyle success(BuildContext context) {
    return body(context).copyWith(color: Colors.green);
  }

  /// Texte d'avertissement
  static TextStyle warning(BuildContext context) {
    return body(context).copyWith(color: Colors.orange);
  }

  /// Texte de montant (devise)
  static TextStyle currency(BuildContext context, {bool isPositive = true}) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 16, tablet: 18, desktop: 20),
      fontWeight: FontWeight.bold,
      color: isPositive ? Colors.green : Colors.red,
      height: 1.2,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
  }

  /// Texte de badge/chip
  static TextStyle badge(BuildContext context) {
    return TextStyle(
      fontSize: context.fluidFont(mobile: 10, tablet: 11, desktop: 12),
      fontWeight: FontWeight.w600,
      color: whiteText,
      height: 1.1,
      letterSpacing: 0.3,
    );
  }
}

/// Extension pour faciliter l'utilisation des styles
extension UcashTextStyles on BuildContext {
  TextStyle get h1 => UcashTypography.h1(this);
  TextStyle get h2 => UcashTypography.h2(this);
  TextStyle get h3 => UcashTypography.h3(this);
  TextStyle get h4 => UcashTypography.h4(this);
  TextStyle get titleAccent => UcashTypography.titleAccent(this);
  TextStyle get body => UcashTypography.body(this);
  TextStyle get bodySecondary => UcashTypography.bodySecondary(this);
  TextStyle get caption => UcashTypography.caption(this);
  TextStyle get button => UcashTypography.button(this);
  TextStyle get label => UcashTypography.label(this);
  TextStyle get statValue => UcashTypography.statValue(this);
  TextStyle get statLabel => UcashTypography.statLabel(this);
  TextStyle get navigation => UcashTypography.navigation(this);
  TextStyle get error => UcashTypography.error(this);
  TextStyle get success => UcashTypography.success(this);
  TextStyle get warning => UcashTypography.warning(this);
  
  TextStyle currency({bool isPositive = true}) => UcashTypography.currency(this, isPositive: isPositive);
  TextStyle get badge => UcashTypography.badge(this);
}
