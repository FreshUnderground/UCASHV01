import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import '../models/operation_model.dart';

/// Service de notification pour les opérations importantes
/// Fournit des notifications sonores, vibrantes et visuelles pour les opérations critiques
class OperationNotificationService extends ChangeNotifier {
  static final OperationNotificationService _instance = OperationNotificationService._internal();
  factory OperationNotificationService() => _instance;
  OperationNotificationService._internal();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late AudioPlayer _audioPlayer;
  
  bool _initialized = false;
  bool get initialized => _initialized;

  /// Initialise le service de notifications
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Initialiser les notifications
      _notificationsPlugin = FlutterLocalNotificationsPlugin();
      
      // Configuration pour Android
      const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
      
      // Configuration pour iOS/MacOS
      const darwinSettings = DarwinInitializationSettings();
      
      // Configuration globale
      const initSettings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
      );
      
      await _notificationsPlugin.initialize(
        initSettings,
        onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      );
      
      // Initialiser l'audio
      _audioPlayer = AudioPlayer();
      
      _initialized = true;
      debugPrint('✅ OperationNotificationService initialisé');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation du OperationNotificationService: $e');
    }
  }
  
  /// Gère les réponses aux notifications
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Gérer les actions sur les notifications si nécessaire
    debugPrint('Notification reçue: ${response.payload}');
  }
  
  /// Déclenche une notification pour une opération importante
  Future<void> notifyOperation(OperationModel operation) async {
    if (!_initialized) {
      debugPrint('⚠️ OperationNotificationService non initialisé');
      return;
    }
    
    try {
      // Vibration
      await _vibrate();
      
      // Son d'alerte
      await _playAlertSound();
      
      // Notification visuelle
      await _showNotification(operation);
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la notification de l\'opération: $e');
    }
  }
  
  /// Vibration d'alerte
  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Vibration pattern: long - short - long
        await Vibration.vibrate(
          pattern: [0, 500, 200, 500],
        );
      }
    } catch (e) {
      debugPrint('⚠️ Vibration non disponible: $e');
    }
  }
  
  /// Joue un son d'alerte
  Future<void> _playAlertSound() async {
    try {
      // Play a beep sound using AudioPlayer
      await _audioPlayer.play(AssetSource('sounds/notification.mp3'));
    } catch (e) {
      debugPrint('⚠️ Son non disponible: $e');
      // Fallback to system beep if custom sound fails
      try {
        // For now, we'll just log that we're trying to play a sound
        debugPrint('🎵 Playing system beep sound');
      } catch (e2) {
        debugPrint('⚠️ Son système non disponible: $e2');
      }
    }
  }
  
  /// Affiche une notification visuelle
  Future<void> _showNotification(OperationModel operation) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'operation_channel',
        'Opérations',
        channelDescription: 'Notifications pour les opérations importantes',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: false, // On gère la vibration séparément
      );
      
      const platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
        macOS: DarwinNotificationDetails(),
      );
      
      final title = _getOperationTitle(operation);
      final body = _getOperationBody(operation);
      
      await _notificationsPlugin.show(
        operation.id ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title,
        body,
        platformDetails,
        payload: operation.id?.toString(),
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'affichage de la notification: $e');
    }
  }
  
  /// Retourne le titre approprié pour l'opération
  String _getOperationTitle(OperationModel operation) {
    switch (operation.type) {
      case OperationType.transfertNational:
        return '💰 Transfert National';
      case OperationType.transfertInternationalSortant:
        return '🌍 Transfert International Sortant';
      case OperationType.transfertInternationalEntrant:
        return '🌍 Transfert International Entrant';
      case OperationType.depot:
        return '📥 Dépôt';
      case OperationType.retrait:
        return '📤 Retrait';
      case OperationType.virement:
        return '🔄 Virement';
    }
  }
  
  /// Retourne le corps approprié pour l'opération
  String _getOperationBody(OperationModel operation) {
    final amount = '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}';
    final client = operation.clientNom ?? 'Client';
    
    switch (operation.type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
      case OperationType.transfertInternationalEntrant:
        return '$amount vers ${operation.destinataire ?? "Inconnu"}';
      case OperationType.depot:
        return '$amount de $client';
      case OperationType.retrait:
        return '$amount pour $client';
      case OperationType.virement:
        return '$amount - Virement interne';
    }
  }
  
  /// Nettoie les ressources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}