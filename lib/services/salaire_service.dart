import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/salaire_model.dart';
import '../models/personnel_model.dart';
import '../models/avance_personnel_model.dart';
import '../models/credit_personnel_model.dart';
import 'local_db.dart';
import 'personnel_service.dart';
import 'avance_service.dart';
import 'credit_service.dart';
import 'retenue_service.dart';

class SalaireService extends ChangeNotifier {
  static final SalaireService _instance = SalaireService._internal();
  static SalaireService get instance => _instance;
  
  SalaireService._internal();

  List<SalaireModel> _salaires = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<SalaireModel> get salaires => _salaires;
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

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Charger tous les salaires
  Future<void> loadSalaires({bool forceRefresh = false}) async {
    if (!forceRefresh && _salaires.isNotEmpty) {
      debugPrint('✅ [SalaireService] Cache utilisé (${_salaires.length} salaires)');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((key) => key.startsWith('salaire_')).toList();
      
      _salaires.clear();
      
      for (var key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            final data = jsonDecode(jsonString);
            _salaires.add(SalaireModel.fromJson(data));
          } catch (e) {
            debugPrint('⚠️ Erreur parsing salaire $key: $e');
          }
        }
      }
      
      // Dédupliquer les salaires (garder le plus récent pour chaque période)
      final Map<String, SalaireModel> uniqueSalaires = {};
      for (final salaire in _salaires) {
        final key = '${salaire.personnelId}_${salaire.mois}_${salaire.annee}';
        if (!uniqueSalaires.containsKey(key) ||
            (salaire.lastModifiedAt?.isAfter(uniqueSalaires[key]!.lastModifiedAt ?? DateTime(2000)) ?? false)) {
          uniqueSalaires[key] = salaire;
        }
      }
      
      _salaires = uniqueSalaires.values.toList();

      // Trier par année/mois décroissant
      _salaires.sort((a, b) {
        final cmpAnnee = b.annee.compareTo(a.annee);
        if (cmpAnnee != 0) return cmpAnnee;
        return b.mois.compareTo(a.mois);
      });
      
