import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/credit_personnel_model.dart';
import 'local_db.dart';

class CreditService extends ChangeNotifier {
  static final CreditService _instance = CreditService._internal();
  static CreditService get instance => _instance;
  
  CreditService._internal();

  List<CreditPersonnelModel> _credits = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<CreditPersonnelModel> get credits => _credits;
  List<CreditPersonnelModel> get creditsEnCours =>
      _credits.where((c) => c.statut == 'En_Cours').toList();
  List<CreditPersonnelModel> get creditsEnRetard =>
      _credits.where((c) => c.statut == 'En_Retard').toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Charger tous les crédits
  Future<void> loadCredits({bool forceRefresh = false}) async {
    if (!forceRefresh && _credits.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((key) => key.startsWith('credit_')).toList();
      
      _credits.clear();
      
      for (var key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            _credits.add(CreditPersonnelModel.fromJson(jsonDecode(jsonString)));
          } catch (e) {
            debugPrint('⚠️ Erreur parsing crédit $key: $e');
          }
        }
      }

      // Mettre à jour les statuts des crédits
      await _updateCreditsStatuts();

      _credits.sort((a, b) => b.dateOctroi.compareTo(a.dateOctroi));
      notifyListeners();
    } catch (e) {
      _setError('Erreur chargement crédits: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Mettre à jour les statuts des crédits (détecter les retards)
  Future<void> _updateCreditsStatuts() async {
    final prefs = await LocalDB.instance.database;
    final now = DateTime.now();

    for (var credit in _credits) {
      if (credit.montantRestant <= 0) {
        if (credit.statut != 'Rembourse') {
          final updated = credit.copyWith(statut: 'Rembourse');
          await prefs.setString('credit_${credit.id}', jsonEncode(updated.toJson()));
        }
      } else if (credit.dateEcheance.isBefore(now) && credit.statut == 'En_Cours') {
        final updated = credit.copyWith(statut: 'En_Retard');
        await prefs.setString('credit_${credit.id}', jsonEncode(updated.toJson()));
      }
    }
  }

  /// Créer un crédit
  Future<CreditPersonnelModel> createCredit(CreditPersonnelModel credit) async {
    try {
      final prefs = await LocalDB.instance.database;
      final id = DateTime.now().millisecondsSinceEpoch;
      
      final newCredit = credit.copyWith(
        id: id,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      await prefs.setString('credit_$id', jsonEncode(newCredit.toJson()));
      await loadCredits(forceRefresh: true);
      
      debugPrint('✅ Crédit créé: ${newCredit.montantCredit} pour personnel ${newCredit.personnelId}');
      debugPrint('   Mensualité: ${newCredit.mensualite.toStringAsFixed(2)}');
      return newCredit;
    } catch (e) {
      debugPrint('❌ Erreur création crédit: $e');
      rethrow;
    }
  }

  /// Obtenir les crédits en cours d'un employé
  Future<List<CreditPersonnelModel>> getCreditsEnCours(int personnelId) async {
    await loadCredits();
    return _credits.where((c) => 
      c.personnelId == personnelId && (c.statut == 'En_Cours' || c.statut == 'En_Retard')
    ).toList();
  }

  /// Calculer le total des crédits restants
  Future<double> getTotalCreditsRestants(int personnelId) async {
    final creditsEnCours = await getCreditsEnCours(personnelId);
    return creditsEnCours.fold<double>(0.0, (sum, c) => sum + c.montantRestant);
  }

  /// Calculer la déduction mensuelle pour un employé
  Future<double> calculerDeductionMensuelle(
    int personnelId,
    int mois,
    int annee,
  ) async {
    final creditsEnCours = await getCreditsEnCours(personnelId);
    double totalDeduction = 0.0;

    for (var credit in creditsEnCours) {
      // Vérifier si le crédit doit être déduit ce mois
      final dateDebut = credit.dateOctroi;
      final dateFin = credit.dateEcheance;
      final dateCourante = DateTime(annee, mois, 1);

      if (dateCourante.isAfter(dateDebut) && dateCourante.isBefore(dateFin)) {
        totalDeduction += credit.mensualite;
      }
    }

    return totalDeduction;
  }

  /// Enregistrer une déduction mensuelle
  Future<void> enregistrerDeductionMensuelle(
    int personnelId,
    int mois,
    int annee,
    double montantDeduit,
  ) async {
    final creditsEnCours = await getCreditsEnCours(personnelId);
    final prefs = await LocalDB.instance.database;
    
    double reste = montantDeduit;

    for (var credit in creditsEnCours) {
      if (reste <= 0) break;

      final deduction = reste > credit.mensualite 
          ? credit.mensualite 
          : reste;

      // Calculer la répartition principal/intérêt (simplifié)
      final ratioInteret = credit.tauxInteret > 0 
          ? credit.montantRestant * (credit.tauxInteret / 12 / 100) 
          : 0.0;
      final montantInteret = ratioInteret > deduction ? deduction : ratioInteret;
      final montantPrincipal = deduction - montantInteret;

      final nouveauMontantRembourse = credit.montantRembourse + montantPrincipal;
      final nouveauxInteretsPayes = credit.interetsPayes + montantInteret;
      final nouveauMontantRestant = credit.montantCredit - nouveauMontantRembourse;
      
      String nouveauStatut = credit.statut;
      if (nouveauMontantRestant <= 0) {
        nouveauStatut = 'Rembourse';
      }

      final creditUpdate = credit.copyWith(
        montantRembourse: nouveauMontantRembourse,
        interetsPayes: nouveauxInteretsPayes,
        montantRestant: nouveauMontantRestant,
        statut: nouveauStatut,
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      await prefs.setString('credit_${credit.id}', jsonEncode(creditUpdate.toJson()));
      reste -= deduction;
    }

    await loadCredits(forceRefresh: true);
  }

  /// Nettoyer le cache
  void clearCache() {
    _credits.clear();
    notifyListeners();
  }
}
