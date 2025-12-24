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

  /// Supprimer une retenue (soft delete puis sync)
  Future<void> deleteRetenue(int retenueId) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'retenue_personnel_$retenueId';
      
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        throw Exception('Retenue avec ID $retenueId introuvable');
      }

      final retenue = RetenuePersonnelModel.fromJson(jsonDecode(jsonString));
      
      // Marquer pour suppression avec sync
      await _markRetenueForDeletion(retenueId, 'retenue_personnel');
      
      // Déclencher synchronisation
      await _triggerRetenueSync();
      
      debugPrint('✅ Retenue marquée pour suppression: ${retenue.reference}');
    } catch (e) {
      debugPrint('❌ Erreur suppression retenue: $e');
      rethrow;
    }
  }

  /// Supprimer définitivement une retenue après sync
  Future<void> hardDeleteRetenue(int retenueId) async {
    try {
      final prefs = await LocalDB.instance.database;
      
      // Supprimer l'enregistrement principal
      await prefs.remove('retenue_personnel_$retenueId');
      
      // Supprimer le marqueur de suppression
      await prefs.remove('deletion_retenue_personnel_$retenueId');
      
      _retenues.removeWhere((r) => r.id == retenueId);
      notifyListeners();
      
      debugPrint('✅ Retenue supprimée définitivement: ID $retenueId');
    } catch (e) {
      debugPrint('❌ Erreur suppression définitive retenue: $e');
      rethrow;
    }
  }

  /// Marquer une retenue pour suppression
  Future<void> _markRetenueForDeletion(int id, String type) async {
    try {
      final prefs = await LocalDB.instance.database;
      final deletionRecord = {
        'id': id,
        'type': type,
        'marked_at': DateTime.now().toIso8601String(),
        'synced': false,
      };
      
      await prefs.setString('deletion_${type}_$id', jsonEncode(deletionRecord));
      debugPrint('🗑️ Retenue marquée pour suppression: $type ID $id');
    } catch (e) {
      debugPrint('❌ Erreur marquage suppression retenue: $e');
    }
  }

  /// Déclencher synchronisation des retenues
  Future<void> _triggerRetenueSync() async {
    try {
      final prefs = await LocalDB.instance.database;
      await prefs.setBool('sync_retenue_required', true);
      await prefs.setString('sync_retenue_required_at', DateTime.now().toIso8601String());
      debugPrint('📢 Notification sync retenue enregistrée');
    } catch (e) {
      debugPrint('⚠️ Erreur notification sync retenue: $e');
    }
  }

  /// Marquer une suppression de retenue comme synchronisée
  Future<void> markRetenueDeletionAsSynced(int id) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'deletion_retenue_personnel_$id';
      
      final data = prefs.getString(key);
      if (data != null) {
        final deletion = jsonDecode(data);
        deletion['synced'] = true;
        deletion['synced_at'] = DateTime.now().toIso8601String();
        
        await prefs.setString(key, jsonEncode(deletion));
        debugPrint('✅ Suppression retenue marquée comme synchronisée: ID $id');
        
        // Procéder à la suppression définitive
        await hardDeleteRetenue(id);
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage sync suppression retenue: $e');
    }
  }

  /// Obtenir les retenues d'un agent
  List<RetenuePersonnelModel> getRetenuesParPersonnel(String personnelMatricule) {
    return _retenues.where((r) => r.personnelMatricule == personnelMatricule).toList();
  }
  
  /// Obtenir les retenues d'un agent par matricule
  List<RetenuePersonnelModel> getRetenuesParPersonnelMatricule(String personnelMatricule) {
    return _retenues.where((r) => r.personnelMatricule == personnelMatricule).toList();
  }

  /// Obtenir les retenues d'un agent par ID (DEPRECATED - pour compatibilité)
  @Deprecated('Use getRetenuesParPersonnelMatricule instead')
  List<RetenuePersonnelModel> getRetenuesParPersonnelId(int personnelId) {
    // Cette méthode est obsolète car personnelId n'existe plus
    throw Exception('Méthode obsolète - utilisez getRetenuesParPersonnelMatricule');
  }

  /// Obtenir les retenues actives pour un agent à une période donnée (DEPRECATED)
  @Deprecated('Use getRetenuesActivesParPeriodeMatricule instead')
  List<RetenuePersonnelModel> getRetenuesActivesParPeriode({
    required int personnelId,
    required int mois,
    required int annee,
  }) {
    throw Exception('Méthode obsolète - utilisez getRetenuesActivesParPeriodeMatricule');
  }
  
  /// Obtenir les retenues actives pour un agent à une période donnée par matricule
  List<RetenuePersonnelModel> getRetenuesActivesParPeriodeMatricule({
    required String personnelMatricule,
    required int mois,
    required int annee,
  }) {
    return _retenues.where((r) {
      return r.personnelMatricule == personnelMatricule && 
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
    
    return retenuesActives.fold(0.0, (sum, retenue) {
      return sum + retenue.getMontantPourPeriode(mois, annee);
    });
  }
  
  /// Calculer le total des retenues pour un agent à une période donnée par matricule
  double calculerTotalRetenuesPourPeriodeMatricule({
    required String personnelMatricule,
    required int mois,
    required int annee,
  }) {
    final retenuesActives = getRetenuesActivesParPeriodeMatricule(
      personnelMatricule: personnelMatricule,
      mois: mois,
      annee: annee,
    );

    double total = 0.0;
    for (final retenue in retenuesActives) {
      total += retenue.getMontantPourPeriode(mois, annee);
    }

    return total;
  }

  /// Calculer le total des retenues pour un agent par matricule à une période donnée
  double calculerTotalRetenuesPourPeriodeByMatricule({
    required String personnelMatricule,
    required int mois,
    required int annee,
  }) {
    final retenuesActives = _retenues.where((r) {
      return r.personnelMatricule == personnelMatricule && 
             r.isActivePourPeriode(mois, annee);
    }).toList();

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
