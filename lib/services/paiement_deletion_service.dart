import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_db.dart';
import '../models/salaire_model.dart';
import '../models/avance_personnel_model.dart';
import '../models/retenue_personnel_model.dart';
import 'salaire_service.dart';
import 'avance_service.dart';
import 'retenue_service.dart';

/// Types de paiements supprimables
enum TypePaiement {
  salaire,
  avance,
  retenue,
  paiementPartiel,
}

/// Service pour gérer la suppression sécurisée des paiements
class PaiementDeletionService {
  static final PaiementDeletionService _instance = PaiementDeletionService._internal();
  static PaiementDeletionService get instance => _instance;
  PaiementDeletionService._internal();

  /// Supprimer un salaire avec validation
  Future<bool> supprimerSalaire({
    required int salaireId,
    required String motifSuppression,
    required String utilisateurSuppression,
  }) async {
    try {
      debugPrint('🗑️ Début suppression salaire ID: $salaireId');
      
      // 1. Charger le salaire à supprimer
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      final salaire = SalaireService.instance.salaires.firstWhere(
        (s) => s.id == salaireId,
        orElse: () => throw Exception('Salaire introuvable'),
      );
      
      // 2. Validations de sécurité
      final validationResult = await _validerSuppressionSalaire(salaire);
      if (!validationResult.isValid) {
        throw Exception(validationResult.message);
      }
      
      // 3. Créer un enregistrement de suppression pour audit
      await _creerEnregistrementSuppression(
        type: TypePaiement.salaire,
        referenceId: salaireId,
        donnees: salaire.toJson(),
        motif: motifSuppression,
        utilisateur: utilisateurSuppression,
      );
      
      // 4. Supprimer le salaire
      final prefs = await LocalDB.instance.database;
      await prefs.remove('salaire_$salaireId');
      
      // 5. Recharger les données
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      
      debugPrint('✅ Salaire supprimé avec succès: ${salaire.reference}');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur suppression salaire: $e');
      rethrow;
    }
  }

  /// Supprimer une avance avec validation
  Future<bool> supprimerAvance({
    required int avanceId,
    required String motifSuppression,
    required String utilisateurSuppression,
  }) async {
    try {
      debugPrint('🗑️ Début suppression avance ID: $avanceId');
      
      // 1. Charger l'avance à supprimer
      await AvanceService.instance.loadAvances(forceRefresh: true);
      final avance = AvanceService.instance.avances.firstWhere(
        (a) => a.id == avanceId,
        orElse: () => throw Exception('Avance introuvable'),
      );
      
      // 2. Validations de sécurité
      final validationResult = await _validerSuppressionAvance(avance);
      if (!validationResult.isValid) {
        throw Exception(validationResult.message);
      }
      
      // 3. Créer un enregistrement de suppression pour audit
      await _creerEnregistrementSuppression(
        type: TypePaiement.avance,
        referenceId: avanceId,
        donnees: avance.toJson(),
        motif: motifSuppression,
        utilisateur: utilisateurSuppression,
      );
      
      // 4. Supprimer l'avance
      final prefs = await LocalDB.instance.database;
      await prefs.remove('avance_personnel_$avanceId');
      
      // 5. Recharger les données
      await AvanceService.instance.loadAvances(forceRefresh: true);
      
      debugPrint('✅ Avance supprimée avec succès: ${avance.reference}');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur suppression avance: $e');
      rethrow;
    }
  }

  /// Supprimer une retenue avec validation
  Future<bool> supprimerRetenue({
    required int retenueId,
    required String motifSuppression,
    required String utilisateurSuppression,
  }) async {
    try {
      debugPrint('🗑️ Début suppression retenue ID: $retenueId');
      
      // 1. Charger la retenue à supprimer
      await RetenueService.instance.loadRetenues(forceRefresh: true);
      final retenue = RetenueService.instance.retenues.firstWhere(
        (r) => r.id == retenueId,
        orElse: () => throw Exception('Retenue introuvable'),
      );
      
      // 2. Validations de sécurité
      final validationResult = await _validerSuppressionRetenue(retenue);
      if (!validationResult.isValid) {
        throw Exception(validationResult.message);
      }
      
      // 3. Créer un enregistrement de suppression pour audit
      await _creerEnregistrementSuppression(
        type: TypePaiement.retenue,
        referenceId: retenueId,
        donnees: retenue.toJson(),
        motif: motifSuppression,
        utilisateur: utilisateurSuppression,
      );
      
      // 4. Supprimer la retenue
      await RetenueService.instance.deleteRetenue(retenueId);
      
      debugPrint('✅ Retenue supprimée avec succès: ${retenue.reference}');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur suppression retenue: $e');
      rethrow;
    }
  }

