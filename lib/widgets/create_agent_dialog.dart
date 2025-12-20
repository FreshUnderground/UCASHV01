import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
  final _matriculeController = TextEditingController();
  ShopModel? _selectedShop;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    // Charger les shops au démarrage et générer un matricule automatiquement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<ShopService>(context, listen: false).loadShops();
      _generateMatricule();
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _matriculeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add, color: Color(0xFFDC2626)),
              const SizedBox(width: 8),
              Text(l10n.newAgent),
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
                      labelText: '${l10n.username} *',
                      hintText: l10n.exampleUsername,
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
                      labelText: '${l10n.password} *',
                      hintText: l10n.passwordMinLength,
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
                  
                  // Champ Matricule avec génération automatique
                  TextFormField(
                    controller: _matriculeController,
                    decoration: InputDecoration(
                      labelText: 'Matricule',
                      hintText: 'Généré automatiquement ou saisissez manuellement',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.badge),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.refresh),
                        tooltip: 'Générer un nouveau matricule',
                        onPressed: () {
                          _generateMatricule();
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le matricule est requis';
                      }
                      if (value.trim().length < 3) {
                        return 'Le matricule doit contenir au moins 3 caractères';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  DropdownButtonFormField<ShopModel>(
                    value: _selectedShop,
                    decoration: InputDecoration(
                      labelText: '${l10n.assignedShop} *',
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
                        return l10n.shopRequired;
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
                          Expanded(
                            child: Text(
                              l10n.noShopsAvailable,
                              style: const TextStyle(color: Colors.orange),
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
              child: Text(l10n.cancel),
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
                  : Text(l10n.save),
            ),
          ],
        );
      },
    );
  }

  // Générer un matricule automatique
  void _generateMatricule() {
    final agentService = Provider.of<AgentService>(context, listen: false);
    final matricule = agentService.generateMatricule(shopId: _selectedShop?.id);
    setState(() {
      _matriculeController.text = matricule;
    });
  }

  Future<void> _handleSubmit() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_formKey.currentState!.validate()) return;
    
    // Vérifier que le shop est sélectionné et a un ID valide
    if (_selectedShop == null || _selectedShop!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shopRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final agentService = Provider.of<AgentService>(context, listen: false);
    
    final success = await agentService.createAgent(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
      matricule: _matriculeController.text.trim(),
      shopId: _selectedShop!.id!,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.agentCreatedSuccessfully),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
