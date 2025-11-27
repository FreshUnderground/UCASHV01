import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/compte_special_model.dart';
import '../config/app_config.dart';

/// Service pour gérer les comptes spéciaux (FRAIS et DÉPENSE)
class CompteSpecialService extends ChangeNotifier {
  static final CompteSpecialService _instance = CompteSpecialService._internal();
  static CompteSpecialService get instance => _instance;
  
  CompteSpecialService._internal();

  List<CompteSpecialModel> _transactions = [];
  bool _isLoading = false;

  List<CompteSpecialModel> get transactions => _transactions;
  bool get isLoading => _isLoading;

  /// Charger toutes les transactions des comptes spéciaux
  Future<void> loadTransactions({int? shopId}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      _transactions = [];

      // TOUJOURS charger TOUTES les transactions
      // Le filtrage se fera au niveau de getStatistics, getFrais, getDepenses
      for (String key in keys) {
        if (key.startsWith('compte_special_')) {
          final data = prefs.getString(key);
          if (data != null) {
            final transaction = CompteSpecialModel.fromJson(jsonDecode(data));
            _transactions.add(transaction);
          }
        }
      }

      // Trier par date décroissante
      _transactions.sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
      
      debugPrint('📊 ${_transactions.length} transactions de comptes spéciaux chargées (toutes shops)');
      if (shopId != null) {
        final filteredCount = _transactions.where((t) => t.shopId == shopId).length;
        debugPrint('   → $filteredCount transactions pour shop $shopId');
      }
    } catch (e) {
      debugPrint('❌ Erreur chargement comptes spéciaux: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Créer une transaction générique
  Future<CompteSpecialModel?> createTransaction({
    required TypeCompteSpecial type,
    required TypeTransactionCompte typeTransaction,
    required double montant,
    required String description,
    required int shopId,
    int? operationId,
    int? agentId,
    String? agentUsername,
  }) async {
    try {
      final transaction = CompteSpecialModel(
        id: DateTime.now().millisecondsSinceEpoch,
        type: type,
        typeTransaction: typeTransaction,
        montant: montant,
        description: description,
        shopId: shopId,
        dateTransaction: DateTime.now(),
        operationId: operationId,
        agentId: agentId,
        agentUsername: agentUsername,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'system',
        isSynced: false,
      );

      await _saveTransaction(transaction);
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ Transaction créée: \$${montant.toStringAsFixed(2)} - $description');
      return transaction;
    } catch (e) {
      debugPrint('❌ Erreur création transaction: $e');
      return null;
    }
  }

  /// Ajouter une commission automatique au compte FRAIS
  Future<CompteSpecialModel?> addFrais({
    required double montant,
    required String description,
    required int shopId,
    int? operationId,
    int? agentId,
    String? agentUsername,
  }) async {
    try {
      final transaction = CompteSpecialModel(
        id: DateTime.now().millisecondsSinceEpoch,
        type: TypeCompteSpecial.FRAIS,
        typeTransaction: TypeTransactionCompte.COMMISSION_AUTO,
        montant: montant,
        description: description,
        shopId: shopId,
        dateTransaction: DateTime.now(),
        operationId: operationId,
        agentId: agentId,
        agentUsername: agentUsername,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'system',
        isSynced: false,
      );

      await _saveTransaction(transaction);
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ 💰 FRAIS ajouté: \$${montant.toStringAsFixed(2)} - $description');
      return transaction;
    } catch (e) {
      debugPrint('❌ Erreur ajout FRAIS: $e');
      return null;
    }
  }

  /// Dépôt par le Boss dans le compte DÉPENSE
  Future<CompteSpecialModel?> depotDepense({
    required double montant,
    required String description,
    required int shopId,
    int? agentId,
    String? agentUsername,
  }) async {
    try {
      final transaction = CompteSpecialModel(
        id: DateTime.now().millisecondsSinceEpoch,
        type: TypeCompteSpecial.DEPENSE,
        typeTransaction: TypeTransactionCompte.DEPOT,
        montant: montant,
        description: description,
        shopId: shopId,
        dateTransaction: DateTime.now(),
        agentId: agentId,
        agentUsername: agentUsername,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'boss',
        isSynced: false,
      );

      await _saveTransaction(transaction);
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ ➕ DÉPÔT DEPENSE: \$${montant.toStringAsFixed(2)} - $description');
      return transaction;
    } catch (e) {
      debugPrint('❌ Erreur dépôt DEPENSE: $e');
      return null;
    }
  }

  /// Sortie depuis le compte DÉPENSE
  Future<CompteSpecialModel?> sortieDepense({
    required double montant,
    required String description,
    required int shopId,
    int? agentId,
    String? agentUsername,
  }) async {
    try {
      final solde = getSoldeDepense(shopId: shopId);
      if (solde < montant) {
        debugPrint('⚠️ Solde insuffisant: \$${solde.toStringAsFixed(2)} < \$${montant.toStringAsFixed(2)}');
        throw Exception('Solde insuffisant dans le compte DÉPENSE');
      }

      final transaction = CompteSpecialModel(
        id: DateTime.now().millisecondsSinceEpoch,
        type: TypeCompteSpecial.DEPENSE,
        typeTransaction: TypeTransactionCompte.SORTIE,
        montant: -montant, // Négatif pour sortie
        description: description,
        shopId: shopId,
        dateTransaction: DateTime.now(),
        agentId: agentId,
        agentUsername: agentUsername,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'admin',
        isSynced: false,
      );

      await _saveTransaction(transaction);
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ 💸 SORTIE DEPENSE: \$${montant.toStringAsFixed(2)} - $description');
      return transaction;
    } catch (e) {
      debugPrint('❌ Erreur sortie DEPENSE: $e');
      rethrow;
    }
  }

  /// Retrait par le Boss depuis le compte FRAIS
  Future<CompteSpecialModel?> retraitFrais({
    required double montant,
    required String description,
    required int shopId,
    int? agentId,
    String? agentUsername,
  }) async {
    try {
      final solde = getSoldeFrais(shopId: shopId);
      if (solde < montant) {
        debugPrint('⚠️ Solde insuffisant: \$${solde.toStringAsFixed(2)} < \$${montant.toStringAsFixed(2)}');
        throw Exception('Solde insuffisant dans le compte FRAIS');
      }

      final transaction = CompteSpecialModel(
        id: DateTime.now().millisecondsSinceEpoch,
        type: TypeCompteSpecial.FRAIS,
        typeTransaction: TypeTransactionCompte.RETRAIT,
        montant: -montant, // Négatif pour retrait
        description: description,
        shopId: shopId,
        dateTransaction: DateTime.now(),
        agentId: agentId,
        agentUsername: agentUsername,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'boss',
        isSynced: false,
      );

      await _saveTransaction(transaction);
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ ➖ RETRAIT FRAIS: \$${montant.toStringAsFixed(2)} - $description');
      return transaction;
    } catch (e) {
      debugPrint('❌ Erreur retrait FRAIS: $e');
      rethrow;
    }
  }

  /// Sauvegarder une transaction
  Future<void> _saveTransaction(CompteSpecialModel transaction) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'compte_special_${transaction.id}',
      jsonEncode(transaction.toJson()),
    );
  }