  /// Supprimer un paiement partiel d'un salaire
  Future<bool> supprimerPaiementPartiel({
    required int salaireId,
    required int indexPaiement,
    required String motifSuppression,
    required String utilisateurSuppression,
  }) async {
    try {
      debugPrint('🗑️ Début suppression paiement partiel: salaire $salaireId, index $indexPaiement');
      
      // 1. Charger le salaire
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      final salaire = SalaireService.instance.salaires.firstWhere(
        (s) => s.id == salaireId,
        orElse: () => throw Exception('Salaire introuvable'),
      );
      
      // 2. Vérifier que l'index est valide
      if (indexPaiement < 0 || indexPaiement >= salaire.historiquePaiements.length) {
        throw Exception('Index de paiement invalide');
      }
      
      final paiementASupprimer = salaire.historiquePaiements[indexPaiement];
      
      // 3. Validations de sécurité
      if (salaire.historiquePaiements.length <= 1) {
        throw Exception('Impossible de supprimer le dernier paiement. Supprimez plutôt le salaire entier.');
      }
      
      // 4. Créer un enregistrement de suppression pour audit
      await _creerEnregistrementSuppression(
        type: TypePaiement.paiementPartiel,
        referenceId: salaireId,
        donnees: {
          'salaire_reference': salaire.reference,
          'paiement_supprime': paiementASupprimer.toJson(),
          'index': indexPaiement,
        },
        motif: motifSuppression,
        utilisateur: utilisateurSuppression,
      );
      
      // 5. Supprimer le paiement de l'historique
      final nouvelHistorique = List.from(salaire.historiquePaiements);
      nouvelHistorique.removeAt(indexPaiement);
      
      // 6. Recalculer le montant payé
      final nouveauMontantPaye = nouvelHistorique.fold<double>(
        0.0, 
        (sum, paiement) => sum + paiement.montant,
      );
      
      // 7. Mettre à jour le statut du salaire
      String nouveauStatut;
      if (nouveauMontantPaye <= 0) {
        nouveauStatut = 'Non_Paye';
      } else if (nouveauMontantPaye >= salaire.salaireNet) {
        nouveauStatut = 'Paye';
      } else {
        nouveauStatut = 'Paye_Partiellement';
      }
      
      // 8. Créer le salaire mis à jour
      final salaireModifie = salaire.copyWith(
        montantPaye: nouveauMontantPaye,
        statut: nouveauStatut,
        historiquePaiementsJson: jsonEncode(
          nouvelHistorique.map((p) => p.toJson()).toList()
        ),
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );
      
      // 9. Sauvegarder
      await SalaireService.instance.updateSalaire(salaireModifie);
      
      debugPrint('✅ Paiement partiel supprimé avec succès');
      return true;
      
    } catch (e) {
      debugPrint('❌ Erreur suppression paiement partiel: $e');
      rethrow;
    }
  }

  /// Valider la suppression d'un salaire
  Future<ValidationResult> _validerSuppressionSalaire(SalaireModel salaire) async {
    // Vérifier si le salaire a des paiements
    if (salaire.montantPaye > 0) {
      return ValidationResult(
        isValid: false,
        message: 'Impossible de supprimer un salaire avec des paiements. Supprimez d\'abord les paiements individuels.',
      );
    }
    
    // Vérifier si c'est un salaire récent (moins de 7 jours)
    final maintenant = DateTime.now();
    final dateSalaire = DateTime(salaire.annee, salaire.mois);
    final difference = maintenant.difference(dateSalaire).inDays;
    
    if (difference > 90) {
      return ValidationResult(
        isValid: false,
        message: 'Impossible de supprimer un salaire de plus de 90 jours.',
      );
    }
    
    return ValidationResult(isValid: true, message: 'Validation OK');
  }

  /// Valider la suppression d'une avance
  Future<ValidationResult> _validerSuppressionAvance(AvancePersonnelModel avance) async {
    // Vérifier si l'avance a été partiellement remboursée
    if (avance.montantRembourse > 0) {
      return ValidationResult(
        isValid: false,
        message: 'Impossible de supprimer une avance partiellement remboursée (${avance.montantRembourse.toStringAsFixed(2)} USD déjà remboursé).',
      );
    }
    
    // Vérifier si c'est une avance récente (moins de 30 jours)
    final maintenant = DateTime.now();
    final difference = maintenant.difference(avance.dateAvance).inDays;
    
    if (difference > 30) {
      return ValidationResult(
        isValid: false,
        message: 'Impossible de supprimer une avance de plus de 30 jours.',
      );
    }
    
    return ValidationResult(isValid: true, message: 'Validation OK');
  }

