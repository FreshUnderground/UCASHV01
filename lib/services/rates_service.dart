import 'package:flutter/material.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';
import '../services/local_db.dart';

class RatesService extends ChangeNotifier {
  static final RatesService _instance = RatesService._internal();
  static RatesService get instance => _instance;
  
  RatesService._internal();

  List<TauxModel> _taux = [];
  List<CommissionModel> _commissions = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<TauxModel> get taux => _taux;
  List<CommissionModel> get commissions => _commissions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  // Charger tous les taux et commissions
  Future<void> loadRatesAndCommissions() async {
    _setLoading(true);
    try {
      final loadedTaux = await LocalDB.instance.getAllTaux();
      final loadedCommissions = await LocalDB.instance.getAllCommissions();
      
      // Charger uniquement les données saisies par l'utilisateur
      _taux = loadedTaux;
      _commissions = loadedCommissions;
      
      debugPrint('Taux chargés: ${_taux.length}');
      debugPrint('Commissions chargées: ${_commissions.length}');
      
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }


  // === GESTION DES TAUX ===

  // Creer un nouveau taux (DEPRECATED - utiliser TauxChangeService)
  Future<bool> createTaux({
    required String devise,
    required double taux,
    required String type,
  }) async {
    _setLoading(true);
    try {
      // Generer un ID unique
      final tauxId = DateTime.now().millisecondsSinceEpoch;
      
      // Convertir en nouveau format (deviseSource/deviseCible)
      final newTaux = TauxModel(
        id: tauxId,
        deviseSource: 'USD', // Par defaut source = USD
        deviseCible: devise,  // Cible = devise fournie
        taux: taux,
        type: 'MOYEN',
      );

      await LocalDB.instance.saveTaux(newTaux);
      await loadRatesAndCommissions();
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la creation du taux: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Mettre à jour un taux
  Future<bool> updateTaux(TauxModel taux) async {
    _setLoading(true);
    try {
      await LocalDB.instance.updateTaux(taux);
      await loadRatesAndCommissions();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du taux: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Supprimer un taux
  Future<bool> deleteTaux(int tauxId) async {
    _setLoading(true);
    try {
      await LocalDB.instance.deleteTaux(tauxId);
      await loadRatesAndCommissions();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression du taux: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // === GESTION DES COMMISSIONS ===

  // Créer une nouvelle commission
  Future<bool> createCommission({
    required String type,
    required double taux,
    required String description,
  }) async {
    _setLoading(true);
    try {
      // Générer un ID unique
      final commissionId = DateTime.now().millisecondsSinceEpoch + 1;
      
      final newCommission = CommissionModel(
        id: commissionId,
        type: type,
        taux: taux,
        description: description,
      );

      await LocalDB.instance.saveCommission(newCommission);
      await loadRatesAndCommissions();
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création de la commission: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Mettre à jour une commission
  Future<bool> updateCommission(CommissionModel commission) async {
    _setLoading(true);
    try {
      await LocalDB.instance.updateCommission(commission);
      await loadRatesAndCommissions();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour de la commission: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // Supprimer une commission
  Future<bool> deleteCommission(int commissionId) async {
    _setLoading(true);
    try {
      await LocalDB.instance.deleteCommission(commissionId);
      await loadRatesAndCommissions();
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression de la commission: $e';
      debugPrint(_errorMessage);
      _setLoading(false);
      return false;
    }
  }

  // === MÉTHODES UTILITAIRES ===

  // Obtenir un taux par devise et type (DEPRECATED - utiliser TauxChangeService)
  TauxModel? getTauxByDeviseAndType(String devise, String type) {
    try {
      // Chercher avec la nouvelle structure (deviseCible)
      return _taux.firstWhere(
        (taux) => taux.deviseCible == devise && taux.type == type,
      );
    } catch (e) {
      return null;
    }
  }

  // Obtenir une commission par type
  CommissionModel? getCommissionByType(String type) {
    try {
      return _commissions.firstWhere(
        (commission) => commission.type == type,
      );
    } catch (e) {
      return null;
    }
  }

  // Obtenir un taux par ID
  TauxModel? getTauxById(int id) {
    try {
      return _taux.firstWhere((taux) => taux.id == id);
    } catch (e) {
      return null;
    }
  }

  // Obtenir une commission par ID
  CommissionModel? getCommissionById(int id) {
    try {
      return _commissions.firstWhere((commission) => commission.id == id);
    } catch (e) {
      return null;
    }
  }

  // Calculer le montant avec commission
  double calculateAmountWithCommission(double amount, String transactionType) {
    // ENTRANT vers RDC = gratuit (0% commission)
    if (transactionType == 'ENTRANT') {
      return amount;
    }
    
    // SORTANT depuis RDC = commission unique
    final commission = getCommissionByType('SORTANT');
    if (commission != null) {
      return amount * (1 + commission.taux / 100);
    }
    return amount;
  }

  // Valider les données d'un taux
  String? validateTauxData({
    required String devise,
    required String tauxStr,
    required String type,
  }) {
    if (devise.trim().isEmpty) {
      return 'La devise est requise';
    }
    if (tauxStr.trim().isEmpty) {
      return 'Le taux est requis';
    }
    
    final taux = double.tryParse(tauxStr);
    if (taux == null || taux <= 0) {
      return 'Le taux doit être un nombre positif';
    }
    
    if (type.trim().isEmpty) {
      return 'Le type est requis';
    }
    
    return null;
  }

  // Valider les données d'une commission
  String? validateCommissionData({
    required String type,
    required String tauxStr,
    required String description,
  }) {
    if (type.trim().isEmpty) {
      return 'Le type est requis';
    }
    if (description.trim().isEmpty) {
      return 'La description est requise';
    }
    if (tauxStr.trim().isEmpty) {
      return 'Le taux est requis';
    }
    
    final taux = double.tryParse(tauxStr);
    if (taux == null || taux < 0) {
      return 'Le taux doit être un nombre positif ou zéro';
    }
    
    // Pour les transactions entrantes, le taux doit être 0
    if (type == 'ENTRANT' && taux != 0) {
      return 'Les transactions entrantes vers la RDC sont gratuites (0%)';
    }
    
    return null;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  void clearError() {
    _errorMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
}
