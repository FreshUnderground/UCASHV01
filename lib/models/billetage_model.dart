import 'dart:convert';

/// Model representing currency denominations (billetage) for withdrawals
class BilletageModel {
  /// Map of denomination values to quantities
  /// Example: {100.0: 5, 50.0: 2} means 5 bills of $100 and 2 bills of $50
  final Map<double, int> denominations;

  BilletageModel({required this.denominations});

  /// Convert to JSON string for storage in the database
  String toJson() {
    final Map<String, dynamic> data = {
      'denominations': denominations.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
    return jsonEncode(data);
  }
  
  /// Convert to JSON map for API requests
  Map<String, dynamic> toMap() {
    return {
      'denominations': denominations.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  /// Create BilletageModel from JSON string
  static BilletageModel fromJson(String jsonString) {
    try {
      // Parse the JSON string
      final Map<String, dynamic> parsedMap = jsonDecode(jsonString);
      
      // Check if it has 'denominations' wrapper or is raw denominations
      final Map<String, dynamic> denominationsMap = parsedMap.containsKey('denominations')
          ? parsedMap['denominations'] as Map<String, dynamic>
          : parsedMap;
      
      final Map<double, int> denominations = {};
      
      denominationsMap.forEach((key, value) {
        final denomination = double.tryParse(key);
        if (denomination != null) {
          denominations[denomination] = value as int;
        }
      });
      
      return BilletageModel(denominations: denominations);
    } catch (e) {
      // Return empty billetage if parsing fails
      return BilletageModel(denominations: {});
    }
  }

  /// Calculate total amount represented by these denominations
  double get totalAmount {
    double total = 0;
    denominations.forEach((denomination, quantity) {
      total += denomination * quantity;
    });
    return total;
  }

  @override
  String toString() {
    return 'BilletageModel(denominations: $denominations)';
  }
}