import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/operation_model.dart';
import '../services/flot_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../utils/currency_utils.dart';

/// Dialog pour créer ou mettre à jour un FLOT
class FlotDialog extends StatefulWidget {
  final OperationModel? flot; // Si null, c'est une création, sinon c'est une mise à jour
  final int? currentShopId; // ID du shop actuel (source par défaut)

  const FlotDialog({
    super.key,
    this.flot,
    this.currentShopId,
  });

  @override
  State<FlotDialog> createState() => _FlotDialogState();
}

class _FlotDialogState extends State<FlotDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _montantController;
  late TextEditingController _notesController;
  
  int? _selectedShopDestinationId;
  ModePaiement _selectedModePaiement = ModePaiement.cash;
  String _selectedCurrency = CurrencyUtils.defaultCurrency; // USD par défaut
  
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController(
      text: widget.flot?.montantNet.toString() ?? '',
    );
    _notesController = TextEditingController(
      text: widget.flot?.notes ?? '',
    );
    
    _selectedShopDestinationId = widget.flot?.shopDestinationId;
    _selectedModePaiement = widget.flot?.modePaiement ?? ModePaiement.cash;
    _selectedCurrency = widget.flot?.devise ?? CurrencyUtils.defaultCurrency;
  }

  @override
  void dispose() {
    _montantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shopService = Provider.of<ShopService>(context);
    final authService = Provider.of<AuthService>(context);
    final currentShopId = widget.currentShopId ?? authService.currentUser?.shopId;
    
    // Filtrer les shops pour exclure le shop source
    final availableShops = shopService.shops
        .where((shop) => shop.id != currentShopId)
        .toList();
        
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final dialogWidth = isMobile ? size.width * 0.9 : 500.0;

    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: size.height * 0.9, // Limiter la hauteur à 90% de l'écran
        ),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView( // Rendre le contenu scrollable
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header avec icône et titre
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: Color(0xFF9C27B0),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.local_shipping,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.flot == null ? 'Nouvel Approvisionnement' : 'Modifier Approvisionnement',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.flot == null 
                            ? "Envoyer de l'argent à un autre shop" 
                            : 'Mettre à jour les détails du transfert',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Montant avec design amélioré
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Montant à envoyer',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _montantController,
                      decoration: InputDecoration(
                        hintText: 'Entrez le montant',
                        prefixIcon: const Icon(Icons.attach_money, color: Colors.blue),
                        suffixText: _selectedCurrency,
                        suffixStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.blue.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF9C27B0), width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(decimal: true),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Veuillez entrer un montant';
                        }
                        final montant = double.tryParse(value);
                        if (montant == null || montant <= 0) {
                          return 'Veuillez entrer un montant valide';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Informations sur la dette
              if (widget.flot == null) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.orange, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'En envoyant ce FLOT, le shop de destination vous devra ce montant',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              // Shop de destination
              _buildDropdownField(
                label: 'Shop de destination',
                icon: Icons.store,
                child: DropdownButtonFormField<int>(
                  value: _selectedShopDestinationId,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  items: availableShops.map((shop) {
                    return DropdownMenuItem(
                      value: shop.id,
                      child: Text(
                        shop.designation,
                        style: const TextStyle(fontSize: 16),
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => _selectedShopDestinationId = value);
                  },
                  validator: (value) {
                    if (value == null) {
                      return 'Veuillez sélectionner un shop de destination';
                    }
                    return null;
                  },
                  isExpanded: true,
                ),
              ),
              const SizedBox(height: 16),
              
              // Mode de paiement
              _buildDropdownField(
                label: 'Mode de paiement',
                icon: Icons.payment,
                child: DropdownButtonFormField<ModePaiement>(
                  value: _selectedModePaiement,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  items: ModePaiement.values
                    .where((mode) => mode == ModePaiement.cash) // MASQUÉ: Seul Cash doit être visible
                    .map((mode) {
                    String label;
                    IconData icon;
                    switch (mode) {
                      case ModePaiement.cash:
                        label = 'Cash';
                        icon = Icons.money;
                        break;
                      case ModePaiement.airtelMoney:
                        label = 'Airtel Money';
                        icon = Icons.phone_android;
                        break;
                      case ModePaiement.mPesa:
                        label = 'M-Pesa';
                        icon = Icons.phone_iphone;
                        break;
                      case ModePaiement.orangeMoney:
                        label = 'Orange Money';
                        icon = Icons.phone_iphone;
                        break;
                    }
                    
                    return DropdownMenuItem(
                      value: mode,
                      child: Row(
                        children: [
                          Icon(icon, size: 18, color: const Color(0xFF9C27B0)),
                          const SizedBox(width: 12),
                          Text(label, style: const TextStyle(fontSize: 16)),
                        ],
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _selectedModePaiement = value);
                    }
                  },
                  isExpanded: true,
                ),
              ),
              const SizedBox(height: 16),
              
              // Notes
              _buildTextField(
                label: 'Notes (optionnel)',
                icon: Icons.note,
                child: TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    hintText: 'Ajoutez des détails sur ce transfert...',
                  ),
                  maxLines: 3,
                ),
              ),
              
              // Message d'erreur
              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (_isLoading) ...[
                const SizedBox(height: 24),
                const Center(child: CircularProgressIndicator(color: Color(0xFF9C27B0))),
              ],
              
              const SizedBox(height: 24),
              
              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Annuler',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleSubmit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9C27B0),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        widget.flot == null ? 'Envoyer Flot' : 'Mettre à jour',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          ), // Fin du SingleChildScrollView
        ),
      ),
    );
  }

  /// Widget helper pour les champs dropdown
  Widget _buildDropdownField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF9C27B0), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
  
  /// Widget helper pour les champs text
  Widget _buildTextField({
    required String label,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF9C27B0), size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
  
  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final flotService = Provider.of<FlotService>(context, listen: false);
      
      final currentShopId = widget.currentShopId ?? authService.currentUser?.shopId;
      final currentAgentId = authService.currentUser?.id;
      final currentAgentUsername = authService.currentUser?.username;
      
      if (currentShopId == null || currentAgentId == null) {
        throw Exception('Utilisateur non authentifié');
      }
      
      // IMPORTANT: Charger les shops si pas encore chargés
      if (shopService.shops.isEmpty) {
        debugPrint('⚠️ Shops non chargés, chargement en cours...');
        await shopService.loadShops();
        debugPrint('✅ ${shopService.shops.length} shops chargés');
      }
      
      final montant = double.parse(_montantController.text);
      final shopDestination = shopService.getShopById(_selectedShopDestinationId!);
      
      if (shopDestination == null) {
        throw Exception('Shop de destination introuvable (ID: $_selectedShopDestinationId)');
      }
      
      final currentShop = shopService.getShopById(currentShopId);
      if (currentShop == null) {
        throw Exception('Shop source introuvable (ID: $currentShopId). ${shopService.shops.length} shops disponibles.');
      }
      
      if (widget.flot == null) {
        // Création d'un nouveau flot
        final success = await flotService.createFlot(
          shopSourceId: currentShopId,
          shopSourceDesignation: currentShop.designation,
          shopDestinationId: _selectedShopDestinationId!,
          shopDestinationDesignation: shopDestination.designation,
          montant: montant,
          devise: 'USD',
          modePaiement: _selectedModePaiement,
          agentEnvoyeurId: currentAgentId,
          agentEnvoyeurUsername: currentAgentUsername,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
        );
        
        if (!success) {
          throw Exception(flotService.errorMessage ?? 'Erreur lors de la création du flot');
        }
      } else {
        // Mise à jour d'un flot existant (seulement si c'est le shop source et statut enRoute)
        if (widget.flot!.shopSourceId != currentShopId) {
          throw Exception('Vous ne pouvez modifier que les flots que vous avez créés');
        }
        
        if (widget.flot!.statut != OperationStatus.enAttente) {
          throw Exception('Seuls les flots en cours peuvent être modifiés');
        }
        
        final updatedFlot = widget.flot!.copyWith(
          shopDestinationId: _selectedShopDestinationId!,
          shopDestinationDesignation: shopDestination.designation,
          montantBrut: montant,
          montantNet: montant,
          modePaiement: _selectedModePaiement,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'agent_$currentAgentUsername',
        );
        
        final success = await flotService.updateFlot(updatedFlot);
        if (!success) {
          throw Exception(flotService.errorMessage ?? 'Erreur lors de la mise à jour du flot');
        }
      }
      
      if (mounted) {
        Navigator.pop(context, true); // Retourner true pour indiquer le succès
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
}