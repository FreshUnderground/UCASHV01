import 'package:flutter/material.dart';
import '../models/billetage_model.dart';

/// Dialog for entering currency denominations (Billetage) during withdrawal validation
class BilletageInputDialog extends StatefulWidget {
  final double amount;
  final String currency;
  
  const BilletageInputDialog({
    super.key,
    required this.amount,
    required this.currency,
  });

  @override
  State<BilletageInputDialog> createState() => _BilletageInputDialogState();
}

class _BilletageInputDialogState extends State<BilletageInputDialog> {
  // Standard USD denominations
  final List<double> _denominations = [100, 50, 20, 10, 5, 1];
  final Map<double, TextEditingController> _controllers = {};
  
  @override
  void initState() {
    super.initState();
    // Initialize controllers with empty text
    for (var denom in _denominations) {
      _controllers[denom] = TextEditingController();
    }
  }
  
  @override
  void dispose() {
    // Dispose all controllers
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Colors.green),
          SizedBox(width: 12),
          Text('Billetage'),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.8,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Montant à donner: ${widget.amount.toStringAsFixed(2)} ${widget.currency}',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            // Denomination table
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  // Table header
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4CAF50),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Coupure',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Qté',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Total',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Denomination rows
                  ..._denominations.map((denom) {
                    return _buildDenominationRow(denom);
                  }),
                  // Total row
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(8)),
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text(
                            'TOTAL',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const Expanded(
                          flex: 2,
                          child: SizedBox(),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${_calculateTotal().toStringAsFixed(2)} ${widget.currency}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Validation message
            if ((_calculateTotal() - widget.amount).abs() > 0.01)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Montant Incorrect',
                        style: TextStyle(color: Colors.orange, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: () {
            // Validate that total matches the expected amount
            final total = _calculateTotal();
            if ((total - widget.amount).abs() <= 0.01) {
              // Create BilletageModel with the entered data
              final denominations = <double, int>{};
              for (var denom in _denominations) {
                final text = _controllers[denom]!.text;
                if (text.isNotEmpty) {
                  final quantity = int.tryParse(text) ?? 0;
                  if (quantity > 0) {
                    denominations[denom] = quantity;
                  }
                }
              }
              
              final billetage = BilletageModel(denominations: denominations);
              Navigator.of(context).pop(billetage);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
          ),
          child: const Text('Valider'),
        ),
      ],
    );
  }
  
  Widget _buildDenominationRow(double denomination) {
    final isCoin = denomination < 1;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isCoin ? Colors.orange.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isCoin 
                        ? '${denomination.toStringAsFixed(denomination == 0.01 ? 2 : 2)} ¢' 
                        : '${denomination.toStringAsFixed(0)}',
                    style: TextStyle(
                      color: isCoin ? Colors.orange.shade800 : Colors.blue.shade800,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: TextField(
              controller: _controllers[denomination],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {}); // Trigger rebuild to update total
              },
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${(_getQuantity(denomination) * denomination).toStringAsFixed(2)} \$',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  int _getQuantity(double denomination) {
    final text = _controllers[denomination]!.text;
    return text.isEmpty ? 0 : (int.tryParse(text) ?? 0);
  }
  
  double _calculateTotal() {
    double total = 0;
    for (var denom in _denominations) {
      total += _getQuantity(denom) * denom;
    }
    return total;
  }
}