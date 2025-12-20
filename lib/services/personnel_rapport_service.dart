import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'local_db.dart';
import '../models/personnel_model.dart';
import '../models/salaire_model.dart';

/// Service pour générer les rapports de paiements du personnel
class PersonnelRapportService {
  static final PersonnelRapportService _instance = PersonnelRapportService._internal();
  static PersonnelRapportService get instance => _instance;
  PersonnelRapportService._internal();

  /// Générer un rapport détaillé des paiements pour une période donnée
  Future<RapportPaiementsPersonnel> genererRapportPaiements({
    required DateTime dateDebut,
    required DateTime dateFin,
    List<int>? personnelIds, // Filtrer par agents spécifiques
    bool grouperParAgent = true,
  }) async {
    try {
      debugPrint('📊 Génération rapport paiements du ${dateDebut.toIso8601String()} au ${dateFin.toIso8601String()}');
      
      // 1. Charger tous les personnels
      final personnels = await _chargerPersonnels(personnelIds);
      
      // 2. Charger tous les paiements de la période
      final paiements = await _chargerPaiementsPeriode(dateDebut, dateFin, personnelIds);
      
      // 3. Générer les statistiques
      final stats = await _calculerStatistiques(personnels, paiements, grouperParAgent);
      
      return RapportPaiementsPersonnel(
        dateDebut: dateDebut,
        dateFin: dateFin,
        personnels: personnels,
        paiements: paiements,
        statistiques: stats,
        dateGeneration: DateTime.now(),
      );
      
    } catch (e) {
      debugPrint('❌ Erreur génération rapport paiements: $e');
      rethrow;
    }
  }

