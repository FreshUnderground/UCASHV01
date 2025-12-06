import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operation_model.dart';

/// Service de notification pour les flots entrants
/// Vérifie en permanence les nouveaux flots destinés au shop de l'utilisateur
/// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
class FlotNotificationService extends ChangeNotifier {
  static final FlotNotificationService _instance = FlotNotificationService._internal();
  factory FlotNotificationService() => _instance;
  FlotNotificationService._internal();

  Timer? _checkTimer;
  static const Duration _checkInterval = Duration(seconds: 10); // Vérifier toutes les 10 secondes
  
  final List<int> _notifiedFlotIds = [];
  int _pendingFlotsCount = 0;
  
  // Référence aux flots (injectée depuis l'extérieur)
  List<OperationModel> Function()? _getFlots;
  
  int get pendingFlotsCount => _pendingFlotsCount;
  
  // Callback pour afficher une notification
  void Function(String title, String message, int flotId)? onNewFlotDetected;
  
  /// Démarre la vérification automatique des flots entrants
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  void startMonitoring({
    required int shopId,
    required List<OperationModel> Function() getFlots,
  }) {
    stopMonitoring();
    
    if (shopId <= 0) {
      debugPrint('⚠️ FlotNotificationService: Shop ID invalide ($shopId), impossible de démarrer la surveillance');
      return;
    }
    
    final currentShopId = shopId;
    
    // Stocker la référence pour accéder aux flots
    _getFlots = getFlots;
    
    debugPrint('🔔 FlotNotificationService: Démarrage de la surveillance des flots pour shop $shopId');
    debugPrint('   NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop');
    
    // Charger les IDs déjà notifiés depuis le stockage
    _loadNotifiedFlotIds();
    
    // Vérifier immédiatement
    _checkForNewFlots(currentShopId);
    
    // Démarrer le timer périodique
    _checkTimer = Timer.periodic(_checkInterval, (timer) {
      _checkForNewFlots(currentShopId);
    });
  }
  
  /// Arrête la surveillance
  void stopMonitoring() {
    if (_checkTimer != null) {
      debugPrint('🔔 FlotNotificationService: Arrêt de la surveillance');
      _checkTimer?.cancel();
      _checkTimer = null;
    }
  }
  
  /// Vérifie les nouveaux flots en route
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  void _checkForNewFlots(int shopId) {
    try {
      // Vérifier que nous avons accès aux flots
      if (_getFlots == null) {
        debugPrint('⚠️ Pas d\'accès aux flots, attente...');
        return;
      }
      
      final allFlots = _getFlots!();
      debugPrint('📊 Vérification flots: ${allFlots.length} flots en mémoire');
      debugPrint('   NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop');
      
      // Récupérer les flots en route pour ce shop (destination)
      final pendingFlots = allFlots.where((flot) {
        return flot.statut == OperationStatus.enAttente &&
               flot.type == OperationType.flotShopToShop &&
               flot.shopDestinationId == shopId;
      }).toList();
      
      debugPrint('🔍 ${pendingFlots.length} flots en route pour shop $shopId');
      debugPrint('   NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop');
      
      // Mettre à jour le compteur
      final oldCount = _pendingFlotsCount;
      _pendingFlotsCount = pendingFlots.length;
      
      if (_pendingFlotsCount != oldCount) {
        notifyListeners();
      }
      
      // Vérifier les nouveaux flots (non encore notifiés)
      bool hasNewFlots = false;
      for (final flot in pendingFlots) {
        // Ignorer les flots sans ID
        if (flot.id == null) {
          debugPrint('⚠️ Flot sans ID ignoré');
          continue;
        }
        
        if (!_notifiedFlotIds.contains(flot.id)) {
          debugPrint('🔔 Nouveau flot détecté: ID ${flot.id}, Montant: ${flot.montantNet} ${flot.devise}');
          debugPrint('   Source: ${flot.shopSourceDesignation} -> Destination: ${flot.shopDestinationDesignation}');
          debugPrint('   Envoyé par: ${flot.agentUsername ?? "Inconnu"}');
          debugPrint('   NOTE: Ce flot est maintenant une operation avec type=flotShopToShop');
          
          // Marquer comme notifié
          _notifiedFlotIds.add(flot.id!);
          _saveNotifiedFlotIds();
          
          // Déclencher le callback
          if (onNewFlotDetected != null) {
            final sourceShopName = flot.shopSourceDesignation;
            final modePaiement = _getModePaiementLabel(flot.modePaiement);
            onNewFlotDetected!(
              '💸 Nouveau FLOT Reçu',
              '${flot.montantNet} ${flot.devise} ($modePaiement) de $sourceShopName\n${flot.notes != null && flot.notes!.isNotEmpty ? "Note: ${flot.notes}" : ""}',
              flot.id!,
            );
          }
          
          hasNewFlots = true;
          notifyListeners();
        }
      }
      
      // Si de nouveaux flots ont été détectés, forcer un rafraîchissement
      if (hasNewFlots) {
        // Trigger a refresh event that can be listened to by other services
        // This will help ensure TransferSyncService gets updated data
        notifyListeners();
      }
      
      // Nettoyer les IDs des flots déjà servis/annulés
      _cleanupNotifiedIds(allFlots);
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification des flots: $e');
    }
  }
  
  /// Convertit le mode de paiement en label lisible
  String _getModePaiementLabel(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }
  
  /// Nettoie les IDs des flots qui ne sont plus en route
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  void _cleanupNotifiedIds(List<OperationModel> allFlots) {
    final pendingIds = allFlots
        .where((flot) => flot.statut == OperationStatus.enAttente && 
                         flot.type == OperationType.flotShopToShop && 
                         flot.id != null)
        .map((flot) => flot.id!)
        .toSet();
    
    final initialCount = _notifiedFlotIds.length;
    _notifiedFlotIds.removeWhere((id) => !pendingIds.contains(id));
    
    if (_notifiedFlotIds.length != initialCount) {
      _saveNotifiedFlotIds();
      debugPrint('🧹 Nettoyage: ${initialCount - _notifiedFlotIds.length} IDs supprimés');
    }
  }
  
  /// Charge les IDs déjà notifiés depuis SharedPreferences
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  Future<void> _loadNotifiedFlotIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final idsJson = prefs.getStringList('notified_flot_ids') ?? [];
      _notifiedFlotIds.clear();
      _notifiedFlotIds.addAll(idsJson.map((id) => int.parse(id)));
      debugPrint('📋 ${_notifiedFlotIds.length} flots déjà notifiés chargés');
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement des IDs notifiés: $e');
    }
  }
  
  /// Sauvegarde les IDs notifiés dans SharedPreferences
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  Future<void> _saveNotifiedFlotIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(
        'notified_flot_ids',
        _notifiedFlotIds.map((id) => id.toString()).toList(),
      );
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la sauvegarde des IDs notifiés: $e');
    }
  }
  
  /// Réinitialise les notifications (utile après réception d'un flot)
  /// NOTE: Les flots sont maintenant gérés comme des operations avec type=flotShopToShop
  void resetNotifications() {
    _notifiedFlotIds.clear();
    _saveNotifiedFlotIds();
    _pendingFlotsCount = 0;
    notifyListeners();
    debugPrint('🔄 Notifications de flots réinitialisées');
  }
  
  @override
  void dispose() {
    stopMonitoring();
    super.dispose();
  }
}
