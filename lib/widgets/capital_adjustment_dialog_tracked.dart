import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/shop_model.dart';
import '../services/shop_service.dart';
import '../services/capital_adjustment_service.dart';
import '../services/auth_service.dart';

class CapitalAdjustmentDialogWithTracking extends StatefulWidget {
  final ShopModel shop;

  const CapitalAdjustmentDialogWithTracking({super.key, required this.shop});

  @override
  State<CapitalAdjustmentDialogWithTracking> createState() => _CapitalAdjustmentDialogWithTrackingState();
}

class _CapitalAdjustmentDialogWithTrackingState extends State<CapitalAdjustmentDialogWithTracking> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  AdjustmentType _adjustmentType = AdjustmentType.increase;
  PaymentMode _paymentMode = PaymentMode.cash;
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      
      if (user == null) {
        final l10n = AppLocalizations.of(context)!;
        throw Exception(l10n.userNotConnected);
      }

      final amount = double.parse(_amountController.text.trim());
      final reason = _reasonController.text.trim();
      final description = _descriptionController.text.trim();

      final capitalAdjustmentService = CapitalAdjustmentService.instance;
      
      final result = await capitalAdjustmentService.createAdjustment(
        shop: widget.shop,
        adjustmentType: _adjustmentType,
        amount: amount,
        modePaiement: _paymentMode,
        reason: reason,
        description: description.isNotEmpty ? description : null,
        adminId: user.id!,
        adminUsername: user.username,
      );

      if (result != null && result['success'] == true) {
        if (mounted) {
          // Recharger les shops pour voir les modifications
          await Provider.of<ShopService>(context, listen: false).loadShops(forceRefresh: true);
          
          Navigator.of(context).pop(true);
          
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('✅ ${l10n.capitalAdjustedSuccessfully}'),
                  SizedBox(height: 4),
                  Text(
                    'Capital: ${result['adjustment']['capital_before']} → ${result['adjustment']['capital_after']} USD',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '${l10n.auditId}: ${result['adjustment']['audit_id']}',
                    style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 5),
            ),
          );
        }
      } else {
        throw Exception(capitalAdjustmentService.errorMessage ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${l10n.error}: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.account_balance_wallet, color: Color(0xFFDC2626)),
          SizedBox(width: 12),
          Text(l10n.adjustCapital),
        ],
      ),
      content: Container(
        width: 550,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Informations du shop
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏪 ${widget.shop.designation}',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      _buildCapitalRow('Capital actuel total', widget.shop.capitalActuel, Colors.blue),
                      Divider(height: 16),
                      _buildCapitalRow('Cash', widget.shop.capitalCash, Colors.green),
                      _buildCapitalRow('Airtel Money', widget.shop.capitalAirtelMoney, Colors.red),
                      _buildCapitalRow('M-Pesa', widget.shop.capitalMPesa, Colors.green),
                      _buildCapitalRow('Orange Money', widget.shop.capitalOrangeMoney, Colors.orange),
                    ],
                  ),
                ),
                SizedBox(height: 20),
                
                // Type d'ajustement
                Text('${l10n.adjustmentType} *', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                DropdownButtonFormField<AdjustmentType>(
                  value: _adjustmentType,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: AdjustmentType.increase,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_upward, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.increaseCapital),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: AdjustmentType.decrease,
                      child: Row(
                        children: [
                          Icon(Icons.arrow_downward, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.decreaseCapital),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _adjustmentType = value);
                    }
                  },
                ),
                SizedBox(height: 16),
                
                // Mode de paiement
                Text('${l10n.paymentMode} *', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                DropdownButtonFormField<PaymentMode>(
                  value: _paymentMode,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: PaymentMode.cash,
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.cash),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: PaymentMode.airtelMoney,
                      child: Row(
                        children: [
                          Icon(Icons.phone_android, color: Colors.red, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.airtelMoney),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: PaymentMode.mpesa,
                      child: Row(
                        children: [
                          Icon(Icons.phone_android, color: Colors.green, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.mPesa),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: PaymentMode.orangeMoney,
                      child: Row(
                        children: [
                          Icon(Icons.phone_android, color: Colors.orange, size: 18),
                          SizedBox(width: 8),
                          Text(l10n.orangeMoney),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _paymentMode = value);
                    }
                  },
                ),
                SizedBox(height: 16),
                
                // Montant
                Text('${l10n.amount} (USD) *', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: l10n.exampleAmount,
                    prefixIcon: Icon(Icons.attach_money),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.amountRequired;
                    }
                    final amount = double.tryParse(value);
                    if (amount == null || amount <= 0) {
                      return l10n.invalidAmount;
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
                SizedBox(height: 16),
                
                // Raison (obligatoire)
                Text('${l10n.reason} *', style: TextStyle(fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Ex: Injection de capital supplémentaire pour augmenter liquidité',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.reasonRequired;
                    }
                    if (value.trim().length < 10) {
                      return l10n.reasonMinLength;
                    }
                    return null;
                  },
                ),
                SizedBox(height: 16),
                
                // Description (optionnelle)
                Text(l10n.detailedDescription, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[600])),
                SizedBox(height: 8),
                TextFormField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: l10n.descriptionOptional,
                  ),
                ),
                SizedBox(height: 16),
                
                // Aperçu du résultat
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _adjustmentType == AdjustmentType.increase 
                      ? Colors.green[50] 
                      : Colors.orange[50],
                    border: Border.all(
                      color: _adjustmentType == AdjustmentType.increase 
                        ? Colors.green 
                        : Colors.red,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildPreview(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _handleSubmit,
          icon: _isLoading 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : Icon(Icons.check_circle),
          label: Text(_isLoading ? l10n.loading : l10n.confirmAdjustment),
          style: ElevatedButton.styleFrom(
            backgroundColor: Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCapitalRow(String label, double amount, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPreview() {
    final l10n = AppLocalizations.of(context)!;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final isIncrease = _adjustmentType == AdjustmentType.increase;
    final newCapitalTotal = isIncrease
      ? widget.shop.capitalActuel + amount
      : widget.shop.capitalActuel - amount;
    
    double newModeCapital = 0.0;
    String modeLabel = '';
    
    switch (_paymentMode) {
      case PaymentMode.cash:
        newModeCapital = widget.shop.capitalCash + (isIncrease ? amount : -amount);
        modeLabel = l10n.cash;
        break;
      case PaymentMode.airtelMoney:
        newModeCapital = widget.shop.capitalAirtelMoney + (isIncrease ? amount : -amount);
        modeLabel = l10n.airtelMoney;
        break;
      case PaymentMode.mpesa:
        newModeCapital = widget.shop.capitalMPesa + (isIncrease ? amount : -amount);
        modeLabel = l10n.mPesa;
        break;
      case PaymentMode.orangeMoney:
        newModeCapital = widget.shop.capitalOrangeMoney + (isIncrease ? amount : -amount);
        modeLabel = l10n.orangeMoney;
        break;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.info_outline,
              size: 16,
              color: isIncrease ? Colors.green[700] : Colors.red[700],
            ),
            SizedBox(width: 8),
            Text(
              l10n.adjustmentPreview,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: isIncrease ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        
        // Capital total
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.currentCapitalTotal}:', style: TextStyle(fontSize: 12)),
            Text(
              '${widget.shop.capitalActuel.toStringAsFixed(2)} USD',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
        SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.adjustment} ($modeLabel):', style: TextStyle(fontSize: 12)),
            Text(
              '${isIncrease ? '+' : '-'}${amount.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: isIncrease ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
        Divider(height: 16, thickness: 2),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${l10n.newCapitalTotal}:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            Text(
              '${newCapitalTotal.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isIncrease ? Colors.green[700] : Colors.red[700],
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Nouveau $modeLabel:', style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            Text(
              '${newModeCapital.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
