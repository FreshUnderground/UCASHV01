import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';
import '../lib/services/local_db.dart';
import '../lib/services/rates_service.dart';
import '../lib/data/initial_rates_data.dart';

void main() {
  group('Commission Initialization Tests', () {
    setUp(() async {
      // Initialize the binding
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    test('Default commissions should be initialized when none exist', () async {
      // Get the initial commissions from our data
      final initialCommissions = InitialRatesData.getInitialCommissions();
      
      // Verify we have the expected default commissions
      expect(initialCommissions.length, 2);
      expect(initialCommissions[0].type, 'SORTANT');
      expect(initialCommissions[0].taux, 3.5);
      expect(initialCommissions[1].type, 'ENTRANT');
      expect(initialCommissions[1].taux, 0.0);
      
      // Load rates and commissions - this should initialize defaults
      await RatesService.instance.loadRatesAndCommissions();
      
      // Check that commissions were initialized
      final commissions = RatesService.instance.commissions;
      expect(commissions.length, 2);
      
      // Verify SORTANT commission
      final sortantCommission = commissions.firstWhere((c) => c.type == 'SORTANT');
      expect(sortantCommission.taux, 3.5);
      expect(sortantCommission.description, 'Commission pour transferts sortants depuis la RDC vers l\'étranger');
      
      // Verify ENTRANT commission
      final entrantCommission = commissions.firstWhere((c) => c.type == 'ENTRANT');
      expect(entrantCommission.taux, 0.0);
      expect(entrantCommission.description, 'Transferts entrants vers la RDC (service gratuit)');
    });

    test('RatesService should find commissions by type', () async {
      // Load rates and commissions - this should initialize defaults
      await RatesService.instance.loadRatesAndCommissions();
      
      // Test finding commissions by type
      final sortantCommission = RatesService.instance.getCommissionByType('SORTANT');
      expect(sortantCommission, isNotNull);
      expect(sortantCommission!.taux, 3.5);
      
      final entrantCommission = RatesService.instance.getCommissionByType('ENTRANT');
      expect(entrantCommission, isNotNull);
      expect(entrantCommission!.taux, 0.0);
      
      // Test finding non-existent commission type
      final invalidCommission = RatesService.instance.getCommissionByType('INVALID');
      expect(invalidCommission, isNull);
    });
  });
}