  /// Valider la suppression d'une retenue
  Future<ValidationResult> _validerSuppressionRetenue(RetenuePersonnelModel retenue) async {
    // Vérifier si la retenue a été partiellement déduite
    if (retenue.montantDejaDeduit > 0) {
      return ValidationResult(
        isValid: false,
        message: 'Impossible de supprimer une retenue partiellement déduite (${retenue.montantDejaDeduit.toStringAsFixed(2)} USD déjà déduit).',
      );
    }
    
    // Vérifier si c'est une retenue récente (moins de 30 jours)
    final maintenant = DateTime.now();
    final dateRetenue = DateTime(retenue.anneeDebut, retenue.moisDebut);
    final difference = maintenant.difference(dateRetenue).inDays;
    
    if (difference > 30) {
      return ValidationResult(
        isValid: false,
        message: 'Impossible de supprimer une retenue de plus de 30 jours.',
      );
    }
    
    return ValidationResult(isValid: true, message: 'Validation OK');
  }

  /// Créer un enregistrement de suppression pour audit
  Future<void> _creerEnregistrementSuppression({
    required TypePaiement type,
    required int referenceId,
    required Map<String, dynamic> donnees,
    required String motif,
    required String utilisateur,
  }) async {
    try {
      final prefs = await LocalDB.instance.database;
      final suppressionId = DateTime.now().millisecondsSinceEpoch;
      
      final enregistrement = {
        'id': suppressionId,
        'type': type.toString(),
        'reference_id': referenceId,
        'donnees_supprimees': donnees,
        'motif': motif,
        'utilisateur': utilisateur,
        'date_suppression': DateTime.now().toIso8601String(),
        'synced': false,
      };
      
      await prefs.setString(
        'suppression_paiement_$suppressionId',
        jsonEncode(enregistrement),
      );
      
      debugPrint('📝 Enregistrement de suppression créé: $suppressionId');
    } catch (e) {
      debugPrint('⚠️ Erreur création enregistrement suppression: $e');
      // Ne pas faire échouer la suppression pour l'audit
    }
  }

  /// Récupérer l'historique des suppressions
  Future<List<Map<String, dynamic>>> getHistoriqueSuppressions() async {
    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys()
          .where((key) => key.startsWith('suppression_paiement_'))
          .toList();
      
      final suppressions = <Map<String, dynamic>>[];
      
      for (final key in keys) {
        final data = prefs.getString(key);
        if (data != null) {
          try {
            suppressions.add(jsonDecode(data));
          } catch (e) {
            debugPrint('⚠️ Erreur lecture suppression $key: $e');
          }
        }
      }
      
      // Trier par date de suppression (plus récent en premier)
      suppressions.sort((a, b) {
        final dateA = DateTime.parse(a['date_suppression']);
        final dateB = DateTime.parse(b['date_suppression']);
        return dateB.compareTo(dateA);
      });
      
      return suppressions;
    } catch (e) {
      debugPrint('❌ Erreur récupération historique suppressions: $e');
      return [];
    }
  }

  /// Vérifier si un paiement peut être supprimé
  Future<ValidationResult> peutSupprimerPaiement({
    required TypePaiement type,
    required int id,
  }) async {
    try {
      switch (type) {
        case TypePaiement.salaire:
          await SalaireService.instance.loadSalaires(forceRefresh: true);
          final salaire = SalaireService.instance.salaires.firstWhere(
            (s) => s.id == id,
            orElse: () => throw Exception('Salaire introuvable'),
          );
          return await _validerSuppressionSalaire(salaire);
          
        case TypePaiement.avance:
          await AvanceService.instance.loadAvances(forceRefresh: true);
          final avance = AvanceService.instance.avances.firstWhere(
            (a) => a.id == id,
            orElse: () => throw Exception('Avance introuvable'),
          );
          return await _validerSuppressionAvance(avance);
          
        case TypePaiement.retenue:
          await RetenueService.instance.loadRetenues(forceRefresh: true);
          final retenue = RetenueService.instance.retenues.firstWhere(
            (r) => r.id == id,
            orElse: () => throw Exception('Retenue introuvable'),
          );
          return await _validerSuppressionRetenue(retenue);
          
        case TypePaiement.paiementPartiel:
          return ValidationResult(
            isValid: true,
            message: 'Les paiements partiels peuvent généralement être supprimés',
          );
      }
    } catch (e) {
      return ValidationResult(
        isValid: false,
        message: 'Erreur lors de la validation: $e',
      );
    }
  }
}

/// Résultat de validation pour les suppressions
class ValidationResult {
  final bool isValid;
  final String message;
  
  ValidationResult({
    required this.isValid,
    required this.message,
  });
}
