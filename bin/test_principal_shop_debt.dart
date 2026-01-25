import 'dart:async';
import 'package:flutter/foundation.dart';
import '../lib/models/shop_model.dart';
import '../lib/services/auth_service.dart';
import '../lib/services/local_db.dart';
import '../lib/services/report_service.dart';
import '../lib/services/shop_service.dart';
import '../lib/services/operation_service.dart';

/// Test script to diagnose principal shop debt display issue
///
/// Usage: dart run bin/test_principal_shop_debt.dart
///
/// This script will:
/// 1. Load all shops and identify principal/transfer shops
/// 2. Load all transfers
/// 3. Generate a debt report for the principal shop
/// 4. Display the consolidation logic results

void main() async {
  print('╔═══════════════════════════════════════════════════════════════╗');
  print('║   TEST: Principal Shop Debt Display Issue Diagnosis          ║');
  print('╚═══════════════════════════════════════════════════════════════╝');
  print('');

  try {
    // Initialize database
    print('📊 Initializing database...');
    await LocalDB.instance.database;
    print('✅ Database initialized');
    print('');

    // Initialize services (all use singleton pattern)
    final authService = AuthService();
    final shopService = ShopService.instance;
    final operationService = OperationService();
    final reportService = ReportService();

    // Load shops
    print('🏪 Loading shops...');
    final shops = await LocalDB.instance.getAllShops();
    print('✅ Found ${shops.length} shops:');
    print('');

    // Identify special shops
    var principalShop;
    var transferShop;

    for (final shop in shops) {
      final isPrincipal = shop.isPrincipal ?? false;
      final isTransfer = shop.isTransferShop ?? false;

      String flags = '';
      if (isPrincipal) {
        flags += '[PRINCIPAL] ';
        principalShop = shop;
      }
      if (isTransfer) {
        flags += '[TRANSFER] ';
        transferShop = shop;
      }

      print('   ${shop.id}: ${shop.designation} $flags');
    }
    print('');

    if (principalShop == null) {
      print('⚠️  WARNING: No shop flagged as isPrincipal=true!');
      print('   Attempting fallback identification...');
      principalShop = shops.firstWhere(
        (shop) =>
            shop.designation.toUpperCase().contains('BUTEMBO') ||
            shop.designation.toUpperCase().contains('DURBA'),
        orElse: () => shops.first,
      );
      print('   Fallback principal shop: ${principalShop.designation}');
    } else {
      print(
          '✅ Principal Shop: ${principalShop.designation} (id=${principalShop.id})');
    }

    if (transferShop == null) {
      print('⚠️  WARNING: No shop flagged as isTransferShop=true!');
      print('   Attempting fallback identification...');
      transferShop = shops.firstWhere(
        (shop) => shop.designation.toUpperCase().contains('KAMPALA'),
        orElse: () => shops.first,
      );
      print('   Fallback transfer shop: ${transferShop.designation}');
    } else {
      print(
          '✅ Transfer Shop: ${transferShop.designation} (id=${transferShop.id})');
    }
    print('');

    // Load operations
    print('📦 Loading operations...');
    final operations = await LocalDB.instance.getAllOperations();
    print('✅ Found ${operations.length} total operations');
    print('');

    // Filter transfers to transfer shop from normal shops
    print('🔍 Analyzing transfers that should trigger consolidation...');
    print('   (Normal Shop → Transfer Shop transfers)');
    print('');

    var consolidationTransfers = 0;
    var directTransfers = 0;

    for (final op in operations) {
      if (op.type.toString().contains('transfert') &&
          op.shopDestinationId == transferShop.id &&
          op.shopSourceId != principalShop.id) {
        consolidationTransfers++;
        ShopModel? sourceShop;
        try {
          sourceShop = shops.firstWhere(
            (s) => s.id == op.shopSourceId,
          );
        } catch (e) {
          sourceShop = null;
        }
        print('   📌 Consolidation Transfer #$consolidationTransfers:');
        print(
            '      ${sourceShop?.designation ?? "Shop ${op.shopSourceId}"} → ${transferShop.designation}');
        print('      Amount: ${op.montantBrut} USD');
        print('      Date: ${op.dateOp}');
        print('      Status: ${op.statut}');
        print('      ➡️  Should create:');
        print(
            '         - DEBT: ${principalShop.designation} owes ${op.montantBrut} USD to ${transferShop.designation}');
        print(
            '         - CREDIT: ${sourceShop?.designation ?? "Shop ${op.shopSourceId}"} owes ${op.montantBrut} USD to ${principalShop.designation}');
        print('');
      } else if (op.type.toString().contains('transfert') &&
          op.shopSourceId == principalShop.id &&
          op.shopDestinationId == transferShop.id) {
        directTransfers++;
        print('   📌 Direct Transfer #$directTransfers:');
        print(
            '      ${principalShop.designation} → ${transferShop.designation}');
        print('      Amount: ${op.montantBrut} USD');
        print('      Date: ${op.dateOp}');
        print('      Status: ${op.statut}');
        print('      ➡️  Should create:');
        print(
            '         - DEBT: ${principalShop.designation} owes ${op.montantBrut} USD to ${transferShop.designation}');
        print('');
      }
    }

    print('📊 Summary:');
    print('   Consolidation transfers: $consolidationTransfers');
    print('   Direct transfers: $directTransfers');
    print(
        '   Total expected debts to ${transferShop.designation}: ${consolidationTransfers + directTransfers}');
    print('');

    // Generate debt report for principal shop
    print('═══════════════════════════════════════════════════════════════');
    print('📊 Generating Debt Report for Principal Shop...');
    print('   Shop: ${principalShop.designation} (id=${principalShop.id})');
    print('   Period: Last 30 days');
    print('═══════════════════════════════════════════════════════════════');
    print('');

    final now = DateTime.now();
    final startDate = now.subtract(const Duration(days: 30));

    final reportData = await reportService.generateDettesIntershopReport(
      shopId: principalShop.id,
      startDate: startDate,
      endDate: now,
    );

    print('✅ Report generated!');
    print('');
    print('📈 REPORT SUMMARY:');
    print(
        '   Total Credits (Others owe us): ${reportData['totalCreances']?.toStringAsFixed(2) ?? "0.00"} USD');
    print(
        '   Total Debts (We owe others): ${reportData['totalDettes']?.toStringAsFixed(2) ?? "0.00"} USD');
    print(
        '   Net Balance: ${((reportData['totalCreances'] ?? 0.0) - (reportData['totalDettes'] ?? 0.0)).toStringAsFixed(2)} USD');
    print('');

    // Analyze debts per shop
    final soldesParShop = reportData['soldesParShop'] as Map<int, double>?;
    if (soldesParShop != null && soldesParShop.isNotEmpty) {
      print('💰 DEBTS/CREDITS BY SHOP:');
      for (final entry in soldesParShop.entries) {
        ShopModel? shop;
        try {
          shop = shops.firstWhere(
            (s) => s.id == entry.key,
          );
        } catch (e) {
          shop = null;
        }
        final shopName = shop?.designation ?? 'Shop ${entry.key}';
        final balance = entry.value;

        if (balance > 0) {
          print(
              '   ✅ CREDIT: $shopName owes us ${balance.toStringAsFixed(2)} USD');
        } else if (balance < 0) {
          print(
              '   ❌ DEBT: We owe ${(-balance).toStringAsFixed(2)} USD to $shopName');
        }
      }
    } else {
      print('⚠️  No debts/credits found in report!');
    }
    print('');

    // Check specifically for transfer shop debt
    print('🎯 CHECKING TRANSFER SHOP DEBT:');
    if (soldesParShop != null && soldesParShop.containsKey(transferShop.id)) {
      final balance = soldesParShop[transferShop.id]!;
      if (balance < 0) {
        print(
            '   ✅ FOUND: ${principalShop.designation} owes ${(-balance).toStringAsFixed(2)} USD to ${transferShop.designation}');
      } else if (balance > 0) {
        print(
            '   ⚠️  UNEXPECTED: ${transferShop.designation} owes ${balance.toStringAsFixed(2)} USD to ${principalShop.designation}');
      } else {
        print('   ⚠️  Balance is 0.00 USD');
      }
    } else {
      print('   ❌ NOT FOUND: No debt entry for ${transferShop.designation}!');
      print(
          '   🔍 This is the issue! The consolidation logic is not creating the expected debt.');
    }
    print('');

    // List all movements
    final mouvements = reportData['mouvements'] as List?;
    if (mouvements != null && mouvements.isNotEmpty) {
      print('📋 MOVEMENTS (showing first 10):');
      for (var i = 0; i < mouvements.length && i < 10; i++) {
        final mouvement = mouvements[i] as Map<String, dynamic>;
        final desc = mouvement['description'] ?? 'No description';
        final montant = mouvement['montant'] ?? 0.0;
        final isCreance = mouvement['isCreance'] ?? false;
        final type = isCreance ? 'CREDIT' : 'DEBT';

        print('   ${i + 1}. [$type] ${montant.toStringAsFixed(2)} USD - $desc');
      }
      if (mouvements.length > 10) {
        print('   ... and ${mouvements.length - 10} more movements');
      }
    } else {
      print('⚠️  No movements found in report!');
    }
    print('');

    print('╔═══════════════════════════════════════════════════════════════╗');
    print('║   TEST COMPLETED                                              ║');
    print('╚═══════════════════════════════════════════════════════════════╝');
  } catch (e, stackTrace) {
    print('');
    print('❌ ERROR: $e');
    print('');
    print('Stack trace:');
    print(stackTrace);
  }
}
