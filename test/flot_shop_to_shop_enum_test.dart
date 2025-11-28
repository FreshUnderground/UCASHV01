import 'package:flutter_test/flutter_test.dart';
import 'package:ucashv01/models/operation_model.dart';

/// Tests unitaires pour valider que le nouveau type flotShopToShop
/// est correctement aligné entre Flutter, PHP et MySQL
/// 
/// CRITIQUE: L'index 7 DOIT correspondre à 'flotShopToShop' partout!
void main() {
  group('flotShopToShop Enum Alignment Tests', () {
    
    test('flotShopToShop enum has correct index', () {
      // flotShopToShop doit être à l'index 7
      expect(OperationType.flotShopToShop.index, 7, 
        reason: 'flotShopToShop must be index 7 to match PHP array');
    });
    
    test('flotShopToShop enum has correct name', () {
      expect(OperationType.flotShopToShop.name, 'flotShopToShop');
    });
    
    test('All OperationType indices are sequential and complete', () {
      // Vérifier que tous les indices de 0 à 7 sont bien définis
      expect(OperationType.transfertNational.index, 0);
      expect(OperationType.transfertInternationalSortant.index, 1);
      expect(OperationType.transfertInternationalEntrant.index, 2);
      expect(OperationType.depot.index, 3);
      expect(OperationType.retrait.index, 4);
      expect(OperationType.virement.index, 5);
      expect(OperationType.retraitMobileMoney.index, 6);
      expect(OperationType.flotShopToShop.index, 7);
      
      // Vérifier qu'il y a exactement 8 types (0 à 7)
      expect(OperationType.values.length, 8,
        reason: 'Should have exactly 8 operation types (including flotShopToShop)');
    });
    
    test('PHP array conversion matches Flutter enum indices', () {
      // Simuler le tableau PHP de conversion
      final phpTypes = [
        'transfertNational',              // 0
        'transfertInternationalSortant',  // 1
        'transfertInternationalEntrant',  // 2
        'depot',                          // 3
        'retrait',                        // 4
        'virement',                       // 5
        'retraitMobileMoney',             // 6
        'flotShopToShop',                 // 7 ← NOUVEAU
      ];
      
      // Vérifier que chaque enum Flutter correspond au bon string PHP
      for (var type in OperationType.values) {
        expect(phpTypes[type.index], type.name,
          reason: 'OperationType.${type.name} index ${type.index} should map to PHP "${type.name}"');
      }
    });
    
    test('flotShopToShop parses correctly from string', () {
      // Test parsing depuis différentes variantes de string
      final testCases = [
        'flotShopToShop',
        'flotshoptoshop',
        'flot_shop_to_shop',
      ];
      
      for (var testCase in testCases) {
        final parsed = OperationModel.fromJson({
          'id': 1,
          'type': testCase,  // String depuis MySQL
          'montant_brut': 1000,
          'montant_net': 1000,
          'commission': 0,
          'code_ops': 'TEST123',
          'agent_id': 1,
          'mode_paiement': 'cash',
          'statut': 'enAttente',
          'date_op': DateTime.now().toIso8601String(),
        });
        
        expect(parsed.type, OperationType.flotShopToShop,
          reason: 'String "$testCase" should parse to OperationType.flotShopToShop');
      }
    });
    
    test('flotShopToShop parses correctly from index', () {
      // Test parsing depuis index (cas synchronisation)
      final parsed = OperationModel.fromJson({
        'id': 1,
        'type': 7,  // Index depuis Flutter
        'montant_brut': 1000,
        'montant_net': 1000,
        'commission': 0,
        'code_ops': 'TEST123',
        'agent_id': 1,
        'mode_paiement': 0,
        'statut': 0,
        'date_op': DateTime.now().toIso8601String(),
      });
      
      expect(parsed.type, OperationType.flotShopToShop);
      expect(parsed.type.index, 7);
    });
    
    test('flotShopToShop toJson produces correct index', () {
      final operation = OperationModel(
        type: OperationType.flotShopToShop,
        montantBrut: 1000,
        montantNet: 1000,
        commission: 0,
        codeOps: 'FLOT123',
        agentId: 1,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.enAttente,
        dateOp: DateTime.now(),
      );
      
      final json = operation.toJson();
      
      // L'index doit être 7
      expect(json['type'], 7,
        reason: 'flotShopToShop should serialize to index 7');
    });
    
    test('flotShopToShop has zero commission semantics', () {
      // Les FLOTs doivent toujours avoir commission = 0
      final flot = OperationModel(
        type: OperationType.flotShopToShop,
        montantBrut: 1000,
        montantNet: 1000,
        commission: 0,  // TOUJOURS 0 pour les FLOTs
        codeOps: 'FLOT123',
        agentId: 1,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.enAttente,
        dateOp: DateTime.now(),
      );
      
      expect(flot.commission, 0,
        reason: 'FLOTs should always have commission = 0');
      expect(flot.montantBrut, flot.montantNet,
        reason: 'For FLOTs, montantBrut should equal montantNet (no commission)');
    });
    
    test('Roundtrip: Flutter → PHP → MySQL → PHP → Flutter', () {
      // Test du cycle complet de synchronisation
      
      // 1. Flutter: Créer une opération FLOT
      final original = OperationModel(
        type: OperationType.flotShopToShop,
        montantBrut: 1000,
        montantNet: 1000,
        commission: 0,
        codeOps: 'FLOT123',
        agentId: 1,
        shopSourceId: 1,
        shopDestinationId: 2,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.enAttente,
        dateOp: DateTime.now(),
      );
      
      // 2. Flutter → JSON (upload)
      final json = original.toJson();
      expect(json['type'], 7);  // Index Flutter
      
      // 3. PHP convertit: 7 → 'flotShopToShop'
      final phpTypes = [
        'transfertNational', 
        'transfertInternationalSortant', 
        'transfertInternationalEntrant', 
        'depot', 
        'retrait', 
        'virement', 
        'retraitMobileMoney', 
        'flotShopToShop'
      ];
      final mysqlValue = phpTypes[json['type']];
      expect(mysqlValue, 'flotShopToShop');
      
      // 4. MySQL stocke: ENUM('...', 'flotShopToShop')
      // (simulation - en vrai c'est dans MySQL)
      
      // 5. PHP lit depuis MySQL et retourne 'flotShopToShop' string
      final downloadedJson = {
        ...json,
        'type': 'flotShopToShop',  // String depuis MySQL
      };
      
      // 6. Flutter parse le JSON
      final downloaded = OperationModel.fromJson(downloadedJson);
      
      // 7. Vérifier que le type est correct
      expect(downloaded.type, OperationType.flotShopToShop);
      expect(downloaded.type.index, 7);
    });
  });
}
