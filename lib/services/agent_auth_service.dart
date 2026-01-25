import 'package:flutter/foundation.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';
import 'local_db.dart';

class AgentAuthService extends ChangeNotifier {
  static final AgentAuthService _instance = AgentAuthService._internal();
  factory AgentAuthService() => _instance;
  AgentAuthService._internal();

  AgentModel? _currentAgent;
  ShopModel? _currentShop;
  bool _isAuthenticated = false;
  String? _errorMessage;

  // Référence au service de synchronisation (injecté)
  dynamic _syncService;

  AgentModel? get currentAgent => _currentAgent;
  ShopModel? get currentShop => _currentShop;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  /// Injecte le service de synchronisation
  void setSyncService(dynamic syncService) {
    _syncService = syncService;
  }

  Future<bool> login(String username, String password) async {
    try {
      _errorMessage = null;

      // Rechercher l'agent dans la base locale
      final agents = await LocalDB.instance.getAllAgents();
      debugPrint(
          '🔍 Login: ${agents.length} agents trouvés dans la base locale');

      final agent = agents.firstWhere(
        (a) => a.username == username && a.password == password && a.isActive,
        orElse: () => throw Exception('Agent non trouvé ou inactif'),
      );

      debugPrint('✅ Agent trouvé: ${agent.username} (ID: ${agent.id})');
      debugPrint('   Shop ID: ${agent.shopId}');
      debugPrint('   Shop Designation: ${agent.shopDesignation}');

      // Récupérer le shop associé (si l'agent en a un)
      ShopModel? shop;
      if (agent.shopId != null) {
        final shops = await LocalDB.instance.getAllShops();
        debugPrint('🏪 ${shops.length} shops trouvés dans la base locale');

        try {
          shop = shops.firstWhere((s) => s.id == agent.shopId);
          debugPrint('✅ Shop trouvé: ${shop.designation} (ID: ${shop.id})');
        } catch (e) {
          debugPrint(
              '⚠️ Shop ID ${agent.shopId} non trouvé pour agent ${agent.username}');
          debugPrint('   Liste des shops disponibles:');
          for (var s in shops) {
            debugPrint('   - Shop ID: ${s.id}, Nom: ${s.designation}');
          }
          // Continuer le login même sans shop
        }
      } else {
        debugPrint('⚠️ Agent ${agent.username} n\'a pas de shopId assigné');
      }

      _currentAgent = agent;
      _currentShop = shop;
      _isAuthenticated = true;

      debugPrint('🎉 Login réussi pour ${agent.username}');
      debugPrint('   currentAgent.shopId: ${_currentAgent?.shopId}');
      debugPrint('   currentShop: ${_currentShop?.designation ?? "null"}');

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;

      // 🔄 RELANCER LA SYNCHRONISATION APRÈS ÉCHEC DE LOGIN
      // Cela permet de récupérer les données manquantes (agents, shops)
      debugPrint('❌ Échec login: $_errorMessage');
      debugPrint('🔄 Lancement synchronisation pour récupérer les données...');
      _syncAfterLoginFailure();

      notifyListeners();
      return false;
    }
  }

  /// Synchronise les données après un échec de login
  Future<void> _syncAfterLoginFailure() async {
    try {
      // Import nécessaire pour accéder au RobustSyncService
      final robustSync = await _getRobustSyncService();
      if (robustSync != null) {
        debugPrint('🚀 Démarrage synchronisation shops & agents...');
        await robustSync.syncNow();
        debugPrint(
            '✅ Synchronisation terminée - veuillez réessayer de vous connecter');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur synchronisation après échec login: $e');
    }
  }

  /// Récupère l'instance de RobustSyncService (si disponible)
  Future<dynamic> _getRobustSyncService() async {
    return _syncService;
  }

  void logout() {
    _currentAgent = null;
    _currentShop = null;
    _isAuthenticated = false;
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> changePassword(String oldPassword, String newPassword) async {
    if (_currentAgent == null) return false;

    try {
      if (_currentAgent!.password != oldPassword) {
        _errorMessage = 'Ancien mot de passe incorrect';
        notifyListeners();
        return false;
      }

      final updatedAgent = _currentAgent!.copyWith(
        password: newPassword,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: _currentAgent!.username,
      );

      await LocalDB.instance.updateAgent(updatedAgent);
      _currentAgent = updatedAgent;
      _errorMessage = null;

      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> updateProfile({String? nom, String? telephone}) async {
    if (_currentAgent == null) return;

    try {
      final updatedAgent = _currentAgent!.copyWith(
        nom: nom ?? _currentAgent!.nom,
        telephone: telephone ?? _currentAgent!.telephone,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: _currentAgent!.username,
      );

      await LocalDB.instance.updateAgent(updatedAgent);
      _currentAgent = updatedAgent;
      _errorMessage = null;

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
    }
  }
}
