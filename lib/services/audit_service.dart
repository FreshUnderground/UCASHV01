import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/audit_log_model.dart';
import 'agent_auth_service.dart';

/// Service d'audit trail - Traçabilité complète des modifications
class AuditService extends ChangeNotifier {
  static final AuditService _instance = AuditService._internal();
  static AuditService get instance => _instance;
  AuditService._internal();

  List<AuditLogModel> _audits = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<AuditLogModel> get audits => _audits;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Enregistre une action dans l'audit trail
  Future<void> logAudit({
    required String tableName,
    required int recordId,
    required AuditAction action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? reason,
  }) async {
    try {
      final authService = AgentAuthService();
      final currentUser = authService.currentAgent;

      // Calculer les champs modifiés
      List<String>? changedFields;
      if (oldValues != null && newValues != null) {
        changedFields = [];
        newValues.forEach((key, value) {
          if (oldValues[key] != value) {
            changedFields!.add(key);
          }
        });
      }

      final audit = AuditLogModel(
        tableName: tableName,
        recordId: recordId,
        action: action,
        oldValues: oldValues,
        newValues: newValues,
        changedFields: changedFields,
        userId: currentUser?.id,
        userRole: 'agent', // AgentModel n'a pas de champ role, toujours 'agent'
        username: currentUser?.username,
        shopId: currentUser?.shopId,
        deviceInfo: await _getDeviceInfo(),
        reason: reason,
        createdAt: DateTime.now(),
      );

      // Sauvegarder localement
      await _saveAuditLocally(audit);

      debugPrint('✅ Audit enregistré: ${action.label} sur $tableName #$recordId par ${currentUser?.username}');

      // Sync en arrière-plan (non bloquant)
      _syncAuditInBackground(audit);
    } catch (e) {
      debugPrint('❌ Erreur enregistrement audit: $e');
    }
  }

  /// Sauvegarde l'audit localement
  Future<void> _saveAuditLocally(AuditLogModel audit) async {
    final prefs = await SharedPreferences.getInstance();
    final auditId = audit.id ?? DateTime.now().millisecondsSinceEpoch;
    final key = 'audit_$auditId';
    await prefs.setString(key, jsonEncode(audit.toJson()));
    _audits.insert(0, audit); // Ajouter en début de liste (plus récent)
    notifyListeners();
  }

  /// Charge les audits depuis le stockage local
  Future<void> loadAudits({
    String? tableName,
    int? recordId,
    int? userId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('audit_')).toList();

      _audits.clear();
      for (final key in keys) {
        final auditJson = prefs.getString(key);
        if (auditJson != null) {
          try {
            final audit = AuditLogModel.fromJson(jsonDecode(auditJson));

            // Appliquer les filtres
            bool matches = true;
            if (tableName != null && audit.tableName != tableName) matches = false;
            if (recordId != null && audit.recordId != recordId) matches = false;
            if (userId != null && audit.userId != userId) matches = false;
            if (startDate != null && audit.createdAt.isBefore(startDate)) matches = false;
            if (endDate != null && audit.createdAt.isAfter(endDate)) matches = false;

            if (matches) {
              _audits.add(audit);
            }
          } catch (e) {
            debugPrint('⚠️ Erreur parsing audit $key: $e');
          }
        }
      }

      // Trier par date décroissante (plus récent en premier)
      _audits.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      debugPrint('📋 ${_audits.length} audits chargés');
      _errorMessage = null;
    } catch (e) {
      _errorMessage = 'Erreur chargement audits: $e';
      debugPrint(_errorMessage);
    }
    _setLoading(false);
  }

  /// Récupère l'historique complet d'un enregistrement
  Future<List<AuditLogModel>> getRecordHistory(String tableName, int recordId) async {
    await loadAudits(tableName: tableName, recordId: recordId);
    return _audits;
  }

  /// Récupère les audits d'un utilisateur
  Future<List<AuditLogModel>> getUserAudits(int userId) async {
    await loadAudits(userId: userId);
    return _audits;
  }

  /// Récupère les audits d'une période
  Future<List<AuditLogModel>> getAuditsByDateRange(DateTime start, DateTime end) async {
    await loadAudits(startDate: start, endDate: end);
    return _audits;
  }

  /// Statistiques des audits
  Map<String, dynamic> getAuditStats() {
    final actionCounts = <AuditAction, int>{};
    final tableCounts = <String, int>{};
    final userCounts = <int, int>{};

    for (final audit in _audits) {
      actionCounts[audit.action] = (actionCounts[audit.action] ?? 0) + 1;
      tableCounts[audit.tableName] = (tableCounts[audit.tableName] ?? 0) + 1;
      if (audit.userId != null) {
        userCounts[audit.userId!] = (userCounts[audit.userId!] ?? 0) + 1;
      }
    }

    return {
      'totalAudits': _audits.length,
      'actionCounts': actionCounts,
      'tableCounts': tableCounts,
      'userCounts': userCounts,
      'oldestAudit': _audits.isNotEmpty ? _audits.last.createdAt : null,
      'newestAudit': _audits.isNotEmpty ? _audits.first.createdAt : null,
    };
  }

  /// Synchronise un audit avec le serveur (en arrière-plan)
  Future<void> _syncAuditInBackground(AuditLogModel audit) async {
    // TODO: Implémenter l'upload vers le serveur
    // Pour l'instant, juste logger
    debugPrint('🔄 [Background] Sync audit vers serveur...');
  }

  /// Obtient les informations de l'appareil
  Future<String> _getDeviceInfo() async {
    if (kIsWeb) {
      return 'Web Browser';
    } else {
      // TODO: Utiliser device_info_plus pour obtenir les infos
      return 'Mobile App';
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
