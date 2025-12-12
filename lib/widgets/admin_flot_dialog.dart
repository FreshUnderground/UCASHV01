import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/operation_model.dart';
import '../models/compte_special_model.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/compte_special_service.dart';

/// Dialog pour créer des FLOTs administratifs
/// - Crée des dettes inter-shops
/// - Attribue des frais à chaque shop
/// - N'impacte PAS le cash disponible
class AdminFlotDialog extends StatefulWidget {
  const AdminFlotDialog({super.key});

  @override
  State<AdminFlotDialog> createState() => _AdminFlotDialogState();
}

class _AdminFlotDialogState extends State<AdminFlotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _fraisShopSourceController = TextEditingController();
  final _fraisShopDestinationController = TextEditingController();
  final _notesController = TextEditingController();
  
  int? _shopSourceId;
  int? _shopDestinationId;
  bool _isLoading = false;
  DateTime _selectedDate = DateTime.now(); // Date sélectionnée pour le flot

  @override
  void dispose() {
    _montantController.dispose();
    _fraisShopSourceController.dispose();
    _fraisShopDestinationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _creerFlotAdministratif() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_shopSourceId == null || _shopDestinationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner les deux shops'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_shopSourceId == _shopDestinationId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Les shops source et destination doivent être différents'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final compteSpecialService = CompteSpecialService.instance;
      
      final montant = double.parse(_montantController.text);
      final fraisSource = _fraisShopSourceController.text.isEmpty 
          ? 0.0 
          : double.parse(_fraisShopSourceController.text);
      final fraisDestination = _fraisShopDestinationController.text.isEmpty 
          ? 0.0 
          : double.parse(_fraisShopDestinationController.text);
      
      final shopSource = shopService.getShopById(_shopSourceId!);
      final shopDestination = shopService.getShopById(_shopDestinationId!);
      
      if (shopSource == null || shopDestination == null) {
        throw Exception('Shop introuvable');
      }

      // 1. Créer le FLOT administratif (n'impacte PAS le cash)
      final flotReference = _generateReference(_shopSourceId!, _shopDestinationId!);
      
      final flotAdministratif = OperationModel(
        type: OperationType.flotShopToShop,
        shopSourceId: _shopSourceId!,
        shopSourceDesignation: shopSource.designation,
        shopDestinationId: _shopDestinationId!,
        shopDestinationDesignation: shopDestination.designation,
        
        montantBrut: montant,
        montantNet: montant,
        commission: 0.0, // Pas de commission sur le flot lui-même
        devise: 'USD',
        
        modePaiement: ModePaiement.cash,
        statut: OperationStatus.validee, // Validé immédiatement
        
        agentId: authService.currentUser?.id ?? 1,
        agentUsername: authService.currentUser?.username ?? 'admin',
        
        dateOp: _selectedDate, // Date sélectionnée par l'admin
        dateValidation: _selectedDate, // Même date pour validation
        notes: _notesController.text.isNotEmpty 
            ? 'FLOT ADMINISTRATIF - ${_notesController.text}' 
            : 'FLOT ADMINISTRATIF',
        
        codeOps: flotReference,
        reference: flotReference,
        destinataire: shopDestination.designation,
        
        createdAt: DateTime.now(), // Date de création = maintenant
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'admin_${authService.currentUser?.username}',
        
        // FLAG CRITIQUE: Ce flot est administratif et n'impacte pas le cash
        isAdministrative: true,
      );

      // Sauvegarder le flot administratif
      await LocalDB.instance.saveOperation(flotAdministratif);
      
      debugPrint('✅ Flot administratif créé: ${flotAdministratif.codeOps}');
      debugPrint('   ${shopSource.designation} → ${shopDestination.designation}');
      debugPrint('   Montant: $montant USD');
      debugPrint('   isAdministrative: true (n\'impacte PAS le cash)');

      // 2. Attribuer les frais au shop SOURCE (si spécifié)
      if (fraisSource > 0) {
        await compteSpecialService.createTransaction(
          type: TypeCompteSpecial.FRAIS,
          typeTransaction: TypeTransactionCompte.COMMISSION_AUTO,
          montant: fraisSource,
          description: 'Frais flot administratif vers ${shopDestination.designation}',
          shopId: _shopSourceId!,
          operationId: flotAdministratif.id,
          agentId: authService.currentUser?.id,
          agentUsername: authService.currentUser?.username,
        );
        
        debugPrint('✅ Frais attribués au shop source: $fraisSource USD');
      }

      // 3. Attribuer les frais au shop DESTINATION (si spécifié)
      if (fraisDestination > 0) {
        await compteSpecialService.createTransaction(
          type: TypeCompteSpecial.FRAIS,
          typeTransaction: TypeTransactionCompte.COMMISSION_AUTO,
          montant: fraisDestination,
          description: 'Frais flot administratif depuis ${shopSource.designation}',
          shopId: _shopDestinationId!,
          operationId: flotAdministratif.id,
          agentId: authService.currentUser?.id,
          agentUsername: authService.currentUser?.username,
        );
        
        debugPrint('✅ Frais attribués au shop destination: $fraisDestination USD');
      }

      setState(() => _isLoading = false);

      if (mounted) {
        Navigator.of(context).pop(true); // Retourner true pour indiquer le succès
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Flot administratif créé avec succès',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text('${shopSource.designation} → ${shopDestination.designation}'),
                Text('Montant: ${montant.toStringAsFixed(2)} USD'),
                Text('Date: ${_formatDate(_selectedDate)}'),
                if (fraisSource > 0 || fraisDestination > 0)
                  Text('Frais: ${(fraisSource + fraisDestination).toStringAsFixed(2)} USD'),
              ],
            ),
            backgroundColor: Colors.green.shade700,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      debugPrint('❌ Erreur création flot administratif: $e');
    }
  }

  String _generateReference(int shopSourceId, int shopDestinationId) {
    final now = DateTime.now();
    final year = (now.year % 100).toString().padLeft(2, '0');
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final second = now.second.toString().padLeft(2, '0');
    
    return 'ADMIN_$year$month$day$hour$minute${second}_S${shopSourceId}D$shopDestinationId';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.purple.shade700,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final shopService = Provider.of<ShopService>(context);
    final availableShops = shopService.shops.where((s) => s.id != null).toList();

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.admin_panel_settings, color: Colors.purple.shade700),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Créer un Flot Administratif',
              style: TextStyle(fontSize: 18),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Information card
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, 
                            size: 20, 
                            color: Colors.blue.shade700,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Flot Administratif',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• N\'impacte PAS le cash disponible\n'
                        '• Crée des dettes inter-shops\n'
                        '• Permet d\'attribuer des frais',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Shop Source
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Shop Source',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                  ),
                  value: _shopSourceId,
                  items: availableShops.map((shop) {
                    return DropdownMenuItem<int>(
                      value: shop.id,
                      child: Text(shop.designation),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _shopSourceId = value),
                  validator: (value) => value == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                
                // Shop Destination
                DropdownButtonFormField<int>(
                  decoration: const InputDecoration(
                    labelText: 'Shop Destination',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store_outlined),
                  ),
                  value: _shopDestinationId,
                  items: availableShops.map((shop) {
                    return DropdownMenuItem<int>(
                      value: shop.id,
                      child: Text(shop.designation),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _shopDestinationId = value),
                  validator: (value) => value == null ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                
                // Sélecteur de Date
                InkWell(
                  onTap: _selectDate,
                  borderRadius: BorderRadius.circular(4),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date du Flot',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                      hintText: 'Sélectionnez la date',
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDate(_selectedDate),
                          style: const TextStyle(fontSize: 16),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Montant
                TextFormField(
                  controller: _montantController,
                  decoration: const InputDecoration(
                    labelText: 'Montant du Flot (USD)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.attach_money),
                    suffixText: 'USD',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Requis';
                    final montant = double.tryParse(value);
                    if (montant == null || montant <= 0) {
                      return 'Montant invalide';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Divider
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Attribution des Frais (optionnel)',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Frais Shop Source
                TextFormField(
                  controller: _fraisShopSourceController,
                  decoration: const InputDecoration(
                    labelText: 'Frais pour Shop Source',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments),
                    suffixText: 'USD',
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Frais Shop Destination
                TextFormField(
                  controller: _fraisShopDestinationController,
                  decoration: const InputDecoration(
                    labelText: 'Frais pour Shop Destination',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payments_outlined),
                    suffixText: 'USD',
                    hintText: '0.00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Notes
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes / Raison',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.note),
                    hintText: 'Ex: Régularisation de compte...',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _creerFlotAdministratif,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Créer Flot Administratif'),
        ),
      ],
    );
  }
}
