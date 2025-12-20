import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/avance_personnel_model.dart';
import '../models/salaire_model.dart';
import 'local_db.dart';
import 'salaire_service.dart';

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

      await prefs.setString('avance_personnel_$id', jsonEncode(newAvance.toJson()));
      
      // Ajouter l'avance à l'historique des paiements du salaire correspondant
      await _ajouterAvanceAHistoriqueSalaire(newAvance);
      
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

      await prefs.setString('avance_personnel_${avance.id}', jsonEncode(avanceUpdate.toJson()));
      
      // Ajouter le remboursement à l'historique des paiements
      await _ajouterRemboursementAHistoriqueSalaire(
        personnelId: personnelId,
        mois: mois,
        annee: annee,
        montantRembourse: deduction,
        referenceAvance: avance.reference,
      );
      
      reste -= deduction;
    }

    await loadAvances(forceRefresh: true);
  }

  /// Ajouter une avance à l'historique des paiements du salaire correspondant
  Future<void> _ajouterAvanceAHistoriqueSalaire(AvancePersonnelModel avance) async {
    try {
      // Charger les salaires pour trouver celui de la période correspondante
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      
      // Chercher le salaire de la période de l'avance
      SalaireModel? salaireCorrespondant;
      try {
        salaireCorrespondant = SalaireService.instance.salaires.firstWhere(
          (s) => s.personnelId == avance.personnelId && 
                 s.mois == avance.moisAvance && 
                 s.annee == avance.anneeAvance,
        );
      } catch (e) {
        // Pas de salaire trouvé pour cette période, on peut ignorer
        debugPrint('ℹ️ Aucun salaire trouvé pour la période ${avance.moisAvance}/${avance.anneeAvance}');
        return;
      }
      
      // Ajouter l'avance à l'historique du salaire
      final salaireAvecAvance = salaireCorrespondant.ajouterAvanceAHistorique(
        dateAvance: avance.dateAvance,
        montantAvance: avance.montant,
        referenceAvance: avance.reference,
        agentAvance: avance.accordePar,
        notesAvance: avance.motif,
      );
      
      // Sauvegarder le salaire mis à jour
      await SalaireService.instance.updateSalaire(salaireAvecAvance);
      
      debugPrint('✅ Avance ${avance.reference} ajoutée à l\'historique du salaire ${salaireCorrespondant.reference}');
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'ajout de l\'avance à l\'historique: $e');
      // Ne pas faire échouer la création de l'avance pour autant
    }
  }
  
  /// Ajouter un remboursement d'avance à l'historique des paiements
  Future<void> _ajouterRemboursementAHistoriqueSalaire({
    required int personnelId,
    required int mois,
    required int annee,
    required double montantRembourse,
    required String referenceAvance,
  }) async {
    try {
      // Charger les salaires pour trouver celui de la période correspondante
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      
      // Chercher le salaire de la période du remboursement
      SalaireModel? salaireCorrespondant;
      try {
        salaireCorrespondant = SalaireService.instance.salaires.firstWhere(
          (s) => s.personnelId == personnelId && 
                 s.mois == mois && 
                 s.annee == annee,
        );
      } catch (e) {
        // Pas de salaire trouvé pour cette période, on peut ignorer
        debugPrint('ℹ️ Aucun salaire trouvé pour la période $mois/$annee');
        return;
      }
      
      // Ajouter le remboursement à l'historique du salaire
      final salaireAvecRemboursement = salaireCorrespondant.ajouterRemboursementAvanceAHistorique(
        dateRemboursement: DateTime.now(),
        montantRembourse: montantRembourse,
        referenceAvance: referenceAvance,
        notes: 'Remboursement automatique avance $referenceAvance',
      );
      
      // Sauvegarder le salaire mis à jour
      await SalaireService.instance.updateSalaire(salaireAvecRemboursement);
      
      debugPrint('✅ Remboursement avance $referenceAvance ajouté à l\'historique du salaire ${salaireCorrespondant.reference}');
    } catch (e) {
      debugPrint('⚠️ Erreur lors de l\'ajout du remboursement à l\'historique: $e');
      // Ne pas faire échouer le remboursement pour autant
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _avances.clear();
    notifyListeners();
  }
}
