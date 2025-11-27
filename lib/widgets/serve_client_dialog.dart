import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/virtual_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../models/virtual_transaction_model.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../utils/auto_print_helper.dart';

/// Dialog pour servir un client (valider une transaction virtuelle)
class ServeClientDialog extends StatefulWidget {
  final VirtualTransactionModel transaction;

  const ServeClientDialog({super.key, required this.transaction});

  @override
  State<ServeClientDialog> createState() => _ServeClientDialogState();
}

class _ServeClientDialogState extends State<ServeClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _clientNomController = TextEditingController();
  final _clientTelephoneController = TextEditingController();
  final _commissionPercentController = TextEditingController();
  
  bool _isLoading = false;
  double _montantCashCalcule = 0.0;
  double _commissionCalculee = 0.0;

  @override
  void initState() {
    super.initState();
    // Calculer le % initial à partir des frais existants
    if (widget.transaction.montantVirtuel > 0) {
      final percentInitial = (widget.transaction.frais / widget.transaction.montantVirtuel) * 100;
      _commissionPercentController.text = percentInitial.toStringAsFixed(2);
    } else {
      _commissionPercentController.text = '0';
    }
    _calculateMontantCash();
  }

  @override
  void dispose() {
    _clientNomController.dispose();
    _clientTelephoneController.dispose();
    _commissionPercentController.dispose();
    super.dispose();
  }

  void _calculateMontantCash() {
    final percent = double.tryParse(_commissionPercentController.text) ?? 0.0;
    final commission = (widget.transaction.montantVirtuel * percent) / 100;
    setState(() {
      _commissionCalculee = commission;
      _montantCashCalcule = widget.transaction.montantVirtuel - commission;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final percent = double.parse(_commissionPercentController.text);
    final commission = (widget.transaction.montantVirtuel * percent) / 100;
    final montantCash = widget.transaction.montantVirtuel - commission;

    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous confirmer cette opération?'),
            const SizedBox(height: 16),
            Text('Client: ${_clientNomController.text}', style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Téléphone: ${_clientTelephoneController.text}'),
            const SizedBox(height: 8),
            Text('Montant Virtuel: \$${widget.transaction.montantVirtuel.toStringAsFixed(2)}'),
            Text('Commission: ${percent.toStringAsFixed(2)}% = \$${commission.toStringAsFixed(2)}', 
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
            const Divider(),
            Text(
              'Cash à remettre: \$${montantCash.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final success = await VirtualTransactionService.instance.validateTransaction(
        transaction: widget.transaction,
        clientNom: _clientNomController.text.trim(),
        clientTelephone: _clientTelephoneController.text.trim(),
        commission: commission,
        modifiedBy: currentUser.username,
      );

      if (mounted) {
        if (success) {
          // Imprimer le bordereau de retrait
          await _printWithdrawalReceipt(
            transaction: widget.transaction,
            clientNom: _clientNomController.text.trim(),
            clientTelephone: _clientTelephoneController.text.trim(),
            commission: commission,
            montantCash: montantCash,
          );
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Client servi!\nCommission: ${percent.toStringAsFixed(2)}% (\$${commission.toStringAsFixed(2)})\nCash remis: \$${montantCash.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${VirtualTransactionService.instance.errorMessage ?? "Erreur"}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
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
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add, color: Colors.green),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Servir Client',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Informations transaction
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Transaction: ${widget.transaction.reference}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('SIM', widget.transaction.simNumero),
                        _buildInfoRow('Virtuel', '\$${widget.transaction.montantVirtuel.toStringAsFixed(2)}'),
                        const Divider(height: 16),
                        Row(
                          children: [
                            const Text('Cash à servir:', style: TextStyle(fontWeight: FontWeight.w600)),
                            const Spacer(),
                            Text(
                              '\$${_montantCashCalcule.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Informations Client',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  
                  // Nom client
                  TextFormField(
                    controller: _clientNomController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du Client *',
                      hintText: 'Ex: Jean Dupont',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le nom du client est requis';
                      }
                      return null;
                    },
                    autofocus: true,
                  ),
                  const SizedBox(height: 16),
                  
                  // Téléphone client
                  TextFormField(
                    controller: _clientTelephoneController,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone *',
                      hintText: 'Ex: 0812345678',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.phone),
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le téléphone est requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Commission en pourcentage (modifiable)
                  TextFormField(
                    controller: _commissionPercentController,
                    decoration: InputDecoration(
                      labelText: 'Commission (%) *',
                      hintText: '0.00',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.percent),
                      suffixText: '%',
                      helperText: 'Commission = ${_commissionCalculee.toStringAsFixed(2)} USD',
                      helperStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La commission est requise';
                      }
                      final percent = double.tryParse(value);
                      if (percent == null || percent < 0) {
                        return 'Pourcentage invalide';
                      }
                      if (percent > 100) {
                        return 'Maximum 100%';
                      }
                      return null;
                    },
                    onChanged: (value) => _calculateMontantCash(),
                  ),
                  const SizedBox(height: 24),
                  
                  // Avertissement
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.warning, color: Colors.orange),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Assurez-vous que le client a bien montré sa capture avant de valider.',
                            style: TextStyle(color: Colors.grey[800], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Servir Client'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Imprimer le bordereau de retrait pour transaction virtuelle
  Future<void> _printWithdrawalReceipt({
    required VirtualTransactionModel transaction,
    required String clientNom,
    required String clientTelephone,
    required double commission,
    required double montantCash,
  }) async {
    try {
      debugPrint('🖨️ Impression bordereau retrait virtuel...');
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        debugPrint('❌ Utilisateur non connecté');
        return;
      }
      
      // Récupérer le shop
      final shop = shopService.shops.firstWhere(
        (s) => s.id == transaction.shopId,
        orElse: () => ShopModel(
          designation: transaction.shopDesignation ?? 'Shop',
          localisation: '',
        ),
      );
      
      // Créer un agent model
      final agent = AgentModel(
        id: transaction.agentId,
        username: transaction.agentUsername ?? currentUser.username,
        password: '',
        nom: currentUser.username,
        shopId: transaction.shopId,
        shopDesignation: transaction.shopDesignation,
      );
      
      // Créer un OperationModel pour le bordereau
      final receiptOperation = OperationModel(
        type: OperationType.retrait,
        montantBrut: transaction.montantVirtuel,
        montantNet: montantCash,
        commission: commission,
        devise: 'USD',
        clientNom: clientNom,
        shopSourceId: transaction.shopId,
        shopSourceDesignation: transaction.shopDesignation,
        agentId: transaction.agentId,
        agentUsername: transaction.agentUsername,
        codeOps: transaction.reference, // Utiliser la référence comme code
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.validee,
        notes: 'Retrait Virtuel (${transaction.simNumero})\nTél: $clientTelephone',
        observation: 'Mobile Money - SIM: ${transaction.simNumero}',
        dateOp: DateTime.now(),
        createdAt: transaction.dateEnregistrement,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );
      
      // Utiliser AutoPrintHelper pour imprimer
      await AutoPrintHelper.autoPrintWithDialog(
        context: context,
        operation: receiptOperation,
        shop: shop,
        agent: agent,
        clientName: clientNom,
        isWithdrawalReceipt: true,
      );
      
      debugPrint('✅ Bordereau retrait virtuel imprimé');
    } catch (e) {
      debugPrint('❌ Erreur impression bordereau: $e');
      // Ne pas bloquer si l'impression échoue
    }
  }
}
