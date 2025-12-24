import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/triangular_debt_settlement_model.dart';
import '../models/shop_model.dart';
import '../config/app_config.dart';
import 'local_db.dart';

/// Service pour gérer les règlements triangulaires de dettes inter-shops
/// 
/// **Scénario**: Shop A doit à Shop C, mais Shop B reçoit le paiement pour le compte de Shop C
/// 
/// **Impacts**:
/// - Dette de Shop A envers Shop C: diminue
/// - Dette de Shop B envers Shop C: augmente
class TriangularDebtSettlementService {
  static final TriangularDebtSettlementService _instance = TriangularDebtSettlementService._internal();
  
  TriangularDebtSettlementService._internal();
  
  static TriangularDebtSettlementService get instance => _instance;
  
  /// Supprimer un règlement triangulaire (local puis serveur)
  Future<bool> deleteTriangularSettlement({
    required String reference,
    required String userId,
    String? deleteReason,
  }) async {
    try {
      debugPrint('🗑️ === SUPPRESSION RÈGLEMENT TRIANGULAIRE ===');
      debugPrint('   Référence: $reference');
      debugPrint('   Utilisateur: $userId');
      
      // ÉTAPE 1: Suppression locale
      debugPrint('📱 ÉTAPE 1: Suppression locale...');
      
      // Récupérer le règlement existant
      final settlements = await getAllTriangularSettlements();
      final settlement = settlements.firstWhere(
        (s) => s.reference == reference && !s.isDeleted,
        orElse: () => throw Exception('Règlement non trouvé: $reference'),
      );
      
      // Marquer comme supprimé localement
      final deletedSettlement = settlement.copyWith(
        isDeleted: true,
        deletedAt: DateTime.now(),
        deletedBy: userId,
        deleteReason: deleteReason ?? 'Suppression par admin',
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: userId,
        isSynced: false, // Marquer pour synchronisation
      );
      
      // Sauvegarder localement
      await LocalDB.instance.saveTriangularDebtSettlement(deletedSettlement);
      debugPrint('✅ Règlement supprimé localement: $reference');
      
      // ÉTAPE 2: Suppression serveur
      debugPrint('🌐 ÉTAPE 2: Suppression serveur...');
      
      final success = await _deleteOnServer(reference, userId, deleteReason);
      if (success) {
        debugPrint('✅ Règlement supprimé sur serveur: $reference');
        
        // Marquer comme synchronisé
        final syncedSettlement = deletedSettlement.copyWith(
          isSynced: true,
          syncedAt: DateTime.now(),
        );
        await LocalDB.instance.saveTriangularDebtSettlement(syncedSettlement);
        
        debugPrint('🔄 Synchronisation terminée pour: $reference');
      } else {
        debugPrint('⚠️ Échec suppression serveur, sera retentée lors du prochain sync');
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Erreur suppression règlement: $e');
      return false;
    }
  }

  /// Supprimer sur le serveur via API
  Future<bool> _deleteOnServer(String reference, String userId, String? deleteReason) async {
    try {
      final baseUrl = await _getApiBaseUrl();
      final url = '$baseUrl/triangular_debt_settlements/delete.php';
      
      final payload = {
        'reference': reference,
        'user_id': userId,
        'user_role': 'admin',
        'delete_reason': deleteReason ?? 'Suppression par admin',
      };
      
      debugPrint('📤 Envoi requête suppression vers: $url');
      debugPrint('📤 Payload: $payload');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 30));
      
      debugPrint('📥 Response status: ${response.statusCode}');
      debugPrint('📥 Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        return result['success'] == true;
      }
      
      return false;
    } catch (e) {
      debugPrint('❌ Erreur API suppression: $e');
      return false;
    }
  }

  /// Obtenir l'URL de base de l'API
  Future<String> _getApiBaseUrl() async {
    return await AppConfig.getApiBaseUrl();
  }

  /// Récupérer tous les règlements (incluant supprimés pour sync)
  Future<List<TriangularDebtSettlementModel>> getAllTriangularSettlements({
    bool includeDeleted = false,
  }) async {
    final allSettlements = await LocalDB.instance.getAllTriangularDebtSettlements();
    
    if (includeDeleted) {
      return allSettlements;
    }
    
    return allSettlements.where((s) => !s.isDeleted).toList();
  }

  /// Récupérer les règlements actifs seulement
  Future<List<TriangularDebtSettlementModel>> getActiveTriangularSettlements() async {
    return getAllTriangularSettlements(includeDeleted: false);
  }

  /// Créer un nouveau règlement triangulaire et mettre à jour les dettes
  /// 
  /// **Paramètres**:
  /// - [shopDebtorId]: Shop A (qui doit l'argent initialement)
  /// - [shopIntermediaryId]: Shop B (qui reçoit le paiement)
  /// - [shopCreditorId]: Shop C (à qui l'argent est dû)
  /// - [montant]: Montant du règlement
  /// - [agentId]: ID de l'agent qui effectue l'opération
  /// - [notes]: Notes optionnelles
  /// - [modePaiement]: Mode de paiement optionnel
  /// 
  /// **Retourne**: Le règlement créé avec son ID
  Future<TriangularDebtSettlementModel> createTriangularSettlement({
    required int shopDebtorId,
    required int shopIntermediaryId,
    required int shopCreditorId,
    required double montant,
    required int agentId,
    String? agentUsername,
    String? notes,
    String? modePaiement,
    String devise = 'USD',
  }) async {
    try {
      debugPrint('🔺 === CRÉATION RÈGLEMENT TRIANGULAIRE ===');
      debugPrint('   Shop Débiteur (A): ID $shopDebtorId');
      debugPrint('   Shop Intermédiaire (B): ID $shopIntermediaryId');
      debugPrint('   Shop Créancier (C): ID $shopCreditorId');
      debugPrint('   Montant: $montant $devise');
      
      // Validation: Les 3 shops doivent être différents
      if (shopDebtorId == shopIntermediaryId || 
          shopDebtorId == shopCreditorId || 
          shopIntermediaryId == shopCreditorId) {
        throw Exception('Les 3 shops doivent être différents');
      }
      
      // Validation: Montant positif
      if (montant <= 0) {
        throw Exception('Le montant doit être positif');
      }
      
      // Charger les informations des 3 shops
      final shopDebtor = await LocalDB.instance.getShopById(shopDebtorId);
      final shopIntermediary = await LocalDB.instance.getShopById(shopIntermediaryId);
      final shopCreditor = await LocalDB.instance.getShopById(shopCreditorId);
      
      if (shopDebtor == null || shopIntermediary == null || shopCreditor == null) {
        throw Exception('Un ou plusieurs shops n\'ont pas été trouvés');
      }
      
      debugPrint('🏪 Shop A (Débiteur): ${shopDebtor.designation}');
      debugPrint('🏪 Shop B (Intermédiaire): ${shopIntermediary.designation}');
      debugPrint('🏪 Shop C (Créancier): ${shopCreditor.designation}');
      
      // Créer le règlement triangulaire
      final settlement = TriangularDebtSettlementModel(
        reference: TriangularDebtSettlementModel.generateReference(),
        shopDebtorId: shopDebtorId,
        shopDebtorDesignation: shopDebtor.designation,
        shopIntermediaryId: shopIntermediaryId,
        shopIntermediaryDesignation: shopIntermediary.designation,
        shopCreditorId: shopCreditorId,
        shopCreditorDesignation: shopCreditor.designation,
        montant: montant,
        devise: devise,
        dateReglement: DateTime.now(),
        modePaiement: modePaiement,
        notes: notes,
        agentId: agentId,
        agentUsername: agentUsername,
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentId',
      );
      
      // Sauvegarder le règlement
      final savedSettlement = await LocalDB.instance.saveTriangularDebtSettlement(settlement);
      
      // Mettre à jour les dettes des shops
      await _updateShopDebts(
        shopDebtor: shopDebtor,
        shopIntermediary: shopIntermediary,
        shopCreditor: shopCreditor,
        montant: montant,
        agentId: agentId,
      );
      
      debugPrint('✅ Règlement triangulaire créé: ${savedSettlement.reference}');
      debugPrint('🔺 === FIN RÈGLEMENT TRIANGULAIRE ===');
      
      return savedSettlement;
    } catch (e) {
      debugPrint('❌ Erreur création règlement triangulaire: $e');
      rethrow;
    }
  }
  
  /// Mettre à jour les dettes des 3 shops impliqués
  /// 
  /// **Logique**:
  /// 1. Shop A (débiteur): Dette envers C diminue de [montant]
  /// 2. Shop B (intermédiaire): Dette envers C augmente de [montant]
  /// 3. Shop C (créancier): Créances ajustées en conséquence
  Future<void> _updateShopDebts({
    required ShopModel shopDebtor,
    required ShopModel shopIntermediary,
    required ShopModel shopCreditor,
    required double montant,
    required int agentId,
  }) async {
    debugPrint('💰 === MISE À JOUR DETTES TRIANGULAIRES ===');
    
    // IMPACT 1: Shop A (débiteur) - Sa dette envers C diminue
    // On réduit ses dettes et on réduit les créances de C
    final updatedShopDebtor = shopDebtor.copyWith(
      dettes: shopDebtor.dettes - montant,
      lastModifiedAt: DateTime.now(),
      lastModifiedBy: 'triangular_settlement_$agentId',
    );
    await LocalDB.instance.saveShop(updatedShopDebtor);
    debugPrint('   ✅ ${shopDebtor.designation}: Dettes ${shopDebtor.dettes} → ${updatedShopDebtor.dettes} (-$montant)');
    
    // IMPACT 2: Shop B (intermédiaire) - Sa dette envers C augmente
    // On augmente ses dettes et on augmente les créances de C
    final updatedShopIntermediary = shopIntermediary.copyWith(
      dettes: shopIntermediary.dettes + montant,
      lastModifiedAt: DateTime.now(),
      lastModifiedBy: 'triangular_settlement_$agentId',
    );
    await LocalDB.instance.saveShop(updatedShopIntermediary);
    debugPrint('   ❌ ${shopIntermediary.designation}: Dettes ${shopIntermediary.dettes} → ${updatedShopIntermediary.dettes} (+$montant)');
    
    // IMPACT 3: Shop C (créancier) - Ses créances restent globalement constantes
    // (La dette de A diminue mais la dette de B augmente du même montant)
    // Donc pas de changement net sur les créances totales de C
    debugPrint('   ℹ️ ${shopCreditor.designation}: Créances inchangées (transfert de dette A→B)');
    
    debugPrint('💰 === FIN MISE À JOUR DETTES ===');
  }
  
  /// Récupérer tous les règlements triangulaires
  Future<List<TriangularDebtSettlementModel>> getAllSettlements() async {
    return await LocalDB.instance.getAllTriangularDebtSettlements();
  }
  
  /// Récupérer les règlements triangulaires pour un shop spécifique
  /// (Où le shop est impliqué comme débiteur, intermédiaire ou créancier)
  Future<List<TriangularDebtSettlementModel>> getSettlementsByShop(int shopId) async {
    final allSettlements = await getAllSettlements();
    return allSettlements.where((s) => 
      s.shopDebtorId == shopId || 
      s.shopIntermediaryId == shopId || 
      s.shopCreditorId == shopId
    ).toList();
  }
  
  /// Récupérer les règlements triangulaires dans une période
  Future<List<TriangularDebtSettlementModel>> getSettlementsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final allSettlements = await getAllSettlements();
    return allSettlements.where((s) => 
      s.dateReglement.isAfter(startDate) && 
      s.dateReglement.isBefore(endDate)
    ).toList();
  }
  
  /// Supprimer un règlement triangulaire (avec annulation des impacts)
  Future<void> deleteSettlement(int settlementId) async {
    try {
      final settlement = await LocalDB.instance.getTriangularDebtSettlementById(settlementId);
      if (settlement == null) {
        throw Exception('Règlement triangulaire non trouvé');
      }
      
      debugPrint('🗑️ Suppression règlement triangulaire: ${settlement.reference}');
      
      // Annuler les impacts sur les dettes
      final shopDebtor = await LocalDB.instance.getShopById(settlement.shopDebtorId);
      final shopIntermediary = await LocalDB.instance.getShopById(settlement.shopIntermediaryId);
      
      if (shopDebtor != null && shopIntermediary != null) {
        // Inverser les impacts
        final updatedShopDebtor = shopDebtor.copyWith(
          dettes: shopDebtor.dettes + settlement.montant, // Restaurer la dette
          lastModifiedAt: DateTime.now(),
        );
        await LocalDB.instance.saveShop(updatedShopDebtor);
        
        final updatedShopIntermediary = shopIntermediary.copyWith(
          dettes: shopIntermediary.dettes - settlement.montant, // Annuler la dette
          lastModifiedAt: DateTime.now(),
        );
        await LocalDB.instance.saveShop(updatedShopIntermediary);
        
        debugPrint('   ✅ Impacts annulés sur les shops');
      }
      
      // Supprimer le règlement
      await LocalDB.instance.deleteTriangularDebtSettlement(settlementId);
      debugPrint('   ✅ Règlement supprimé');
      
    } catch (e) {
      debugPrint('❌ Erreur suppression règlement triangulaire: $e');
      rethrow;
    }
  }
}
