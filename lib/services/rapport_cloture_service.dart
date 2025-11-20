import 'package:flutter/foundation.dart';
import '../models/rapport_cloture_model.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/cloture_caisse_model.dart';
import 'local_db.dart';
import 'flot_service.dart';

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

      // 7. Calculer le cash disponible par mode de paiement
      final cashDisponible = _calculerCashDisponible(
        shop: shop,
        soldeAnterieur: soldeAnterieur,
        flots: {
          'recu': flots['recu'] as double,
          'envoye': flots['envoye'] as double,
        },
        transferts: transferts,
        operationsClients: {
          'depots': operationsClients['depots'] as double,
          'retraits': operationsClients['retraits'] as double,
        },
      );

      // Calculate capital net according to the formula:
      // CAPITAL NET = CASH DISPONIBLE + PERSONNE QUI NOUS DOIVENT - CEUX QUE NOUS DEVONS
      final totalClientsNousDoivent = comptesClients['nousDoivent']!
          .fold(0.0, (sum, client) => sum + client.solde.abs());
      final totalClientsNousDevons = comptesClients['nousDevons']!
          .fold(0.0, (sum, client) => sum + client.solde);
      final totalShopsNousDoivent = comptesShops['nousDoivent']!
          .fold(0.0, (sum, shop) => sum + shop.montant);
      final totalShopsNousDevons = comptesShops['nousDevons']!
          .fold(0.0, (sum, shop) => sum + shop.montant);
      
      final capitalNet = cashDisponible['total']! + totalClientsNousDoivent + totalShopsNousDoivent - totalClientsNousDevons - totalShopsNousDevons;

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
        
        // Clients
        depotsClients: operationsClients['depots']!,
        retraitsClients: operationsClients['retraits']!,
        
        // Comptes clients
        clientsNousDoivent: comptesClients['nousDoivent']!,
        clientsNousDevons: comptesClients['nousDevons']!,
        
        // Comptes inter-shops
        shopsNousDoivent: comptesShops['nousDoivent']!,
        shopsNousDevons: comptesShops['nousDevons']!,
        
        // NOUVEAU: Listes détaillées des FLOT
        flotsRecusDetails: flots['flotsRecusDetails'] as List<FlotResume>,
        flotsEnvoyes: flots['flotsEnvoyesDetails'] as List<FlotResume>,
        
        // NOUVEAU: Listes détaillées des opérations clients
        depotsClientsDetails: operationsClients['depotsDetails'] as List<OperationResume>,
        retraitsClientsDetails: operationsClients['retraitsDetails'] as List<OperationResume>,
        
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
  Future<Map<String, double>> _getSoldeAnterieur(int shopId, DateTime dateRapport) async {
    // Récupérer la clôture du jour précédent
    final jourPrecedent = dateRapport.subtract(const Duration(days: 1));
    final cloturePrecedente = await LocalDB.instance.getClotureCaisseByDate(shopId, jourPrecedent);
    
    if (cloturePrecedente != null) {
      debugPrint('📋 Solde antérieur trouvé (clôture du ${jourPrecedent.toIso8601String().split('T')[0]}):');
      debugPrint('   Cash SAISI: ${cloturePrecedente.soldeSaisiCash} USD (Calculé: ${cloturePrecedente.soldeCalculeCash})');
      debugPrint('   Airtel Money SAISI: ${cloturePrecedente.soldeSaisiAirtelMoney} USD (Calculé: ${cloturePrecedente.soldeCalculeAirtelMoney})');
      debugPrint('   M-Pesa SAISI: ${cloturePrecedente.soldeSaisiMPesa} USD (Calculé: ${cloturePrecedente.soldeCalculeMPesa})');
      debugPrint('   Orange Money SAISI: ${cloturePrecedente.soldeSaisiOrangeMoney} USD (Calculé: ${cloturePrecedente.soldeCalculeOrangeMoney})');
      debugPrint('   TOTAL SAISI: ${cloturePrecedente.soldeSaisiTotal} USD (Calculé: ${cloturePrecedente.soldeCalculeTotal})');
      debugPrint('   ÉCART TOTAL: ${cloturePrecedente.ecartTotal} USD');
      
      // Utiliser les montants SAISIS comme solde antérieur (ce que l'agent a compté)
      return {
        'cash': cloturePrecedente.soldeSaisiCash,
        'airtelMoney': cloturePrecedente.soldeSaisiAirtelMoney,
        'mPesa': cloturePrecedente.soldeSaisiMPesa,
        'orangeMoney': cloturePrecedente.soldeSaisiOrangeMoney,
      };
    }
    
    // Si aucune clôture précédente, retourner 0 (premier jour d'utilisation)
    debugPrint('ℹ️ Aucun solde antérieur (pas de clôture du jour précédent)');
    return {
      'cash': 0.0,
      'airtelMoney': 0.0,
      'mPesa': 0.0,
      'orangeMoney': 0.0,
    };
  }

  /// Calculer les flots (reçus, en cours, servis) + LISTES DÉTAILLÉES
  Future<Map<String, dynamic>> _calculerFlots(int shopId, DateTime dateRapport) async {
    final flotService = FlotService.instance;
    await flotService.loadFlots(shopId: shopId);

    // FLOT REÇUS = FLOTs vers nous (en cours + servis reçus aujourd'hui)
    final flotsRecusEnCours = flotService.getFlotsEnCours(shopId)
        .where((f) => f.shopDestinationId == shopId); // En cours vers nous
    final flotsRecusServis = flotService.flots.where((f) =>
        f.shopDestinationId == shopId &&
        f.statut == flot_model.StatutFlot.servi &&
        f.dateReception != null &&
        _isSameDay(f.dateReception!, dateRapport)
    );
    final flotsRecus = [...flotsRecusEnCours, ...flotsRecusServis];
    
    // FLOT ENVOYÉS = FLOTs par nous (en cours + servis envoyés aujourd'hui)
    final flotsEnvoyesEnCours = flotService.getFlotsEnCours(shopId)
        .where((f) => f.shopSourceId == shopId); // En cours de nous
    final flotsEnvoyesServis = flotService.flots.where((f) =>
        f.shopSourceId == shopId &&
        f.statut == flot_model.StatutFlot.servi &&
        f.dateReception != null &&
        _isSameDay(f.dateReception!, dateRapport)
    );
    final flotsEnvoyes = [...flotsEnvoyesEnCours, ...flotsEnvoyesServis];
    
    // Créer les listes détaillées pour affichage dans le rapport
    final flotsRecusDetails = flotsRecus.map((f) => FlotResume(
      flotId: f.id!,
      shopSourceDesignation: f.shopSourceDesignation,
      shopDestinationDesignation: f.shopDestinationDesignation,
      montant: f.montant,
      devise: f.devise,
      statut: f.statut.name,
      dateEnvoi: f.dateEnvoi,
      dateReception: f.dateReception,
      modePaiement: f.modePaiement.name,
    )).toList();
    
    final flotsEnvoyesDetails = flotsEnvoyes.map((f) => FlotResume(
      flotId: f.id!,
      shopSourceDesignation: f.shopSourceDesignation,
      shopDestinationDesignation: f.shopDestinationDesignation,
      montant: f.montant,
      devise: f.devise,
      statut: f.statut.name,
      dateEnvoi: f.dateEnvoi,
      dateReception: f.dateReception,
      modePaiement: f.modePaiement.name,
    )).toList();

    return {
      'recu': flotsRecus.fold(0.0, (sum, f) => sum + f.montant),     // ENTRÉE (+)
      'envoye': flotsEnvoyes.fold(0.0, (sum, f) => sum + f.montant), // SORTIE (-)
      'flotsRecusDetails': flotsRecusDetails,
      'flotsEnvoyesDetails': flotsEnvoyesDetails,
    };
  }

  /// Calculer les transferts (reçus et servis)
  Future<Map<String, double>> _calculerTransferts(int shopId, DateTime dateRapport, List<OperationModel>? providedOperations) async {
    // Utiliser les opérations fournies (de "Mes Ops") ou charger depuis LocalDB
    final operations = providedOperations ?? await LocalDB.instance.getAllOperations();
    
    // Transferts REÇUS = client nous paie (ENTRÉE d'argent)
    final transfertsRecus = operations.where((op) =>
        op.shopSourceId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalSortant) &&
        _isSameDay(op.dateOp, dateRapport)
    );

    // Transferts SERVIS = nous servons le client (SORTIE d'argent)
    final transfertsServis = operations.where((op) =>
        op.shopDestinationId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.lastModifiedAt ?? op.dateOp, dateRapport)
    );

    return {
      'recus': transfertsRecus.fold(0.0, (sum, op) => sum + op.montantBrut), // ENTRÉE: Client nous paie
      'servis': transfertsServis.fold(0.0, (sum, op) => sum + op.montantNet), // SORTIE: On sert le client
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
        op.type == OperationType.retrait &&
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
  /// - "Clients Nous Devons" = "Dépôts Partenaires" : Partenaires qui ont déposé dans leur compte durant le jour
  /// - "Clients Nous Doivent" = "Partenaires Servis" : Partenaires qui ont retiré de leur compte durant le jour
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
        op.type == OperationType.retrait &&
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
  /// - Transferts servis PAR nous → Ils nous doivent
  /// - Transferts servis PAR eux → On leur doit
  /// - FLOTs reçus DE eux → On leur doit rembourser
  /// - FLOTs envoyés À eux → Ils nous doivent rembourser
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
    for (final flot in flotService.flots) {
      if (flot.statut == flot_model.StatutFlot.enRoute && flot.devise == 'USD') {
        if (flot.shopSourceId == shopId) {
          // NOUS avons envoyé en cours → Ils nous doivent rembourser
          final autreShopId = flot.shopDestinationId;
          if (autreShopId != null && autreShopId != shopId) {
            soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montant;
            debugPrint('   FLOT EN COURS envoyé PAR nous à Shop $autreShopId: Ils nous doivent +${flot.montant} USD');
          }
        } else if (flot.shopDestinationId == shopId) {
          // ILS ont envoyé en cours → On leur doit rembourser
          final autreShopId = flot.shopSourceId;
          if (autreShopId != null && autreShopId != shopId) {
            soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montant;
            debugPrint('   FLOT EN COURS reçu DE Shop $autreShopId: On leur doit -${flot.montant} USD');
          }
        }
      }
    }
    
    // 4. FLOTS REÇUS ET SERVIS (shopDestinationId = nous) → On leur doit rembourser
    for (final flot in flotService.flots) {
      if (flot.shopDestinationId == shopId &&
          flot.statut == flot_model.StatutFlot.servi &&
          flot.devise == 'USD') {
        final autreShopId = flot.shopSourceId;
        if (autreShopId != null && autreShopId != shopId) {
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montant;
          debugPrint('   FLOT SERVI reçu DE Shop $autreShopId: On leur doit -${flot.montant} USD');
        }
      }
    }
    
    // 5. FLOTS ENVOYÉS ET SERVIS (shopSourceId = nous) → Ils nous doivent rembourser
    for (final flot in flotService.flots) {
      if (flot.shopSourceId == shopId &&
          flot.statut == flot_model.StatutFlot.servi &&
          flot.devise == 'USD') {
        final autreShopId = flot.shopDestinationId;
        if (autreShopId != null && autreShopId != shopId) {
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montant;
          debugPrint('   FLOT SERVI envoyé À Shop $autreShopId: Ils nous doivent +${flot.montant} USD');
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
        // Ils nous doivent (créance)
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
    debugPrint('   Total créances (ils nous doivent): ${totalCreances.toStringAsFixed(2)} USD');
    debugPrint('   Total dettes (on leur doit): ${totalDettes.toStringAsFixed(2)} USD');
    debugPrint('   Solde net: ${(totalCreances - totalDettes).toStringAsFixed(2)} USD');
    debugPrint('📊 === FIN CALCUL DETTES/CRÉANCES ===');
    
    return {
      'nousDoivent': shopsNousDoivent,
      'nousDevons': shopsNousDevons,
    };
  }

  /// Calculer le cash disponible par mode de paiement
  /// FORMULE: Cash Disponible = (Solde Antérieur + Dépôts + FLOT Reçu + Transfert Reçu) - (Retraits + FLOT Envoyé + Transfert Servi)
  Map<String, double> _calculerCashDisponible({
    required ShopModel shop,
    required Map<String, double> soldeAnterieur,
    required Map<String, double> flots,
    required Map<String, double> transferts,
    required Map<String, double> operationsClients,
  }) {
    // CALCUL RÉEL avec la formule exacte:
    // Cash Disponible = (Solde Antérieur + Dépôts + FLOT Reçu + Transfert Reçu) - (Retraits + FLOT Envoyé + Transfert Servi)
    
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
    
    // Appliquer la formule
    final totalDisponible = (soldeAnterieurTotal + depots + flotRecu + transfertRecu) 
                          - (retraits + flotEnvoye + transfertServi);
    
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
    debugPrint('   + Transfert Reçu: ${transfertRecu.toStringAsFixed(2)} USD');
    debugPrint('   - Retraits: ${retraits.toStringAsFixed(2)} USD');
    debugPrint('   - FLOT Envoyé: ${flotEnvoye.toStringAsFixed(2)} USD');
    debugPrint('   - Transfert Servi: ${transfertServi.toStringAsFixed(2)} USD');
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
      
      final cloture = ClotureCaisseModel(
        shopId: shopId,
        dateCloture: DateTime(dateCloture.year, dateCloture.month, dateCloture.day), // Normaliser à minuit
        
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
    } catch (e) {
      debugPrint('❌ Erreur lors de la clôture de journée: $e');
      rethrow;
    }
  }

  /// Vérifier si la journée a déjà été clôturée
  Future<bool> journeeEstCloturee(int shopId, DateTime date) async {
    return await LocalDB.instance.clotureExistsPourDate(shopId, date);
  }
}
