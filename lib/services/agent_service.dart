import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/agent_model.dart';
import 'local_db.dart';
import 'sync_service.dart';
import 'shop_service.dart';

class AgentService extends ChangeNotifier {
  static final AgentService _instance = AgentService._internal();
  static AgentService get instance => _instance;
  
  AgentService._internal();

  List<AgentModel> _agents = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AgentModel> get agents => _agents;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Charger tous les agents
  Future<void> loadAgents({bool forceRefresh = false, bool clearBeforeLoad = false}) async {
    _setLoading(true);
    try {
      // Si clearBeforeLoad, supprimer toutes les données locales pour forcer le rechargement depuis le serveur
      if (clearBeforeLoad) {
        debugPrint('🗑️ [AgentService] Suppression des agents en local avant rechargement...');
        await LocalDB.instance.clearAllAgents();
        _agents.clear();
      }
      
      // Si forceRefresh, vider d'abord le cache
      if (forceRefresh) {
        _agents.clear();
        debugPrint('🗑️ [AgentService] Cache vidé - Rechargement forcé');
      }
      
      // S'assurer que l'admin existe
      await LocalDB.instance.ensureAdminExists();
      
      // Nettoyer les données corrompues avant le chargement
      await LocalDB.instance.cleanCorruptedAgentData();
      
      _agents = await LocalDB.instance.getAllAgents();
      debugPrint('📋 Agents chargés: ${_agents.length}');
      _errorMessage = null;
      notifyListeners(); // Notifier les widgets après le chargement
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des agents: $e';
      debugPrint(_errorMessage);
    }
    _setLoading(false);
  }

  // Créer un nouvel agent
  Future<bool> createAgent({
    required String username,
    required String password,
    int? shopId,
    String role = 'AGENT',
  }) async {
    _setLoading(true);
    try {
      // Vérifier si le username existe déjà
      if (await _usernameExists(username)) {
        _errorMessage = 'Ce nom d\'utilisateur existe déjà';
        _setLoading(false);
        return false;
      }

      // Récupérer le nom du shop pour le shop_designation (seulement si shopId est fourni)
      String? shopDesignation;
      if (shopId != null) {
        final shops = ShopService.instance.shops;
        final shop = shops.where((s) => s.id == shopId).firstOrNull;
        shopDesignation = shop?.designation;
      }

      final newAgent = AgentModel(
        username: username,
        password: password, // En production, hasher le mot de passe
        shopId: shopId,
        shopDesignation: shopDesignation,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'admin',
      );

      // Sauvegarder localement (l'ID sera généré automatiquement)
      final savedAgent = await LocalDB.instance.saveAgent(newAgent);
      debugPrint('✅ Agent sauvegardé avec ID: ${savedAgent.id}, Shop: $shopDesignation');
      
      // Recharger la liste
      await loadAgents();
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      debugPrint('✅ Agent créé localement: $username');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création de l\'agent: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Mettre à jour un agent
  Future<bool> updateAgent(AgentModel agent) async {
    _setLoading(true);
    try {
      if (agent.id == null) {
        throw Exception('L\'ID de l\'agent est requis pour la mise à jour');
      }

      debugPrint('🔄 Mise à jour de l\'agent: ${agent.username} (ID: ${agent.id})');
      
      // Mettre à jour via LocalDB
      await LocalDB.instance.updateAgent(agent);
      debugPrint('✅ Agent mis à jour avec succès');
      
      // Recharger complètement avec cache vidé
      await loadAgents(forceRefresh: true);
      
      // Synchronisation en arrière-plan
      _syncInBackground();
      
      _errorMessage = null;
      _setLoading(false);
      debugPrint('✅ Agent mis à jour localement: ${agent.username}');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour de l\'agent: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Supprimer un agent
  Future<bool> deleteAgent(int agentId) async {
    _setLoading(true);
    try {
      await LocalDB.instance.deleteAgent(agentId);
      
      // Recharger la liste
      await loadAgents();
      
      _errorMessage = null;
      _setLoading(false);
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression de l\'agent: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Obtenir un agent par ID
  AgentModel? getAgentById(int id) {
    try {
      return _agents.firstWhere((agent) => agent.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtenir les agents d'un shop spécifique
  List<AgentModel> getAgentsByShop(int shopId) {
    return _agents.where((agent) => agent.shopId == shopId).toList();
  }

  // Vérifier si un username existe déjà
  Future<bool> _usernameExists(String username) async {
    final existingAgents = await LocalDB.instance.getAllAgents();
    return existingAgents.any((agent) => agent.username == username);
  }

  // Obtenir les statistiques des agents
  Map<String, dynamic> getAgentsStats() {
    final agentsByShop = <int, int>{};
    for (var agent in _agents) {
      if (agent.shopId != null) {
        agentsByShop[agent.shopId!] = (agentsByShop[agent.shopId!] ?? 0) + 1;
      }
    }

    return {
      'totalAgents': _agents.length,
      'agentsByShop': agentsByShop,
      'activeAgents': _agents.length, // Tous les agents sont considérés actifs
    };
  }

  // Valider les données d'un agent
  String? validateAgentData({
    required String username,
    required String password,
    required int? shopId,
  }) {
    if (username.trim().isEmpty) {
      return 'Le nom d\'utilisateur est requis';
    }
    if (username.length < 3) {
      return 'Le nom d\'utilisateur doit contenir au moins 3 caractères';
    }
    if (password.trim().isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (password.length < 6) {
      return 'Le mot de passe doit contenir au moins 6 caractères';
    }
    if (shopId == null) {
      return 'Veuillez sélectionner un shop';
    }
    return null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    // Utiliser SchedulerBinding pour éviter setState pendant build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Créer des agents de test pour vérifier le système
  Future<void> createTestAgents() async {
    try {
      debugPrint('🧪 Création d\'agents de test...');
      
      // Agent 1
      await createAgent(
        username: 'agent_test1',
        password: 'test123',
        shopId: 1, // Premier shop disponible
      );
      
      // Agent 2
      await createAgent(
        username: 'agent_test2',
        password: 'test123',
        shopId: 1,
      );
      
      debugPrint('✅ Agents de test créés avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de la création des agents de test: $e');
    }
  }

  // Synchronisation en arrière-plan (non bloquante)
  void _syncInBackground() {
    Future.delayed(Duration.zero, () async {
      try {
        debugPrint('🔄 [AgentService] Synchronisation en arrière-plan...');
        final syncService = SyncService();
        await syncService.syncAll();
        debugPrint('✅ [AgentService] Synchronisation terminée');
      } catch (e) {
        debugPrint('⚠️ [AgentService] Erreur sync (non bloquante): $e');
      }
    });
  }
}
