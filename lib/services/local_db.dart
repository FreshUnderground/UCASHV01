import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../models/client_model.dart';
import '../models/transaction_model.dart';
import '../models/caisse_model.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/cloture_caisse_model.dart';
import '../models/sim_model.dart';
import '../models/sim_movement_model.dart';
import '../models/virtual_transaction_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../models/cloture_virtuelle_model.dart';
import '../models/depot_client_model.dart';

class LocalDB {
  static final LocalDB _instance = LocalDB._internal();
  static SharedPreferences? _prefs;

  LocalDB._internal();

  static LocalDB get instance => _instance;

  Future<SharedPreferences> get database async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  // Générer un ID séquentiel au lieu d'un timestamp
  Future<int> _generateSequentialId(String prefix) async {
    final prefs = await database;
    final keys = prefs.getKeys().where((key) => key.startsWith(prefix)).toList();
    
    if (keys.isEmpty) {
      return 1; // Premier ID
    }
    
    // Trouver le plus grand ID existant
    int maxId = 0;
    for (var key in keys) {
      final idStr = key.replaceFirst(prefix, '');
      final id = int.tryParse(idStr) ?? 0;
      if (id > maxId) maxId = id;
    }
    
    return maxId + 1; // Prochain ID
  }

  // === CRUD SHOPS ===
  Future<void> saveShop(ShopModel shop) async {
    final prefs = await database;
    final shopId = shop.id ?? await _generateSequentialId('shop_');
    final updatedShop = shop.copyWith(id: shopId);
    final key = 'shop_$shopId';
    final jsonData = updatedShop.toJson();
    
    debugPrint('💾 Sauvegarde shop: $key');
    debugPrint('📄 Données: ${jsonEncode(jsonData)}');
    
    await prefs.setString(key, jsonEncode(jsonData));
    
    // Vérifier que la sauvegarde a fonctionné
    final saved = prefs.getString(key);
    if (saved != null) {
      debugPrint('✅ Shop sauvegardé avec succès: ${updatedShop.designation} (ID: $shopId)');
    } else {
      debugPrint('❌ Échec de la sauvegarde du shop dans SharedPreferences');
    }
  }

  Future<void> updateShop(ShopModel shop) async {
    if (shop.id == null) throw Exception('Shop ID is required for update');
    await saveShop(shop);
  }

  Future<void> deleteShop(int shopId) async {
    final prefs = await database;
    await prefs.remove('shop_$shopId');
  }

  // === CRUD AGENTS (Legacy - UserModel) ===
  Future<void> saveAgentLegacy(UserModel agent) async {
    final prefs = await database;
    final agentId = agent.id ?? await _generateSequentialId('agent_legacy_');
    final updatedAgent = agent.copyWith(id: agentId);
    await prefs.setString('agent_legacy_$agentId', jsonEncode(updatedAgent.toJson()));
  }

  Future<void> updateAgentLegacy(UserModel agent) async {
    if (agent.id == null) throw Exception('Agent ID is required for update');
    await saveAgentLegacy(agent);
  }

  Future<void> deleteAgentLegacy(int agentId) async {
    final prefs = await database;
    await prefs.remove('agent_legacy_$agentId');
  }

  // === CRUD CAISSES ===
  Future<void> saveCaisse(CaisseModel caisse) async {
    final prefs = await database;
    final caisseId = caisse.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedCaisse = caisse.copyWith(id: caisseId);
    await prefs.setString('caisse_$caisseId', jsonEncode(updatedCaisse.toJson()));
  }

  Future<void> updateCaisse(CaisseModel caisse) async {
    if (caisse.id == null) throw Exception('Caisse ID is required for update');
    await saveCaisse(caisse);
  }

