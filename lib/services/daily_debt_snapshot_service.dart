import 'package:flutter/foundation.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/daily_intershop_debt_snapshot_model.dart';
import 'local_db.dart';

/// Service to manage daily inter-shop debt snapshots
/// Avoids recalculating debts from the beginning by storing daily balances
class DailyDebtSnapshotService {
  static final DailyDebtSnapshotService _instance =
      DailyDebtSnapshotService._internal();
  static DailyDebtSnapshotService get instance => _instance;

  DailyDebtSnapshotService._internal();

  /// Calculate and save today's snapshot for a shop
  /// Call this at the end of each day (during closure)
  Future<void> saveSnapshotForDate({
    required int shopId,
    required DateTime date,
  }) async {
    try {
      debugPrint(
          '📸 Creating debt snapshots for shop $shopId on ${date.toIso8601String().split('T')[0]}');

      // Get all operations for today
      final allOperations = await LocalDB.instance.getAllOperations();
      final shops = await LocalDB.instance.getAllShops();
      final shopsMap = {for (var shop in shops) shop.id: shop};

      // Filter operations for this date
      final todayOperations = allOperations.where((op) {
        final opDate = op.dateOp;
        return opDate.year == date.year &&
            opDate.month == date.month &&
            opDate.day == date.day;
      }).toList();

      // Group operations by other shop (calculate debts/credits per shop pair)
      final Map<int, _DebtMovement> movementsByShop = {};

      for (final op in todayOperations) {
        // Only process transfers and flots between shops
        if (op.type == OperationType.transfertNational ||
            op.type == OperationType.transfertInternationalEntrant ||
            op.type == OperationType.transfertInternationalSortant ||
            op.type == OperationType.flotShopToShop) {
          // NEW LOGIC: Direct source → destination debt
          final sourceId = op.shopSourceId;
          final destId = op.shopDestinationId;

          if (sourceId == null || destId == null) continue;
          if (sourceId == destId) continue; // Ignore internal ops

          // If we are the source shop
          if (sourceId == shopId && destId != shopId) {
            // We OWE the destination shop (dette)
            movementsByShop[destId] ??= _DebtMovement();
            movementsByShop[destId]!.dettesDuJour += op.montantBrut;
          }

          // If we are the destination shop
          if (destId == shopId && sourceId != shopId) {
            // The source shop OWES us (créance)
            movementsByShop[sourceId] ??= _DebtMovement();
            movementsByShop[sourceId]!.creancesDuJour += op.montantBrut;
          }
        }
      }

      // For each shop pair, create or update snapshot
      for (final entry in movementsByShop.entries) {
        final otherShopId = entry.key;
        final movement = entry.value;

        // Get yesterday's snapshot (dette_anterieure)
        final yesterday = date.subtract(const Duration(days: 1));
        final yesterdaySnapshot = await LocalDB.instance.getDailyDebtSnapshot(
          shopId: shopId,
          otherShopId: otherShopId,
          date: yesterday,
        );

        final detteAnterieure = yesterdaySnapshot?['solde_cumule'] ?? 0.0;

        // Calculate cumulative balance
        // Positive = they owe us (créance), Negative = we owe them (dette)
        final soldeCumule =
            detteAnterieure + movement.creancesDuJour - movement.dettesDuJour;

        // Save snapshot
        final snapshot = {
          'shop_id': shopId,
          'other_shop_id': otherShopId,
          'date': date.toIso8601String().split('T')[0],
          'dette_anterieure': detteAnterieure,
          'creances_du_jour': movement.creancesDuJour,
          'dettes_du_jour': movement.dettesDuJour,
          'solde_cumule': soldeCumule,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
          'synced': 0,
          'sync_version': 1,
        };

        await LocalDB.instance.saveDailyDebtSnapshot(snapshot);

        final otherShopName =
            shopsMap[otherShopId]?.designation ?? 'Shop $otherShopId';
        debugPrint('  💾 Saved snapshot: $otherShopName → '
            'Anterieure: ${detteAnterieure.toStringAsFixed(2)}, '
            'Creances: ${movement.creancesDuJour.toStringAsFixed(2)}, '
            'Dettes: ${movement.dettesDuJour.toStringAsFixed(2)}, '
            'Cumule: ${soldeCumule.toStringAsFixed(2)}');
      }

      debugPrint(
          '✅ Saved ${movementsByShop.length} debt snapshots for shop $shopId');
    } catch (e) {
      debugPrint('❌ Error saving debt snapshots: $e');
      rethrow;
    }
  }

