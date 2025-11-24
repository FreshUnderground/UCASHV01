import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';
import '../services/shop_service.dart';
import '../models/commission_model.dart';
import '../models/shop_model.dart';

class ModernCommissionDialog extends StatefulWidget {
  final CommissionModel? commission; // null = créer, non-null = modifier
  
  const ModernCommissionDialog({super.key, this.commission});

  @override
  State<ModernCommissionDialog> createState() => _ModernCommissionDialogState();
}

class _ModernCommissionDialogState extends State<ModernCommissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _tauxController = TextEditingController();
  
  String _selectedType = 'SORTANT';
  String _routeType = 'GENERAL'; // GENERAL, SHOP_SPECIFIC, SHOP_TO_SHOP
  int? _selectedShopId;
  int? _selectedShopSourceId;
  int? _selectedShopDestinationId;

  final List<Map<String, dynamic>> _types = [
    {
      'value': 'SORTANT',
      'label': 'Sortant (depuis RDC)',
      'description': 'Transferts depuis la RDC vers l\'étranger',
      'icon': Icons.arrow_upward,
      'color': Colors.orange,
    },
    {
      'value': 'ENTRANT',
      'label': 'Entrant (vers RDC)',
      'description': 'Transferts depuis l\'étranger vers la RDC (GRATUIT)',
      'icon': Icons.arrow_downward,
      'color': Colors.green,
    },
  ];

  final List<Map<String, String>> _routeTypes = [
    {'value': 'GENERAL', 'label': 'Générale', 'description': 'S\'applique à tous les shops'},
    {'value': 'SHOP_SPECIFIC', 'label': 'Shop Spécifique', 'description': 'S\'applique à un shop particulier'},
    {'value': 'SHOP_TO_SHOP', 'label': 'Route Shop à Shop', 'description': 'Entre deux shops spécifiques'},
  ];

  @override
  void initState() {
    super.initState();
    if (widget.commission != null) {
      // Mode édition
      _selectedType = widget.commission!.type;
      _descriptionController.text = widget.commission!.description;
      _tauxController.text = widget.commission!.taux.toString();
      
      if (widget.commission!.shopSourceId != null && widget.commission!.shopDestinationId != null) {
        _routeType = 'SHOP_TO_SHOP';
        _selectedShopSourceId = widget.commission!.shopSourceId;
        _selectedShopDestinationId = widget.commission!.shopDestinationId;
      } else if (widget.commission!.shopId != null) {
        _routeType = 'SHOP_SPECIFIC';
        _selectedShopId = widget.commission!.shopId;
      } else {
        _routeType = 'GENERAL';
      }
    } else {
      // Mode création - valeurs par défaut
      _tauxController.text = '0';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _tauxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Dialog(
      insetPadding: isMobile 
          ? const EdgeInsets.all(16) 
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      child: Container(
        width: isMobile ? double.infinity : 600,
        constraints: BoxConstraints(
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isMobile),
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : 24),
                child: _buildForm(isMobile),
              ),
            ),
            _buildActions(isMobile),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [const Color(0xFFDC2626), const Color(0xFFEF4444)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(4),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.percent,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.commission == null ? 'Nouvelle Commission' : 'Modifier Commission',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (!isMobile)
                  const Text(
                    'Configurez les paramètres de commission',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildForm(bool isMobile) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Type de commission (SORTANT/ENTRANT)
          _buildSectionTitle('Type de Commission', Icons.category),
          const SizedBox(height: 12),
          _buildTypeSelector(isMobile),
          const SizedBox(height: 24),

          // Type de route (GENERAL/SHOP_SPECIFIC/SHOP_TO_SHOP)
          _buildSectionTitle('Portée de la Commission', Icons.route),
          const SizedBox(height: 12),
          _buildRouteTypeSelector(isMobile),
          const SizedBox(height: 24),

          // Sélection des shops selon le type de route
          if (_routeType == 'SHOP_SPECIFIC') ...[
            _buildSectionTitle('Shop Concerné', Icons.store),
            const SizedBox(height: 12),
            _buildShopSelector(isMobile),
            const SizedBox(height: 24),
          ],

          if (_routeType == 'SHOP_TO_SHOP') ...[
            _buildSectionTitle('Route Shop à Shop', Icons.alt_route),
            const SizedBox(height: 12),
            _buildShopSourceDestinationSelector(isMobile),
            const SizedBox(height: 24),
          ],

          // Description
          _buildSectionTitle('Description', Icons.description),
          const SizedBox(height: 12),
          TextFormField(
            controller: _descriptionController,
            decoration: InputDecoration(
              hintText: 'Ex: Commission pour transferts vers l\'Europe',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Colors.grey[50],
              prefixIcon: const Icon(Icons.text_fields),
            ),
            maxLines: 2,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'La description est requise';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),

          // Taux de commission
          _buildSectionTitle('Taux de Commission', Icons.attach_money),
          const SizedBox(height: 12),
          TextFormField(
            controller: _tauxController,
            enabled: _selectedType != 'ENTRANT',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: _selectedType == 'ENTRANT' ? 'GRATUIT (0%)' : 'Ex: 2.5',
              suffix: const Text('%'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: _selectedType == 'ENTRANT' ? Colors.green[50] : Colors.grey[50],
              prefixIcon: Icon(
                Icons.percent,
                color: _selectedType == 'ENTRANT' ? Colors.green : null,
              ),
            ),
            validator: (value) {
              if (_selectedType == 'ENTRANT') return null; // ENTRANT est toujours gratuit
              
              if (value == null || value.trim().isEmpty) {
                return 'Le taux est requis';
              }
              final taux = double.tryParse(value.trim());
              if (taux == null || taux < 0) {
                return 'Le taux doit être un nombre positif';
              }
              return null;
            },
          ),
          if (_selectedType == 'ENTRANT')
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Les transferts ENTRANTS sont toujours GRATUITS (0% de commission)',
                      style: TextStyle(fontSize: 12, color: Colors.green[700]),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: const Color(0xFFDC2626)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFFDC2626),
          ),
        ),
      ],
    );
  }

  Widget _buildTypeSelector(bool isMobile) {
    return Column(
      children: _types.map((type) {
        final isSelected = _selectedType == type['value'];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? type['color'] as Color : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedType = type['value'] as String;
                if (_selectedType == 'ENTRANT') {
                  _tauxController.text = '0';
                }
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (type['color'] as Color).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      type['icon'] as IconData,
                      color: type['color'] as Color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected ? type['color'] as Color : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          type['description'] as String,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, color: type['color'] as Color, size: 24),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRouteTypeSelector(bool isMobile) {
    return Column(
      children: _routeTypes.map((routeType) {
        final isSelected = _routeType == routeType['value'];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: isSelected ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isSelected ? const Color(0xFFDC2626) : Colors.grey[300]!,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: RadioListTile<String>(
            value: routeType['value']!,
            groupValue: _routeType,
            onChanged: (value) {
              setState(() {
                _routeType = value!;
                // Réinitialiser les sélections
                _selectedShopId = null;
                _selectedShopSourceId = null;
                _selectedShopDestinationId = null;
              });
            },
            title: Text(
              routeType['label']!,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? const Color(0xFFDC2626) : Colors.black87,
              ),
            ),
            subtitle: Text(
              routeType['description']!,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            activeColor: const Color(0xFFDC2626),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildShopSelector(bool isMobile) {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        final shops = shopService.shops;
        
        if (shops.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucun shop disponible',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return DropdownButtonFormField<int>(
          value: _selectedShopId,
          decoration: InputDecoration(
            labelText: 'Sélectionner le shop',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            prefixIcon: const Icon(Icons.store),
          ),
          items: shops.map((shop) {
            return DropdownMenuItem<int>(
              value: shop.id,
              child: Text('${shop.designation} - ${shop.localisation}'),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedShopId = value;
            });
          },
          validator: (value) {
            if (_routeType == 'SHOP_SPECIFIC' && value == null) {
              return 'Veuillez sélectionner un shop';
            }
            return null;
          },
        );
      },
    );
  }

  Widget _buildShopSourceDestinationSelector(bool isMobile) {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        final shops = shopService.shops;
        
        if (shops.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Aucun shop disponible',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ),
          );
        }

        return Column(
          children: [
            // Shop Source
            DropdownButtonFormField<int>(
              value: _selectedShopSourceId,
              decoration: InputDecoration(
                labelText: 'Shop Source (Départ)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.orange[50],
                prefixIcon: const Icon(Icons.store, color: Colors.orange),
              ),
              items: shops.map((shop) {
                return DropdownMenuItem<int>(
                  value: shop.id,
                  child: Text('${shop.designation} - ${shop.localisation}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedShopSourceId = value;
                });
              },
              validator: (value) {
                if (_routeType == 'SHOP_TO_SHOP' && value == null) {
                  return 'Veuillez sélectionner le shop source';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Flèche indicatrice
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.arrow_downward, size: 20, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Shop Destination
            DropdownButtonFormField<int>(
              value: _selectedShopDestinationId,
              decoration: InputDecoration(
                labelText: 'Shop Destination (Arrivée)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.green[50],
                prefixIcon: const Icon(Icons.store, color: Colors.green),
              ),
              items: shops.where((shop) => shop.id != _selectedShopSourceId).map((shop) {
                return DropdownMenuItem<int>(
                  value: shop.id,
                  child: Text('${shop.designation} - ${shop.localisation}'),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedShopDestinationId = value;
                });
              },
              validator: (value) {
                if (_routeType == 'SHOP_TO_SHOP' && value == null) {
                  return 'Veuillez sélectionner le shop destination';
                }
                if (_selectedShopSourceId != null && value == _selectedShopSourceId) {
                  return 'Le shop destination doit être différent du shop source';
                }
                if (_routeType == 'SHOP_TO_SHOP' && _selectedShopSourceId == null) {
                  return 'Veuillez d\'abord sélectionner un shop source';
                }
                return null;
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildActions(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[300]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _handleSubmit,
            icon: const Icon(Icons.check),
            label: Text(widget.commission == null ? 'Créer' : 'Modifier'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isMobile ? 20 : 24,
                vertical: isMobile ? 12 : 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final ratesService = Provider.of<RatesService>(context, listen: false);
    
    final commission = CommissionModel(
      id: widget.commission?.id,
      type: _selectedType,
      taux: _selectedType == 'ENTRANT' ? 0.0 : double.parse(_tauxController.text.trim()),
      description: _descriptionController.text.trim(),
      shopId: _routeType == 'SHOP_SPECIFIC' ? _selectedShopId : null,
      shopSourceId: _routeType == 'SHOP_TO_SHOP' ? _selectedShopSourceId : null,
      shopDestinationId: _routeType == 'SHOP_TO_SHOP' ? _selectedShopDestinationId : null,
    );

    bool success;
    if (widget.commission == null) {
      // Création
      success = await ratesService.createCommission(
        type: commission.type,
        taux: commission.taux,
        description: commission.description,
        shopId: commission.shopId,
        shopSourceId: commission.shopSourceId,
        shopDestinationId: commission.shopDestinationId,
      );
    } else {
      // Modification
      success = await ratesService.updateCommission(commission);
    }

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.commission == null 
                ? '✅ Commission créée avec succès!' 
                : '✅ Commission modifiée avec succès!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Erreur lors de l\'opération'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