  Future<List<CaisseModel>> getCaissesByShop(int shopId) async {
    final prefs = await database;
    final caisses = <CaisseModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('caisse_')) {
        final caisseData = prefs.getString(key);
        if (caisseData != null) {
          final caisse = CaisseModel.fromJson(jsonDecode(caisseData));
          if (caisse.shopId == shopId) {
            caisses.add(caisse);
          }
        }
      }
    }
    return caisses;
  }

  // === CRUD TAUX ===
  Future<void> saveTaux(TauxModel taux) async {
    final prefs = await database;
    final tauxId = taux.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedTaux = taux.copyWith(id: tauxId);
    await prefs.setString('taux_$tauxId', jsonEncode(updatedTaux.toJson()));
  }

  Future<void> updateTaux(TauxModel taux) async {
    if (taux.id == null) throw Exception('Taux ID is required for update');
    await saveTaux(taux);
  }

  Future<void> deleteTaux(int tauxId) async {
    final prefs = await database;
    await prefs.remove('taux_$tauxId');
  }

  Future<List<TauxModel>> getAllTaux() async {
    final prefs = await database;
    final taux = <TauxModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('taux_')) {
        final tauxData = prefs.getString(key);
        if (tauxData != null) {
          taux.add(TauxModel.fromJson(jsonDecode(tauxData)));
        }
      }
    }
    return taux;
  }

  // === CRUD COMMISSIONS ===
  Future<void> saveCommission(CommissionModel commission) async {
    final prefs = await database;
    final commissionId = commission.id ?? await _generateSequentialId('commission_');
    final updatedCommission = commission.copyWith(id: commissionId);
    
    await prefs.setString('commission_$commissionId', jsonEncode(updatedCommission.toJson()));
  }

  Future<void> updateCommission(CommissionModel commission) async {
    if (commission.id == null) throw Exception('Commission ID is required for update');
    await saveCommission(commission);
  }

  Future<void> deleteCommission(int commissionId) async {
    final prefs = await database;
    await prefs.remove('commission_$commissionId');
  }

  Future<List<CommissionModel>> getAllCommissions() async {
    final prefs = await database;
    final commissions = <CommissionModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('commission_')) {
        final commissionData = prefs.getString(key);
        if (commissionData != null) {
          commissions.add(CommissionModel.fromJson(jsonDecode(commissionData)));
        }
      }
    }
    
    return commissions;
  }

  // Méthodes pour créer de nouveaux utilisateurs (compatibilité)
  Future<void> createAgent(String username, String password, int shopId) async {
    final agent = UserModel(
      username: username,
      password: password,
      role: 'AGENT',
      shopId: shopId,
      createdAt: DateTime.now(),
    );
    await saveAgentLegacy(agent);
  }

  Future<void> createCompte(String username, String password) async {
    final compte = UserModel(
      username: username,
      password: password,
      role: 'COMPTE',
      createdAt: DateTime.now(),
    );
    await saveAgentLegacy(compte);
  }

  Future<void> createShop(String designation, String localisation, double capitalInitial, 
      {double capitalCash = 0.0, double capitalAirtelMoney = 0.0, double capitalMPesa = 0.0, double capitalOrangeMoney = 0.0}) async {
    final shop = ShopModel(
      designation: designation,
      localisation: localisation,
      capitalInitial: capitalInitial,
      capitalActuel: capitalInitial,
      capitalCash: capitalCash,
      capitalAirtelMoney: capitalAirtelMoney,
      capitalMPesa: capitalMPesa,
      capitalOrangeMoney: capitalOrangeMoney,
      createdAt: DateTime.now(),
      // Marquer comme non synchronisé pour forcer l'upload
      isSynced: false,
      lastModifiedAt: DateTime.now(),
      lastModifiedBy: 'local_user',
    );
    await saveShop(shop);
  }

  // Récupérer l'utilisateur actuellement connecté
  Future<UserModel?> getCurrentUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString('current_user');
      if (userJson != null && userJson.isNotEmpty) {
        final userData = json.decode(userJson);
        return UserModel.fromJson(userData);
      }
    } catch (e) {
      debugPrint('Erreur lors de la récupération de l\'utilisateur: $e');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('current_user');
    }
    return null;
  }

  // Sauvegarder la session utilisateur
  Future<void> saveUserSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_user', jsonEncode(user.toJson()));
  }

  // Effacer la session
  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_user');
  }


  // ===== GESTION DES ADMINISTRATEURS (MAX 2) =====
  
  static const int maxAdmins = 2;
  
  // Récupérer tous les admins (sans l'admin par défaut temporaire)
  Future<List<UserModel>> getAllAdmins() async {
    final prefs = await database;
    final admins = <UserModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('admin_') && key != 'admin_default_temp') {
        final adminData = prefs.getString(key);
        if (adminData != null) {
          try {
            final admin = UserModel.fromJson(jsonDecode(adminData));
            if (admin.role == 'ADMIN') {
              admins.add(admin);
            }
          } catch (e) {
            debugPrint('Erreur lors de la lecture de l\'admin $key: $e');
          }
        }
      }
    }
    return admins;
  }
  
  // Compter le nombre d'admins
  Future<int> countAdmins() async {
    final admins = await getAllAdmins();
    return admins.length;
  }
  
  // Vérifier si on peut créer un nouvel admin
  Future<bool> canCreateAdmin() async {
    final count = await countAdmins();
    return count < maxAdmins;
  }
  
  // Créer un nouvel administrateur
  Future<Map<String, dynamic>> createAdmin({
    required String username,
    required String password,
    String? nom,
    String? telephone,
    String? email,
  }) async {
    try {
      // Vérifier le nombre maximum
      final canCreate = await canCreateAdmin();
      if (!canCreate) {
        return {
          'success': false,
          'message': 'Nombre maximum d\'administrateurs atteint (2 max)'
        };
      }
      
      // Vérifier si le username existe déjà
      final existingAdmin = await getAdminByUsername(username);
      if (existingAdmin != null) {
        return {
          'success': false,
          'message': 'Ce nom d\'utilisateur existe déjà'
        };
      }
      
      final prefs = await database;
      final admins = await getAllAdmins();
      
      // Générer un ID unique (basé sur le nombre d'admins)
      final newId = admins.isEmpty ? 1 : (admins.map((a) => a.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
      
      final newAdmin = UserModel(
        id: newId,
        username: username,
        password: password,
        role: 'ADMIN',
        nom: nom,
        telephone: telephone,
        shopId: null, // Admin n'a pas besoin de shop
        createdAt: DateTime.now(),
      );
      
      // Sauvegarder localement
      await prefs.setString('admin_$newId', jsonEncode(newAdmin.toJson()));
      
      // Supprimer l'admin par défaut si c'est le premier admin personnalisé créé
      await _removeDefaultAdminIfNeeded();
      
      debugPrint('✅ Admin créé: $username (ID: $newId)');
      
      return {
        'success': true,
        'message': 'Administrateur créé avec succès',
        'admin': newAdmin
      };
    } catch (e) {
      debugPrint('❌ Erreur lors de la création de l\'admin: $e');
      return {
        'success': false,
        'message': 'Erreur: $e'
      };
    }
  }
  
  // Récupérer un admin par username
  Future<UserModel?> getAdminByUsername(String username) async {
    final admins = await getAllAdmins();
    try {
      return admins.firstWhere((admin) => admin.username == username);
    } catch (e) {
      return null;
    }
  }
  
  // Récupérer un admin par ID
  Future<UserModel?> getAdminById(int id) async {
    final prefs = await database;
    final adminData = prefs.getString('admin_$id');
    if (adminData != null) {
      try {
        return UserModel.fromJson(jsonDecode(adminData));
      } catch (e) {
        debugPrint('Erreur lors de la récupération de l\'admin $id: $e');
      }
    }
    return null;
  }
  
  // Mettre à jour un admin
  Future<Map<String, dynamic>> updateAdmin(UserModel admin) async {
    try {
      if (admin.id == null) {
        return {
          'success': false,
          'message': 'ID de l\'administrateur manquant'
        };
      }
      
      final prefs = await database;
      await prefs.setString('admin_${admin.id}', jsonEncode(admin.toJson()));
      
      debugPrint('✅ Admin mis à jour: ${admin.username}');
      
      return {
        'success': true,
        'message': 'Administrateur mis à jour avec succès'
      };
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour de l\'admin: $e');
      return {
        'success': false,
        'message': 'Erreur: $e'
      };
    }
  }
  
  // Supprimer un admin
  Future<Map<String, dynamic>> deleteAdmin(int id) async {
    try {
      final admins = await getAllAdmins();
      
      // Empêcher la suppression s'il ne reste qu'un seul admin
      if (admins.length <= 1) {
        return {
          'success': false,
          'message': 'Impossible de supprimer le dernier administrateur'
        };
      }
      
      final prefs = await database;
      await prefs.remove('admin_$id');
      
      debugPrint('✅ Admin supprimé: ID $id');
      
      return {
        'success': true,
        'message': 'Administrateur supprimé avec succès'
      };
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression de l\'admin: $e');
      return {
        'success': false,
        'message': 'Erreur: $e'
      };
    }
  }
  
  // Initialiser l'admin par défaut (PROTÉGÉ)
  Future<void> initializeDefaultAdmin() async {
    final prefs = await database;
    
    // Vérifier si un admin existe déjà
    final admins = await getAllAdmins();
    if (admins.isEmpty) {
      final admin = UserModel(
        id: 0, // ID spécial pour l'admin par défaut
        username: 'admin',
        password: 'admin123',
        role: 'ADMIN',
        shopId: null,
        createdAt: DateTime.now(),
      );
      await prefs.setString('admin_default_temp', jsonEncode(admin.toJson()));
      debugPrint('🔐 Admin par défaut temporaire créé: admin/admin123 (sera supprimé après création du premier admin)');
    } else {
      debugPrint('🔐 Admin(s) déjà présent(s): ${admins.length}');
    }
  }

  // Vérifier et restaurer l'admin si nécessaire
  Future<void> ensureAdminExists() async {
    final admins = await getAllAdmins();
    if (admins.isEmpty) {
      debugPrint('⚠️  Aucun admin trouvé ! Création de l\'admin par défaut...');
      await initializeDefaultAdmin();
    }
  }

  // Récupérer l'admin par défaut (le premier admin ou l'admin temporaire)
  Future<UserModel?> getDefaultAdmin() async {
    final admins = await getAllAdmins();
    if (admins.isNotEmpty) {
      return admins.first;
    }
    
    // Si aucun admin personnalisé, vérifier l'admin temporaire
    final prefs = await database;
    final tempAdminData = prefs.getString('admin_default_temp');
    if (tempAdminData != null) {
      try {
        return UserModel.fromJson(jsonDecode(tempAdminData));
      } catch (e) {
        debugPrint('Erreur lors de la récupération de l\'admin temporaire: $e');
      }
    }
    return null;
  }

  // Vérifier si les données par défaut ont été initialisées
  Future<bool> isDefaultDataInitialized() async {
    final prefs = await database;
    return prefs.getBool('default_data_initialized') ?? false;
  }

  // Marquer les données par défaut comme initialisées
  Future<void> markDefaultDataInitialized() async {
    final prefs = await database;
    await prefs.setBool('default_data_initialized', true);
  }

  // Forcer la création de l'admin (même s'il existe)
  Future<void> forceCreateAdmin() async {
    final prefs = await database;
    
    final admin = UserModel(
      id: 1,
      username: 'admin',
      password: 'admin123',
      role: 'ADMIN',
      shopId: null,
    );
    await prefs.setString('agent_admin', jsonEncode(admin.toJson()));
    debugPrint('Admin forcé créé: admin/admin123');
  }

  // Réinitialiser complètement la base de données
  Future<void> resetDatabase() async {
    final prefs = await database;
    await prefs.clear();
    await forceCreateAdmin();
    debugPrint('Base de données réinitialisée avec admin par défaut');
  }

  // Supprimer toutes les données sauf l'admin
  Future<void> clearAllDataExceptAdmin() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    
    for (String key in keys) {
      // Garder seulement l'admin et les données de session
      if (!key.startsWith('agent_admin') && 
          !key.startsWith('current_user') && 
          !key.startsWith('user_session')) {
        await prefs.remove(key);
      }
    }
    
    debugPrint('Toutes les données supprimées sauf l\'admin');
  }

  // Supprimer l'admin par défaut temporaire si un admin personnalisé existe
  Future<void> _removeDefaultAdminIfNeeded() async {
    final prefs = await database;
    final tempAdminData = prefs.getString('admin_default_temp');
    
    if (tempAdminData != null) {
      await prefs.remove('admin_default_temp');
      debugPrint('🗑️ Admin par défaut temporaire supprimé (admin personnalisé créé)');
    }
  }
  
  // Nettoyer l'admin par défaut au démarrage de la session
  Future<void> cleanupDefaultAdminOnStartup() async {
    final admins = await getAllAdmins();
    if (admins.isNotEmpty) {
      // Il y a au moins un admin personnalisé, supprimer l'admin temporaire
      await _removeDefaultAdminIfNeeded();
    }
  }

  // Méthodes pour les agents
  Future<UserModel?> getAgentByCredentials(String username, String password) async {
    // Vérifier d'abord dans les admins personnalisés
    final admins = await getAllAdmins();
    for (var admin in admins) {
      if (admin.username == username && admin.password == password) {
        return admin;
      }
    }
    
    // Vérifier l'admin par défaut temporaire
    final prefs = await database;
    final tempAdminData = prefs.getString('admin_default_temp');
    if (tempAdminData != null) {
      try {
        final tempAdmin = UserModel.fromJson(jsonDecode(tempAdminData));
        if (tempAdmin.username == username && tempAdmin.password == password) {
          return tempAdmin;
        }
      } catch (e) {
        debugPrint('Erreur lors de la lecture de l\'admin temporaire: $e');
      }
    }
    
    // Chercher dans les agents
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('agent_') && !key.startsWith('admin_')) {
        final agentData = prefs.getString(key);
        if (agentData != null) {
          final agent = UserModel.fromJson(jsonDecode(agentData));
          if (agent.username == username && agent.password == password) {
            return agent;
          }
        }
      }
    }
    return null;
  }

  Future<List<UserModel>> getAllAgentsLegacy() async {
    final prefs = await database;
    final agents = <UserModel>[];
    
    // Chercher tous les agents stockés dynamiquement
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('agent_legacy_')) {
        final agentData = prefs.getString(key);
        if (agentData != null) {
          agents.add(UserModel.fromJson(jsonDecode(agentData)));
        }
      }
    }
    return agents;
  }

  // Méthodes pour les comptes
  Future<UserModel?> getCompteByCredentials(String username, String password) async {
    final prefs = await database;
    
    // Chercher tous les comptes stockés dynamiquement
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('compte_')) {
        final compteData = prefs.getString(key);
        if (compteData != null) {
          final compte = UserModel.fromJson(jsonDecode(compteData));
          if (compte.username == username && compte.password == password) {
            return compte;
          }
        }
      }
    }
    return null;
  }

  Future<List<UserModel>> getAllComptes() async {
    final prefs = await database;
    final comptes = <UserModel>[];
    
    // Chercher tous les comptes stockés dynamiquement
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('compte_')) {
        final compteData = prefs.getString(key);
        if (compteData != null) {
          comptes.add(UserModel.fromJson(jsonDecode(compteData)));
        }
      }
    }
    return comptes;
  }


  // Récupérer les shops
  Future<List<ShopModel>> getAllShops() async {
    final prefs = await database;
    final shops = <ShopModel>[];
    
    final keys = prefs.getKeys();
    final shopKeys = keys.where((key) => key.startsWith('shop_')).toList();
    
    for (String key in shopKeys) {
      final shopData = prefs.getString(key);
      if (shopData != null) {
        try {
          final shop = ShopModel.fromJson(jsonDecode(shopData));
          shops.add(shop);
        } catch (e) {
          debugPrint('❌ Erreur parsing shop $key: $e');
        }
      }
    }
    
    return shops;
  }

  // === CRUD AGENTS (Module Agent) ===
  Future<AgentModel> saveAgent(AgentModel agent) async {
    final prefs = await database;
    final agentId = agent.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedAgent = agent.copyWith(
      id: agentId,
      lastModifiedAt: DateTime.now(),
    );
    
    final jsonData = updatedAgent.toJson();
    final key = 'agent_$agentId';
    
    debugPrint('💾 Sauvegarde agent: $key');
    debugPrint('📄 Données: ${jsonEncode(jsonData)}');
    
    await prefs.setString(key, jsonEncode(jsonData));
    
    // Vérifier que la sauvegarde a fonctionné
    final saved = prefs.getString(key);
    if (saved != null) {
      debugPrint('✅ Agent sauvegardé avec succès dans SharedPreferences');
    } else {
      debugPrint('❌ Échec de la sauvegarde dans SharedPreferences');
    }
    
    return updatedAgent;
  }

  Future<void> updateAgent(AgentModel agent) async {
    if (agent.id == null) throw Exception('Agent ID is required for update');
    
    // Forcer la mise à jour en marquant lastModifiedAt
    final updatedAgent = agent.copyWith(
      lastModifiedAt: DateTime.now(),
    );
    
    debugPrint('🔄 [LocalDB] Mise à jour agent ID: ${agent.id}, Username: ${agent.username}');
    await saveAgent(updatedAgent);
    
    // Vérifier immédiatement que la mise à jour a été faite
    final prefs = await database;
    final saved = prefs.getString('agent_${agent.id}');
    if (saved != null) {
      final savedData = jsonDecode(saved);
      debugPrint('✅ [LocalDB] Agent mis à jour - Username: ${savedData['username']}');
    }
  }

  Future<void> deleteAgent(int agentId) async {
    final prefs = await database;
    await prefs.remove('agent_$agentId');
  }

  Future<List<AgentModel>> getAllAgents() async {
    final prefs = await database;
    final agents = <AgentModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('agent_')) {
        try {
          final agentData = prefs.getString(key);
          if (agentData != null) {
            final agentJson = jsonDecode(agentData);
            
            // Vérifier que les champs obligatoires sont présents
            if (agentJson['id'] != null && 
                agentJson['username'] != null) {
              agents.add(AgentModel.fromJson(agentJson));
            } else {
              // Supprimer les données corrompues
              await prefs.remove(key);
            }
          }
        } catch (e) {
          // En cas d'erreur de parsing, supprimer la donnée corrompue
          await prefs.remove(key);
        }
      }
    }
    return agents;
  }

  // Mettre à jour le mot de passe d'un agent
  Future<void> updateAgentPassword(int agentId, String newPassword) async {
    final prefs = await database;
    final key = 'agent_$agentId';
    
    final agentData = prefs.getString(key);
    if (agentData != null) {
      final agentJson = jsonDecode(agentData);
      agentJson['password'] = newPassword;
      agentJson['last_modified_at'] = DateTime.now().toIso8601String();
      
      await prefs.setString(key, jsonEncode(agentJson));
      debugPrint('✅ Mot de passe mis à jour pour agent ID: $agentId');
    } else {
      throw Exception('Agent non trouvé: $agentId');
    }
  }

  // === CRUD CLIENTS ===
  Future<ClientModel> saveClient(ClientModel client) async {
    final prefs = await database;
    final clientId = client.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedClient = client.copyWith(
      id: clientId,
      lastModifiedAt: DateTime.now(),
    );
    await prefs.setString('client_$clientId', jsonEncode(updatedClient.toJson()));
    return updatedClient;
  }

  Future<void> updateClient(ClientModel client) async {
    if (client.id == null) throw Exception('Client ID is required for update');
    await saveClient(client);
  }

  Future<void> deleteClient(int clientId) async {
    final prefs = await database;
    await prefs.remove('client_$clientId');
  }
  Future<List<ClientModel>> getAllClients() async {
    final prefs = await database;
    final clients = <ClientModel>[];
    
    final keys = prefs.getKeys().where((key) => key.startsWith('client_'));
    for (final key in keys) {
      final clientJson = prefs.getString(key);
      if (clientJson != null) {
        try {
          final clientData = jsonDecode(clientJson);
          clients.add(ClientModel.fromJson(clientData));
        } catch (e) {
          debugPrint('Erreur lors du parsing du client $key: $e');
        }
      }
    }
    
    return clients;
  }

  Future<ClientModel?> getClientById(int clientId) async {
    final prefs = await database;
    final clientJson = prefs.getString('client_$clientId');
    if (clientJson != null) {
      try {
        final clientData = jsonDecode(clientJson);
        return ClientModel.fromJson(clientData);
      } catch (e) {
        debugPrint('Erreur lors du parsing du client $clientId: $e');
        return null;
      }
    }
    return null;
  }

  Future<ShopModel?> getShopById(int shopId) async {
    final prefs = await database;
    final shopJson = prefs.getString('shop_$shopId');
    if (shopJson != null) {
      try {
        final shopData = jsonDecode(shopJson);
        return ShopModel.fromJson(shopData);
      } catch (e) {
        debugPrint('Erreur lors du parsing du shop $shopId: $e');
        return null;
      }
    }
    return null;
  }

  Future<List<ClientModel>> getClientsByShop(int shopId) async {
    final allClients = await getAllClients();
    return allClients.where((client) => client.shopId == shopId).toList();
  }
  // === CRUD OPERATIONS ===
  /// Sauvegarde une opération localement
  /// Utilise code_ops comme clé unique pour éviter les doublons
  /// Si une opération avec le même code_ops existe, elle est écrasée
  Future<OperationModel> saveOperation(OperationModel operation) async {
    final prefs = await database;
    
    // IMPORTANT: Vérifier si une opération avec le même code_ops existe déjà
    final existingOp = await getOperationByCodeOps(operation.codeOps);
    
    // Si l'opération existe déjà, utiliser son ID et écraser les données
    // Sinon, générer un nouvel ID
    final operationId = existingOp?.id ?? operation.id ?? DateTime.now().millisecondsSinceEpoch;
    
    final updatedOperation = operation.copyWith(
      id: operationId,
      lastModifiedAt: DateTime.now(),
    );
    
    // Log pour les opérations de capital initial
    if (operation.destinataire == 'CAPITAL INITIAL') {
      debugPrint('💰 saveOperation: Enregistrement opération de capital initial ID $operationId');
      debugPrint('   Montant: ${operation.montantNet} USD');
      debugPrint('   Shop source: ${operation.shopSourceId}');
      debugPrint('   Statut: ${operation.statut.name}');
    }
    
    if (existingOp != null) {
      // ÉCRASER l'opération existante avec les nouvelles données
      debugPrint('🔄 Opération ${operation.codeOps} existe déjà (ID: $operationId) - ÉCRASEMENT des données');
      
      // Supprimer l'ancienne clé si elle existe
      await prefs.remove('operation_${existingOp.id}');
    }
    
    // Sauvegarder avec la clé operation_ID
    await prefs.setString('operation_$operationId', jsonEncode(updatedOperation.toJson()));
    
    // Confirmation de sauvegarde
    if (operation.destinataire == 'CAPITAL INITIAL') {
      debugPrint('✅ saveOperation: Opération de capital initial ID $operationId sauvegardée avec succès');
    } else if (existingOp != null) {
      debugPrint('✅ Opération ${operation.codeOps} mise à jour avec succès (ID: $operationId)');
    } else {
      debugPrint('✅ Opération ${operation.codeOps} créée avec succès (ID: $operationId)');
    }
    
    return updatedOperation;
  }

  Future<void> updateOperation(OperationModel operation) async {
    if (operation.id == null) throw Exception('Operation ID is required for update');
    await saveOperation(operation);
  }
  
  /// Update operation by CodeOps (unique identifier - more reliable than ID)
  Future<void> updateOperationByCodeOps(OperationModel operation) async {
    // First, find the operation by CodeOps to get its ID
    final existingOp = await getOperationByCodeOps(operation.codeOps);
    if (existingOp == null) {
      throw Exception('Operation not found with CodeOps: ${operation.codeOps}');
    }
    
    // Update using the existing ID
    final operationWithId = operation.copyWith(id: existingOp.id);
    await saveOperation(operationWithId);
  }

  Future<void> deleteOperation(int operationId) async {
    final prefs = await database;
    await prefs.remove('operation_$operationId');
  }

  Future<List<OperationModel>> getAllOperations() async {
    final prefs = await database;
    final operations = <OperationModel>[];
    
    final keys = prefs.getKeys();
    int initialCapitalCount = 0;
    
    for (String key in keys) {
      if (key.startsWith('operation_')) {
        final operationData = prefs.getString(key);
        if (operationData != null) {
          final operation = OperationModel.fromJson(jsonDecode(operationData));
          operations.add(operation);
          
          // Compter et logger les opérations de capital initial
          if (operation.destinataire == 'CAPITAL INITIAL') {
            initialCapitalCount++;
            debugPrint('💰 getAllOperations: Opération de capital initial trouvée - ID ${operation.id}, Montant: ${operation.montantNet} USD');
          }
        }
      }
    }
    
    if (initialCapitalCount > 0) {
      debugPrint('💰 getAllOperations: $initialCapitalCount opérations de capital initial chargées');
    }
    
    return operations;
  }

  Future<List<OperationModel>> getOperationsByAgent(int agentId) async {
    final allOperations = await getAllOperations();
    return allOperations.where((op) => op.agentId == agentId).toList();
  }

  Future<List<OperationModel>> getOperationsByShop(int shopId) async {
    final allOperations = await getAllOperations();
    return allOperations.where((op) => 
      op.shopSourceId == shopId || op.shopDestinationId == shopId).toList();
  }

  Future<OperationModel?> getOperationByCodeOps(String codeOps) async {
    final allOperations = await getAllOperations();
    try {
      return allOperations.firstWhere((op) => op.codeOps == codeOps);
    } catch (e) {
      return null; // Not found
    }
  }
  
  Future<OperationModel?> getOperationById(int operationId) async {
    final prefs = await database;
    final operationJson = prefs.getString('operation_$operationId');
    if (operationJson != null) {
      try {
        final operationData = jsonDecode(operationJson);
        return OperationModel.fromJson(operationData);
      } catch (e) {
        debugPrint('Erreur lors du parsing de l\'operation $operationId: $e');
        return null;
      }
    }
    return null;
  }

  // === CRUD JOURNAL DE CAISSE ===
  Future<JournalCaisseModel> saveJournalEntry(JournalCaisseModel entry) async {
    final prefs = await database;
    final entryId = entry.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedEntry = entry.copyWith(
      id: entryId,
      lastModifiedAt: DateTime.now(),
    );
    await prefs.setString('journal_$entryId', jsonEncode(updatedEntry.toJson()));
    return updatedEntry;
  }

  Future<void> updateJournalEntry(JournalCaisseModel entry) async {
    if (entry.id == null) throw Exception('Journal entry ID is required for update');
    await saveJournalEntry(entry);
  }

  Future<void> deleteJournalEntry(int entryId) async {
    final prefs = await database;
    await prefs.remove('journal_$entryId');
  }

  Future<List<JournalCaisseModel>> getAllJournalEntries() async {
    final prefs = await database;
    final entries = <JournalCaisseModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('journal_')) {
        final entryData = prefs.getString(key);
        if (entryData != null) {
          entries.add(JournalCaisseModel.fromJson(jsonDecode(entryData)));
        }
      }
    }
    return entries;
  }

  Future<List<JournalCaisseModel>> getJournalEntriesByShop(int shopId) async {
    final allEntries = await getAllJournalEntries();
    return allEntries.where((entry) => entry.shopId == shopId).toList();
  }

  Future<List<JournalCaisseModel>> getJournalEntriesByAgent(int agentId) async {
    final allEntries = await getAllJournalEntries();
    return allEntries.where((entry) => entry.agentId == agentId).toList();
  }

  // === MÉTHODES UTILITAIRES ===
  Future<void> clearAllData() async {
    final prefs = await database;
    await prefs.clear();
  }

  Future<void> clearAgentData() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('agent_') || 
          key.startsWith('client_') || 
          key.startsWith('operation_') || 
          key.startsWith('journal_')) {
        await prefs.remove(key);
      }
    }
  }

  // Nettoyer les données corrompues d'agents
  Future<void> cleanCorruptedAgentData() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    int cleaned = 0;
    
    for (String key in keys) {
      if (key.startsWith('agent_')) {
        try {
          final agentData = prefs.getString(key);
          if (agentData != null) {
            final agentJson = jsonDecode(agentData);
            
            // Vérifier les champs obligatoires
            if (agentJson['id'] == null || 
                agentJson['username'] == null || 
                (agentJson['shop_id'] == null && agentJson['shopId'] == null)) {
              await prefs.remove(key);
              cleaned++;
            }
          }
        } catch (e) {
          await prefs.remove(key);
          cleaned++;
        }
      }
    }
    
    if (cleaned > 0) {
      debugPrint('🧹 Nettoyage terminé: $cleaned données d\'agents corrompues supprimées');
    }
  }

  // Debug: Lister tous les agents dans SharedPreferences
  Future<void> debugListAllAgents() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    final agentKeys = keys.where((key) => key.startsWith('agent_')).toList();
    
    debugPrint('🔍 Debug: ${agentKeys.length} clés d\'agents trouvées dans SharedPreferences:');
    for (String key in agentKeys) {
      final data = prefs.getString(key);
      if (data != null) {
        try {
          final json = jsonDecode(data);
          debugPrint('   $key: ${json['username']} (ID: ${json['id']}, Shop: ${json['shop_id'] ?? json['shopId']})');
        } catch (e) {
          debugPrint('   $key: DONNÉES CORROMPUES - $e');
        }
      }
    }
  }

  // Vérifier la compatibilité avec la table MySQL agents
  Future<void> verifyMySQLCompatibility() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    final agentKeys = keys.where((key) => key.startsWith('agent_')).toList();
    
    debugPrint('🔍 VÉRIFICATION COMPATIBILITÉ MYSQL - TABLE AGENTS');
    debugPrint('📋 Structure attendue: id, username, password, role, shop_id');
    debugPrint('📊 Analyse de ${agentKeys.length} agents dans SharedPreferences:');
    debugPrint('');
    
    int compatibleCount = 0;
    int incompatibleCount = 0;
    
    for (String key in agentKeys) {
      final data = prefs.getString(key);
      if (data != null) {
        try {
          final json = jsonDecode(data);
          
          // Vérifier les champs requis pour MySQL
          final id = json['id'];
          final username = json['username'];
          final password = json['password'];
          final role = json['role'] ?? 'AGENT'; // Par défaut AGENT
          final shopId = json['shop_id'] ?? json['shopId'];
          
          var isCompatible = true;
          final missingFields = <String>[];
          final extraFields = <String>[];
          
          // Vérifier les champs obligatoires
          if (id == null) {
            missingFields.add('id');
            isCompatible = false;
          }
          if (username == null || username.toString().isEmpty) {
            missingFields.add('username');
            isCompatible = false;
          }
          if (password == null || password.toString().isEmpty) {
            missingFields.add('password');
            isCompatible = false;
          }
          if (shopId == null) {
            missingFields.add('shop_id');
            isCompatible = false;
          }
          
          // Vérifier les champs supplémentaires (non MySQL)
          json.forEach((key, value) {
            if (!['id', 'username', 'password', 'role', 'shop_id', 'shopId'].contains(key)) {
              extraFields.add(key);
            }
          });
          
          if (isCompatible) {
            compatibleCount++;
            debugPrint('✅ $key: COMPATIBLE');
            debugPrint('   - ID: $id (${id.runtimeType})');
            debugPrint('   - Username: $username');
            debugPrint('   - Password: ${password.toString().length} caractères');
            debugPrint('   - Role: $role');
            debugPrint('   - Shop ID: $shopId (${shopId.runtimeType})');
            if (extraFields.isNotEmpty) {
              debugPrint('   - Champs supplémentaires: ${extraFields.join(", ")}');
            }
          } else {
            incompatibleCount++;
            debugPrint('❌ $key: INCOMPATIBLE');
            if (missingFields.isNotEmpty) {
              debugPrint('   - Champs manquants: ${missingFields.join(", ")}');
            }
            debugPrint('   - Données: ${json.toString()}');
          }
          debugPrint('');
          
        } catch (e) {
          incompatibleCount++;
          debugPrint('❌ $key: ERREUR DE PARSING - $e');
          debugPrint('');
        }
      }
    }
    
    debugPrint('📊 RÉSUMÉ DE COMPATIBILITÉ:');
    debugPrint('✅ Agents compatibles: $compatibleCount');
    debugPrint('❌ Agents incompatibles: $incompatibleCount');
    debugPrint('📈 Taux de compatibilité: ${agentKeys.isEmpty ? 0 : (compatibleCount * 100 / agentKeys.length).toStringAsFixed(1)}%');
    
    if (compatibleCount > 0) {
      debugPrint('');
      debugPrint('🎯 RECOMMANDATION: Les données sont ${compatibleCount == agentKeys.length ? "entièrement" : "partiellement"} compatibles avec MySQL');
      debugPrint('💡 Vous pouvez migrer vers MySQL en utilisant ces données');
    } else if (agentKeys.isNotEmpty) {
      debugPrint('');
      debugPrint('⚠️  ATTENTION: Aucune donnée compatible trouvée');
      debugPrint('💡 Vous devrez recréer les agents ou adapter la structure');
    } else {
      debugPrint('');
      debugPrint('ℹ️  INFO: Aucun agent trouvé dans SharedPreferences');
      debugPrint('💡 Vous pouvez commencer directement avec MySQL');
    }
  }

  // Nettoyer TOUS les agents (PROTÈGE L'ADMIN)
  Future<void> clearAllAgents() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    int removed = 0;
    
    for (String key in keys.toList()) {
      if (key.startsWith('agent_') && key != 'admin_default') {
        await prefs.remove(key);
        removed++;
      }
    }
    
    debugPrint('🧹 Suppression de $removed agents de SharedPreferences (Admin protégé)');
    
    // S'assurer que l'admin existe toujours
    await ensureAdminExists();
  }

  /// Supprimer tous les shops en local (pour forcer le rechargement depuis le serveur)
  Future<void> clearAllShops() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    int cleared = 0;
    
    for (String key in keys) {
      if (key.startsWith('shop_')) {
        await prefs.remove(key);
        cleared++;
      }
    }
    
    debugPrint('🗑️ Shops supprimés en local: $cleared');
  }
  
  /// Supprimer tous les clients en local (pour forcer le rechargement depuis le serveur)
  Future<void> clearAllClients() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    int cleared = 0;
    
    for (String key in keys) {
      if (key.startsWith('client_')) {
        await prefs.remove(key);
        cleared++;
      }
    }
    
    debugPrint('🗑️ Clients supprimés en local: $cleared');
  }
  
  /// Supprimer toutes les commissions en local (pour forcer le rechargement depuis le serveur)
  Future<void> clearAllCommissions() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    int cleared = 0;
    
    for (String key in keys) {
      if (key.startsWith('commission_')) {
        await prefs.remove(key);
        cleared++;
      }
    }
    
    debugPrint('🗑️ Commissions supprimées en local: $cleared');
  }
  
  /// Supprimer tous les taux en local (pour forcer le rechargement depuis le serveur)
  Future<void> clearAllTaux() async {
    final prefs = await database;
    final keys = prefs.getKeys();
    int cleared = 0;
    
    for (String key in keys) {
      if (key.startsWith('taux_')) {
        await prefs.remove(key);
        cleared++;
      }
    }
    
    debugPrint('🗑️ Taux supprimés en local: $cleared');
  }


  // === CRUD TRANSACTIONS ===
  Future<TransactionModel> saveTransaction(TransactionModel transaction) async {
    final prefs = await database;
    final transactionId = transaction.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedTransaction = transaction.copyWith(
      id: transactionId,
      lastModifiedAt: DateTime.now(),
    );
    await prefs.setString('transaction_$transactionId', jsonEncode(updatedTransaction.toJson()));
    return updatedTransaction;
  }

  Future<void> updateTransaction(TransactionModel transaction) async {
    if (transaction.id == null) throw Exception('Transaction ID is required for update');
    await saveTransaction(transaction);
  }

  Future<void> deleteTransaction(int transactionId) async {
    final prefs = await database;
    await prefs.remove('transaction_$transactionId');
  }

  Future<List<TransactionModel>> getAllTransactions() async {
    final prefs = await database;
    final transactions = <TransactionModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('transaction_')) {
        try {
          final transactionData = prefs.getString(key);
          if (transactionData != null) {
            transactions.add(TransactionModel.fromJson(jsonDecode(transactionData)));
          }
        } catch (e) {
          debugPrint('Erreur lors du parsing de la transaction $key: $e');
        }
      }
    }
    return transactions;
  }

  Future<List<TransactionModel>> getTransactionsByShop(int shopId) async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((transaction) => transaction.shopId == shopId).toList();
  }

  Future<List<TransactionModel>> getTransactionsByAgent(int agentId) async {
    final allTransactions = await getAllTransactions();
    return allTransactions.where((transaction) => transaction.agentId == agentId).toList();
  }

  // ===== MÉTHODES DE SYNCHRONISATION =====

  /// Récupère les entités non synchronisées d'une table
  Future<List<Map<String, dynamic>>> getUnsyncedEntities(String tableName) async {
    try {
      // Pour la simulation web, retourner une liste vide
      // Dans une vraie implémentation SQLite, ce serait :
      // SELECT * FROM $tableName WHERE is_synced = 0
      return [];
    } catch (e) {
      debugPrint('Erreur getUnsyncedEntities: $e');
      return [];
    }
  }

  /// Marque une entité comme synchronisée
  Future<void> markEntityAsSynced(String tableName, dynamic entityId) async {
    try {
      // Dans une vraie implémentation SQLite :
      // UPDATE $tableName SET is_synced = 1, synced_at = ? WHERE id = ?
      debugPrint('Entité $entityId de $tableName marquée comme synchronisée');
    } catch (e) {
      debugPrint('Erreur markEntityAsSynced: $e');
    }
  }

  /// Récupère la date de dernière synchronisation d'une table
  Future<DateTime?> getLastSyncDate(String tableName) async {
    try {
      // Dans une vraie implémentation SQLite :
      // SELECT last_sync_date FROM sync_metadata WHERE table_name = ?
      return null; // Première synchronisation
    } catch (e) {
      debugPrint('Erreur getLastSyncDate: $e');
      return null;
    }
  }

  /// Met à jour la date de dernière synchronisation
  Future<void> updateLastSyncDate(String tableName, DateTime syncDate) async {
    try {
      // Dans une vraie implémentation SQLite :
      // INSERT OR REPLACE INTO sync_metadata (table_name, last_sync_date) VALUES (?, ?)
      debugPrint('Date de sync mise à jour pour $tableName: $syncDate');
    } catch (e) {
      debugPrint('Erreur updateLastSyncDate: $e');
    }
  }

  /// Récupère une entité par son ID
  Future<Map<String, dynamic>?> getEntityById(String tableName, dynamic entityId) async {
    try {
      // Dans une vraie implémentation SQLite :
      // SELECT * FROM $tableName WHERE id = ?
      
      // Simulation pour les tables existantes
      switch (tableName) {
        case 'operations':
          final operations = await getAllOperations();
          final operation = operations.cast<OperationModel?>().firstWhere((op) => op?.id == entityId, orElse: () => null);
          return operation?.toJson();
        
        case 'shops':
          // Simulation - retourner null pour déclencher l'insertion
          return null;
        
        default:
          return null;
      }
    } catch (e) {
      debugPrint('Erreur getEntityById: $e');
      return null;
    }
  }

  /// Insère une nouvelle entité
  Future<void> insertEntity(String tableName, Map<String, dynamic> data) async {
    try {
      // Dans une vraie implémentation SQLite :
      // INSERT INTO $tableName (...) VALUES (...)
      debugPrint('Nouvelle entité insérée dans $tableName: ${data['id']}');
    } catch (e) {
      debugPrint('Erreur insertEntity: $e');
    }
  }

  /// Met à jour une entité existante
  Future<void> updateEntity(String tableName, dynamic entityId, Map<String, dynamic> data) async {
    try {
      // Dans une vraie implémentation SQLite :
      // UPDATE $tableName SET ... WHERE id = ?
      debugPrint('Entité $entityId mise à jour dans $tableName');
    } catch (e) {
      debugPrint('Erreur updateEntity: $e');
    }
  }

  /// Marque une entité pour re-upload
  Future<void> markEntityForReupload(String tableName, dynamic entityId) async {
    try {
      // Dans une vraie implémentation SQLite :
      // UPDATE $tableName SET is_synced = 0 WHERE id = ?
      debugPrint('Entité $entityId marquée pour re-upload');
    } catch (e) {
      debugPrint('Erreur markEntityForReupload: $e');
    }
  }

  /// Sauvegarde l'état de synchronisation
  Future<void> saveSyncState(Map<String, dynamic> state) async {
    try {
      // Dans une vraie implémentation SQLite :
      // INSERT OR REPLACE INTO sync_state (key, value) VALUES ...
      debugPrint('État de synchronisation sauvegardé: $state');
    } catch (e) {
      debugPrint('Erreur saveSyncState: $e');
    }
  }

  /// Récupère l'état de synchronisation
  Future<Map<String, dynamic>?> getSyncState() async {
    try {
      // Dans une vraie implémentation SQLite :
      // SELECT * FROM sync_state
      return null; // Pas d'état sauvegardé
    } catch (e) {
      debugPrint('Erreur getSyncState: $e');
      return null;
    }
  }

  /// Initialise les tables de synchronisation
  Future<void> initSyncTables() async {
    try {
      // Dans une vraie implémentation SQLite, créer les tables :
      /*
      CREATE TABLE IF NOT EXISTS sync_metadata (
        table_name TEXT PRIMARY KEY,
        last_sync_date TEXT
      );
      
      CREATE TABLE IF NOT EXISTS sync_state (
        key TEXT PRIMARY KEY,
        value TEXT
      );
      
      // Ajouter les colonnes de sync aux tables existantes :
      ALTER TABLE operations ADD COLUMN is_synced INTEGER DEFAULT 0;
      ALTER TABLE operations ADD COLUMN last_modified_at TEXT;
      ALTER TABLE operations ADD COLUMN last_modified_by TEXT;
      ALTER TABLE operations ADD COLUMN synced_at TEXT;
      ALTER TABLE operations ADD COLUMN sync_id TEXT;
      */
      
      debugPrint('Tables de synchronisation initialisées');
    } catch (e) {
      debugPrint('Erreur initSyncTables: $e');
    }
  }

  /// Crée une entrée de journal pour un flot
  Future<void> _createJournalEntryForFlot(flot_model.FlotModel flot) async {
    try {
      // Pour le shop source: SORTIE (quand le flot est envoyé)
      if (flot.statut == flot_model.StatutFlot.enRoute) {
        // Charger les shops pour résoudre les désignations
        final shops = await getAllShops();
        
        final journalEntry = JournalCaisseModel(
          shopId: flot.shopSourceId,
          agentId: flot.agentEnvoyeurId,
          libelle: 'FLOT envoyé vers ${flot.getShopDestinationDesignation(shops)}',
          montant: flot.montant,
          type: TypeMouvement.sortie,
          mode: _convertFlotModeToJournalMode(flot.modePaiement),
          dateAction: flot.dateEnvoi,
          notes: 'FLOT ${flot.reference}',
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: flot.lastModifiedBy,
        );
        
        await saveJournalEntry(journalEntry);
        debugPrint('📋 Journal FLOT: SORTIE de ${flot.montant} ${flot.devise} - FLOT ${flot.reference}');
      }
      
      // Pour le shop destination: ENTRÉE (quand le flot est servi/reçu)
      if (flot.statut == flot_model.StatutFlot.servi && flot.dateReception != null) {
        // Charger les shops pour résoudre les désignations
        final shops = await getAllShops();
        
        final journalEntry = JournalCaisseModel(
          shopId: flot.shopDestinationId,
          agentId: flot.agentRecepteurId ?? 0, // Peut être null
          libelle: 'FLOT reçu de ${flot.getShopSourceDesignation(shops)}',
          montant: flot.montant,
          type: TypeMouvement.entree,
          mode: _convertFlotModeToJournalMode(flot.modePaiement),
          dateAction: flot.dateReception!,
          notes: 'FLOT ${flot.reference}',
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: flot.lastModifiedBy,
        );
        
        await saveJournalEntry(journalEntry);
        debugPrint('📋 Journal FLOT: ENTRÉE de ${flot.montant} ${flot.devise} - FLOT ${flot.reference}');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur création entrée journal FLOT: $e');
    }
  }

  /// Convertit le ModePaiement de FlotModel en celui de JournalCaisseModel
  ModePaiement _convertFlotModeToJournalMode(flot_model.ModePaiement flotMode) {
    switch (flotMode) {
      case flot_model.ModePaiement.cash:
        return ModePaiement.cash;
      case flot_model.ModePaiement.airtelMoney:
        return ModePaiement.airtelMoney;
      case flot_model.ModePaiement.mPesa:
        return ModePaiement.mPesa;
      case flot_model.ModePaiement.orangeMoney:
        return ModePaiement.orangeMoney;
      default:
        return ModePaiement.cash;
    }
  }

  // === CRUD FLOTS ===
  
  /// Sauvegarder un flot
  /// Utilise reference comme clé unique pour éviter les doublons
  /// Si un flot avec la même reference existe, il est écrasé
  Future<flot_model.FlotModel> saveFlot(flot_model.FlotModel flot) async {
    final prefs = await database;
    
    // IMPORTANT: Vérifier si un flot avec la même reference existe déjà
    flot_model.FlotModel? existingFlot;
    if (flot.reference != null && flot.reference!.isNotEmpty) {
      existingFlot = await getFlotByReference(flot.reference!);
    }
    
    // Si le flot existe déjà, utiliser son ID et écraser les données
    // Sinon, générer un nouvel ID
    final flotId = existingFlot?.id ?? flot.id ?? DateTime.now().millisecondsSinceEpoch;
    
    final updatedFlot = flot.copyWith(id: flotId);
    
    if (existingFlot != null) {
      // ÉCRASER le flot existant avec les nouvelles données
      debugPrint('🔄 Flot ${flot.reference} existe déjà (ID: $flotId) - ÉCRASEMENT des données');
      
      // Supprimer l'ancienne clé si elle existe
      await prefs.remove('flot_${existingFlot.id}');
    }
    
    // Sauvegarder avec la clé flot_ID
    await prefs.setString('flot_$flotId', jsonEncode(updatedFlot.toJson()));
    
    // Confirmation de sauvegarde
    if (existingFlot != null) {
      debugPrint('✅ Flot ${flot.reference} mis à jour avec succès (ID: $flotId)');
    } else {
      debugPrint('💸 Flot sauvegardé: reference=${flot.reference}, ID=$flotId, montant=${updatedFlot.montant} ${updatedFlot.devise}');
    }
    
    // Créer une entrée de journal pour le flot
    await _createJournalEntryForFlot(updatedFlot);
    
    return updatedFlot;
  }

  /// Mettre à jour un flot
  Future<void> updateFlot(flot_model.FlotModel flot) async {
    if (flot.id == null) throw Exception('Flot ID is required for update');
    await saveFlot(flot);
  }

  /// Supprimer un flot
  Future<void> deleteFlot(int flotId) async {
    final prefs = await database;
    await prefs.remove('flot_$flotId');
    debugPrint('💸 Flot supprimé: ID=$flotId');
  }

  /// Récupérer tous les flots
  Future<List<flot_model.FlotModel>> getAllFlots() async {
    final prefs = await database;
    final flots = <flot_model.FlotModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('flot_')) {
        try {
          final flotData = prefs.getString(key);
          if (flotData != null) {
            flots.add(flot_model.FlotModel.fromJson(jsonDecode(flotData)));
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chargement flot $key: $e');
        }
      }
    }
    
    // Trier par date d'envoi (plus récents en premier)
    flots.sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi));
    return flots;
  }

  /// Récupérer un flot par ID
  Future<flot_model.FlotModel?> getFlotById(int flotId) async {
    final prefs = await database;
    final flotData = prefs.getString('flot_$flotId');
    if (flotData != null) {
      return flot_model.FlotModel.fromJson(jsonDecode(flotData));
    }
    return null;
  }

  /// Récupérer un flot par reference (CLÉ UNIQUE)
  Future<flot_model.FlotModel?> getFlotByReference(String reference) async {
    final allFlots = await getAllFlots();
    try {
      return allFlots.firstWhere((flot) => flot.reference == reference);
    } catch (e) {
      return null; // Not found
    }
  }

  /// Récupérer les flots par shop (source ou destination)
  Future<List<flot_model.FlotModel>> getFlotsByShop(int shopId) async {
    final allFlots = await getAllFlots();
    return allFlots.where((f) => 
      f.shopSourceId == shopId || f.shopDestinationId == shopId
    ).toList();
  }

  /// Récupérer les flots par statut
  Future<List<flot_model.FlotModel>> getFlotsByStatut(flot_model.StatutFlot statut) async {
    final allFlots = await getAllFlots();
    return allFlots.where((f) => f.statut == statut).toList();
  }

  /// Récupérer les flots par agent (envoyeur ou récepteur)
  Future<List<flot_model.FlotModel>> getFlotsByAgentId(int agentId) async {
    final allFlots = await getAllFlots();
    return allFlots.where((f) => 
      f.agentEnvoyeurId == agentId || f.agentRecepteurId == agentId
    ).toList();
  }

  // === CRUD CLOTURE CAISSE ===
  
  /// Sauvegarder une clôture de caisse
  Future<void> saveClotureCaisse(ClotureCaisseModel cloture) async {
    final prefs = await database;
    final clotureId = cloture.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedCloture = cloture.copyWith(id: clotureId);
    final key = 'cloture_caisse_$clotureId';
    
    debugPrint('💾 Sauvegarde clôture caisse: $key');
    debugPrint('   Shop ID: ${updatedCloture.shopId}');
    debugPrint('   Date: ${updatedCloture.dateCloture}');
    debugPrint('   Solde Saisi: ${updatedCloture.soldeSaisiTotal} USD');
    debugPrint('   Solde Calculé: ${updatedCloture.soldeCalculeTotal} USD');
    debugPrint('   Écart: ${updatedCloture.ecartTotal} USD');
    
    await prefs.setString(key, jsonEncode(updatedCloture.toJson()));
    
    debugPrint('✅ Clôture caisse sauvegardée avec succès');
  }

  /// Récupérer toutes les clôtures de caisse
  Future<List<ClotureCaisseModel>> getAllCloturesCaisse() async {
    final prefs = await database;
    final clotures = <ClotureCaisseModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('cloture_caisse_')) {
        final clotureData = prefs.getString(key);
        if (clotureData != null) {
          clotures.add(ClotureCaisseModel.fromJson(jsonDecode(clotureData)));
        }
      }
    }
    
    // Trier par date de clôture (plus récent en premier)
    clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));
    return clotures;
  }

  /// Récupérer les clôtures de caisse d'un shop spécifique
  Future<List<ClotureCaisseModel>> getCloturesCaisseByShop(int shopId) async {
    final allClotures = await getAllCloturesCaisse();
    return allClotures.where((c) => c.shopId == shopId).toList();
  }

  /// Récupérer la clôture de caisse d'une date spécifique pour un shop
  Future<ClotureCaisseModel?> getClotureCaisseByDate(int shopId, DateTime date) async {
    debugPrint('🔍 [getClotureCaisseByDate] Recherche clôture pour shop $shopId, date: ${date.toIso8601String().split('T')[0]}');
    
    final clotures = await getCloturesCaisseByShop(shopId);
    debugPrint('📊 [getClotureCaisseByDate] ${clotures.length} clôtures trouvées pour le shop $shopId');
    
    // Chercher la clôture qui correspond à cette date exacte
    for (var cloture in clotures) {
      debugPrint('🔎 [getClotureCaisseByDate] Comparaison avec clôture date: ${cloture.dateCloture.toIso8601String().split('T')[0]}');
      if (_isSameDay(cloture.dateCloture, date)) {
        debugPrint('✅ Clôture trouvée pour le ${date.toIso8601String().split('T')[0]}');
        debugPrint('   Solde Saisi: ${cloture.soldeSaisiTotal} USD');
        debugPrint('   Solde Calculé: ${cloture.soldeCalculeTotal} USD');
        debugPrint('   Écart: ${cloture.ecartTotal} USD');
        return cloture;
      }
    }
    
    debugPrint('⚠️ Aucune clôture trouvée pour le ${date.toIso8601String().split('T')[0]}');
    return null;
  }

  /// Récupérer la dernière clôture de caisse pour un shop
  Future<ClotureCaisseModel?> getLastClotureCaisse(int shopId) async {
    final clotures = await getCloturesCaisseByShop(shopId);
    return clotures.isEmpty ? null : clotures.first; // Déjà trié par date décroissante
  }

  /// Vérifier si une clôture existe pour une date donnée
  Future<bool> clotureExistsPourDate(int shopId, DateTime date) async {
    final cloture = await getClotureCaisseByDate(shopId, date);
    return cloture != null;
  }

  /// Supprimer une clôture de caisse
  Future<void> deleteClotureCaisse(int clotureId) async {
    final prefs = await database;
    await prefs.remove('cloture_caisse_$clotureId');
    debugPrint('🗑️ Clôture caisse supprimée: $clotureId');
  }

  /// Utilitaire: vérifier si deux dates sont le même jour
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  // === CRUD SIMS ===
  
  /// Sauvegarder une SIM
  Future<SimModel> saveSim(SimModel sim) async {
    final prefs = await database;
    final simId = sim.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedSim = sim.copyWith(
      id: simId,
      lastModifiedAt: DateTime.now(),
    );
    await prefs.setString('sim_$simId', jsonEncode(updatedSim.toJson()));
    debugPrint('📱 SIM sauvegardée: ID=$simId, Numéro=${updatedSim.numero}');
    return updatedSim;
  }

  /// Mettre à jour une SIM
  Future<void> updateSim(SimModel sim) async {
    if (sim.id == null) throw Exception('SIM ID is required for update');
    await saveSim(sim);
  }
  
  /// Mettre à jour uniquement le solde d'une SIM
  Future<void> updateSimSolde(String simNumero, double nouveauSolde) async {
    final sims = await getAllSims();
    final sim = sims.where((s) => s.numero == simNumero).firstOrNull;
    
    if (sim == null) {
      throw Exception('SIM $simNumero non trouvée');
    }
    
    final simUpdated = sim.copyWith(soldeActuel: nouveauSolde);
    await updateSim(simUpdated);
    debugPrint('💰 Solde SIM mis à jour: $simNumero = \$${nouveauSolde.toStringAsFixed(2)}');
  }

  /// Récupérer toutes les SIMs
  Future<List<SimModel>> getAllSims({int? shopId}) async {
    final prefs = await database;
    final sims = <SimModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('sim_')) {
        try {
          final simData = prefs.getString(key);
          if (simData != null) {
            final sim = SimModel.fromJson(jsonDecode(simData));
            // Filtrer par shopId si fourni
            if (shopId == null || sim.shopId == shopId) {
              sims.add(sim);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chargement SIM $key: $e');
        }
      }
    }
    
    return sims;
  }

  /// Récupérer une SIM par ID
  Future<SimModel?> getSimById(int simId) async {
    final prefs = await database;
    final simData = prefs.getString('sim_$simId');
    if (simData != null) {
      return SimModel.fromJson(jsonDecode(simData));
    }
    return null;
  }

  /// Supprimer une SIM
  Future<void> deleteSim(int simId) async {
    final prefs = await database;
    await prefs.remove('sim_$simId');
    debugPrint('🗑️ SIM supprimée: ID=$simId');
  }

  // === CRUD SIM MOVEMENTS ===
  
  /// Sauvegarder un mouvement de SIM
  Future<SimMovementModel> saveSimMovement(SimMovementModel movement) async {
    final prefs = await database;
    final movementId = movement.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedMovement = movement.copyWith(id: movementId);
    await prefs.setString('sim_movement_$movementId', jsonEncode(updatedMovement.toJson()));
    debugPrint('📝 Mouvement SIM sauvegardé: ID=$movementId');
    return updatedMovement;
  }

  /// Récupérer tous les mouvements de SIM
  Future<List<SimMovementModel>> getAllSimMovements({int? simId}) async {
    final prefs = await database;
    final movements = <SimMovementModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('sim_movement_')) {
        try {
          final movementData = prefs.getString(key);
          if (movementData != null) {
            final movement = SimMovementModel.fromJson(jsonDecode(movementData));
            // Filtrer par simId si fourni
            if (simId == null || movement.simId == simId) {
              movements.add(movement);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chargement mouvement SIM $key: $e');
        }
      }
    }
    
    // Trier par date (plus récents en premier)
    movements.sort((a, b) => b.dateMovement.compareTo(a.dateMovement));
    return movements;
  }

  /// Supprimer un mouvement de SIM
  Future<void> deleteSimMovement(int movementId) async {
    final prefs = await database;
    await prefs.remove('sim_movement_$movementId');
    debugPrint('🗑️ Mouvement SIM supprimé: ID=$movementId');
  }

  // === CRUD VIRTUAL TRANSACTIONS ===
  
  /// Sauvegarder une transaction virtuelle
  Future<VirtualTransactionModel> saveVirtualTransaction(VirtualTransactionModel transaction) async {
    final prefs = await database;
    
    // 🔍 PROTECTION ANTI-DOUBLON: Vérifier si une transaction avec cette référence existe déjà
    final existingTransaction = await getVirtualTransactionByReference(transaction.reference);
    
    if (existingTransaction != null) {
      // Si c'est la même transaction (même ID), mettre à jour
      if (transaction.id != null && existingTransaction.id == transaction.id) {
        debugPrint('🔄 Mise à jour transaction virtuelle: ID=${transaction.id}, REF=${transaction.reference}');
        await prefs.setString('virtual_transaction_${transaction.id}', jsonEncode(transaction.toJson()));
        return transaction;
      }
      
      // Si c'est un doublon (référence identique mais ID différent)
      debugPrint('⚠️ DOUBLON DÉTECTÉ: REF=${transaction.reference} existe déjà (ID=${existingTransaction.id})');
      debugPrint('   Transaction existante: ID=${existingTransaction.id}, Statut=${existingTransaction.statut.name}');
      debugPrint('   Nouvelle tentative: ID=${transaction.id}, Statut=${transaction.statut.name}');
      
      // Si la transaction existante est plus récente ou validée, la garder
      if (existingTransaction.statut == VirtualTransactionStatus.validee || 
          (existingTransaction.lastModifiedAt?.isAfter(transaction.lastModifiedAt ?? DateTime.now()) ?? false)) {
        debugPrint('   ✅ Conservation de la transaction existante (plus récente ou validée)');
        return existingTransaction;
      } else {
        // Sinon, remplacer par la nouvelle version
        debugPrint('   🔄 Remplacement par la nouvelle version');
        // Supprimer l'ancienne
        await prefs.remove('virtual_transaction_${existingTransaction.id}');
        // Continuer avec la sauvegarde de la nouvelle
      }
    }
    
    final transactionId = transaction.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedTransaction = transaction.id == null 
        ? transaction.copyWith(
            id: transactionId,
            lastModifiedAt: DateTime.now(),
          )
        : transaction; // Si la transaction a déjà un ID, ne pas modifier
    await prefs.setString('virtual_transaction_$transactionId', jsonEncode(updatedTransaction.toJson()));
    debugPrint('💰 Transaction virtuelle sauvegardée: ID=$transactionId, REF=${updatedTransaction.reference}');
    return updatedTransaction;
  }

  /// Mettre à jour une transaction virtuelle
  Future<void> updateVirtualTransaction(VirtualTransactionModel transaction) async {
    if (transaction.id == null) throw Exception('Transaction ID is required for update');
    await saveVirtualTransaction(transaction);
  }

  /// Récupérer toutes les transactions virtuelles (avec filtres optionnels)
  Future<List<VirtualTransactionModel>> getAllVirtualTransactions({
    int? shopId,
    String? simNumero,
    DateTime? dateDebut,
    DateTime? dateFin,
    VirtualTransactionStatus? statut,
  }) async {
    final prefs = await database;
    final transactions = <VirtualTransactionModel>[];
    
    final keys = prefs.getKeys();
    debugPrint('🔍 [LocalDB] getAllVirtualTransactions - Found ${keys.where((k) => k.startsWith('virtual_transaction_')).length} virtual transaction keys');
    
    for (String key in keys) {
      if (key.startsWith('virtual_transaction_')) {
        try {
          final transactionData = prefs.getString(key);
          if (transactionData != null) {
            final transaction = VirtualTransactionModel.fromJson(jsonDecode(transactionData));
            
            debugPrint('🔍 [LocalDB] Found transaction: ${transaction.reference} (shop: ${transaction.shopId} (${transaction.shopId.runtimeType}), status: ${transaction.statut.name})');
            
            // Appliquer les filtres
            bool matches = true;
            
            if (shopId != null) {
              debugPrint('🔍 [LocalDB] Checking shopId filter: expected $shopId (${shopId.runtimeType}), got ${transaction.shopId} (${transaction.shopId.runtimeType})');
              if (transaction.shopId != shopId) {
                debugPrint('  ❌ Filtered out - shopId mismatch: expected $shopId, got ${transaction.shopId}');
                matches = false;
              } else {
                debugPrint('  ✅ shopId matches: ${transaction.shopId}');
              }
            }
            
            if (simNumero != null && transaction.simNumero != simNumero) {
              debugPrint('  ❌ Filtered out - simNumero mismatch: expected $simNumero, got ${transaction.simNumero}');
              matches = false;
            }
            
            if (statut != null && transaction.statut != statut) {
              debugPrint('  ❌ Filtered out - statut mismatch: expected ${statut.name}, got ${transaction.statut.name}');
              matches = false;
            }
            
            if (dateDebut != null && transaction.dateEnregistrement.isBefore(dateDebut)) {
              debugPrint('  ❌ Filtered out - dateDebut mismatch: ${transaction.dateEnregistrement} is before $dateDebut');
              matches = false;
            }
            
            if (dateFin != null && transaction.dateEnregistrement.isAfter(dateFin)) {
              debugPrint('  ❌ Filtered out - dateFin mismatch: ${transaction.dateEnregistrement} is after $dateFin');
              matches = false;
            }
            
            if (matches) {
              debugPrint('  ✅ Included transaction: ${transaction.reference}');
              transactions.add(transaction);
            } else {
              debugPrint('  ❌ Excluded transaction: ${transaction.reference}');
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chargement transaction virtuelle $key: $e');
        }
      }
    }
    
    debugPrint('📊 [LocalDB] getAllVirtualTransactions returning ${transactions.length} transactions');
    
    // Trier par date (plus récents en premier)
    transactions.sort((a, b) => b.dateEnregistrement.compareTo(a.dateEnregistrement));
    return transactions;
  }

  /// Récupérer une transaction virtuelle par ID
  Future<VirtualTransactionModel?> getVirtualTransactionById(int transactionId) async {
    final prefs = await database;
    final transactionData = prefs.getString('virtual_transaction_$transactionId');
    if (transactionData != null) {
      return VirtualTransactionModel.fromJson(jsonDecode(transactionData));
    }
    return null;
  }

  /// Récupérer une transaction virtuelle par référence (insensible à la casse et aux espaces)
  Future<VirtualTransactionModel?> getVirtualTransactionByReference(String reference) async {
    final prefs = await database;
    final keys = prefs.getKeys();
    
    // Normaliser la référence recherchée
    final normalizedReference = reference.trim().toLowerCase();
    
    for (String key in keys) {
      if (key.startsWith('virtual_transaction_')) {
        try {
          final transactionData = prefs.getString(key);
          if (transactionData != null) {
            final transaction = VirtualTransactionModel.fromJson(jsonDecode(transactionData));
            // Comparaison insensible à la casse et aux espaces
            if (transaction.reference.trim().toLowerCase() == normalizedReference) {
              return transaction;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur recherche transaction par référence: $e');
        }
      }
    }
    return null;
  }

  /// Récupérer une SIM par numéro
  Future<SimModel?> getSimByNumero(String numero) async {
    final allSims = await getAllSims();
    try {
      return allSims.firstWhere((sim) => sim.numero == numero);
    } catch (e) {
      return null;
    }
  }

  /// Supprimer une transaction virtuelle
  Future<void> deleteVirtualTransaction(int transactionId) async {
    final prefs = await database;
    await prefs.remove('virtual_transaction_$transactionId');
    debugPrint('🗑️ Transaction virtuelle supprimée: ID=$transactionId');
  }

  /// Nettoyer les doublons de transactions virtuelles
  /// Retourne le nombre de doublons supprimés
  Future<int> cleanDuplicateVirtualTransactions() async {
    debugPrint('🧹 NETTOYAGE DES DOUBLONS - Début...');
    
    final prefs = await database;
    final keys = prefs.getKeys();
    final transactions = <VirtualTransactionModel>[];
    
    // Charger toutes les transactions
    for (String key in keys) {
      if (key.startsWith('virtual_transaction_')) {
        try {
          final transactionData = prefs.getString(key);
          if (transactionData != null) {
            transactions.add(VirtualTransactionModel.fromJson(jsonDecode(transactionData)));
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chargement $key: $e');
        }
      }
    }
    
    debugPrint('📊 Total transactions chargées: ${transactions.length}');
    
    // Grouper par référence (insensible à la casse)
    final groupedByReference = <String, List<VirtualTransactionModel>>{};
    for (var transaction in transactions) {
      final normalizedRef = transaction.reference.trim().toLowerCase();
      groupedByReference[normalizedRef] ??= [];
      groupedByReference[normalizedRef]!.add(transaction);
    }
    
    int duplicatesRemoved = 0;
    
    // Nettoyer les doublons
    for (var entry in groupedByReference.entries) {
      final transactionsWithSameRef = entry.value;
      
      if (transactionsWithSameRef.length > 1) {
        debugPrint('⚠️ DOUBLON TROUVÉ: RÉF="${entry.key}" - ${transactionsWithSameRef.length} occurrences');
        
        // Trier: valider d'abord, puis par date de modification la plus récente
        transactionsWithSameRef.sort((a, b) {
          // Priorité 1: Transactions validées en premier
          if (a.statut == VirtualTransactionStatus.validee && b.statut != VirtualTransactionStatus.validee) {
            return -1;
          }
          if (b.statut == VirtualTransactionStatus.validee && a.statut != VirtualTransactionStatus.validee) {
            return 1;
          }
          
          // Priorité 2: Date de modification la plus récente
          final aDate = a.lastModifiedAt ?? a.dateEnregistrement;
          final bDate = b.lastModifiedAt ?? b.dateEnregistrement;
          return bDate.compareTo(aDate);
        });
        
        // Garder la première (meilleure), supprimer les autres
        final toKeep = transactionsWithSameRef.first;
        debugPrint('   ✅ Conservation: ID=${toKeep.id}, Statut=${toKeep.statut.name}, Date=${toKeep.lastModifiedAt ?? toKeep.dateEnregistrement}');
        
        for (int i = 1; i < transactionsWithSameRef.length; i++) {
          final toRemove = transactionsWithSameRef[i];
          debugPrint('   🗑️ Suppression: ID=${toRemove.id}, Statut=${toRemove.statut.name}, Date=${toRemove.lastModifiedAt ?? toRemove.dateEnregistrement}');
          await prefs.remove('virtual_transaction_${toRemove.id}');
          duplicatesRemoved++;
        }
      }
    }
    
    debugPrint('✅ NETTOYAGE TERMINÉ: $duplicatesRemoved doublons supprimés');
    return duplicatesRemoved;
  }

  // === CRUD FLOTS ===
  
  /// Sauvegarder un retrait virtuel
  Future<RetraitVirtuelModel> saveRetraitVirtuel(RetraitVirtuelModel retrait) async {
    final prefs = await database;
    final retraitId = retrait.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedRetrait = retrait.id == null 
        ? retrait.copyWith(
            id: retraitId,
            lastModifiedAt: DateTime.now(),
          )
        : retrait;
    await prefs.setString('retrait_virtuel_$retraitId', jsonEncode(updatedRetrait.toJson()));
    debugPrint('Flot sauvegarde: ID=$retraitId, Montant=\$${updatedRetrait.montant}');
    return updatedRetrait;
  }

  /// Mettre à jour un retrait virtuel
  Future<void> updateRetraitVirtuel(RetraitVirtuelModel retrait) async {
    if (retrait.id == null) throw Exception('Retrait ID is required for update');
    await saveRetraitVirtuel(retrait);
  }

  /// Récupérer tous les retraits virtuels (avec filtres optionnels)
  Future<List<RetraitVirtuelModel>> getAllRetraitsVirtuels({
    int? shopSourceId,
    int? shopDebiteurId,
    String? simNumero,
    DateTime? dateDebut,
    DateTime? dateFin,
    RetraitVirtuelStatus? statut,
  }) async {
    final prefs = await database;
    final retraits = <RetraitVirtuelModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('retrait_virtuel_')) {
        try {
          final retraitData = prefs.getString(key);
          if (retraitData != null) {
            final retrait = RetraitVirtuelModel.fromJson(jsonDecode(retraitData));
            
            // Appliquer les filtres
            bool matches = true;
            
            if (shopSourceId != null && retrait.shopSourceId != shopSourceId) {
              matches = false;
            }
            
            if (shopDebiteurId != null && retrait.shopDebiteurId != shopDebiteurId) {
              matches = false;
            }
            
            if (simNumero != null && retrait.simNumero != simNumero) {
              matches = false;
            }
            
            if (statut != null && retrait.statut != statut) {
              matches = false;
            }
            
            if (dateDebut != null && retrait.dateRetrait.isBefore(dateDebut)) {
              matches = false;
            }
            
            if (dateFin != null && retrait.dateRetrait.isAfter(dateFin)) {
              matches = false;
            }
            
            if (matches) {
              retraits.add(retrait);
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur chargement retrait virtuel $key: $e');
        }
      }
    }
    
    // Trier par date (plus récents en premier)
    retraits.sort((a, b) => b.dateRetrait.compareTo(a.dateRetrait));
    return retraits;
  }

  /// Supprimer un retrait virtuel
  Future<void> deleteRetraitVirtuel(int retraitId) async {
    final prefs = await database;
    await prefs.remove('retrait_virtuel_$retraitId');
    debugPrint('Flot supprime: ID=$retraitId');
  }

  // === CRUD CLOTURES VIRTUELLES ===
  
  /// Sauvegarder une clôture virtuelle
  Future<ClotureVirtuelleModel> saveClotureVirtuelle(ClotureVirtuelleModel cloture) async {
    final prefs = await database;
    final clotureId = cloture.id ?? DateTime.now().millisecondsSinceEpoch;
    final updatedCloture = cloture.id == null 
        ? cloture.copyWith(
            id: clotureId,
            lastModifiedAt: DateTime.now(),
          )
        : cloture;
    await prefs.setString('cloture_virtuelle_$clotureId', jsonEncode(updatedCloture.toJson()));
    debugPrint('Cloture virtuelle sauvegardee: ID=$clotureId, Date=${updatedCloture.dateCloture}');
    return updatedCloture;
  }

  /// Recuperer toutes les clotures virtuelles
  Future<List<ClotureVirtuelleModel>> getAllCloturesVirtuelles({
    int? shopId,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final prefs = await database;
    final clotures = <ClotureVirtuelleModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('cloture_virtuelle_')) {
        try {
          final clotureData = prefs.getString(key);
          if (clotureData != null) {
            final cloture = ClotureVirtuelleModel.fromJson(jsonDecode(clotureData));
            
            // Appliquer les filtres
            bool matches = true;
            
            if (shopId != null && cloture.shopId != shopId) {
              matches = false;
            }
            
            if (dateDebut != null && cloture.dateCloture.isBefore(dateDebut)) {
              matches = false;
            }
            
            if (dateFin != null && cloture.dateCloture.isAfter(dateFin)) {
              matches = false;
            }
            
            if (matches) {
              clotures.add(cloture);
            }
          }
        } catch (e) {
          debugPrint('Erreur chargement cloture virtuelle $key: $e');
        }
      }
    }
    
    // Trier par date (plus recents en premier)
    clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));
    return clotures;
  }

  /// Recuperer une cloture virtuelle par shop et date
  Future<ClotureVirtuelleModel?> getClotureVirtuelleByDate(int shopId, DateTime date) async {
    final allClotures = await getAllCloturesVirtuelles(shopId: shopId);
    
    final dateOnly = DateTime(date.year, date.month, date.day);
    
    try {
      return allClotures.firstWhere(
        (c) {
          final clotureDate = DateTime(c.dateCloture.year, c.dateCloture.month, c.dateCloture.day);
          return clotureDate.isAtSameMomentAs(dateOnly);
        },
      );
    } catch (e) {
      return null;
    }
  }

  /// Verifier si une cloture existe pour une date
  Future<bool> clotureVirtuelleExistsPourDate(int shopId, DateTime date) async {
    final cloture = await getClotureVirtuelleByDate(shopId, date);
    return cloture != null;
  }

  /// Supprimer une cloture virtuelle
  Future<void> deleteClotureVirtuelle(int clotureId) async {
    final prefs = await database;
    await prefs.remove('cloture_virtuelle_$clotureId');
    debugPrint('Cloture virtuelle supprimee: ID=$clotureId');
  }

  // === CRUD DÉPÔTS CLIENTS ===
  
  /// Insérer un nouveau dépôt client
  Future<int> insertDepotClient(DepotClientModel depot) async {
    final prefs = await database;
    final depotId = await _generateSequentialId('depot_client_');
    final depotWithId = DepotClientModel(
      id: depotId,
      shopId: depot.shopId,
      simNumero: depot.simNumero,
      montant: depot.montant,
      telephoneClient: depot.telephoneClient,
      dateDepot: depot.dateDepot,
      userId: depot.userId,
    );
    
    await prefs.setString('depot_client_$depotId', jsonEncode(depotWithId.toMap()));
    debugPrint('💰 Dépôt client enregistré: ID=$depotId, Montant=\$${depot.montant}');
    return depotId;
  }
  
  /// Mettre à jour un dépôt client
  Future<void> updateDepotClient(DepotClientModel depot) async {
    if (depot.id == null) throw Exception('Depot ID is required for update');
    final prefs = await database;
    await prefs.setString('depot_client_${depot.id}', jsonEncode(depot.toMap()));
    debugPrint('💰 Dépôt client mis à jour: ID=${depot.id}, Montant=\$${depot.montant}');
  }
  
  /// Récupérer tous les dépôts clients
  Future<List<DepotClientModel>> getAllDepotsClients({
    int? shopId,
    DateTime? dateDebut,
    DateTime? dateFin,
  }) async {
    final prefs = await database;
    final depots = <DepotClientModel>[];
    
    final keys = prefs.getKeys();
    for (String key in keys) {
      if (key.startsWith('depot_client_')) {
        try {
          final depotData = prefs.getString(key);
          if (depotData != null) {
            final depot = DepotClientModel.fromMap(jsonDecode(depotData));
            
            // Filtres
            bool matches = true;
            
            if (shopId != null && depot.shopId != shopId) {
              matches = false;
            }
            
            if (dateDebut != null && depot.dateDepot.isBefore(dateDebut)) {
              matches = false;
            }
            
            if (dateFin != null && depot.dateDepot.isAfter(dateFin)) {
              matches = false;
            }
            
            if (matches) {
              depots.add(depot);
            }
          }
        } catch (e) {
          debugPrint('Erreur chargement dépôt client $key: $e');
        }
      }
    }
    
    // Trier par date (plus récents en premier)
    depots.sort((a, b) => b.dateDepot.compareTo(a.dateDepot));
    return depots;
  }
  
  /// Récupérer un dépôt client par ID
  Future<DepotClientModel?> getDepotClientById(int depotId) async {
    final prefs = await database;
    final depotData = prefs.getString('depot_client_$depotId');
    
    if (depotData == null) return null;
    
    try {
      return DepotClientModel.fromMap(jsonDecode(depotData));
    } catch (e) {
      debugPrint('Erreur chargement dépôt client $depotId: $e');
      return null;
    }
  }
  
  /// Supprimer un dépôt client
  Future<void> deleteDepotClient(int depotId) async {
    final prefs = await database;
    await prefs.remove('depot_client_$depotId');
    debugPrint('Dépôt client supprimé: ID=$depotId');
  }

  // ===================================================================
  // CLÔTURES VIRTUELLES PAR SIM
  // ===================================================================

  /// Sauvegarder une clôture virtuelle par SIM
  Future<void> saveClotureVirtuelleParSim(dynamic cloture) async {
    final prefs = await database;
    
    // Générer un ID si nécessaire
    final clotureId = cloture.id ?? await _generateSequentialId('cloture_sim_');
    final clotureWithId = cloture.copyWith(id: clotureId);
    
    // Sauvegarder avec une clé unique: cloture_sim_{simNumero}_{date}
    final dateKey = clotureWithId.dateCloture.toIso8601String().split('T')[0];
    final key = 'cloture_sim_${clotureWithId.simNumero}_$dateKey';
    
    await prefs.setString(key, jsonEncode(clotureWithId.toMap()));
    debugPrint('✅ Clôture SIM sauvegardée: ${clotureWithId.simNumero} - $dateKey');
  }

  /// Récupérer toutes les clôtures par SIM pour une date donnée
  Future<List<dynamic>> getCloturesVirtuellesParDate({
    required int shopId,
    required DateTime date,
  }) async {
    final prefs = await database;
    final dateKey = date.toIso8601String().split('T')[0];
    final List<dynamic> clotures = [];
    
    final allKeys = prefs.getKeys();
    for (var key in allKeys) {
      if (key.startsWith('cloture_sim_') && key.endsWith(dateKey)) {
        final clotureData = prefs.getString(key);
        if (clotureData != null) {
          final clotureMap = jsonDecode(clotureData);
          if (clotureMap['shop_id'] == shopId) {
            // Note: Le service appelant doit convertir vers le bon modèle
            clotures.add(clotureMap);
          }
        }
      }
    }
    
    debugPrint('📊 ${clotures.length} clôture(s) trouvée(s) pour le $dateKey');
    return clotures;
  }

  /// Récupérer la dernière clôture d'une SIM avant une date donnée
  Future<dynamic> getDerniereClotureParSim({
    required String simNumero,
    required DateTime avant,
  }) async {
    final prefs = await database;
    final allKeys = prefs.getKeys();
    
    dynamic derniereCloture;
    DateTime? derniereDateCloture;
    
    for (var key in allKeys) {
      if (key.startsWith('cloture_sim_$simNumero')) {
        final clotureData = prefs.getString(key);
        if (clotureData != null) {
          final clotureMap = jsonDecode(clotureData);
          final dateCloture = DateTime.parse(clotureMap['date_cloture']);
          
          // Vérifier si cette clôture est avant la date demandée
          if (dateCloture.isBefore(avant)) {
            // Garder la plus récente
            if (derniereDateCloture == null || dateCloture.isAfter(derniereDateCloture)) {
              derniereDateCloture = dateCloture;
              derniereCloture = clotureMap;
            }
          }
        }
      }
    }
    
    return derniereCloture;
  }

  /// Récupérer l'historique des clôtures pour une SIM
  Future<List<dynamic>> getHistoriqueCloturesParSim({
    required String simNumero,
    DateTime? depuis,
    DateTime? jusqua,
  }) async {
    final prefs = await database;
    final allKeys = prefs.getKeys();
    final List<dynamic> clotures = [];
    
    for (var key in allKeys) {
      if (key.startsWith('cloture_sim_$simNumero')) {
        final clotureData = prefs.getString(key);
        if (clotureData != null) {
          final clotureMap = jsonDecode(clotureData);
          final dateCloture = DateTime.parse(clotureMap['date_cloture']);
          
          // Filtrer par période si spécifiée
          bool inclure = true;
          if (depuis != null && dateCloture.isBefore(depuis)) {
            inclure = false;
          }
          if (jusqua != null && dateCloture.isAfter(jusqua)) {
            inclure = false;
          }
          
          if (inclure) {
            clotures.add(clotureMap);
          }
        }
      }
    }
    
    // Trier par date décroissante (plus récente en premier)
    clotures.sort((a, b) {
      final dateA = DateTime.parse(a['date_cloture']);
      final dateB = DateTime.parse(b['date_cloture']);
      return dateB.compareTo(dateA);
    });
    
    debugPrint('📊 ${clotures.length} clôture(s) trouvée(s) pour SIM $simNumero');
    return clotures;
  }

}
