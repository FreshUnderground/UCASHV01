import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sim_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';

import '../models/shop_model.dart';

/// Dialog pour créer une nouvelle carte SIM
class CreateSimDialog extends StatefulWidget {
  const CreateSimDialog({super.key});

  @override
  State<CreateSimDialog> createState() => _CreateSimDialogState();
}

class _CreateSimDialogState extends State<CreateSimDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _numeroController = TextEditingController();
  final _soldeInitialController = TextEditingController(text: '0');
  
  // Selected values
  String _selectedOperateur = 'Airtel';
  ShopModel? _selectedShop;
  
  bool _isLoading = false;
  bool _isLoadingShops = true;

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      await shopService.loadShops();
      debugPrint('✅ Shops chargés: ${shopService.shops.length} shops trouvés');
      if (shopService.shops.isNotEmpty) {
        debugPrint('   Shops: ${shopService.shops.map((s) => s.designation).join(", ")}');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement shops: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingShops = false);
      }
    }
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _soldeInitialController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.sim_card, color: Color(0xFFDC2626), size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nouvelle Carte SIM',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Créer une nouvelle SIM Mobile Money',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // Form fields
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Numéro SIM
                      _buildSectionTitle('Numéro de la SIM'),
                      TextFormField(
                        controller: _numeroController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Numéro SIM',
                          hintText: '4-20 caractères, chiffres ou spéciaux',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le numéro de SIM';
                          }
                          if (value.length < 4) {
                            return 'Numéro trop court (minimum 4 caractères)';
                          }
                          if (value.length > 20) {
                            return 'Numéro trop long (maximum 20 caractères)';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Opérateur
                      _buildSectionTitle('Opérateur Mobile Money'),
                      DropdownButtonFormField<String>(
                        value: _selectedOperateur,
                        decoration: const InputDecoration(
                          labelText: 'Opérateur',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.cell_tower),
                        ),
                        items: ['Airtel', 'Vodacom', 'Orange', 'Africell']
                            .map((op) => DropdownMenuItem(value: op, child: Text(op)))
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedOperateur = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Shop
                      _buildSectionTitle('Affectation Shop'),
                      if (_isLoadingShops)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Chargement des shops...'),
                              ],
                            ),
                          ),
                        )
                      else
                        Consumer<ShopService>(
                          builder: (context, shopService, child) {
                            final shops = shopService.shops;
                            
                            if (shops.isEmpty) {
                              return Card(
                                color: Colors.orange[50],
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.warning, color: Colors.orange[700]),
                                          const SizedBox(width: 12),
                                          const Expanded(
                                            child: Text(
                                              'Aucun shop trouvé',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Veuillez créer un shop dans "SHOP" avant de créer une SIM.',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: () {
                                            setState(() {
                                              _isLoadingShops = true;
                                            });
                                            _loadShops();
                                          },
                                          icon: const Icon(Icons.refresh, size: 16),
                                          label: const Text('Recharger les shops'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange[700],
                                            foregroundColor: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            
                            return DropdownButtonFormField<ShopModel>(
                              value: _selectedShop,
                              decoration: const InputDecoration(
                                labelText: 'Shop',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.store),
                              ),
                              items: shops.map((shop) {
                                return DropdownMenuItem(
                                  value: shop,
                                  child: Text(shop.designation),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedShop = value;
                                });
                              },
                              validator: (value) {
                                if (value == null) return 'Veuillez sélectionner un shop';
                                return null;
                              },
                            );
                          },
                        ),
                      const SizedBox(height: 16),
                      
                      // Solde initial (optionnel)
                      _buildSectionTitle('Solde Initial (Optionnel)'),
                      TextFormField(
                        controller: _soldeInitialController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Solde Initial',
                          hintText: '0.00',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'USD',
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            final montant = double.tryParse(value);
                            if (montant == null || montant < 0) {
                              return 'Montant invalide';
                            }
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 32),
              
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _creerSim,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Création...' : 'Créer la SIM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Future<void> _creerSim() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final soldeInitial = double.tryParse(_soldeInitialController.text) ?? 0.0;
      
      final sim = await SimService.instance.createSim(
        numero: _numeroController.text.trim(),
        operateur: _selectedOperateur,
        shopId: _selectedShop!.id!,
        shopDesignation: _selectedShop!.designation,
        soldeInitial: soldeInitial,
        creePar: currentUser.username,
      );
      
      if (sim != null && mounted) {
        Navigator.pop(context, sim);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ SIM créée avec succès: ${sim.numero}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
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
