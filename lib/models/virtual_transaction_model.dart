/// Modèle pour la gestion des transactions virtuelles (Mobile Money)
/// Workflow: Agent reçoit capture client → Enregistre REF+MONTANT (en attente)
/// → Client arrive → Cherche par REF → Enregistre client servi + valide
class VirtualTransactionModel {
  final int? id;
  final String reference; // Référence unique de la transaction (du screenshot client)
  final double montantVirtuel; // Montant reçu virtuellement sur la SIM
  final double frais; // Commission/Frais prélevés
  final double montantCash; // Montant cash à donner au client (montantVirtuel - frais)
  final String devise;
  
  // Informations SIM
  final String simNumero; // Numéro de la SIM utilisée
  final int shopId; // Shop auquel appartient la SIM
  final String? shopDesignation;
  
  // Informations agent
  final int agentId; // Agent qui a enregistré la transaction
  final String? agentUsername;
  
  // Informations client (complétées lors de la validation)
  final String? clientNom; // Nom du client qui est servi
  final String? clientTelephone; // Numéro du client
  
  // Statut de la transaction
  final VirtualTransactionStatus statut;
  
  // Dates et tracking
  final DateTime dateEnregistrement; // Date d'enregistrement de la capture
  final DateTime? dateValidation; // Date de validation (quand le client est servi)
  final String? notes;
  
  // Synchronization
  final DateTime? lastModifiedAt;
  final String? lastModifiedBy;
  final bool isSynced;
  final DateTime? syncedAt;
  
  // Transaction administrative (n'impacte pas le cash disponible)
  final bool isAdministrative;

  VirtualTransactionModel({
    this.id,
    required String reference, // Normalized reference
    required this.montantVirtuel,
    this.frais = 0.0,
    required this.montantCash,
    this.devise = 'USD',
    required this.simNumero,
    required this.shopId,
    this.shopDesignation,
    required this.agentId,
    this.agentUsername,
    this.clientNom,
    this.clientTelephone,
    this.statut = VirtualTransactionStatus.enAttente,
    required this.dateEnregistrement,
    this.dateValidation,
    this.notes,
    this.lastModifiedAt,
    this.lastModifiedBy,
    this.isSynced = false,
    this.syncedAt,
    this.isAdministrative = false, // Par défaut: transaction normale
  }) : reference = reference.trim().toLowerCase();

  VirtualTransactionModel copyWith({
    int? id,
    String? reference,
    double? montantVirtuel,
    double? frais,
    double? montantCash,
    String? devise,
    String? simNumero,
    int? shopId,
    String? shopDesignation,
    int? agentId,
    String? agentUsername,
    String? clientNom,
    String? clientTelephone,
    VirtualTransactionStatus? statut,
    DateTime? dateEnregistrement,
    DateTime? dateValidation,
    bool clearDateValidation = false,
    String? notes,
    DateTime? lastModifiedAt,
    String? lastModifiedBy,
    bool? isSynced,
    DateTime? syncedAt,
    bool? isAdministrative,
  }) {
    return VirtualTransactionModel(
      id: id ?? this.id,
      reference: reference != null ? reference.trim().toLowerCase() : this.reference,
      montantVirtuel: montantVirtuel ?? this.montantVirtuel,
      frais: frais ?? this.frais,
      montantCash: montantCash ?? this.montantCash,
      devise: devise ?? this.devise,
      simNumero: simNumero ?? this.simNumero,
      shopId: shopId ?? this.shopId,
      shopDesignation: shopDesignation ?? this.shopDesignation,
      agentId: agentId ?? this.agentId,
      agentUsername: agentUsername ?? this.agentUsername,
      clientNom: clientNom ?? this.clientNom,
      clientTelephone: clientTelephone ?? this.clientTelephone,
      statut: statut ?? this.statut,
      dateEnregistrement: dateEnregistrement ?? this.dateEnregistrement,
      dateValidation: clearDateValidation ? null : (dateValidation ?? this.dateValidation),
      notes: notes ?? this.notes,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      lastModifiedBy: lastModifiedBy ?? this.lastModifiedBy,
      isSynced: isSynced ?? this.isSynced,
      syncedAt: syncedAt ?? this.syncedAt,
      isAdministrative: isAdministrative ?? this.isAdministrative,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'reference': reference,
      'montant_virtuel': montantVirtuel,
      'frais': frais,
      'montant_cash': montantCash,
      'devise': devise,
      'sim_numero': simNumero,
      'shop_id': shopId,
      'shop_designation': shopDesignation,
      'agent_id': agentId,
      'agent_username': agentUsername,
      'client_nom': clientNom,
      'client_telephone': clientTelephone,
      'statut': statut.name,
      'date_enregistrement': dateEnregistrement.toIso8601String(),
      'date_validation': dateValidation?.toIso8601String(),
      'notes': notes,
      'last_modified_at': lastModifiedAt?.toIso8601String(),
      'last_modified_by': lastModifiedBy,
      'is_synced': isSynced ? 1 : 0,
      'synced_at': syncedAt?.toIso8601String(),
      'is_administrative': isAdministrative ? 1 : 0,
    };
  }

