import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/virtual_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/currency_service.dart';
import '../models/virtual_transaction_model.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../utils/auto_print_helper.dart';
import '../utils/currency_utils.dart';

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
  final _pourcentageController = TextEditingController();  // Saisir le pourcentage
  
  bool _isLoading = false;
  bool _isDisposed = false; // Track disposal state
  double _montantCashCalcule = 0.0;  // Calculé à partir du %
  double _commissionCalculee = 0.0;  // Calculée à partir du %

  @override
  void initState() {
    super.initState();
    // Par défaut, le pourcentage = 0
    _pourcentageController.text = '0';
    _calculateFromPercentage();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _clientNomController.dispose();
    _clientTelephoneController.dispose();
    _pourcentageController.dispose();
    super.dispose();
  }

  /// Calculer le montant cash et la commission à partir du pourcentage
  /// NOUVEAU: Pour CDF, convertir d'abord en USD puis appliquer les frais
  /// Pour USD, appliquer directement les frais
  void _calculateFromPercentage() {
    if (_isDisposed || !mounted) return;
    
    final pourcentage = double.tryParse(_pourcentageController.text) ?? 0.0;
    final montantVirtuel = widget.transaction.montantVirtuel;
    
    if (widget.transaction.devise == 'CDF') {
      // NOUVEAU: Pour CDF, convertir d'abord en USD, puis appliquer les frais
      final montantUsd = CurrencyService.instance.convertCdfToUsd(montantVirtuel);
      final commissionUsd = (montantUsd * pourcentage) / 100;
      final montantCashUsd = montantUsd - commissionUsd;
      
      setState(() {
        _commissionCalculee = commissionUsd; // Commission en USD
        _montantCashCalcule = montantCashUsd; // Cash en USD
      });
    } else {
      // Pour USD, calcul normal
      final commission = (montantVirtuel * pourcentage) / 100;
      final montantCash = montantVirtuel - commission;
      
      setState(() {
        _commissionCalculee = commission;
        _montantCashCalcule = montantCash;
      });
    }
  }
  
  /// Calculer le pourcentage des frais par rapport au montant virtuel
  double _calculatePercentageVirtuel() {
    if (widget.transaction.devise == 'CDF') {
      // Pour CDF, calculer le pourcentage par rapport au montant USD converti
      final montantUsd = CurrencyService.instance.convertCdfToUsd(widget.transaction.montantVirtuel);
      if (montantUsd == 0) return 0.0;
      return (_commissionCalculee / montantUsd) * 100;
    } else {
      // Pour USD, calcul normal
      if (widget.transaction.montantVirtuel == 0) return 0.0;
      return (_commissionCalculee / widget.transaction.montantVirtuel) * 100;
    }
  }
  
  /// Calculer le pourcentage des frais par rapport au montant cash
  double _calculatePercentageCash() {
    if (_montantCashCalcule == 0) return 0.0;
    return (_commissionCalculee / _montantCashCalcule) * 100;
  }

  Future<void> _submit() async {
    if (_isDisposed || !mounted) return;
    
    if (!_formKey.currentState!.validate()) return;

    final pourcentage = double.parse(_pourcentageController.text);
    final montantCash = _montantCashCalcule;
    final commission = _commissionCalculee;
    final percentVirtuel = pourcentage;
    final percentCash = montantCash > 0 ? (commission / montantCash) * 100 : 0.0;
    
    // Vérification: le pourcentage ne peut pas être négatif ou > 100
    if (pourcentage < 0 || pourcentage > 100) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Le pourcentage doit être entre 0 et 100'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
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
            Text('Montant Virtuel: ${CurrencyUtils.formatAmount(widget.transaction.montantVirtuel, widget.transaction.devise)}'),
            if (widget.transaction.devise == 'CDF') ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Conversion CDF → USD:',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 4),
                    Text('${widget.transaction.montantVirtuel.toStringAsFixed(0)} CDF → \$${CurrencyService.instance.convertCdfToUsd(widget.transaction.montantVirtuel).toStringAsFixed(2)} USD'),
                    Text('Taux: 1 USD = ${CurrencyService.instance.tauxCdfToUsd.toStringAsFixed(0)} CDF', 
                      style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            Text('Frais: \$${commission.toStringAsFixed(2)} USD (${percentVirtuel.toStringAsFixed(2)}% saisi)', 
              style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
            if (montantCash > 0)
              Text('  = ${percentCash.toStringAsFixed(2)}% du cash servi',
                style: const TextStyle(color: Colors.orange, fontSize: 12)),
            const Divider(),
            Text(
              'Cash à remettre: \$${montantCash.toStringAsFixed(2)} USD',
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

    if (confirm != true || _isDisposed || !mounted) return;

    if (!_isDisposed && mounted) {
      setState(() => _isLoading = true);
    }

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

      if (!_isDisposed && mounted) {
        if (success) {
          // Imprimer le bordereau de retrait
          await _printWithdrawalReceipt(
            transaction: widget.transaction,
            clientNom: _clientNomController.text.trim(),
            clientTelephone: _clientTelephoneController.text.trim(),
            commission: commission,
            montantCash: montantCash,
          );
          
          // IMPORTANT: Attendre un court délai pour que les données se propagent
          await Future.delayed(const Duration(milliseconds: 500));
          
          if (!_isDisposed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Client servi!\nFrais: \$${commission.toStringAsFixed(2)} USD (${_calculatePercentageVirtuel().toStringAsFixed(2)}%)\nCash remis: \$${montantCash.toStringAsFixed(2)} USD'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 4),
              ),
            );
            Navigator.pop(context, true);
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${VirtualTransactionService.instance.errorMessage ?? "Erreur"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [ServeClientDialog] Erreur: $e');
      
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (!_isDisposed && mounted) {
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
            padding: const EdgeInsets.all(15),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_add, color: Colors.green),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          'Servir Client',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  
                  // Informations transaction
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Transaction: ${widget.transaction.reference}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                            ),
                            // NOUVEAU: Affichage du taux de change
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.blue[600],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.currency_exchange, color: Colors.white, size: 14),
                                  const SizedBox(width: 4),
                                  Text(
                                    '1 USD = ${CurrencyService.instance.tauxCdfToUsd.toStringAsFixed(0)} CDF',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow('SIM', widget.transaction.simNumero),
                        _buildInfoRow('Montant Virtuel', CurrencyUtils.formatAmount(widget.transaction.montantVirtuel, widget.transaction.devise)),
                          if (widget.transaction.devise == 'CDF')
                          _buildInfoRow('Montant Converti', '\$${CurrencyService.instance.convertCdfToUsd(widget.transaction.montantVirtuel).toStringAsFixed(2)} USD'),
                        const Divider(height: 16),
                       Row(
                          children: [
                            const Text('Frais calculés:', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.orange)),
                            const Spacer(),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '\$${_commissionCalculee.toStringAsFixed(2)} USD',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                Text(
                                  '${_calculatePercentageVirtuel().toStringAsFixed(2)}% saisi',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.orange,
                                  ),
                                ),
                                if (_calculatePercentageCash() > 0)
                                  Text(
                                    '${_calculatePercentageCash().toStringAsFixed(2)}% du cash',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.orange,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Informations Client',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  
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
                  const SizedBox(height: 15),
                  
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
                  const SizedBox(height: 15),
                  
                  // Pourcentage de frais (à saisir par l'agent)
                  TextFormField(
                    controller: _pourcentageController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le pourcentage est requis';
                      }
                      final pourcentage = double.tryParse(value);
                      if (pourcentage == null || pourcentage < 0) {
                        return 'Pourcentage invalide';
                      }
                      if (pourcentage > 100) {
                        return 'Le pourcentage ne peut pas dépasser 100%';
                      }
                      return null;
                    },
                    onChanged: (value) => _calculateFromPercentage(),
                  ),
                  const SizedBox(height: 12),
                  
                  // Avertissement
                  Container(
                    padding: const EdgeInsets.all(5),
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
                            'Assurez-vous que le client a montré sa capture.',
                            style: TextStyle(color: Colors.grey[800], fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  
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
                              : const Text('Servir'),
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
        notes: 'Flot (${transaction.simNumero})\nTél: $clientTelephone',
        observation: 'SIM: ${transaction.simNumero}',
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
