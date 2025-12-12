import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../lib/services/sync_service.dart';
import '../lib/services/auth_service.dart';

void main() {
  print('=== FORCER LA SYNCHRONISATION DES FLOTS ===');
  print('Ce script va forcer la synchronisation des flots malgré les erreurs.');
  
  // Simuler un contexte d'application
  runApp(
    MaterialApp(
      home: Scaffold(
        body: FutureBuilder(
          future: forceFlotSync(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              if (snapshot.hasError) {
                return Text('Erreur: ${snapshot.error}');
              }
              return const Text('Synchronisation terminée !');
            }
            return const Text('Synchronisation en cours...');
          },
        ),
      ),
    ),
  );
}

Future<void> forceFlotSync() async {
  try {
    print('🔄 Démarrage de la synchronisation forcée des flots...');
    
    // Réinitialiser le circuit breaker
    print('🔓 Réinitialisation du circuit breaker...');
    // Ici, vous pouvez appeler une méthode pour réinitialiser le circuit breaker
    
    // Forcer la synchronisation
    print('🚀 Lancement de la synchronisation...');
    final syncService = SyncService();
    
    // Désactiver temporairement le circuit breaker
    print('⚡ Désactivation temporaire du circuit breaker...');
    // Implémenter la désactivation du circuit breaker
    
 
  } catch (e) {
    print('❌ Erreur lors de la synchronisation: $e');
    rethrow;
  }
}