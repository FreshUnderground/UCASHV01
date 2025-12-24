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
        final key = '${salaire.personnelMatricule}_${salaire.mois}_${salaire.annee}';
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
    required String personnelMatricule,
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
          s.personnelMatricule == personnelMatricule && s.mois == mois && s.annee == annee);
      
      // Bloquer seulement si le salaire est TOTALEMENT payé
      if (existant.isNotEmpty && existant.first.statut == 'Paye') {
        throw Exception('Salaire pour $mois/$annee déjà totalement payé pour cet employé');
      }
      
      // Si salaire existe et est partiellement payé, retourner le salaire existant
      if (existant.isNotEmpty && existant.first.statut == 'Paye_Partiellement') {
        return existant.first;
      }

      // Charger l'employé
      final personnel = await PersonnelService.instance.getPersonnelByMatricule(personnelMatricule);
      if (personnel == null) {
        throw Exception('Personnel avec matricule $personnelMatricule introuvable');
      }

      if (personnel.statut != 'Actif') {
        throw Exception('Personnel ${personnel.nomComplet} n\'est pas actif');
      }

      // Calculer les déductions d'avances et crédits
      final avancesDeduites = await AvanceService.instance
          .calculerDeductionMensuelleByMatricule(personnelMatricule, mois, annee);
      final creditsDeduits = await CreditService.instance
          .calculerDeductionMensuelleByMatricule(personnelMatricule, mois, annee);
      
      // Calculer les retenues (pertes, dettes, sanctions)
      final retenuesTotal = RetenueService.instance.calculerTotalRetenuesPourPeriodeByMatricule(
        personnelMatricule: personnelMatricule,
        mois: mois,
        annee: annee,
      );
      
      debugPrint('💰 Retenues calculées pour ${personnel.nomComplet} ($mois/$annee): $retenuesTotal');

      // Créer le salaire avec un ID généré
      final reference = SalaireModel.generateReference();
      final salaireId = DateTime.now().millisecondsSinceEpoch;
      final salaire = SalaireModel(
        id: salaireId,
        reference: reference,
        personnelMatricule: personnelMatricule,
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

      // Sauvegarder avec l'ID comme clé pour cohérence avec updateSalaire
      final prefs = await LocalDB.instance.database;
      await prefs.setString('salaire_${salaire.id}', jsonEncode(salaire.toJson()));

      // Enregistrer les déductions dans les avances et crédits
      if (avancesDeduites > 0) {
        await AvanceService.instance.enregistrerDeductionMensuelleByMatricule(
          personnelMatricule, mois, annee, avancesDeduites);
      }
      if (creditsDeduits > 0) {
        await CreditService.instance.enregistrerDeductionMensuelleByMatricule(
          personnelMatricule, mois, annee, creditsDeduits);
      }

      // Recharger
      await loadSalaires(forceRefresh: true);
      
      debugPrint('✅ Salaire généré: ${personnel.nomComplet} - $mois/$annee');
      debugPrint('   Référence: ${salaire.reference}');
      debugPrint('   Brut: ${salaire.salaireBrut} ${salaire.devise}');
      debugPrint('   Avances: ${salaire.avancesDeduites} ${salaire.devise}');
      debugPrint('   Retenues: ${salaire.retenueDisciplinaire} ${salaire.devise}');
      debugPrint('   Total Déductions: ${salaire.totalDeductions} ${salaire.devise}');
      debugPrint('   Net: ${salaire.salaireNet} ${salaire.devise}');
      
      return salaire;
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
            personnelMatricule: personnel.matricule,
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

  /// Recalculer un salaire avec de nouveaux bonus/avantages
  Future<SalaireModel?> recalculateSalaireWithBonusAndAdvantages({
    required SalaireModel salaire,
    double? newBonus,
    double? newAvantageNatureLogement,
    double? newAvantageNatureVoiture,
    double? newAutresAvantagesNature,
    double? newHeuresSupplementaires,
    double? newSupplementWeekend,
    double? newSupplementJoursFeries,
    double? newAllocationsFamiliales,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔄 [SalaireService] Recalcul salaire...');
      debugPrint('   ID: ${salaire.id}');
      debugPrint('   Référence: ${salaire.reference}');
      debugPrint('   Ancien bonus: ${salaire.bonus}');
      debugPrint('   Nouveau bonus: ${newBonus ?? salaire.bonus}');
      debugPrint('   Anciens avantages logement: ${salaire.avantageNatureLogement}');
      debugPrint('   Nouveaux avantages logement: ${newAvantageNatureLogement ?? salaire.avantageNatureLogement}');
      
      // Utiliser la méthode statique de recalcul du modèle
      final recalculatedSalaire = SalaireModel.recalculateWithBonusAndAdvantages(
        salaire: salaire,
        newBonus: newBonus,
        newAvantageNatureLogement: newAvantageNatureLogement,
        newAvantageNatureVoiture: newAvantageNatureVoiture,
        newAutresAvantagesNature: newAutresAvantagesNature,
        newHeuresSupplementaires: newHeuresSupplementaires,
        newSupplementWeekend: newSupplementWeekend,
        newSupplementJoursFeries: newSupplementJoursFeries,
        newAllocationsFamiliales: newAllocationsFamiliales,
      ).copyWith(
        lastModifiedBy: modifiedBy,
        isSynced: false, // Marquer comme non synchronisé
      );
      
      // Recalculer tous les montants avec les nouvelles valeurs
      final finalSalaire = recalculatedSalaire.recalculateAmounts();
      
      debugPrint('   Salaire brut recalculé: ${finalSalaire.salaireBrut}');
      debugPrint('   Total déductions: ${finalSalaire.totalDeductions}');
      debugPrint('   Salaire net final: ${finalSalaire.salaireNet}');
      debugPrint('   Total avantages: ${finalSalaire.totalAvantages}');
      
      // Sauvegarder le salaire recalculé
      await updateSalaire(finalSalaire);
      debugPrint('✅ [SalaireService] Salaire recalculé et sauvegardé');
      
      _setLoading(false);
      _setError(null);
      
      return finalSalaire;
    } catch (e) {
      final errorMsg = 'Erreur recalcul salaire: $e';
      debugPrint('❌ [SalaireService] $errorMsg');
      _setLoading(false);
      _setError(errorMsg);
      return null;
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
        final key = '${salaire.personnelMatricule}_${salaire.mois}_${salaire.annee}';
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
            personnelMatricule: personnel.matricule,
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

  /// Obtenir un salaire par référence
  Future<SalaireModel?> getSalaireByReference(String reference) async {
    await loadSalaires();
    try {
      return _salaires.firstWhere((s) => s.reference == reference);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir les salaires d'un employé
  Future<List<SalaireModel>> getSalairesByPersonnel(String personnelMatricule) async {
    await loadSalaires();
    return _salaires.where((s) => s.personnelMatricule == personnelMatricule).toList();
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

  /// Générer et payer plusieurs mois de salaire en une seule opération
  Future<List<SalaireModel>> genererEtPayerSalaireMultiPeriodes({
    required String personnelMatricule,
    required List<Map<String, int>> periodes, // [{"mois": 1, "annee": 2024}, ...]
    required double montantTotalServi,
    double heuresSupplementaires = 0,
    double bonus = 0,
    String? notes,
  }) async {
    try {
      // Charger le personnel
      await PersonnelService.instance.loadPersonnel();
      final personnel = PersonnelService.instance.personnel
          .firstWhere((p) => p.matricule == personnelMatricule);
      
      List<SalaireModel> salairesGeneres = [];
      double montantTotalCalcule = 0;
      
      // 1. Générer tous les salaires pour les périodes demandées
      for (final periode in periodes) {
        final mois = periode['mois']!;
        final annee = periode['annee']!;
        
        // Vérifier si le salaire existe déjà
        await loadSalaires(forceRefresh: true);
        SalaireModel? salaireExistant;
        try {
          salaireExistant = _salaires.firstWhere(
            (s) => s.personnelMatricule == personnelMatricule && s.mois == mois && s.annee == annee,
          );
        } catch (e) {
          salaireExistant = null;
        }
        
        // Si le salaire existe et est totalement payé, ignorer
        if (salaireExistant != null && salaireExistant.statut == 'Paye') {
          debugPrint('⚠️ Salaire $mois/$annee déjà payé, ignoré');
          continue;
        }
        
        // Générer le salaire pour cette période
        final salaire = await genererSalaireMensuel(
          personnelMatricule: personnelMatricule,
          mois: mois,
          annee: annee,
          heuresSupplementaires: heuresSupplementaires,
          bonus: bonus,
          notes: notes,
        );
        
        salairesGeneres.add(salaire);
        montantTotalCalcule += salaire.salaireNet;
      }
      
      if (salairesGeneres.isEmpty) {
        throw Exception('Aucun salaire à générer (tous déjà payés)');
      }
      
      // 2. Répartir le montant servi proportionnellement
      final ratio = montantTotalServi / montantTotalCalcule;
      List<SalaireModel> salairesFinaux = [];
      
      for (final salaire in salairesGeneres) {
        final montantPourCeSalaire = salaire.salaireNet * ratio;
        
        // Créer l'historique de paiement
        final historique = [PaiementSalaireModel(
          datePaiement: DateTime.now(),
          montant: montantPourCeSalaire,
          modePaiement: 'Especes',
          agentPaiement: 'Admin',
          notes: 'Paiement multi-périodes (${periodes.length} mois)',
        )];
        
        final historiqueJson = jsonEncode(
          historique.map((p) => p.toJson()).toList()
        );
        
        // Mettre à jour le salaire avec le paiement
        final salaireAvecPaiement = salaire.copyWith(
          montantPaye: montantPourCeSalaire,
          statut: montantPourCeSalaire >= salaire.salaireNet ? 'Paye' : 'Paye_Partiellement',
          datePaiement: DateTime.now(),
          historiquePaiementsJson: historiqueJson,
          notes: '${salaire.notes ?? ''} | Paiement groupé ${periodes.length} mois'.trim(),
          lastModifiedAt: DateTime.now(),
        );
        
        // Sauvegarder
        await updateSalaire(salaireAvecPaiement);
        salairesFinaux.add(salaireAvecPaiement);
      }
      
      await loadSalaires(forceRefresh: true);
      
      debugPrint('✅ Paiement multi-périodes généré: ${salairesFinaux.length} salaires, total: ${montantTotalServi.toStringAsFixed(2)} USD');
      return salairesFinaux;
      
    } catch (e) {
      debugPrint('❌ Erreur génération multi-périodes: $e');
      rethrow;
    }
  }
  
  /// Calculer le montant total pour plusieurs périodes (DEPRECATED - use calculerMontantTotalMultiPeriodesMatricule)
  @Deprecated('Use calculerMontantTotalMultiPeriodesMatricule instead')
  Future<Map<String, dynamic>> calculerMontantTotalMultiPeriodes({
    required int personnelId,
    required List<Map<String, int>> periodes,
    double heuresSupplementaires = 0,
    double bonus = 0,
  }) async {
    try {
      // Charger le personnel
      await PersonnelService.instance.loadPersonnel();
      final personnel = PersonnelService.instance.personnel
          .firstWhere((p) => p.id == personnelId);
      
      return await calculerMontantTotalMultiPeriodesMatricule(
        personnelMatricule: personnel.matricule,
        periodes: periodes,
        heuresSupplementaires: heuresSupplementaires,
        bonus: bonus,
      );
    } catch (e) {
      debugPrint('❌ Erreur calcul montant total multi-périodes: $e');
      return {
        'montantTotalBrut': 0.0,
        'montantTotalNet': 0.0,
        'totalAvancesDeduites': 0.0,
        'totalRetenuesDeduites': 0.0,
        'details': <Map<String, dynamic>>[],
      };
    }
  }
  
  /// Calculer le montant total pour plusieurs périodes par matricule
  Future<Map<String, dynamic>> calculerMontantTotalMultiPeriodesMatricule({
    required String personnelMatricule,
    required List<Map<String, int>> periodes,
    double heuresSupplementaires = 0,
    double bonus = 0,
  }) async {
    try {
      // Charger le personnel
      await PersonnelService.instance.loadPersonnel();
      final personnel = PersonnelService.instance.personnel
          .firstWhere((p) => p.matricule == personnelMatricule);
      
      double montantTotalBrut = 0;
      double montantTotalNet = 0;
      double totalAvances = 0;
      double totalRetenues = 0;
      List<Map<String, dynamic>> detailsPeriodes = [];
      
      for (final periode in periodes) {
        final mois = periode['mois']!;
        final annee = periode['annee']!;
        
        // Calculer les déductions pour cette période
        final avancesDeduites = await AvanceService.instance.calculerDeductionMensuelleByMatricule(
          personnelMatricule,
          mois,
          annee,
        );
        
        final retenuesDeduites = RetenueService.instance.calculerTotalRetenuesPourPeriodeByMatricule(
          personnelMatricule: personnelMatricule,
          mois: mois,
          annee: annee,
        );
        
        // Calculer brut et net pour cette période
        final salaireBrut = personnel.salaireTotal + heuresSupplementaires + bonus;
        final salaireNet = salaireBrut - avancesDeduites - retenuesDeduites;
        
        montantTotalBrut += salaireBrut;
        montantTotalNet += salaireNet;
        totalAvances += avancesDeduites;
        totalRetenues += retenuesDeduites;
        
        detailsPeriodes.add({
          'mois': mois,
          'annee': annee,
          'periode': '${mois.toString().padLeft(2, '0')}/$annee',
          'salaireBrut': salaireBrut,
          'salaireNet': salaireNet,
          'avancesDeduites': avancesDeduites,
          'retenuesDeduites': retenuesDeduites,
        });
      }
      
      return {
        'montantTotalBrut': montantTotalBrut,
        'montantTotalNet': montantTotalNet,
        'totalAvances': totalAvances,
        'totalRetenues': totalRetenues,
        'nombrePeriodes': periodes.length,
        'detailsPeriodes': detailsPeriodes,
      };
      
    } catch (e) {
      debugPrint('❌ Erreur calcul multi-périodes: $e');
      rethrow;
    }
  }
  
  /// Obtenir les périodes disponibles pour un personnel (non payées) - DEPRECATED
  @Deprecated('Use getPeriodesDisponiblesMatricule instead')
  Future<List<Map<String, dynamic>>> getPeriodesDisponibles(int personnelId) async {
    await loadSalaires(forceRefresh: true);
    
    // Trouver le matricule du personnel
    await PersonnelService.instance.loadPersonnel();
    final personnel = PersonnelService.instance.personnel
        .firstWhere((p) => p.id == personnelId, orElse: () => throw Exception('Personnel non trouvé'));
    
    return await getPeriodesDisponiblesMatricule(personnel.matricule);
  }
  
  /// Obtenir les périodes disponibles pour un personnel par matricule (non payées)
  Future<List<Map<String, dynamic>>> getPeriodesDisponiblesMatricule(String personnelMatricule) async {
    await loadSalaires(forceRefresh: true);
    
    List<Map<String, dynamic>> periodesDisponibles = [];
    final now = DateTime.now();
    
    // Générer les 12 derniers mois
    for (int i = 11; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i, 1);
      final mois = date.month;
      final annee = date.year;
      
      // Vérifier si le salaire existe et son statut
      final salaireExistant = _salaires.where(
        (s) => s.personnelMatricule == personnelMatricule && s.mois == mois && s.annee == annee,
      ).firstOrNull;
      
      String statut;
      if (salaireExistant == null) {
        statut = 'Non généré';
      } else if (salaireExistant.statut == 'Paye') {
        statut = 'Payé';
      } else if (salaireExistant.statut == 'Paye_Partiellement') {
        statut = 'Partiellement payé';
      } else {
        statut = 'En attente';
      }
      
      periodesDisponibles.add({
        'mois': mois,
        'annee': annee,
        'periode': '${mois.toString().padLeft(2, '0')}/$annee',
        'nomMois': _getMonthName(mois),
        'statut': statut,
        'peutEtrePaye': statut != 'Payé',
        'montantPaye': salaireExistant?.montantPaye ?? 0.0,
        'montantRestant': salaireExistant?.montantRestant ?? 0.0,
      });
    }
    
    return periodesDisponibles;
  }
  
  /// Obtenir le nom du mois
  String _getMonthName(int month) {
    const months = [
      '', 'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month];
  }

  /// Supprimer un salaire (soft delete puis sync)
  Future<void> deleteSalaire(String salaireReference) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'salaire_$salaireReference';
      
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        throw Exception('Salaire avec référence $salaireReference introuvable');
      }

      final salaire = SalaireModel.fromJson(jsonDecode(jsonString));
      
      // Marquer pour suppression avec sync
      await _markSalaireForDeletion(salaireReference, 'salaire');
      
      // Déclencher synchronisation
      await _triggerSalaireSync();
      
      debugPrint('✅ Salaire marqué pour suppression: ${salaire.reference}');
    } catch (e) {
      debugPrint('❌ Erreur suppression salaire: $e');
      rethrow;
    }
  }

  /// Supprimer définitivement un salaire après sync
  Future<void> hardDeleteSalaire(String salaireReference) async {
    try {
      final prefs = await LocalDB.instance.database;
      
      // Supprimer l'enregistrement principal
      await prefs.remove('salaire_$salaireReference');
      
      // Supprimer le marqueur de suppression
      await prefs.remove('deletion_salaire_$salaireReference');
      
      await loadSalaires(forceRefresh: true);
      debugPrint('✅ Salaire supprimé définitivement: Référence $salaireReference');
    } catch (e) {
      debugPrint('❌ Erreur suppression définitive salaire: $e');
      rethrow;
    }
  }

  /// Marquer un salaire pour suppression
  Future<void> _markSalaireForDeletion(String reference, String type) async {
    try {
      final prefs = await LocalDB.instance.database;
      final deletionRecord = {
        'reference': reference,
        'type': type,
        'marked_at': DateTime.now().toIso8601String(),
        'synced': false,
      };
      
      await prefs.setString('deletion_${type}_$reference', jsonEncode(deletionRecord));
      debugPrint('🗑️ Salaire marqué pour suppression: $type Référence $reference');
    } catch (e) {
      debugPrint('❌ Erreur marquage suppression salaire: $e');
    }
  }

  /// Déclencher synchronisation des salaires
  Future<void> _triggerSalaireSync() async {
    try {
      final prefs = await LocalDB.instance.database;
      await prefs.setBool('sync_salaire_required', true);
      await prefs.setString('sync_salaire_required_at', DateTime.now().toIso8601String());
      debugPrint('📢 Notification sync salaire enregistrée');
    } catch (e) {
      debugPrint('⚠️ Erreur notification sync salaire: $e');
    }
  }

  /// Marquer une suppression de salaire comme synchronisée
  Future<void> markSalaireDeletionAsSynced(String reference) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'deletion_salaire_$reference';
      
      final data = prefs.getString(key);
      if (data != null) {
        final deletion = jsonDecode(data);
        deletion['synced'] = true;
        deletion['synced_at'] = DateTime.now().toIso8601String();
        
        await prefs.setString(key, jsonEncode(deletion));
        debugPrint('✅ Suppression salaire marquée comme synchronisée: Référence $reference');
        
        // Procéder à la suppression définitive
        await hardDeleteSalaire(reference);
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage sync suppression salaire: $e');
    }
  }

  /// Nettoyer le cache
  void clearCache() {
    _salaires.clear();
    notifyListeners();
  }
}
