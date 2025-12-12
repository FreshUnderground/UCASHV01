import 'package:flutter/foundation.dart';
import '../models/cloture_virtuelle_par_sim_model.dart';
import '../models/virtual_transaction_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../models/sim_model.dart';
import '../models/depot_client_model.dart';
import 'local_db.dart';

/// Service pour gérer les clôtures virtuelles détaillées par SIM
class ClotureVirtuelleParSimService {
  static final ClotureVirtuelleParSimService _instance = ClotureVirtuelleParSimService._internal();
  static ClotureVirtuelleParSimService get instance => _instance;
  
  ClotureVirtuelleParSimService._internal();

  /// Générer la clôture pour toutes les SIMs d'un shop pour une date donnée
  Future<List<ClotureVirtuelleParSimModel>> genererClotureParSim({
    required int shopId,
    required int agentId,
    required String cloturePar,
    DateTime? date,
    String? notes,
  }) async {
    try {
      final dateCloture = date ?? DateTime.now();
      final dateDebut = DateTime(dateCloture.year, dateCloture.month, dateCloture.day);
      final dateFin = DateTime(dateCloture.year, dateCloture.month, dateCloture.day, 23, 59, 59);
      
      debugPrint('🔄 Génération clôture par SIM - Shop: $shopId, Date: ${dateCloture.toIso8601String().split('T')[0]}');
      
      // Récupérer toutes les SIMs du shop
      final allSims = await LocalDB.instance.getAllSims();
      final shopSims = allSims.where((sim) => sim.shopId == shopId).toList();
      
      if (shopSims.isEmpty) {
        debugPrint('⚠️ Aucune SIM trouvée pour le shop $shopId');
        return [];
      }
      
      debugPrint('📱 ${shopSims.length} SIM(s) trouvée(s) pour le shop');
      
      // Récupérer toutes les données nécessaires en une seule fois
      final allTransactions = await LocalDB.instance.getAllVirtualTransactions(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      final allRetraits = await LocalDB.instance.getAllRetraitsVirtuels(
        shopSourceId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      final allDepots = await LocalDB.instance.getAllDepotsClients(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      debugPrint('📊 Données récupérées: ${allTransactions.length} transactions, ${allRetraits.length} retraits, ${allDepots.length} dépôts');
      
      // Générer la clôture pour chaque SIM
      List<ClotureVirtuelleParSimModel> clotures = [];
      
      for (var sim in shopSims) {
        final cloture = await _genererCloturePourSim(
          sim: sim,
          dateCloture: dateCloture,
          dateDebut: dateDebut,
          dateFin: dateFin,
          transactions: allTransactions.where((t) => t.simNumero == sim.numero).toList(),
          retraits: allRetraits.where((r) => r.simNumero == sim.numero).toList(),
          depots: allDepots.where((d) => d.simNumero == sim.numero).toList(),
          cloturePar: cloturePar,
          agentId: agentId,
          notes: notes,
        );
        
        clotures.add(cloture);
      }
      
      debugPrint('✅ ${clotures.length} clôture(s) générée(s)');
      return clotures;
      
    } catch (e) {
      debugPrint('❌ Erreur génération clôture par SIM: $e');
      rethrow;
    }
  }

  /// Générer la clôture pour une SIM spécifique
  Future<ClotureVirtuelleParSimModel> _genererCloturePourSim({
    required SimModel sim,
    required DateTime dateCloture,
    required DateTime dateDebut,
    required DateTime dateFin,
    required List<VirtualTransactionModel> transactions,
    required List<RetraitVirtuelModel> retraits,
    required List<DepotClientModel> depots,
    required String cloturePar,
    required int agentId,
    String? notes,
  }) async {
    // === CALCULER SOLDE ANTÉRIEUR ===
    // Récupérer la dernière clôture de cette SIM
    final derniereClotureMap = await LocalDB.instance.getDerniereClotureParSim(
      simNumero: sim.numero,
      avant: dateDebut,
    );
    
    final derniereCloture = derniereClotureMap != null
        ? ClotureVirtuelleParSimModel.fromMap(derniereClotureMap as Map<String, dynamic>)
        : null;
    
    final soldeAnterieur = derniereCloture?.soldeActuel ?? sim.soldeActuel;
    
    // === TRANSACTIONS DU JOUR ===
    int nombreCaptures = 0;
    double montantCaptures = 0.0;
    int nombreServies = 0;
    double montantServies = 0.0;
    double cashServi = 0.0;
    double fraisDuJour = 0.0;
    int nombreEnAttente = 0;
    double montantEnAttente = 0.0;
    
    for (var trans in transactions) {
      nombreCaptures++;
      montantCaptures += trans.montantVirtuel;
      
      if (trans.statut == VirtualTransactionStatus.validee) {
        nombreServies++;
        montantServies += trans.montantVirtuel;
        cashServi += trans.montantCash;
        fraisDuJour += trans.frais;
      } else if (trans.statut == VirtualTransactionStatus.enAttente) {
        nombreEnAttente++;
        montantEnAttente += trans.montantVirtuel;
      }
    }
    
    // === RETRAITS DU JOUR ===
    int nombreRetraits = retraits.length;
    double montantRetraits = retraits.fold<double>(0.0, (sum, r) => sum + r.montant);
    
    // === DÉPÔTS CLIENTS DU JOUR ===
    int nombreDepots = depots.length;
    double montantDepots = depots.fold<double>(0.0, (sum, d) => sum + d.montant);
    
    // === CALCULER SOLDE ACTUEL ===
    // BUSINESS LOGIC: Solde Actuel = Solde Antérieur + Captures - Servies - Retraits - Dépôts
    // This formula represents the virtual balance evolution for a SIM card:
    // - Starting balance (soldeAnterieur)
    // - Add all captured virtual amounts (captures)
    // - Subtract served transactions (servies) - money converted to cash
    // - Subtract withdrawals (retraits) - money given to clients
    // - Subtract client deposits (depots) - virtual to cash conversions
    final soldeActuel = soldeAnterieur + montantCaptures - montantServies - montantRetraits - montantDepots;
    
    // === CALCULER CASH DISPONIBLE ===
    // Le cash est GLOBAL et sera défini par le widget
    // Ici on le met à 0 par défaut, il sera écrasé lors de la saisie
    final cashDisponible = 0.0;
    
    // === FRAIS (AUTOMATIQUE) ===
    // Formule: Frais Antérieur + Frais Encaissés du Jour
    // Les frais sont perçus sur chaque transaction servie
    final fraisAnterieur = derniereCloture?.fraisTotal ?? 0.0;
    final fraisTotal = fraisAnterieur + fraisDuJour; // AUTOMATIQUE, pas de saisie manuelle
    
    debugPrint('💰 Frais pour ${sim.numero}: Antérieur=$fraisAnterieur + Du Jour=$fraisDuJour = Total=$fraisTotal (AUTOMATIQUE)');
    debugPrint('📱 SIM ${sim.numero}: Solde=${soldeActuel.toStringAsFixed(2)}, Frais=${fraisTotal.toStringAsFixed(2)}');
    
    return ClotureVirtuelleParSimModel(
      shopId: sim.shopId,
      simNumero: sim.numero,
      operateur: sim.operateur,
      dateCloture: dateCloture,
      soldeAnterieur: soldeAnterieur,
      soldeActuel: soldeActuel,
      cashDisponible: cashDisponible,
      fraisAnterieur: fraisAnterieur,
      fraisDuJour: fraisDuJour,
      fraisTotal: fraisTotal,
      nombreCaptures: nombreCaptures,
      montantCaptures: montantCaptures,
      nombreServies: nombreServies,
      montantServies: montantServies,
      cashServi: cashServi,
      nombreEnAttente: nombreEnAttente,
      montantEnAttente: montantEnAttente,
      nombreRetraits: nombreRetraits,
      montantRetraits: montantRetraits,
      nombreDepots: nombreDepots,
      montantDepots: montantDepots,
      cloturePar: cloturePar,
      agentId: agentId,
      dateEnregistrement: DateTime.now(),
      notes: notes,
    );
  }

  /// Sauvegarder les clôtures dans LocalDB
  Future<void> sauvegarderClotures(List<ClotureVirtuelleParSimModel> clotures) async {
    try {
      for (var cloture in clotures) {
        await LocalDB.instance.saveClotureVirtuelleParSim(cloture);
      }
      debugPrint('✅ ${clotures.length} clôture(s) sauvegardée(s)');
    } catch (e) {
      debugPrint('❌ Erreur sauvegarde clôtures: $e');
      rethrow;
    }
  }

  /// Récupérer les clôtures par date
  Future<List<ClotureVirtuelleParSimModel>> getCloturesParDate({
    required int shopId,
    required DateTime date,
  }) async {
    try {
      final cloturesMaps = await LocalDB.instance.getCloturesVirtuellesParDate(
        shopId: shopId,
        date: date,
      );
      
      return cloturesMaps
          .map((map) => ClotureVirtuelleParSimModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération clôtures: $e');
      return [];
    }
  }

  /// Récupérer l'historique des clôtures pour une SIM
  Future<List<ClotureVirtuelleParSimModel>> getHistoriqueParSim({
    required String simNumero,
    DateTime? depuis,
    DateTime? jusqua,
  }) async {
    try {
      final cloturesMaps = await LocalDB.instance.getHistoriqueCloturesParSim(
        simNumero: simNumero,
        depuis: depuis,
        jusqua: jusqua,
      );
      
      return cloturesMaps
          .map((map) => ClotureVirtuelleParSimModel.fromMap(map as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('❌ Erreur récupération historique: $e');
      return [];
    }
  }

  /// Supprimer toutes les clôtures par SIM pour une date donnée
  Future<void> deleteCloturesParDate({
    required int shopId,
    required DateTime date,
  }) async {
    try {
      await LocalDB.instance.deleteCloturesVirtuellesParDate(
        shopId: shopId,
        date: date,
      );
      debugPrint('✅ Clôtures supprimées pour le ${date.toIso8601String()}');
    } catch (e) {
      debugPrint('❌ Erreur suppression clôtures: $e');
      rethrow;
    }
  }
}
