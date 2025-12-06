import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

/// Service de notification pour les conflits de synchronisation
/// Fournit des notifications sonores, vibrantes et visuelles pour les conflits détectés
class ConflictNotificationService extends ChangeNotifier {
  static final ConflictNotificationService _instance = ConflictNotificationService._internal();
  factory ConflictNotificationService() => _instance;
  ConflictNotificationService._internal();

  late FlutterLocalNotificationsPlugin _notificationsPlugin;
  late AudioPlayer _audioPlayer;
  
  bool _initialized = false;
  bool get initialized => _initialized;
  
  // Track if sound asset is available to avoid repeated error logs
  bool _soundAssetChecked = false;
  bool _soundAssetAvailable = false;

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
      debugPrint('✅ ConflictNotificationService initialisé');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation du ConflictNotificationService: $e');
    }
  }
  
  /// Gère les réponses aux notifications
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    // Gérer les actions sur les notifications si nécessaire
    debugPrint('Notification de conflit reçue: ${response.payload}');
  }
  
  /// Déclenche une notification pour un conflit détecté
  Future<void> notifyConflict({
    required String tableName,
    required dynamic entityId,
    required DateTime localModified,
    required DateTime remoteModified,
    String? localDataPreview,
    String? remoteDataPreview,
  }) async {
    if (!_initialized) {
      debugPrint('⚠️ ConflictNotificationService non initialisé');
      return;
    }
    
    try {
      // Vibration
      await _vibrate();
      
      // Son d'alerte
      await _playAlertSound();
      
      // Notification visuelle
      await _showNotification(
        tableName: tableName,
        entityId: entityId,
        localModified: localModified,
        remoteModified: remoteModified,
        localDataPreview: localDataPreview,
        remoteDataPreview: remoteDataPreview,
      );
      
    } catch (e) {
      debugPrint('❌ Erreur lors de la notification du conflit: $e');
    }
  }
  
  /// Vibration d'alerte
  Future<void> _vibrate() async {
    try {
      if (await Vibration.hasVibrator() ?? false) {
        // Vibration pattern: short - pause - short - pause - long
        await Vibration.vibrate(
          pattern: [0, 300, 200, 300, 200, 500],
        );
      }
    } catch (e) {
      debugPrint('⚠️ Vibration non disponible: $e');
    }
  }
  
  /// Joue un son d'alerte
  Future<void> _playAlertSound() async {
    // Skip if we already know the sound asset is not available
    if (_soundAssetChecked && !_soundAssetAvailable) {
      return;
    }
    
    try {
      // Play a warning sound using AudioPlayer
      await _audioPlayer.play(AssetSource('sounds/conflict_warning.mp3'));
      _soundAssetChecked = true;
      _soundAssetAvailable = true;
    } catch (e) {
      // Only log the error once
      if (!_soundAssetChecked) {
        debugPrint('ℹ️ Son de conflit non configuré (sounds/conflict_warning.mp3)');
        _soundAssetChecked = true;
        _soundAssetAvailable = false;
      }
      // Silently continue - vibration and notification still work
    }
  }
  
  /// Affiche une notification visuelle
  Future<void> _showNotification({
    required String tableName,
    required dynamic entityId,
    required DateTime localModified,
    required DateTime remoteModified,
    String? localDataPreview,
    String? remoteDataPreview,
  }) async {
    try {
      const androidDetails = AndroidNotificationDetails(
        'conflict_channel',
        'Conflits de Synchronisation',
        channelDescription: 'Notifications pour les conflits de synchronisation détectés',
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
      
      final title = '⚠️ Conflit de Synchronisation';
      final body = 'Conflit détecté dans $tableName (ID: $entityId)\n'
          'Local: ${localModified.toIso8601String()}\n'
          'Serveur: ${remoteModified.toIso8601String()}';
      
      await _notificationsPlugin.show(
        entityId.hashCode ^ tableName.hashCode, // Unique ID based on entity and table
        title,
        body,
        platformDetails,
        payload: '$tableName:$entityId',
      );
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'affichage de la notification de conflit: $e');
    }
  }
  
  /// Nettoie les ressources
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
}