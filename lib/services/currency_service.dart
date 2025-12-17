import 'package:flutter/foundation.dart';
import 'local_db.dart';

/// Service de gestion des taux de change CDF/USD
class CurrencyService extends ChangeNotifier {
  static final CurrencyService _instance = CurrencyService._internal();
  static CurrencyService get instance => _instance;
  
  CurrencyService._internal();

  double _tauxCdfToUsd = 2500.0; // Taux par défaut: 1 USD = 2500 CDF
  bool _isLoading = false;
  String? _errorMessage;

  double get tauxCdfToUsd => _tauxCdfToUsd;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger le taux de change depuis la base de données
  Future<void> loadTauxChange() async {
    _setLoading(true);
    try {
      final taux = await LocalDB.instance.getTauxChange();
      if (taux != null) {
        _tauxCdfToUsd = taux;
        debugPrint('💱 Taux de change chargé: 1 USD = ${_tauxCdfToUsd.toStringAsFixed(0)} CDF');
      }
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur chargement taux: $e';
      debugPrint('❌ $_errorMessage');
    } finally {
      _setLoading(false);
      notifyListeners();
    }
  }

  /// Mettre à jour le taux de change
  Future<bool> updateTauxChange(double nouveauTaux) async {
    _setLoading(true);
    try {
      await LocalDB.instance.saveTauxChange(nouveauTaux);
      _tauxCdfToUsd = nouveauTaux;
      debugPrint('💱 Taux de change mis à jour: 1 USD = ${_tauxCdfToUsd.toStringAsFixed(0)} CDF');
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Erreur mise à jour taux: $e';
      debugPrint('❌ $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Convertir CDF vers USD
  double convertCdfToUsd(double montantCdf) {
    if (_tauxCdfToUsd <= 0) return 0.0;
    return montantCdf / _tauxCdfToUsd;
  }

  /// Convertir USD vers CDF
  double convertUsdToCdf(double montantUsd) {
    return montantUsd * _tauxCdfToUsd;
  }

  /// Formater un montant selon la devise
  String formatMontant(double montant, String devise) {
    if (devise == 'CDF') {
      return '${montant.toStringAsFixed(0)} FC';
    } else {
      return '\$${montant.toStringAsFixed(2)}';
    }
  }

  /// Obtenir le symbole de la devise
  String getDeviseSymbol(String devise) {
    return devise == 'CDF' ? 'FC' : '\$';
  }

  /// Synchroniser les taux de change avec le serveur
  Future<void> syncWithServer() async {
    try {
      // Ici on pourrait implémenter la synchronisation avec le serveur
      // Pour l'instant, on charge juste depuis la base locale
      await loadTauxChange();
    } catch (e) {
      debugPrint('❌ Erreur sync taux de change: $e');
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
