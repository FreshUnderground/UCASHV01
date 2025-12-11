import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../data/initial_client_data.dart';
import 'local_db.dart';
import 'sync_service.dart';
import 'connectivity_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../config/app_config.dart';

class ClientService extends ChangeNotifier {
  static final ClientService _instance = ClientService._internal();
  factory ClientService() => _instance;
  ClientService._internal();

  List<ClientModel> _clients = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<ClientModel> get clients => _clients;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  // Charger tous les clients (GLOBAUX - visibles dans tous les shops)
  Future<void> loadClients({int? shopId, bool clearBeforeLoad = false}) async {
    _setLoading(true);
    try {
      // Si clearBeforeLoad, supprimer toutes les données locales pour forcer le rechargement depuis le serveur
      if (clearBeforeLoad) {
        debugPrint('🗑️ [ClientService] Suppression des clients en local avant rechargement...');
        await LocalDB.instance.clearAllClients();
        _clients.clear();
      }
      
      // IMPORTANT: Toujours charger TOUS les clients LOCALEMENT d'abord
      // Le paramètre shopId est ignoré - les clients sont accessibles partout
      _clients = await LocalDB.instance.getAllClients();
      
      // Pas d'initialisation de données par défaut
      // Les clients sont créés uniquement par les agents
      
      _errorMessage = null;
      debugPrint('👥 Clients chargés LOCALEMENT (GLOBAUX): ${_clients.length}');
      
      // Notifier les listeners pour mettre à jour l'UI IMMÉDIATEMENT
      notifyListeners();
      
      // Vérifier les clients supprimés sur le serveur EN ARRIÈRE-PLAN
      _checkForDeletedClients();
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des clients: $e';
      debugPrint(_errorMessage);
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }
  
  /// Synchroniser les clients depuis le serveur (Téléchargement + Rechargement)
  Future<bool> syncFromServer() async {
    try {
      debugPrint('='.padRight(60, '='));
      debugPrint('🔄 [ClientService] DÉBUT SYNCHRONISATION DEPUIS SERVEUR');
      debugPrint('='.padRight(60, '='));
      _setLoading(true);
      
      // Vérifier la connectivité
      debugPrint('🌐 [ClientService] Vérification connectivité internet...');
      final connectivityService = ConnectivityService.instance;
      final isOnline = connectivityService.isOnline;
      debugPrint('🌐 [ClientService] Statut connexion: ${isOnline ? "EN LIGNE" : "HORS LIGNE"}');
      
      if (!isOnline) {
        debugPrint('⚠️ [ClientService] HORS LIGNE - Synchronisation annulée');
        _errorMessage = 'Pas de connexion internet';
        notifyListeners();
        return false;
      }
      
      // Nombre de clients AVANT synchronisation
      final clientsAvant = _clients.length;
      debugPrint('📊 [ClientService] Clients en mémoire AVANT sync: $clientsAvant');
      
      // Vérifier LocalDB AVANT
      final localClientsAvant = await LocalDB.instance.getAllClients();
      debugPrint('💾 [ClientService] Clients en LocalDB AVANT sync: ${localClientsAvant.length}');
      
      // IMPORTANT: Réinitialiser le timestamp pour FORCER le téléchargement COMPLET
      debugPrint('🗑️ [ClientService] Réinitialisation timestamp clients pour download complet...');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_clients');
      debugPrint('✅ [ClientService] Timestamp réinitialisé - téléchargement COMPLET activé');
      
      // Télécharger les clients depuis le serveur
      debugPrint('📥 [ClientService] Lancement downloadTableData("clients") - DOWNLOAD COMPLET...');
      final syncService = SyncService();
      await syncService.downloadTableData('clients', 'admin', 'admin');
      debugPrint('✅ [ClientService] downloadTableData() terminé sans exception');
      
      // DIAGNOSTIC: Vérifier combien de clients MySQL a retourné
      debugPrint('🔍 [ClientService] Vérification directe de la base MySQL...');
      try {
        final response = await http.get(
          Uri.parse('${AppConfig.apiBaseUrl}/clients/changes.php?since=2020-01-01T00:00:00.000'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          final mysqlClients = (result['entities'] as List?) ?? [];
          debugPrint('📊 [ClientService] MySQL contient: ${mysqlClients.length} clients');
          if (mysqlClients.isNotEmpty) {
            debugPrint('📋 [ClientService] Premiers 3 clients MySQL:');
            for (int i = 0; i < (mysqlClients.length > 3 ? 3 : mysqlClients.length); i++) {
              final c = mysqlClients[i];
              debugPrint('   - ID: ${c['id']}, Nom: ${c['nom']}, Tél: ${c['telephone']}');
            }
          }
        } else {
          debugPrint('⚠️ [ClientService] Erreur HTTP ${response.statusCode} depuis MySQL');
        }
      } catch (e) {
        debugPrint('⚠️ [ClientService] Erreur vérification MySQL: $e');
      }
      
      // Vérifier LocalDB APRÈS
      final localClientsApres = await LocalDB.instance.getAllClients();
      debugPrint('💾 [ClientService] Clients en LocalDB APRÈS sync: ${localClientsApres.length}');
      
      // Recharger depuis LocalDB (qui contient maintenant les données à jour)
      _clients = localClientsApres;
      final clientsApres = _clients.length;
      debugPrint('📊 [ClientService] Clients en mémoire APRÈS sync: $clientsApres');
      
      // Afficher le différentiel
      final diff = clientsApres - clientsAvant;
      if (diff > 0) {
        debugPrint('🎉 [ClientService] +$diff nouveau(x) client(s) synchronisé(s)');
      } else if (diff < 0) {
        debugPrint('🗑️ [ClientService] ${diff.abs()} client(s) supprimé(s)');
      } else {
        debugPrint('✅ [ClientService] Aucun changement ($clientsApres clients)');
      }
      
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('='.padRight(60, '='));
      debugPrint('✅ [ClientService] SYNCHRONISATION TERMINÉE AVEC SUCCÈS');
      debugPrint('='.padRight(60, '='));
      return true;
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur lors de la synchronisation: $e';
      debugPrint('='.padRight(60, '='));
      debugPrint('❌ [ClientService] ERREUR SYNCHRONISATION');
      debugPrint('❌ Erreur: $e');
      debugPrint('❌ Stack trace: $stackTrace');
      debugPrint('='.padRight(60, '='));
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // Créer un nouveau client (GLOBAL - accessible depuis tous les shops)
  Future<bool> createClient({
    required String nom,
    required String telephone,
    String? adresse,
    String? username,
    String? password,
    int? shopId,  // Changé de required int à int? pour permettre null
    required int agentId,
  }) async {
    try {
      // Vérifier si le téléphone existe déjà
      if (await _phoneExists(telephone)) {
        _errorMessage = 'Ce numéro de téléphone existe déjà';
        notifyListeners();
        return false;
      }

      // Vérifier si le username existe déjà (s'il est fourni)
      if (username != null && await _usernameExists(username)) {
        _errorMessage = 'Ce nom d\'utilisateur existe déjà';
        notifyListeners();
        return false;
      }

      final newClient = ClientModel(
        nom: nom,
        telephone: telephone,
        adresse: adresse,
        username: username,
        password: password,
        numeroCompte: null,  // Sera NULL en DB - on utilise l'ID formaté
        shopId: shopId,  // Shop de création (pour traçabilité) - peut être null
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentId',
      );

      // Sauvegarder localement
      final savedClient = await LocalDB.instance.saveClient(newClient);
      
      // Ajouter IMMÉDIATEMENT à la liste en mémoire pour mise à jour instantanée de l'UI
      _clients.add(savedClient);
      debugPrint('💾 Client ajouté à la liste en mémoire: ${savedClient.nom} (ID: ${savedClient.id})');
      
      // Notifier IMMÉDIATEMENT les listeners pour mettre à jour l'UI
      notifyListeners();
      
      // Synchroniser vers le serveur en arrière-plan (ne pas attendre)
      if (savedClient.id != null) {
        _syncClientUpdateToServer(savedClient);
      }
      
      debugPrint('✅ Client créé (GLOBAL): $nom - visible dans tous les shops');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du client: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }


  // Mettre à jour un client
  Future<bool> updateClient(ClientModel client) async {
    try {
      debugPrint('✏️ [ClientService] Mise à jour du client ID: ${client.id}...');
      
      // 1. Mettre à jour localement d'abord (pour une réponse rapide)
      await LocalDB.instance.updateClient(client);
      debugPrint('✅ [ClientService] Client mis à jour localement');
      
      // 2. Mettre à jour IMMÉDIATEMENT dans la liste en mémoire
      final index = _clients.indexWhere((c) => c.id == client.id);
      if (index != -1) {
        _clients[index] = client;
        debugPrint('💾 Client mis à jour dans la liste en mémoire: ${client.nom}');
      }
      
      // 3. Notifier IMMÉDIATEMENT les listeners pour mettre à jour l'UI
      notifyListeners();
      
      // 4. Essayer de synchroniser avec le serveur en arrière-plan
      _syncClientUpdateToServer(client);
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du client: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Vérifier les clients supprimés sur le serveur et les supprimer localement
  Future<void> _checkForDeletedClients() async {
    try {
      // Récupérer tous les IDs de clients locaux
      final localClients = await LocalDB.instance.getAllClients();
      
      if (localClients.isEmpty) {
        debugPrint('✅ [ClientService] Aucun client local - skip vérification suppression');
        return;
      }
      
      final clientIds = localClients
          .where((c) => c.id != null)
          .map((c) => c.id!)
          .toList();
      
      if (clientIds.isEmpty) {
        debugPrint('⚠️ [ClientService] Aucun ID valide - skip vérification suppression');
        return;
      }
      
      final url = '${AppConfig.apiBaseUrl}/sync/clients/check_deleted.php';
      debugPrint('🔍 [ClientService] Vérification de ${clientIds.length} clients...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({'client_ids': clientIds}),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final deletedClients = List<int>.from(data['deleted_clients']);
          
          if (deletedClients.isNotEmpty) {
            debugPrint('🗑️ [ClientService] ${deletedClients.length} client(s) supprimé(s) trouvé(s) sur le serveur');
            
            // Supprimer les clients locaux qui ont été supprimés du serveur
            for (final clientId in deletedClients) {
              await LocalDB.instance.deleteClient(clientId);
              debugPrint('  • Client ID $clientId supprimé localement');
            }
            
            // Recharger la liste en mémoire
            _clients = await LocalDB.instance.getAllClients();
            debugPrint('✅ [ClientService] Liste clients mise à jour: ${_clients.length} clients');
          } else {
            debugPrint('✅ [ClientService] Aucun client supprimé trouvé');
          }
        } else {
          debugPrint('⚠️ [ClientService] Erreur vérification suppressions: ${data['error']}');
        }
      } else {
        debugPrint('⚠️ [ClientService] HTTP ${response.statusCode} lors de la vérification');
      }
    } catch (e) {
      debugPrint('⚠️ [ClientService] Erreur vérification clients supprimés: $e');
      // Ne pas bloquer le chargement - continuer
    }
  }
  
  /// Synchroniser la mise à jour du client vers le serveur en arrière-plan
  void _syncClientUpdateToServer(ClientModel client) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/clients/upload.php';
      debugPrint('🌐 [ClientService] Sync client update to server...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'entities': [client.toJson()],
          'user_id': 'admin',
          'timestamp': DateTime.now().toIso8601String(),
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [ClientService] Client synchronized to server: ${result['updated']} updated');
        } else {
          debugPrint('⚠️ [ClientService] Server error: ${result['message']}');
        }
      } else {
        debugPrint('⚠️ [ClientService] HTTP Error ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [ClientService] Background sync failed: $e');
      // Don't propagate error - local update already succeeded
    }
  }

  // Supprimer un client
  Future<bool> deleteClient(int clientId, int shopId) async {
    try {
      debugPrint('🗑️ [ClientService] Suppression du client ID: $clientId...');
      
      // 1. Essayer de supprimer sur le serveur d'abord
      try {
        final url = '${AppConfig.apiBaseUrl}/sync/clients/delete.php';
        debugPrint('🌐 [ClientService] Appel API: $url');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {
            'Content-Type': 'application/json; charset=utf-8',
            'Accept': 'application/json',
          },
          body: jsonEncode({'id': clientId}),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            debugPrint('✅ [ClientService] Client supprimé sur le serveur: ${result['client_name']}');
          } else {
            debugPrint('⚠️ [ClientService] Erreur serveur: ${result['message']}');
            // Si le serveur refuse (ex: opérations associées), propager l'erreur
            _errorMessage = result['message'];
            notifyListeners();
            return false;
          }
        } else {
          debugPrint('⚠️ [ClientService] Erreur HTTP ${response.statusCode}');
          // Continue avec la suppression locale même si le serveur échoue
        }
      } catch (e) {
        debugPrint('⚠️ [ClientService] Erreur connexion serveur: $e');
        debugPrint('   Suppression locale uniquement (sera re-synchronisé)');
        // Continue avec la suppression locale
      }
      
      // 2. Supprimer localement
      await LocalDB.instance.deleteClient(clientId);
      debugPrint('✅ [ClientService] Client supprimé localement');
      
      // 3. Supprimer IMMÉDIATEMENT de la liste en mémoire
      _clients.removeWhere((c) => c.id == clientId);
      debugPrint('💾 Client supprimé de la liste en mémoire');
      
      // 4. Notifier IMMÉDIATEMENT les listeners pour mettre à jour l'UI
      notifyListeners();
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression du client: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Obtenir un client par ID
  ClientModel? getClientById(int id) {
    try {
      return _clients.firstWhere((client) => client.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtenir les clients d'un shop spécifique (pour statistiques uniquement)
  List<ClientModel> getClientsByShop(int shopId) {
    // NOTE: Cette méthode est conservée pour les statistiques par shop
    // Mais les clients restent GLOBAUX et accessibles partout
    return _clients.where((client) => client.shopId == shopId).toList();
  }

  // Rechercher des clients par nom ou téléphone
  List<ClientModel> searchClients(String query) {
    final lowerQuery = query.toLowerCase();
    return _clients.where((client) =>
      client.nom.toLowerCase().contains(lowerQuery) ||
      client.telephone.contains(query)
    ).toList();
  }

  // Vérifier si un téléphone existe déjà
  Future<bool> _phoneExists(String telephone) async {
    final existingClients = await LocalDB.instance.getAllClients();
    return existingClients.any((client) => client.telephone == telephone);
  }

  // Vérifier si un username existe déjà
  Future<bool> _usernameExists(String username) async {
    final existingClients = await LocalDB.instance.getAllClients();
    return existingClients.any((client) => client.username == username);
  }

  // Obtenir les statistiques des clients
  Map<String, dynamic> getClientsStats(int shopId) {
    final shopClients = getClientsByShop(shopId);
    final activeClients = shopClients.where((c) => c.isActive).length;
    final withAccounts = shopClients.where((c) => c.username != null).length;
    
    return {
      'totalClients': shopClients.length,
      'activeClients': activeClients,
      'withAccounts': withAccounts,
      'withoutAccounts': shopClients.length - withAccounts,
    };
  }
}
