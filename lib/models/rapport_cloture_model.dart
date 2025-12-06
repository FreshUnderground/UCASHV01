/// Modèle pour le Rapport de Clôture Journée
class RapportClotureModel {
  final int shopId;
  final String shopDesignation;
  final DateTime dateRapport;
  final String deviseLocale; // NOUVEAU: CDF, UGX, etc.
  
  // Solde antérieur USD
  final double soldeAnterieurCash;
  final double soldeAnterieurAirtelMoney;
  final double soldeAnterieurMPesa;
  final double soldeAnterieurOrangeMoney;
  
  // NOUVEAU: Solde antérieur DEVISE LOCALE
  final double soldeAnterieurCashDeviseLocale;
  final double soldeAnterieurAirtelMoneyDeviseLocale;
  final double soldeAnterieurMPesaDeviseLocale;
  final double soldeAnterieurOrangeMoneyDeviseLocale;
  
  // Flots USD
  final double flotRecu;
  final double flotEnvoye;
  final double flotsEnAttente; // NEW: FLOTs en attente  
  // NOUVEAU: Flots DEVISE LOCALE
  final double flotRecuDeviseLocale;
  final double flotEnvoyeDeviseLocale;
  
  // Transferts USD
  final double transfertsRecus;
  final double transfertsServis;
  final double transfertsEnAttente; // NOUVEAU: Transferts à servir (shop destination)
  
  // NOUVEAU: Transferts groupés par shop
  final Map<String, double> transfertsRecusGroupes; // Groupé par shop destination
  final Map<String, double> transfertsServisGroupes; // Groupé par shop source
  final Map<String, double> transfertsEnAttenteGroupes; // Groupé par shop source
  
  // NOUVEAU: Transferts DEVISE LOCALE
  final double transfertsRecusDeviseLocale;
  final double transfertsServisDeviseLocale;
  final double transfertsEnAttenteDeviseLocale;
  
  // Clients USD
  final double depotsClients;
  final double retraitsClients;
  
  // NOUVEAU: Clients DEVISE LOCALE
  final double depotsClientsDeviseLocale;
  final double retraitsClientsDeviseLocale;
  
  // Comptes clients
  final List<CompteClientResume> clientsNousDoivent;
  final List<CompteClientResume> clientsNousDevons;
  
  // Comptes inter-shops
  final List<CompteShopResume> shopsNousDoivent;
  final List<CompteShopResume> shopsNousDevons;
  
  // NOUVEAU: Comptes spéciaux (FRAIS et DÉPENSE)
  final double soldeFraisAnterieur;       // NOUVEAU: Solde FRAIS antérieur (jour précédent)
  final double retraitsFraisDuJour;      // Retraits FRAIS du jour
  final double commissionsFraisDuJour;   // FRAIS encaissés sur les transferts que nous avons servis (shop destination)
  final Map<String, double> fraisGroupesParShop; // Frais groupés par shop source (qui a envoyé le transfert)
  final double soldeFraisTotal;          // Solde total du compte FRAIS
  final double sortiesDepenseDuJour;     // Sorties DÉPENSE du jour
  final double depotsDepenseDuJour;      // Dépôts DÉPENSE du jour
  final double soldeDepenseTotal;        // Solde total du compte DÉPENSE
  
  // Listes détaillées des FLOT
  final List<FlotResume> flotsRecusDetails;
  final Map<String, double> flotsRecusGroupes; // Flots reçus groupés par shop expéditeur
  final List<FlotResume> flotsEnvoyes;
  final Map<String, double> flotsEnvoyesGroupes; // Flots envoyés groupés par shop destination
  final Map<String, double> flotsEnAttenteGroupes; // NEW: FLOTs en attente groupés par shop expéditeur
  
  // NOUVEAU: Listes détaillées des opérations clients (dépôts et retraits)
  final List<OperationResume> depotsClientsDetails;
  final List<OperationResume> retraitsClientsDetails;
  
  // NOUVEAU: Liste détaillée des transferts en attente
  final List<OperationResume> transfertsEnAttenteDetails;
  
  // NOUVEAU: Liste des transferts groupés par route (source → destination)
  final List<TransfertRouteResume> transfertsGroupes;
  
  // Cash disponible USD
  final double cashDisponibleCash;
  final double cashDisponibleAirtelMoney;
  final double cashDisponibleMPesa;
  final double cashDisponibleOrangeMoney;
  final double cashDisponibleTotal;
  
