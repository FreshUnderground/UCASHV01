// ignore_for_file: body_might_complete_normally_nullable

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/shop_model.dart';
import '../models/client_model.dart';
import '../models/agent_model.dart';
import 'local_db.dart';
import 'transfer_sync_service.dart'; // Add this import
import 'agent_service.dart';
import 'rates_service.dart';
import 'shop_service.dart';
import 'sync_service.dart';
import 'connectivity_service.dart';

class AuthService extends ChangeNotifier {
  UserModel? _currentUser;
  ShopModel? _currentShop;
  ClientModel? _currentClient;
  bool _isAuthenticated = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  UserModel? get currentUser => _currentUser;
  ShopModel? get currentShop => _currentShop;
  ClientModel? get currentClient => _currentClient;
  bool get isAuthenticated => _isAuthenticated;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get displayName => _currentUser?.username ?? _currentClient?.nom ?? 'Utilisateur';

  // Vérifier une session sauvegardée
  Future<void> checkSavedSession() async {
    _setLoading(true);
    
    try {
      // Timeout rapide pour éviter les blocages
      final user = await Future.any([
        LocalDB.instance.getCurrentUser(),
        Future.delayed(const Duration(seconds: 2), () => null),
      ]);
      
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        
        // Charger les informations du shop en arrière-plan (non bloquant)
        if (user.shopId != null) {
          LocalDB.instance.getShopById(user.shopId!).then((shop) {
            _currentShop = shop;
            notifyListeners();
          }).catchError((e) {
            debugPrint('Erreur chargement shop: $e');
          });
        }
        
        // Initialize TransferSyncService for agents with saved sessions
        if (user.role == 'AGENT' && user.shopId != null) {
          try {
            final transferSyncService = TransferSyncService();
            await transferSyncService.initialize(user.shopId!);
            debugPrint('✅ TransferSyncService initialisé pour shop: ${user.shopId}');
          } catch (e) {
            debugPrint('⚠️ Erreur initialisation TransferSyncService: $e');
          }
        }
        
        // Déclencher une synchronisation automatique après session sauvegardée
        _triggerPostLoginSync();
      }
    } catch (e) {
      _errorMessage = 'Erreur lors de la vérification de session: $e';
      debugPrint(_errorMessage);
    }
    
