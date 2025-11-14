import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import '../models/shop_model.dart';

class CreateAgentDialog extends StatefulWidget {
  const CreateAgentDialog({super.key});

  @override
  State<CreateAgentDialog> createState() => _CreateAgentDialogState();
}

class _CreateAgentDialogState extends State<CreateAgentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  ShopModel? _selectedShop;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Charger les shops au démarrage
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShopService>(context, listen: false).loadShops();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.person_add, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Nouvel Agent'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Nom d\'utilisateur *',
                      hintText: 'Ex: agent1',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    validator: (value) {
                      return agentService.validateAgentData(
                        username: value ?? '',
                        password: _passwordController.text,
                        shopId: _selectedShop?.id,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Mot de passe *',
                      hintText: 'Minimum 6 caractères',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      return agentService.validateAgentData(
                        username: _usernameController.text,
                        password: value ?? '',
                        shopId: _selectedShop?.id,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<ShopModel>(
                    value: _selectedShop,
                    decoration: InputDecoration(
                      labelText: 'Shop assigné *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.store),
                    ),
                    items: shopService.shops.map((shop) {
                      return DropdownMenuItem<ShopModel>(
                        value: shop,
                        child: Text('${shop.designation} - ${shop.localisation}'),
                      );
                    }).toList(),
                    onChanged: (shop) {
                      setState(() {
                        _selectedShop = shop;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Veuillez sélectionner un shop';
                      }
                      return null;
                    },
                  ),
                  
                  if (agentService.errorMessage != null) ...[
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
                              agentService.errorMessage!,
                              style: TextStyle(color: Colors.red[700]),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  
                  if (shopService.shops.isEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange[200]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Aucun shop disponible. Créez d\'abord un shop.',
                              style: TextStyle(color: Colors.orange),
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
          actions: [
            TextButton(
              onPressed: agentService.isLoading ? null : () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: (agentService.isLoading || shopService.shops.isEmpty) 
                  ? null 
                  : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: agentService.isLoading
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
    
    // Vérifier que le shop est sélectionné et a un ID valide
    if (_selectedShop == null || _selectedShop!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner un shop valide'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final agentService = Provider.of<AgentService>(context, listen: false);
    
    final success = await agentService.createAgent(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      shopId: _selectedShop!.id!,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agent créé avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
