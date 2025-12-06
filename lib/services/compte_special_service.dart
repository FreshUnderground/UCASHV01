import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/compte_special_model.dart';
import '../models/cloture_caisse_model.dart';
import '../config/app_config.dart';
import '../services/local_db.dart';

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
      // MODIFIÉ: Utiliser le solde réel depuis getStatistics
      final stats = await getStatistics(shopId: shopId); // Sans filtre de date = solde global
      final soldeDepense = stats['solde_depense'] ?? 0.0;
      
      debugPrint('💰 Vérification solde DÉPENSE pour sortie:');
      debugPrint('   Solde disponible: \$${soldeDepense.toStringAsFixed(2)}');
      debugPrint('   Montant à retirer: \$${montant.toStringAsFixed(2)}');
      
      if (soldeDepense < montant) {
        debugPrint('⚠️ Solde insuffisant: \$${soldeDepense.toStringAsFixed(2)} < \$${montant.toStringAsFixed(2)}');
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
      debugPrint('\n🔍 === DÉBUT RETRAIT FRAIS ===');
      debugPrint('   Shop ID: $shopId');
      debugPrint('   Montant demandé: \$${montant.toStringAsFixed(2)}');
      
      // MODIFIÉ: Calculer le vrai solde FRAIS (incluant les frais encaissés des transferts)
      final stats = await getStatistics(shopId: shopId); // Sans filtre de date = solde global
      final soldeFrais = stats['solde_frais_jour'] ?? stats['solde_frais'] ?? 0.0;
      
      debugPrint('💰 Vérification solde FRAIS pour retrait:');
      debugPrint('   Stats reçues: ${stats.keys.toList()}');
      debugPrint('   solde_frais_jour: ${stats['solde_frais_jour']}');
      debugPrint('   solde_frais: ${stats['solde_frais']}');
      debugPrint('   frais_anterieur: ${stats['frais_anterieur']}');
      debugPrint('   frais_encaisses_jour: ${stats['frais_encaisses_jour']}');
      debugPrint('   sortie_frais_jour: ${stats['sortie_frais_jour']}');
      debugPrint('   Solde calculé: \$${soldeFrais.toStringAsFixed(2)}');
      debugPrint('   Montant à retirer: \$${montant.toStringAsFixed(2)}');
      debugPrint('   Suffisant? ${soldeFrais >= montant}');
      
      if (soldeFrais < montant) {
        debugPrint('⚠️ REJET: Solde insuffisant: \$${soldeFrais.toStringAsFixed(2)} < \$${montant.toStringAsFixed(2)}');
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
  /// NOUVELLE LOGIQUE: Retourne les frais encaissés depuis les transferts servis avec description améliorée
  Future<List<CompteSpecialModel>> getFraisAsync({int? shopId, DateTime? startDate, DateTime? endDate}) async {
    debugPrint('📊 getFraisAsync appelé: shopId=$shopId, startDate=$startDate, endDate=$endDate');
    debugPrint('   Total transactions FRAIS en mémoire: ${_transactions.where((t) => t.type == TypeCompteSpecial.FRAIS).length}');
    
    try {
      // Charger les retraits FRAIS normaux depuis les transactions
      final retraits = _transactions.where((t) {
        if (t.type != TypeCompteSpecial.FRAIS) return false;
        if (t.typeTransaction != TypeTransactionCompte.RETRAIT) return false;
        if (shopId != null && t.shopId != shopId) {
          // DEBUG: Afficher pourquoi ça ne matche pas
          if (_transactions.indexOf(t) < 2) {
            debugPrint('   ❌ RETRAIT Transaction ${t.id}: shopId=${t.shopId} != $shopId (type=${t.shopId.runtimeType} vs ${shopId.runtimeType})');
          }
          return false;
        }
        
        final effectiveDate = _getEffectiveDate(t);
        if (startDate != null) {
          final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
          if (effectiveDate.isBefore(startOfDay)) return false;
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (effectiveDate.isAfter(endOfDay)) return false;
        }
        return true;
      }).toList();
      
      debugPrint('   ✅ Retraits FRAIS trouvés: ${retraits.length}');
      
      // Charger les opérations et shops pour les frais encaissés
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final operations = <Map<String, dynamic>>[];
      
      for (String key in keys) {
        if (key.startsWith('operation_')) {
          final data = prefs.getString(key);
          if (data != null) {
            final opData = jsonDecode(data) as Map<String, dynamic>;
            operations.add(opData);
          }
        }
      }
      
      // Charger les shops
      final shops = <Map<String, dynamic>>[];
      for (String key in keys) {
        if (key.startsWith('shop_')) {
          final data = prefs.getString(key);
          if (data != null) {
            final shopData = jsonDecode(data) as Map<String, dynamic>;
            shops.add(shopData);
          }
        }
      }
      final shopsMap = <int, String>{};
      for (final shop in shops) {
        try {
          final idRaw = shop['id'];
          final id = idRaw is int ? idRaw : (idRaw is String ? int.tryParse(idRaw) : null);
          final designation = shop['designation']; // Peut être String ou int
          if (id != null) {
            shopsMap[id] = designation?.toString() ?? 'Shop $id';
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing shop dans getFraisAsync: $e');
        }
      }
      
      // Créer les frais encaissés depuis les transferts
      final fraisEncaisses = <CompteSpecialModel>[];
      
      debugPrint('   🔍 Analyse des opérations pour frais encaissés...');
      debugPrint('   Total opérations chargées: ${operations.length}');
      debugPrint('   Période filtre: $startDate => $endDate');
      debugPrint('   Shop ID filtre: $shopId (type: ${shopId.runtimeType})');
      
      // Afficher les 3 premières opérations pour debug
      if (operations.isNotEmpty) {
        debugPrint('   📑 Échantillon des opérations (3 premières):');
        for (var i = 0; i < operations.length && i < 3; i++) {
          final op = operations[i];
          final shopDestIdRaw = op['shop_destination_id'];
          final type = op['type'];
          final statut = op['statut'];
          final commission = op['commission'];
          debugPrint('      OP $i: shopDest=$shopDestIdRaw (${shopDestIdRaw.runtimeType}), type=$type, statut=$statut, commission=$commission');
        }
      }
      
      int rejectedByShop = 0;
      int rejectedByType = 0;
      int rejectedByStatut = 0;
      int rejectedByCommission = 0;
      int rejectedByDate = 0;
      
      for (final opData in operations) {
        try {
          // Handle shop_destination_id - COMPARAISON EN STRING pour supporter les grands IDs
          final shopDestIdRaw = opData['shop_destination_id'];
          final shopDestIdStr = shopDestIdRaw?.toString();
          final shopIdStr = shopId?.toString();
          
          if (shopIdStr != null && shopDestIdStr != shopIdStr) {
            rejectedByShop++;
            // DEBUG: Afficher les 2 premières opérations rejetées
            if (rejectedByShop <= 2) {
              debugPrint('   ❌ OP ${opData['id']}: shopDestId="$shopDestIdStr" != "$shopIdStr"');
            }
            continue;
          }
          
          // Parser shopDestId pour utilisation ultérieure
          final shopDestId = shopDestIdRaw is int ? shopDestIdRaw : (shopDestIdRaw is String ? int.tryParse(shopDestIdRaw) : null);
          
          final type = opData['type']?.toString();
          if (!(type == 'transfertNational' ||
               type == 'transfertInternationalEntrant' ||
               type == 'transfertInternationalSortant')) {
            rejectedByType++;
            continue;
          }
          
          final statut = opData['statut']?.toString();
          if (statut != 'validee') {
            rejectedByStatut++;
            continue;
          }
          
          // Parse date de manière robuste
          DateTime dateValidation;
          try {
            if (opData['date_validation'] != null) {
              final dateVal = opData['date_validation'];
              if (dateVal is String) {
                dateValidation = DateTime.parse(dateVal);
              } else if (dateVal is int) {
                dateValidation = DateTime.fromMillisecondsSinceEpoch(dateVal);
              } else {
                dateValidation = DateTime.now();
              }
            } else if (opData['created_at'] != null) {
              final createdAtVal = opData['created_at'];
              if (createdAtVal is String) {
                dateValidation = DateTime.parse(createdAtVal);
              } else if (createdAtVal is int) {
                dateValidation = DateTime.fromMillisecondsSinceEpoch(createdAtVal);
              } else {
                dateValidation = DateTime.now();
              }
            } else {
              final dateOpVal = opData['date_op'];
              if (dateOpVal is String) {
                dateValidation = DateTime.parse(dateOpVal);
              } else if (dateOpVal is int) {
                dateValidation = DateTime.fromMillisecondsSinceEpoch(dateOpVal);
              } else {
                dateValidation = DateTime.now();
              }
            }
          } catch (e) {
            debugPrint('⚠️ Erreur parsing date dans getFraisAsync: $e');
            continue;
          }
        
        if (startDate != null) {
          final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
          if (dateValidation.isBefore(startOfDay)) {
            rejectedByDate++;
            if (rejectedByDate <= 2) {
              debugPrint('   ❌ OP ${opData['id']}: date=$dateValidation < $startOfDay');
            }
            continue;
          }
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (dateValidation.isAfter(endOfDay)) {
            rejectedByDate++;
            if (rejectedByDate <= 2) {
              debugPrint('   ❌ OP ${opData['id']}: date=$dateValidation > $endOfDay');
            }
            continue;
          }
        }
        
        final commission = (opData['commission'] as num?)?.toDouble() ?? 0.0;
        if (commission <= 0) {
          rejectedByCommission++;
          continue;
        }
        
        // Créer description: Shop source → Shop destination, Destinataire : Montant net
        // Handle shop_source_id - peut être int ou String depuis SharedPreferences
        final shopSrcIdRaw = opData['shop_source_id'];
        final shopSrcId = shopSrcIdRaw is int ? shopSrcIdRaw : (shopSrcIdRaw is String ? int.tryParse(shopSrcIdRaw) : null);
        final shopSrc = shopsMap[shopSrcId] ?? 'Shop $shopSrcId';
        final shopDest = shopsMap[shopDestId] ?? 'Shop $shopDestId';
        final destinataire = opData['destinataire']?.toString() ?? 'N/A';  // Peut être String ou int
        final montantNet = (opData['montant_net'] as num?)?.toDouble() ?? 0.0;
        
        final description = '$shopSrc → $shopDest, $destinataire : ${montantNet.toStringAsFixed(2)} USD';
        
        // Parse created_at de manière robuste
        DateTime createdAt;
        try {
          if (opData['created_at'] != null) {
            final createdAtVal = opData['created_at'];
            if (createdAtVal is String) {
              createdAt = DateTime.parse(createdAtVal);
            } else if (createdAtVal is int) {
              createdAt = DateTime.fromMillisecondsSinceEpoch(createdAtVal);
            } else {
              createdAt = DateTime.now();
            }
          } else {
            createdAt = DateTime.now();
          }
        } catch (e) {
          createdAt = DateTime.now();
        }
        
        // Parse IDs de manière robuste
        final idRaw = opData['id'];
        final id = idRaw is int ? idRaw : (idRaw is String ? int.tryParse(idRaw) : DateTime.now().millisecondsSinceEpoch);
        
        final operationIdRaw = opData['id'];
        final operationId = operationIdRaw is int ? operationIdRaw : (operationIdRaw is String ? int.tryParse(operationIdRaw) : null);
        
        final agentIdRaw = opData['agent_id'];
        final agentId = agentIdRaw is int ? agentIdRaw : (agentIdRaw is String ? int.tryParse(agentIdRaw) : null);
        
        final isSyncedRaw = opData['is_synced'];
        final isSynced = isSyncedRaw == 1 || isSyncedRaw == true || isSyncedRaw == '1';
        
        fraisEncaisses.add(CompteSpecialModel(
          id: id ?? DateTime.now().millisecondsSinceEpoch,
          type: TypeCompteSpecial.FRAIS,
          typeTransaction: TypeTransactionCompte.COMMISSION_AUTO,
          montant: commission,
          description: description,
          shopId: shopDestId,
          dateTransaction: dateValidation,
          operationId: operationId,
          agentId: agentId,
          agentUsername: opData['agent_username']?.toString(),  // Peut être String ou int
          createdAt: createdAt,
          isSynced: isSynced,
        ));
        
        // Log les 3 premières opérations valides
        if (fraisEncaisses.length <= 3) {
          debugPrint('   ✅ OP ${opData['id']}: commission=$commission, date=$dateValidation, shop=$shopDestId');
        }
        } catch (e) {
          debugPrint('⚠️ Erreur traitement opération dans getFraisAsync: $e');
          continue;
        }
      }
      
      debugPrint('   📊 Résultats filtrage opérations:');
      debugPrint('      ❌ Rejetées par shopId: $rejectedByShop');
      debugPrint('      ❌ Rejetées par type: $rejectedByType');
      debugPrint('      ❌ Rejetées par statut: $rejectedByStatut');
      debugPrint('      ❌ Rejetées par date: $rejectedByDate');
      debugPrint('      ❌ Rejetées par commission: $rejectedByCommission');
      debugPrint('   ✅ Frais encaissés trouvés: ${fraisEncaisses.length}');
      
      final totalFrais = [...fraisEncaisses, ...retraits];
      debugPrint('   💰 TOTAL FRAIS (encaissés + retraits): ${totalFrais.length}');
      debugPrint('      - Frais encaissés: ${fraisEncaisses.length}');
      debugPrint('      - Retraits: ${retraits.length}');
      
      // Combiner les retraits et les frais encaissés
      return totalFrais..sort((a, b) => b.dateTransaction.compareTo(a.dateTransaction));
    } catch (e) {
      debugPrint('❌ Erreur getFraisAsync: $e');
      return [];
    }
  }

  /// Obtenir les frais groupés par route (Shop Source → Shop(s) Destination)
  /// Format: {"Shop A → Shop B, Shop C": {"montant": 150.0, "count": 5, "details": [...]}}
  Future<Map<String, Map<String, dynamic>>> getFraisParRoute({int? shopId, DateTime? startDate, DateTime? endDate}) async {
    try {
      debugPrint('📊 getFraisParRoute: DEBUT');
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final operations = <Map<String, dynamic>>[];
      final shops = <Map<String, dynamic>>[];
      
      // Charger les opérations
      for (String key in keys) {
        if (key.startsWith('operation_')) {
          final data = prefs.getString(key);
          if (data != null) {
            final opData = jsonDecode(data) as Map<String, dynamic>;
            operations.add(opData);
          }
        }
      }
      
      // Charger les shops
      for (String key in keys) {
        if (key.startsWith('shop_')) {
          final data = prefs.getString(key);
          if (data != null) {
            final shopData = jsonDecode(data) as Map<String, dynamic>;
            shops.add(shopData);
          }
        }
      }
      
      debugPrint('📊 getFraisParRoute: ${shops.length} shops chargés');
      
      final shopsMap = <int, String>{};
      for (final shop in shops) {
        try {
          final id = shop['id'] as int?;
          final designation = shop['designation']; // Peut être String ou int
          debugPrint('   Shop: id=$id, designation=$designation (type=${designation.runtimeType})');
          if (id != null) {
            shopsMap[id] = designation?.toString() ?? 'Shop $id';
          }
        } catch (e) {
          debugPrint('❌ Erreur parsing shop: $e - shop data: $shop');
        }
      }
      
      debugPrint('📊 getFraisParRoute: shopsMap créé avec ${shopsMap.length} entrées');
      
      // Grouper par shop source
      final Map<int, Map<String, dynamic>> parShopSource = {};
      
      for (final opData in operations) {
        try {
          // Handle shop_source_id - peut être int ou String depuis SharedPreferences
          final shopSrcIdRaw = opData['shop_source_id'];
          final shopSrcId = shopSrcIdRaw is int ? shopSrcIdRaw : (shopSrcIdRaw is String ? int.tryParse(shopSrcIdRaw) : null);
          
          // Handle shop_destination_id - peut être int ou String depuis SharedPreferences
          final shopDestIdRaw = opData['shop_destination_id'];
          final shopDestId = shopDestIdRaw is int ? shopDestIdRaw : (shopDestIdRaw is String ? int.tryParse(shopDestIdRaw) : null);
          
          if (shopSrcId == null || shopDestId == null) continue;
          
          // Si shopId spécifié, filtrer par source OU destination
          if (shopId != null && shopSrcId != shopId && shopDestId != shopId) continue;
          
          final type = opData['type']?.toString();
          if (!(type == 'transfertNational' ||
               type == 'transfertInternationalEntrant' ||
               type == 'transfertInternationalSortant')) continue;
          
          final statut = opData['statut']?.toString();
          if (statut != 'validee') continue;
        
        // Parse date de manière robuste (peut être String, int timestamp, ou DateTime)
        DateTime dateValidation;
        try {
          if (opData['date_validation'] != null) {
            final dateVal = opData['date_validation'];
            if (dateVal is String) {
              dateValidation = DateTime.parse(dateVal);
            } else if (dateVal is int) {
              dateValidation = DateTime.fromMillisecondsSinceEpoch(dateVal);
            } else {
              dateValidation = DateTime.now();
            }
          } else if (opData['created_at'] != null) {
            final createdAt = opData['created_at'];
            if (createdAt is String) {
              dateValidation = DateTime.parse(createdAt);
            } else if (createdAt is int) {
              dateValidation = DateTime.fromMillisecondsSinceEpoch(createdAt);
            } else {
              dateValidation = DateTime.now();
            }
          } else {
            final dateOp = opData['date_op'];
            if (dateOp is String) {
              dateValidation = DateTime.parse(dateOp);
            } else if (dateOp is int) {
              dateValidation = DateTime.fromMillisecondsSinceEpoch(dateOp);
            } else {
              dateValidation = DateTime.now();
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing date (getFraisParRoute): $e');
          continue;
        }
        
        if (startDate != null) {
          final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
          if (dateValidation.isBefore(startOfDay)) continue;
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (dateValidation.isAfter(endOfDay)) continue;
        }
        
        final commission = (opData['commission'] as num?)?.toDouble() ?? 0.0;
        if (commission <= 0) continue;
        
        // Grouper par shop source
        if (!parShopSource.containsKey(shopSrcId)) {
          parShopSource[shopSrcId] = {
            'destinations': <int>{},
            'montant': 0.0,
            'count': 0,
            'details': <Map<String, dynamic>>[],
          };
        }
        
        (parShopSource[shopSrcId]!['destinations'] as Set<int>).add(shopDestId);
        parShopSource[shopSrcId]!['montant'] = (parShopSource[shopSrcId]!['montant'] as double) + commission;
        parShopSource[shopSrcId]!['count'] = (parShopSource[shopSrcId]!['count'] as int) + 1;
        (parShopSource[shopSrcId]!['details'] as List<Map<String, dynamic>>).add({
          'shopDestId': shopDestId,
            'destinataire': opData['destinataire']?.toString() ?? 'N/A',  // Peut être String ou int
            'montantNet': (opData['montant_net'] as num?)?.toDouble() ?? 0.0,
            'commission': commission,
            'date': dateValidation,
          });
        } catch (e) {
          debugPrint('⚠️ Erreur traitement opération (getFraisParRoute): $e');
          continue;
        }
      }
      
      // Créer le résultat final avec format "Shop A → Shop B, Shop C"
      final Map<String, Map<String, dynamic>> result = {};
      
      for (final entry in parShopSource.entries) {
        final shopSrcId = entry.key;
        final data = entry.value;
        final destinations = data['destinations'] as Set<int>;
        
        final shopSrcName = shopsMap[shopSrcId] ?? 'Shop $shopSrcId';
        final destNames = destinations.map((id) => shopsMap[id] ?? 'Shop $id').join(', ');
        
        final routeKey = '$shopSrcName → $destNames';
        
        result[routeKey] = {
          'montant': data['montant'],
          'count': data['count'],
          'details': data['details'],
          'shopSourceId': shopSrcId,
          'destinationIds': destinations.toList(),
        };
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Erreur getFraisParRoute: $e');
      return {};
    }
  }

  /// Obtenir les frais groupés par SHOP DESTINATION (qui encaisse les frais)
  Future<Map<String, Map<String, dynamic>>> getFraisParShopDestination({
    int? shopId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      debugPrint('📊 getFraisParShopDestination: DEBUT');
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      final operations = <Map<String, dynamic>>[];
      
      // Charger toutes les opérations
      for (String key in keys) {
        if (key.startsWith('operation_')) {
          final data = prefs.getString(key);
          if (data != null) {
            try {
              final opData = jsonDecode(data);
              operations.add(opData as Map<String, dynamic>);
            } catch (e) {
              debugPrint('⚠️ Erreur décodage opération $key: $e');
            }
          }
        }
      }
      
      // Charger les shops pour obtenir leurs noms
      final shops = <Map<String, dynamic>>[];
      for (String key in keys) {
        if (key.startsWith('shop_')) {
          final data = prefs.getString(key);
          if (data != null) {
            try {
              shops.add(jsonDecode(data) as Map<String, dynamic>);
            } catch (e) {
              debugPrint('⚠️ Erreur décodage shop $key: $e');
            }
          }
        }
      }
      
      debugPrint('📊 getFraisParShopDestination: ${shops.length} shops chargés');
      
      final shopsMap = <int, String>{};
      for (final shop in shops) {
        try {
          final id = shop['id'] as int?;
          final designation = shop['designation']; // Peut être String ou int
          debugPrint('   Shop: id=$id, designation=$designation (type=${designation.runtimeType})');
          if (id != null) {
            shopsMap[id] = designation?.toString() ?? 'Shop $id';
          }
        } catch (e) {
          debugPrint('❌ Erreur parsing shop: $e - shop data: $shop');
        }
      }
      
      debugPrint('📊 getFraisParShopDestination: shopsMap créé avec ${shopsMap.length} entrées');
      
      // Grouper par shop destination (qui encaisse les frais)
      final Map<int, Map<String, dynamic>> parShopDest = {};
      
      for (final opData in operations) {
        try {
          // Handle shop_destination_id - peut être int ou String depuis SharedPreferences
          final shopDestIdRaw = opData['shop_destination_id'];
          final shopDestId = shopDestIdRaw is int ? shopDestIdRaw : (shopDestIdRaw is String ? int.tryParse(shopDestIdRaw) : null);
          
          // Handle shop_source_id - peut être int ou String depuis SharedPreferences
          final shopSrcIdRaw = opData['shop_source_id'];
          final shopSrcId = shopSrcIdRaw is int ? shopSrcIdRaw : (shopSrcIdRaw is String ? int.tryParse(shopSrcIdRaw) : null);
          
          if (shopDestId == null || shopSrcId == null) continue;
          
          // Filtrer par shop si spécifié (on veut voir les frais encaissés par CE shop)
          if (shopId != null && shopDestId != shopId) continue;
          
          final type = opData['type']?.toString();
          if (!(type == 'transfertNational' ||
               type == 'transfertInternationalEntrant' ||
               type == 'transfertInternationalSortant')) continue;
          
          final statut = opData['statut']?.toString();
          if (statut != 'validee') continue;
        
        // Parse date de manière robuste (peut être String, int timestamp, ou DateTime)
        DateTime dateValidation;
        try {
          if (opData['date_validation'] != null) {
            final dateVal = opData['date_validation'];
            if (dateVal is String) {
              dateValidation = DateTime.parse(dateVal);
            } else if (dateVal is int) {
              dateValidation = DateTime.fromMillisecondsSinceEpoch(dateVal);
            } else {
              dateValidation = DateTime.now();
            }
          } else if (opData['created_at'] != null) {
            final createdAt = opData['created_at'];
            if (createdAt is String) {
              dateValidation = DateTime.parse(createdAt);
            } else if (createdAt is int) {
              dateValidation = DateTime.fromMillisecondsSinceEpoch(createdAt);
            } else {
              dateValidation = DateTime.now();
            }
          } else {
            final dateOp = opData['date_op'];
            if (dateOp is String) {
              dateValidation = DateTime.parse(dateOp);
            } else if (dateOp is int) {
              dateValidation = DateTime.fromMillisecondsSinceEpoch(dateOp);
            } else {
              dateValidation = DateTime.now();
            }
          }
        } catch (e) {
          debugPrint('⚠️ Erreur parsing date (getFraisParShopDestination): $e');
          continue;
        }
        
        if (startDate != null) {
          final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
          if (dateValidation.isBefore(startOfDay)) continue;
        }
        if (endDate != null) {
          final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
          if (dateValidation.isAfter(endOfDay)) continue;
        }
        
        final commission = (opData['commission'] as num?)?.toDouble() ?? 0.0;
        if (commission <= 0) continue;
        
        // Grouper par shop source (qui a envoyé le transfert)
        if (!parShopDest.containsKey(shopSrcId)) {
          parShopDest[shopSrcId] = {
            'montant': 0.0,
            'count': 0,
            'details': <Map<String, dynamic>>[],
          };
        }
        
        parShopDest[shopSrcId]!['montant'] = (parShopDest[shopSrcId]!['montant'] as double) + commission;
        parShopDest[shopSrcId]!['count'] = (parShopDest[shopSrcId]!['count'] as int) + 1;
        (parShopDest[shopSrcId]!['details'] as List<Map<String, dynamic>>).add({
          'destinataire': opData['destinataire']?.toString() ?? 'N/A',  // Peut être String ou int
            'montantNet': (opData['montant_net'] as num?)?.toDouble() ?? 0.0,
            'commission': commission,
            'date': dateValidation,
          });
        } catch (e) {
          debugPrint('⚠️ Erreur traitement opération (getFraisParShopDestination): $e');
          continue;
        }
      }
      
      // Créer le résultat final avec noms de shops
      final Map<String, Map<String, dynamic>> result = {};
      
      for (final entry in parShopDest.entries) {
        final shopSrcId = entry.key;
        final data = entry.value;
        
        final shopSrcName = shopsMap[shopSrcId] ?? 'Shop $shopSrcId';
        
        result[shopSrcName] = {
          'montant': data['montant'],
          'count': data['count'],
          'details': data['details'],
          'shopSourceId': shopSrcId,
        };
      }
      
      return result;
    } catch (e) {
      debugPrint('❌ Erreur getFraisParShopDestination: $e');
      return {};
    }
  }

  /// Obtenir les transactions FRAIS (méthode synchrone conservée pour compatibilité)
  List<CompteSpecialModel> getFrais({int? shopId, DateTime? startDate, DateTime? endDate}) {
    debugPrint('📊 getFrais appelé: shopId=$shopId, startDate=$startDate, endDate=$endDate');
    debugPrint('   Total transactions FRAIS en mémoire: ${_transactions.where((t) => t.type == TypeCompteSpecial.FRAIS).length}');
    
    final result = _transactions.where((t) {
      // Filtre par type
      if (t.type != TypeCompteSpecial.FRAIS) return false;
      
      // Filtre par shop
      if (shopId != null && t.shopId != shopId) {
        // DEBUG: Afficher les IDs qui ne matchent pas
        if (_transactions.indexOf(t) < 3) {
          debugPrint('   ❌ FRAIS Transaction ${t.id}: shopId=${t.shopId} != $shopId (type=${t.shopId.runtimeType} vs ${shopId.runtimeType})');
        }
        return false;
      }
      
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
    
    debugPrint('   ✅ Résultat: ${result.length} FRAIS trouvés (depuis _transactions uniquement)');
    if (result.isNotEmpty && result.length <= 3) {
      for (var t in result) {
        debugPrint('      - ID: ${t.id}, shopId: ${t.shopId}, type: ${t.typeTransaction.name}, montant: ${t.montant}');
      }
    }
    
    return result;
  }

  /// Obtenir les transactions DÉPENSE
  List<CompteSpecialModel> getDepenses({int? shopId, DateTime? startDate, DateTime? endDate}) {
    debugPrint('📊 getDepenses appelé: shopId=$shopId, startDate=$startDate, endDate=$endDate');
    debugPrint('   Total transactions en mémoire: ${_transactions.length}');
    
    final result = _transactions.where((t) {
      // Filtre par type
      if (t.type != TypeCompteSpecial.DEPENSE) return false;
      
      // Filtre par shop
      if (shopId != null && t.shopId != shopId) {
        // DEBUG: Afficher les IDs qui ne matchent pas
        if (_transactions.indexOf(t) < 3) {
          debugPrint('   ❌ Transaction ${t.id}: shopId=${t.shopId} != $shopId (type=${t.shopId.runtimeType} vs ${shopId.runtimeType})');
        }
        return false;
      }
      
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
    
    debugPrint('   ✅ Résultat: ${result.length} dépenses trouvées');
    if (result.isNotEmpty && result.length <= 3) {
      for (var t in result) {
        debugPrint('      - ID: ${t.id}, shopId: ${t.shopId}, montant: ${t.montant}, desc: ${t.description}');
      }
    }
    
    return result;
  }

  /// Statistiques pour les rapports
  /// NOUVELLE LOGIQUE: Les frais affichés sont UNIQUEMENT les frais encaissés sur les transferts servis
  Future<Map<String, dynamic>> getStatistics({int? shopId, DateTime? startDate, DateTime? endDate}) async {
    debugPrint('🔍 DÉBUT getStatistics - shopId: $shopId');
    
    final frais = getFrais(shopId: shopId, startDate: startDate, endDate: endDate);
    final depenses = getDepenses(shopId: shopId, startDate: startDate, endDate: endDate);
    
    debugPrint('📊 FRAIS: ${frais.length}, DÉPENSES: ${depenses.length}');
    
    final soldeFrais = getSoldeFrais(shopId: shopId, startDate: startDate, endDate: endDate);
    final soldeDepense = getSoldeDepense(shopId: shopId, startDate: startDate, endDate: endDate);
    
    debugPrint('💰 Solde FRAIS: ${soldeFrais.toStringAsFixed(2)}, Solde DÉPENSE: ${soldeDepense.toStringAsFixed(2)}');
    
    // Calculer les FRAIS ENCAISSÉS sur les transferts servis (au lieu de COMMISSION_AUTO)
    // Charger les opérations depuis LocalDB
    debugPrint('📥 Chargement des opérations...');
    final operations = await _loadOperationsForStats(shopId, startDate, endDate);
    debugPrint('✅ Opérations chargées: ${operations.length}');
    
    // Filtrer les transferts servis par ce shop dans la période
    List<dynamic> transfertsServis = [];
    try {
      debugPrint('🔍 Filtrage des transferts servis...');
      debugPrint('   Critères: shopId=$shopId, startDate=$startDate, endDate=$endDate');
      
      int rejectedByShop = 0;
      int rejectedByType = 0;
      int rejectedByStatut = 0;
      int rejectedByDate = 0;
      
      transfertsServis = operations.where((op) {
        try {
          // Vérifier si c'est un transfert servi par this shop
          if (shopId != null && op.shopDestinationId != shopId) {
            rejectedByShop++;
            return false;
          }
          if (!(op.type.name == 'transfertNational' ||
               op.type.name == 'transfertInternationalEntrant' ||
               op.type.name == 'transfertInternationalSortant')) {
            rejectedByType++;
            return false;
          }
          if (op.statut.name != 'validee') {
            rejectedByStatut++;
            return false;
          }
          
          // Filtrer par date si spécifié
          final dateValidation = op.dateValidation ?? op.createdAt ?? op.dateOp;
          if (startDate != null) {
            final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
            if (dateValidation.isBefore(startOfDay)) {
              rejectedByDate++;
              return false;
            }
          }
          if (endDate != null) {
            final endOfDay = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);
            if (dateValidation.isAfter(endOfDay)) {
              rejectedByDate++;
              return false;
            }
          }
          
          return true;
        } catch (e) {
          debugPrint('❌ Erreur lors du filtrage d\'une opération: $e');
          return false;
        }
      }).toList();
      
      debugPrint('📊 Après filtrage: ${transfertsServis.length} transferts servis');
      debugPrint('   ❌ Rejetés par shopId: $rejectedByShop');
      debugPrint('   ❌ Rejetés par type: $rejectedByType');
      debugPrint('   ❌ Rejetés par statut: $rejectedByStatut');
      debugPrint('   ❌ Rejetés par date: $rejectedByDate');
      
      // Afficher un échantillon des opérations pour debug
      if (operations.isNotEmpty && transfertsServis.isEmpty) {
        debugPrint('📋 Échantillon des opérations (premières 3):');
        for (var op in operations.take(3)) {
          debugPrint('   - shopDest: ${op.shopDestinationId}, type: ${op.type.name}, statut: ${op.statut.name}, commission: ${op.commission}');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur critique lors du filtrage: $e');
    }
    
    // Calculer le total des frais encaissés
    final fraisEncaisses = transfertsServis.fold(0.0, (sum, op) => sum + op.commission);
    
    debugPrint('📊 STATISTIQUES COMPTES SPÉCIAUX:');
    debugPrint('   Shop ID: ${shopId ?? "TOUS LES SHOPS"}');
    debugPrint('   Période: ${startDate != null ? startDate.toString().split(' ')[0] : "Depuis toujours"} au ${endDate != null ? endDate.toString().split(' ')[0] : "Aujourd\'hui"}');
    debugPrint('   Opérations totales chargées: ${operations.length}');
    debugPrint('   Transferts servis trouvés: ${transfertsServis.length}');
    debugPrint('   Frais encaissés calculés: ${fraisEncaisses.toStringAsFixed(2)} USD');
    if (transfertsServis.isNotEmpty) {
      debugPrint('   Détail des transferts:');
      for (var op in transfertsServis.take(5)) {
        debugPrint('     - Shop dest: ${op.shopDestinationId}, Commission: ${op.commission.toStringAsFixed(2)}');
      }
      if (transfertsServis.length > 5) {
        debugPrint('     ... et ${transfertsServis.length - 5} autres');
      }
    }
    
    // Séparer les retraits pour FRAIS
    final retraits = frais.where((t) => t.typeTransaction == TypeTransactionCompte.RETRAIT).toList();
    
    // Séparer les dépôts et sorties pour DÉPENSE
    final depots = depenses.where((t) => t.typeTransaction == TypeTransactionCompte.DEPOT).toList();
    final sorties = depenses.where((t) => t.typeTransaction == TypeTransactionCompte.SORTIE).toList();
    
    // Calculer les montants du jour pour DÉPENSE
    final depotsDuJour = depots.fold(0.0, (sum, t) => sum + t.montant);
    final sortiesDuJour = sorties.fold(0.0, (sum, t) => sum + t.montant.abs());
    
    // Calculer le Solde FRAIS
    // BUSINESS LOGIC: Solde FRAIS = Total Frais encaissés - Total Sorties Frais
    // This represents the net balance of the FRAIS account, where:
    // - Credits: Commissions earned from serving transfers (fraisEncaisses)
    // - Debits: Withdrawals from the FRAIS account (retraits)
    // For performance reasons:
    //   - WITHOUT date filter: Use current balance (soldeFrais = all fees - all withdrawals)
    //   - WITH date filter: Previous balance + daily fees - daily withdrawals
    
    double soldeFraisAnterieur = 0.0;
    double sortieFraisDuJour = retraits.fold(0.0, (sum, t) => sum + t.montant.abs());
    double soldeFraisDuJour;
    
    // NOUVEAU: Calculer le Solde DÉPENSE Antérieur
    double soldeDepenseAnterieur = 0.0;
    double soldeDepenseDuJour;
    
    if (startDate != null || endDate != null) {
      // AVEC FILTRE DE DATE: Utiliser Frais Antérieur de la clôture précédente
      try {
        if (shopId != null) {
          final clotures = await LocalDB.instance.getCloturesCaisseByShop(shopId);
          if (clotures.isNotEmpty) {
            clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));
            
            // Chercher la dernière clôture AVANT la date de début
            ClotureCaisseModel? cloturePrecedente;
            if (startDate != null) {
              for (var cloture in clotures) {
                if (cloture.dateCloture.isBefore(startDate)) {
                  cloturePrecedente = cloture;
                  break;
                }
              }
            } else {
              cloturePrecedente = clotures.first;
            }
            
            if (cloturePrecedente != null) {
              soldeFraisAnterieur = cloturePrecedente.soldeFraisAnterieur ?? 0.0;
              debugPrint('💾 Frais Antérieur (clôture du ${cloturePrecedente.dateCloture}): ${soldeFraisAnterieur.toStringAsFixed(2)} USD');
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Erreur chargement clôture: $e');
      }
      
      // NOUVEAU: Calculer le Solde DÉPENSE Antérieur (toutes les transactions DÉPENSE avant startDate)
      if (startDate != null) {
        try {
          final startOfDay = DateTime(startDate.year, startDate.month, startDate.day);
          final depenseAnterieur = _transactions.where((t) {
            if (t.type != TypeCompteSpecial.DEPENSE) return false;
            if (shopId != null && t.shopId != shopId) return false;
            final effectiveDate = _getEffectiveDate(t);
            return effectiveDate.isBefore(startOfDay);
          }).fold(0.0, (sum, t) => sum + t.montant);
          
          soldeDepenseAnterieur = depenseAnterieur;
          debugPrint('💾 Dépense Antérieur (avant $startDate): ${soldeDepenseAnterieur.toStringAsFixed(2)} USD');
        } catch (e) {
          debugPrint('❌ Erreur calcul Dépense Antérieur: $e');
        }
      }
      
      // Formule: Frais Antérieur + Frais encaissés - Sortie Frais
      soldeFraisDuJour = soldeFraisAnterieur + fraisEncaisses - sortieFraisDuJour;
      debugPrint('📊 Avec filtre: Frais Ant ($soldeFraisAnterieur) + Encaissés ($fraisEncaisses) - Sortie ($sortieFraisDuJour) = $soldeFraisDuJour');
      
      // Formule DÉPENSE: Dépense Antérieur + Dépôts du jour - Sorties du jour
      soldeDepenseDuJour = soldeDepenseAnterieur + depotsDuJour - sortiesDuJour;
      debugPrint('📊 Avec filtre: Dépense Ant ($soldeDepenseAnterieur) + Dépôts ($depotsDuJour) - Sorties ($sortiesDuJour) = $soldeDepenseDuJour');
    } else {
      // SANS FILTRE: Calculer le solde global = Total frais encaissés - Total sorties
      // NE PAS utiliser soldeFrais car il ne contient que les transactions de la table comptes_speciaux
      // Il faut inclure fraisEncaisses (des transferts servis)
      soldeFraisDuJour = fraisEncaisses - sortieFraisDuJour;
      debugPrint('📊 Sans filtre: Frais encaissés ($fraisEncaisses) - Sortie ($sortieFraisDuJour) = $soldeFraisDuJour');
      
      // SANS FILTRE: Solde DÉPENSE = somme de toutes les transactions
      soldeDepenseDuJour = soldeDepense;
      debugPrint('📊 Sans filtre: Solde DÉPENSE total = $soldeDepenseDuJour');
    }
    
    return {
      'solde_frais': soldeFrais,
      'solde_depense': soldeDepense,
      'nombre_frais': frais.length,
      'nombre_depenses': depenses.length,
      'benefice_net': soldeFraisDuJour + soldeDepenseDuJour, // CORRIGÉ: Utiliser les soldes du jour
      
      // Détails FRAIS - MODIFIÉ: Utiliser les frais encaissés au lieu de COMMISSION_AUTO
      'commissions_auto': fraisEncaisses, // Frais encaissés sur transferts servis
      'nombre_commissions': transfertsServis.length, // Nombre de transferts servis
      'retraits_frais': sortieFraisDuJour,
      'nombre_retraits': retraits.length,
      
      // NOUVEAU: Formule du Solde FRAIS
      'frais_anterieur': soldeFraisAnterieur,
      'frais_encaisses_jour': fraisEncaisses,
      'sortie_frais_jour': sortieFraisDuJour,
      'solde_frais_jour': soldeFraisDuJour,
      
      // NOUVEAU: Liste des opérations (pour affichage détaillé)
      'operations_frais': transfertsServis.map((op) => {
        'shop_destination_id': op.shopDestinationId,
        'commission': op.commission,
        'date': op.dateValidation ?? op.createdAt ?? op.dateOp,
        'type': op.type.name,
        'statut': op.statut.name,
      }).toList(),
      
      // Détails DÉPENSE - NOUVEAU: Avec formule Antérieur + Dépôts - Sorties
      'depense_anterieur': soldeDepenseAnterieur,
      'depots_boss': depotsDuJour,
      'depots_jour': depotsDuJour,
      'nombre_depots': depots.length,
      'sorties': sortiesDuJour,
      'sorties_jour': sortiesDuJour,
      'nombre_sorties': sorties.length,
      'solde_depense_jour': soldeDepenseDuJour,
    };
  }
  
  /// Charger les opérations pour le calcul des statistiques
  Future<List<dynamic>> _loadOperationsForStats(int? shopId, DateTime? startDate, DateTime? endDate) async {
    try {
      debugPrint('📥 _loadOperationsForStats - Début chargement...');
      
      // MODIFIÉ: Utiliser LocalDB comme le fait RapportClotureService
      final operations = await LocalDB.instance.getAllOperations();
      
      debugPrint('   Opérations brutes chargées depuis LocalDB: ${operations.length}');
      
      // Convertir en objets simplifiés pour le filtrage
      final simpleOps = operations.map((op) => _SimpleOperation(
        shopDestinationId: op.shopDestinationId,
        type: _SimpleOperationType(name: op.type.name),
        statut: _SimpleOperationStatus(name: op.statut.name),
        commission: op.commission,
        dateValidation: op.dateValidation,
        createdAt: op.createdAt,
        dateOp: op.dateOp,
      )).toList();
      
      debugPrint('   Opérations converties: ${simpleOps.length}');
      return simpleOps;
    } catch (e) {
      debugPrint('❌ Erreur lors du chargement des opérations: $e');
      return [];
    }
  }
}

// Classes simples pour éviter les dépendances circulaires
class _SimpleOperation {
  final int? shopDestinationId;
  final _SimpleOperationType type;
  final _SimpleOperationStatus statut;
  final double commission;
  final DateTime? dateValidation;
  final DateTime? createdAt;
  final DateTime dateOp;
  
  _SimpleOperation({
    required this.shopDestinationId,
    required this.type,
    required this.statut,
    required this.commission,
    this.dateValidation,
    this.createdAt,
    required this.dateOp,
  });
}

class _SimpleOperationType {
  final String name;
  _SimpleOperationType({required this.name});
}

class _SimpleOperationStatus {
  final String name;
  _SimpleOperationStatus({required this.name});
}
