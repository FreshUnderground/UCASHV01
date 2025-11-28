import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Script pour mettre à jour tous les clients existants avec le flag isSynced = false
/// Cela permettra de synchroniser tous les clients existants vers le serveur

void main() async {
  print('🔧 Début de la mise à jour des flags de synchronisation des clients...');
  
  try {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('client_')).toList();
    
    print('📊 Nombre de clients trouvés: ${keys.length}');
    
    int updated = 0;
    for (final key in keys) {
      final clientJson = prefs.getString(key);
      if (clientJson != null) {
        try {
          final clientData = jsonDecode(clientJson);
          
          // Ajouter les champs de synchronisation
          clientData['is_synced'] = 0; // false
          clientData['synced_at'] = null;
          
          // Sauvegarder
          await prefs.setString(key, jsonEncode(clientData));
          updated++;
          
          print('✅ Client mis à jour: ${clientData['nom']} (ID: ${clientData['id']})');
        } catch (e) {
          print('❌ Erreur lors de la mise à jour du client $key: $e');
        }
      }
    }
    
    print('\n✅ Mise à jour terminée: $updated/$keys.length clients mis à jour');
    print('🚀 Lancez une synchronisation pour envoyer les clients vers le serveur');
  } catch (e) {
    print('❌ Erreur: $e');
  }
}
