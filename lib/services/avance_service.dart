import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/avance_personnel_model.dart';
import '../models/salaire_model.dart';
import 'local_db.dart';
import 'salaire_service.dart';
import 'personnel_service.dart';

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
      final reference = AvancePersonnelModel.generateReference();
      
      final newAvance = avance.copyWith(
        reference: reference,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      // Utiliser la référence comme clé
      await prefs.setString('avance_personnel_$reference', jsonEncode(newAvance.toJson()));
      
      // Ajouter l'avance à l'historique des paiements du salaire correspondant
      await _ajouterAvanceAHistoriqueSalaire(newAvance);
      
      await loadAvances(forceRefresh: true);
      
      debugPrint('✅ Avance créée: ${newAvance.montant} pour personnel ${newAvance.personnelMatricule}');
      return newAvance;
    } catch (e) {
      debugPrint('❌ Erreur création avance: $e');
      rethrow;
    }
  }

  /// Obtenir les avances en cours d'un employé
  Future<List<AvancePersonnelModel>> getAvancesEnCours(String personnelMatricule) async {
    await loadAvances();
    return _avances.where((a) => 
      a.personnelMatricule == personnelMatricule && a.statut == 'En_Cours'
    ).toList();
  }

  /// Calculer le montant total des avances en cours pour un employé
  Future<double> calculerTotalAvancesEnCours(String personnelMatricule) async {
    final avances = await getAvancesEnCours(personnelMatricule);
    return avances.fold<double>(0.0, (sum, a) => sum + a.montantRestant);
  }

  /// Calculer la déduction mensuelle pour un employé (méthode legacy)
  Future<double> calculerDeductionMensuelle(int personnelId, int mois, int annee) async {
    // Convertir personnelId en matricule pour utiliser la nouvelle méthode
    final personnel = await PersonnelService.instance.personnel.firstWhere(
      (p) => p.id == personnelId,
      orElse: () => throw Exception('Personnel avec ID $personnelId introuvable')
    );
    return await calculerDeductionMensuelleByMatricule(personnel.matricule, mois, annee);
  }

  /// Calculer la déduction mensuelle pour un employé
  /// Ne déduit que les avances dont le mois/année correspond ou est antérieur
  Future<double> calculerDeductionMensuelleByMatricule(String personnelMatricule, int mois, int annee) async {
    final avancesEnCours = await getAvancesEnCours(personnelMatricule);
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

  /// Enregistrer une déduction mensuelle par matricule
  Future<void> enregistrerDeductionMensuelleByMatricule(String personnelMatricule, int mois, int annee, double montant) async {
    // Répartir le montant sur les avances en cours
    final avances = await getAvancesEnCours(personnelMatricule);
    double montantRestant = montant;

    for (var avance in avances) {
      if (montantRestant <= 0) break;

      final deductionPourCetteAvance = montantRestant > avance.montantRestant 
          ? avance.montantRestant 
          : montantRestant;

      final avanceUpdated = avance.copyWith(
        montantRembourse: avance.montantRembourse + deductionPourCetteAvance,
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      // Sauvegarder avec la référence
      final prefs = await LocalDB.instance.database;
      await prefs.setString('avance_personnel_${avance.reference}', jsonEncode(avanceUpdated.toJson()));

      montantRestant -= deductionPourCetteAvance;
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
          (s) => s.personnelMatricule == avance.personnelMatricule && 
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
    required String personnelMatricule,
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
          (s) => s.personnelMatricule == personnelMatricule && 
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

  /// Supprimer une avance (soft delete puis sync)
  Future<void> deleteAvance(String avanceReference) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'avance_personnel_$avanceReference';
      
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        throw Exception('Avance avec référence $avanceReference introuvable');
      }

      final avance = AvancePersonnelModel.fromJson(jsonDecode(jsonString));
      
      // Marquer pour suppression avec sync
      await _markAvanceForDeletion(avanceReference, 'avance_personnel');
      
      // Déclencher synchronisation
      await _triggerAvanceSync();
      
      debugPrint('✅ Avance marquée pour suppression: ${avance.montant} USD');
    } catch (e) {
      debugPrint('❌ Erreur suppression avance: $e');
      rethrow;
    }
  }

  /// Supprimer définitivement une avance après sync
  Future<void> hardDeleteAvance(String avanceReference) async {
    try {
      final prefs = await LocalDB.instance.database;
      
      // Supprimer l'enregistrement principal
      await prefs.remove('avance_personnel_$avanceReference');
      
      // Supprimer le marqueur de suppression
      await prefs.remove('deletion_avance_personnel_$avanceReference');
      
      await loadAvances(forceRefresh: true);
      debugPrint('✅ Avance supprimée définitivement: Référence $avanceReference');
    } catch (e) {
      debugPrint('❌ Erreur suppression définitive avance: $e');
      rethrow;
    }
  }

  /// Marquer une avance pour suppression
  Future<void> _markAvanceForDeletion(String reference, String type) async {
    try {
      final prefs = await LocalDB.instance.database;
      final deletionRecord = {
        'reference': reference,
        'type': type,
        'marked_at': DateTime.now().toIso8601String(),
        'synced': false,
      };
      
      await prefs.setString('deletion_${type}_$reference', jsonEncode(deletionRecord));
      debugPrint('🗑️ Avance marquée pour suppression: $type Référence $reference');
    } catch (e) {
      debugPrint('❌ Erreur marquage suppression avance: $e');
    }
  }

  /// Déclencher synchronisation des avances
  Future<void> _triggerAvanceSync() async {
    try {
      final prefs = await LocalDB.instance.database;
      await prefs.setBool('sync_avance_required', true);
      await prefs.setString('sync_avance_required_at', DateTime.now().toIso8601String());
      debugPrint('📢 Notification sync avance enregistrée');
    } catch (e) {
      debugPrint('⚠️ Erreur notification sync avance: $e');
    }
  }

  /// Marquer une suppression d'avance comme synchronisée
  Future<void> markAvanceDeletionAsSynced(String reference) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'deletion_avance_personnel_$reference';
      
      final data = prefs.getString(key);
      if (data != null) {
        final deletion = jsonDecode(data);
        deletion['synced'] = true;
        deletion['synced_at'] = DateTime.now().toIso8601String();
        
        await prefs.setString(key, jsonEncode(deletion));
        debugPrint('✅ Suppression avance marquée comme synchronisée: Référence $reference');
        
        // Procéder à la suppression définitive
        await hardDeleteAvance(reference);
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage sync suppression avance: $e');
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _avances.clear();
    notifyListeners();
  }
}
