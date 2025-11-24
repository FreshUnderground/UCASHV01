import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flot_model.dart' as flot_model;
import 'agent_auth_service.dart';

/// Service de notification pour les flots entrants
/// Vérifie en permanence les nouveaux flots destinés au shop de l'utilisateur
class FlotNotificationService extends ChangeNotifier {
  static final FlotNotificationService _instance = FlotNotificationService._internal();
  factory FlotNotificationService() => _instance;
  FlotNotificationService._internal();

  Timer? _checkTimer;
  static const Duration _checkInterval = Duration(seconds: 10); // Vérifier toutes les 10 secondes
  
  final List<int> _notifiedFlotIds = [];
  int _pendingFlotsCount = 0;
  
  // Référence aux flots (injectée depuis l'extérieur)
  List<flot_model.FlotModel> Function()? _getFlots;
  
  int get pendingFlotsCount => _pendingFlotsCount;
  
  // Callback pour afficher une notification
  void Function(String title, String message, int flotId)? onNewFlotDetected;
  
  /// Démarre la vérification automatique des flots entrants
  void startMonitoring({
    required AgentAuthService authService,
    required List<flot_model.FlotModel> Function() getFlots,
  }) {
    stopMonitoring();
    
    final currentShopId = authService.currentAgent?.shopId;
    if (currentShopId == null) {
      debugPrint('⚠️ FlotNotificationService: Aucun shop ID, impossible de démarrer la surveillance');
      return;
    }
    
    // Stocker la référence pour accéder aux flots
    _getFlots = getFlots;
    
    debugPrint('🔔 FlotNotificationService: Démarrage de la surveillance des flots pour shop $currentShopId');
    
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
  void _checkForNewFlots(int shopId) {
    try {
      // Vérifier que nous avons accès aux flots
      if (_getFlots == null) {
        debugPrint('⚠️ Pas d\'accès aux flots, attente...');
        return;
      }
      
      final allFlots = _getFlots!();
      debugPrint('📊 Vérification flots: ${allFlots.length} flots en mémoire');
      
      // Récupérer les flots en route pour ce shop (destination)
      final pendingFlots = allFlots.where((flot) {
        return flot.statut == flot_model.StatutFlot.enRoute &&
               flot.shopDestinationId == shopId;
      }).toList();
      
      debugPrint('🔍 ${pendingFlots.length} flots en route pour shop $shopId');
      
      // Mettre à jour le compteur
      final oldCount = _pendingFlotsCount;
      _pendingFlotsCount = pendingFlots.length;
      
      if (_pendingFlotsCount != oldCount) {
        notifyListeners();
      }
      
      // Vérifier les nouveaux flots (non encore notifiés)
      for (final flot in pendingFlots) {
        // Ignorer les flots sans ID
        if (flot.id == null) {
          debugPrint('⚠️ Flot sans ID ignoré');
          continue;
        }
        
        if (!_notifiedFlotIds.contains(flot.id)) {
          debugPrint('🔔 Nouveau flot détecté: ID ${flot.id}, Montant: ${flot.montant} ${flot.devise}');
          debugPrint('   Source: ${flot.shopSourceDesignation} -> Destination: ${flot.shopDestinationDesignation}');
          debugPrint('   Envoyé par: ${flot.agentEnvoyeurUsername ?? "Inconnu"}');
          
          // Marquer comme notifié
          _notifiedFlotIds.add(flot.id!);
          _saveNotifiedFlotIds();
          
          // Déclencher le callback
          if (onNewFlotDetected != null) {
            final sourceShopName = flot.shopSourceDesignation;
            final modePaiement = _getModePaiementLabel(flot.modePaiement);
            onNewFlotDetected!(
              '💸 Nouveau FLOT Reçu',
              '${flot.montant} ${flot.devise} ($modePaiement) de $sourceShopName\n${flot.notes != null && flot.notes!.isNotEmpty ? "Note: ${flot.notes}" : ""}',
              flot.id!,
            );
          }
          
          notifyListeners();
        }
      }
      
      // Nettoyer les IDs des flots déjà servis/annulés
      _cleanupNotifiedIds(allFlots);
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la vérification des flots: $e');
    }
  }
  
  /// Convertit le mode de paiement en label lisible
  String _getModePaiementLabel(flot_model.ModePaiement mode) {
    switch (mode) {
      case flot_model.ModePaiement.cash:
        return 'Cash';
      case flot_model.ModePaiement.airtelMoney:
        return 'Airtel Money';
      case flot_model.ModePaiement.mPesa:
        return 'M-Pesa';
      case flot_model.ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }
  
  /// Nettoie les IDs des flots qui ne sont plus en route
  void _cleanupNotifiedIds(List<flot_model.FlotModel> allFlots) {
    final pendingIds = allFlots
        .where((flot) => flot.statut == flot_model.StatutFlot.enRoute && flot.id != null)
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