    _setLoading(false);
  }

  // Connexion utilisateur
  Future<bool> login(String username, String password, {bool rememberMe = false}) async {
    _setLoading(true);
    _clearError();

    try {
      UserModel? user;
      
      // Essayer d'abord la connexion online (API REST future)
      if (await _isOnline()) {
        user = await _loginOnline(username, password);
        if (user != null) {
          // Sauvegarder en local pour utilisation offline
          await _saveUserLocally(user);
        }
      }
      
      // Si pas de connexion online ou échec, essayer offline
      if (user == null) {
        user = await _loginOffline(username, password);
      }
      
      if (user != null) {
        _currentUser = user;
        _isAuthenticated = true;
        
        if (user.shopId != null) {
          _currentShop = await LocalDB.instance.getShopById(user.shopId!);
        }
        
        // Sauvegarder la session
        await LocalDB.instance.saveUserSession(user);
        await _saveLoginPreferences(rememberMe: rememberMe);
        
        // Initialize TransferSyncService for agents
        if (user.role == 'AGENT' && user.shopId != null) {
          try {
            final transferSyncService = TransferSyncService();
            await transferSyncService.initialize(user.shopId!);
            debugPrint('✅ TransferSyncService initialisé pour shop: ${user.shopId}');
          } catch (e) {
            debugPrint('⚠️ Erreur initialisation TransferSyncService: $e');
          }
        }
        
        // Déclencher une synchronisation automatique après login réussi
        _triggerPostLoginSync();
        
        _setLoading(false);
        return true;
      }
      
      _errorMessage = 'Nom d\'utilisateur ou mot de passe incorrect';
      _setLoading(false);
      return false;
    } catch (e) {
      _errorMessage = 'Erreur lors de la connexion: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Connexion online (API REST - à implémenter plus tard)
  Future<UserModel?> _loginOnline(String username, String password) async {
    try {
      // TODO: Implémenter l'appel API REST
      // final response = await ApiService.login(username, password);
      // return UserModel.fromJson(response);
      return null; // Temporairement désactivé
    } catch (e) {
      debugPrint('Erreur connexion online: $e');
      return null;
    }
  }

  // Connexion offline (SQLite local)
  Future<UserModel?> _loginOffline(String username, String password) async {
    try {
      // S'assurer que l'admin existe avant de tenter la connexion
      await LocalDB.instance.ensureAdminExists();
      
      // Vérifier d'abord l'admin par défaut (PROTÉGÉ)
      if (username == 'admin' && password == 'admin123') {
        final admin = await LocalDB.instance.getDefaultAdmin();
        if (admin != null) {
          debugPrint('🔐 Connexion admin par défaut réussie (PROTÉGÉ)');
          return admin;
        }
      }
      
      // Vérifier dans la table agents
      UserModel? user = await LocalDB.instance.getAgentByCredentials(username, password);
      
      if (user != null) {
        debugPrint('Connexion offline réussie pour: ${user.username}');
        return user;
      }
      
      debugPrint('Échec de la connexion offline pour: $username');
      
      // 🔄 NOUVEAU: Si échec, tenter une synchronisation et réessayer
      // Cela permet de récupérer un agent récemment ajouté sur le serveur
      final syncedUser = await _syncAndRetryLogin(username, password);
      if (syncedUser != null) {
        return syncedUser;
      }
      
      return null;
    } catch (e) {
      debugPrint('Erreur lors de la connexion offline: $e');
    }
  }

  /// OPTIMISATION #1: Synchronisation ciblée et rapide pour retry login
  /// Synchronise seulement les agents (plus rapide) avec timeout
  Future<UserModel?> _syncAndRetryLogin(String username, String password) async {
    try {
      // Vérifier si on est en ligne
      final connectivityService = ConnectivityService.instance;
      if (!connectivityService.isOnline) {
        debugPrint('⚠️ Pas de connexion internet - impossible de synchroniser');
        return null;
      }
      
      debugPrint('🔄 Échec login offline - Sync ciblée pour agent: $username');
      
      // OPTIMISATION: Sync avec timeout pour éviter les blocages
      try {
        final syncService = SyncService();
        
        // Réinitialiser seulement le timestamp des agents pour sync ciblée
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('last_sync_agents');
        debugPrint('🗑️ Timestamp agents réinitialisé pour sync ciblée');
        
        // Télécharger seulement les AGENTS avec timeout
        debugPrint('📥 Téléchargement ciblé des AGENTS (timeout 10s)...');
        await Future.any([
          syncService.downloadTableData('agents', 'login_sync', 'admin'),
          Future.delayed(const Duration(seconds: 10), () => throw TimeoutException('Sync timeout')),
        ]);
        
        await AgentService.instance.loadAgents(forceRefresh: true);
        debugPrint('✅ ${AgentService.instance.agents.length} agents téléchargés');
        
        // Réessayer le login immédiatement
        final user = await LocalDB.instance.getAgentByCredentials(username, password);
        
        if (user != null) {
          debugPrint('✅ Connexion réussie après sync ciblée pour: ${user.username}');
          
          // OPTIMISATION: Sync shops en arrière-plan seulement (pas de commissions)
          Future.delayed(const Duration(seconds: 5), () async {
            try {
              debugPrint('🔄 Sync arrière-plan: shops seulement...');
              await prefs.remove('last_sync_shops');
              
              await syncService.downloadTableData('shops', 'login_sync', 'admin');
              await ShopService.instance.loadShops(forceRefresh: true);
              
              debugPrint('✅ Sync shops arrière-plan terminée');
            } catch (e) {
              debugPrint('⚠️ Erreur sync shops arrière-plan: $e');
            }
          });
          
          return user;
        } else {
          debugPrint('❌ Agent "$username" toujours non trouvé après sync ciblée');
        }
      } catch (syncError) {
        debugPrint('⚠️ Erreur lors de la sync ciblée: $syncError');
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Erreur lors de la sync et retry login: $e');
      return null;
    }
  }

  // Déconnexion
  Future<void> logout() async {
    _setLoading(true);
    
    try {
      // Effacer les données de session
      _currentUser = null;
      _currentShop = null;
      _currentClient = null;
      _isAuthenticated = false;
      
      // Effacer les préférences de connexion
      await _clearLoginPreferences();
      await _clearClientSession();
      
      
      debugPrint('✅ Déconnexion réussie');
    } catch (e) {
      _errorMessage = 'Erreur lors de la déconnexion: $e';
      debugPrint(_errorMessage);
    }
    
    _setLoading(false);
  }

  // Sauvegarder utilisateur localement pour synchronisation future
  Future<void> _saveUserLocally(UserModel user) async {
    // TODO: Implémenter la sauvegarde locale des données utilisateur
    // pour synchronisation future avec MySQL
  }
  Future<bool> _isOnline() async {
    try {
      // TODO: Implémenter la vérification de connexion
      // Peut utiliser connectivity_plus package
      return false; // Temporairement offline
    } catch (e) {
      return false;
    }
  }

  // Sauvegarder les préférences de connexion
  Future<void> _saveLoginPreferences({bool rememberMe = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setBool('remember_me', rememberMe);
    await prefs.setString('last_login', DateTime.now().toIso8601String());
    
    // Sauvegarder le rôle et shop_id pour le filtrage de la synchronisation
    if (_currentUser != null) {
      await prefs.setString('user_role', _currentUser!.role.toLowerCase());  // admin ou agent
      if (_currentUser!.shopId != null) {
        await prefs.setInt('current_shop_id', _currentUser!.shopId!);
      } else {
        await prefs.remove('current_shop_id');  // Admin n'a pas de shop
      }
    }
    
    if (rememberMe && _currentUser != null) {
      await prefs.setString('remembered_username', _currentUser!.username);
    } else {
      await prefs.remove('remembered_username');
    }
  }

  // Supprimer les préférences de connexion
  Future<void> _clearLoginPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_logged_in');
    await prefs.remove('last_login');
    await prefs.remove('remember_me');
    await prefs.remove('remembered_username');
  }

  // Récupérer le nom d'utilisateur mémorisé
  Future<String?> getRememberedUsername() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberMe = prefs.getBool('remember_me') ?? false;
    if (rememberMe) {
      return prefs.getString('remembered_username');
    }
    return null;
  }

  // Méthodes de synchronisation future
  Future<void> syncUserData() async {
    if (!await _isOnline()) return;
    
    try {
      // TODO: Implémenter la synchronisation avec MySQL
      // 1. Envoyer les données locales non synchronisées
      // 2. Récupérer les nouvelles données du serveur
      // 3. Mettre à jour la base locale
      debugPrint('Synchronisation des données utilisateur...');
    } catch (e) {
      debugPrint('Erreur synchronisation: $e');
    }
  }

  /// Rafraîchir les données utilisateur et shop depuis la base locale
  /// À appeler après une synchronisation pour récupérer les modifications
  /// faites par l'admin (commission, shop, agents, etc.)
  Future<void> refreshUserData() async {
    try {
      debugPrint('🔄 Rafraîchissement des données utilisateur...');
      
      // 1. Rafraîchir les services de données de base
      debugPrint('📊 Rafraîchissement des services de données...');
      
      // Rafraîchir les taux et commissions (forceRefresh uniquement, pas de suppression)
      try {
        await RatesService.instance.loadRatesAndCommissions();
        debugPrint('✅ Taux et commissions rechargés');
      } catch (e) {
        debugPrint('⚠️ Erreur rechargement taux/commissions: $e');
      }
      
      // Rafraîchir les shops (forceRefresh uniquement, pas de suppression)
      try {
        await ShopService.instance.loadShops(forceRefresh: true);
        debugPrint('✅ Shops rechargés');
      } catch (e) {
        debugPrint('⚠️ Erreur rechargement shops: $e');
      }
      
      // 2. Rafraîchir l'utilisateur actuel depuis la base locale
      if (_currentUser != null) {
        final userId = _currentUser!.id;
        final username = _currentUser!.username;
        final currentRole = _currentUser!.role; // Préserver le rôle actuel
        
        // ========== PROTECTION ADMIN ==========
        // Si l'utilisateur actuel est un ADMIN, TOUJOURS vérifier dans les admins locaux
        // pour éviter qu'un agent du serveur avec le même username écrase la session admin
        if (currentRole == 'ADMIN') {
          debugPrint('🔐 Utilisateur ADMIN détecté: $username - Protection de session activée');
          
          // Chercher dans TOUS les admins locaux (pas seulement le défaut)
          final allAdmins = await LocalDB.instance.getAllAdmins();
          UserModel? localAdmin;
          
          // Chercher par username dans les admins personnalisés
          for (var admin in allAdmins) {
            if (admin.username == username) {
              localAdmin = admin;
              break;
            }
          }
          
          // Si pas trouvé, vérifier l'admin par défaut temporaire
          if (localAdmin == null) {
            final defaultAdmin = await LocalDB.instance.getDefaultAdmin();
            if (defaultAdmin != null && defaultAdmin.username == username) {
              localAdmin = defaultAdmin;
            }
          }
          
          if (localAdmin != null) {
            // ADMIN TROUVÉ - Conserver la session admin protégée
            _currentUser = localAdmin;
            debugPrint('🔐 Admin rechargé depuis stockage protégé: ${localAdmin.username}');
            
            // Mettre à jour la session sauvegardée
            await LocalDB.instance.saveUserSession(_currentUser!);
            
            // Notifier les listeners pour mettre à jour l'interface
            notifyListeners();
            
            debugPrint('✅ Données admin rafraîchies avec succès (session protégée)');
            // Pas besoin de shop pour l'admin
            return;
          } else {
            // Admin non trouvé dans le stockage local - GARDER la session actuelle
            debugPrint('⚠️ Admin $username non trouvé dans stockage local - Session conservée');
            return;
          }
        }
        // ========== FIN PROTECTION ADMIN ==========
        
        // Pour les AGENTS uniquement, recharger depuis AgentService
        await AgentService.instance.loadAgents(forceRefresh: true);
        
        // Recharger l'utilisateur depuis AgentService
        AgentModel? updatedAgent;
        if (userId != null) {
          updatedAgent = AgentService.instance.getAgentById(userId);
        }
        
        // Si pas trouvé par ID, chercher par username
        if (updatedAgent == null) {
          try {
            updatedAgent = AgentService.instance.agents.firstWhere(
              (agent) => agent.username == username,
            );
          } catch (e) {
            debugPrint('⚠️ Agent non trouvé par username: $username');
          }
        }
        
        if (updatedAgent != null) {
          // SÉCURITÉ: Vérifier que l'agent trouvé n'est pas un ADMIN
          // pour éviter de remplacer un admin par un agent du serveur
          if (updatedAgent.role == 'ADMIN') {
            debugPrint('⚠️ Agent trouvé avec role ADMIN - Ignoré pour protéger la session');
            return;
          }
          
          // Convertir AgentModel en UserModel
          _currentUser = UserModel(
            id: updatedAgent.id,
            username: updatedAgent.username,
            password: updatedAgent.password,
            role: updatedAgent.role,
            shopId: updatedAgent.shopId,
            nom: updatedAgent.nom,
            telephone: updatedAgent.telephone,
            createdAt: updatedAgent.createdAt,
          );
          
          debugPrint('✅ Agent rechargé: ${updatedAgent.username} (Rôle: ${updatedAgent.role})');
          
          // Rafraîchir le shop si l'utilisateur a un shopId
          if (updatedAgent.shopId != null) {
            final updatedShop = await LocalDB.instance.getShopById(updatedAgent.shopId!);
            if (updatedShop != null) {
              _currentShop = updatedShop;
              debugPrint('✅ Shop rechargé: ${updatedShop.designation}');
            }
          }
          
          // Mettre à jour la session sauvegardée
          await LocalDB.instance.saveUserSession(_currentUser!);
          
          // Notifier les listeners pour mettre à jour l'interface
          notifyListeners();
          
          debugPrint('✅ Données agent rafraîchies avec succès');
        } else {
          debugPrint('⚠️ Agent non trouvé lors du rafraîchissement');
        }
      }
      
      // 3. Rafraîchir le client actuel si applicable
      if (_currentClient != null) {
        final clientId = _currentClient!.id;
        if (clientId != null) {
          final updatedClient = await LocalDB.instance.getClientById(clientId);
          if (updatedClient != null) {
            _currentClient = updatedClient;
            debugPrint('✅ Client rechargé: ${updatedClient.nom}');
            notifyListeners();
          }
        }
      }
      
      debugPrint('🎉 Rafraîchissement complet des données terminé');
    } catch (e) {
      debugPrint('❌ Erreur rafraîchissement données utilisateur: $e');
    }
  }

  /// Déclencher une synchronisation automatique après login
  /// OPTIMISÉ: Synchronisation légère et non-bloquante
  void _triggerPostLoginSync() {
    // Exécuter la synchronisation en arrière-plan avec délai plus long
    Future.delayed(const Duration(seconds: 3), () async {
      try {
        debugPrint('🔄 Synchronisation post-login optimisée...');
        
        // OPTIMISATION: Sync seulement les données critiques
        final syncService = SyncService();
        
        // Sync ciblée - seulement agents et shops (plus rapide)
        try {
          await Future.wait([
            syncService.downloadTableData('agents', 'post_login_sync', _currentUser?.username ?? 'unknown'),
            syncService.downloadTableData('shops', 'post_login_sync', _currentUser?.username ?? 'unknown'),
          ], eagerError: false); // Continue même si une sync échoue
          
          debugPrint('✅ Synchronisation post-login optimisée terminée');
          
          // Rafraîchir seulement si nécessaire (pas de refreshUserData complet)
          if (_currentUser?.role == 'AGENT') {
            await _refreshAgentDataLightweight();
          }
        } catch (e) {
          debugPrint('⚠️ Sync post-login partielle: $e');
          // Continuer même en cas d'erreur partielle
        }
      } catch (e) {
        debugPrint('⚠️ Erreur synchronisation post-login: $e');
      }
    });
  }
  
  /// Rafraîchissement léger des données agent (optimisé)
  Future<void> _refreshAgentDataLightweight() async {
    try {
      if (_currentUser?.role == 'AGENT' && _currentUser?.shopId != null) {
        // Recharger seulement le shop si nécessaire
        final updatedShop = await LocalDB.instance.getShopById(_currentUser!.shopId!);
        if (updatedShop != null && updatedShop != _currentShop) {
          _currentShop = updatedShop;
          notifyListeners();
          debugPrint('✅ Shop mis à jour: ${updatedShop.designation}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur rafraîchissement léger: $e');
    }
  }

  // Méthodes utilitaires privées
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }


  // Connexion client
  Future<bool> loginClient({
    required String username,
    required String password,
  }) async {
    _setLoading(true);
    _clearError();

    try {
      // Rechercher le client par nom d'utilisateur
      final clients = await LocalDB.instance.getAllClients();
      final client = clients.firstWhere(
        (c) => c.username == username,
        orElse: () => throw Exception('Client non trouvé'),
      );

      // Vérifier le mot de passe (dans un vrai système, il serait hashé)
      if (client.password != password) {
        throw Exception('Mot de passe incorrect');
      }

      // Vérifier que le compte est actif
      if (!client.isActive) {
        throw Exception('Compte désactivé. Contactez votre agent.');
      }

      _currentClient = client;
      _isAuthenticated = true;

      // Sauvegarder la session client
      await _saveClientSession(client);

      debugPrint('✅ Connexion client réussie: ${client.nom}');
      return true;
    } catch (e) {
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      debugPrint('❌ Erreur connexion client: $_errorMessage');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Sauvegarder la session client
  Future<void> _saveClientSession(ClientModel client) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_client_logged_in', true);
    await prefs.setInt('client_id', client.id!);
    await prefs.setString('client_username', client.username ?? '');
    await prefs.setString('last_client_login', DateTime.now().toIso8601String());
  }

  // Vérifier une session client sauvegardée
  Future<void> checkSavedClientSession() async {
    _setLoading(true);
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final isClientLoggedIn = prefs.getBool('is_client_logged_in') ?? false;
      
      if (isClientLoggedIn) {
        final clientId = prefs.getInt('client_id');
        if (clientId != null) {
          final client = await LocalDB.instance.getClientById(clientId);
          if (client != null && client.isActive) {
            _currentClient = client;
            _isAuthenticated = true;
          } else {
            await _clearClientSession();
          }
        }
      }
    } catch (e) {
      debugPrint('Erreur vérification session client: $e');
      await _clearClientSession();
    }
    
    _setLoading(false);
  }

  // Effacer la session client
  Future<void> _clearClientSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('is_client_logged_in');
    await prefs.remove('client_id');
    await prefs.remove('client_username');
    await prefs.remove('last_client_login');
  }

  // Mettre à jour le client actuel
  void updateCurrentClient(ClientModel client) {
    _currentClient = client;
    notifyListeners();
  }

  // Obtenir le message d'accueil selon le rôle
  String get welcomeMessage {
    if (_currentClient != null) {
      return 'Bienvenue ${_currentClient!.nom}';
    }
    
    if (_currentUser == null) return '';
    
    final name = displayName;
    switch (_currentUser!.role) {
      case 'ADMIN':
        return 'Bienvenue Administrateur $name';
      case 'AGENT':
        return 'Bienvenue Agent $name';
      case 'COMPTE':
        return 'Bienvenue $name';
      default:
        return 'Bienvenue $name';
    }
  }

  // Changer le mot de passe de l'utilisateur actuel
  Future<bool> changePassword(String currentPassword, String newPassword) async {
    if (_currentUser == null) {
      _errorMessage = 'Aucun utilisateur connecté';
      return false;
    }

    try {
      // Vérifier le mot de passe actuel
      final user = await LocalDB.instance.getAgentByCredentials(
        _currentUser!.username,
        currentPassword,
      );

      if (user == null) {
        _errorMessage = 'Mot de passe actuel incorrect';
        return false;
      }

      // Mettre à jour le mot de passe dans la base locale
      await LocalDB.instance.updateAgentPassword(
        user.id!,
        newPassword,
      );

      debugPrint('✅ Mot de passe mis à jour pour: ${user.username}');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors du changement de mot de passe: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }
}