  // NOUVEAU: Cash disponible DEVISE LOCALE
  final double cashDisponibleCashDeviseLocale;
  final double cashDisponibleAirtelMoneyDeviseLocale;
  final double cashDisponibleMPesaDeviseLocale;
  final double cashDisponibleOrangeMoneyDeviseLocale;
  final double cashDisponibleTotalDeviseLocale;
  
  // Capital Net USD
  final double capitalNet;
  
  // NOUVEAU: Capital Net DEVISE LOCALE
  final double capitalNetDeviseLocale;
  
  // Métadonnées
  final String? generePar;
  final DateTime dateGeneration;

  RapportClotureModel({
    required this.shopId,
    required this.shopDesignation,
    required this.dateRapport,
    this.deviseLocale = 'CDF', // Par défaut CDF
    required this.soldeAnterieurCash,
    required this.soldeAnterieurAirtelMoney,
    required this.soldeAnterieurMPesa,
    required this.soldeAnterieurOrangeMoney,
    this.soldeAnterieurCashDeviseLocale = 0.0,
    this.soldeAnterieurAirtelMoneyDeviseLocale = 0.0,
    this.soldeAnterieurMPesaDeviseLocale = 0.0,
    this.soldeAnterieurOrangeMoneyDeviseLocale = 0.0,
    required this.flotRecu,
    required this.flotEnvoye,
    this.flotsEnAttente = 0.0, // NEW: FLOTs en attente
    this.flotRecuDeviseLocale = 0.0,
    this.flotEnvoyeDeviseLocale = 0.0,
    required this.transfertsRecus,
    required this.transfertsServis,
    this.transfertsEnAttente = 0.0,
    required this.transfertsRecusGroupes,
    required this.transfertsServisGroupes,
    required this.transfertsEnAttenteGroupes,
    this.transfertsRecusDeviseLocale = 0.0,
    this.transfertsServisDeviseLocale = 0.0,
    this.transfertsEnAttenteDeviseLocale = 0.0,
    required this.depotsClients,
    required this.retraitsClients,
    this.depotsClientsDeviseLocale = 0.0,
    this.retraitsClientsDeviseLocale = 0.0,
    required this.clientsNousDoivent,
    required this.clientsNousDevons,
    required this.shopsNousDoivent,
    required this.shopsNousDevons,
    this.soldeFraisAnterieur = 0.0,
    this.retraitsFraisDuJour = 0.0,
    this.commissionsFraisDuJour = 0.0,
    this.fraisGroupesParShop = const {},
    this.soldeFraisTotal = 0.0,
    this.sortiesDepenseDuJour = 0.0,
    this.depotsDepenseDuJour = 0.0,
    this.soldeDepenseTotal = 0.0,
    this.flotsRecusDetails = const [],
    required this.flotsRecusGroupes,
    this.flotsEnvoyes = const [],
    required this.flotsEnvoyesGroupes,
    required this.flotsEnAttenteGroupes, // NEW: FLOTs en attente groupés
    this.depotsClientsDetails = const [],
    this.retraitsClientsDetails = const [],
    this.transfertsEnAttenteDetails = const [],
    this.transfertsGroupes = const [],
    required this.cashDisponibleCash,
    required this.cashDisponibleAirtelMoney,
    required this.cashDisponibleMPesa,
    required this.cashDisponibleOrangeMoney,
    required this.cashDisponibleTotal,
    this.cashDisponibleCashDeviseLocale = 0.0,
    this.cashDisponibleAirtelMoneyDeviseLocale = 0.0,
    this.cashDisponibleMPesaDeviseLocale = 0.0,
    this.cashDisponibleOrangeMoneyDeviseLocale = 0.0,
    this.cashDisponibleTotalDeviseLocale = 0.0,
    required this.capitalNet,
    this.capitalNetDeviseLocale = 0.0,
    this.generePar,
    DateTime? dateGeneration,
  }) : dateGeneration = dateGeneration ?? DateTime.now();

  double get totalClientsNousDoivent =>
      clientsNousDoivent.fold(0.0, (sum, client) => sum + client.solde.abs());

  double get totalClientsNousDevons =>
      clientsNousDevons.fold(0.0, (sum, client) => sum + client.solde);
  
  double get totalShopsNousDoivent =>
      shopsNousDoivent.fold(0.0, (sum, shop) => sum + shop.montant);
  
  double get totalShopsNousDevons =>
      shopsNousDevons.fold(0.0, (sum, shop) => sum + shop.montant);

