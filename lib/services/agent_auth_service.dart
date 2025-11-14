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

  AgentModel? get currentAgent => _currentAgent;
  ShopModel? get currentShop => _currentShop;
  bool get isAuthenticated => _isAuthenticated;
  String? get errorMessage => _errorMessage;

  Future<bool> login(String username, String password) async {
    try {
      _errorMessage = null;
      
      // Rechercher l'agent dans la base locale
      final agents = await LocalDB.instance.getAllAgents();
      final agent = agents.firstWhere(
        (a) => a.username == username && a.password == password && a.isActive,
        orElse: () => throw Exception('Agent non trouvé ou inactif'),
      );

      // Récupérer le shop associé
      final shops = await LocalDB.instance.getAllShops();
      final shop = shops.firstWhere(
        (s) => s.id == agent.shopId,
        orElse: () => throw Exception('Shop associé non trouvé'),
      );

      _currentAgent = agent;
      _currentShop = shop;
      _isAuthenticated = true;
      
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isAuthenticated = false;
      notifyListeners();
      return false;
    }
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
