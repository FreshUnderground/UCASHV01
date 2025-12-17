import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/shop_service.dart';

// Dialog pour initialiser le solde d'un client sans impacter le cash disponible
class InitializeBalanceDialog extends StatefulWidget {
  final ClientModel client;

  const InitializeBalanceDialog({super.key, required this.client});

  @override
  State<InitializeBalanceDialog> createState() => _InitializeBalanceDialogState();
}

class _InitializeBalanceDialogState extends State<InitializeBalanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _observationController = TextEditingController();
  ModePaiement _modePaiement = ModePaiement.cash;
  ShopModel? _selectedShop;
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Initialiser Solde - ${widget.client.nom}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Avertissement
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info, color: Colors.blue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Cette opération créera un solde initial SANS impacter votre cash disponible. '
                                'Elle sera marquée comme administrative.\n\n'
                                '• Montant POSITIF = Nous leur devons (crédit)\n'
                                '• Montant NÉGATIF = Ils nous doivent (dette)',
                                style: TextStyle(
                                  color: Colors.blue.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      
                      // Montant
                      TextFormField(
                        controller: _montantController,
                        decoration: const InputDecoration(
                          labelText: 'Montant initial *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'USD',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le montant est requis';
                          }
                          final montant = double.tryParse(value);
                          if (montant == null || montant == 0) {
                            return 'Veuillez saisir un montant valide (≠ 0)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Sélection du shop
                      Consumer<ShopService>(
                        builder: (context, shopService, child) {
                          return DropdownButtonFormField<ShopModel>(
                            value: _selectedShop,
                            decoration: const InputDecoration(
                              labelText: 'Shop *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.store),
                            ),
                            items: shopService.shops.map((shop) {
                              return DropdownMenuItem(
                                value: shop,
                                child: Text('${shop.designation} (#${shop.id})'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedShop = value;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Veuillez sélectionner un shop';
                              }
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Mode de paiement
                      DropdownButtonFormField<ModePaiement>(
                        value: _modePaiement,
                        decoration: const InputDecoration(
                          labelText: 'Mode de paiement',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: ModePaiement.values.map((mode) {
                          return DropdownMenuItem(
                            value: mode,
                            child: Text(_getModePaiementLabel(mode)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _modePaiement = value;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Observation
                      TextFormField(
                        controller: _observationController,
                        decoration: const InputDecoration(
                          labelText: 'Observation (optionnel)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.note),
                          hintText: 'Solde d\'ouverture de compte',
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Initialiser'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModePaiementLabel(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final clientService = Provider.of<ClientService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser?.id == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (_selectedShop == null) {
        throw Exception('Veuillez sélectionner un shop');
      }

      final montant = double.parse(_montantController.text.trim());
      final observation = _observationController.text.trim().isEmpty 
          ? 'Solde d\'ouverture de compte'
          : _observationController.text.trim();

      final success = await clientService.initialiserSoldeClient(
        clientId: widget.client.id!,
        montantInitial: montant,
        shopId: _selectedShop?.id ?? 0,
        agentId: currentUser!.id!,
        observation: observation,
        modePaiement: _modePaiement,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Solde initialisé avec succès !',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '👤 ${widget.client.nom}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '💰 Montant: ${montant.toStringAsFixed(2)} USD',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  '⚠️ Opération administrative - sans impact sur le cash disponible',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${clientService.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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
}
