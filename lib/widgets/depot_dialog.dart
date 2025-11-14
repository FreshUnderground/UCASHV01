import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import '../utils/responsive_dialog_utils.dart';
import 'print_receipt_dialog.dart';

class DepotDialog extends StatefulWidget {
  const DepotDialog({super.key});

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
    await clientService.loadClients();
    if (mounted) {
      setState(() {
        _clients = clientService.clients;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
            
            // 3. Mode de paiement
            Text(
              '3. Mode de paiement *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
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
                DropdownMenuItem(
                  value: ModePaiement.airtelMoney,
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Airtel Money'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ModePaiement.mPesa,
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('M-Pesa'),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ModePaiement.orangeMoney,
                  child: Row(
                    children: [
                      Icon(Icons.payment, color: Colors.orange),
                      SizedBox(width: 8),
                      Text('Orange Money'),
                    ],
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _modePaiement = value!;
                });
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // 4. Observation (facultatif)
            Text(
              '4. Observation (facultatif)',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
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
            ),
            SizedBox(height: fieldSpacing),
            
            // Solde actuel du client
            if (_selectedClient != null) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.account_balance_wallet, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Solde actuel du client',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            '${_selectedClient!.solde.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _selectedClient!.solde >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: fieldSpacing),
            ],
            
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
                      const Text('Client:'),
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
                      const Text('Nouveau solde:'),
                      Text(
                        _selectedClient != null && _montantController.text.isNotEmpty
                            ? '${(_selectedClient!.solde + (double.tryParse(_montantController.text) ?? 0)).toStringAsFixed(2)} USD'
                            : '${_selectedClient?.solde.toStringAsFixed(2) ?? '0.00'} USD',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Type d\'opération:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Text(
                        'DÉPÔT (0% commission)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
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
        return 'M-Pesa';
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
      
      // Créer l'opération de dépôt
      final operation = OperationModel(
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
        shopSourceId: authService.currentUser?.shopId ?? 1,
        statut: OperationStatus.terminee,
        dateOp: DateTime.now(),
        notes: 'Dépôt dans le compte client',
        observation: _observationController.text.isNotEmpty ? _observationController.text : null,
      );
      
      debugPrint('🔍 DEPOT CRÉÉ: statut=${operation.statut.name} (index=${operation.statut.index})');
      debugPrint('   Montant: ${operation.montantBrut}, Client: ${operation.clientNom}');

      // Créer l'opération (cela mettra à jour automatiquement les soldes)
      final savedOperation = await operationService.createOperation(operation);
      
      if (savedOperation != null && mounted) {
        // Fermer le dialog de dépôt
        Navigator.of(context).pop(true);
        
        // Récupérer les données pour le reçu
        final shop = shopService.shops.firstWhere(
          (s) => s.id == authService.currentUser?.shopId,
          orElse: () => shopService.shops.first,
        );
        
        // Convertir UserModel en AgentModel pour le reçu
        final agent = AgentModel(
          id: authService.currentUser!.id,
          username: authService.currentUser!.username,
          password: '', // Pas besoin du mot de passe pour le reçu
          shopId: authService.currentUser!.shopId!,
          nom: authService.currentUser!.nom,
          telephone: authService.currentUser!.telephone,
        );
        
        // Afficher le dialog d'impression
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => PrintReceiptDialog(
            operation: savedOperation,
            shop: shop,
            agent: agent,
            clientName: _selectedClient!.nom,
            onPrintSuccess: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dépôt de ${montant.toStringAsFixed(2)} USD effectué - Reçu imprimé'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onSkipPrint: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Dépôt de ${montant.toStringAsFixed(2)} USD effectué (sans impression)'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        );
      } else if (mounted) {
        throw Exception(operationService.errorMessage ?? 'Erreur inconnue');
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
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
