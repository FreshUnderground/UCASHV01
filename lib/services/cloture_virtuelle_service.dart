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

      // === 1. TRANSACTIONS VIRTUELLES ===
      final allTransactions = await LocalDB.instance.getAllVirtualTransactions(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      // Statistiques globales
      final captures = allTransactions;
      final nombreCaptures = captures.length;
      final montantTotalCaptures = captures.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      
      // CASH LORS DES CAPTURES:
      // Client donne VIRTUEL → Nous donnons CASH
      // Cash SORT (diminue) = montantVirtuel des captures
      final cashSortiCaptures = captures.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      
      final servies = allTransactions.where((t) => t.statut == VirtualTransactionStatus.validee).toList();
      final nombreServies = servies.length;
      final montantVirtuelServies = servies.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      final fraisPercus = servies.fold<double>(0, (sum, t) => sum + t.frais);
      final cashServi = servies.fold<double>(0, (sum, t) => sum + t.montantCash);
      
      final enAttente = allTransactions.where((t) => t.statut == VirtualTransactionStatus.enAttente).toList();
      final nombreEnAttente = enAttente.length;
      final montantVirtuelEnAttente = enAttente.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      
      final annulees = allTransactions.where((t) => t.statut == VirtualTransactionStatus.annulee).toList();
      final nombreAnnulees = annulees.length;
      final montantVirtuelAnnulees = annulees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
      
      // NOUVEAU: Statistiques PAR SIM pour les transactions
      final Map<String, Map<String, dynamic>> transactionsParSim = {};
      
      for (var trans in allTransactions) {
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
          transactionsParSim[simKey]!['nombreServies'] += 1;
          transactionsParSim[simKey]!['montantServies'] += trans.montantVirtuel;
          transactionsParSim[simKey]!['fraisServies'] += trans.frais;
          transactionsParSim[simKey]!['cashServi'] += trans.montantCash;
        } else if (trans.statut == VirtualTransactionStatus.enAttente) {
          transactionsParSim[simKey]!['nombreEnAttente'] += 1;
          transactionsParSim[simKey]!['montantEnAttente'] += trans.montantVirtuel;
        } else if (trans.statut == VirtualTransactionStatus.annulee) {
          transactionsParSim[simKey]!['nombreAnnulees'] += 1;
          transactionsParSim[simKey]!['montantAnnulees'] += trans.montantVirtuel;
        }
      }
      
      // === 2. RETRAITS VIRTUELS ===
      final allRetraits = await LocalDB.instance.getAllRetraitsVirtuels(
        shopSourceId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      final nombreRetraits = allRetraits.length;
      final montantTotalRetraits = allRetraits.fold<double>(0, (sum, r) => sum + r.montant);
      
      final retraitsRembourses = allRetraits.where((r) => r.statut == RetraitVirtuelStatus.rembourse).toList();
      final nombreRetraitsRembourses = retraitsRembourses.length;
      final montantRetraitsRembourses = retraitsRembourses.fold<double>(0, (sum, r) => sum + r.montant);
      
      // CASH ENTRANT lors des remboursements de retraits virtuels
      // Quand un retrait est remboursé (via FLOT), on reçoit du CASH
      final cashEntrantRetraitsRembourses = montantRetraitsRembourses;
      
      final retraitsEnAttente = allRetraits.where((r) => r.statut == RetraitVirtuelStatus.enAttente).toList();
      final nombreRetraitsEnAttente = retraitsEnAttente.length;
      final montantRetraitsEnAttente = retraitsEnAttente.fold<double>(0, (sum, r) => sum + r.montant);
      
      // NOUVEAU: Retraits PAR SIM
      final Map<String, Map<String, dynamic>> retraitsParSim = {};
      
      for (var retrait in allRetraits) {
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
          retraitsParSim[simKey]!['nombreRembourses'] += 1;
          retraitsParSim[simKey]!['montantRembourses'] += retrait.montant;
        } else if (retrait.statut == RetraitVirtuelStatus.enAttente) {
          retraitsParSim[simKey]!['nombreEnAttente'] += 1;
          retraitsParSim[simKey]!['montantEnAttente'] += retrait.montant;
        }
      }
      
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
      // Cash SORT lors des captures (on donne cash contre virtuel)
      final cashSortiTotal = cashSortiCaptures;
      
      // Cash ENTRANT lors des remboursements de retraits
      final cashEntrantTotal = cashEntrantRetraitsRembourses;
      
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
        'mouvementNetCash': mouvementNetCash,
        // NOUVEAU: Détails par SIM
        'transactionsParSim': transactionsParSim,
        'retraitsParSim': retraitsParSim,
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
