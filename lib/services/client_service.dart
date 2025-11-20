import 'package:flutter/foundation.dart';
import '../models/client_model.dart';
import '../data/initial_client_data.dart';
import 'local_db.dart';

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
  Future<void> loadClients({int? shopId}) async {
    _setLoading(true);
    try {
      // IMPORTANT: Toujours charger TOUS les clients (globaux)
      // Le paramètre shopId est ignoré - les clients sont accessibles partout
      _clients = await LocalDB.instance.getAllClients();
      
      // Pas d'initialisation de données par défaut
      // Les clients sont créés uniquement par les agents
      
      _errorMessage = null;
      debugPrint('👥 Clients chargés (GLOBAUX): ${_clients.length}');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des clients: $e';
      debugPrint(_errorMessage);
      notifyListeners();
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
    required int shopId,  // Shop de création (informatif uniquement)
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

      // Générer un numéro de compte unique
      final numeroCompte = _generateAccountNumber(shopId);

      final newClient = ClientModel(
        nom: nom,
        telephone: telephone,
        adresse: adresse,
        username: username,
        password: password,
        numeroCompte: numeroCompte,
        shopId: shopId,  // Shop de création (pour traçabilité)
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentId',
      );

      // Sauvegarder localement
      await LocalDB.instance.saveClient(newClient);
      
      // Recharger TOUS les clients (sans filtre)
      await loadClients();
      
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

  // Générer un numéro de compte unique
  String _generateAccountNumber(int shopId) {
    final now = DateTime.now();
    final dateStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final randomDigits = (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString().substring(0, 4);
    return '${shopId.toString().padLeft(3, '0')}$dateStr$randomDigits';
  }

  // Mettre à jour un client
  Future<bool> updateClient(ClientModel client) async {
    try {
      await LocalDB.instance.updateClient(client);
      // Recharger TOUS les clients (sans filtre)
      await loadClients();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du client: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Supprimer un client
  Future<bool> deleteClient(int clientId, int shopId) async {
    try {
      await LocalDB.instance.deleteClient(clientId);
      // Recharger TOUS les clients (sans filtre)
      await loadClients();
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
