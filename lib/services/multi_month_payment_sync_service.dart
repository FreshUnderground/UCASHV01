import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../config/sync_config.dart';
import '../models/multi_month_payment_model.dart';
import 'local_db.dart';
import 'multi_month_payment_service.dart';

/// Service de synchronisation pour les paiements multi-mois
/// 
/// Ce service synchronise la table multi_month_payments (SLOW SYNC)
/// Compatible avec l'architecture SharedPreferences existante
class MultiMonthPaymentSyncService {
  static final MultiMonthPaymentSyncService _instance = MultiMonthPaymentSyncService._internal();
  factory MultiMonthPaymentSyncService() => _instance;
  MultiMonthPaymentSyncService._internal();

  static MultiMonthPaymentSyncService get instance => _instance;

  bool _isSyncing = false;
  DateTime? _lastSyncTime;

  /// Synchronise tous les paiements multi-mois (upload + download)
  Future<bool> syncMultiMonthPayments({bool forceFullSync = false}) async {
    if (_isSyncing) {
      debugPrint('⚠️ Synchronisation paiements multi-mois déjà en cours');
      return false;
    }

    _isSyncing = true;
    debugPrint('🔄 ========== DÉBUT SYNC PAIEMENTS MULTI-MOIS ==========');

    try {
      // 1. Upload des données locales non synchronisées
      await _uploadMultiMonthPayments();

      // 2. Download des données du serveur
      await _downloadMultiMonthPayments(forceFullSync: forceFullSync);

      _lastSyncTime = DateTime.now();
      debugPrint('✅ Synchronisation paiements multi-mois terminée avec succès');
      debugPrint('🔄 ========== FIN SYNC PAIEMENTS MULTI-MOIS ==========');
      return true;
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors de la sync paiements multi-mois: $e');
      if (kDebugMode) {
        debugPrint('Stack trace: $stackTrace');
      }
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Upload des paiements multi-mois locaux vers le serveur
  Future<void> _uploadMultiMonthPayments() async {
    debugPrint('📤 Upload paiements multi-mois...');

    try {
      final baseUrl = await AppConfig.getApiBaseUrl();
      
      // Récupérer tous les paiements non synchronisés
      final unsyncedPayments = await _getUnsyncedMultiMonthPayments();
      
      if (unsyncedPayments.isEmpty) {
        debugPrint('  ℹ️ Aucun paiement multi-mois à uploader');
        return;
      }

      debugPrint('  📤 Upload de ${unsyncedPayments.length} paiements multi-mois');

      // Préparer les données pour l'upload
      List<Map<String, dynamic>> paymentData = [];
      for (var payment in unsyncedPayments) {
        var data = payment.toJson();
        data['_table'] = 'multi_month_payments';
        paymentData.add(data);
      }

      // Envoyer au serveur
      final response = await http.post(
        Uri.parse('$baseUrl/api/sync/multi_month_payments/upload.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'entities': paymentData}),
      ).timeout(SyncConfig.syncTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('  ✅ Upload terminé: ${result['uploaded_count']} insérés, ${result['updated_count']} mis à jour');
          
          // Marquer les paiements comme synchronisés localement
          for (var payment in unsyncedPayments) {
            final syncedPayment = payment.copyWith(
              isSynced: true,
              syncedAt: DateTime.now(),
            );
            await LocalDB.instance.updateMultiMonthPayment(syncedPayment);
          }
        } else {
          debugPrint('  ⚠️ Erreur upload: ${result['message'] ?? 'Erreur inconnue'}');
        }
      } else {
        debugPrint('  ❌ Upload failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Erreur upload: $e');
      rethrow;
    }
  }

  /// Download des paiements multi-mois du serveur
  Future<void> _downloadMultiMonthPayments({bool forceFullSync = false}) async {
    debugPrint('📥 Download paiements multi-mois...');

    try {
      final baseUrl = await AppConfig.getApiBaseUrl();
      
      // Construire l'URL avec le paramètre since si nécessaire
      String url = '$baseUrl/api/sync/multi_month_payments/changes.php';
      if (!forceFullSync) {
        final lastSync = await _getLastSyncTimestamp();
        if (lastSync != null) {
          url += '?since=${lastSync.toIso8601String()}';
        }
      }

      debugPrint('  📥 Download depuis $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      ).timeout(SyncConfig.syncTimeout);

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final changes = result['changes'] as List? ?? [];
          
          if (changes.isEmpty) {
            debugPrint('  ℹ️ Aucun nouveau paiement multi-mois');
            await _updateLastSyncTimestamp();
            return;
          }

          debugPrint('  📥 ${changes.length} paiements multi-mois reçus');

          // Insérer/Mettre à jour les données locales
          for (var change in changes) {
            try {
              final payment = MultiMonthPaymentModel.fromJson(change);
              
              // Vérifier si le paiement existe déjà localement
              final existingPayment = await LocalDB.instance.getMultiMonthPaymentById(payment.id!);
              
              if (existingPayment != null) {
                // Mettre à jour seulement si la version serveur est plus récente
                if (payment.lastModifiedAt != null && 
                    existingPayment.lastModifiedAt != null &&
                    payment.lastModifiedAt!.isAfter(existingPayment.lastModifiedAt!)) {
                  await LocalDB.instance.updateMultiMonthPayment(payment.copyWith(isSynced: true));
                  debugPrint('  🔄 Paiement multi-mois mis à jour: ${payment.reference}');
                }
              } else {
                // Nouveau paiement
                await LocalDB.instance.saveMultiMonthPayment(payment.copyWith(isSynced: true));
                debugPrint('  ➕ Nouveau paiement multi-mois: ${payment.reference}');
              }
            } catch (e) {
              debugPrint('  ⚠️ Erreur traitement paiement: $e');
            }
          }
          
          // Mettre à jour le timestamp
          await _updateLastSyncTimestamp();
          
          debugPrint('  ✅ Download terminé');
        } else {
          debugPrint('  ⚠️ Erreur download: ${result['message'] ?? 'Erreur inconnue'}');
        }
      } else {
        debugPrint('  ❌ Download failed: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('  ❌ Erreur download: $e');
      rethrow;
    }
  }

  /// Récupère les paiements multi-mois non synchronisés
  Future<List<MultiMonthPaymentModel>> _getUnsyncedMultiMonthPayments() async {
    final allPayments = await LocalDB.instance.getAllMultiMonthPayments();
    return allPayments.where((payment) => !payment.isSynced).toList();
  }

  /// Récupère le timestamp de dernière synchronisation
  Future<DateTime?> _getLastSyncTimestamp() async {
    final prefs = await LocalDB.instance.database;
    final timestampStr = prefs.getString('multi_month_payments_last_sync');
    if (timestampStr != null) {
      try {
        return DateTime.parse(timestampStr);
      } catch (e) {
        debugPrint('⚠️ Erreur parsing timestamp sync: $e');
        return null;
      }
    }
    return null;
  }

  /// Met à jour le timestamp de dernière synchronisation
  Future<void> _updateLastSyncTimestamp() async {
    final prefs = await LocalDB.instance.database;
    await prefs.setString('multi_month_payments_last_sync', DateTime.now().toIso8601String());
  }

  /// Force la synchronisation d'un paiement spécifique
  Future<bool> forceSyncPayment(MultiMonthPaymentModel payment) async {
    try {
      debugPrint('🔄 Force sync paiement: ${payment.reference}');
      
      // Marquer comme non synchronisé pour forcer l'upload
      final unsyncedPayment = payment.copyWith(
        isSynced: false,
        lastModifiedAt: DateTime.now(),
      );
      
      await LocalDB.instance.updateMultiMonthPayment(unsyncedPayment);
      
      // Lancer une synchronisation
      return await syncMultiMonthPayments();
    } catch (e) {
      debugPrint('❌ Erreur force sync: $e');
      return false;
    }
  }

  /// Nettoie les paiements multi-mois supprimés côté serveur
  Future<void> cleanupDeletedPayments(List<String> deletedReferences) async {
    if (deletedReferences.isEmpty) return;
    
    debugPrint('🧹 Nettoyage ${deletedReferences.length} paiements supprimés');
    
    for (String reference in deletedReferences) {
      try {
        final payment = await LocalDB.instance.getMultiMonthPaymentByReference(reference);
        if (payment != null) {
          await LocalDB.instance.deleteMultiMonthPayment(payment.id!);
          debugPrint('  🗑️ Paiement supprimé localement: $reference');
        }
      } catch (e) {
        debugPrint('  ⚠️ Erreur suppression $reference: $e');
      }
    }
  }

  /// Statistiques de synchronisation
  Map<String, dynamic> getSyncStats() {
    return {
      'isSyncing': _isSyncing,
      'lastSyncTime': _lastSyncTime,
    };
  }

  /// Getters
  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncTime => _lastSyncTime;
}
