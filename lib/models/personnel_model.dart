class PersonnelModel {
  final int? id;
  final String matricule;
  final String nom;
  final String prenom;
  final String telephone;
  final String? email;
  final String? adresse;
  final DateTime? dateNaissance;
  final String? lieuNaissance;
  final String sexe; // 'M' ou 'F'
  final String etatCivil; // 'Celibataire', 'Marie', 'Divorce', 'Veuf'
  final int nombreEnfants;
  final String? numeroINSS; // Numéro INSS (obligatoire RDC)
  final String categorieProfessionnelle; // Catégorie selon classification RDC
  
  // Informations professionnelles
  final String poste;
  final String? departement;
  final int? shopId;
  final String? shopDesignation;
  final DateTime dateEmbauche;
  final DateTime? dateFinContrat;
  final String typeContrat; // 'CDI', 'CDD', 'Stage', 'Temporaire'
  final String statut; // 'Actif', 'Suspendu', 'Conge', 'Demissionne', 'Licencie'
  
  // Informations salariales
  final double salaireBase;
  final String deviseSalaire;
  final double primeTransport;
  final double primeLogement;
  final double primeFonction;
  final double autresPrimes;
  
  // Avantages en nature (RDC)
  final double avantageNatureLogement; // Valeur logement fourni
  final double avantageNatureVoiture; // Valeur voiture de service
  final double autresAvantagesNature; // Autres avantages évaluables
  
  // Informations bancaires
  final String? numeroCompteBancaire;
  final String? banque;
  
  // Métadonnées
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final DateTime? createdAt;
  final bool isSynced;
  final DateTime? syncedAt;

  PersonnelModel({
    this.id,
    required this.matricule,
    required this.nom,
    required this.prenom,
    required this.telephone,
    this.email,
    this.adresse,
    this.dateNaissance,
    this.lieuNaissance,
    this.sexe = 'M',
    this.etatCivil = 'Celibataire',
    this.nombreEnfants = 0,
    this.numeroINSS,
    this.categorieProfessionnelle = 'Non classe',
    required this.poste,
    this.departement,
    this.shopId,
    this.shopDesignation,
    required this.dateEmbauche,
    this.dateFinContrat,
    this.typeContrat = 'CDI',
    this.statut = 'Actif',
    this.salaireBase = 0.0,
    this.deviseSalaire = 'USD',
    this.primeTransport = 0.0,
    this.primeLogement = 0.0,
    this.primeFonction = 0.0,
    this.autresPrimes = 0.0,
    this.avantageNatureLogement = 0.0,
    this.avantageNatureVoiture = 0.0,
    this.autresAvantagesNature = 0.0,
    this.numeroCompteBancaire,
    this.banque,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.createdAt,
    this.isSynced = false,
    this.syncedAt,
  });

  // Calcul du salaire total (incluant avantages en nature)
  double get salaireTotal => salaireBase + primeTransport + primeLogement + primeFonction + autresPrimes + 
                             avantageNatureLogement + avantageNatureVoiture + autresAvantagesNature;

  // Nom complet
  String get nomComplet => '$nom $prenom';

  factory PersonnelModel.fromJson(Map<String, dynamic> json) {
    return PersonnelModel(
      id: json['id'],
      matricule: json['matricule'] ?? '',
      nom: json['nom'] ?? '',
      prenom: json['prenom'] ?? '',
      telephone: json['telephone'] ?? '',
      email: json['email'],
      adresse: json['adresse'],
      dateNaissance: json['date_naissance'] != null 
          ? DateTime.parse(json['date_naissance']) 
          : null,
      lieuNaissance: json['lieu_naissance'],
      sexe: json['sexe'] ?? 'M',
      etatCivil: json['etat_civil'] ?? 'Celibataire',
      nombreEnfants: json['nombre_enfants'] ?? 0,
      numeroINSS: json['numero_inss'],
      categorieProfessionnelle: json['categorie_professionnelle'] ?? 'Non classe',
      poste: json['poste'] ?? '',
      departement: json['departement'],
      shopId: json['shop_id'],
      shopDesignation: json['shop_designation'],
      dateEmbauche: json['date_embauche'] != null 
          ? DateTime.parse(json['date_embauche']) 
          : DateTime.now(),
      dateFinContrat: json['date_fin_contrat'] != null 
          ? DateTime.parse(json['date_fin_contrat']) 
          : null,
      typeContrat: json['type_contrat'] ?? 'CDI',
      statut: json['statut'] ?? 'Actif',
      salaireBase: json['salaire_base'] != null 
          ? double.tryParse(json['salaire_base'].toString()) ?? 0.0 
          : 0.0,
      deviseSalaire: json['devise_salaire'] ?? 'USD',
      primeTransport: json['prime_transport'] != null 
          ? double.tryParse(json['prime_transport'].toString()) ?? 0.0 
          : 0.0,
      primeLogement: json['prime_logement'] != null 
          ? double.tryParse(json['prime_logement'].toString()) ?? 0.0 
          : 0.0,
      primeFonction: json['prime_fonction'] != null 
          ? double.tryParse(json['prime_fonction'].toString()) ?? 0.0 
          : 0.0,
      autresPrimes: json['autres_primes'] != null 
          ? double.tryParse(json['autres_primes'].toString()) ?? 0.0 
          : 0.0,
      avantageNatureLogement: json['avantage_nature_logement'] != null 
          ? double.tryParse(json['avantage_nature_logement'].toString()) ?? 0.0 
          : 0.0,
      avantageNatureVoiture: json['avantage_nature_voiture'] != null 
          ? double.tryParse(json['avantage_nature_voiture'].toString()) ?? 0.0 
          : 0.0,
      autresAvantagesNature: json['autres_avantages_nature'] != null 
          ? double.tryParse(json['autres_avantages_nature'].toString()) ?? 0.0 
          : 0.0,
      numeroCompteBancaire: json['numero_compte_bancaire'],
      banque: json['banque'],
      lastModifiedAt: json['last_modified_at'] != null 
          ? DateTime.parse(json['last_modified_at']) 
          : null,
      lastModifiedBy: json['last_modified_by'],
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
      syncedAt: json['synced_at'] != null 
          ? DateTime.parse(json['synced_at']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'matricule': matricule,
      'nom': nom,
      'prenom': prenom,
      'telephone': telephone,
      'email': email,
      'adresse': adresse,
      'date_naissance': dateNaissance?.toString().split(' ')[0],
      'lieu_naissance': lieuNaissance,
      'sexe': sexe,
      'etat_civil': etatCivil,
      'nombre_enfants': nombreEnfants,
      'numero_inss': numeroINSS,
      'categorie_professionnelle': categorieProfessionnelle,
      'poste': poste,
      'departement': departement,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'date_embauche': dateEmbauche.toString().split(' ')[0],
      'date_fin_contrat': dateFinContrat?.toString().split(' ')[0],
      'type_contrat': typeContrat,
      'statut': statut,
      'salaire_base': salaireBase,
      'devise_salaire': deviseSalaire,
      'prime_transport': primeTransport,
      'prime_logement': primeLogement,
      'prime_fonction': primeFonction,
      'autres_primes': autresPrimes,
      'avantage_nature_logement': avantageNatureLogement,
      'avantage_nature_voiture': avantageNatureVoiture,
      'autres_avantages_nature': autresAvantagesNature,
      'numero_compte_bancaire': numeroCompteBancaire,
      'banque': banque,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'created_at': createdAt?.toIso8601String(),
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
    };
  }

  PersonnelModel copyWith({
    int? id,
    String? matricule,
    String? nom,
    String? prenom,
    String? telephone,
    String? email,
    String? adresse,
    DateTime? dateNaissance,
    String? lieuNaissance,
    String? sexe,
    String? etatCivil,
    int? nombreEnfants,
    String? numeroINSS,
    String? categorieProfessionnelle,
    String? poste,
    String? departement,
    int? shopId,
    String? shopDesignation,
    DateTime? dateEmbauche,
    DateTime? dateFinContrat,
    String? typeContrat,
    String? statut,
    double? salaireBase,
    String? deviseSalaire,
    double? primeTransport,
    double? primeLogement,
    double? primeFonction,
    double? autresPrimes,
    double? avantageNatureLogement,
    double? avantageNatureVoiture,
    double? autresAvantagesNature,
    String? numeroCompteBancaire,
    String? banque,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    DateTime? createdAt,
    bool? isSynced,
    DateTime? syncedAt,
  }) {
    return PersonnelModel(
      id: id ?? this.id,
      matricule: matricule ?? this.matricule,
      nom: nom ?? this.nom,
      prenom: prenom ?? this.prenom,
      telephone: telephone ?? this.telephone,
      email: email ?? this.email,
      adresse: adresse ?? this.adresse,
      dateNaissance: dateNaissance ?? this.dateNaissance,
      lieuNaissance: lieuNaissance ?? this.lieuNaissance,
      sexe: sexe ?? this.sexe,
      etatCivil: etatCivil ?? this.etatCivil,
      nombreEnfants: nombreEnfants ?? this.nombreEnfants,
      numeroINSS: numeroINSS ?? this.numeroINSS,
      categorieProfessionnelle: categorieProfessionnelle ?? this.categorieProfessionnelle,
      poste: poste ?? this.poste,
      departement: departement ?? this.departement,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      dateEmbauche: dateEmbauche ?? this.dateEmbauche,
      dateFinContrat: dateFinContrat ?? this.dateFinContrat,
      typeContrat: typeContrat ?? this.typeContrat,
      statut: statut ?? this.statut,
      salaireBase: salaireBase ?? this.salaireBase,
      deviseSalaire: deviseSalaire ?? this.deviseSalaire,
      primeTransport: primeTransport ?? this.primeTransport,
      primeLogement: primeLogement ?? this.primeLogement,
      primeFonction: primeFonction ?? this.primeFonction,
      autresPrimes: autresPrimes ?? this.autresPrimes,
      avantageNatureLogement: avantageNatureLogement ?? this.avantageNatureLogement,
      avantageNatureVoiture: avantageNatureVoiture ?? this.avantageNatureVoiture,
      autresAvantagesNature: autresAvantagesNature ?? this.autresAvantagesNature,
      numeroCompteBancaire: numeroCompteBancaire ?? this.numeroCompteBancaire,
      banque: banque ?? this.banque,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
    );
  }
}
