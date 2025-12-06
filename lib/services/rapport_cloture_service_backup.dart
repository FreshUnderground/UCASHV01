import 'package:flutter/foundation.dart';
import '../models/rapport_cloture_model.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/cloture_caisse_model.dart';
import '../models/cloture_virtuelle_par_sim_model.dart';
import '../models/compte_special_model.dart';
import 'local_db.dart';
import 'flot_service.dart';
import 'compte_special_service.dart';

/// Service pour générer le Rapport de Clôture Journalière
class RapportClotureService {
  static final RapportClotureService _instance = RapportClotureService._internal();
  static RapportClotureService get instance => _instance;
  
  RapportClotureService._internal();

  /// Générer le rapport de clôture pour une date donnée
  Future<RapportClotureModel> genererRapport({
    required int shopId,
    DateTime? date,
    String? generePar,
    List<OperationModel>? operations, // Optionnel: utiliser les opérations de "Mes Ops"
  }) async {
    try {
      final dateRapport = date ?? DateTime.now();
      final shop = await LocalDB.instance.getShopById(shopId);
      
      if (shop == null) {
        throw Exception('Shop non trouvé: $shopId');
      }

      debugPrint('📊 Génération rapport clôture pour ${shop.designation} - ${dateRapport.toIso8601String().split('T')[0]}');

      // 1. Récupérer le solde antérieur (clôture du jour précédent)
      final soldeAnterieur = await _getSoldeAnterieur(shopId, dateRapport);
      final soldeFraisAnterieur = soldeAnterieur['soldeFraisAnterieur'] ?? 0.0;

      // 2. Calculer les flots
      final flots = await _calculerFlots(shopId, dateRapport);

      // 3. Calculer les transferts
      final transferts = await _calculerTransferts(shopId, dateRapport, operations);

      // 4. Calculer les opérations clients (dépôts/retraits)
      final operationsClients = await _calculerOperationsClients(shopId, dateRapport, operations);

      // 5. Récupérer les transactions partenaires du jour
      final comptesClients = await _getComptesClients(shopId, dateRapport, operations);
      
      // 6. Calculer les dettes/créances inter-shops
      final comptesShops = await _getComptesShops(shopId);
      
      // 6.5. Calculer les comptes spéciaux (FRAIS et DÉPENSE)
      final comptesSpeciaux = await _calculerComptesSpeciaux(shopId, dateRapport, operations);

      // 7. Calculer les transferts groupés par route
      final transfertsGroupes = await _calculerTransfertsGroupes(shopId, dateRapport, operations);

      // 8. Calculer le cash disponible par mode de paiement
      final cashDisponible = _calculerCashDisponible(
        shop: shop,
        soldeAnterieur: soldeAnterieur,
        flots: {
          'recu': flots['recu'] as double,
          'envoye': flots['envoye'] as double,
        },
        transferts: {
          'recus': transferts['recus'] as double,
          'servis': transferts['servis'] as double,
        },
        operationsClients: {
          'depots': operationsClients['depots'] as double,
          'retraits': operationsClients['retraits'] as double,
        },
        retraitsFrais: comptesSpeciaux['retraits_frais'] as double, // NOUVEAU: Soustraire retraits FRAIS
      );

      // Calculate capital net according to the formula:
      // CAPITAL NET = CASH DISPONIBLE (déjà diminué des retraits FRAIS) + CRÉANCES - DETTES
      final totalClientsNousDoivent = comptesClients['nousDoivent']!
          .fold(0.0, (sum, client) => sum + client.solde.abs());
      final totalClientsNousDevons = comptesClients['nousDevons']!
          .fold(0.0, (sum, client) => sum + client.solde);
      final totalShopsNousDoivent = comptesShops['nousDoivent']!
          .fold(0.0, (sum, shop) => sum + shop.montant);
      final totalShopsNousDevons = comptesShops['nousDevons']!
          .fold(0.0, (sum, shop) => sum + shop.montant);
      
      // Le cash disponible a déjà les retraits FRAIS soustraits, donc on ne les soustrait PAS ici
      final capitalNet = cashDisponible['total']! 
          + totalClientsNousDoivent 
          + totalShopsNousDoivent 
          - totalClientsNousDevons 
          - totalShopsNousDevons;

      return RapportClotureModel(
        shopId: shopId,
        shopDesignation: shop.designation,
        dateRapport: dateRapport,
        
        // Solde antérieur
        soldeAnterieurCash: soldeAnterieur['cash']!,
        soldeAnterieurAirtelMoney: soldeAnterieur['airtelMoney']!,
        soldeAnterieurMPesa: soldeAnterieur['mPesa']!,
        soldeAnterieurOrangeMoney: soldeAnterieur['orangeMoney']!,
        
        // Flots
        flotRecu: flots['recu']!,
        flotEnvoye: flots['envoye']!,
        
        // Transferts
        transfertsRecus: transferts['recus']!,
        transfertsServis: transferts['servis']!,
        transfertsEnAttente: transferts['enAttente']!,
        transfertsRecusGroupes: transferts['transfertsRecusGroupes'] as Map<String, double>,
        transfertsServisGroupes: transferts['transfertsServisGroupes'] as Map<String, double>,
        transfertsEnAttenteGroupes: transferts['transfertsEnAttenteGroupes'] as Map<String, double>,
        
        // Clients
        depotsClients: operationsClients['depots']!,
        retraitsClients: operationsClients['retraits']!,
        
        // Comptes clients
        clientsNousDoivent: comptesClients['nousDoivent']!,
        clientsNousDevons: comptesClients['nousDevons']!,
        
        // Comptes inter-shops
        shopsNousDoivent: comptesShops['nousDoivent']!,
        shopsNousDevons: comptesShops['nousDevons']!,
        
        // NOUVEAU: Comptes spéciaux (FRAIS uniquement)
        soldeFraisAnterieur: soldeFraisAnterieur,
        retraitsFraisDuJour: comptesSpeciaux['retraits_frais'] as double,
        commissionsFraisDuJour: comptesSpeciaux['commissions_frais'] as double,
        fraisGroupesParShop: comptesSpeciaux['frais_groupes_par_shop'] as Map<String, double>,
        soldeFraisTotal: comptesSpeciaux['solde_frais_total'] as double,
        sortiesDepenseDuJour: 0.0,  // Non utilisé
        depotsDepenseDuJour: 0.0,   // Non utilisé
        soldeDepenseTotal: 0.0,     // Non utilisé
        
        // NOUVEAU: Listes détaillées des FLOT
        flotsRecusDetails: flots['flotsRecusDetails'] as List<FlotResume>,
        flotsRecusGroupes: flots['flotsRecusGroupes'] as Map<String, double>,
        flotsEnvoyes: flots['flotsEnvoyesDetails'] as List<FlotResume>,
        flotsEnvoyesGroupes: flots['flotsEnvoyesGroupes'] as Map<String, double>,
        flotsEnAttenteGroupes: flots['flotsEnAttenteGroupes'] as Map<String, double>,        
        // NOUVEAU: Listes détaillées des opérations clients
        depotsClientsDetails: operationsClients['depotsDetails'] as List<OperationResume>,
        retraitsClientsDetails: operationsClients['retraitsDetails'] as List<OperationResume>,
        
        // NOUVEAU: Liste détaillée des transferts en attente
        transfertsEnAttenteDetails: transferts['enAttenteDetails'] as List<OperationResume>,
        
        // NOUVEAU: Liste des transferts groupés par route
        transfertsGroupes: transfertsGroupes,
        
        // Cash disponible
        cashDisponibleCash: cashDisponible['cash']!,
        cashDisponibleAirtelMoney: cashDisponible['airtelMoney']!,
        cashDisponibleMPesa: cashDisponible['mPesa']!,
        cashDisponibleOrangeMoney: cashDisponible['orangeMoney']!,
        cashDisponibleTotal: cashDisponible['total']!,
        
        // Capital Net
        capitalNet: capitalNet,
        
        generePar: generePar,
        dateGeneration: DateTime.now(),
      );
    } catch (e) {
      debugPrint('❌ Erreur génération rapport: $e');
      rethrow;
    }
  }

