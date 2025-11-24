import 'package:flutter/material.dart';
import '../services/sync_service.dart';

/// Helper pour réinitialiser complètement les commissions
/// À utiliser une seule fois pour forcer le re-téléchargement depuis MySQL
class ResetCommissionsHelper {
  
  /// Supprime toutes les commissions en local et force un re-sync
  static Future<void> resetAndResyncCommissions() async {
    // Utiliser la méthode du SyncService
    await SyncService().resetCommissionsCache();
  }
  
  /// Widget bouton pour déclencher le reset (à ajouter temporairement dans l'admin)
  static Widget buildResetButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Réinitialiser les commissions?'),
            content: const Text(
              'Cela va supprimer toutes les commissions en local et les retélécharger depuis le serveur MySQL.\n\n'
              'Cette action est nécessaire pour corriger les shop_source_id et shop_destination_id.'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Réinitialiser'),
              ),
            ],
          ),
        );
        
        if (confirm == true) {
          try {
            await resetAndResyncCommissions();
            
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Commissions réinitialisées et resynchronisées'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Erreur: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      },
      icon: const Icon(Icons.refresh),
      label: const Text('Réinitialiser Commissions'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}
