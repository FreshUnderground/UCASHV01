import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operation_model.dart';
import 'auth_service.dart';

/// Service de notification pour les transferts entrants
/// Vérifie en permanence les nouveaux transferts destinés au shop de l'utilisateur
class TransferNotificationService extends ChangeNotifier {
  static final TransferNotificationService _instance = TransferNotificationService._internal();
  factory TransferNotificationService() => _instance;
  TransferNotificationService._internal();

  Timer? _checkTimer;
  static const Duration _checkInterval = Duration(seconds: 10); // Vérifier toutes les 10 secondes
  
  final List<int> _notifiedTransferIds = [];
  int _pendingTransfersCount = 0;
  
  // Référence aux opérations (injectée depuis l'extérieur)
  List<OperationModel> Function()? _getOperations;
  
  int get pendingTransfersCount => _pendingTransfersCount;
  
  // Callback pour afficher une notification
  void Function(String title, String message, int transferId)? onNewTransferDetected;
  
  /// Démarre la vérification automatique des transferts entrants
  void startMonitoring({
    required AuthService authService,
    required List<OperationModel> Function() getOperations,
  }) {
    stopMonitoring();
    
    final currentShopId = authService.currentUser?.shopId;
    if (currentShopId == null) {
      debugPrint('⚠️ TransferNotificationService: Aucun shop ID, impossible de démarrer la surveillance');
      return;
    }
    
    // Stocker la référence pour accéder aux opérations
    _getOperations = getOperations;
    
    debugPrint('🔔 TransferNotificationService: Démarrage de la surveillance des transferts pour shop $currentShopId');
    
    // Charger les IDs déjà notifiés depuis le stockage
    _loadNotifiedTransferIds();
    
    // Vérifier immédiatement
    _checkForNewTransfers(currentShopId);
    
    // Démarrer le timer périodique
    _checkTimer = Timer.periodic(_checkInterval, (timer) {
      _checkForNewTransfers(currentShopId);
    });
  }
  
  /// Arrête la surveillance
  void stopMonitoring() {
    if (_checkTimer != null) {
      debugPrint('🔔 TransferNotificationService: Arrêt de la surveillance');
      _checkTimer?.cancel();
      _checkTimer = null;
    }
  }
  
  /// Vérifie les nouveaux transferts en attente
  void _checkForNewTransfers(int shopId) {
    try {
      // Vérifier que nous avons accès aux opérations
      if (_getOperations == null) {
        debugPrint('⚠️ Pas d\'accès aux opérations, attente...');
        return;
      }
      
      final allOperations = _getOperations!();
      debugPrint('📊 Vérification transferts: ${allOperations.length} opérations en mémoire');
      
      // Récupérer les transferts en attente pour ce shop
      final pendingTransfers = allOperations.where((operation) {
        return operation.statut == OperationStatus.enAttente &&
               (operation.type == OperationType.transfertNational ||
                operation.type == OperationType.transfertInternationalSortant ||
                operation.type == OperationType.transfertInternationalEntrant) &&
               operation.shopDestinationId == shopId;
      }).toList();
      
      debugPrint('🔍 ${pendingTransfers.length} transferts en attente pour shop $shopId');
      
      // Mettre à jour le compteur
      final oldCount = _pendingTransfersCount;
      _pendingTransfersCount = pendingTransfers.length;
      
      if (_pendingTransfersCount != oldCount) {
        notifyListeners();
      }
      
      // Vérifier les nouveaux transferts (non encore notifiés)
      for (final transfer in pendingTransfers) {
        // Ignorer les transferts sans ID
        if (transfer.id == null) {
          debugPrint('⚠️ Transfert sans ID ignoré');
          continue;
        }
        
        if (!_notifiedTransferIds.contains(transfer.id)) {
          debugPrint('🔔 Nouveau transfert détecté: ID ${transfer.id}, Montant: ${transfer.montantNet} ${transfer.devise}');
          debugPrint('   Source: ${transfer.shopSourceDesignation ?? "Inconnu"} -> Destination: ${transfer.shopDestinationDesignation ?? "Inconnu"}');
          debugPrint('   Destinataire: ${transfer.destinataire ?? "Non spécifié"}');
          
          // Marquer comme notifié
          _notifiedTransferIds.add(transfer.id!);
          _saveNotifiedTransferIds();
          
          // Déclencher le callback
          if (onNewTransferDetected != null) {
            final sourceShopName = transfer.shopSourceDesignation ?? 'Shop Inconnu';
            onNewTransferDetected!(
              '💰 Nouveau Transfert Reçu',
              '${transfer.montantNet} ${transfer.devise} de $sourceShopName\nDestinataire: ${transfer.destinataire ?? "Non spécifié"}',
              transfer.id!,
            );
          }
          
          notifyListeners();
        }
      }
      
      // Nettoyer les IDs des transferts déjà validés/annulés
      _cleanupNotifiedIds(allOperations);
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification des transferts: $e');
    }
  }
  
  /// Nettoie les IDs des transferts qui ne sont plus en attente
  void _cleanupNotifiedIds(List<OperationModel> allOperations) {
    final pendingIds = allOperations
        .where((op) => op.statut == OperationStatus.enAttente && op.id != null)
        .map((op) => op.id!)
        .toSet();
    
    final initialCount = _notifiedTransferIds.length;
    _notifiedTransferIds.removeWhere((id) => !pendingIds.contains(id));
    
    if (_notifiedTransferIds.length != initialCount) {
      _saveNotifiedTransferIds();
      debugPrint('🧹 Nettoyage: ${initialCount - _notifiedTransferIds.length} IDs supprimés');
    }
  }
  
  /// Charge les IDs déjà notifiés depuis SharedPreferences
  Future<void> _loadNotifiedTransferIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsJson = prefs.getStringList('notified_transfer_ids') ?? [];
      _notifiedTransferIds.clear();
      _notifiedTransferIds.addAll(idsJson.map((id) => int.parse(id)));
      debugPrint('📋 ${_notifiedTransferIds.length} transferts déjà notifiés chargés');
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement des IDs notifiés: $e');
    }
  }
  
  /// Sauvegarde les IDs notifiés dans SharedPreferences
  Future<void> _saveNotifiedTransferIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'notified_transfer_ids',
        _notifiedTransferIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la sauvegarde des IDs notifiés: $e');
    }
  }
  
  /// Réinitialise les notifications (utile après une validation)
  void resetNotifications() {
    _notifiedTransferIds.clear();
    _saveNotifiedTransferIds();
    _pendingTransfersCount = 0;
    notifyListeners();
    debugPrint('🔄 Notifications réinitialisées');
  }
  
  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