  /// Récupérer le solde antérieur (du jour précédent)
  /// NOUVEAU: Inclut automatiquement la somme des soldes des SIMs de la clôture virtuelle
  Future<Map<String, double>> _getSoldeAnterieur(int shopId, DateTime dateRapport) async {
    // Récupérer la clôture CASH du jour précédent
    final jourPrecedent = dateRapport.subtract(const Duration(days: 1));
    final cloturePrecedente = await LocalDB.instance.getClotureCaisseByDate(shopId, jourPrecedent);
    
    // NOUVEAU: Récupérer les clôtures virtuelles PAR SIM du jour précédent
    final cloturesSimsHierMaps = await LocalDB.instance.getCloturesVirtuellesParDate(
      shopId: shopId,
      date: jourPrecedent,
    );
    
    // Convertir en modèles
    final cloturesSimsHier = cloturesSimsHierMaps
        .map((map) => ClotureVirtuelleParSimModel.fromMap(map as Map<String, dynamic>))
        .toList();
    
    // Calculer la SOMME des soldes des SIMs d'hier
    double soldeTotalSimsHier = 0.0;
    if (cloturesSimsHier.isNotEmpty) {
      soldeTotalSimsHier = cloturesSimsHier.fold<double>(
        0.0,
        (sum, clotureSim) => sum + (clotureSim.soldeActuel ?? 0.0),
      );
      debugPrint('💰 Somme des soldes SIMs d\'hier: ${soldeTotalSimsHier.toStringAsFixed(2)} USD (${cloturesSimsHier.length} SIM(s))');
    } else {
      debugPrint('ℹ️ Aucune clôture virtuelle par SIM trouvée pour hier');
    }
    
    if (cloturePrecedente != null) {
      debugPrint('📋 Solde antérieur trouvé (clôture du ${jourPrecedent.toIso8601String().split('T')[0]}):');
      debugPrint('   Cash SAISI: ${cloturePrecedente.soldeSaisiCash} USD (Calculé: ${cloturePrecedente.soldeCalculeCash})');
      debugPrint('   Airtel Money SAISI: ${cloturePrecedente.soldeSaisiAirtelMoney} USD (Calculé: ${cloturePrecedente.soldeCalculeAirtelMoney})');
      debugPrint('   M-Pesa SAISI: ${cloturePrecedente.soldeSaisiMPesa} USD (Calculé: ${cloturePrecedente.soldeCalculeMPesa})');
      debugPrint('   Orange Money SAISI: ${cloturePrecedente.soldeSaisiOrangeMoney} USD (Calculé: ${cloturePrecedente.soldeCalculeOrangeMoney})');
      debugPrint('   TOTAL SAISI: ${cloturePrecedente.soldeSaisiTotal} USD (Calculé: ${cloturePrecedente.soldeCalculeTotal})');
      debugPrint('   ÉCART TOTAL: ${cloturePrecedente.ecartTotal} USD');
      debugPrint('   FRAIS ANTÉRIEUR: ${cloturePrecedente.soldeFraisAnterieur} USD');
      debugPrint('   + SOLDE VIRTUEL (SIMs): ${soldeTotalSimsHier.toStringAsFixed(2)} USD');
      
      // NOUVEAU: Utiliser les montants SAISIS + SOLDE VIRTUEL comme solde antérieur
      // Le solde virtuel est ajouté au Cash car c'est de l'argent mobile
      return {
        'cash': cloturePrecedente.soldeSaisiCash + soldeTotalSimsHier,  // Cash + Virtuel
        'airtelMoney': cloturePrecedente.soldeSaisiAirtelMoney,
        'mPesa': cloturePrecedente.soldeSaisiMPesa,
        'orangeMoney': cloturePrecedente.soldeSaisiOrangeMoney,
        'soldeFraisAnterieur': cloturePrecedente.soldeFraisAnterieur ?? 0.0,
      };
    }
    
    // Si aucune clôture CASH précédente, mais il y a des clôtures virtuelles
    if (soldeTotalSimsHier > 0) {
      debugPrint('ℹ️ Aucune clôture CASH, mais solde virtuel trouvé: ${soldeTotalSimsHier.toStringAsFixed(2)} USD');
      return {
        'cash': soldeTotalSimsHier,  // Le virtuel devient le cash de départ
        'airtelMoney': 0.0,
        'mPesa': 0.0,
        'orangeMoney': 0.0,
        'soldeFraisAnterieur': 0.0,
      };
    }
    
    // Si aucune clôture précédente (ni cash ni virtuelle), retourner 0 (premier jour d'utilisation)
    debugPrint('ℹ️ Aucun solde antérieur (pas de clôture du jour précédent)');
    return {
      'cash': 0.0,
      'airtelMoney': 0.0,
      'mPesa': 0.0,
      'orangeMoney': 0.0,
      'soldeFraisAnterieur': 0.0,
    };
  }

  /// Calculer les flots (reçus, en cours, servis) + LISTES DÉTAILLÉES
  Future<Map<String, dynamic>> _calculerFlots(int shopId, DateTime dateRapport) async {
    // IMPORTANT: Charger les FLOTs depuis la table operations (type = flotShopToShop)
    // Au lieu de l'ancienne table flots
    final operations = await LocalDB.instance.getAllOperations();
    
    // Charger tous les shops pour avoir leurs noms
    final shops = await LocalDB.instance.getAllShops();
    final shopsMap = {for (var shop in shops) shop.id: shop.designation};

    // FLOT REÇUS = FLOTs vers nous (reçus aujourd'hui - utilisent date_validation, fallback sur created_at si null)
    final flotsRecusServis = operations.where((f) =>
        f.type == OperationType.flotShopToShop &&
        f.shopDestinationId == shopId &&
        f.statut == OperationStatus.validee &&
        _isSameDay(f.dateValidation ?? f.createdAt ?? f.dateOp, dateRapport)
    ).toList();
    
    // FLOT EN ATTENTE = FLOTs vers nous (en attente de réception)
    final flotsEnAttente = operations.where((f) =>
        f.type == OperationType.flotShopToShop &&
        f.shopDestinationId == shopId &&
        f.statut == OperationStatus.enAttente
    ).toList();
    
    final flotsRecus = [...flotsRecusServis, ...flotsEnAttente];
    
    debugPrint('📥 FLOTs REÇUS (shopDestinationId=$shopId): ${flotsRecus.length} FLOTs (${flotsRecusServis.length} servis, ${flotsEnAttente.length} en attente)');
    
    // FLOT ENVOYÉS = FLOTs par nous (envoyés aujourd'hui - utilisent created_at)
    final flotsEnvoyes = operations.where((f) =>
        f.type == OperationType.flotShopToShop &&
        f.shopSourceId == shopId &&
        _isSameDay(f.createdAt ?? f.dateOp, dateRapport)
    ).toList();
    
    debugPrint('📤 FLOTs ENVOYÉS (shopSourceId=$shopId): ${flotsEnvoyes.length} FLOTs');
    
    // Créer les listes détaillées pour affichage dans le rapport
    final flotsRecusDetails = flotsRecus.map((f) => FlotResume(
      flotId: f.id!,
      shopSourceDesignation: shopsMap[f.shopSourceId] ?? 'Shop inconnu',
      shopDestinationDesignation: shopsMap[f.shopDestinationId] ?? 'Shop inconnu',
      montant: f.montantNet,
      devise: f.devise,
      statut: f.statut.name,
      dateEnvoi: f.dateOp,
      dateReception: f.dateValidation,
      modePaiement: f.modePaiement.name,
    )).toList();
    
    // GROUPER LES FLOTS REÇUS PAR SHOP EXPÉDITEUR (SOURCE ID)
    final flotsRecusGroupes = <String, double>{};
    for (var flot in flotsRecus) {
      final shopSourceId = flot.shopSourceId;
      final shopName = shopsMap[shopSourceId] ?? 'Shop inconnu (ID: $shopSourceId)';
      flotsRecusGroupes[shopName] = (flotsRecusGroupes[shopName] ?? 0.0) + flot.montantNet;
    }
    
    // GROUPER LES FLOTS EN ATTENTE PAR SHOP EXPÉDITEUR (SOURCE ID)
    final flotsEnAttenteGroupes = <String, double>{};
    for (var flot in flotsEnAttente) {
      final shopSourceId = flot.shopSourceId;
      final shopName = shopsMap[shopSourceId] ?? 'Shop inconnu (ID: $shopSourceId)';
      flotsEnAttenteGroupes[shopName] = (flotsEnAttenteGroupes[shopName] ?? 0.0) + flot.montantNet;
    }
    
    debugPrint('📊 FLOTS REÇUS GROUPÉS PAR SHOP SOURCE:');
    flotsRecusGroupes.forEach((shop, montant) {
      debugPrint('   - $shop: ${montant.toStringAsFixed(2)} USD');
    });
    
    final flotsEnvoyesDetails = flotsEnvoyes.map((f) => FlotResume(
      flotId: f.id!,
      shopSourceDesignation: shopsMap[f.shopSourceId] ?? 'Shop inconnu',
      shopDestinationDesignation: shopsMap[f.shopDestinationId] ?? 'Shop inconnu',
      montant: f.montantNet,
      devise: f.devise,
      statut: f.statut.name,
      dateEnvoi: f.dateOp,
      dateReception: f.dateValidation,
      modePaiement: f.modePaiement.name,
    )).toList();
    
    // GROUPER LES FLOTS ENVOYÉS PAR SHOP DESTINATION (DESTINATION ID)
    final flotsEnvoyesGroupes = <String, double>{};
    for (var flot in flotsEnvoyes) {
      final shopDestinationId = flot.shopDestinationId;
      final shopName = shopsMap[shopDestinationId] ?? 'Shop inconnu (ID: $shopDestinationId)';
      flotsEnvoyesGroupes[shopName] = (flotsEnvoyesGroupes[shopName] ?? 0.0) + flot.montantNet;
    }

    return {
      'recu': flotsRecus.fold(0.0, (sum, f) => sum + f.montantNet),     // ENTRÉE (+)
      'envoye': flotsEnvoyes.fold(0.0, (sum, f) => sum + f.montantNet), // SORTIE (-)
      'flotsRecusDetails': flotsRecusDetails,
      'flotsRecusGroupes': flotsRecusGroupes, // GROUPÉ PAR SHOP EXPÉDITEUR
      'flotsEnAttenteGroupes': flotsEnAttenteGroupes, // GROUPÉ PAR SHOP EXPÉDITEUR
      'flotsEnvoyesDetails': flotsEnvoyesDetails,
      'flotsEnvoyesGroupes': flotsEnvoyesGroupes, // GROUPÉ PAR SHOP DESTINATION
    };
  }
  /// Calculer les transferts (reçus, servis et en attente)
  Future<Map<String, dynamic>> _calculerTransferts(int shopId, DateTime dateRapport, List<OperationModel>? providedOperations) async {
    // Utiliser les opérations fournies (de "Mes Ops") ou charger depuis LocalDB
    final operations = providedOperations ?? await LocalDB.instance.getAllOperations();
    
    // Charger tous les shops pour avoir leurs noms
    final shops = await LocalDB.instance.getAllShops();
    final shopsMap = {for (var shop in shops) shop.id: shop.designation};
    
    // Transferts REÇUS = client nous paie (ENTRÉE d'argent) - utilisent created_at
    final transfertsRecus = operations.where((op) =>
        op.shopSourceId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalSortant) &&
        _isSameDay(op.createdAt ?? op.dateOp, dateRapport)
    ).toList();

