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
import '../utils/auto_print_helper.dart';

class RetraitDialog extends StatefulWidget {
  const RetraitDialog({super.key});

  @override
  State<RetraitDialog> createState() => _RetraitDialogState();
}

class _RetraitDialogState extends State<RetraitDialog> {
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
        title: 'Nouveau Retrait',
        icon: Icons.remove_circle,
        color: Colors.orange,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instructions
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.orange, size: ResponsiveDialogUtils.getIconSize(context)),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      isMobile
                          ? 'Sélectionnez le client et le montant à retirer.'
                          : 'Pour effectuer un retrait d\'un compte client :\n• Sélectionnez le client\n• Saisissez le montant à retirer\n• Le montant sera débité du solde du client',
                      style: TextStyle(
                        color: Colors.orange,
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
                color: Colors.orange,
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
              '2. Montant du retrait *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
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
                color: Colors.orange,
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
              items: const [
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
            
            // 4. Observation (new field)
            Text(
              '4. Observation (facultatif)',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
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
              const SizedBox(height: 16),
              
              // Validation du solde (DÉCOUVERT AUTORISÉ)
              if (_montantController.text.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _getNouveauSolde() >= 0 
                        ? Colors.green.withOpacity(0.1) 
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _getNouveauSolde() >= 0 
                          ? Colors.green.withOpacity(0.3) 
                          : Colors.orange.withOpacity(0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _getNouveauSolde() >= 0 ? Icons.check_circle : Icons.warning,
                        color: _getNouveauSolde() >= 0 ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _getNouveauSolde() >= 0
                              ? 'Retrait validé - Solde restant positif'
                              : 'DÉCOUVERT: Le client nous devra ${_getNouveauSolde().abs().toStringAsFixed(2)} USD après ce retrait',
                          style: TextStyle(
                            color: _getNouveauSolde() >= 0 ? Colors.green : Colors.orange,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            
            // Résumé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Résumé du retrait',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.orange,
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
                      const Text('Nouveau solde:'),
                      Text(
                        _selectedClient != null && _montantController.text.isNotEmpty
                            ? '${_getNouveauSolde().toStringAsFixed(2)} USD'
                            : '${_selectedClient?.solde.toStringAsFixed(2) ?? '0.00'} USD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _getNouveauSolde() >= 0 ? Colors.green : Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text(
                        'Type d\'opération:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'RETRAIT (0% commission)',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                          // Generate a preview of what the CodeOps will look like
                          '${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}0001',
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
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              minimumSize: Size(isMobile ? double.infinity : 120, isMobile ? 48 : 40),
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
                : Text(isMobile ? 'Confirmer' : 'Confirmer Retrait'),
          ),
        ],
      ),
    );
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
      
      // Créer l'opération de retrait
      final operation = OperationModel(
        codeOps: '', // Sera généré automatiquement par createOperation
        type: OperationType.retrait,
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
        notes: 'Retrait du compte client',
        observation: _observationController.text.isNotEmpty ? _observationController.text : null,
      );

      // Créer l'opération (cela mettra à jour automatiquement les soldes)
      final savedOperation = await operationService.createOperation(operation);
      
      if (savedOperation != null && mounted) {
        // Fermer le dialog de retrait
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
          password: '',
          shopId: authService.currentUser!.shopId!,
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

  // Calculer le nouveau solde après retrait
  double _getNouveauSolde() {
    if (_selectedClient == null || _montantController.text.isEmpty) {
      return _selectedClient?.solde ?? 0.0;
    }
    final montant = double.tryParse(_montantController.text) ?? 0;
    return _selectedClient!.solde - montant;
  }
  
  // Validation: Toujours valide (découvert autorisé)
  bool _isValidAmount() {
    // DÉCOUVERT AUTORISÉ - toujours retourner true
    // Le client peut retirer même si son solde devient négatif
    return true;
  }
}
