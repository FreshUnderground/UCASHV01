import 'package:flutter_test/flutter_test.dart';
import 'package:ucashv01/models/operation_model.dart';

/// Tests unitaires pour valider l'alignement des enums entre Flutter et PHP
/// 
/// CRITIQUE: Les index des enums DOIVENT correspondre exactement entre:
/// - Flutter (Dart enums)
/// - PHP (tableaux de conversion dans upload.php)
/// 
/// Si les index ne correspondent pas, les données seront corrompues lors de la synchronisation!
void main() {
  group('Enum Alignment Tests', () {
    
    test('OperationType enum indices match PHP conversion array', () {
      // PHP: $types = ['transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'depot', 'retrait', 'virement', 'retraitMobileMoney'];
      
      expect(OperationType.transfertNational.index, 0, 
        reason: 'transfertNational must be index 0 to match PHP array');
      
      expect(OperationType.transfertInternationalSortant.index, 1,
        reason: 'transfertInternationalSortant must be index 1 to match PHP array');
      
      expect(OperationType.transfertInternationalEntrant.index, 2,
        reason: 'transfertInternationalEntrant must be index 2 to match PHP array');
      
      expect(OperationType.depot.index, 3,
        reason: 'depot must be index 3 to match PHP array');
      
      expect(OperationType.retrait.index, 4,
        reason: 'retrait must be index 4 to match PHP array');
      
      expect(OperationType.virement.index, 5,
        reason: 'virement must be index 5 to match PHP array');
      
      expect(OperationType.retraitMobileMoney.index, 6,
        reason: 'retraitMobileMoney must be index 6 to match PHP array');
    });
    
    test('ModePaiement enum indices match PHP conversion array', () {
      // PHP: $modes = ['cash', 'airtelMoney', 'mPesa', 'orangeMoney'];
      
      expect(ModePaiement.cash.index, 0,
        reason: 'cash must be index 0 to match PHP array');
      
      expect(ModePaiement.airtelMoney.index, 1,
        reason: 'airtelMoney must be index 1 to match PHP array');
      
      expect(ModePaiement.mPesa.index, 2,
        reason: 'mPesa must be index 2 to match PHP array');
      
      expect(ModePaiement.orangeMoney.index, 3,
        reason: 'orangeMoney must be index 3 to match PHP array');
    });
    
    test('OperationStatus enum indices match PHP conversion array', () {
      // PHP: $statuts = ['enAttente', 'validee', 'terminee', 'annulee'];
      
      expect(OperationStatus.enAttente.index, 0,
        reason: 'enAttente must be index 0 to match PHP array');
      
      expect(OperationStatus.validee.index, 1,
        reason: 'validee must be index 1 to match PHP array');
      
      expect(OperationStatus.terminee.index, 2,
        reason: 'terminee must be index 2 to match PHP array');
      
      expect(OperationStatus.annulee.index, 3,
        reason: 'annulee must be index 3 to match PHP array');
    });
    
    test('Enum counts match PHP array lengths', () {
      // Vérifier que le nombre d'éléments dans chaque enum correspond au nombre d'éléments dans les tableaux PHP
      
      expect(OperationType.values.length, 7,
        reason: 'OperationType must have exactly 7 values to match PHP array');
      
      expect(ModePaiement.values.length, 4,
        reason: 'ModePaiement must have exactly 4 values to match PHP array');
      
      expect(OperationStatus.values.length, 4,
        reason: 'OperationStatus must have exactly 4 values to match PHP array');
    });
    
    test('No duplicate enum values', () {
      // Vérifier qu'il n'y a pas de valeurs dupliquées dans les enums
      
      final operationTypes = OperationType.values.map((e) => e.index).toSet();
      expect(operationTypes.length, OperationType.values.length,
        reason: 'OperationType enum should not have duplicate indices');
      
      final modePaiements = ModePaiement.values.map((e) => e.index).toSet();
      expect(modePaiements.length, ModePaiement.values.length,
        reason: 'ModePaiement enum should not have duplicate indices');
      
      final statuts = OperationStatus.values.map((e) => e.index).toSet();
      expect(statuts.length, OperationStatus.values.length,
        reason: 'OperationStatus enum should not have duplicate indices');
    });
    
    test('Enum names match MySQL ENUM values', () {
      // Vérifier que les noms des enums correspondent aux valeurs MySQL ENUM
      
      expect(OperationType.transfertNational.name, 'transfertNational');
      expect(OperationType.transfertInternationalSortant.name, 'transfertInternationalSortant');
      expect(OperationType.transfertInternationalEntrant.name, 'transfertInternationalEntrant');
      expect(OperationType.depot.name, 'depot');
      expect(OperationType.retrait.name, 'retrait');
      expect(OperationType.virement.name, 'virement');
      expect(OperationType.retraitMobileMoney.name, 'retraitMobileMoney');
      
      expect(ModePaiement.cash.name, 'cash');
      expect(ModePaiement.airtelMoney.name, 'airtelMoney');
      expect(ModePaiement.mPesa.name, 'mPesa');
      expect(ModePaiement.orangeMoney.name, 'orangeMoney');
      
      expect(OperationStatus.enAttente.name, 'enAttente');
      expect(OperationStatus.validee.name, 'validee');
      expect(OperationStatus.terminee.name, 'terminee');
      expect(OperationStatus.annulee.name, 'annulee');
    });
    
    test('Conversion roundtrip: index -> PHP -> MySQL -> index', () {
      // Simuler le processus complet de conversion
      
      // Flutter index -> PHP string (simulation)
      final phpTypes = ['transfertNational', 'transfertInternationalSortant', 'transfertInternationalEntrant', 'depot', 'retrait', 'virement', 'retraitMobileMoney'];
      final phpModes = ['cash', 'airtelMoney', 'mPesa', 'orangeMoney'];
      final phpStatuts = ['enAttente', 'validee', 'terminee', 'annulee'];
      
      // Vérifier que chaque enum Flutter correspond au bon string PHP
      for (var type in OperationType.values) {
        expect(phpTypes[type.index], type.name,
          reason: 'OperationType.${type.name} index ${type.index} should map to PHP "${type.name}"');
      }
      
      for (var mode in ModePaiement.values) {
        expect(phpModes[mode.index], mode.name,
          reason: 'ModePaiement.${mode.name} index ${mode.index} should map to PHP "${mode.name}"');
      }
      
      for (var statut in OperationStatus.values) {
        expect(phpStatuts[statut.index], statut.name,
          reason: 'OperationStatus.${statut.name} index ${statut.index} should map to PHP "${statut.name}"');
      }
    });
  });
  
  group('Data Integrity Tests', () {
    test('Operation with all enums can be serialized correctly', () {
      // Test qu'une opération complète peut être sérialisée avec tous les enums
      final operation = OperationModel(
        codeOps: '', // Test operation
        id: 1,
        type: OperationType.transfertNational,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.enAttente,
        montantBrut: 100.0,
        montantNet: 97.0,
        commission: 3.0,
        devise: 'USD',
        agentId: 1,
        shopSourceId: 1,
        dateOp: DateTime.now(),
        destinataire: 'Test Client',
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'test_user',
      );
      
      final json = operation.toJson();
      
      // Vérifier que les index sont corrects
      expect(json['type'], 0, reason: 'transfertNational should be index 0');
      expect(json['mode_paiement'], 0, reason: 'cash should be index 0');
      expect(json['statut'], 0, reason: 'enAttente should be index 0');
    });
    
    test('Different operation types have different indices', () {
      final depot = OperationModel(
        codeOps: '', // Test depot
        type: OperationType.depot,
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.terminee,
        montantBrut: 100.0,
        montantNet: 100.0,
        commission: 0.0,
        devise: 'USD',
        agentId: 1,
        shopSourceId: 1,
        dateOp: DateTime.now(),
        destinataire: 'Client',
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'test',
      );
      
      final transfert = OperationModel(
        codeOps: '', // Test transfert
        type: OperationType.transfertNational,
        modePaiement: ModePaiement.airtelMoney,
        statut: OperationStatus.validee,
        montantBrut: 100.0,
        montantNet: 97.0,
        commission: 3.0,
        devise: 'USD',
        agentId: 1,
        shopSourceId: 1,
        dateOp: DateTime.now(),
        destinataire: 'Client',
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'test',
      );
      
      final depotJson = depot.toJson();
      final transfertJson = transfert.toJson();
      
      // Les types doivent être différents
      expect(depotJson['type'], isNot(equals(transfertJson['type'])));
      expect(depotJson['mode_paiement'], isNot(equals(transfertJson['mode_paiement'])));
      expect(depotJson['statut'], isNot(equals(transfertJson['statut'])));
    });
  });
}
