import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';

class EditAgentDialog extends StatefulWidget {
  final AgentModel agent;

  const EditAgentDialog({
    super.key,
    required this.agent,
  });

  @override
  State<EditAgentDialog> createState() => _EditAgentDialogState();
}

class _EditAgentDialogState extends State<EditAgentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _matriculeController = TextEditingController();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  
  ShopModel? _selectedShop;
  bool _isActive = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeFields();
  }

  void _initializeFields() {
    final l10n = AppLocalizations.of(context)!;
    _usernameController.text = widget.agent.username;
    _passwordController.text = widget.agent.password;
    _matriculeController.text = widget.agent.matricule ?? '';
    _nomController.text = widget.agent.nom ?? '';
    _telephoneController.text = widget.agent.telephone ?? '';
    _isActive = widget.agent.isActive;
    
    // Trouver le shop sélectionné
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final shopService = Provider.of<ShopService>(context, listen: false);
      _selectedShop = shopService.shops.firstWhere(
        (shop) => shop.id == widget.agent.shopId,
        orElse: () => shopService.shops.isNotEmpty ? shopService.shops.first : ShopModel(
          id: 0,
          designation: l10n.noShopAssigned,
          localisation: '',
          capitalInitial: 0,
        ),
      );
      setState(() {});
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _matriculeController.dispose();
    _nomController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.edit, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l10n.editAgent,
                      style: TextStyle(
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
                      // Username
                      TextFormField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          labelText: '${l10n.username} *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.usernameRequired;
                          }
                          if (value.length < 3) {
                            return l10n.usernameMinLength;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Password
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: '${l10n.password} *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock),
                        ),
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return l10n.passwordRequired;
                          }
                          if (value.length < 6) {
                            return l10n.passwordMinLength;
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Matricule
                      TextFormField(
                        controller: _matriculeController,
                        decoration: InputDecoration(
                          labelText: 'Matricule',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
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
                      
                      // Shop Selection
                      Consumer<ShopService>(
                        builder: (context, shopService, child) {
                          if (shopService.shops.isEmpty) {
                            return Card(
                              color: Colors.orange,
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Text(
                                      l10n.noShopsAvailable,
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          return DropdownButtonFormField<ShopModel>(
                            value: _selectedShop,
                            decoration: InputDecoration(
                              labelText: '${l10n.assignedShop} *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.store),
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
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Nom complet (optionnel)
                      TextFormField(
                        controller: _nomController,
                        decoration: InputDecoration(
                          labelText: l10n.fullNameOptional,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.badge),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // Téléphone (optionnel)
                      TextFormField(
                        controller: _telephoneController,
                        decoration: InputDecoration(
                          labelText: l10n.phoneOptional,
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      
                      // Statut actif/inactif
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Icon(
                                _isActive ? Icons.check_circle : Icons.cancel,
                                color: _isActive ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.status,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[800],
                                      ),
                                    ),
                                    Text(
                                      _isActive ? l10n.active : l10n.inactive,
                                      style: TextStyle(
                                        color: _isActive ? Colors.green : Colors.red,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                                activeColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
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
                    child: Text(l10n.cancel),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
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
                        : Text(l10n.edit),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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
    
    if (_selectedShop == null || _selectedShop!.id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.shopRequired),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final agentService = Provider.of<AgentService>(context, listen: false);
      
      // Créer l'agent modifié
      final updatedAgent = widget.agent.copyWith(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
        matricule: _matriculeController.text.trim(),
        shopId: _selectedShop!.id!,
        nom: _nomController.text.trim().isEmpty ? null : _nomController.text.trim(),
        telephone: _telephoneController.text.trim().isEmpty ? null : _telephoneController.text.trim(),
        isActive: _isActive,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'admin',
      );

      final success = await agentService.updateAgent(updatedAgent);

      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.agentUpdatedSuccessfully),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: ${agentService.errorMessage ?? l10n.errorUpdatingAgent}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.error}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
