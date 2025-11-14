import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shop_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/operation_model.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';
import '../services/agent_auth_service.dart';

class CapitalAdjustmentDialog extends StatefulWidget {
  final ShopModel shop;

  const CapitalAdjustmentDialog({super.key, required this.shop});

  @override
  State<CapitalAdjustmentDialog> createState() => _CapitalAdjustmentDialogState();
}

class _CapitalAdjustmentDialogState extends State<CapitalAdjustmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;
  ModePaiement _selectedMode = ModePaiement.cash;
  TypeMouvement _movementType = TypeMouvement.entree;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final amount = double.parse(_amountController.text.trim());
      
      // Update shop capital
      final updatedShop = _updateShopCapital(widget.shop, _selectedMode, amount, _movementType == TypeMouvement.entree);
      
      // Save updated shop
      await LocalDB.instance.saveShop(updatedShop);
      
      // Update shop service
      final shopService = Provider.of<ShopService>(context, listen: false);
      await shopService.loadShops(); // Refresh shops list
      
      // Get current agent
      final agentAuthService = Provider.of<AgentAuthService>(context, listen: false);
      final currentAgent = agentAuthService.currentAgent;
      final agentId = currentAgent?.id ?? 1;
      final agentName = currentAgent?.username ?? 'admin';
      
      // Create journal entry
      final journalEntry = JournalCaisseModel(
        shopId: updatedShop.id!,
        agentId: agentId,
        libelle: 'Ajustement Capital - ${_movementType == TypeMouvement.entree ? 'Ajout' : 'Retrait'}',
        montant: amount,
        type: _movementType,
        mode: _selectedMode,
        dateAction: DateTime.now(),
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentName,
      );
      
      await LocalDB.instance.saveJournalEntry(journalEntry);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ajustement de capital effectué avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'ajustement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  ShopModel _updateShopCapital(ShopModel shop, ModePaiement mode, double amount, bool isCredit) {
    final factor = isCredit ? 1.0 : -1.0;
    final deltaAmount = amount * factor;
    
    switch (mode) {
      case ModePaiement.cash:
        return shop.copyWith(
          capitalCash: shop.capitalCash + deltaAmount,
          capitalActuel: shop.capitalActuel + deltaAmount,
        );
      case ModePaiement.airtelMoney:
        return shop.copyWith(
          capitalAirtelMoney: shop.capitalAirtelMoney + deltaAmount,
          capitalActuel: shop.capitalActuel + deltaAmount,
        );
      case ModePaiement.mPesa:
        return shop.copyWith(
          capitalMPesa: shop.capitalMPesa + deltaAmount,
          capitalActuel: shop.capitalActuel + deltaAmount,
        );
      case ModePaiement.orangeMoney:
        return shop.copyWith(
          capitalOrangeMoney: shop.capitalOrangeMoney + deltaAmount,
          capitalActuel: shop.capitalActuel + deltaAmount,
        );
    }
    // If mode is not recognized, return the shop unchanged
    return shop;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Ajustement du Capital'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ajuster le capital du shop',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              
              // Type de mouvement
              DropdownButtonFormField<TypeMouvement>(
                value: _movementType,
                decoration: const InputDecoration(
                  labelText: 'Type d\'ajustement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: TypeMouvement.entree,
                    child: Text('Ajout au capital (Entrée)'),
                  ),
                  DropdownMenuItem(
                    value: TypeMouvement.sortie,
                    child: Text('Retrait du capital (Sortie)'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _movementType = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Montant
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  labelText: 'Montant *',
                  hintText: 'Ex: 5000.00',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le montant est requis';
                  }
                  final amount = double.tryParse(value);
                  if (amount == null || amount <= 0) {
                    return 'Le montant doit être un nombre positif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Mode de paiement
              DropdownButtonFormField<ModePaiement>(
                value: _selectedMode,
                decoration: const InputDecoration(
                  labelText: 'Mode de paiement',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: ModePaiement.cash,
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem(
                    value: ModePaiement.airtelMoney,
                    child: Text('Airtel Money'),
                  ),
                  DropdownMenuItem(
                    value: ModePaiement.mPesa,
                    child: Text('M-Pesa'),
                  ),
                  DropdownMenuItem(
                    value: ModePaiement.orangeMoney,
                    child: Text('Orange Money'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedMode = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Raison de l\'ajustement',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _handleSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Valider'),
        ),
      ],
    );
  }
}