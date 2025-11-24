import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ucashv01/services/local_db.dart';
import 'package:ucashv01/services/rates_service.dart';
import 'package:ucashv01/models/commission_model.dart';

void main() {
  group('Shop-Specific Commission Tests', () {
    setUp(() async {
      // Initialize the binding
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Should create and retrieve shop-specific commissions', () async {
      // Create a global commission
      final globalCommission = CommissionModel(
        id: 1,
        type: 'SORTANT',
        taux: 3.5,
        description: 'Global commission for outgoing transfers',
      );
      
      // Save the global commission
      await LocalDB.instance.saveCommission(globalCommission);
      
      // Create a shop-specific commission
      final shopSpecificCommission = CommissionModel(
        id: 2,
        shopId: 100, // Specific shop ID
        type: 'SORTANT',
        taux: 2.0, // Different rate for this shop
        description: 'Shop-specific commission for outgoing transfers',
      );
      
      // Save the shop-specific commission
      await LocalDB.instance.saveCommission(shopSpecificCommission);
      
      // Load rates and commissions
      await RatesService.instance.loadRatesAndCommissions();
      
      // Test finding global commission
      final globalCommissionResult = RatesService.instance.getCommissionByTypeAndShop('SORTANT', 999);
      expect(globalCommissionResult, isNotNull);
      expect(globalCommissionResult!.taux, 3.5);
      expect(globalCommissionResult.shopId, isNull);
      
      // Test finding shop-specific commission
      final shopSpecificCommissionResult = RatesService.instance.getCommissionByTypeAndShop('SORTANT', 100);
      expect(shopSpecificCommissionResult, isNotNull);
      expect(shopSpecificCommissionResult!.taux, 2.0);
      expect(shopSpecificCommissionResult.shopId, 100);
      
      // Test that a different shop still gets the global commission
      final otherShopCommissionResult = RatesService.instance.getCommissionByTypeAndShop('SORTANT', 200);
      expect(otherShopCommissionResult, isNotNull);
      expect(otherShopCommissionResult!.taux, 3.5);
      expect(otherShopCommissionResult.shopId, isNull);
    });

    test('Should calculate amount with shop-specific commission', () async {
      // Create a global commission
      final globalCommission = CommissionModel(
        id: 1,
        type: 'SORTANT',
        taux: 3.5,
        description: 'Global commission for outgoing transfers',
      );
      
      // Save the global commission
      await LocalDB.instance.saveCommission(globalCommission);
      
      // Create a shop-specific commission
      final shopSpecificCommission = CommissionModel(
        id: 2,
        shopId: 100, // Specific shop ID
        type: 'SORTANT',
        taux: 2.0, // Different rate for this shop
        description: 'Shop-specific commission for outgoing transfers',
      );
      
      // Save the shop-specific commission
      await LocalDB.instance.saveCommission(shopSpecificCommission);
      
      // Load rates and commissions
      await RatesService.instance.loadRatesAndCommissions();
      
      // Test calculation with global commission
      final amountWithGlobalCommission = RatesService.instance.calculateAmountWithCommissionForShop(1000, 'SORTANT', 999);
      // 1000 + (1000 * 3.5/100) = 1000 + 35 = 1035
      expect(amountWithGlobalCommission, 1035.0);
      
      // Test calculation with shop-specific commission
      final amountWithShopCommission = RatesService.instance.calculateAmountWithCommissionForShop(1000, 'SORTANT', 100);
      // 1000 + (1000 * 2.0/100) = 1000 + 20 = 1020
      expect(amountWithShopCommission, 1020.0);
    });
  });
}