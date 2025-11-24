import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ucashv01/services/local_db.dart';
import 'package:ucashv01/services/rates_service.dart';
import 'package:ucashv01/models/commission_model.dart';

void main() {
  group('Shop-to-Shop Commission Tests', () {
    setUp(() async {
      // Initialize the binding
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Should create and retrieve shop-to-shop commissions', () async {
      // Create a commission for a specific route: BUTEMBO -> KAMPALA (1%)
      final butemboToKampalaCommission = CommissionModel(
        id: 1,
        shopSourceId: 100, // BUTEMBO shop ID
        shopDestinationId: 200, // KAMPALA shop ID
        type: 'SORTANT',
        taux: 1.0, // 1% commission
        description: 'Commission pour transferts BUTEMBO -> KAMPALA',
      );
      
      // Save the commission
      await LocalDB.instance.saveCommission(butemboToKampalaCommission);
      
      // Create another commission for a different route: BUTEMBO -> KINDU (1.5%)
      final butemboToKinduCommission = CommissionModel(
        id: 2,
        shopSourceId: 100, // BUTEMBO shop ID
        shopDestinationId: 300, // KINDU shop ID
        type: 'SORTANT',
        taux: 1.5, // 1.5% commission
        description: 'Commission pour transferts BUTEMBO -> KINDU',
      );
      
      // Save the commission
      await LocalDB.instance.saveCommission(butemboToKinduCommission);
      
      // Load rates and commissions
      await RatesService.instance.loadRatesAndCommissions();
      
      // Test finding commission for BUTEMBO -> KAMPALA route
      final butemboToKampalaResult = RatesService.instance.getCommissionByShopsAndType(100, 200, 'SORTANT');
      expect(butemboToKampalaResult, isNotNull);
      expect(butemboToKampalaResult!.taux, 1.0);
      expect(butemboToKampalaResult.shopSourceId, 100);
      expect(butemboToKampalaResult.shopDestinationId, 200);
      
      // Test finding commission for BUTEMBO -> KINDU route
      final butemboToKinduResult = RatesService.instance.getCommissionByShopsAndType(100, 300, 'SORTANT');
      expect(butemboToKinduResult, isNotNull);
      expect(butemboToKinduResult!.taux, 1.5);
      expect(butemboToKinduResult.shopSourceId, 100);
      expect(butemboToKinduResult.shopDestinationId, 300);
      
      // Test that a different route gets null
      final differentRouteResult = RatesService.instance.getCommissionByShopsAndType(999, 888, 'SORTANT');
      expect(differentRouteResult, isNull);
    });

    test('Should calculate amount with shop-to-shop commission', () async {
      // Create a commission for a specific route: BUTEMBO -> KAMPALA (1%)
      final butemboToKampalaCommission = CommissionModel(
        id: 1,
        shopSourceId: 100, // BUTEMBO shop ID
        shopDestinationId: 200, // KAMPALA shop ID
        type: 'SORTANT',
        taux: 1.0, // 1% commission
        description: 'Commission pour transferts BUTEMBO -> KAMPALA',
      );
      
      // Save the commission
      await LocalDB.instance.saveCommission(butemboToKampalaCommission);
      
      // Create another commission for a different route: BUTEMBO -> KINDU (1.5%)
      final butemboToKinduCommission = CommissionModel(
        id: 2,
        shopSourceId: 100, // BUTEMBO shop ID
        shopDestinationId: 300, // KINDU shop ID
        type: 'SORTANT',
        taux: 1.5, // 1.5% commission
        description: 'Commission pour transferts BUTEMBO -> KINDU',
      );
      
      // Save the commission
      await LocalDB.instance.saveCommission(butemboToKinduCommission);
      
      // Load rates and commissions
      await RatesService.instance.loadRatesAndCommissions();
      
      // Test calculation for BUTEMBO -> KAMPALA route (1% commission)
      final amountButemboToKampala = RatesService.instance.calculateAmountWithCommissionForShops(1000, 'SORTANT', 100, 200);
      // 1000 + (1000 * 1.0/100) = 1000 + 10 = 1010
      expect(amountButemboToKampala, closeTo(1010.0, 0.001));
      
      // Test calculation for BUTEMBO -> KINDU route (1.5% commission)
      final amountButemboToKindu = RatesService.instance.calculateAmountWithCommissionForShops(1000, 'SORTANT', 100, 300);
      // 1000 + (1000 * 1.5/100) = 1000 + 15 = 1015
      expect(amountButemboToKindu, closeTo(1015.0, 0.001));
    });
  });
}