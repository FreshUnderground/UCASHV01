import '../models/operation_model.dart';

class InitialOperationsData {
  static List<OperationModel> getInitialOperations() {
    // Retourne une liste vide - pas de données par défaut
    // Les opérations seront créées uniquement par les utilisateurs
    return [];
  }
  
  static Future<void> initializeOperationsIfEmpty() async {
    // Cette méthode sera appelée pour initialiser des données de test
    // si aucune opération n'existe
  }
}
