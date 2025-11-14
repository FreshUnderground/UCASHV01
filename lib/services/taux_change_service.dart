import 'package:flutter/foundation.dart';
import '../models/taux_model.dart';
import 'local_db.dart';

/// Service de gestion des taux de change entre devises
class TauxChangeService extends ChangeNotifier {
  static final TauxChangeService _instance = TauxChangeService._internal();
  factory TauxChangeService() => _instance;
  TauxChangeService._internal();

  final Map<String, TauxModel> _taux = {};
  bool _isLoading = false;
  String? _errorMessage;

  Map<String, TauxModel> get taux => _taux;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Initialiser avec les taux par defaut
  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _loadTauxDefaut();
      _errorMessage = null;
      debugPrint('✅ TauxChangeService initialise avec ${_taux.length} taux');
    } catch (e) {
      _errorMessage = 'Erreur initialisation taux: $e';
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Charger les taux par defaut (peuvent etre mis a jour depuis le serveur)
  Future<void> _loadTauxDefaut() async {
    // Taux USD vers CDF (Franc Congolais)
    _taux['USD_CDF'] = TauxModel(
      id: 1,
      deviseSource: 'USD',
      deviseCible: 'CDF',
      taux: 2500.0, // 1 USD = 2500 CDF
      type: 'MOYEN',
      dateEffet: DateTime.now(),
      estActif: true,
    );

    // Taux USD vers UGX (Shilling Ougandais)
    _taux['USD_UGX'] = TauxModel(
      id: 2,
      deviseSource: 'USD',
      deviseCible: 'UGX',
      taux: 3700.0, // 1 USD = 3700 UGX
      type: 'MOYEN',
      dateEffet: DateTime.now(),
      estActif: true,
    );

    // Taux CDF vers USD (inverse)
    _taux['CDF_USD'] = _taux['USD_CDF']!.inverse;

    // Taux UGX vers USD (inverse)
    _taux['UGX_USD'] = _taux['USD_UGX']!.inverse;

    // Taux CDF vers UGX (cross-rate)
    final usdToCdf = _taux['USD_CDF']!.taux;
    final usdToUgx = _taux['USD_UGX']!.taux;
    _taux['CDF_UGX'] = TauxModel(
      id: 3,
      deviseSource: 'CDF',
      deviseCible: 'UGX',
      taux: usdToUgx / usdToCdf, // Cross rate
      type: 'MOYEN',
      dateEffet: DateTime.now(),
      estActif: true,
    );

    // Taux UGX vers CDF (inverse)
    _taux['UGX_CDF'] = _taux['CDF_UGX']!.inverse;
  }

  /// Obtenir le taux entre deux devises
  TauxModel? getTaux(String deviseSource, String deviseCible) {
    if (deviseSource == deviseCible) {
      return TauxModel(
        deviseSource: deviseSource,
        deviseCible: deviseCible,
        taux: 1.0,
        type: 'IDENTIQUE',
      );
    }

    final cle = '${deviseSource}_$deviseCible';
    return _taux[cle];
  }

  /// Convertir un montant d'une devise vers une autre
  double convertir({
    required double montant,
    required String deviseSource,
    required String deviseCible,
  }) {
    if (deviseSource == deviseCible) return montant;

    final taux = getTaux(deviseSource, deviseCible);
    if (taux == null) {
      debugPrint('⚠️ Aucun taux trouve pour $deviseSource -> $deviseCible');
      return montant; // Retourne le montant inchange si pas de taux
    }

    return taux.convertir(montant);
  }

  /// Mettre a jour un taux de change
  Future<void> updateTaux(TauxModel taux) async {
    try {
      _taux[taux.cle] = taux;
      
      // Mettre a jour aussi le taux inverse
      _taux[taux.inverse.cle] = taux.inverse;
      
      // Sauvegarder dans LocalDB si necessaire
      // await LocalDB.instance.saveTaux(taux);
      
      notifyListeners();
      debugPrint('✅ Taux mis a jour: ${taux.cle} = ${taux.taux}');
    } catch (e) {
      _errorMessage = 'Erreur mise a jour taux: $e';
      debugPrint(_errorMessage);
    }
  }

  /// Obtenir tous les taux actifs pour une devise source
  List<TauxModel> getTauxForDevise(String deviseSource) {
    return _taux.values
        .where((t) => t.deviseSource == deviseSource && t.estActif)
        .toList();
  }

  /// Calculer l'interet ou le gain d'une conversion
  Map<String, dynamic> calculerInteretConversion({
    required double montantSource,
    required String deviseSource,
    required String deviseCible,
  }) {
    final montantConverti = convertir(
      montant: montantSource,
      deviseSource: deviseSource,
      deviseCible: deviseCible,
    );

    final taux = getTaux(deviseSource, deviseCible);
    
    return {
      'montantSource': montantSource,
      'deviseSource': deviseSource,
      'montantConverti': montantConverti,
      'deviseCible': deviseCible,
      'taux': taux?.taux ?? 1.0,
      'tauxType': taux?.type ?? 'N/A',
      'dateEffet': taux?.dateEffet,
      'formule': '${montantSource.toStringAsFixed(2)} $deviseSource x ${taux?.taux.toStringAsFixed(2)} = ${montantConverti.toStringAsFixed(2)} $deviseCible',
    };
  }

  /// Formater un montant avec sa devise
  String formaterMontant(double montant, String devise) {
    switch (devise) {
      case 'USD':
        return '\$${montant.toStringAsFixed(2)}';
      case 'CDF':
        return '${montant.toStringAsFixed(2)} FC';
      case 'UGX':
        return '${montant.toStringAsFixed(2)} USh';
      default:
        return '${montant.toStringAsFixed(2)} $devise';
    }
  }
}
