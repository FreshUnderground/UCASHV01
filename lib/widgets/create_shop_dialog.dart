import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shop_service.dart';

class CreateShopDialog extends StatefulWidget {
  const CreateShopDialog({super.key});

  @override
  State<CreateShopDialog> createState() => _CreateShopDialogState();
}

class _CreateShopDialogState extends State<CreateShopDialog> {
  final _formKey = GlobalKey<FormState>();
  final _designationController = TextEditingController();
  final _localisationController = TextEditingController();
  final _capitalCashController = TextEditingController();
  bool _isPrincipal = false; // Shop principal (gère les flots)
  bool _isTransferShop =
      false; // Shop de transfert/service (sert les transferts)
  // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
  // final _capitalAirtelController = TextEditingController();
  // final _capitalMPesaController = TextEditingController();
  // final _capitalOrangeController = TextEditingController();

  @override
  void dispose() {
    _designationController.dispose();
    _localisationController.dispose();
    _capitalCashController.dispose();
    // MASQUÉ: Controllers pour mobile money
    // _capitalAirtelController.dispose();
    // _capitalMPesaController.dispose();
    // _capitalOrangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.store, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Nouveau Shop'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _designationController,
                      decoration: InputDecoration(
                        labelText: 'Désignation *',
                        hintText: 'Ex: UCASH Central, KAMPALA, Shop Goma',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.business),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La désignation est requise';
                        }
                        if (value.length < 3) {
                          return 'La désignation doit contenir au moins 3 caractères';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _localisationController,
                      decoration: InputDecoration(
                        labelText: 'Localisation *',
                        hintText: 'Ex: Kinshasa, Gombe',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'La localisation est requise';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Case à cocher Shop Principal
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: CheckboxListTile(
                        title: const Row(
                          children: [
                            Icon(Icons.account_balance,
                                size: 20, color: Color(0xFF1976D2)),
                            SizedBox(width: 8),
                            Text(
                              'Shop Principal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          'Cochez si ce shop est le siège/central qui gère tous les flots (ex: Durba)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        value: _isPrincipal,
                        onChanged: (bool? value) {
                          setState(() {
                            _isPrincipal = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF1976D2),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Case à cocher Shop de Transfert/Service
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: CheckboxListTile(
                        title: const Row(
                          children: [
                            Icon(Icons.swap_horiz,
                                size: 20, color: Color(0xFF388E3C)),
                            SizedBox(width: 8),
                            Text(
                              'Shop de Transfert (Service)',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        subtitle: const Text(
                          'Cochez si ce shop sert les transferts par défaut (ex: Kampala)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        value: _isTransferShop,
                        onChanged: (bool? value) {
                          setState(() {
                            _isTransferShop = value ?? false;
                          });
                        },
                        activeColor: const Color(0xFF388E3C),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section des capitaux par type
                    const Text(
                      'Capitaux par Type de Caisse (USD)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Capital Cash
                    TextFormField(
                      controller: _capitalCashController,
                      decoration: InputDecoration(
                        labelText: 'Capital Cash *',
                        hintText: 'Ex: 20000',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon:
                            const Icon(Icons.money, color: Color(0xFF388E3C)),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Le capital Cash est requis';
                        }
                        final capital = double.tryParse(value);
                        if (capital == null || capital < 0) {
                          return 'Le capital doit être un nombre positif ou zéro';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
                    // // Capital Airtel Money
                    // TextFormField(
                    //   controller: _capitalAirtelController,
                    //   decoration: InputDecoration(
                    //     labelText: 'Capital Airtel Money *',
                    //     hintText: 'Ex: 12500',
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     prefixIcon: const Icon(Icons.phone_android, color: Color(0xFFE65100)),
                    //   ),
                    //   keyboardType: TextInputType.number,
                    //   validator: (value) {
                    //     if (value == null || value.trim().isEmpty) {
                    //       return 'Le capital Airtel Money est requis';
                    //     }
                    //     final capital = double.tryParse(value);
                    //     if (capital == null || capital < 0) {
                    //       return 'Le capital doit être un nombre positif ou zéro';
                    //     }
                    //     return null;
                    //   },
                    // ),
                    // const SizedBox(height: 12),
                    //
                    // // Capital M-Pesa
                    // TextFormField(
                    //   controller: _capitalMPesaController,
                    //   decoration: InputDecoration(
                    //     labelText: 'Capital M-Pesa *',
                    //     hintText: 'Ex: 10000',
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     prefixIcon: const Icon(Icons.account_balance_wallet, color: Color(0xFF1976D2)),
                    //   ),
                    //   keyboardType: TextInputType.number,
                    //   validator: (value) {
                    //     if (value == null || value.trim().isEmpty) {
                    //       return 'Le capital MPESA/VODACASH est requis';
                    //     }
                    //     final capital = double.tryParse(value);
                    //     if (capital == null || capital < 0) {
                    //       return 'Le capital doit être un nombre positif ou zéro';
                    //     }
                    //     return null;
                    //   },
                    // ),
                    // const SizedBox(height: 12),
                    //
                    // // Capital Orange Money
                    // TextFormField(
                    //   controller: _capitalOrangeController,
                    //   decoration: InputDecoration(
                    //     labelText: 'Capital Orange Money *',
                    //     hintText: 'Ex: 7500',
                    //     border: OutlineInputBorder(
                    //       borderRadius: BorderRadius.circular(12),
                    //     ),
                    //     prefixIcon: const Icon(Icons.payment, color: Color(0xFFFF9800)),
                    //   ),
                    //   keyboardType: TextInputType.number,
                    //   validator: (value) {
                    //     if (value == null || value.trim().isEmpty) {
                    //       return 'Le capital Orange Money est requis';
                    //     }
                    //     final capital = double.tryParse(value);
                    //     if (capital == null || capital < 0) {
                    //       return 'Le capital doit être un nombre positif ou zéro';
                    //     }
                    //     return null;
                    //   },
                    // ),

                    if (shopService.errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error, color: Colors.red[700], size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                shopService.errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: shopService.isLoading
                  ? null
                  : () {
                      Navigator.of(context).pop();
                    },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: shopService.isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: shopService.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final shopService = Provider.of<ShopService>(context, listen: false);

    final capitalCash = double.parse(_capitalCashController.text.trim());
    // MASQUÉ: Mobile money capitaux sont fixés à 0
    final capitalAirtel =
        0.0; // double.parse(_capitalAirtelController.text.trim());
    final capitalMPesa =
        0.0; // double.parse(_capitalMPesaController.text.trim());
    final capitalOrange =
        0.0; // double.parse(_capitalOrangeController.text.trim());
    final totalCapital =
        capitalCash + capitalAirtel + capitalMPesa + capitalOrange;

    final success = await shopService.createShop(
      designation: _designationController.text.trim(),
      localisation: _localisationController.text.trim(),
      isPrincipal: _isPrincipal,
      isTransferShop: _isTransferShop,
      capitalInitial: totalCapital,
      capitalCash: capitalCash,
      capitalAirtelMoney: capitalAirtel,
      capitalMPesa: capitalMPesa,
      capitalOrangeMoney: capitalOrange,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Shop créé avec succès! '
              '${_isPrincipal ? "🏦 Shop Principal " : ""}'
              '${_isTransferShop ? "🔄 Shop de Transfert " : ""}'
              'Capital total: ${totalCapital.toStringAsFixed(0)} USD'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }
}
