import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/retenue_personnel_model.dart';
import 'local_db.dart';

class RetenueService extends ChangeNotifier {
  static final RetenueService instance = RetenueService._();
  RetenueService._();

  List<RetenuePersonnelModel> _retenues = [];
  bool _isLoading = false;

  List<RetenuePersonnelModel> get retenues => _retenues;
  bool get isLoading => _isLoading;

  /// Charger toutes les retenues depuis LocalDB
  Future<void> loadRetenues({bool forceRefresh = false}) async {
    if (_isLoading) return;
    
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((key) => key.startsWith('retenue_')).toList();

      _retenues = [];
      for (final key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          final retenue = RetenuePersonnelModel.fromJson(jsonDecode(jsonString));
          _retenues.add(retenue);
        }
      }

      // Trier par date de création décroissante
      _retenues.sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      debugPrint('✅ ${_retenues.length} retenues chargées');
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des retenues: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Créer une nouvelle retenue
  Future<RetenuePersonnelModel> createRetenue(RetenuePersonnelModel retenue) async {
    try {
      // Générer un ID local négatif si pas d'ID
      final newRetenue = retenue.id == null
          ? retenue.copyWith(
              id: -DateTime.now().millisecondsSinceEpoch,
              lastModifiedAt: DateTime.now(),
            )
          : retenue;

      // Sauvegarder dans LocalDB
      final prefs = await LocalDB.instance.database;
      await prefs.setString(
        'retenue_${newRetenue.id}',
        jsonEncode(newRetenue.toJson()),
      );

      // Ajouter à la liste
      _retenues.insert(0, newRetenue);
      notifyListeners();

      debugPrint('✅ Retenue créée: ${newRetenue.reference}');
      return newRetenue;
    } catch (e) {
      debugPrint('❌ Erreur lors de la création de la retenue: $e');
      rethrow;
    }
  }

  /// Mettre à jour une retenue existante
  Future<RetenuePersonnelModel> updateRetenue(RetenuePersonnelModel retenue) async {
    if (retenue.id == null) {
      throw Exception('La retenue doit avoir un ID pour être mise à jour');
    }

    try {
      final updatedRetenue = retenue.copyWith(
        lastModifiedAt: DateTime.now(),
      );

      // Sauvegarder dans LocalDB
      final prefs = await LocalDB.instance.database;
      await prefs.setString(
        'retenue_${updatedRetenue.id}',
        jsonEncode(updatedRetenue.toJson()),
      );

      // Mettre à jour dans la liste
      final index = _retenues.indexWhere((r) => r.id == updatedRetenue.id);
      if (index != -1) {
        _retenues[index] = updatedRetenue;
        notifyListeners();
      }

      debugPrint('✅ Retenue mise à jour: ${updatedRetenue.reference}');
      return updatedRetenue;
    } catch (e) {
      debugPrint('❌ Erreur lors de la mise à jour de la retenue: $e');
      rethrow;
    }
  }

  /// Supprimer une retenue
  Future<void> deleteRetenue(int retenueId) async {
    try {
      final prefs = await LocalDB.instance.database;
      await prefs.remove('retenue_$retenueId');

      _retenues.removeWhere((r) => r.id == retenueId);
      notifyListeners();

      debugPrint('✅ Retenue supprimée: ID $retenueId');
    } catch (e) {
      debugPrint('❌ Erreur lors de la suppression de la retenue: $e');
      rethrow;
    }
  }

  /// Obtenir les retenues d'un agent
  List<RetenuePersonnelModel> getRetenuesParPersonnel(int personnelId) {
    return _retenues.where((r) => r.personnelId == personnelId).toList();
  }

  /// Obtenir les retenues actives pour un agent à une période donnée
  List<RetenuePersonnelModel> getRetenuesActivesParPeriode({
    required int personnelId,
    required int mois,
    required int annee,
  }) {
    return _retenues.where((r) {
      return r.personnelId == personnelId && 
             r.isActivePourPeriode(mois, annee);
    }).toList();
  }

  /// Calculer le total des retenues pour un agent à une période donnée
  double calculerTotalRetenuesPourPeriode({
    required int personnelId,
    required int mois,
    required int annee,
  }) {
    final retenuesActives = getRetenuesActivesParPeriode(
      personnelId: personnelId,
      mois: mois,
      annee: annee,
    );

    double total = 0.0;
    for (final retenue in retenuesActives) {
      total += retenue.getMontantPourPeriode(mois, annee);
    }

    return total;
  }

  /// Enregistrer une déduction de retenue
  Future<void> enregistrerDeduction({
    required int retenueId,
    required double montantDeduit,
  }) async {
    final retenue = _retenues.firstWhere((r) => r.id == retenueId);
    
    final nouveauMontantDeduit = retenue.montantDejaDeduit + montantDeduit;
    final nouveauMontantRestant = retenue.montantTotal - nouveauMontantDeduit;
    
    // Mettre à jour le statut si terminé
    String nouveauStatut = retenue.statut;
    if (nouveauMontantRestant <= 0) {
      nouveauStatut = 'Termine';
    }

    final retenueUpdated = retenue.copyWith(
      montantDejaDeduit: nouveauMontantDeduit,
      montantRestant: nouveauMontantRestant,
      statut: nouveauStatut,
    );

    await updateRetenue(retenueUpdated);
  }

  /// Annuler une retenue
  Future<void> annulerRetenue(int retenueId) async {
    final retenue = _retenues.firstWhere((r) => r.id == retenueId);
    final retenueAnnulee = retenue.copyWith(statut: 'Annule');
    await updateRetenue(retenueAnnulee);
  }
}