    // Transferts SERVIS = nous servons le client (SORTIE d'argent) - utilisent date_validation, fallback sur created_at si null
    final transfertsServis = operations.where((op) =>
        op.shopDestinationId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.dateValidation ?? op.createdAt ?? op.dateOp, dateRapport)
    ).toList();
    
    // Transferts EN ATTENTE = transferts à servir (shop destination, statut enAttente)
    // OU transferts servis sans date_validation (affichés comme en attente)
    final transfertsEnAttente = operations.where((op) =>
        op.shopDestinationId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant ||
         op.type == OperationType.transfertInternationalSortant) &&
        (op.statut == OperationStatus.enAttente )
    ).toList();
    
    // Créer la liste détaillée des transferts en attente
    final transfertsEnAttenteDetails = transfertsEnAttente.map((op) => OperationResume(
      operationId: op.id!,
      type: 'transfert_en_attente',
      montant: op.montantNet,
      devise: op.devise,
      date: op.dateOp,
      destinataire: op.destinataire,
      observation: op.observation,
      notes: op.notes,
      modePaiement: op.modePaiement.name,
    )).toList();
    
    // GROUPER LES TRANSFERTS REÇUS PAR SHOP DESTINATION ID (vers nous)
    final transfertsRecusGroupes = <String, double>{};
    for (var op in transfertsRecus) {
      final shopDestId = op.shopDestinationId;
      final shopName = shopsMap[shopDestId] ?? 'Shop inconnu (ID: $shopDestId)';
      transfertsRecusGroupes[shopName] = (transfertsRecusGroupes[shopName] ?? 0.0) + op.montantBrut;
    }
    
    // GROUPER LES TRANSFERTS SERVIS PAR SHOP SOURCE ID (de nous)
    final transfertsServisGroupes = <String, double>{};
    for (var op in transfertsServis) {
      final shopSrcId = op.shopSourceId;
      final shopName = shopsMap[shopSrcId] ?? 'Shop inconnu (ID: $shopSrcId)';
      transfertsServisGroupes[shopName] = (transfertsServisGroupes[shopName] ?? 0.0) + op.montantNet;
    }
    
    // GROUPER LES TRANSFERTS EN ATTENTE PAR SHOP SOURCE ID (qui nous envoie)
    // Note: shopDestinationId = nous, shopSourceId = shop expéditeur
    final transfertsEnAttenteGroupes = <String, double>{};
    for (var op in transfertsEnAttente) {
      final shopSrcId = op.shopSourceId; // Le shop qui nous envoie
      final shopName = shopsMap[shopSrcId] ?? 'Shop inconnu (ID: $shopSrcId)';
      transfertsEnAttenteGroupes[shopName] = (transfertsEnAttenteGroupes[shopName] ?? 0.0) + op.montantNet;
    }
    
    debugPrint('📊 TRANSFERTS EN ATTENTE (${transfertsEnAttente.length} transferts):');
    transfertsEnAttenteGroupes.forEach((shop, montant) {
      debugPrint('   - $shop: ${montant.toStringAsFixed(2)} USD');
    });

    return {
      'recus': transfertsRecus.fold(0.0, (sum, op) => sum + op.montantBrut), // ENTRÉE: Client nous paie
      'servis': transfertsServis.fold(0.0, (sum, op) => sum + op.montantNet), // SORTIE: On sert le client
      'enAttente': transfertsEnAttente.fold(0.0, (sum, op) => sum + op.montantNet), // À SERVIR: Transferts en attente
      'enAttenteDetails': transfertsEnAttenteDetails,
      'transfertsRecusGroupes': transfertsRecusGroupes, // GROUPÉ PAR SHOP DESTINATION
      'transfertsServisGroupes': transfertsServisGroupes, // GROUPÉ PAR SHOP SOURCE
      'transfertsEnAttenteGroupes': transfertsEnAttenteGroupes, // GROUPÉ PAR SHOP SOURCE
    };
  }

  /// Calculer les dépôts et retraits clients
  Future<Map<String, dynamic>> _calculerOperationsClients(int shopId, DateTime dateRapport, List<OperationModel>? providedOperations) async {
    // Utiliser les opérations fournies (de "Mes Ops") ou charger depuis LocalDB
    final operations = providedOperations ?? await LocalDB.instance.getAllOperations();
    
    final depotsAujourdhui = operations.where((op) =>
        op.shopSourceId == shopId &&
        op.type == OperationType.depot &&
        _isSameDay(op.dateOp, dateRapport)
    ).toList();

    final retraitsAujourdhui = operations.where((op) =>
        op.shopSourceId == shopId &&
        (op.type == OperationType.retrait || op.type == OperationType.retraitMobileMoney) &&
        _isSameDay(op.dateOp, dateRapport)
    ).toList();
    
    // Créer les listes détaillées avec observations
    final depotsDetails = depotsAujourdhui.map((op) => OperationResume(
      operationId: op.id!,
      type: 'depot',
      montant: op.montantNet,
      devise: op.devise,
      date: op.dateOp,
      destinataire: op.destinataire,
      observation: op.observation, // IMPORTANT: Observation saisie par l'agent
      notes: op.notes,
      modePaiement: op.modePaiement.name,
    )).toList();
    
    final retraitsDetails = retraitsAujourdhui.map((op) => OperationResume(
      operationId: op.id!,
      type: 'retrait',
      montant: op.montantNet,
      devise: op.devise,
      date: op.dateOp,
      destinataire: op.destinataire,
      observation: op.observation, // IMPORTANT: Observation saisie par l'agent
      notes: op.notes,
      modePaiement: op.modePaiement.name,
    )).toList();

    return {
      'depots': depotsAujourdhui.fold(0.0, (sum, op) => sum + op.montantNet),
      'retraits': retraitsAujourdhui.fold(0.0, (sum, op) => sum + op.montantNet),
      'depotsDetails': depotsDetails,
      'retraitsDetails': retraitsDetails,
    };
  }

  /// Récupérer les transactions partenaires du jour
  /// - "Clients Nous que Devons" = "Dépôts Partenaires" : Partenaires qui ont déposé dans leur compte durant le jour
  /// - "Clients Nous qui Doivent" = "Partenaires Servis" : Partenaires qui ont retiré de leur compte durant le jour
  Future<Map<String, List<CompteClientResume>>> _getComptesClients(int shopId, DateTime dateRapport, List<OperationModel>? providedOperations) async {
    // Utiliser les opérations fournies (de "Mes Ops") ou charger depuis LocalDB
    final operations = providedOperations ?? await LocalDB.instance.getAllOperations();
    final clients = await LocalDB.instance.getAllClients();
    
    final depotsPartenaires = <CompteClientResume>[];
    final partenairesServis = <CompteClientResume>[];

    // Récupérer les opérations de type DÉPÔT avec clientId (partenaire dépose dans son compte)
    final depotsCompte = operations.where((op) =>
        op.shopSourceId == shopId &&
        op.type == OperationType.depot &&
        op.clientId != null && // Dépôt dans un compte client
        _isSameDay(op.dateOp, dateRapport)
    );

    // Récupérer les opérations de type RETRAIT avec clientId (partenaire retire de son compte)
    final retraitsCompte = operations.where((op) =>
        op.shopSourceId == shopId &&
        (op.type == OperationType.retrait || op.type == OperationType.retraitMobileMoney) &&
        op.clientId != null && // Retrait d'un compte client
        _isSameDay(op.dateOp, dateRapport)
    );
    
    // Grouper les dépôts par client
    final depotsParClient = <int, double>{};
    for (var op in depotsCompte) {
      if (op.clientId != null) {
        depotsParClient[op.clientId!] = (depotsParClient[op.clientId!] ?? 0) + op.montantNet;
      }
    }
    
    // Grouper les retraits par client
    final retraitsParClient = <int, double>{};
    for (var op in retraitsCompte) {
      if (op.clientId != null) {
        retraitsParClient[op.clientId!] = (retraitsParClient[op.clientId!] ?? 0) + op.montantNet;
      }
    }
    
    // Créer les résumés pour les dépôts
    for (var entry in depotsParClient.entries) {
      final client = clients.firstWhere((c) => c.id == entry.key, orElse: () => throw Exception('Client non trouvé'));
      depotsPartenaires.add(CompteClientResume(
        clientId: client.id!,
        nom: client.nom,
        telephone: client.telephone,
        solde: entry.value, // Montant déposé aujourd'hui
        numeroCompte: client.numeroCompte ?? 'N/A',
      ));
    }
    
    // Créer les résumés pour les retraits
    for (var entry in retraitsParClient.entries) {
      final client = clients.firstWhere((c) => c.id == entry.key, orElse: () => throw Exception('Client non trouvé'));
      partenairesServis.add(CompteClientResume(
        clientId: client.id!,
        nom: client.nom,
        telephone: client.telephone,
        solde: entry.value, // Montant retiré aujourd'hui
        numeroCompte: client.numeroCompte ?? 'N/A',
      ));
    }

    debugPrint('📊 Dépôts Partenaires (compte): ${depotsPartenaires.length} partenaire(s), Total: ${depotsParClient.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)} USD');
    debugPrint('📊 Partenaires Servis (compte): ${partenairesServis.length} partenaire(s), Total: ${retraitsParClient.values.fold(0.0, (a, b) => a + b).toStringAsFixed(2)} USD');

    return {
      'nousDoivent': partenairesServis, // Partenaires qui ont retiré (on leur a servi)
      'nousDevons': depotsPartenaires,  // Partenaires qui ont déposé (on leur doit)
    };
  }
  
  /// Calculer les dettes/créances inter-shops
  /// NOUVELLE LOGIQUE BASÉE SUR LES TRANSFERTS ET FLOTS
  /// - Transferts servis PAR nous → Ils Nous qui Doivent
  /// - Transferts servis PAR eux → On leur doit
  /// - FLOTs reçus DE eux → On leur doit rembourser
  /// - FLOTs envoyés À eux → Ils Nous qui Doivent rembourser
  /// Le solde final détermine si c'est une dette ou une créance
  Future<Map<String, List<CompteShopResume>>> _getComptesShops(int shopId) async {
    final shops = await LocalDB.instance.getAllShops();
    final operations = await LocalDB.instance.getAllOperations();
    final flotService = FlotService.instance;
    await flotService.loadFlots(shopId: shopId);
    
    // Calculer le solde par shop
    final Map<int, double> soldesParShop = {};
    final Map<int, ShopModel> shopsMap = {};
    
    // Créer un map des shops pour accès rapide
    for (final shop in shops) {
      if (shop.id != null && shop.id != shopId) {
        shopsMap[shop.id!] = shop;
      }
    }
    
    debugPrint('📊 === CALCUL DETTES/CRÉANCES INTER-SHOPS (NOUVELLE LOGIQUE) ===');
    debugPrint('Shop actuel ID: $shopId');
    
    // 1. TRANSFERTS SERVIS PAR NOUS (shop source nous doit le montant BRUT)
    for (final op in operations) {
      if ((op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) &&
          op.shopDestinationId == shopId && // Nous servons le client
          op.devise == 'USD') {
        final autreShopId = op.shopSourceId; // Shop qui a reçu l'argent du client
        if (autreShopId != null && autreShopId != shopId) {
          // IMPORTANT: Le shop source nous doit le MONTANT BRUT (montantNet + commission)
          // Car nous gardons la commission et servons le montantNet
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + op.montantBrut;
          debugPrint('   Transfert SERVI par nous: Shop $autreShopId nous doit +${op.montantBrut.toStringAsFixed(2)} USD (Brut = Net ${op.montantNet} + Commission ${op.commission})');
        }
      }
    }
    
    // 2. TRANSFERTS REÇUS/INITIÉS PAR NOUS (on doit le montant BRUT à l'autre shop)
    for (final op in operations) {
      if ((op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) &&
          op.shopSourceId == shopId && // Client nous a payé
          op.devise == 'USD') {
        final autreShopId = op.shopDestinationId; // Shop qui va servir
        if (autreShopId != null && autreShopId != shopId) {
          // IMPORTANT: On doit le MONTANT BRUT au shop destination
          // Le shop destination garde la commission et sert le montantNet
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - op.montantBrut;
          debugPrint('   Transfert INITIÉ par nous: On doit à Shop $autreShopId -${op.montantBrut.toStringAsFixed(2)} USD (Brut = Net ${op.montantNet} + Commission ${op.commission})');
        }
      }
    }
    
    // 3. FLOTS EN COURS - Deux sens selon qui a initié
    // NOUVEAU: Utiliser operations avec type=flotShopToShop au lieu de flotService.flots
    final allFlots = operations.where((op) => op.type == OperationType.flotShopToShop).toList();
    
    for (final flot in allFlots) {
      if (flot.statut == OperationStatus.enAttente && flot.devise == 'USD') {
        if (flot.shopSourceId == shopId) {
          // NOUS avons envoyé en cours → Ils Nous qui Doivent rembourser
          final autreShopId = flot.shopDestinationId;
          if (autreShopId != null && autreShopId != shopId) {
            soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
            debugPrint('   FLOT EN COURS envoyé PAR nous à Shop $autreShopId: Ils Nous qui Doivent +${flot.montantNet} USD');
          }
        } else if (flot.shopDestinationId == shopId) {
          // ILS ont envoyé en cours → On leur doit rembourser
          final autreShopId = flot.shopSourceId;
          if (autreShopId != null && autreShopId != shopId) {
            soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
            debugPrint('   FLOT EN COURS reçu DE Shop $autreShopId: On leur doit -${flot.montantNet} USD');
          }
        }
      }
    }
    
    // 4. FLOTS REÇUS ET SERVIS (shopDestinationId = nous) → On leur doit rembourser
    for (final flot in allFlots) {
      if (flot.shopDestinationId == shopId &&
          flot.statut == OperationStatus.validee &&
          flot.devise == 'USD') {
        final autreShopId = flot.shopSourceId;
        if (autreShopId != null && autreShopId != shopId) {
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
          debugPrint('   FLOT SERVI reçu DE Shop $autreShopId: On leur doit -${flot.montantNet} USD');
        }
      }
    }
    
    // 5. FLOTS ENVOYÉS ET SERVIS (shopSourceId = nous) → Ils Nous qui Doivent rembourser
    for (final flot in allFlots) {
      if (flot.shopSourceId == shopId &&
          flot.statut == OperationStatus.validee &&
          flot.devise == 'USD') {
        final autreShopId = flot.shopDestinationId;
        if (autreShopId != null && autreShopId != shopId) {
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
          debugPrint('   FLOT SERVI envoyé À Shop $autreShopId: Ils Nous qui Doivent +${flot.montantNet} USD');
        }
      }
    }
    
    // Séparer en créances (solde > 0) et dettes (solde < 0)
    final shopsNousDoivent = <CompteShopResume>[];
    final shopsNousDevons = <CompteShopResume>[];
    
    for (final entry in soldesParShop.entries) {
      final autreShopId = entry.key;
      final solde = entry.value;
      final shop = shopsMap[autreShopId];
      
      if (shop == null) continue;
      
      if (solde > 0) {
        // Ils Nous qui Doivent (créance)
        shopsNousDoivent.add(CompteShopResume(
          shopId: autreShopId,
          designation: shop.designation,
          localisation: shop.localisation,
          montant: solde,
        ));
        debugPrint('   ✅ CRÉANCE: ${shop.designation} nous doit ${solde.toStringAsFixed(2)} USD');
      } else if (solde < 0) {
        // On leur doit (dette)
        shopsNousDevons.add(CompteShopResume(
          shopId: autreShopId,
          designation: shop.designation,
          localisation: shop.localisation,
          montant: solde.abs(),
        ));
        debugPrint('   ❌ DETTE: On doit à ${shop.designation} ${solde.abs().toStringAsFixed(2)} USD');
      }
    }
    
    final totalCreances = shopsNousDoivent.fold(0.0, (sum, shop) => sum + shop.montant);
    final totalDettes = shopsNousDevons.fold(0.0, (sum, shop) => sum + shop.montant);
    
    debugPrint('📊 RÉSUMÉ INTER-SHOPS:');
    debugPrint('   Total créances (ils Nous qui Doivent): ${totalCreances.toStringAsFixed(2)} USD');
    debugPrint('   Total dettes (on leur doit): ${totalDettes.toStringAsFixed(2)} USD');
    debugPrint('   Solde net: ${(totalCreances - totalDettes).toStringAsFixed(2)} USD');
    debugPrint('📊 === FIN CALCUL DETTES/CRÉANCES ===');
    
    return {
      'nousDoivent': shopsNousDoivent,
      'nousDevons': shopsNousDevons,
    };
  }

  /// Calculer les comptes spéciaux (FRAIS et DÉPENSE)
  /// IMPORTANT: Les frais affichés sont UNIQUEMENT les frais encaissés sur les transferts que nous avons servis
  Future<Map<String, dynamic>> _calculerComptesSpeciaux(int shopId, DateTime dateRapport, List<OperationModel>? providedOperations) async {
    final service = CompteSpecialService.instance;
    await service.loadTransactions(shopId: shopId);
    
    // Début de la journée
    final startOfDay = DateTime(dateRapport.year, dateRapport.month, dateRapport.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    
    // Récupérer les transactions du jour
    final fraisDuJour = service.getFrais(
      shopId: shopId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
    
    final depensesDuJour = service.getDepenses(
      shopId: shopId,
      startDate: startOfDay,
      endDate: endOfDay,
    );
    
    // Calculer les RETRAITS FRAIS du jour (montants négatifs)
    final retraitsFraisList = fraisDuJour
        .where((t) => t.typeTransaction == TypeTransactionCompte.RETRAIT)
        .toList();
    final retraitsFrais = retraitsFraisList.fold(0.0, (sum, t) => sum + t.montant.abs());
    
    // NOUVELLE LOGIQUE: Calculer les FRAIS ENCAISSÉS sur TOUS les transferts qui passent par le shop
    // Les frais peuvent appartenir au shop selon deux cas:
    // 1. Le shop est la DESTINATION (il sert le transfert) - frais gagnés
    // 2. Le shop est la SOURCE (il initie le transfert) - frais payés mais comptabilisés
    final operations = providedOperations ?? await LocalDB.instance.getAllOperations();
    
    // Récupérer tous les shops pour afficher leurs noms dans les logs
    final shops = await LocalDB.instance.getAllShops();
    final shopsMap = {for (var shop in shops) shop.id: shop.designation};
    
    // Transferts SERVIS par le shop (où le shop est DESTINATION) - frais gagnés
    final transfertsServis = operations.where((op) =>
        op.shopDestinationId == shopId && // Nous sommes le shop destination
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant ||
         op.type == OperationType.transfertInternationalSortant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.dateValidation ?? op.createdAt ?? op.dateOp, dateRapport)
    ).toList();
    
    // Transferts INITIÉS par le shop (où le shop est SOURCE) - frais payés mais comptabilisés
    final transfertsInities = operations.where((op) =>
        op.shopSourceId == shopId && // Nous sommes le shop source
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalSortant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.dateValidation ?? op.createdAt ?? op.dateOp, dateRapport)
    ).toList();
    
    // Total des frais encaissés = somme des commissions sur tous les transferts liés au shop
    final fraisEncaissesServis = transfertsServis.fold(0.0, (sum, op) => sum + op.commission);
    final fraisEncaissesInities = transfertsInities.fold(0.0, (sum, op) => sum + op.commission);
    final fraisEncaisses = fraisEncaissesServis + fraisEncaissesInities;
    
    // Grouper les frais par shop source (qui a envoyé le transfert)
    final Map<String, double> fraisGroupesParShop = {};
    
    // Ajouter les frais des transferts servis
    for (final op in transfertsServis) {
      final shopSource = shopsMap[op.shopSourceId] ?? 'Shop ${op.shopSourceId}';
      fraisGroupesParShop[shopSource] = (fraisGroupesParShop[shopSource] ?? 0.0) + op.commission;
    }
    
    // Ajouter les frais des transferts initiés (le shop lui-même est la source)
    for (final op in transfertsInities) {
      final shopDest = shopsMap[op.shopDestinationId] ?? 'Shop ${op.shopDestinationId}';
      fraisGroupesParShop[shopDest] = (fraisGroupesParShop[shopDest] ?? 0.0) + op.commission;
    }
    
    debugPrint('📊 FRAIS ENCAISSÉS SUR TOUS LES TRANSFERTS LIÉS AU SHOP:');
    debugPrint('   Nombre de transferts servis: ${transfertsServis.length} (frais gagnés: ${fraisEncaissesServis.toStringAsFixed(2)} USD)');
    debugPrint('   Nombre de transferts initiés: ${transfertsInities.length} (frais payés: ${fraisEncaissesInities.toStringAsFixed(2)} USD)');
    debugPrint('   Total frais encaissés: ${fraisEncaisses.toStringAsFixed(2)} USD');
    debugPrint('   Frais groupés par shop:');
    fraisGroupesParShop.forEach((shop, montant) {
      debugPrint('     - $shop : ${montant.toStringAsFixed(2)} USD');
    });
    
    transfertsServis.forEach((op) {
      final shopSource = shopsMap[op.shopSourceId] ?? 'Shop ${op.shopSourceId}';
      final shopDest = shopsMap[op.shopDestinationId] ?? 'Shop ${op.shopDestinationId}';
      final destinataire = op.destinataire ?? 'N/A';
      debugPrint('     - SERVI: $shopSource → $shopDest, $destinataire : ${op.montantNet.toStringAsFixed(2)} USD (Frais: ${op.commission.toStringAsFixed(2)} USD)');
    });
    
    transfertsInities.forEach((op) {
      final shopSource = shopsMap[op.shopSourceId] ?? 'Shop ${op.shopSourceId}';
      final shopDest = shopsMap[op.shopDestinationId] ?? 'Shop ${op.shopDestinationId}';
      final destinataire = op.destinataire ?? 'N/A';
      debugPrint('     - INITIÉ: $shopSource → $shopDest, $destinataire : ${op.montantNet.toStringAsFixed(2)} USD (Frais: ${op.commission.toStringAsFixed(2)} USD)');
    });    
    debugPrint('📊 RETRAITS SUR FRAIS DU JOUR:');
    debugPrint('   Nombre de retraits: ${retraitsFraisList.length}');
    debugPrint('   Total retraits: ${retraitsFrais.toStringAsFixed(2)} USD');
    retraitsFraisList.forEach((r) {
      debugPrint('     - ${r.description} : ${r.montant.abs().toStringAsFixed(2)} USD');
    });
    
    // Calculer les SORTIES DÉPENSE du jour (montants négatifs)
    final sortiesDepense = depensesDuJour
        .where((t) => t.typeTransaction == TypeTransactionCompte.SORTIE)
        .fold(0.0, (sum, t) => sum + t.montant.abs());
    
    // Calculer les DÉPÔTS DÉPENSE du jour (montants positifs)
    final depotsDepense = depensesDuJour
        .where((t) => t.typeTransaction == TypeTransactionCompte.DEPOT)
        .fold(0.0, (sum, t) => sum + t.montant);
    
    // Soldes globaux (tout l'historique)
    final soldeFraisTotal = service.getSoldeFrais(shopId: shopId);
    final soldeDepenseTotal = service.getSoldeDepense(shopId: shopId);
    
    debugPrint('📊 COMPTES SPÉCIAUX - ${dateRapport.toIso8601String().split('T')[0]}:');
    debugPrint('   FRAIS: Frais encaissés (tous transferts) = ${fraisEncaisses.toStringAsFixed(2)} USD');
    debugPrint('   FRAIS: Retraits du jour = ${retraitsFrais.toStringAsFixed(2)} USD');
    debugPrint('   FRAIS: Solde total = ${soldeFraisTotal.toStringAsFixed(2)} USD');    debugPrint('   DÉPENSE: Dépôts du jour = ${depotsDepense.toStringAsFixed(2)} USD');
    debugPrint('   DÉPENSE: Sorties du jour = ${sortiesDepense.toStringAsFixed(2)} USD');
    debugPrint('   DÉPENSE: Solde total = ${soldeDepenseTotal.toStringAsFixed(2)} USD');
    
    return {
      'retraits_frais': retraitsFrais,
      'commissions_frais': fraisEncaisses, // MODIFIÉ: Utiliser les frais encaissés calculés
      'frais_groupes_par_shop': fraisGroupesParShop, // NOUVEAU: Frais groupés par shop
      'solde_frais_total': soldeFraisTotal,
      'sorties_depense': sortiesDepense,
      'depots_depense': depotsDepense,
      'solde_depense_total': soldeDepenseTotal,
    };
  }

  /// Calculer les transferts groupés par route
  Future<List<TransfertRouteResume>> _calculerTransfertsGroupes(int shopId, DateTime dateRapport, List<OperationModel>? providedOperations) async {
    // Utiliser les opérations fournies (de "Mes Ops") ou charger depuis LocalDB
    final operations = providedOperations ?? await LocalDB.instance.getAllOperations();
    
    // Récupérer tous les shops pour obtenir leurs désignations
    final allShops = await LocalDB.instance.getAllShops();
    
    // Filtrer les transferts reçus (validees) pour le shop courant - utilise dateValidation si disponible, sinon createdAt
    final transfertsRecus = operations.where((op) =>
        op.shopDestinationId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant ||
         op.type == OperationType.transfertInternationalSortant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.dateValidation ?? op.createdAt ?? op.dateOp, dateRapport)
    ).toList();

    // Filtrer les transferts servis (validees) par le shop courant - utilise dateValidation si disponible, sinon createdAt
    final transfertsServis = operations.where((op) =>
        op.shopSourceId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalSortant ||
         op.type == OperationType.transfertInternationalEntrant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.dateValidation ?? op.createdAt ?? op.dateOp, dateRapport)
    ).toList();

    // Filtrer les transferts en attente pour le shop courant
    final transfertsEnAttente = operations.where((op) =>
        (op.shopDestinationId == shopId || op.shopSourceId == shopId) &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant ||
         op.type == OperationType.transfertInternationalSortant) &&
        op.statut == OperationStatus.enAttente
    ).toList();

    // Grouper par route (source -> destination)
    final Map<String, List<OperationModel>> transfertsParRoute = {};
    
    // Regrouper toutes les opérations par route
    final allTransferts = [...transfertsRecus, ...transfertsServis, ...transfertsEnAttente];
    for (final op in allTransferts) {
      final sourceId = op.shopSourceId ?? 0;
      final destId = op.shopDestinationId ?? 0;
      final routeKey = '$sourceId->$destId';
      
      if (!transfertsParRoute.containsKey(routeKey)) {
        transfertsParRoute[routeKey] = [];
      }
      transfertsParRoute[routeKey]!.add(op);
    }

    // Créer les résumés par route
    final List<TransfertRouteResume> result = [];
    
    for (final entry in transfertsParRoute.entries) {
      final routeParts = entry.key.split('->');
      final sourceId = int.tryParse(routeParts[0]) ?? 0;
      final destId = int.tryParse(routeParts[1]) ?? 0;
      
      final sourceShop = allShops.firstWhere((s) => s.id == sourceId, orElse: () => ShopModel(id: sourceId, designation: 'Shop $sourceId', localisation: ''));
      final destShop = allShops.firstWhere((s) => s.id == destId, orElse: () => ShopModel(id: destId, designation: 'Shop $destId', localisation: ''));
      
      // Compter et totaliser par type
      int transfertsCount = 0;
      int servisCount = 0;
      int enAttenteCount = 0;
      double transfertsTotal = 0.0;
      double servisTotal = 0.0;
      double enAttenteTotal = 0.0;
      
      for (final op in entry.value) {
        if (op.statut == OperationStatus.enAttente) {
          enAttenteCount++;
          enAttenteTotal += op.montantNet;
        } else if (op.statut == OperationStatus.validee) {
          if (op.shopSourceId == shopId) {
            servisCount++;
            servisTotal += op.montantNet;
          } else if (op.shopDestinationId == shopId) {
            transfertsCount++;
            transfertsTotal += op.montantNet;
          }
        }
      }
      
      result.add(TransfertRouteResume(
        shopSourceDesignation: sourceShop.designation,
        shopDestinationDesignation: destShop.designation,
        transfertsCount: transfertsCount,
        servisCount: servisCount,
        enAttenteCount: enAttenteCount,
        transfertsTotal: transfertsTotal,
        servisTotal: servisTotal,
        enAttenteTotal: enAttenteTotal,
      ));
    }
    
    return result;
  }

  /// Calculer le cash disponible par mode de paiement
  /// FORMULE: Cash Disponible = (Solde Antérieur + Dépôts + FLOT Reçu + Transfert Reçu) - (Retraits + FLOT Envoyé + Transfert Servi + Retraits FRAIS)
  Map<String, double> _calculerCashDisponible({
    required ShopModel shop,
    required Map<String, double> soldeAnterieur,
    required Map<String, double> flots,
    required Map<String, double> transferts,
    required Map<String, double> operationsClients,
    double retraitsFrais = 0.0, // NOUVEAU: Retraits FRAIS du jour
  }) {
    // CALCUL RÉEL avec la formule exacte:
    // Cash Disponible = (Solde Antérieur + Dépôts + FLOT Reçu + Transfert Reçu) - (Retraits + FLOT Envoyé + Transfert Servi + Retraits FRAIS)
    
    // ATTENTION: Pour le moment, nous ne pouvons pas séparer par mode de paiement car les flots et transferts
    // ne sont pas détaillés par mode de paiement. Nous calculons donc le TOTAL uniquement.
    
    final soldeAnterieurTotal = soldeAnterieur['cash']! + 
                                 soldeAnterieur['airtelMoney']! + 
                                 soldeAnterieur['mPesa']! + 
                                 soldeAnterieur['orangeMoney']!;
    
    final depots = operationsClients['depots']!;
    final retraits = operationsClients['retraits']!;
    final flotRecu = flots['recu']!;      // FLOTs vers nous (ENTRÉE)
    final flotEnvoye = flots['envoye']!;  // FLOTs par nous (SORTIE)
    final transfertRecu = transferts['recus']!;   // Client nous paie (ENTRÉE)
    final transfertServi = transferts['servis']!; // On sert le client (SORTIE)
    
    // Appliquer la formule AVEC retraits FRAIS
    final totalDisponible = (soldeAnterieurTotal + depots + flotRecu + transfertRecu) 
                          - (retraits + flotEnvoye + transfertServi + retraitsFrais); // NOUVEAU: - retraitsFrais
    
    // Répartition proportionnelle du total calculé selon les capitaux actuels du shop
    // Cela nous permet d'avoir une estimation par mode de paiement
    final totalCapital = shop.capitalCash + shop.capitalAirtelMoney + shop.capitalMPesa + shop.capitalOrangeMoney;
    
    double cashDisponible, airtelMoneyDisponible, mPesaDisponible, orangeMoneyDisponible;
    
    if (totalCapital > 0) {
      // Répartition proportionnelle
      final ratioCash = shop.capitalCash / totalCapital;
      final ratioAirtel = shop.capitalAirtelMoney / totalCapital;
      final ratioMPesa = shop.capitalMPesa / totalCapital;
      final ratioOrange = shop.capitalOrangeMoney / totalCapital;
      
      cashDisponible = totalDisponible * ratioCash;
      airtelMoneyDisponible = totalDisponible * ratioAirtel;
      mPesaDisponible = totalDisponible * ratioMPesa;
      orangeMoneyDisponible = totalDisponible * ratioOrange;
    } else {
      // Si pas de capital, tout va en cash
      cashDisponible = totalDisponible;
      airtelMoneyDisponible = 0;
      mPesaDisponible = 0;
      orangeMoneyDisponible = 0;
    }

    debugPrint('💰 CASH DISPONIBLE - CALCUL AVEC FORMULE:');
    debugPrint('   Solde Antérieur: ${soldeAnterieurTotal.toStringAsFixed(2)} USD');
    debugPrint('   + Dépôts: ${depots.toStringAsFixed(2)} USD');
    debugPrint('   + FLOT Reçu: ${flotRecu.toStringAsFixed(2)} USD');
    debugPrint('   + Transferts: ${transfertRecu.toStringAsFixed(2)} USD');
    debugPrint('   - Retraits: ${retraits.toStringAsFixed(2)} USD');
    debugPrint('   - FLOT Envoyé: ${flotEnvoye.toStringAsFixed(2)} USD');
    debugPrint('   - Transfert Servi: ${transfertServi.toStringAsFixed(2)} USD');
    debugPrint('   - Retraits FRAIS: ${retraitsFrais.toStringAsFixed(2)} USD');  // NOUVEAU
    debugPrint('   = TOTAL CALCULÉ: ${totalDisponible.toStringAsFixed(2)} USD');
    debugPrint('   ');
    debugPrint('   Répartition par mode (proportionnelle):');
    debugPrint('   Cash: ${cashDisponible.toStringAsFixed(2)} USD');
    debugPrint('   Airtel Money: ${airtelMoneyDisponible.toStringAsFixed(2)} USD');
    debugPrint('   M-Pesa: ${mPesaDisponible.toStringAsFixed(2)} USD');
    debugPrint('   Orange Money: ${orangeMoneyDisponible.toStringAsFixed(2)} USD');
    debugPrint('   TOTAL: ${(cashDisponible + airtelMoneyDisponible + mPesaDisponible + orangeMoneyDisponible).toStringAsFixed(2)} USD');

    return {
      'cash': cashDisponible,
      'airtelMoney': airtelMoneyDisponible,
      'mPesa': mPesaDisponible,
      'orangeMoney': orangeMoneyDisponible,
      'total': totalDisponible,
    };
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  /// Enregistrer la clôture de caisse pour la journée
  /// Cette clôture sera utilisée comme solde d'ouverture (solde antérieur) pour le lendemain
  Future<void> cloturerJournee({
    required int shopId,
    required DateTime dateCloture,
    required String cloturePar,
    required double soldeSaisiCash,
    required double soldeSaisiAirtelMoney,
    required double soldeSaisiMPesa,
    required double soldeSaisiOrangeMoney,
    String? notes,
  }) async {
    try {
      // Vérifier si une clôture existe déjà pour cette date
      final clotureExistante = await LocalDB.instance.getClotureCaisseByDate(shopId, dateCloture);
      
      if (clotureExistante != null) {
        debugPrint('⚠️ Une clôture existe déjà pour le ${dateCloture.toIso8601String().split('T')[0]}');
        throw Exception('Une clôture existe déjà pour cette date');
      }

      // Générer le rapport pour obtenir les montants CALCULÉS avec la formule
      final rapport = await genererRapport(
        shopId: shopId,
        date: dateCloture,
        generePar: cloturePar,
      );

      // Montants CALCULÉS par le système (avec la formule)
      final soldeCalculeCash = rapport.cashDisponibleCash;
      final soldeCalculeAirtelMoney = rapport.cashDisponibleAirtelMoney;
      final soldeCalculeMPesa = rapport.cashDisponibleMPesa;
      final soldeCalculeOrangeMoney = rapport.cashDisponibleOrangeMoney;
      final soldeCalculeTotal = rapport.cashDisponibleTotal;
      
      // Montants SAISIS par l'agent
      final soldeSaisiTotal = soldeSaisiCash + soldeSaisiAirtelMoney + soldeSaisiMPesa + soldeSaisiOrangeMoney;
      
      // Calcul des ÉCARTS (Saisi - Calculé)
      final ecartCash = soldeSaisiCash - soldeCalculeCash;
      final ecartAirtelMoney = soldeSaisiAirtelMoney - soldeCalculeAirtelMoney;
      final ecartMPesa = soldeSaisiMPesa - soldeCalculeMPesa;
      final ecartOrangeMoney = soldeSaisiOrangeMoney - soldeCalculeOrangeMoney;
      final ecartTotal = soldeSaisiTotal - soldeCalculeTotal;
      
      // NOUVEAU: Calculer le Solde FRAIS du jour selon la formule:
      // Solde Frais = Frais Antérieur + Frais encaissés du jour - Sortie Frais du jour
      final soldeFraisAnterieur = rapport.soldeFraisAnterieur;
      final fraisEncaisses = rapport.commissionsFraisDuJour;
      final sortieFrais = rapport.retraitsFraisDuJour;
      final soldeFraisDuJour = soldeFraisAnterieur + fraisEncaisses - sortieFrais;
      
      debugPrint('💰 Calcul Solde FRAIS du jour:');
      debugPrint('   Frais Antérieur: ${soldeFraisAnterieur.toStringAsFixed(2)} USD');
      debugPrint('   + Frais encaissés: ${fraisEncaisses.toStringAsFixed(2)} USD');
      debugPrint('   - Sortie Frais: ${sortieFrais.toStringAsFixed(2)} USD');
      debugPrint('   = Solde Frais du jour: ${soldeFraisDuJour.toStringAsFixed(2)} USD');
      
      final cloture = ClotureCaisseModel(
        shopId: shopId,
        dateCloture: DateTime(dateCloture.year, dateCloture.month, dateCloture.day), // Normaliser à minuit
        soldeFraisAnterieur: soldeFraisDuJour, // ENREGISTRER le Solde Frais calculé du jour
        
        // Montants saisis
        soldeSaisiCash: soldeSaisiCash,
        soldeSaisiAirtelMoney: soldeSaisiAirtelMoney,
        soldeSaisiMPesa: soldeSaisiMPesa,
        soldeSaisiOrangeMoney: soldeSaisiOrangeMoney,
        soldeSaisiTotal: soldeSaisiTotal,
        
        // Montants calculés
        soldeCalculeCash: soldeCalculeCash,
        soldeCalculeAirtelMoney: soldeCalculeAirtelMoney,
        soldeCalculeMPesa: soldeCalculeMPesa,
        soldeCalculeOrangeMoney: soldeCalculeOrangeMoney,
        soldeCalculeTotal: soldeCalculeTotal,
        
        // Écarts
        ecartCash: ecartCash,
        ecartAirtelMoney: ecartAirtelMoney,
        ecartMPesa: ecartMPesa,
        ecartOrangeMoney: ecartOrangeMoney,
        ecartTotal: ecartTotal,
        
        cloturePar: cloturePar,
        dateEnregistrement: DateTime.now(),
        notes: notes,
      );

      // Sauvegarder la clôture
      await LocalDB.instance.saveClotureCaisse(cloture);
      
      debugPrint('✅ Journée clôturée avec succès pour le ${dateCloture.toIso8601String().split('T')[0]}');
      debugPrint('   Solde Saisi: ${soldeSaisiTotal.toStringAsFixed(2)} USD');
      debugPrint('   Solde Calculé: ${soldeCalculeTotal.toStringAsFixed(2)} USD');
      debugPrint('   Écart: ${ecartTotal.toStringAsFixed(2)} USD');
      debugPrint('   Solde FRAIS enregistré: ${soldeFraisDuJour.toStringAsFixed(2)} USD');
    } catch (e) {
      debugPrint('❌ Erreur lors de la clôture de journée: $e');
      rethrow;
    }
  }

  /// Vérifier si la journée a déjà été clôturée
  Future<bool> journeeEstCloturee(int shopId, DateTime date) async {
    try {
      final cloture = await LocalDB.instance.getClotureCaisseByDate(shopId, date);
      final estCloturee = cloture != null;
      debugPrint('🔎 Journée ${date.toIso8601String().split('T')[0]} pour shop $shopId: ${estCloturee ? "CLÔTURÉE ✅" : "NON CLÔTURÉE ⚠️"}');
      return estCloturee;
    } catch (e) {
      debugPrint('❌ Erreur vérification clôture journée: $e');
      return false; // En cas d'erreur, considérer comme non clôturée pour forcer la vérification
    }
  }

  /// Trouver le dernier jour ouvrable (excluant les dimanches)
  /// Si la date est un dimanche, retourne le samedi précédent
  DateTime getDernierJourOuvrable(DateTime date) {
    DateTime jourOuvrable = date;
    
    // Si c'est un dimanche (weekday = 7), reculer d'un jour
    while (jourOuvrable.weekday == DateTime.sunday) {
      jourOuvrable = jourOuvrable.subtract(const Duration(days: 1));
      debugPrint('⏪ Dimanche détecté, recul au ${jourOuvrable.toIso8601String().split('T')[0]}');
    }
    
    return jourOuvrable;
  }

  /// Vérifier si la journée précédente nécessite une clôture
  /// Retourne la date qui doit être clôturée, ou null si tout est à jour
  Future<DateTime?> verifierCloturePrecedente(int shopId, DateTime dateActuelle) async {
    try {
      // Obtenir la date d'hier (ou le dernier jour ouvrable si on est lundi)
      DateTime dateHier = dateActuelle.subtract(const Duration(days: 1));
      DateTime dernierJourOuvrable = getDernierJourOuvrable(dateHier);
      
      debugPrint('🔍 Vérification clôture pour Shop $shopId');
      debugPrint('   Date actuelle: ${dateActuelle.toIso8601String().split('T')[0]}');
      debugPrint('   Dernier jour ouvrable: ${dernierJourOuvrable.toIso8601String().split('T')[0]}');
      
      // Vérifier si le dernier jour ouvrable est clôturé
      final estCloturee = await journeeEstCloturee(shopId, dernierJourOuvrable);
      
      if (!estCloturee) {
        debugPrint('⚠️ Journée non clôturée détectée: ${dernierJourOuvrable.toIso8601String().split('T')[0]}');
        debugPrint('🔒 CLÔTURE OBLIGATOIRE REQUISE');
        return dernierJourOuvrable;
      }
      
      debugPrint('✅ Toutes les journées précédentes sont clôturées');
      return null;
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur vérification clôture précédente: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      // En cas d'erreur, retourner la date précédente pour forcer une vérification manuelle
      DateTime dateHier = dateActuelle.subtract(const Duration(days: 1));
      DateTime dernierJourOuvrable = getDernierJourOuvrable(dateHier);
      debugPrint('⚠️ En cas d\'erreur, demande de clôture pour: ${dernierJourOuvrable.toIso8601String().split('T')[0]}');
      return dernierJourOuvrable;
    }
  }

  /// Récupérer la dernière clôture de caisse d'un shop
  Future<ClotureCaisseModel?> getDerniereCloture(int shopId) async {
    try {
      final clotures = await LocalDB.instance.getCloturesCaisseByShop(shopId);
      if (clotures.isEmpty) {
        debugPrint('ℹ️ Aucune clôture trouvée pour shop $shopId');
        return null;
      }
      // La liste est déjà triée par date décroissante
      final derniereCloture = clotures.first;
      debugPrint('📋 Dernière clôture trouvée: ${derniereCloture.dateCloture.toIso8601String().split('T')[0]}');
      return derniereCloture;
    } catch (e) {
      debugPrint('❌ Erreur récupération dernière clôture: $e');
      return null;
    }
  }

  /// Trouver TOUS les jours non clôturés depuis la dernière clôture jusqu'à hier
  /// Retourne une liste de dates qui doivent être clôturées (ordre chronologique)
  /// Si aucune clôture n'existe, retourne une liste vide (premier jour d'utilisation)
  Future<List<DateTime>> getJoursNonClotures(int shopId, {int maxJours = 30}) async {
    try {
      final List<DateTime> joursNonClotures = [];
      final aujourdhui = DateTime.now();
      final dateAujourdhui = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
      final dateHier = dateAujourdhui.subtract(const Duration(days: 1));
      
      // Récupérer la dernière clôture
      final derniereCloture = await getDerniereCloture(shopId);
      
      // Si aucune clôture n'existe, c'est le premier jour - pas besoin de clôturer
      if (derniereCloture == null) {
        debugPrint('ℹ️ Aucune clôture précédente - premier jour d\'utilisation');
        return [];
      }
      
      // Date de début de recherche = lendemain de la dernière clôture
      DateTime dateDebut = DateTime(
        derniereCloture.dateCloture.year,
        derniereCloture.dateCloture.month,
        derniereCloture.dateCloture.day,
      ).add(const Duration(days: 1));
      
      debugPrint('🔍 Recherche jours non clôturés pour Shop $shopId');
      debugPrint('   Dernière clôture: ${derniereCloture.dateCloture.toIso8601String().split('T')[0]}');
      debugPrint('   Recherche du: ${dateDebut.toIso8601String().split('T')[0]} au ${dateHier.toIso8601String().split('T')[0]}');
      
      // Parcourir chaque jour depuis le lendemain de la dernière clôture jusqu'à hier
      DateTime dateCourante = dateDebut;
      int compteur = 0;
      
      while (!dateCourante.isAfter(dateHier) && compteur < maxJours) {
        // Ignorer les dimanches (jour de repos)
        if (dateCourante.weekday != DateTime.sunday) {
          // Vérifier si ce jour est clôturé
          final estCloturee = await journeeEstCloturee(shopId, dateCourante);
          if (!estCloturee) {
            joursNonClotures.add(dateCourante);
            debugPrint('   ❌ Jour non clôturé: ${dateCourante.toIso8601String().split('T')[0]}');
          }
        } else {
          debugPrint('   ⏭️ Dimanche ignoré: ${dateCourante.toIso8601String().split('T')[0]}');
        }
        
        dateCourante = dateCourante.add(const Duration(days: 1));
        compteur++;
      }
      
      debugPrint('📊 ${joursNonClotures.length} jour(s) non clôturé(s) trouvé(s)');
      return joursNonClotures;
    } catch (e) {
      debugPrint('❌ Erreur recherche jours non clôturés: $e');
      return [];
    }
  }

  /// Clôturer plusieurs jours avec les mêmes montants
  /// Utilisé pour rattraper les jours non clôturés
  Future<bool> cloturerPlusieursJours({
    required int shopId,
    required List<DateTime> dates,
    required double soldeSaisiCash,
    required double soldeSaisiAirtelMoney,
    required double soldeSaisiMPesa,
    required double soldeSaisiOrangeMoney,
    required String cloturePar,
  }) async {
    try {
      debugPrint('🔒 Clôture en masse de ${dates.length} jour(s) pour Shop $shopId');
      
      // Trier les dates par ordre chronologique
      final datesTriees = List<DateTime>.from(dates);
      datesTriees.sort((a, b) => a.compareTo(b));
      
      for (final date in datesTriees) {
        debugPrint('   📅 Clôture du ${date.toIso8601String().split('T')[0]}...');
        
        await cloturerJournee(
          shopId: shopId,
          dateCloture: date,
          cloturePar: cloturePar,
          soldeSaisiCash: soldeSaisiCash,
          soldeSaisiAirtelMoney: soldeSaisiAirtelMoney,
          soldeSaisiMPesa: soldeSaisiMPesa,
          soldeSaisiOrangeMoney: soldeSaisiOrangeMoney,
          notes: 'Clôture groupée - Rattrapage de jours non clôturés',
        );
        
        debugPrint('   ✅ Jour clôturé: ${date.toIso8601String().split('T')[0]}');
      }
      
      debugPrint('✅ Clôture en masse terminée avec succès');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur lors de la clôture en masse: $e');
      return false;
    }
  }

  /// Vérifier si l'agent peut accéder aux menus opérationnels
  /// (Operations, Validations, Flot)
  /// Retourne null si OK, ou les dates non clôturées si besoin de clôturer
  Future<List<DateTime>?> verifierAccesMenusAgent(int shopId) async {
    try {
      final aujourdhui = DateTime.now();
      final dateAujourdhui = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
      
      // Trouver le dernier jour ouvrable (hier, ou samedi si on est lundi)
      DateTime dateHier = dateAujourdhui.subtract(const Duration(days: 1));
      DateTime dernierJourOuvrable = getDernierJourOuvrable(dateHier);
      
      debugPrint('🔍 Vérification accès menus pour Shop $shopId');
      debugPrint('   Aujourd\'hui: ${dateAujourdhui.toIso8601String().split('T')[0]}');
      debugPrint('   Dernier jour ouvrable à vérifier: ${dernierJourOuvrable.toIso8601String().split('T')[0]}');
      
      // Vérifier directement si le dernier jour ouvrable est clôturé
      final clotureHier = await LocalDB.instance.getClotureCaisseByDate(shopId, dernierJourOuvrable);
      
      if (clotureHier != null) {
        debugPrint('✅ Clôture trouvée pour ${dernierJourOuvrable.toIso8601String().split('T')[0]} - accès autorisé');
        debugPrint('   ID Clôture: ${clotureHier.id}');
        debugPrint('   Date clôture: ${clotureHier.dateCloture.toIso8601String()}');
        return null; // Accès autorisé
      }
      
      // Le dernier jour ouvrable n'est pas clôturé - rechercher tous les jours non clôturés
      debugPrint('⚠️ Pas de clôture pour ${dernierJourOuvrable.toIso8601String().split('T')[0]}');
      
      final joursNonClotures = await getJoursNonClotures(shopId);
      
      if (joursNonClotures.isEmpty) {
        // Aucune clôture précédente - premier jour d'utilisation, autoriser
        debugPrint('✅ Premier jour d\'utilisation - accès autorisé');
        return null;
      }
      
      debugPrint('⚠️ Accès menus bloqué - ${joursNonClotures.length} jour(s) à clôturer');
      return joursNonClotures;
    } catch (e) {
      debugPrint('❌ Erreur vérification accès menus: $e');
      // En cas d'erreur, permettre l'accès pour ne pas bloquer l'agent
      return null;
    }
  }
}
