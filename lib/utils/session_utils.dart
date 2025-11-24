import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/local_db.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';

class SessionUtils {
  /// Vérifie et restaure la session utilisateur avec une approche robuste
  static Future<bool> restoreUserSession() async {
    try {
      final user = await LocalDB.instance.getCurrentUser();
      if (user != null) {
        debugPrint('✅ Session utilisateur trouvée: ${user.username}');
        return true;
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la vérification de la session: $e');
    }
    return false;
  }

  /// Vérifie et restaure les données du shop avec une approche robuste
  static Future<ShopModel?> restoreShopData(int shopId) async {
    try {
      final shop = await LocalDB.instance.getShopById(shopId);
      if (shop != null) {
        debugPrint('✅ Données du shop restaurées: ${shop.designation}');
        return shop;
      } else {
        debugPrint('⚠️ Shop non trouvé dans la base locale (ID: $shopId)');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la restauration des données du shop: $e');
    }
    return null;
  }

  /// Sauvegarde les préférences de session de manière sécurisée
  static Future<void> saveSessionPreferences({
    required UserModel user,
    bool rememberMe = false,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Sauvegarder les préférences de base
      await prefs.setBool('is_logged_in', true);
      await prefs.setBool('remember_me', rememberMe);
      await prefs.setString('last_login', DateTime.now().toIso8601String());
      
      // Sauvegarder les informations utilisateur
      await prefs.setString('user_role', user.role.toLowerCase());
      if (user.shopId != null) {
        await prefs.setInt('current_shop_id', user.shopId!);
      } else {
        await prefs.remove('current_shop_id');
      }
      
      // Sauvegarder le nom d'utilisateur si "Se souvenir de moi" est activé
      if (rememberMe) {
        await prefs.setString('remembered_username', user.username);
      } else {
        await prefs.remove('remembered_username');
      }
      
      debugPrint('✅ Préférences de session sauvegardées');
    } catch (e) {
      debugPrint('❌ Erreur lors de la sauvegarde des préférences de session: $e');
      rethrow;
    }
  }

  /// Efface toutes les données de session de manière sécurisée
  static Future<void> clearAllSessionData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Liste des clés à effacer
      final sessionKeys = [
        'is_logged_in',
        'last_login',
        'remember_me',
        'remembered_username',
        'user_role',
        'current_shop_id',
        'current_user',
        'is_client_logged_in',
        'client_id',
        'client_username',
        'last_client_login',
      ];
      
      // Effacer toutes les clés de session
      for (final key in sessionKeys) {
        try {
          await prefs.remove(key);
        } catch (e) {
          debugPrint('⚠️ Erreur lors de l\'effacement de la clé $key: $e');
        }
      }
      
      debugPrint('✅ Toutes les données de session ont été effacées');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'effacement des données de session: $e');
      rethrow;
    }
  }

  /// Vérifie l'intégrité des données de session
  static Future<bool> checkSessionIntegrity() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Vérifier si l'utilisateur est connecté
      final isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      if (!isLoggedIn) {
        debugPrint('ℹ️ Aucun utilisateur connecté');
        return true; // Pas d'erreur, juste pas de session
      }
      
      // Vérifier les données utilisateur
      final userJson = prefs.getString('current_user');
      if (userJson == null || userJson.isEmpty) {
        debugPrint('⚠️ Données utilisateur manquantes dans la session');
        return false;
      }
      
      // Tenter de parser les données utilisateur
      try {
        final userData = jsonDecode(userJson);
        final user = UserModel.fromJson(userData);
        
        // Si l'utilisateur a un shop, vérifier que le shop existe
        if (user.shopId != null) {
          final shop = await LocalDB.instance.getShopById(user.shopId!);
          if (shop == null) {
            debugPrint('⚠️ Shop associé non trouvé (ID: ${user.shopId})');
            return false;
          }
        }
        
        debugPrint('✅ Intégrité de la session vérifiée avec succès');
        return true;
      } catch (e) {
        debugPrint('❌ Données utilisateur corrompues: $e');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification de l\'intégrité de la session: $e');
      return false;
    }
  }

  /// Tente de récupérer une session corrompue
  static Future<bool> recoverCorruptedSession() async {
    try {
      debugPrint('🔄 Tentative de récupération de session corrompue...');
      
      // Effacer les données corrompues
      await clearAllSessionData();
      
      // Réinitialiser l'état de l'application
      debugPrint('✅ Session corrompue récupérée - déconnexion effectuée');
      return true;
    } catch (e) {
      debugPrint('❌ Échec de la récupération de session corrompue: $e');
      return false;
    }
  }
}