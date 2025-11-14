/// Modèle de base pour tous les objets synchronisables
/// Ajoute les champs nécessaires pour la synchronisation offline/online
abstract class SyncableModel {
  final bool isSynced;
  final DateTime lastModifiedAt;
  final String lastModifiedBy;
  final DateTime? syncedAt;
  final String? syncId; // ID unique pour éviter les doublons

  const SyncableModel({
    this.isSynced = false,
    required this.lastModifiedAt,
    required this.lastModifiedBy,
    this.syncedAt,
    this.syncId,
  });

  /// Convertit en Map pour la base de données locale
  Map<String, dynamic> toSyncJson();

  /// Crée une instance depuis la base de données locale
  static SyncableModel fromSyncJson(Map<String, dynamic> json) {
    throw UnimplementedError('fromSyncJson doit être implémenté dans chaque modèle');
  }

  /// Marque l'objet comme synchronisé
  SyncableModel markAsSynced() {
    throw UnimplementedError('markAsSynced doit être implémenté dans chaque modèle');
  }

  /// Met à jour les informations de modification
  SyncableModel updateModification(String userId) {
    throw UnimplementedError('updateModification doit être implémenté dans chaque modèle');
  }

  /// Détermine si cet objet a priorité sur un autre en cas de conflit
  bool hasPriorityOver(SyncableModel other) {
    return lastModifiedAt.isAfter(other.lastModifiedAt);
  }

  /// Génère un ID de synchronisation unique
  static String generateSyncId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}';
  }
}

/// Énumération des types d'entités synchronisables
enum SyncEntityType {
  shop,
  agent,
  client,
  compte,
  operation,
  caisse,
  capitalShop,
  detteCreance,
  commission,
  rapport,
}

/// Ordre de synchronisation respectant les dépendances métier UCASH
class SyncOrder {
  static const List<SyncEntityType> uploadOrder = [
    SyncEntityType.shop,        // 1. Shops (base)
    SyncEntityType.agent,       // 2. Agents (dépendent des shops)
    SyncEntityType.client,      // 3. Clients (dépendent des shops)
    SyncEntityType.compte,      // 4. Comptes (dépendent des clients)
    SyncEntityType.operation,   // 5. Transactions (dépendent de tout)
    SyncEntityType.caisse,      // 6. Caisses (dépendent des transactions)
    SyncEntityType.capitalShop, // 7. Capital shops (dépendent des transactions)
    SyncEntityType.detteCreance,// 8. Dettes/créances (dépendent des transactions)
    SyncEntityType.commission,  // 9. Commissions (dépendent des transactions)
    SyncEntityType.rapport,     // 10. Rapports (dépendent de tout)
  ];

  static const List<SyncEntityType> downloadOrder = uploadOrder; // Même ordre
}
