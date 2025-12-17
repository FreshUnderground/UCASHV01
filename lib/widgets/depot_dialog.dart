import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';
import '../utils/responsive_dialog_utils.dart';
import '../utils/auto_print_helper.dart';

class DepotDialog extends StatefulWidget {
  final ClientModel? preselectedClient;
  
  const DepotDialog({super.key, this.preselectedClient});

  @override
  State<DepotDialog> createState() => _DepotDialogState();
}

class _DepotDialogState extends State<DepotDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _observationController = TextEditingController();

  ClientModel? _selectedClient;
  ModePaiement _modePaiement = ModePaiement.cash;
  bool _isLoading = false;
  List<ClientModel> _clients = [];
  DateTime _selectedDate = DateTime.now();
  
  // Shop destination selection
  ShopModel? _selectedShopDestination;
  List<ShopModel> _availableShops = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
    });
    _montantController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _montantController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  Future<void> _loadClients() async {
    final clientService = Provider.of<ClientService>(context, listen: false);
    final shopService = Provider.of<ShopService>(context, listen: false);
    
    await clientService.loadClients();
    await shopService.loadShops();
    
    if (mounted) {
      setState(() {
        _clients = clientService.clients;
        _availableShops = shopService.shops;
        
        // Re-synchroniser le client présélectionné avec la liste chargée
        if (widget.preselectedClient != null && widget.preselectedClient!.id != null) {
          _selectedClient = _clients.firstWhere(
            (c) => c.id == widget.preselectedClient!.id,
            orElse: () => widget.preselectedClient!,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('🔴 DEPOT DIALOG OPENED!');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 480;
    final fieldSpacing = ResponsiveDialogUtils.getFieldSpacing(context);
    final labelFontSize = ResponsiveDialogUtils.getLabelFontSize(context);
    
    return ResponsiveDialogUtils.buildResponsiveDialog(
      context: context,
      header: ResponsiveDialogUtils.buildResponsiveHeader(
        context: context,
        title: 'Nouveau Dépôt',
        icon: Icons.add_circle,
        color: Colors.green,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instructions - plus compactes sur mobile
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.green, size: ResponsiveDialogUtils.getIconSize(context)),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      isMobile
                          ? 'Sélectionnez le client et le montant à déposer.'
                          : 'Pour effectuer un dépôt dans un compte client :\n• Sélectionnez le client\n• Saisissez le montant à déposer\n• Le montant sera ajouté au solde du client',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: fieldSpacing),
            
            // 1. Sélection du client
            Text(
              '1. Sélection du client *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            DropdownButtonFormField<ClientModel>(
              value: _selectedClient,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Choisir un client',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              items: _clients.map((client) {
                return DropdownMenuItem<ClientModel>(
                  value: client,
                  child: Text(
                    '${client.nom} - N° ${client.id?.toString().padLeft(6, '0') ?? 'N/A'}',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (ClientModel? value) {
                setState(() {
                  _selectedClient = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Veuillez sélectionner un client';
                }
                return null;
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // 2. Montant
            Text(
              '2. Montant du dépôt *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            TextFormField(
              controller: _montantController,
              decoration: InputDecoration(
                labelText: 'Montant en USD',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money, size: ResponsiveDialogUtils.getIconSize(context)),
                suffixText: 'USD',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: isMobile ? 16 : 18),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le montant est requis';
                }
                final montant = double.tryParse(value);
                if (montant == null || montant <= 0) {
                  return 'Montant invalide';
                }
                return null;
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // 3. Date de l'opération (Admin seulement)
            Consumer<AuthService>(
              builder: (context, authService, child) {
                final isAdmin = authService.currentUser?.role.toUpperCase() == 'ADMIN';
                debugPrint('🔐 DEPOT DIALOG - User role: ${authService.currentUser?.role}, isAdmin: $isAdmin');
                
                // Masquer complètement la section pour les agents
                if (!isAdmin) {
                  return const SizedBox.shrink();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3. Date de l\'opération *',
                      style: TextStyle(
                        fontSize: labelFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    SizedBox(height: isMobile ? 8 : 12),
                    
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () async {
                          debugPrint('📅 Admin clicked - Opening date picker...');
                          
                          try {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: _selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                              helpText: 'Sélectionner la date du dépôt',
                              cancelText: 'Annuler',
                              confirmText: 'OK',
                            );
                            
                            debugPrint('📍 Date returned: $date');
                            
                            if (date != null) {
                              setState(() {
                                _selectedDate = date;
                              });
                              debugPrint('✅ Date sélectionnée: ${date.toString()}');
                            }
                          } catch (e) {
                            debugPrint('❌ Erreur date picker: $e');
                          }
                        },
                        child: Ink(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.green.shade300,
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.green.withOpacity(0.1),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 16 : 20,
                            vertical: isMobile ? 16 : 18,
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  color: Colors.green,
                                  size: isMobile ? 20 : 24,
                                ),
                              ),
                              SizedBox(width: isMobile ? 12 : 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Date',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 18,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Icon(
                                  Icons.edit_calendar,
                                  size: 18,
                                  color: Colors.green.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: fieldSpacing),
                  ],
                );
              },
            ),
            
            // Shop de destination *
            Consumer<AuthService>(
              builder: (context, authService, child) {
                final isAdmin = authService.currentUser?.role.toUpperCase() == 'ADMIN';
                final sectionNumber = isAdmin ? '4' : '3';
                
                return Text(
                  '$sectionNumber. Shop de destination *',
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                );
              },
            ),
            SizedBox(height: isMobile ? 8 : 12),          
            DropdownButtonFormField<ShopModel>(
              value: _selectedShopDestination,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Shop de destination',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.store, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              items: _availableShops.map((shop) {
                return DropdownMenuItem<ShopModel>(
                  value: shop,
                  child: Text(
                    '${shop.designation} - ID: ${shop.id}',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (ShopModel? value) {
                setState(() {
                  _selectedShopDestination = value;
                });
              },
              validator: (value) {
                if (value == null) {
                  return 'Veuillez sélectionner un shop de destination';
                }
                return null;
              },
            ),
            
            // Message informatif dynamique sur le crédit intershop
            Consumer<AuthService>(
              builder: (context, authService, child) {
                if (_selectedShopDestination == null) return const SizedBox.shrink();
                
                final currentShopId = authService.currentUser?.shopId;
                final isIntershop = _selectedShopDestination!.id != currentShopId;
                
                return Container(
                  margin: EdgeInsets.only(top: isMobile ? 8 : 12),
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: isIntershop ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isIntershop ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isIntershop ? Icons.swap_horiz : Icons.check_circle,
                        color: isIntershop ? Colors.orange : Colors.green,
                        size: ResponsiveDialogUtils.getIconSize(context),
                      ),
                      SizedBox(width: isMobile ? 8 : 12),
                      Expanded(
                        child: Text(
                          isIntershop 
                            ? 'Crédit intershop: Ce dépôt créera une dette/créance entre shops.'
                            : 'Opération interne: Aucun crédit intershop (même shop).',
                          style: TextStyle(
                            color: isIntershop ? Colors.orange.shade700 : Colors.green.shade700,
                            fontSize: isMobile ? 13 : 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // Mode de paiement
            Consumer<AuthService>(
              builder: (context, authService, child) {
                final isAdmin = authService.currentUser?.role.toUpperCase() == 'ADMIN';
                final sectionNumber = isAdmin ? '5' : '4';
                
                return Text(
                  '$sectionNumber. Mode de paiement *',
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                );
              },
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            DropdownButtonFormField<ModePaiement>(
              value: _modePaiement,
              decoration: InputDecoration(
                labelText: 'Mode de paiement',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: ModePaiement.cash,
                  child: Row(
                    children: [
                      Icon(Icons.money, color: Colors.green),
                      SizedBox(width: 8),
                      Text('Cash'),
                    ],
                  ),
                ),
                // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
                // DropdownMenuItem(
                //   value: ModePaiement.airtelMoney,
                //   child: Row(
                //     children: [
                //       Icon(Icons.phone_android, color: Colors.orange),
                //       SizedBox(width: 8),
                //       Text('Airtel Money'),
                //     ],
                //   ),
                // ),
                // DropdownMenuItem(
                //   value: ModePaiement.mPesa,
                //   child: Row(
                //     children: [
                //       Icon(Icons.account_balance_wallet, color: Colors.blue),
                //       SizedBox(width: 8),
                //       Text('M-Pesa'),
                //     ],
                //   ),
                // ),
                // DropdownMenuItem(
                //   value: ModePaiement.orangeMoney,
                //   child: Row(
                //     children: [
                //       Icon(Icons.payment, color: Colors.orange),
                //       SizedBox(width: 8),
                //       Text('Orange Money'),
                //     ],
                //   ),
                // ),
              ],
              onChanged: (value) {
                setState(() {
                  _modePaiement = value!;
                });
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // Observation
            Consumer<AuthService>(
              builder: (context, authService, child) {
                final isAdmin = authService.currentUser?.role.toUpperCase() == 'ADMIN';
                final sectionNumber = isAdmin ? '6' : '5';
                
                return Text(
                  '$sectionNumber. Observation *',
                  style: TextStyle(
                    fontSize: labelFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                );
              },
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            TextFormField(
              controller: _observationController,
              decoration: InputDecoration(
                labelText: 'Observation',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.note, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              maxLines: 3,
              style: TextStyle(fontSize: isMobile ? 14 : 16),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'L\'observation est requise';
                }
                return null;
              },
            ),
            SizedBox(height: fieldSpacing),

            // Résumé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résumé du dépôt',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Montant:'),
                      Text(
                        '${_montantController.text.isEmpty ? '0' : _montantController.text} USD',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Partenaire:'),
                      Text(
                        _selectedClient?.nom ?? 'Non sélectionné',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Mode de paiement:'),
                      Text(
                        _getModePaiementLabel(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Shop destination:'),
                      Text(
                        _selectedShopDestination?.designation ?? 'Non sélectionné',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),


                  // Add CodeOps preview
                  if (_selectedClient != null && _montantController.text.isNotEmpty)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Code Opération:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          // Generate a preview of what the CodeOps will look like (timestamp-based for uniqueness)
                          () {
                            final now = DateTime.now();
                            final year = (now.year % 100).toString().padLeft(2, '0');
                            final month = now.month.toString().padLeft(2, '0');
                            final day = now.day.toString().padLeft(2, '0');
                            final hour = now.hour.toString().padLeft(2, '0');
                            final minute = now.minute.toString().padLeft(2, '0');
                            return '$year$month$day${hour}${minute}00123';
                          }(),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: ResponsiveDialogUtils.buildResponsiveActions(
        context: context,
        actions: [
          if (!isMobile)
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              minimumSize: Size(isMobile ? double.infinity : 120, isMobile ? 48 : 40),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(isMobile ? 'Confirmer' : 'Confirmer Dépôt'),
          ),
        ],
      ),
    );
  }

  String _getModePaiementLabel() {
    switch (_modePaiement) {
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

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final montant = double.parse(_montantController.text);
      
      // Récupérer le shop de l'agent pour obtenir la designation
      final shopId = authService.currentUser?.shopId ?? _selectedClient!.shopId ?? 1;
      ShopModel? shop;
      try {
        shop = shopService.shops.firstWhere((s) => s.id == shopId);
      } catch (e) {
        debugPrint('⚠️ Shop non trouvé pour ID $shopId');
        shop = null;
      }
      
      // Validation: Shop destination requis
      if (_selectedShopDestination == null) {
        throw Exception('Veuillez sélectionner un shop de destination');
      }
      
      // Créer l'opération de dépôt avec shop destination
      final operation = OperationModel(
        codeOps: '', // Sera généré automatiquement par createOperation
        type: OperationType.depot,
        montantBrut: montant,
        commission: 0.0,
        montantNet: montant,
        devise: 'USD',
        destinataire: _selectedClient!.nom,
        clientId: _selectedClient!.id,
        clientNom: _selectedClient!.nom,
        modePaiement: _modePaiement,
        agentId: authService.currentUser?.id ?? 1,
        agentUsername: authService.currentUser?.username,
        shopSourceId: shopId,
        shopSourceDesignation: shop?.designation,
        shopDestinationId: _selectedShopDestination!.id,
        shopDestinationDesignation: _selectedShopDestination!.designation,
        statut: OperationStatus.terminee,
        dateOp: _selectedDate,
        notes: _observationController.text,
        observation: _observationController.text,
      );
      
      debugPrint('🔍 DEPOT CRÉÉ: statut=${operation.statut.name} (index=${operation.statut.index})');
      debugPrint('   Montant: ${operation.montantBrut}, Client: ${operation.clientNom}');

      // Créer l'opération (cela mettra à jour automatiquement les soldes)
      final savedOperation = await operationService.createOperation(operation, authService: authService);
      
      if (savedOperation != null && mounted) {
        // Fermer le dialog de dépôt
        Navigator.of(context).pop(true);
        
        // Le shop a déjà été récupéré plus haut
        // Convertir UserModel en AgentModel pour le reçu
        if (shop != null && authService.currentUser != null) {
          final agent = AgentModel(
            id: authService.currentUser!.id,
            username: authService.currentUser!.username,
            password: '', // Pas besoin du mot de passe pour le reçu
            shopId: shopId,
            nom: authService.currentUser!.nom,
            telephone: authService.currentUser!.telephone,
          );
          
          // Imprimer automatiquement le reçu sur POS
          await AutoPrintHelper.autoPrintWithDialog(
            context: context,
            operation: savedOperation,
            shop: shop,
            agent: agent,
            clientName: _selectedClient!.nom,
          );
        } else {
          // Pas de reçu si shop ou user manquant, mais afficher succès
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Dépôt enregistré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else if (mounted) {
        throw Exception(operationService.errorMessage ?? 'Erreur inconnue');
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a closure-related error
        final errorMessage = e.toString();
        if (errorMessage.contains('clôturer') || errorMessage.contains('clôturée')) {
          // Show a prominent alert dialog for closure issues
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.lock_clock, color: Colors.orange, size: 28),
                  SizedBox(width: 12),
                  Text('Journée Clôturée'),
                ],
              ),
              content: Text(
                errorMessage.replaceAll('Exception: ', ''),
                style: const TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK', style: TextStyle(fontSize: 16)),
                ),
              ],
            ),
          );
        } else {
          // Show regular error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
