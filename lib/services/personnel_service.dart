import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/personnel_model.dart';
import '../models/salaire_model.dart';
import '../models/avance_personnel_model.dart';
import '../models/credit_personnel_model.dart';
import 'local_db.dart';

class PersonnelService extends ChangeNotifier {
  static final PersonnelService _instance = PersonnelService._internal();
  static PersonnelService get instance => _instance;
  
  PersonnelService._internal();

  List<PersonnelModel> _personnel = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<PersonnelModel> get personnel => _personnel;
  List<PersonnelModel> get personnelActif => _personnel.where((p) => p.statut == 'Actif').toList();
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? error) {
    _errorMessage = error;
    notifyListeners();
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  /// Charger tout le personnel
  Future<void> loadPersonnel({bool forceRefresh = false}) async {
    if (!forceRefresh && _personnel.isNotEmpty) {
      debugPrint('✅ [PersonnelService] Cache utilisé (${_personnel.length} employés)');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys().where((key) => key.startsWith('personnel_')).toList();
      
      _personnel.clear();
      
      for (var key in keys) {
        final jsonString = prefs.getString(key);
        if (jsonString != null) {
          try {
            final data = jsonDecode(jsonString);
            _personnel.add(PersonnelModel.fromJson(data));
          } catch (e) {
            debugPrint('⚠️ Erreur parsing personnel $key: $e');
          }
        }
      }

      // Trier par matricule
      _personnel.sort((a, b) => a.matricule.compareTo(b.matricule));
      
      debugPrint('✅ [PersonnelService] ${_personnel.length} employés chargés');
      notifyListeners();
    } catch (e) {
      _setError('Erreur chargement personnel: $e');
      debugPrint('❌ [PersonnelService] Erreur: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Créer un employé
  Future<PersonnelModel> createPersonnel(PersonnelModel personnel) async {
    try {
      final prefs = await LocalDB.instance.database;
      
      // Générer un ID unique
      int newId = DateTime.now().millisecondsSinceEpoch;
      
      // Vérifier que le matricule est unique
      await loadPersonnel();
      if (_personnel.any((p) => p.matricule == personnel.matricule)) {
        throw Exception('Matricule ${personnel.matricule} existe déjà');
      }

      final newPersonnel = personnel.copyWith(
        id: newId,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      // Sauvegarder
      await prefs.setString('personnel_$newId', jsonEncode(newPersonnel.toJson()));
      
      // Recharger la liste
      await loadPersonnel(forceRefresh: true);
      
      debugPrint('✅ Personnel créé: ${newPersonnel.nomComplet} (${newPersonnel.matricule})');
      return newPersonnel;
    } catch (e) {
      debugPrint('❌ Erreur création personnel: $e');
      rethrow;
    }
  }

  /// Mettre à jour un employé
  Future<PersonnelModel> updatePersonnel(PersonnelModel personnel) async {
    if (personnel.id == null) {
      throw Exception('ID personnel requis pour mise à jour');
    }

    try {
      final prefs = await LocalDB.instance.database;
      
      // Vérifier que l'employé existe
      final key = 'personnel_${personnel.id}';
      if (!prefs.containsKey(key)) {
        throw Exception('Personnel avec ID ${personnel.id} introuvable');
      }

      final updatedPersonnel = personnel.copyWith(
        lastModifiedAt: DateTime.now(),
        isSynced: false,
      );

      await prefs.setString(key, jsonEncode(updatedPersonnel.toJson()));
      
      // Recharger
      await loadPersonnel(forceRefresh: true);
      
      debugPrint('✅ Personnel mis à jour: ${updatedPersonnel.nomComplet}');
      return updatedPersonnel;
    } catch (e) {
      debugPrint('❌ Erreur mise à jour personnel: $e');
      rethrow;
    }
  }

  /// Supprimer un employé (soft delete - mettre statut Demissionne)
  /// Cette suppression sera synchronisée sur tous les appareils
  Future<void> deletePersonnel(int id) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'personnel_$id';
      
      final jsonString = prefs.getString(key);
      if (jsonString == null) {
        throw Exception('Personnel avec ID $id introuvable');
      }

      final personnel = PersonnelModel.fromJson(jsonDecode(jsonString));
      
      // Soft delete: changer le statut au lieu de supprimer
      final updatedPersonnel = personnel.copyWith(
        statut: 'Demissionne',
        lastModifiedAt: DateTime.now(),
        isSynced: false, // Marquer pour synchronisation
      );

      await prefs.setString(key, jsonEncode(updatedPersonnel.toJson()));
      
      // Marquer pour suppression définitive après sync
      await _markForDeletion(id, 'personnel');
      
      // Déclencher synchronisation immédiate
      await _triggerImmediateSync();
      
      // Recharger
      await loadPersonnel(forceRefresh: true);
      
      debugPrint('✅ Personnel supprimé (soft) et marqué pour sync: ${personnel.nomComplet}');
    } catch (e) {
      debugPrint('❌ Erreur suppression personnel: $e');
      rethrow;
    }
  }

  /// Supprimer définitivement un employé
  /// Cette méthode ne doit être appelée qu'après synchronisation
  Future<void> hardDeletePersonnel(int id) async {
    try {
      final prefs = await LocalDB.instance.database;
      
      // Supprimer l'enregistrement principal
      await prefs.remove('personnel_$id');
      
      // Supprimer le marqueur de suppression
      await prefs.remove('deletion_personnel_$id');
      
      // Supprimer les données liées (salaires, avances, retenues)
      await _deleteRelatedData(id);
      
      await loadPersonnel(forceRefresh: true);
      debugPrint('✅ Personnel supprimé définitivement: ID $id');
    } catch (e) {
      debugPrint('❌ Erreur suppression définitive: $e');
      rethrow;
    }
  }
  
  /// Marquer un enregistrement pour suppression après synchronisation
  Future<void> _markForDeletion(int id, String type) async {
    try {
      final prefs = await LocalDB.instance.database;
      final deletionRecord = {
        'id': id,
        'type': type,
        'marked_at': DateTime.now().toIso8601String(),
        'synced': false,
      };
      
      await prefs.setString('deletion_${type}_$id', jsonEncode(deletionRecord));
      debugPrint('🗑️ Marqué pour suppression: $type ID $id');
    } catch (e) {
      debugPrint('❌ Erreur marquage suppression: $e');
    }
  }
  
  /// Déclencher une synchronisation immédiate
  Future<void> _triggerImmediateSync() async {
    try {
      // Marquer simplement pour synchronisation - le service de sync se chargera du reste
      // lors de la prochaine synchronisation automatique
      debugPrint('🔄 Marqué pour synchronisation lors du prochain cycle');
      
      // Optionnel: déclencher une notification pour forcer la sync
      await _notifySyncRequired();
    } catch (e) {
      debugPrint('❌ Erreur notification sync: $e');
      // Ne pas faire échouer la suppression pour autant
    }
  }
  
  /// Notifier qu'une synchronisation est requise
  Future<void> _notifySyncRequired() async {
    try {
      final prefs = await LocalDB.instance.database;
      await prefs.setBool('sync_personnel_required', true);
      await prefs.setString('sync_personnel_required_at', DateTime.now().toIso8601String());
      debugPrint('📢 Notification sync personnel enregistrée');
    } catch (e) {
      debugPrint('⚠️ Erreur notification sync: $e');
    }
  }
  
  /// Supprimer les données liées à un personnel
  Future<void> _deleteRelatedData(int personnelId) async {
    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys();
      
      // Supprimer salaires
      for (String key in keys) {
        if (key.startsWith('salaire_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final json = jsonDecode(data);
              if (json['personnel_id'] == personnelId) {
                await prefs.remove(key);
                debugPrint('🗑️ Salaire supprimé: $key');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur suppression salaire $key: $e');
          }
        }
      }
      
      // Supprimer avances
      for (String key in keys) {
        if (key.startsWith('avance_personnel_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final json = jsonDecode(data);
              if (json['personnel_id'] == personnelId) {
                await prefs.remove(key);
                debugPrint('🗑️ Avance supprimée: $key');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur suppression avance $key: $e');
          }
        }
      }
      
      // Supprimer retenues
      for (String key in keys) {
        if (key.startsWith('retenue_personnel_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final json = jsonDecode(data);
              if (json['personnel_id'] == personnelId) {
                await prefs.remove(key);
                debugPrint('🗑️ Retenue supprimée: $key');
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur suppression retenue $key: $e');
          }
        }
      }
      
      debugPrint('✅ Données liées supprimées pour personnel ID $personnelId');
    } catch (e) {
      debugPrint('❌ Erreur suppression données liées: $e');
    }
  }
  
  /// Obtenir les suppressions en attente de synchronisation
  Future<List<Map<String, dynamic>>> getPendingDeletions() async {
    try {
      final prefs = await LocalDB.instance.database;
      final keys = prefs.getKeys();
      final deletions = <Map<String, dynamic>>[];
      
      for (String key in keys) {
        if (key.startsWith('deletion_')) {
          try {
            final data = prefs.getString(key);
            if (data != null) {
              final deletion = jsonDecode(data);
              if (deletion['synced'] != true) {
                deletions.add(deletion);
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur lecture suppression $key: $e');
          }
        }
      }
      
      return deletions;
    } catch (e) {
      debugPrint('❌ Erreur récupération suppressions: $e');
      return [];
    }
  }
  
  /// Marquer une suppression comme synchronisée
  Future<void> markDeletionAsSynced(int id, String type) async {
    try {
      final prefs = await LocalDB.instance.database;
      final key = 'deletion_${type}_$id';
      
      final data = prefs.getString(key);
      if (data != null) {
        final deletion = jsonDecode(data);
        deletion['synced'] = true;
        deletion['synced_at'] = DateTime.now().toIso8601String();
        
        await prefs.setString(key, jsonEncode(deletion));
        debugPrint('✅ Suppression marquée comme synchronisée: $type ID $id');
        
        // Procéder à la suppression définitive
        if (type == 'personnel') {
          await hardDeletePersonnel(id);
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur marquage sync suppression: $e');
    }
  }

  // ============================================================================
  // RECHERCHE & FILTRES
  // ============================================================================

  /// Obtenir un employé par ID
  Future<PersonnelModel?> getPersonnelById(int id) async {
    await loadPersonnel();
    try {
      return _personnel.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Obtenir un employé par matricule
  Future<PersonnelModel?> getPersonnelByMatricule(String matricule) async {
    await loadPersonnel();
    try {
      return _personnel.firstWhere((p) => p.matricule == matricule);
    } catch (e) {
      return null;
    }
  }

  /// Rechercher des employés
  List<PersonnelModel> searchPersonnel(String query) {
    if (query.isEmpty) return _personnel;
    
    final lowerQuery = query.toLowerCase();
    return _personnel.where((p) {
      return p.matricule.toLowerCase().contains(lowerQuery) ||
             p.nom.toLowerCase().contains(lowerQuery) ||
             p.prenom.toLowerCase().contains(lowerQuery) ||
             p.poste.toLowerCase().contains(lowerQuery) ||
             p.telephone.toLowerCase().contains(lowerQuery);
    }).toList();
  }

  /// Filtrer par statut
  List<PersonnelModel> filterByStatut(String statut) {
    return _personnel.where((p) => p.statut == statut).toList();
  }

  /// Filtrer par poste
  List<PersonnelModel> filterByPoste(String poste) {
    return _personnel.where((p) => p.poste == poste).toList();
  }

  /// Filtrer par shop
  List<PersonnelModel> filterByShop(int shopId) {
    return _personnel.where((p) => p.shopId == shopId).toList();
  }

  /// Filtrer par type de contrat
  List<PersonnelModel> filterByTypeContrat(String typeContrat) {
    return _personnel.where((p) => p.typeContrat == typeContrat).toList();
  }

  // ============================================================================
  // STATISTIQUES
  // ============================================================================

  /// Compter le personnel actif
  int get countPersonnelActif {
    return _personnel.where((p) => p.statut == 'Actif').length;
  }

  /// Compter le personnel total
  int get countPersonnelTotal {
    return _personnel.length;
  }

  /// Calculer la masse salariale totale (salaire base + primes)
  double get masseSalarialeTotal {
    return _personnel
        .where((p) => p.statut == 'Actif')
        .fold(0.0, (sum, p) => sum + p.salaireTotal);
  }

  /// Calculer la masse salariale par shop
  Map<int?, double> get masseSalarialeParShop {
    final Map<int?, double> result = {};
    
    for (var p in _personnel.where((p) => p.statut == 'Actif')) {
      result[p.shopId] = (result[p.shopId] ?? 0.0) + p.salaireTotal;
    }
    
    return result;
  }

  /// Obtenir les postes uniques
  List<String> get postesUniques {
    final postes = _personnel.map((p) => p.poste).toSet().toList();
    postes.sort();
    return postes;
  }

  /// Obtenir les départements uniques
  List<String> get departementsUniques {
    final depts = _personnel
        .where((p) => p.departement != null)
        .map((p) => p.departement!)
        .toSet()
        .toList();
    depts.sort();
    return depts;
  }

  /// Statistiques par statut
  Map<String, int> get statistiquesParStatut {
    final Map<String, int> stats = {};
    
    for (var p in _personnel) {
      stats[p.statut] = (stats[p.statut] ?? 0) + 1;
    }
    
    return stats;
  }

  /// Statistiques par type de contrat
  Map<String, int> get statistiquesParTypeContrat {
    final Map<String, int> stats = {};
    
    for (var p in _personnel) {
      stats[p.typeContrat] = (stats[p.typeContrat] ?? 0) + 1;
    }
    
    return stats;
  }

  // ============================================================================
  // UTILITAIRES
  // ============================================================================

  /// Générer un matricule unique
  Future<String> generateMatricule() async {
    try {
      await loadPersonnel();
      
      final year = DateTime.now().year.toString().substring(2);
      int counter = 1;
      const int maxAttempts = 9999; // Limite de sécurité
      
      String matricule;
      do {
        matricule = 'AG-$year${counter.toString().padLeft(3, '0')}';
        counter++;
        
        // Sécurité pour éviter une boucle infinie
        if (counter > maxAttempts) {
          throw Exception('Impossible de générer un matricule unique après $maxAttempts tentatives');
        }
      } while (_personnel.any((p) => p.matricule == matricule));
      
      debugPrint('✅ Matricule généré: $matricule');
      return matricule;
    } catch (e) {
      debugPrint('❌ Erreur génération matricule: $e');
      // En cas d'erreur, générer un matricule avec timestamp pour garantir l'unicité
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(8);
      final fallbackMatricule = 'EMP${DateTime.now().year.toString().substring(2)}$timestamp';
      debugPrint('🔄 Matricule de secours généré: $fallbackMatricule');
      return fallbackMatricule;
    }
  }

  /// Vérifier si un matricule existe
  Future<bool> matriculeExists(String matricule) async {
    await loadPersonnel();
    return _personnel.any((p) => p.matricule == matricule);
  }

  /// Nettoyer le cache
  void clearCache() {
    _personnel.clear();
    notifyListeners();
  }
}