      debugPrint('✅ [SalaireService] ${_salaires.length} salaires chargés');
      notifyListeners();
    } catch (e) {
      _setError('Erreur chargement salaires: $e');
      debugPrint('❌ [SalaireService] Erreur: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Générer le salaire mensuel d'un employé
  Future<SalaireModel> genererSalaireMensuel({
    required int personnelId,
    required int mois,
    required int annee,
    double heuresSupplementaires = 0.0,
    double bonus = 0.0,
    double impots = 0.0,
    double cotisationCnss = 0.0,
    double autresDeductions = 0.0,
    String? notes,
  }) async {
    try {
      // Vérifier que le salaire n'existe pas déjà OU qu'il est partiellement payé
      await loadSalaires();
      final existant = _salaires.where((s) =>
          s.personnelId == personnelId && s.mois == mois && s.annee == annee);
      
      // Bloquer seulement si le salaire est TOTALEMENT payé
      if (existant.isNotEmpty && existant.first.statut == 'Paye') {
        throw Exception('Salaire pour $mois/$annee déjà totalement payé pour cet employé');
      }
      
      // Si salaire existe et est partiellement payé, retourner le salaire existant
      if (existant.isNotEmpty && existant.first.statut == 'Paye_Partiellement') {
        return existant.first;
      }

      // Charger l'employé
      final personnel = await PersonnelService.instance.getPersonnelById(personnelId);
      if (personnel == null) {
        throw Exception('Personnel avec ID $personnelId introuvable');
      }

      if (personnel.statut != 'Actif') {
        throw Exception('Personnel ${personnel.nomComplet} n\'est pas actif');
      }

      // Calculer les déductions d'avances et crédits
      final avancesDeduites = await AvanceService.instance
          .calculerDeductionMensuelle(personnelId, mois, annee);
      final creditsDeduits = await CreditService.instance
          .calculerDeductionMensuelle(personnelId, mois, annee);
      
      // Calculer les retenues (pertes, dettes, sanctions)
      final retenuesTotal = RetenueService.instance.calculerTotalRetenuesPourPeriode(
        personnelId: personnelId,
        mois: mois,
        annee: annee,
      );
      
      debugPrint('💰 Retenues calculées pour ${personnel.nomComplet} ($mois/$annee): $retenuesTotal');

      // Créer le salaire
      final salaire = SalaireModel(
        reference: SalaireModel.generateReference(),
        personnelId: personnelId,
        personnelNom: personnel.nomComplet,
        mois: mois,
        annee: annee,
        periode: SalaireModel.generatePeriode(mois, annee),
        salaireBase: personnel.salaireBase,
        primeTransport: personnel.primeTransport,
        primeLogement: personnel.primeLogement,
        primeFonction: personnel.primeFonction,
        autresPrimes: personnel.autresPrimes,
        heuresSupplementaires: heuresSupplementaires,
        bonus: bonus,
        avancesDeduites: avancesDeduites,
        creditsDeduits: creditsDeduits,
        impots: impots,
        cotisationCnss: cotisationCnss,
        autresDeductions: autresDeductions,
        retenueDisciplinaire: retenuesTotal, // Retenues du système (pertes, dettes, sanctions)
        devise: personnel.deviseSalaire,
        statut: 'En_Attente',
        notes: notes,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      // Sauvegarder
      final prefs = await LocalDB.instance.database;
      final id = DateTime.now().millisecondsSinceEpoch;
      final salaireAvecId = salaire.copyWith(id: id);
      
      await prefs.setString('salaire_$id', jsonEncode(salaireAvecId.toJson()));

      // Enregistrer les déductions dans les avances et crédits
      if (avancesDeduites > 0) {
        await AvanceService.instance.enregistrerDeductionMensuelle(
          personnelId, mois, annee, avancesDeduites);
      }
      if (creditsDeduits > 0) {
        await CreditService.instance.enregistrerDeductionMensuelle(
          personnelId, mois, annee, creditsDeduits);
      }

      // Recharger
      await loadSalaires(forceRefresh: true);
      
      debugPrint('✅ Salaire généré: ${personnel.nomComplet} - $mois/$annee');
      debugPrint('   Brut: ${salaireAvecId.salaireBrut} ${salaireAvecId.devise}');
      debugPrint('   Avances: ${salaireAvecId.avancesDeduites} ${salaireAvecId.devise}');
      debugPrint('   Retenues: ${salaireAvecId.retenueDisciplinaire} ${salaireAvecId.devise}');
      debugPrint('   Total Déductions: ${salaireAvecId.totalDeductions} ${salaireAvecId.devise}');
      debugPrint('   Net: ${salaireAvecId.salaireNet} ${salaireAvecId.devise}');
      
      return salaireAvecId;
    } catch (e) {
      debugPrint('❌ Erreur génération salaire: $e');
      rethrow;
    }
  }

  /// Générer les salaires pour tout le personnel actif
  Future<List<SalaireModel>> genererSalairesTousEmployes({
    required int mois,
    required int annee,
  }) async {
    final List<SalaireModel> salairesGeneres = [];
    
    try {
      await PersonnelService.instance.loadPersonnel();
      final personnelActif = PersonnelService.instance.personnelActif;

      debugPrint('🔄 Génération salaires pour ${personnelActif.length} employés...');

      for (final personnel in personnelActif) {
        try {
          final salaire = await genererSalaireMensuel(
            personnelId: personnel.id!,
            mois: mois,
            annee: annee,
          );
          salairesGeneres.add(salaire);
        } catch (e) {
          debugPrint('⚠️ Erreur pour ${personnel.nomComplet}: $e');
        }
      }

      debugPrint('✅ ${salairesGeneres.length} salaires générés');
      return salairesGeneres;
    } catch (e) {
      debugPrint('❌ Erreur génération salaires: $e');
      rethrow;
    }
  }

  /// Mettre à jour un salaire existant (pour paiements complémentaires)
  Future<SalaireModel> updateSalaire(SalaireModel salaire) async {
    try {
      if (salaire.id == null) {
        throw Exception('Le salaire doit avoir un ID pour être mis à jour');
      }

      // Sauvegarder dans LocalDB
      final prefs = await LocalDB.instance.database;
      await prefs.setString('salaire_${salaire.id}', jsonEncode(salaire.toJson()));

      // Mettre à jour la liste en mémoire
      final index = _salaires.indexWhere((s) => s.id == salaire.id);
      if (index != -1) {
        _salaires[index] = salaire;
        notifyListeners();
      }

      debugPrint('✅ Salaire mis à jour: ${salaire.reference}');
      debugPrint('   Montant payé: ${salaire.montantPaye}/${salaire.salaireNet} ${salaire.devise}');
      debugPrint('   Statut: ${salaire.statut}');
      debugPrint('   Nombre de paiements: ${salaire.historiquePaiements.length}');

      return salaire;
    } catch (e) {
      debugPrint('❌ Erreur mise à jour salaire: $e');
      rethrow;
    }
  }

  /// Nettoyer les doublons de salaires dans LocalDB
  Future<void> cleanDuplicateSalaires() async {
    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((key) => key.startsWith('salaire_')).toList();
      
      // Charger tous les salaires
      final List<SalaireModel> allSalaires = [];
      for (var key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            final data = jsonDecode(jsonString);
            allSalaires.add(SalaireModel.fromJson(data));
          } catch (e) {
            debugPrint('⚠️ Erreur parsing salaire $key: $e');
          }
        }
      }
      
      // Grouper par période et garder le plus récent
      final Map<String, SalaireModel> uniqueSalaires = {};
      final Set<int> idsToKeep = {};
      
      for (final salaire in allSalaires) {
        final key = '${salaire.personnelId}_${salaire.mois}_${salaire.annee}';
        if (!uniqueSalaires.containsKey(key) ||
            (salaire.lastModifiedAt?.isAfter(uniqueSalaires[key]!.lastModifiedAt ?? DateTime(2000)) ?? false)) {
          uniqueSalaires[key] = salaire;
        }
      }
      
      // Collecter les IDs à garder
      for (final salaire in uniqueSalaires.values) {
        if (salaire.id != null) {
          idsToKeep.add(salaire.id!);
        }
      }
      
      // Supprimer les doublons
      int deletedCount = 0;
      for (final salaire in allSalaires) {
        if (salaire.id != null && !idsToKeep.contains(salaire.id!)) {
          await prefs.remove('salaire_${salaire.id}');
          deletedCount++;
        }
      }
      
      if (deletedCount > 0) {
        debugPrint('🧹 $deletedCount doublons de salaires supprimés');
        await loadSalaires(forceRefresh: true);
      } else {
        debugPrint('✅ Aucun doublon trouvé');
      }
    } catch (e) {
      debugPrint('❌ Erreur nettoyage doublons: $e');
      rethrow;
    }
  }

  /// Générer les salaires pour tout le personnel actif (DEPRECATED - kept for compatibility)
  @Deprecated('Use genererSalairesTousEmployes instead')
  Future<List<SalaireModel>> _genererSalairesTousEmployesOld({
    required int mois,
    required int annee,
  }) async {
    final List<SalaireModel> salairesGeneres = [];
    
    try {
      await PersonnelService.instance.loadPersonnel();
      final personnelActif = PersonnelService.instance.personnelActif;

      debugPrint('🔄 Génération salaires pour ${personnelActif.length} employés...');

      for (var personnel in personnelActif) {
        try {
          final salaire = await genererSalaireMensuel(
            personnelId: personnel.id!,
            mois: mois,
            annee: annee,
          );
          salairesGeneres.add(salaire);
        } catch (e) {
          debugPrint('⚠️ Erreur pour ${personnel.nomComplet}: $e');
          // Continuer pour les autres employés
        }
      }

      debugPrint('✅ ${salairesGeneres.length} salaires générés avec succès');
      return salairesGeneres;
    } catch (e) {
      debugPrint('❌ Erreur génération salaires: $e');
      rethrow;
    }
  }

  /// Payer un salaire
  Future<void> payerSalaire({
    required int salaireId,
    required double montant,
    required String modePaiement,
    String? agentPaiement,
  }) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'salaire_$salaireId';
      
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        throw Exception('Salaire avec ID $salaireId introuvable');
      }

      final salaire = SalaireModel.fromJson(jsonDecode(jsonString));
      
      if (salaire.statut == 'Paye') {
        throw Exception('Salaire déjà payé intégralement');
      }

      final nouveauMontantPaye = salaire.montantPaye + montant;
      
      if (nouveauMontantPaye > salaire.salaireNet) {
        throw Exception('Montant dépasse le salaire net');
      }

      String nouveauStatut;
      if (nouveauMontantPaye >= salaire.salaireNet) {
        nouveauStatut = 'Paye';
      } else if (nouveauMontantPaye > 0) {
        nouveauStatut = 'Partiel';
      } else {
        nouveauStatut = 'En_Attente';
      }

      final salaireUpdate = salaire.copyWith(
        montantPaye: nouveauMontantPaye,
        datePaiement: nouveauStatut == 'Paye' ? DateTime.now() : salaire.datePaiement,
        modePaiement: modePaiement,
        statut: nouveauStatut,
        agentPaiement: agentPaiement,
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      await prefs.setString(key, jsonEncode(salaireUpdate.toJson()));
      
      await loadSalaires(forceRefresh: true);
      
      debugPrint('✅ Paiement enregistré: $montant - Statut: $nouveauStatut');
    } catch (e) {
      debugPrint('❌ Erreur paiement salaire: $e');
      rethrow;
    }
  }

  // ============================================================================
  // RECHERCHE & FILTRES
  // ============================================================================

  /// Obtenir un salaire par ID
  Future<SalaireModel?> getSalaireById(int id) async {
    await loadSalaires();
    try {
      return _salaires.firstWhere((s) => s.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir les salaires d'un employé
  Future<List<SalaireModel>> getSalairesByPersonnel(int personnelId) async {
    await loadSalaires();
    return _salaires.where((s) => s.personnelId == personnelId).toList();
  }

  /// Obtenir les salaires d'une période
  Future<List<SalaireModel>> getSalairesByPeriode(int mois, int annee) async {
    await loadSalaires();
    return _salaires.where((s) => s.mois == mois && s.annee == annee).toList();
  }

  /// Obtenir les salaires par statut
  List<SalaireModel> filterByStatut(String statut) {
    return _salaires.where((s) => s.statut == statut).toList();
  }

  // ============================================================================
  // RAPPORTS & STATISTIQUES
  // ============================================================================

  /// Rapport mensuel
  Future<Map<String, dynamic>> getRapportMensuel(int mois, int annee) async {
    final salaires = await getSalairesByPeriode(mois, annee);
    
    if (salaires.isEmpty) {
      return {
        'periode': '${mois.toString().padLeft(2, '0')}/$annee',
        'nombre_employes': 0,
        'salaire_brut_total': 0.0,
        'total_deductions': 0.0,
        'salaire_net_total': 0.0,
        'montant_paye': 0.0,
        'montant_impaye': 0.0,
        'nombre_payes': 0,
        'nombre_en_attente': 0,
        'nombre_partiels': 0,
      };
    }

    final salaireBrutTotal = salaires.fold(0.0, (sum, s) => sum + s.salaireBrut);
    final totalDeductions = salaires.fold(0.0, (sum, s) => sum + s.totalDeductions);
    final salaireNetTotal = salaires.fold(0.0, (sum, s) => sum + s.salaireNet);
    final montantPaye = salaires.fold(0.0, (sum, s) => sum + s.montantPaye);
    final montantImpaye = salaireNetTotal - montantPaye;

    return {
      'periode': '${mois.toString().padLeft(2, '0')}/$annee',
      'nombre_employes': salaires.length,
      'salaire_brut_total': salaireBrutTotal,
      'total_deductions': totalDeductions,
      'salaire_net_total': salaireNetTotal,
      'montant_paye': montantPaye,
      'montant_impaye': montantImpaye,
      'nombre_payes': salaires.where((s) => s.statut == 'Paye').length,
      'nombre_en_attente': salaires.where((s) => s.statut == 'En_Attente').length,
      'nombre_partiels': salaires.where((s) => s.statut == 'Partiel').length,
      'salaires': salaires,
    };
  }

  /// Rapport annuel
  Future<List<Map<String, dynamic>>> getRapportAnnuel(int annee) async {
    await loadSalaires();
    final List<Map<String, dynamic>> rapports = [];

    for (int mois = 1; mois <= 12; mois++) {
      final rapport = await getRapportMensuel(mois, annee);
      rapports.add(rapport);
    }

    return rapports;
  }

  /// Nettoyer le cache
  void clearCache() {
    _salaires.clear();
    notifyListeners();
  }
}
