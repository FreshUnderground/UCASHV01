/// Modèle pour le Rapport de Clôture Journalière
class RapportClotureModel {
  final int shopId;
  final String shopDesignation;
  final DateTime dateRapport;
  
  // Solde antérieur (solde de clôture du jour précédent)
  final double soldeAnterieurCash;
  final double soldeAnterieurAirtelMoney;
  final double soldeAnterieurMPesa;
  final double soldeAnterieurOrangeMoney;
  
  // Flots
  final double flotRecu;        // Flots servis (reçus) aujourd'hui
  final double flotEnCours;     // Flots envoyés mais pas encore servis
  final double flotServi;       // Flots qu'on a envoyés et qui ont été servis
  
  // Transferts
  final double transfertsRecus;      // Transferts initiés (clients ont payé)
  final double transfertsServis;     // Transferts servis aux bénéficiaires
  
  // Clients
  final double depotsClients;        // Dépôts dans comptes clients
  final double retraitsClients;      // Retraits des comptes clients
  
  // Comptes clients
  final List<CompteClientResume> clientsNousDoivent;  // Solde négatif
  final List<CompteClientResume> clientsNousDevons;   // Solde positif
  
  // Comptes inter-shops (NOUVEAU)
  final List<CompteShopResume> shopsNousDoivent;  // Shops qui nous doivent (transferts - floats)
  final List<CompteShopResume> shopsNousDevons;   // Shops que nous devons
  
  // NOUVEAU: Listes détaillées des FLOT individuels pour affichage dans le rapport  
  final List<FlotResume> flotsRecusDetails;      // FLOT reçus (servis) avec détails
  final List<FlotResume> flotsEnvoyes;           // FLOT envoyés (enRoute + servis) avec détails
  final List<FlotResume> flotsEnCoursDetails;    // FLOT en cours (enRoute) avec détails
  
  // Cash disponible par mode de paiement
  final double cashDisponibleCash;
  final double cashDisponibleAirtelMoney;
  final double cashDisponibleMPesa;
  final double cashDisponibleOrangeMoney;
  
  // Total
  final double cashDisponibleTotal;
  
  // Capital Net Calculation
  final double capitalNet;
  
  // Métadonnées
  final String? generePar;
  final DateTime dateGeneration;

  RapportClotureModel({
    required this.shopId,
    required this.shopDesignation,
    required this.dateRapport,
    required this.soldeAnterieurCash,
    required this.soldeAnterieurAirtelMoney,
    required this.soldeAnterieurMPesa,
    required this.soldeAnterieurOrangeMoney,
    required this.flotRecu,
    required this.flotEnCours,
    required this.flotServi,
    required this.transfertsRecus,
    required this.transfertsServis,
    required this.depotsClients,
    required this.retraitsClients,
    required this.clientsNousDoivent,
    required this.clientsNousDevons,
    required this.shopsNousDoivent,
    required this.shopsNousDevons,
    this.flotsRecusDetails = const [],     // NOUVEAU: par défaut liste vide
    this.flotsEnvoyes = const [],          // NOUVEAU: par défaut liste vide
    this.flotsEnCoursDetails = const [],    // NOUVEAU: par défaut liste vide
    required this.cashDisponibleCash,
    required this.cashDisponibleAirtelMoney,
    required this.cashDisponibleMPesa,
    required this.cashDisponibleOrangeMoney,
    required this.cashDisponibleTotal,
    required this.capitalNet,
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

  Map<String, dynamic> toJson() {
    return {
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'date_rapport': dateRapport.toIso8601String(),
      'solde_anterieur_cash': soldeAnterieurCash,
      'solde_anterieur_airtel_money': soldeAnterieurAirtelMoney,
      'solde_anterieur_mpesa': soldeAnterieurMPesa,
      'solde_anterieur_orange_money': soldeAnterieurOrangeMoney,
      'flot_recu': flotRecu,
      'flot_en_cours': flotEnCours,
      'flot_servi': flotServi,
      'transferts_recus': transfertsRecus,
      'transferts_servis': transfertsServis,
      'depots_clients': depotsClients,
      'retraits_clients': retraitsClients,
      'clients_nous_doivent': clientsNousDoivent.map((c) => c.toJson()).toList(),
      'clients_nous_devons': clientsNousDevons.map((c) => c.toJson()).toList(),
      'shops_nous_doivent': shopsNousDoivent.map((s) => s.toJson()).toList(),
      'shops_nous_devons': shopsNousDevons.map((s) => s.toJson()).toList(),
      'flots_recus_details': flotsRecusDetails.map((f) => f.toJson()).toList(),  // NOUVEAU
      'flots_envoyes': flotsEnvoyes.map((f) => f.toJson()).toList(),            // NOUVEAU
      'flots_en_cours_details': flotsEnCoursDetails.map((f) => f.toJson()).toList(),  // NOUVEAU
      'cash_disponible_cash': cashDisponibleCash,
      'cash_disponible_airtel_money': cashDisponibleAirtelMoney,
      'cash_disponible_mpesa': cashDisponibleMPesa,
      'cash_disponible_orange_money': cashDisponibleOrangeMoney,
      'cash_disponible_total': cashDisponibleTotal,
      'capital_net': capitalNet,
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