  factory VirtualTransactionModel.fromJson(Map<String, dynamic> json) {
    // Gérer is_synced qui peut être bool (serveur) ou int (local)
    bool isSynced = false;
    if (json['is_synced'] != null) {
      if (json['is_synced'] is bool) {
        isSynced = json['is_synced'] as bool;
      } else if (json['is_synced'] is int) {
        isSynced = (json['is_synced'] as int) == 1;
      }
    }
    
    return VirtualTransactionModel(
      id: json['id'] as int?,
      reference: ((json['reference'] as String?) ?? '').trim().toLowerCase(),
      montantVirtuel: (json['montant_virtuel'] as num?)?.toDouble() ?? 0.0,
      frais: (json['frais'] as num?)?.toDouble() ?? 0.0,
      montantCash: (json['montant_cash'] as num?)?.toDouble() ?? 0.0,
      devise: (json['devise'] as String?) ?? 'USD',
      simNumero: (json['sim_numero'] as String?) ?? '',
      shopId: (json['shop_id'] as int?) ?? 0,
      shopDesignation: json['shop_designation'] as String?,
      agentId: (json['agent_id'] as int?) ?? 0,
      agentUsername: json['agent_username'] as String?,
      clientNom: json['client_nom'] as String?,
      clientTelephone: json['client_telephone'] as String?,
      statut: VirtualTransactionStatus.values.firstWhere(
        (e) => e.name == json['statut'],
        orElse: () => VirtualTransactionStatus.enAttente,
      ),
      dateEnregistrement: json['date_enregistrement'] != null
          ? DateTime.parse(json['date_enregistrement'] as String)
          : DateTime.now(),
      dateValidation: json['date_validation'] != null
          ? DateTime.parse(json['date_validation'] as String)
          : null,
      notes: json['notes'] as String?,
      lastModifiedAt: json['last_modified_at'] != null
          ? DateTime.parse(json['last_modified_at'] as String)
          : null,
      lastModifiedBy: json['last_modified_by'] as String?,
      isSynced: isSynced,
      syncedAt: json['synced_at'] != null
          ? DateTime.parse(json['synced_at'] as String)
          : null,
      isAdministrative: json['is_administrative'] == 1 || json['is_administrative'] == true,
    );
  }

  String get statutLabel {
    switch (statut) {
      case VirtualTransactionStatus.enAttente:
        return 'En Attente';
      case VirtualTransactionStatus.validee:
        return 'Servie';
      case VirtualTransactionStatus.annulee:
        return 'Annulée';
    }
  }

  @override
  String toString() {
    return 'VirtualTransaction(id: $id, ref: $reference, montant: $montantVirtuel $devise, '
        'frais: $frais, cash: $montantCash, SIM: $simNumero, statut: ${statut.name})';
  }
}

enum VirtualTransactionStatus {
  enAttente, // Capture enregistrée, client pas encore servi
  validee,   // Client servi, cash donné
  annulee,   // Transaction annulée
}
