import '../models/client_model.dart';

class InitialClientData {
  static List<ClientModel> getInitialClients() {
    // Retourne une liste vide - pas de données par défaut
    // Les clients seront créés uniquement par les utilisateurs
    return [];
  }
  
  static Future<void> initializeClientsIfEmpty() async {
    // Cette méthode sera appelée pour initialiser des clients de test
    // si aucun client n'existe
  }
}