  /// Charger les personnels concernés
  Future<List<PersonnelModel>> _chargerPersonnels(List<int>? personnelIds) async {
    final prefs = await LocalDB.instance.database;
    final keys = prefs.getKeys();
    final personnels = <PersonnelModel>[];
    
    for (String key in keys) {
      if (key.startsWith('personnel_')) {
        try {
          final data = prefs.getString(key);
          if (data != null) {
            final personnel = PersonnelModel.fromJson(jsonDecode(data));
            
            // Filtrer par IDs si spécifié
            if (personnelIds == null || personnelIds.contains(personnel.id)) {
              // Exclure les démissionnés sauf si explicitement demandés
              if (personnel.statut != 'Demissionne') {
                personnels.add(personnel);
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lecture personnel $key: $e');
        }
      }
    }
    
    // Trier par nom
    personnels.sort((a, b) => '${a.nom} ${a.prenom}'.compareTo('${b.nom} ${b.prenom}'));
    
    return personnels;
  }

  /// Charger les paiements de la période
  Future<List<PaiementDetailPersonnel>> _chargerPaiementsPeriode(
    DateTime dateDebut, 
    DateTime dateFin, 
    List<int>? personnelIds
  ) async {
    final prefs = await LocalDB.instance.database;
    final keys = prefs.getKeys();
    final paiements = <PaiementDetailPersonnel>[];
    
    // Charger tous les salaires de la période
    for (String key in keys) {
      if (key.startsWith('salaire_')) {
        try {
          final data = prefs.getString(key);
          if (data != null) {
            final salaire = SalaireModel.fromJson(jsonDecode(data));
            
            // Filtrer par personnel si spécifié
            if (personnelIds != null && !personnelIds.contains(salaire.personnelId)) {
              continue;
            }
            
            // Vérifier si le salaire est dans la période
            final dateSalaire = DateTime(salaire.annee, salaire.mois);
            if (dateSalaire.isAfter(dateFin) || dateSalaire.isBefore(dateDebut)) {
              continue;
            }
            
            // Traiter l'historique des paiements
            for (var paiement in salaire.historiquePaiements) {
              final datePaiement = paiement.datePaiement;
              
              // Vérifier si le paiement est dans la période
              if (datePaiement.isAfter(dateDebut.subtract(const Duration(days: 1))) &&
                  datePaiement.isBefore(dateFin.add(const Duration(days: 1)))) {
                
                paiements.add(PaiementDetailPersonnel(
                  personnelId: salaire.personnelId,
                  salaireId: salaire.id!,
                  mois: salaire.mois,
                  annee: salaire.annee,
                  datePaiement: datePaiement,
                  montantPaye: paiement.montant,
                  montantBrut: salaire.salaireBase,
                  montantNet: salaire.salaireNet,
                  deductionsAvances: 0.0, // TODO: Ajouter ces champs au SalaireModel si nécessaire
                  deductionsRetenues: 0.0,
                  deductionsImpots: 0.0,
                  deductionsCnss: 0.0,
                  type: paiement.modePaiement ?? 'salaire',
                  reference: salaire.reference,
                  notes: paiement.notes ?? '',
                ));
              }
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lecture salaire $key: $e');
        }
      }
    }
    
    // Trier par date de paiement
    paiements.sort((a, b) => a.datePaiement.compareTo(b.datePaiement));
    
    return paiements;
  }

  /// Calculer les statistiques du rapport
  Future<StatistiquesPaiementsPersonnel> _calculerStatistiques(
    List<PersonnelModel> personnels,
    List<PaiementDetailPersonnel> paiements,
    bool grouperParAgent,
  ) async {
    final stats = StatistiquesPaiementsPersonnel();
    
    // Statistiques globales
    stats.nombrePersonnels = personnels.length;
    stats.nombrePaiements = paiements.length;
    stats.totalMontantPaye = paiements.fold(0.0, (sum, p) => sum + p.montantPaye);
    stats.totalMontantBrut = paiements.fold(0.0, (sum, p) => sum + p.montantBrut);
    stats.totalMontantNet = paiements.fold(0.0, (sum, p) => sum + p.montantNet);
    stats.totalDeductionsAvances = paiements.fold(0.0, (sum, p) => sum + p.deductionsAvances);
    stats.totalDeductionsRetenues = paiements.fold(0.0, (sum, p) => sum + p.deductionsRetenues);
    stats.totalDeductionsImpots = paiements.fold(0.0, (sum, p) => sum + p.deductionsImpots);
    stats.totalDeductionsCnss = paiements.fold(0.0, (sum, p) => sum + p.deductionsCnss);
    
    // Groupement par agent si demandé
    if (grouperParAgent) {
      final Map<int, StatistiquesParAgent> statsParAgent = {};
      
      for (var personnel in personnels) {
        final paiementsAgent = paiements.where((p) => p.personnelId == personnel.id).toList();
        
        if (paiementsAgent.isNotEmpty) {
          statsParAgent[personnel.id!] = StatistiquesParAgent(
            personnel: personnel,
            nombrePaiements: paiementsAgent.length,
            totalMontantPaye: paiementsAgent.fold(0.0, (sum, p) => sum + p.montantPaye),
            totalMontantBrut: paiementsAgent.fold(0.0, (sum, p) => sum + p.montantBrut),
            totalMontantNet: paiementsAgent.fold(0.0, (sum, p) => sum + p.montantNet),
            totalDeductionsAvances: paiementsAgent.fold(0.0, (sum, p) => sum + p.deductionsAvances),
            totalDeductionsRetenues: paiementsAgent.fold(0.0, (sum, p) => sum + p.deductionsRetenues),
            totalDeductionsImpots: paiementsAgent.fold(0.0, (sum, p) => sum + p.deductionsImpots),
            totalDeductionsCnss: paiementsAgent.fold(0.0, (sum, p) => sum + p.deductionsCnss),
            paiements: paiementsAgent,
          );
        }
      }
      
      stats.statistiquesParAgent = statsParAgent;
    }
    
    return stats;
  }

  /// Générer un rapport pour des périodes prédéfinies
  Future<RapportPaiementsPersonnel> genererRapportPeriodePredefinie({
    required TypePeriodeRapport typePeriode,
    DateTime? dateReference,
    List<int>? personnelIds,
    bool grouperParAgent = true,
  }) async {
    final dateRef = dateReference ?? DateTime.now();
    late DateTime dateDebut;
    late DateTime dateFin;
    
    switch (typePeriode) {
      case TypePeriodeRapport.moisCourant:
        dateDebut = DateTime(dateRef.year, dateRef.month, 1);
        dateFin = DateTime(dateRef.year, dateRef.month + 1, 0);
        break;
        
      case TypePeriodeRapport.derniersMois3:
        dateFin = DateTime(dateRef.year, dateRef.month + 1, 0);
        dateDebut = DateTime(dateRef.year, dateRef.month - 2, 1);
        break;
        
      case TypePeriodeRapport.derniersMois6:
        dateFin = DateTime(dateRef.year, dateRef.month + 1, 0);
        dateDebut = DateTime(dateRef.year, dateRef.month - 5, 1);
        break;
        
      case TypePeriodeRapport.derniersMois12:
        dateFin = DateTime(dateRef.year, dateRef.month + 1, 0);
        dateDebut = DateTime(dateRef.year - 1, dateRef.month + 1, 1);
        break;
    }
    
    return genererRapportPaiements(
      dateDebut: dateDebut,
      dateFin: dateFin,
      personnelIds: personnelIds,
      grouperParAgent: grouperParAgent,
    );
  }
}

/// Types de périodes prédéfinies pour les rapports
enum TypePeriodeRapport {
  moisCourant,
  derniersMois3,
  derniersMois6,
  derniersMois12,
}

/// Modèle pour un rapport de paiements du personnel
class RapportPaiementsPersonnel {
  final DateTime dateDebut;
  final DateTime dateFin;
  final List<PersonnelModel> personnels;
  final List<PaiementDetailPersonnel> paiements;
  final StatistiquesPaiementsPersonnel statistiques;
  final DateTime dateGeneration;

  RapportPaiementsPersonnel({
    required this.dateDebut,
    required this.dateFin,
    required this.personnels,
    required this.paiements,
    required this.statistiques,
    required this.dateGeneration,
  });
}

/// Détail d'un paiement pour le rapport
class PaiementDetailPersonnel {
  final int personnelId;
  final int salaireId;
  final int mois;
  final int annee;
  final DateTime datePaiement;
  final double montantPaye;
  final double montantBrut;
  final double montantNet;
  final double deductionsAvances;
  final double deductionsRetenues;
  final double deductionsImpots;
  final double deductionsCnss;
  final String type;
  final String reference;
  final String notes;

  PaiementDetailPersonnel({
    required this.personnelId,
    required this.salaireId,
    required this.mois,
    required this.annee,
    required this.datePaiement,
    required this.montantPaye,
    required this.montantBrut,
    required this.montantNet,
    required this.deductionsAvances,
    required this.deductionsRetenues,
    required this.deductionsImpots,
    required this.deductionsCnss,
    required this.type,
    required this.reference,
    required this.notes,
  });
}

/// Statistiques globales des paiements
class StatistiquesPaiementsPersonnel {
  int nombrePersonnels = 0;
  int nombrePaiements = 0;
  double totalMontantPaye = 0.0;
  double totalMontantBrut = 0.0;
  double totalMontantNet = 0.0;
  double totalDeductionsAvances = 0.0;
  double totalDeductionsRetenues = 0.0;
  double totalDeductionsImpots = 0.0;
  double totalDeductionsCnss = 0.0;
  Map<int, StatistiquesParAgent> statistiquesParAgent = {};
}

/// Statistiques par agent
class StatistiquesParAgent {
  final PersonnelModel personnel;
  final int nombrePaiements;
  final double totalMontantPaye;
  final double totalMontantBrut;
  final double totalMontantNet;
  final double totalDeductionsAvances;
  final double totalDeductionsRetenues;
  final double totalDeductionsImpots;
  final double totalDeductionsCnss;
  final List<PaiementDetailPersonnel> paiements;

  StatistiquesParAgent({
    required this.personnel,
    required this.nombrePaiements,
    required this.totalMontantPaye,
    required this.totalMontantBrut,
    required this.totalMontantNet,
    required this.totalDeductionsAvances,
    required this.totalDeductionsRetenues,
    required this.totalDeductionsImpots,
    required this.totalDeductionsCnss,
    required this.paiements,
  });
}