  double get soldeAnterieurTotal =>
      soldeAnterieurCash +
      soldeAnterieurAirtelMoney +
      soldeAnterieurMPesa +
      soldeAnterieurOrangeMoney;
      
  // NOUVEAU: Total solde antérieur devise locale
  double get soldeAnterieurTotalDeviseLocale =>
      soldeAnterieurCashDeviseLocale +
      soldeAnterieurAirtelMoneyDeviseLocale +
      soldeAnterieurMPesaDeviseLocale +
      soldeAnterieurOrangeMoneyDeviseLocale;

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'date_rapport': dateRapport.toIso8601String(),
      'devise_locale': deviseLocale,
      'solde_anterieur_cash': soldeAnterieurCash,
      'solde_anterieur_airtel_money': soldeAnterieurAirtelMoney,
      'solde_anterieur_mpesa': soldeAnterieurMPesa,
      'solde_anterieur_orange_money': soldeAnterieurOrangeMoney,
      'solde_anterieur_cash_devise_locale': soldeAnterieurCashDeviseLocale,
      'solde_anterieur_airtel_money_devise_locale': soldeAnterieurAirtelMoneyDeviseLocale,
      'solde_anterieur_mpesa_devise_locale': soldeAnterieurMPesaDeviseLocale,
      'solde_anterieur_orange_money_devise_locale': soldeAnterieurOrangeMoneyDeviseLocale,
      'flot_recu': flotRecu,
      'flot_envoye': flotEnvoye,
      'flot_recu_devise_locale': flotRecuDeviseLocale,
      'flot_envoye_devise_locale': flotEnvoyeDeviseLocale,
      'transferts_recus': transfertsRecus,
      'transferts_servis': transfertsServis,
      'transferts_en_attente': transfertsEnAttente,
      'transferts_recus_groupes': transfertsRecusGroupes, // Map<String, double>
      'transferts_servis_groupes': transfertsServisGroupes, // Map<String, double>
      'transferts_en_attente_groupes': transfertsEnAttenteGroupes, // Map<String, double>
      'transferts_recus_devise_locale': transfertsRecusDeviseLocale,
      'transferts_servis_devise_locale': transfertsServisDeviseLocale,
      'transferts_en_attente_devise_locale': transfertsEnAttenteDeviseLocale,
      'depots_clients': depotsClients,
      'retraits_clients': retraitsClients,
      'depots_clients_devise_locale': depotsClientsDeviseLocale,
      'retraits_clients_devise_locale': retraitsClientsDeviseLocale,
      'clients_nous_doivent': clientsNousDoivent.map((c) => c.toJson()).toList(),
      'clients_nous_devons': clientsNousDevons.map((c) => c.toJson()).toList(),
      'shops_nous_doivent': shopsNousDoivent.map((s) => s.toJson()).toList(),
      'shops_nous_devons': shopsNousDevons.map((s) => s.toJson()).toList(),
      'flots_recus_details': flotsRecusDetails.map((f) => f.toJson()).toList(), // Maintenant gérés comme operations
      'flots_recus_groupes': flotsRecusGroupes, // Map<String, double> - Maintenant gérés comme operations
      'flots_envoyes': flotsEnvoyes.map((f) => f.toJson()).toList(), // Maintenant gérés comme operations
      'flots_envoyes_groupes': flotsEnvoyesGroupes, // Map<String, double> - Maintenant gérés comme operations
      'flots_en_attente_groupes': flotsEnAttenteGroupes, // NEW: FLOTs en attente groupés
      'depots_clients_details': depotsClientsDetails.map((d) => d.toJson()).toList(),
      'retraits_clients_details': retraitsClientsDetails.map((r) => r.toJson()).toList(),
      'transferts_en_attente_details': transfertsEnAttenteDetails.map((t) => t.toJson()).toList(),
      'transferts_groupes': transfertsGroupes.map((t) => t.toJson()).toList(),
      'cash_disponible_cash': cashDisponibleCash,
      'cash_disponible_airtel_money': cashDisponibleAirtelMoney,
      'cash_disponible_mpesa': cashDisponibleMPesa,
      'cash_disponible_orange_money': cashDisponibleOrangeMoney,
      'cash_disponible_total': cashDisponibleTotal,
      'cash_disponible_cash_devise_locale': cashDisponibleCashDeviseLocale,
      'cash_disponible_airtel_money_devise_locale': cashDisponibleAirtelMoneyDeviseLocale,
      'cash_disponible_mpesa_devise_locale': cashDisponibleMPesaDeviseLocale,
      'cash_disponible_orange_money_devise_locale': cashDisponibleOrangeMoneyDeviseLocale,
      'cash_disponible_total_devise_locale': cashDisponibleTotalDeviseLocale,
      'capital_net': capitalNet,
      'capital_net_devise_locale': capitalNetDeviseLocale,
      'genere_par': generePar,
      'date_generation': dateGeneration.toIso8601String(),
    };
  }
}

