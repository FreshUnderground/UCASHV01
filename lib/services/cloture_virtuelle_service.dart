import 'package:flutter/foundation.dart';
import '../models/cloture_virtuelle_model.dart';
import '../models/virtual_transaction_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../models/sim_model.dart';
import 'local_db.dart';

/// Service pour générer les clôtures de transactions virtuelles
class ClotureVirtuelleService {
  static final ClotureVirtuelleService _instance = ClotureVirtuelleService._internal();
  static ClotureVirtuelleService get instance => _instance;
  
  ClotureVirtuelleService._internal();

  /// Générer le rapport de clôture virtuelle pour une date donnée
  Future<Map<String, dynamic>> genererRapportCloture({
    required int shopId,
    DateTime? date,
  }) async {
    try {
      // S'assurer que LocalDB est prêt
      await LocalDB.instance.database;
      
      final dateRapport = date ?? DateTime.now();
      final dateDebut = DateTime(dateRapport.year, dateRapport.month, dateRapport.day);
      final dateFin = DateTime(dateRapport.year, dateRapport.month, dateRapport.day, 23, 59, 59);
      
      debugPrint('Génération rapport clôture virtuelle pour shop $shopId - ${dateRapport.toIso8601String().split('T')[0]}');

      // === 1. TRANSACTIONS VIRTUELLES (optimisé pour mobiles) ===
      final allTransactions = await LocalDB.instance.getAllVirtualTransactions(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      // Statistiques globales (calculs en une seule passe)
      double montantTotalCaptures = 0.0;
      double cashSortiCaptures = 0.0;
      double montantVirtuelServies = 0.0;
      double fraisPercus = 0.0;
      double cashServi = 0.0;
      int nombreServies = 0;
      double montantVirtuelEnAttente = 0.0;
      int nombreEnAttente = 0;
      double montantVirtuelAnnulees = 0.0;
      int nombreAnnulees = 0;
      
      // NOUVEAU: Statistiques PAR SIM (optimisé)
      final Map<String, Map<String, dynamic>> transactionsParSim = {};
      
      // Traiter toutes les transactions en une seule boucle (optimisation mémoire)
      for (var trans in allTransactions) {
        // EXCLUSION: Les transactions administratives ne sont PAS comptabilisées dans les montants cash
        final isNormalTransaction = !trans.isAdministrative;
        
        montantTotalCaptures += trans.montantVirtuel;
        if (isNormalTransaction) {
          cashSortiCaptures += trans.montantVirtuel;
        }
        
        final simKey = trans.simNumero;
        if (!transactionsParSim.containsKey(simKey)) {
          transactionsParSim[simKey] = {
            'simNumero': simKey,
            'nombreCaptures': 0,
            'montantCaptures': 0.0,
            'nombreServies': 0,
            'montantServies': 0.0,
            'fraisServies': 0.0,
            'cashServi': 0.0,
            'nombreEnAttente': 0,
            'montantEnAttente': 0.0,
            'nombreAnnulees': 0,
            'montantAnnulees': 0.0,
          };
        }
        
        transactionsParSim[simKey]!['nombreCaptures'] += 1;
        transactionsParSim[simKey]!['montantCaptures'] += trans.montantVirtuel;
        
        if (trans.statut == VirtualTransactionStatus.validee) {
          nombreServies++;
          montantVirtuelServies += trans.montantVirtuel;
          fraisPercus += trans.frais;
          if (isNormalTransaction) {
            cashServi += trans.montantCash;
          }
          
          transactionsParSim[simKey]!['nombreServies'] += 1;
          transactionsParSim[simKey]!['montantServies'] += trans.montantVirtuel;
          transactionsParSim[simKey]!['fraisServies'] += trans.frais;
          if (isNormalTransaction) {
            transactionsParSim[simKey]!['cashServi'] += trans.montantCash;
          }
        } else if (trans.statut == VirtualTransactionStatus.enAttente) {
          nombreEnAttente++;
          montantVirtuelEnAttente += trans.montantVirtuel;
          
          transactionsParSim[simKey]!['nombreEnAttente'] += 1;
          transactionsParSim[simKey]!['montantEnAttente'] += trans.montantVirtuel;
        } else if (trans.statut == VirtualTransactionStatus.annulee) {
          nombreAnnulees++;
          montantVirtuelAnnulees += trans.montantVirtuel;
          
          transactionsParSim[simKey]!['nombreAnnulees'] += 1;
          transactionsParSim[simKey]!['montantAnnulees'] += trans.montantVirtuel;
        }
      }
      
      final nombreCaptures = allTransactions.length;
      
      // === 2. FLOTS (optimisé) ===
      final allRetraits = await LocalDB.instance.getAllRetraitsVirtuels(
        shopSourceId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      // Séparer les retraits et les transferts (Dépots)
      final retraitsSeuls = allRetraits.where((r) => 
        !((r.notes?.contains('Dépot') ?? false) || (r.notes?.contains('Transfert') ?? false))
      ).toList();
      final transfertsVirtuels = allRetraits.where((r) => 
        (r.notes?.contains('Dépot') ?? false) || (r.notes?.contains('Transfert') ?? false)
      ).toList();
      
      // Calculer en une seule passe (optimisation mémoire)
      double montantTotalRetraits = 0.0;
      double montantRetraitsRembourses = 0.0;
      int nombreRetraitsRembourses = 0;
      double montantRetraitsEnAttente = 0.0;
      int nombreRetraitsEnAttente = 0;
      
      // NOUVEAU: Transferts (Dépots Virtuel → Cash)
      final nombreTransferts = transfertsVirtuels.length;
      final montantTotalTransferts = transfertsVirtuels.fold<double>(0.0, (sum, r) => sum + r.montant);
      
      // NOUVEAU: Dépots PAR SIM (optimisé)
      final Map<String, Map<String, dynamic>> depotsParSim = {};
      
      for (var depot in transfertsVirtuels) {
        final simKey = depot.simNumero;
        if (!depotsParSim.containsKey(simKey)) {
          depotsParSim[simKey] = {
            'simNumero': simKey,
            'nombreDepots': 0,
            'montantDepots': 0.0,
          };
        }
        
        depotsParSim[simKey]!['nombreDepots'] += 1;
        depotsParSim[simKey]!['montantDepots'] += depot.montant;
      }
      
      debugPrint('💵 Dépôts par SIM: ${depotsParSim.length} SIM(s) - Total: \$${montantTotalTransferts.toStringAsFixed(2)}');
      
      // NOUVEAU: Retraits PAR SIM (optimisé)
      final Map<String, Map<String, dynamic>> retraitsParSim = {};
      
      for (var retrait in retraitsSeuls) {
        montantTotalRetraits += retrait.montant;
        
        final simKey = retrait.simNumero;
        if (!retraitsParSim.containsKey(simKey)) {
          retraitsParSim[simKey] = {
            'simNumero': simKey,
            'nombreRetraits': 0,
            'montantRetraits': 0.0,
            'nombreRembourses': 0,
            'montantRembourses': 0.0,
            'nombreEnAttente': 0,
            'montantEnAttente': 0.0,
          };
        }
        
        retraitsParSim[simKey]!['nombreRetraits'] += 1;
        retraitsParSim[simKey]!['montantRetraits'] += retrait.montant;
        
        if (retrait.statut == RetraitVirtuelStatus.rembourse) {
          nombreRetraitsRembourses++;
          montantRetraitsRembourses += retrait.montant;
          
          retraitsParSim[simKey]!['nombreRembourses'] += 1;
          retraitsParSim[simKey]!['montantRembourses'] += retrait.montant;
        } else if (retrait.statut == RetraitVirtuelStatus.enAttente) {
          nombreRetraitsEnAttente++;
          montantRetraitsEnAttente += retrait.montant;
          
          retraitsParSim[simKey]!['nombreEnAttente'] += 1;
          retraitsParSim[simKey]!['montantEnAttente'] += retrait.montant;
        }
      }
      
      final nombreRetraits = allRetraits.length;
      
      // CASH ENTRANT lors des remboursements de retraits virtuels
      // BUSINESS LOGIC: When a virtual withdrawal is refunded, cash enters the system
      // This represents physical cash coming in when a virtual withdrawal is reversed
      final cashEntrantRetraitsRembourses = montantRetraitsRembourses;
      
      // === NOUVEAU: FLOTs PHYSIQUES (entre shops) ===
      final allFlots = await LocalDB.instance.getAllFlots();
      
      // FLOTs REÇUS (shop destination = nous)
      final flotsRecus = allFlots.where((f) =>
        f.shopDestinationId == shopId &&
        f.dateReception != null &&
        f.dateReception!.isAfter(dateDebut) &&
        f.dateReception!.isBefore(dateFin)
      ).toList();
      
      final nombreFlotsRecus = flotsRecus.length;
      final montantFlotsRecus = flotsRecus.fold<double>(0.0, (sum, f) => sum + f.montant);
      
      // FLOTs ENVOYÉS (shop source = nous)
      final flotsEnvoyes = allFlots.where((f) =>
        f.shopSourceId == shopId &&
        f.dateEnvoi.isAfter(dateDebut) &&
        f.dateEnvoi.isBefore(dateFin)
      ).toList();
      
      final nombreFlotsEnvoyes = flotsEnvoyes.length;
      final montantFlotsEnvoyes = flotsEnvoyes.fold<double>(0.0, (sum, f) => sum + f.montant);
      
      debugPrint('📦 FLOTs - Reçus: $nombreFlotsRecus (\$${montantFlotsRecus.toStringAsFixed(2)}) | Envoyés: $nombreFlotsEnvoyes (\$${montantFlotsEnvoyes.toStringAsFixed(2)})');
      
      // === 3. SOLDES DES SIMS ===
      final allSims = await LocalDB.instance.getAllSims();
      final simsActives = allSims.where((s) => 
        s.shopId == shopId && s.statut == SimStatus.active
      ).toList();
      
      // Grouper par opérateur
      final Map<String, double> soldesParOperateur = {};
      final Map<String, int> nombreSimsParOperateur = {};
      
      // NOUVEAU: Détails PAR SIM (avec opérateur)
      final Map<String, Map<String, dynamic>> detailsParSim = {};
      
      for (var sim in simsActives) {
        final operateur = sim.operateur;
        soldesParOperateur[operateur] = (soldesParOperateur[operateur] ?? 0) + sim.soldeActuel;
        nombreSimsParOperateur[operateur] = (nombreSimsParOperateur[operateur] ?? 0) + 1;
        
        detailsParSim[sim.numero] = {
          'simNumero': sim.numero,
          'operateur': sim.operateur,
          'soldeActuel': sim.soldeActuel,
        };
      }
      
      final soldeTotalSims = simsActives.fold<double>(0, (sum, s) => sum + s.soldeActuel);
      final nombreTotalSims = simsActives.length;
      
      // === 4. RÉSUMÉ FINANCIER ===
      final soldeTotalVirtuel = soldeTotalSims;
      final cashDuAuxClients = montantVirtuelEnAttente;
      final fraisTotalJournee = fraisPercus;
      
      // CALCUL DU CASH TOTAL
      // Cash SORTANT:
      // - Captures: on donne cash contre virtuel
      // - FLOTs envoyés: on envoie du cash à d'autres shops
      final cashSortiTotal = cashSortiCaptures + montantFlotsEnvoyes;
      
      // Cash ENTRANT:
      // - Retraits remboursés: on reçoit du cash via FLOT
      // - Dépôts (Virtuel → Cash): conversion interne, augmente le cash
      // - FLOTs reçus: on reçoit du cash d'autres shops
      final cashEntrantTotal = cashEntrantRetraitsRembourses + montantTotalTransferts + montantFlotsRecus;
      
      // MOUVEMENT NET DE CASH = Entrant - Sortant
      final mouvementNetCash = cashEntrantTotal - cashSortiTotal;
      
      return {
        'nombreCaptures': nombreCaptures,
        'montantTotalCaptures': montantTotalCaptures,
        'nombreServies': nombreServies,
        'montantVirtuelServies': montantVirtuelServies,
        'fraisPercus': fraisPercus,
        'cashServi': cashServi,
        'nombreEnAttente': nombreEnAttente,
        'montantVirtuelEnAttente': montantVirtuelEnAttente,
        'nombreAnnulees': nombreAnnulees,
        'montantVirtuelAnnulees': montantVirtuelAnnulees,
        'nombreRetraits': nombreRetraits,
        'montantTotalRetraits': montantTotalRetraits,
        'nombreRetraitsRembourses': nombreRetraitsRembourses,
        'montantRetraitsRembourses': montantRetraitsRembourses,
        'nombreRetraitsEnAttente': nombreRetraitsEnAttente,
        'montantRetraitsEnAttente': montantRetraitsEnAttente,
        // NOUVEAU: Transferts (Dépots)
        'nombreTransferts': nombreTransferts,
        'montantTotalTransferts': montantTotalTransferts,
        // NOUVEAU: FLOTs physiques
        'nombreFlotsRecus': nombreFlotsRecus,
        'montantFlotsRecus': montantFlotsRecus,
        'nombreFlotsEnvoyes': nombreFlotsEnvoyes,
        'montantFlotsEnvoyes': montantFlotsEnvoyes,
        'soldesParOperateur': soldesParOperateur,
        'nombreSimsParOperateur': nombreSimsParOperateur,
        'soldeTotalSims': soldeTotalSims,
        'nombreTotalSims': nombreTotalSims,
        'soldeTotalVirtuel': soldeTotalVirtuel,
        'cashDuAuxClients': cashDuAuxClients,
        'fraisTotalJournee': fraisTotalJournee,
        // CASH
        'cashSortiCaptures': cashSortiCaptures,
        'cashEntrantRetraitsRembourses': cashEntrantRetraitsRembourses,
        'cashEntrantTransferts': montantTotalTransferts, // NOUVEAU: Cash entrant des dépots
        'mouvementNetCash': mouvementNetCash,
        // NOUVEAU: Détails par SIM
        'transactionsParSim': transactionsParSim,
        'retraitsParSim': retraitsParSim,
        'depotsParSim': depotsParSim,
        'detailsParSim': detailsParSim,
      };
    } catch (e) {
      debugPrint('Erreur génération rapport clôture virtuelle: $e');
      rethrow;
    }
  }

  /// Clôturer la journée
  Future<void> cloturerJournee({
    required int shopId,
    required String shopDesignation,
    DateTime? dateCloture,
    required String cloturePar,
    String? notes,
  }) async {
    try {
      // S'assurer que LocalDB est prêt
      await LocalDB.instance.database;
      
      final date = dateCloture ?? DateTime.now();
      final dateOnly = DateTime(date.year, date.month, date.day);
      
      // Vérifier si déjà clôturé
      final clotureExistante = await LocalDB.instance.getClotureVirtuelleByDate(shopId, dateOnly);
      
      if (clotureExistante != null) {
        debugPrint('Une clôture virtuelle existe déjà pour le ${dateOnly.toIso8601String().split('T')[0]}');
        throw Exception('Une clôture virtuelle existe déjà pour cette date');
      }

      // Générer le rapport
      final rapport = await genererRapportCloture(
        shopId: shopId,
        date: dateOnly,
      );

      final cloture = ClotureVirtuelleModel(
        shopId: shopId,
        shopDesignation: shopDesignation,
        dateCloture: dateOnly,
        nombreCaptures: rapport['nombreCaptures'],
        montantTotalCaptures: rapport['montantTotalCaptures'],
        nombreServies: rapport['nombreServies'],
        montantVirtuelServies: rapport['montantVirtuelServies'],
        fraisPercus: rapport['fraisPercus'],
        cashServi: rapport['cashServi'],
        nombreEnAttente: rapport['nombreEnAttente'],
        montantVirtuelEnAttente: rapport['montantVirtuelEnAttente'],
        nombreAnnulees: rapport['nombreAnnulees'],
        montantVirtuelAnnulees: rapport['montantVirtuelAnnulees'],
        nombreRetraits: rapport['nombreRetraits'],
        montantTotalRetraits: rapport['montantTotalRetraits'],
        nombreRetraitsRembourses: rapport['nombreRetraitsRembourses'],
        montantRetraitsRembourses: rapport['montantRetraitsRembourses'],
        nombreRetraitsEnAttente: rapport['nombreRetraitsEnAttente'],
        montantRetraitsEnAttente: rapport['montantRetraitsEnAttente'],
        soldesParOperateur: rapport['soldesParOperateur'],
        nombreSimsParOperateur: rapport['nombreSimsParOperateur'],
        soldeTotalSims: rapport['soldeTotalSims'],
        nombreTotalSims: rapport['nombreTotalSims'],
        soldeTotalVirtuel: rapport['soldeTotalVirtuel'],
        cashDuAuxClients: rapport['cashDuAuxClients'],
        fraisTotalJournee: rapport['fraisTotalJournee'],
        cloturePar: cloturePar,
        dateEnregistrement: DateTime.now(),
        notes: notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: cloturePar,
      );

      // Sauvegarder la clôture
      await LocalDB.instance.saveClotureVirtuelle(cloture);
      
      debugPrint('Journee virtuelle cloturee avec succes pour le ${dateOnly.toIso8601String().split('T')[0]}');
      debugPrint('   Servies: ${rapport['nombreServies']}, Frais: ${rapport['fraisPercus']} USD');
      debugPrint('   Solde total SIMs: ${rapport['soldeTotalSims']} USD');
    } catch (e) {
      debugPrint('Erreur lors de la cloture virtuelle: $e');
      rethrow;
    }
  }

  /// Vérifier si la journée a déjà été clôturée
  Future<bool> journeeEstCloturee(int shopId, DateTime date) async {
    // S'assurer que LocalDB est prêt
    await LocalDB.instance.database;
    
    return await LocalDB.instance.clotureVirtuelleExistsPourDate(shopId, date);
  }
}
