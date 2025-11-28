import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service de gestion de la langue de l'application
/// 
/// Permet de:
/// - Stocker la préférence de langue de l'utilisateur (Français/Anglais)
/// - Persister le choix offline dans SharedPreferences
/// - Notifier les widgets lors du changement de langue
class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  static LanguageService get instance => _instance;
  
  LanguageService._internal();

  // Clé de stockage pour SharedPreferences
  static const String _languageKey = 'app_language';
  
  // Langue par défaut: Français (application initialement en français)
  static const Locale _defaultLocale = Locale('fr');
  
  // Langue actuelle
  Locale _currentLocale = _defaultLocale;
  
  /// Obtenir la langue actuelle
  Locale get currentLocale => _currentLocale;
  
  /// Vérifier si la langue actuelle est le français
  bool get isFrench => _currentLocale.languageCode == 'fr';
  
  /// Vérifier si la langue actuelle est l'anglais
  bool get isEnglish => _currentLocale.languageCode == 'en';
  
  /// Obtenir le code de langue actuel (pour affichage)
  String get currentLanguageCode => _currentLocale.languageCode;
  
  /// Obtenir le nom de la langue actuelle
  String get currentLanguageName {
    switch (_currentLocale.languageCode) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      default:
        return 'Français';
    }
  }

  /// Initialiser le service et charger la langue sauvegardée
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLanguage = prefs.getString(_languageKey);
      
      if (savedLanguage != null) {
        _currentLocale = Locale(savedLanguage);
        debugPrint('🌐 Langue chargée depuis le stockage: $savedLanguage');
      } else {
        debugPrint('🌐 Utilisation de la langue par défaut: ${_defaultLocale.languageCode}');
      }
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement de la langue: $e');
      _currentLocale = _defaultLocale;
    }
  }

  /// Changer la langue de l'application
  /// 
  /// [languageCode] - Code de la langue ('fr' ou 'en')
  /// Retourne true si le changement a réussi
  Future<bool> changeLanguage(String languageCode) async {
    try {
      // Valider le code de langue
      if (languageCode != 'fr' && languageCode != 'en') {
        debugPrint('⚠️ Code de langue invalide: $languageCode');
        return false;
      }
      
      // Vérifier si c'est déjà la langue actuelle
      if (_currentLocale.languageCode == languageCode) {
        debugPrint('ℹ️ La langue $languageCode est déjà sélectionnée');
        return true;
      }
      
      // Sauvegarder dans SharedPreferences (fonctionne offline)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_languageKey, languageCode);
      
      // Mettre à jour la langue actuelle
      _currentLocale = Locale(languageCode);
      
      // Notifier tous les widgets à l'écoute
      notifyListeners();
      
      debugPrint('✅ Langue changée vers: $languageCode');
      debugPrint('🌐 Nom de la langue: $currentLanguageName');
      
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors du changement de langue: $e');
      return false;
    }
  }

  /// Changer vers le français
  Future<bool> setFrench() async {
    return await changeLanguage('fr');
  }

  /// Changer vers l'anglais
  Future<bool> setEnglish() async {
    return await changeLanguage('en');
  }

  /// Basculer entre français et anglais
  Future<bool> toggleLanguage() async {
    final newLanguage = isFrench ? 'en' : 'fr';
    return await changeLanguage(newLanguage);
  }

  /// Réinitialiser à la langue par défaut
  Future<bool> resetToDefault() async {
    return await changeLanguage(_defaultLocale.languageCode);
  }

  /// Obtenir toutes les langues supportées
  static List<Locale> get supportedLocales => const [
    Locale('fr'), // Français
    Locale('en'), // English
  ];

  /// Obtenir les informations de toutes les langues disponibles
  static List<Map<String, String>> get availableLanguages => [
    {'code': 'fr', 'name': 'Français', 'flag': '🇫🇷'},
    {'code': 'en', 'name': 'English', 'flag': '🇬🇧'},
  ];
}
