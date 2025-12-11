import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/shop_model.dart';

enum AdjustmentType {
  increase,  // Augmentation
  decrease,  // Diminution
}

enum PaymentMode {
  cash,
  airtelMoney,
  mpesa,
  orangeMoney,
}

class CapitalAdjustment {
  final int? auditId;
  final int shopId;
  final String shopName;
  final String? shopLocation;
  final AdjustmentType adjustmentType;
  final double amount;
  final PaymentMode modePaiement;
  final double capitalBefore;
  final double capitalAfter;
  final double difference;
  final String reason;
  final String? description;
  final int adminId;
  final String adminUsername;
  final DateTime createdAt;
  
  CapitalAdjustment({
    this.auditId,
    required this.shopId,
    required this.shopName,
    this.shopLocation,
    required this.adjustmentType,
    required this.amount,
    required this.modePaiement,
    required this.capitalBefore,
    required this.capitalAfter,
    required this.difference,
    required this.reason,
    this.description,
    required this.adminId,
    required this.adminUsername,
    required this.createdAt,
  });
  
  factory CapitalAdjustment.fromJson(Map<String, dynamic> json) {
    return CapitalAdjustment(
      auditId: json['id'],
      shopId: json['shop_id'],
      shopName: json['shop_name'] ?? '',
      shopLocation: json['shop_location'],
      adjustmentType: json['adjustment_type'] == 'CAPITAL_INCREASE' 
        ? AdjustmentType.increase 
        : AdjustmentType.decrease,
      amount: (json['amount'] ?? 0).toDouble(),
      modePaiement: _parsePaymentMode(json['mode_paiement']),
      capitalBefore: (json['capital_before'] ?? 0).toDouble(),
      capitalAfter: (json['capital_after'] ?? 0).toDouble(),
      difference: (json['difference'] ?? 0).toDouble(),
      reason: json['reason'] ?? '',
      description: json['description'],
      adminId: json['admin_id'],
      adminUsername: json['admin_username'] ?? 'admin',
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  static PaymentMode _parsePaymentMode(String? mode) {
    switch (mode?.toLowerCase()) {
      case 'airtel_money':
        return PaymentMode.airtelMoney;
      case 'mpesa':
        return PaymentMode.mpesa;
      case 'orange_money':
        return PaymentMode.orangeMoney;
      default:
        return PaymentMode.cash;
    }
  }
  
  String get adjustmentTypeLabel {
    return adjustmentType == AdjustmentType.increase 
      ? 'Augmentation' 
      : 'Diminution';
  }
  
  String get modePaiementLabel {
    switch (modePaiement) {
      case PaymentMode.airtelMoney:
        return 'Airtel Money';
      case PaymentMode.mpesa:
        return 'M-Pesa';
      case PaymentMode.orangeMoney:
        return 'Orange Money';
      case PaymentMode.cash:
      default:
        return 'Cash';
    }
  }
}

class CapitalAdjustmentService extends ChangeNotifier {
  static final CapitalAdjustmentService _instance = CapitalAdjustmentService._internal();
  static CapitalAdjustmentService get instance => _instance;
  
  CapitalAdjustmentService._internal();
  
  List<CapitalAdjustment> _adjustments = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<CapitalAdjustment> get adjustments => _adjustments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  /// Créer un ajustement de capital
  Future<Map<String, dynamic>?> createAdjustment({
    required ShopModel shop,
    required AdjustmentType adjustmentType,
    required double amount,
    required PaymentMode modePaiement,
    required String reason,
    String? description,
    required int adminId,
    required String adminUsername,
  }) async {
    try {
      debugPrint('📤 [CapitalAdjustmentService] Création ajustement capital pour ${shop.designation}');
      
      final baseUrl = await AppConfig.getSyncBaseUrl();
      final url = Uri.parse('$baseUrl/audit/log_capital_adjustment.php');
      
      final payload = {
        'shop_id': shop.id,
        'adjustment_type': adjustmentType == AdjustmentType.increase ? 'INCREASE' : 'DECREASE',
        'amount': amount,
        'mode_paiement': _paymentModeToString(modePaiement),
        'reason': reason,
        'description': description,
        'admin_id': adminId,
        'admin_username': adminUsername,
      };
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          debugPrint('✅ Ajustement capital enregistré: ${result['adjustment']['audit_id']}');
          
          // Recharger l'historique
          await loadAdjustments(shopId: shop.id);
          
          return result;
        } else {
          _errorMessage = result['message'] ?? 'Erreur inconnue';
          debugPrint('❌ Erreur: $_errorMessage');
          return null;
        }
      } else {
        _errorMessage = 'Erreur HTTP: ${response.statusCode}';
        debugPrint('❌ $_errorMessage');
        return null;
      }
    } catch (e) {
      _errorMessage = 'Erreur réseau: $e';
      debugPrint('❌ $_errorMessage');
      return null;
    }
  }
  
  /// Charger l'historique des ajustements
  Future<void> loadAdjustments({
    int? shopId,
    int? adminId,
    String? startDate,
    String? endDate,
    int limit = 50,
  }) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final baseUrl = await AppConfig.getSyncBaseUrl();
      final queryParams = <String, String>{
        'limit': limit.toString(),
      };
      
      if (shopId != null) queryParams['shop_id'] = shopId.toString();
      if (adminId != null) queryParams['admin_id'] = adminId.toString();
      if (startDate != null) queryParams['start_date'] = startDate;
      if (endDate != null) queryParams['end_date'] = endDate;
      
      final url = Uri.parse('$baseUrl/audit/get_capital_adjustments.php')
          .replace(queryParameters: queryParams);
      
      final response = await http.get(
        url,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          _adjustments = (result['adjustments'] as List)
              .map((json) => CapitalAdjustment.fromJson(json))
              .toList();
          
          _errorMessage = null;
          debugPrint('✅ ${_adjustments.length} ajustements chargés');
        } else {
          _errorMessage = result['message'];
        }
      } else {
        _errorMessage = 'Erreur HTTP: ${response.statusCode}';
      }
    } catch (e) {
      _errorMessage = 'Erreur: $e';
      debugPrint('❌ $_errorMessage');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  String _paymentModeToString(PaymentMode mode) {
    switch (mode) {
      case PaymentMode.airtelMoney:
        return 'airtel_money';
      case PaymentMode.mpesa:
        return 'mpesa';
      case PaymentMode.orangeMoney:
        return 'orange_money';
      case PaymentMode.cash:
      default:
        return 'cash';
    }
  }
}
