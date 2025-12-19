import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/avance_personnel_model.dart';
import 'local_db.dart';

class AvanceService extends ChangeNotifier {
  static final AvanceService _instance = AvanceService._internal();
  static AvanceService get instance => _instance;
  
  AvanceService._internal();

  List<AvancePersonnelModel> _avances = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AvancePersonnelModel> get avances => _avances;
  List<AvancePersonnelModel> get avancesEnCours =>
      _avances.where((a) => a.statut == 'En_Cours').toList();
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

  /// Charger toutes les avances
  Future<void> loadAvances({bool forceRefresh = false}) async {
    if (!forceRefresh && _avances.isNotEmpty) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((key) => key.startsWith('avance_')).toList();
      
      _avances.clear();
      
      for (var key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            _avances.add(AvancePersonnelModel.fromJson(jsonDecode(jsonString)));
          } catch (e) {
            debugPrint('⚠️ Erreur parsing avance $key: $e');
          }
        }
      }

      _avances.sort((a, b) => b.dateAvance.compareTo(a.dateAvance));
      notifyListeners();
    } catch (e) {
      _setError('Erreur chargement avances: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Créer une avance
  Future<AvancePersonnelModel> createAvance(AvancePersonnelModel avance) async {
    try {
      final prefs = await LocalDB.instance.database;
      final id = DateTime.now().millisecondsSinceEpoch;
      
      final newAvance = avance.copyWith(
        id: id,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      await prefs.setString('avance_$id', jsonEncode(newAvance.toJson()));
      await loadAvances(forceRefresh: true);
      
      debugPrint('✅ Avance créée: ${newAvance.montant} pour personnel ${newAvance.personnelId}');
      return newAvance;
    } catch (e) {
      debugPrint('❌ Erreur création avance: $e');
      rethrow;
    }
  }

  /// Obtenir les avances en cours d'un employé
  Future<List<AvancePersonnelModel>> getAvancesEnCours(int personnelId) async {
    await loadAvances();
    return _avances.where((a) => 
      a.personnelId == personnelId && a.statut == 'En_Cours'
    ).toList();
  }

  /// Calculer le total des avances restantes
  Future<double> getTotalAvancesRestantes(int personnelId) async {
    final avancesEnCours = await getAvancesEnCours(personnelId);
    return avancesEnCours.fold<double>(0.0, (sum, a) => sum + a.montantRestant);
  }

  /// Calculer la déduction mensuelle pour un employé
  /// Ne déduit que les avances dont le mois/année correspond ou est antérieur
  Future<double> calculerDeductionMensuelle(
    int personnelId, 
    int mois, 
    int annee
  ) async {
    final avancesEnCours = await getAvancesEnCours(personnelId);
    double totalDeduction = 0.0;

    for (var avance in avancesEnCours) {
      // Vérifier si on doit déduire cette avance pour ce mois
      // On déduit si le mois de paiement est >= au mois de l'avance
      final avancePeriode = DateTime(avance.anneeAvance, avance.moisAvance);
      final paiementPeriode = DateTime(annee, mois);
      
      // Ne pas déduire si le paiement est avant l'avance
      if (paiementPeriode.isBefore(avancePeriode)) {
        continue;
      }

      switch (avance.modeRemboursement) {
        case 'Mensuel':
          // Déduire la mensualité si on est dans la période de remboursement
          final moisEcoules = _calculerMoisEcoules(avance.anneeAvance, avance.moisAvance, annee, mois);
          if (moisEcoules < avance.nombreMoisRemboursement) {
            totalDeduction += avance.montantMensuel;
          }
          break;
        case 'Unique':
          // Déduire tout d'un coup le mois de l'avance
          if (avance.anneeAvance == annee && avance.moisAvance == mois) {
            totalDeduction += avance.montantRestant;
          }
          break;
        case 'Progressif':
          // Pour l'instant, traiter comme mensuel
          final moisEcoules = _calculerMoisEcoules(avance.anneeAvance, avance.moisAvance, annee, mois);
          if (moisEcoules < avance.nombreMoisRemboursement) {
            totalDeduction += avance.montantMensuel;
          }
          break;
      }
    }

    return totalDeduction;
  }

  /// Calculer le nombre de mois écoulés entre deux périodes
  int _calculerMoisEcoules(int anneeDebut, int moisDebut, int anneeFin, int moisFin) {
    return (anneeFin - anneeDebut) * 12 + (moisFin - moisDebut);
  }

  /// Enregistrer une déduction mensuelle
  Future<void> enregistrerDeductionMensuelle(
    int personnelId,
    int mois,
    int annee,
    double montantDeduit,
  ) async {
    final avancesEnCours = await getAvancesEnCours(personnelId);
    final prefs = await LocalDB.instance.database;
    
    double reste = montantDeduit;

    for (var avance in avancesEnCours) {
      if (reste <= 0) break;

      final deduction = reste > avance.montantRestant 
          ? avance.montantRestant 
          : reste;

      final nouveauMontantRembourse = avance.montantRembourse + deduction;
      final nouveauMontantRestant = avance.montant - nouveauMontantRembourse;
      final nouveauStatut = nouveauMontantRestant <= 0 ? 'Rembourse' : 'En_Cours';

      final avanceUpdate = avance.copyWith(
        montantRembourse: nouveauMontantRembourse,
        montantRestant: nouveauMontantRestant,
        statut: nouveauStatut,
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      await prefs.setString('avance_${avance.id}', jsonEncode(avanceUpdate.toJson()));
      reste -= deduction;
    }

    await loadAvances(forceRefresh: true);
  }

  /// Nettoyer le cache
  void clearCache() {
    _avances.clear();
    notifyListeners();
  }
}
