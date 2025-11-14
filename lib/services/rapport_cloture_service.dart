import 'package:flutter/foundation.dart';
import '../models/rapport_cloture_model.dart';
import '../models/operation_model.dart';
import '../models/client_model.dart';
import '../models/shop_model.dart';
import '../models/flot_model.dart' as flot_model;
import 'local_db.dart';
import 'flot_service.dart';
import 'client_service.dart';

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
      final transferts = await _calculerTransferts(shopId, dateRapport);

      // 4. Calculer les opérations clients (dépôts/retraits)
      final operationsClients = await _calculerOperationsClients(shopId, dateRapport);

      // 5. Récupérer les comptes clients
      final comptesClients = await _getComptesClients(shopId);
      
      // 6. Calculer les dettes/créances inter-shops
      final comptesShops = await _getComptesShops(shopId);

      // 7. Calculer le cash disponible par mode de paiement
      final cashDisponible = _calculerCashDisponible(
        shop: shop,
        soldeAnterieur: soldeAnterieur,
        flots: {
          'recu': flots['recu'] as double,
          'enCours': flots['enCours'] as double,
          'servi': flots['servi'] as double,
        },
        transferts: transferts,
        operationsClients: operationsClients,
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
        flotEnCours: flots['enCours']!,
        flotServi: flots['servi']!,
        
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
    // TODO: Implémenter la récupération du solde de clôture du jour précédent
    // Pour l'instant, retourner 0
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

    final flotsRecus = flotService.getFlotsRecus(shopId, date: dateRapport);
    final flotsEnCours = flotService.getFlotsEnCours(shopId)
        .where((f) => f.shopDestinationId == shopId);
    final flotsServis = flotService.flots.where((f) =>
        f.shopSourceId == shopId &&
        f.statut == flot_model.StatutFlot.servi &&
        f.dateReception != null &&
        _isSameDay(f.dateReception!, dateRapport)
    );
    
    // NOUVEAU: Créer les listes détaillées pour affichage dans le rapport
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
    
    // NOUVEAU: FLOT envoyés (enRoute + servis) - TOUS sont considérés comme opérations immédiates
    final flotsEnvoyesDetails = flotService.flots.where((f) =>
        f.shopSourceId == shopId &&
        (f.statut == flot_model.StatutFlot.enRoute || f.statut == flot_model.StatutFlot.servi) &&
        _isSameDay(f.dateEnvoi, dateRapport)
    ).map((f) => FlotResume(
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
      'recu': flotsRecus.fold(0.0, (sum, f) => sum + f.montant),
      'enCours': flotsEnCours.fold(0.0, (sum, f) => sum + f.montant),
      'servi': flotsServis.fold(0.0, (sum, f) => sum + f.montant),
      'flotsRecusDetails': flotsRecusDetails,      // NOUVEAU
      'flotsEnvoyesDetails': flotsEnvoyesDetails,  // NOUVEAU
    };
  }

  /// Calculer les transferts (reçus et servis)
  Future<Map<String, double>> _calculerTransferts(int shopId, DateTime dateRapport) async {
    final operations = await LocalDB.instance.getAllOperations();
    
    // Transferts reçus = initiés au shop source aujourd'hui (client a payé)
    final transfertsRecus = operations.where((op) =>
        op.shopSourceId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalSortant) &&
        _isSameDay(op.dateOp, dateRapport)
    );

    // Transferts servis = validés au shop destination aujourd'hui (bénéficiaire a reçu)
    final transfertsServis = operations.where((op) =>
        op.shopDestinationId == shopId &&
        (op.type == OperationType.transfertNational ||
         op.type == OperationType.transfertInternationalEntrant) &&
        op.statut == OperationStatus.validee &&
        _isSameDay(op.lastModifiedAt ?? op.dateOp, dateRapport)
    );

    return {
      'recus': transfertsRecus.fold(0.0, (sum, op) => sum + op.montantBrut), // Montant total reçu
      'servis': transfertsServis.fold(0.0, (sum, op) => sum + op.montantNet), // Montant servi
    };
  }

  /// Calculer les dépôts et retraits clients
  Future<Map<String, double>> _calculerOperationsClients(int shopId, DateTime dateRapport) async {
    final operations = await LocalDB.instance.getAllOperations();
    
    final depotsAujourdhui = operations.where((op) =>
        op.shopSourceId == shopId &&
        op.type == OperationType.depot &&
        _isSameDay(op.dateOp, dateRapport)
    );

    final retraitsAujourdhui = operations.where((op) =>
        op.shopSourceId == shopId &&
        op.type == OperationType.retrait &&
        _isSameDay(op.dateOp, dateRapport)
    );

    return {
      'depots': depotsAujourdhui.fold(0.0, (sum, op) => sum + op.montantNet),
      'retraits': retraitsAujourdhui.fold(0.0, (sum, op) => sum + op.montantNet),
    };
  }

  /// Récupérer les comptes clients (qui nous doivent vs qui nous devons)
  /// IMPORTANT: Filtrer UNIQUEMENT les clients de ce shop pour assurer la traçabilité des transactions
  Future<Map<String, List<CompteClientResume>>> _getComptesClients(int shopId) async {
    final clients = await LocalDB.instance.getAllClients();
    
    final clientsNousDoivent = <CompteClientResume>[];
    final clientsNousDevons = <CompteClientResume>[];

    // FILTRE IMPORTANT: Seulement les clients qui appartiennent à ce shop
    for (var client in clients.where((c) => c.shopId == shopId)) {
      if (client.solde != 0) {
        final resume = CompteClientResume(
          clientId: client.id!,
          nom: client.nom,
          telephone: client.telephone,
          solde: client.solde,
          numeroCompte: client.numeroCompte ?? 'N/A',
        );

        if (client.solde < 0) {
          clientsNousDoivent.add(resume); // Solde négatif = client doit au shop
        } else {
          clientsNousDevons.add(resume);  // Solde positif = shop doit au client
        }
      }
    }

    return {
      'nousDoivent': clientsNousDoivent,
      'nousDevons': clientsNousDevons,
    };
  }
  
  /// Calculer les dettes/créances inter-shops
  Future<Map<String, List<CompteShopResume>>> _getComptesShops(int shopId) async {
    final shops = await LocalDB.instance.getAllShops();
    final operations = await LocalDB.instance.getAllOperations();
    final flots = await LocalDB.instance.getFlotsByShop(shopId);
    
    final shopsNousDoivent = <CompteShopResume>[];
    final shopsNousDevons = <CompteShopResume>[];
    
    // Calculer pour chaque shop
    for (final shop in shops) {
      if (shop.id == shopId) continue; // Ignorer le shop actuel
      
      double dette = 0.0; // Ce que l'autre shop nous doit
      double creance = 0.0; // Ce que nous devons à l'autre shop
      
      // LOGIQUE CORRECTE : Shop SOURCE (qui reçoit le cash du client) DOIT au shop DESTINATION (qui servira le bénéficiaire)
      // Transferts sortants de notre shop vers ce shop (NOUS DEVONS à ce shop le montant BRUT)
      final transfertsSortants = operations.where((op) =>
        op.shopSourceId == shopId &&
        op.shopDestinationId == shop.id &&
        (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) &&
        (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee)
      ).toList();
      
      for (final transfert in transfertsSortants) {
        creance += transfert.montantBrut; // NOUS lui devons le montant BRUT (on a reçu le cash, il doit servir)
      }
      
      // Transferts entrants de ce shop vers notre shop (CE SHOP NOUS DOIT le montant BRUT)
      final transfertsEntrants = operations.where((op) =>
        op.shopSourceId == shop.id &&
        op.shopDestinationId == shopId &&
        (op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) &&
        (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee)
      ).toList();
      
      for (final transfert in transfertsEntrants) {
        dette += transfert.montantBrut; // Il NOUS doit le montant BRUT (il a reçu le cash, nous devons servir)
      }
      
      // LOGIQUE FLOT CORRECTE : Quand Shop A envoie FLOT vers Shop B, Shop B DOIT à Shop A
      // Floats envoyés par notre shop vers ce shop (Shop B nous doit)
      final flotsEnvoyes = flots.where((f) =>
        f.shopSourceId == shopId &&
        f.shopDestinationId == shop.id &&
        (f.statut == flot_model.StatutFlot.enRoute || f.statut == flot_model.StatutFlot.servi)
      ).toList();
      
      for (final flot in flotsEnvoyes) {
        // FLOT envoyé = NOUS avons donné de l'argent à ce shop
        // Donc CE SHOP NOUS DOIT (dette pour eux, créance pour nous)
        dette += flot.montant;
      }
      
      // Floats reçus de ce shop vers notre shop (Nous devons à ce shop)
      final flotsRecus = flots.where((f) =>
        f.shopSourceId == shop.id &&
        f.shopDestinationId == shopId &&
        (f.statut == flot_model.StatutFlot.enRoute || f.statut == flot_model.StatutFlot.servi)
      ).toList();
      
      for (final flot in flotsRecus) {
        // FLOT reçu = CE SHOP a donné de l'argent à nous
        // Donc NOUS DEVONS à ce shop (créance pour nous)
        creance += flot.montant;
      }
      
      // Calculer le solde net
      final soldeNet = dette - creance;
      
      if (soldeNet > 0) {
        // Ce shop nous doit
        shopsNousDoivent.add(CompteShopResume(
          shopId: shop.id!,
          designation: shop.designation,
          localisation: shop.localisation,
          montant: soldeNet,
        ));
      } else if (soldeNet < 0) {
        // Nous devons à ce shop
        shopsNousDevons.add(CompteShopResume(
          shopId: shop.id!,
          designation: shop.designation,
          localisation: shop.localisation,
          montant: soldeNet.abs(),
        ));
      }
    }
    
    return {
      'nousDoivent': shopsNousDoivent,
      'nousDevons': shopsNousDevons,
    };
  }

  /// Calculer le cash disponible par mode de paiement
  Map<String, double> _calculerCashDisponible({
    required ShopModel shop,
    required Map<String, double> soldeAnterieur,
    required Map<String, double> flots,
    required Map<String, double> transferts,
    required Map<String, double> operationsClients,
  }) {
    // Formule CORRECTE:
    // Cash Disponible = Solde Antérieur + Flot Reçu - Flot En cours
    //                   + Transferts Reçus - Transferts Servis
    //                   + Dépôts Clients - Retraits Clients
    //
    // IMPORTANT: 
    // - Flot En cours est SOUSTRAIT car c'est une SORTIE immédiate de cash (shop source a envoyé)
    // - Flot Servi n'affecte PAS le cash car déjà compté en "enCours" lors de l'envoi
    //   (quand statut passe de enRoute -> servi, c'est juste une confirmation, le cash était déjà sorti)

    // Calculer les impacts par mode de paiement
    final cashImpact = soldeAnterieur['cash']! + 
                      flots['recu']! - flots['enCours']! +
                      transferts['recus']! - transferts['servis']! +
                      operationsClients['depots']! - operationsClients['retraits']!;
    
    final airtelMoneyImpact = soldeAnterieur['airtelMoney']! +
                             0.0; // Airtel Money impacts not calculated in current logic
    
    final mPesaImpact = soldeAnterieur['mPesa']! +
                       0.0; // M-Pesa impacts not calculated in current logic
    
    final orangeMoneyImpact = soldeAnterieur['orangeMoney']! +
                             0.0; // Orange Money impacts not calculated in current logic
    
    final totalImpact = cashImpact + airtelMoneyImpact + mPesaImpact + orangeMoneyImpact;

    return {
      'cash': cashImpact,
      'airtelMoney': airtelMoneyImpact,
      'mPesa': mPesaImpact,
      'orangeMoney': orangeMoneyImpact,
      'total': totalImpact,
    };
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }
}
