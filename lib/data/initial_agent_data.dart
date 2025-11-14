import 'package:flutter/foundation.dart';
import '../models/agent_model.dart';
import '../models/client_model.dart';
import '../services/local_db.dart';

class InitialAgentData {
  static List<AgentModel> getInitialAgents() {
    // Retourne une liste vide - pas de données par défaut
    // Les agents seront créés uniquement par l'administrateur
    return [];
  }

  static List<ClientModel> getInitialClients() {
    // Retourne une liste vide - pas de données par défaut
    // Les clients seront créés uniquement par les agents
    return [];
  }

  /// Initialise les données d'agents et clients de test
  static Future<void> initializeAgentData() async {
    try {
      debugPrint('🔄 Initialisation des données Agent UCASH...');
      
      // Utiliser LocalDB directement
      final localDB = LocalDB.instance;
      
      // Vérifier si des agents existent déjà
      final existingAgents = await localDB.getAllAgents();
      if (existingAgents.isNotEmpty) {
        debugPrint('✅ Agents déjà présents (${existingAgents.length} agents)');
        return;
      }
      
      // Créer les agents
      final agents = getInitialAgents();
      for (final agent in agents) {
        await localDB.saveAgent(agent);
      }
      debugPrint('✅ ${agents.length} agents créés avec succès');
      
      // Créer les clients
      final clients = getInitialClients();
      for (final client in clients) {
        await localDB.saveClient(client);
      }
      debugPrint('✅ ${clients.length} clients créés avec succès');
      
      debugPrint('🎉 Données Agent UCASH initialisées (aucune donnée par défaut)');
      
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'initialisation des données Agent: $e');
    }
  }
}