  /// Obtenir la date effective pour filtrage (dateTransaction ou createdAt si null)
  DateTime _getEffectiveDate(CompteSpecialModel transaction) {
    // Si dateTransaction existe et est valide, l'utiliser
    // Sinon, utiliser createdAt comme fallback
    // Cela permet de gérer les cas où date_validation pourrait être null
    return transaction.dateTransaction;
  }

  /// Supprimer une transaction
  Future<bool> deleteTransaction(int id, {int? shopId}) async {
    try {
      debugPrint('🗑️ Suppression de la transaction $id...');
      
      // 1. Supprimer sur le serveur d'abord
      try {
        final url = '${AppConfig.apiBaseUrl}/sync/comptes_speciaux/delete.php';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'id': id}),
        );
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            debugPrint('✅ Transaction supprimée du serveur');
          } else {
            debugPrint('⚠️ Erreur serveur: ${result['error']}');
            // Continue quand même avec la suppression locale
          }
        } else {
          debugPrint('⚠️ Erreur HTTP ${response.statusCode}: ${response.body}');
          // Continue quand même avec la suppression locale
        }
      } catch (e) {
        debugPrint('⚠️ Erreur de connexion au serveur: $e');
        debugPrint('   Suppression locale uniquement (sera re-téléchargée lors de la sync)');
        // Continue avec la suppression locale même si le serveur est inaccessible
      }
      
      // 2. Supprimer de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('compte_special_$id');
      
      // 3. Recharger les transactions
      await loadTransactions(shopId: shopId);
      
      debugPrint('✅ Transaction $id supprimée avec succès');
      return true;
    } catch (e) {
      debugPrint('❌ Erreur suppression transaction: $e');
      return false;
    }
  }

  /// Calculer le solde du compte FRAIS
  double getSoldeFrais({int? shopId, DateTime? startDate, DateTime? endDate}) {
    return _transactions.where((t) {
      // Filtre par type
      if (t.type != TypeCompteSpecial.FRAIS) return false;
      
      // Filtre par shop
      if (shopId != null && t.shopId != shopId) return false;
      
      // Obtenir la date effective (dateTransaction ou createdAt)
      final effectiveDate = _getEffectiveDate(t);
      
      // Filtre par date de début (inclure startDate)
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        if (effectiveDate.isBefore(startOfDay)) return false;
      }
      
      // Filtre par date de fin (inclure endDate jusqu'à 23:59:59)
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (effectiveDate.isAfter(endOfDay)) return false;
      }
      
      return true;
    }).fold(0.0, (sum, t) => sum + t.montant); // Montants positifs (commissions) et négatifs (retraits)
  }

  /// Calculer le solde du compte DÉPENSE
  double getSoldeDepense({int? shopId, DateTime? startDate, DateTime? endDate}) {
    return _transactions.where((t) {
      // Filtre par type
      if (t.type != TypeCompteSpecial.DEPENSE) return false;
      
      // Filtre par shop
      if (shopId != null && t.shopId != shopId) return false;
      
      // Obtenir la date effective (dateTransaction ou createdAt)
      final effectiveDate = _getEffectiveDate(t);
      
      // Filtre par date de début (inclure startDate)
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        if (effectiveDate.isBefore(startOfDay)) return false;
      }
      
      // Filtre par date de fin (inclure endDate jusqu'à 23:59:59)
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (effectiveDate.isAfter(endOfDay)) return false;
      }
      
      return true;
    }).fold(0.0, (sum, t) => sum + t.montant); // Montants positifs (dépôts) et négatifs (sorties)
  }

  /// Obtenir les transactions FRAIS
  List<CompteSpecialModel> getFrais({int? shopId, DateTime? startDate, DateTime? endDate}) {
    return _transactions.where((t) {
      // Filtre par type
      if (t.type != TypeCompteSpecial.FRAIS) return false;
      
      // Filtre par shop
      if (shopId != null && t.shopId != shopId) return false;
      
      // Obtenir la date effective (dateTransaction ou createdAt)
      final effectiveDate = _getEffectiveDate(t);
      
      // Filtre par date de début (inclure startDate)
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        if (effectiveDate.isBefore(startOfDay)) return false;
      }
      
      // Filtre par date de fin (inclure endDate jusqu'à 23:59:59)
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (effectiveDate.isAfter(endOfDay)) return false;
      }
      
      return true;
    }).toList();
  }

  /// Obtenir les transactions DÉPENSE
  List<CompteSpecialModel> getDepenses({int? shopId, DateTime? startDate, DateTime? endDate}) {
    return _transactions.where((t) {
      // Filtre par type
      if (t.type != TypeCompteSpecial.DEPENSE) return false;
      
      // Filtre par shop
      if (shopId != null && t.shopId != shopId) return false;
      
      // Obtenir la date effective (dateTransaction ou createdAt)
      final effectiveDate = _getEffectiveDate(t);
      
      // Filtre par date de début (inclure startDate)
      if (startDate != null) {
        final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
        if (effectiveDate.isBefore(startOfDay)) return false;
      }
      
      // Filtre par date de fin (inclure endDate jusqu'à 23:59:59)
      if (endDate != null) {
        final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
        if (effectiveDate.isAfter(endOfDay)) return false;
      }
      
      return true;
    }).toList();
  }

  /// Statistiques pour les rapports
  Map<String, dynamic> getStatistics({int? shopId, DateTime? startDate, DateTime? endDate}) {
    final frais = getFrais(shopId: shopId, startDate: startDate, endDate: endDate);
    final depenses = getDepenses(shopId: shopId, startDate: startDate, endDate: endDate);
    
    final soldeFrais = getSoldeFrais(shopId: shopId, startDate: startDate, endDate: endDate);
    final soldeDepense = getSoldeDepense(shopId: shopId, startDate: startDate, endDate: endDate);
    
    // Séparer les commissions et retraits pour FRAIS
    final commissionsAuto = frais.where((t) => t.typeTransaction == TypeTransactionCompte.COMMISSION_AUTO).toList();
    final retraits = frais.where((t) => t.typeTransaction == TypeTransactionCompte.RETRAIT).toList();
    
    // Séparer les dépôts et sorties pour DÉPENSE
    final depots = depenses.where((t) => t.typeTransaction == TypeTransactionCompte.DEPOT).toList();
    final sorties = depenses.where((t) => t.typeTransaction == TypeTransactionCompte.SORTIE).toList();
    
    return {
      'solde_frais': soldeFrais,
      'solde_depense': soldeDepense,
      'nombre_frais': frais.length,
      'nombre_depenses': depenses.length,
      'benefice_net': soldeFrais + soldeDepense, // FRAIS positif, DÉPENSE peut être négatif
      
      // Détails FRAIS
      'commissions_auto': commissionsAuto.fold(0.0, (sum, t) => sum + t.montant),
      'nombre_commissions': commissionsAuto.length,
      'retraits_frais': retraits.fold(0.0, (sum, t) => sum + t.montant.abs()),
      'nombre_retraits': retraits.length,
      
      // Détails DÉPENSE
      'depots_boss': depots.fold(0.0, (sum, t) => sum + t.montant),
      'nombre_depots': depots.length,
      'sorties': sorties.fold(0.0, (sum, t) => sum + t.montant.abs()),
      'nombre_sorties': sorties.length,
    };
  }
}
