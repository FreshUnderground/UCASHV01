import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService extends ChangeNotifier {
  static final ConnectivityService _instance = ConnectivityService._internal();
  static ConnectivityService get instance => _instance;
  
  ConnectivityService._internal() {
    _initConnectivityListener();
    _checkInitialConnectivity();
  }

  bool _isOnline = true;
  Timer? _connectivityTimer;
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  bool get isOnline => _isOnline;
  String get statusText => _isOnline ? 'En ligne' : 'Hors ligne';

  void _initConnectivityListener() {
    // Écouter les changements de connectivité avec connectivity_plus
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
      final isConnected = result != ConnectivityResult.none;
      _updateConnectivity(isConnected);
    });
    
    // Vérification périodique de la connectivité
    _connectivityTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _checkConnectivity();
    });
  }

  void _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _isOnline = result != ConnectivityResult.none;
      notifyListeners();
    } catch (e) {
      debugPrint('Erreur vérification connectivité: $e');
      _isOnline = true; // Par défaut, considérer connecté
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      final isConnected = result != ConnectivityResult.none;
      _updateConnectivity(isConnected);
    } catch (e) {
      debugPrint('Erreur check connectivité: $e');
      _updateConnectivity(false);
    }
  }

  void _updateConnectivity(bool isConnected) {
    if (_isOnline != isConnected) {
      _isOnline = isConnected;
      notifyListeners();
      
      if (_isOnline) {
        _onConnectionRestored();
      }
    }
  }

  void _onConnectionRestored() {
    // Déclencher la synchronisation automatique quand la connexion est restaurée
    debugPrint('🌐 Connexion restaurée - Déclenchement de la synchronisation automatique...');
    
    // Déclencher la synchronisation avec un délai pour éviter les dépendances circulaires
    Timer(const Duration(seconds: 3), () {
      try {
        // TODO: Déclencher la synchronisation automatique
        // SyncService.instance.autoSync();
        debugPrint('🔄 Synchronisation automatique déclenchée');
      } catch (e) {
        debugPrint('Erreur lors du déclenchement de la synchronisation: $e');
      }
    });
  }

  /// Démarre la surveillance de connectivité
  void startMonitoring() {
    debugPrint('🌐 Démarrage de la surveillance de connectivité');
    _checkInitialConnectivity();
    
    // Démarrer un timer périodique pour vérifier la connectivité
    _connectivityTimer?.cancel();
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });
  }

  /// Arrête la surveillance de connectivité
  void stopMonitoring() {
    debugPrint('🌐 Arrêt de la surveillance de connectivité');
    _connectivityTimer?.cancel();
  }

  @override
  void dispose() {
    _connectivityTimer?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