  /// Get debt evolution for a shop over a date range using snapshots
  /// This is MUCH faster than recalculating from day 1
  Future<List<Map<String, dynamic>>> getDebtEvolution({
    required int shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint(
          '📊 Getting debt evolution for shop $shopId from ${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]}');

      // Get all snapshots for this shop in the date range
      final snapshots =
          await LocalDB.instance.getDailyDebtSnapshotsForShopInRange(
        shopId: shopId,
        startDate: startDate,
        endDate: endDate,
      );

      // Group by date
      final Map<String, List<Map<String, dynamic>>> snapshotsByDate = {};
      for (final snapshot in snapshots) {
        final date = snapshot['date'] as String;
        snapshotsByDate[date] ??= [];
        snapshotsByDate[date]!.add(snapshot);
      }

      // Build evolution data (one entry per date)
      final evolution = <Map<String, dynamic>>[];
      final shops = await LocalDB.instance.getAllShops();
      final shopsMap = {for (var shop in shops) shop.id: shop.designation};

      for (final entry in snapshotsByDate.entries) {
        final date = entry.key;
        final daySnapshots = entry.value;

        // Aggregate totals for this day
        double totalCreances = 0.0;
        double totalDettes = 0.0;
        double detteAnterieure = 0.0;
        final Map<String, double> balancesByShop = {};

        for (final snapshot in daySnapshots) {
          final otherShopId = snapshot['other_shop_id'] as int;
          final otherShopName = shopsMap[otherShopId] ?? 'Shop $otherShopId';

          totalCreances += (snapshot['creances_du_jour'] as num).toDouble();
          totalDettes += (snapshot['dettes_du_jour'] as num).toDouble();
          detteAnterieure += (snapshot['dette_anterieure'] as num).toDouble();

          final soldeCumule = (snapshot['solde_cumule'] as num).toDouble();
          balancesByShop[otherShopName] = soldeCumule;
        }

        final soldeDuJour = totalCreances - totalDettes;
        final soldeCumule = detteAnterieure + soldeDuJour;

        evolution.add({
          'date': date,
          'dette_anterieure': detteAnterieure,
          'creances_du_jour': totalCreances,
          'dettes_du_jour': totalDettes,
          'solde_du_jour': soldeDuJour,
          'solde_cumule': soldeCumule,
          'balances_by_shop': balancesByShop,
          'transaction_count': daySnapshots.length,
        });
      }

      // Sort by date
      evolution
          .sort((a, b) => (a['date'] as String).compareTo(b['date'] as String));

      debugPrint('✅ Retrieved ${evolution.length} days of debt evolution');
      return evolution;
    } catch (e) {
      debugPrint('❌ Error getting debt evolution: $e');
      rethrow;
    }
  }

  /// Check if snapshots exist for a date range
  /// If missing, recalculate and create them
  Future<void> ensureSnapshotsExist({
    required int shopId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      debugPrint(
          '🔍 Checking snapshots for shop $shopId from ${startDate.toIso8601String().split('T')[0]} to ${endDate.toIso8601String().split('T')[0]}');

      // Check each day in the range
      DateTime currentDate = startDate;
      int missingDays = 0;

      while (!currentDate.isAfter(endDate)) {
        final snapshots =
            await LocalDB.instance.getDailyDebtSnapshotsForShopAndDate(
          shopId: shopId,
          date: currentDate,
        );

        // If no snapshots exist for this date, create them
        if (snapshots.isEmpty) {
          debugPrint(
              '⚠️ Missing snapshots for ${currentDate.toIso8601String().split('T')[0]}, creating...');
          await saveSnapshotForDate(shopId: shopId, date: currentDate);
          missingDays++;
        }

        currentDate = currentDate.add(const Duration(days: 1));
      }

      if (missingDays > 0) {
        debugPrint('✅ Created snapshots for $missingDays missing days');
      } else {
        debugPrint('✅ All snapshots exist for the date range');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring snapshots exist: $e');
      rethrow;
    }
  }

  /// Clean old snapshots (older than X days)
  Future<int> cleanOldSnapshots({int keepDays = 365}) async {
    final cutoffDate = DateTime.now().subtract(Duration(days: keepDays));
    return await LocalDB.instance.cleanOldDebtSnapshots(beforeDate: cutoffDate);
  }
}

/// Helper class to track debt movements for a day
class _DebtMovement {
  double creancesDuJour = 0.0; // What others owe us
  double dettesDuJour = 0.0; // What we owe others
}
