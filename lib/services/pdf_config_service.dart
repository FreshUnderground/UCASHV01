import 'package:shared_preferences/shared_preferences.dart';

/// Service pour gérer la configuration des en-têtes PDF
class PdfConfigService {
  static const String _keyCompanyName = 'pdf_company_name';
  static const String _keyCompanyAddress = 'pdf_company_address';
  static const String _keyCompanyPhone = 'pdf_company_phone';
  static const String _keyFooterMessage = 'pdf_footer_message';
  
  /// Nom de l'entreprise par défaut
  static const String defaultCompanyName = 'UCASH';
  
  /// Message de pied de page par défaut
  static const String defaultFooterMessage = 'Merci de votre confiance';

  /// Récupère le nom de l'entreprise
  static Future<String> getCompanyName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCompanyName) ?? defaultCompanyName;
  }

  /// Sauvegarde le nom de l'entreprise
  static Future<void> setCompanyName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompanyName, name);
  }

  /// Récupère l'adresse de l'entreprise
  static Future<String> getCompanyAddress() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCompanyAddress) ?? '';
  }

  /// Sauvegarde l'adresse de l'entreprise
  static Future<void> setCompanyAddress(String address) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompanyAddress, address);
  }

  /// Récupère le téléphone de l'entreprise
  static Future<String> getCompanyPhone() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCompanyPhone) ?? '';
  }

  /// Sauvegarde le téléphone de l'entreprise
  static Future<void> setCompanyPhone(String phone) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCompanyPhone, phone);
  }

  /// Récupère le message de pied de page
  static Future<String> getFooterMessage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyFooterMessage) ?? defaultFooterMessage;
  }

  /// Sauvegarde le message de pied de page
  static Future<void> setFooterMessage(String message) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyFooterMessage, message);
  }

  /// Réinitialise toutes les configurations par défaut
  static Future<void> resetToDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyCompanyName);
    await prefs.remove(_keyCompanyAddress);
    await prefs.remove(_keyCompanyPhone);
    await prefs.remove(_keyFooterMessage);
  }

  /// Récupère toutes les configurations
  static Future<Map<String, String>> getAllConfig() async {
    return {
      'companyName': await getCompanyName(),
      'companyAddress': await getCompanyAddress(),
      'companyPhone': await getCompanyPhone(),
      'footerMessage': await getFooterMessage(),
    };
  }

  /// Sauvegarde toutes les configurations
  static Future<void> saveAllConfig({
    required String companyName,
    required String companyAddress,
    required String companyPhone,
    required String footerMessage,
  }) async {
    await setCompanyName(companyName);
    await setCompanyAddress(companyAddress);
    await setCompanyPhone(companyPhone);
    await setFooterMessage(footerMessage);
  }
}