/// Résumé d'un compte client pour le rapport
class CompteClientResume {
  final int clientId;
  final String nom;
  final String telephone;
  final double solde;
  final String numeroCompte;

  CompteClientResume({
    required this.clientId,
    required this.nom,
    required this.telephone,
    required this.solde,
    required this.numeroCompte,
  });

  Map<String, dynamic> toJson() {
    return {
      'client_id': clientId,
      'nom': nom,
      'telephone': telephone,
      'solde': solde,
      'numero_compte': numeroCompte,
    };
  }
}

/// Résumé d'un compte inter-shop pour le rapport
class CompteShopResume {
  final int shopId;
  final String designation;
  final String localisation;
  final double montant; // Montant dû (positif)

  CompteShopResume({
    required this.shopId,
    required this.designation,
    required this.localisation,
    required this.montant,
  });

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'designation': designation,
      'localisation': localisation,
      'montant': montant,
    };
  }
}

/// Résumé d'un FLOT pour le rapport de clôture
/// NOTE: Les FLOTs sont maintenant gérés comme des operations avec type=flotShopToShop
class FlotResume {
  final int flotId;
  final String shopSourceDesignation;
  final String shopDestinationDesignation;
  final double montant;
  final String devise;
  final String statut;  // 'enRoute' ou 'servi'
  final DateTime dateEnvoi;
  final DateTime? dateReception;
  final String modePaiement;

  FlotResume({
    required this.flotId,
    required this.shopSourceDesignation,
    required this.shopDestinationDesignation,
    required this.montant,
    required this.devise,
    required this.statut,
    required this.dateEnvoi,
    this.dateReception,
    required this.modePaiement,
  });

  Map<String, dynamic> toJson() {
    return {
      'flot_id': flotId,
      'shop_source': shopSourceDesignation,
      'shop_destination': shopDestinationDesignation,
      'montant': montant,
      'devise': devise,
      'statut': statut,
      'date_envoi': dateEnvoi.toIso8601String(),
      'date_reception': dateReception?.toIso8601String(),
      'mode_paiement': modePaiement,
    };
  }
}

/// Résumé d'une opération client (dépôt ou retrait) pour le rapport de clôture
class OperationResume {
  final int operationId;
  final String type; // 'depot' ou 'retrait'
  final double montant;
  final String devise;
  final DateTime date;
  final String? destinataire;
  final String? observation; // IMPORTANT: Observation saisie par l'agent
  final String? notes;
  final String modePaiement;

  OperationResume({
    required this.operationId,
    required this.type,
    required this.montant,
    required this.devise,
    required this.date,
    this.destinataire,
    this.observation,
    this.notes,
    required this.modePaiement,
  });

  Map<String, dynamic> toJson() {
    return {
      'operation_id': operationId,
      'type': type,
      'montant': montant,
      'devise': devise,
      'date': date.toIso8601String(),
      'destinataire': destinataire,
      'observation': observation,
      'notes': notes,
      'mode_paiement': modePaiement,
    };
  }
}

/// Résumé des transferts groupés par route (source → destination)
class TransfertRouteResume {
  final String shopSourceDesignation;
  final String shopDestinationDesignation;
  final int transfertsCount;
  final int servisCount;
  final int enAttenteCount;
  final double transfertsTotal;
  final double servisTotal;
  final double enAttenteTotal;

  TransfertRouteResume({
    required this.shopSourceDesignation,
    required this.shopDestinationDesignation,
    required this.transfertsCount,
    required this.servisCount,
    required this.enAttenteCount,
    required this.transfertsTotal,
    required this.servisTotal,
    required this.enAttenteTotal,
  });

  Map<String, dynamic> toJson() {
    return {
      'shop_source_designation': shopSourceDesignation,
      'shop_destination_designation': shopDestinationDesignation,
      'transferts_count': transfertsCount,
      'servis_count': servisCount,
      'en_attente_count': enAttenteCount,
      'transferts_total': transfertsTotal,
      'servis_total': servisTotal,
      'en_attente_total': enAttenteTotal,
    };
  }
}
