import 'dart:convert';
import 'package:flutter/material.dart';

/// Modèle pour l'audit trail (journal d'audit)
/// Trace toutes les modifications importantes dans le système
class AuditLogModel {
  final int? id;
  final String tableName;
  final int recordId;
  final AuditAction action;
  final Map<String, dynamic>? oldValues;
  final Map<String, dynamic>? newValues;
  final List<String>? changedFields;
  final int? userId;
  final String? userRole;
  final String? username;
  final int? shopId;
  final String? ipAddress;
  final String? deviceInfo;
  final String? reason;
  final DateTime createdAt;

  AuditLogModel({
    this.id,
    required this.tableName,
    required this.recordId,
    required this.action,
    this.oldValues,
    this.newValues,
    this.changedFields,
    this.userId,
    this.userRole,
    this.username,
    this.shopId,
    this.ipAddress,
    this.deviceInfo,
    this.reason,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'table_name': tableName,
        'record_id': recordId,
        'action': action.name.toUpperCase(),
        'old_values': oldValues != null ? _encodeJson(oldValues!) : null,
        'new_values': newValues != null ? _encodeJson(newValues!) : null,
        'changed_fields': changedFields != null ? _encodeJson(changedFields!) : null,
        'user_id': userId,
        'user_role': userRole,
        'username': username,
        'shop_id': shopId,
        'ip_address': ipAddress,
        'device_info': deviceInfo,
        'reason': reason,
        'created_at': createdAt.toIso8601String(),
      };

  factory AuditLogModel.fromJson(Map<String, dynamic> json) => AuditLogModel(
        id: json['id'] as int?,
        tableName: json['table_name'] as String,
        recordId: json['record_id'] as int,
        action: AuditAction.values.firstWhere(
          (e) => e.name.toUpperCase() == (json['action'] as String).toUpperCase(),
        ),
        oldValues: json['old_values'] != null ? _decodeJson(json['old_values']) : null,
        newValues: json['new_values'] != null ? _decodeJson(json['new_values']) : null,
        changedFields: json['changed_fields'] != null 
            ? List<String>.from(_decodeJson(json['changed_fields'])) 
            : null,
        userId: json['user_id'] as int?,
        userRole: json['user_role'] as String?,
        username: json['username'] as String?,
        shopId: json['shop_id'] as int?,
        ipAddress: json['ip_address'] as String?,
        deviceInfo: json['device_info'] as String?,
        reason: json['reason'] as String?,
        createdAt: json['created_at'] is String
            ? DateTime.parse(json['created_at'] as String)
            : (json['created_at'] as DateTime? ?? DateTime.now()),
      );

  AuditLogModel copyWith({
    int? id,
    String? tableName,
    int? recordId,
    AuditAction? action,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    List<String>? changedFields,
    int? userId,
    String? userRole,
    String? username,
    int? shopId,
    String? ipAddress,
    String? deviceInfo,
    String? reason,
    DateTime? createdAt,
  }) =>
      AuditLogModel(
        id: id ?? this.id,
        tableName: tableName ?? this.tableName,
        recordId: recordId ?? this.recordId,
        action: action ?? this.action,
        oldValues: oldValues ?? this.oldValues,
        newValues: newValues ?? this.newValues,
        changedFields: changedFields ?? this.changedFields,
        userId: userId ?? this.userId,
        userRole: userRole ?? this.userRole,
        username: username ?? this.username,
        shopId: shopId ?? this.shopId,
        ipAddress: ipAddress ?? this.ipAddress,
        deviceInfo: deviceInfo ?? this.deviceInfo,
        reason: reason ?? this.reason,
        createdAt: createdAt ?? this.createdAt,
      );

  static String _encodeJson(dynamic value) {
    if (value is String) return value;
    return jsonEncode(value);
  }

  static dynamic _decodeJson(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      try {
        return jsonDecode(value);
      } catch (e) {
        return value;
      }
    }
    return value;
  }
}

enum AuditAction {
  CREATE,
  UPDATE,
  DELETE,
  VALIDATE,
  CANCEL,
}

/// Extension pour obtenir un label lisible
extension AuditActionLabel on AuditAction {
  String get label {
    switch (this) {
      case AuditAction.CREATE:
        return 'Création';
      case AuditAction.UPDATE:
        return 'Modification';
      case AuditAction.DELETE:
        return 'Suppression';
      case AuditAction.VALIDATE:
        return 'Validation';
      case AuditAction.CANCEL:
        return 'Annulation';
    }
  }

  IconData get icon {
    switch (this) {
      case AuditAction.CREATE:
        return Icons.add_circle;
      case AuditAction.UPDATE:
        return Icons.edit;
      case AuditAction.DELETE:
        return Icons.delete;
      case AuditAction.VALIDATE:
        return Icons.check_circle;
      case AuditAction.CANCEL:
        return Icons.cancel;
    }
  }

  Color get color {
    switch (this) {
      case AuditAction.CREATE:
        return Colors.green;
      case AuditAction.UPDATE:
        return Colors.blue;
      case AuditAction.DELETE:
        return Colors.red;
      case AuditAction.VALIDATE:
        return Colors.teal;
      case AuditAction.CANCEL:
        return Colors.orange;
    }
  }
}