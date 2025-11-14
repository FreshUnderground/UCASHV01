import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/transaction_service.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';
import '../services/rates_service.dart';
import '../models/client_model.dart';
import 'responsive_form_dialog.dart';
import 'responsive_card.dart';

class CreateTransactionDialogResponsive extends StatefulWidget {
  final ClientModel? preselectedClient;

  const CreateTransactionDialogResponsive({
    super.key,
    this.preselectedClient,
  });

  @override
  State<CreateTransactionDialogResponsive> createState() => _CreateTransactionDialogResponsiveState();
}

class _CreateTransactionDialogResponsiveState extends State<CreateTransactionDialogResponsive> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _nomDestinataireController = TextEditingController();
  final _telephoneDestinataireController = TextEditingController();
  final _adresseDestinataireController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _selectedType = 'ENVOI';
  String _deviseSource = 'USD';
  String _deviseDestination = 'CDF';
  ClientModel? _selectedClient;
  bool _isLoading = false;
  
  // Calculs automatiques
  double _montantConverti = 0.0;
  double _tauxChange = 1.0; // Sera chargé depuis RatesService
  double _commission = 0.0;
  double _montantTotal = 0.0;

  final List<String> _types = ['ENVOI', 'RECEPTION', 'DEPOT', 'RETRAIT'];
  final List<String> _devises = ['USD', 'EUR', 'CDF', 'GBP', 'CAD'];

  @override
  void initState() {
    super.initState();
    _selectedClient = widget.preselectedClient;
    _loadClients();
    _loadRatesAndCommissions(); // Charger les taux réels
    _calculateAmounts();
    
    // Listener pour recalculer automatiquement
    _montantController.addListener(_calculateAmounts);
  }

  void _loadClients() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.shopId != null) {
      // Charger TOUS les clients (globaux - accessible depuis tous les shops)
      Provider.of<ClientService>(context, listen: false).loadClients();
    }
  }
  
  Future<void> _loadRatesAndCommissions() async {
    await RatesService.instance.loadRatesAndCommissions();
    if (mounted) {
      setState(() {
        _calculateAmounts(); // Recalculer avec les vrais taux
      });
    }
  }

  void _calculateAmounts() {
    final montant = double.tryParse(_montantController.text) ?? 0.0;
    final ratesService = RatesService.instance;
    
    // Calculer le taux selon les devises - UTILISER LES VRAIS TAUX
    if (_deviseSource == _deviseDestination) {
      _tauxChange = 1.0;
      _montantConverti = montant;
    } else {
      // Déterminer le type de taux selon le type de transaction
      String typeTaux;
      if (_selectedType == 'ENVOI') {
        typeTaux = 'INTERNATIONAL_SORTANT'; // Taux sortant (plus élevé)
      } else if (_selectedType == 'RECEPTION') {
        typeTaux = 'INTERNATIONAL_ENTRANT'; // Taux entrant
      } else {
        typeTaux = 'NATIONAL'; // Pour dépôts/retraits
      }
      
      // Récupérer le taux réel depuis RatesService (par deviseCible et type)
      final tauxData = ratesService.getTauxByDeviseAndType(_deviseDestination, typeTaux);
      
      if (tauxData != null) {
        _tauxChange = tauxData.taux;
        debugPrint('✅ Taux récupéré: $_deviseSource -> $_deviseDestination = $_tauxChange (type: $typeTaux)');
      } else {
        // PAS DE FALLBACK - Afficher erreur
        _tauxChange = 0.0;
        debugPrint('❌ ERREUR: Taux $typeTaux non trouvé pour $_deviseDestination dans la base de données!');
      }
      
      _montantConverti = montant * _tauxChange;
    }
    
    // Calculer la commission - UTILISER LA VRAIE COMMISSION
    if (_selectedType == 'ENVOI') {
      final commissionData = ratesService.getCommissionByType('SORTANT');
      if (commissionData != null) {
        _commission = montant * (commissionData.taux / 100);
        debugPrint('✅ Commission récupérée: ${commissionData.taux}% = $_commission');
      } else {
        // PAS DE FALLBACK - Erreur
        _commission = 0.0;
        debugPrint('❌ ERREUR: Commission SORTANT non trouvée dans la base de données!');
      }
    } else if (_selectedType == 'RECEPTION') {
      final commissionData = ratesService.getCommissionByType('ENTRANT');
      if (commissionData != null) {
        _commission = montant * (commissionData.taux / 100);
        debugPrint('✅ Commission récupérée: ${commissionData.taux}% = $_commission');
      } else {
        // PAS DE FALLBACK - Erreur  
        _commission = 0.0;
        debugPrint('❌ ERREUR: Commission ENTRANT non trouvée dans la base de données!');
      }
    } else {
      _commission = 0.0; // Gratuit pour dépôts/retraits
    }
    
    // Calculer le montant total
    _montantTotal = montant + _commission;
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _nomDestinataireController.dispose();
    _telephoneDestinataireController.dispose();
    _adresseDestinataireController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormDialog(
      title: 'Nouvelle Transaction',
      titleIcon: Icons.add_circle,
      maxWidth: context.isDesktop ? 700 : null,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Type de transaction
            ResponsiveDropdownField<String>(
              label: 'Type de Transaction',
              value: _selectedType,
              items: _types.map((type) => DropdownMenuItem(
                value: type,
                child: Text(_getTypeLabel(type)),
              )).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedType = value!;
                  _calculateAmounts();
                });
              },
            ),
            
            // Sélection du client
            Consumer<ClientService>(
              builder: (context, clientService, child) {
                if (clientService.clients.isEmpty) {
                  return ResponsiveCard(
                    backgroundColor: Colors.orange[50],
                    child: Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Aucun client disponible. Créez d\'abord des clients.',
                            style: TextStyle(color: Colors.orange[700]),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                return ResponsiveDropdownField<ClientModel>(
                  label: 'Client Expéditeur',
                  value: _selectedClient,
                  items: clientService.clients.map((client) => DropdownMenuItem(
                    value: client,
                    child: Text('${client.nom} (${client.telephone})'),
                  )).toList(),
                  onChanged: (client) {
                    setState(() {
                      _selectedClient = client;
                    });
                  },
                  validator: (value) => value == null ? 'Sélectionnez un client' : null,
                );
              },
            ),
            
            // Montant
            ResponsiveFormField(
              label: 'Montant ($_deviseSource)',
              controller: _montantController,
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Saisissez le montant';
                }
                final amount = double.tryParse(value);
                if (amount == null || amount <= 0) {
                  return 'Montant invalide';
                }
                return null;
              },
            ),
            
            // Devises
            ResponsiveGrid(
              forceColumns: context.isMobile ? 1 : 2,
              children: [
                ResponsiveDropdownField<String>(
                  label: 'Devise Source',
                  value: _deviseSource,
                  items: _devises.map((devise) => DropdownMenuItem(
                    value: devise,
                    child: Text(devise),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _deviseSource = value!;
                      _calculateAmounts();
                    });
                  },
                ),
                ResponsiveDropdownField<String>(
                  label: 'Devise Destination',
                  value: _deviseDestination,
                  items: _devises.map((devise) => DropdownMenuItem(
                    value: devise,
                    child: Text(devise),
                  )).toList(),
                  onChanged: (value) {
                    setState(() {
                      _deviseDestination = value!;
                      _calculateAmounts();
                    });
                  },
                ),
              ],
            ),
            
            // Informations destinataire (pour envois)
            if (_selectedType == 'ENVOI') ...[
              const SizedBox(height: 16),
              Text(
                'Informations du Destinataire',
                style: TextStyle(
                  fontSize: context.isMobile ? 16 : 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(height: 16),
              ResponsiveFormField(
                label: 'Nom Complet',
                controller: _nomDestinataireController,
                validator: (value) => value?.isEmpty == true ? 'Nom requis' : null,
              ),
              ResponsiveGrid(
                forceColumns: context.isMobile ? 1 : 2,
                children: [
                  ResponsiveFormField(
                    label: 'Téléphone',
                    controller: _telephoneDestinataireController,
                    keyboardType: TextInputType.phone,
                    validator: (value) => value?.isEmpty == true ? 'Téléphone requis' : null,
                  ),
                  ResponsiveFormField(
                    label: 'Adresse',
                    controller: _adresseDestinataireController,
                  ),
                ],
              ),
            ],
            
            // Notes
            ResponsiveFormField(
              label: 'Notes (optionnel)',
              controller: _notesController,
              maxLines: 3,
            ),
            
            // Résumé des calculs
            ResponsiveCard(
              backgroundColor: Colors.grey[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résumé de la Transaction',
                    style: TextStyle(
                      fontSize: context.isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSummaryRow('Type', _getTypeLabel(_selectedType)),
                  _buildSummaryRow('Montant', '${_montantController.text} $_deviseSource'),
                  if (_deviseSource != _deviseDestination)
                    _buildSummaryRow('Taux de change', '1 $_deviseSource = ${_tauxChange.toStringAsFixed(2)} $_deviseDestination'),
                  if (_montantConverti != double.tryParse(_montantController.text))
                    _buildSummaryRow('Montant converti', '${_montantConverti.toStringAsFixed(2)} $_deviseDestination'),
                  _buildSummaryRow('Commission', '${_commission.toStringAsFixed(2)} $_deviseSource'),
                  const Divider(),
                  _buildSummaryRow(
                    'Total à payer',
                    '${_montantTotal.toStringAsFixed(2)} $_deviseSource',
                    isTotal: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ResponsiveActionButtons(
          onCancel: () => Navigator.of(context).pop(),
          onSave: _isLoading ? null : _handleSubmit,
          isLoading: _isLoading,
          saveText: 'Créer Transaction',
          saveEnabled: _selectedClient != null,
        ),
      ],
    );
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'ENVOI':
        return 'Envoi de fonds';
      case 'RECEPTION':
        return 'Réception de fonds';
      case 'DEPOT':
        return 'Dépôt en compte';
      case 'RETRAIT':
        return 'Retrait de compte';
      default:
        return type;
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? const Color(0xFFDC2626) : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              fontSize: isTotal ? 16 : 14,
              color: isTotal ? const Color(0xFFDC2626) : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final transactionService = Provider.of<TransactionService>(context, listen: false);
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser?.id == null || currentUser?.shopId == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Créer la transaction selon le type
      final success = await transactionService.createTransaction(
        type: _selectedType,
        montant: double.parse(_montantController.text),
        deviseSource: _deviseSource,
        deviseDestination: _deviseDestination,
        expediteurId: _selectedClient!.id!,
        nomDestinataire: _nomDestinataireController.text.trim().isEmpty ? null : _nomDestinataireController.text.trim(),
        telephoneDestinataire: _telephoneDestinataireController.text.trim().isEmpty ? null : _telephoneDestinataireController.text.trim(),
        adresseDestinataire: _adresseDestinataireController.text.trim().isEmpty ? null : _adresseDestinataireController.text.trim(),
        agentId: currentUser!.id!,
        shopId: currentUser.shopId!,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!success) {
        throw Exception(transactionService.errorMessage ?? 'Erreur lors de la création de la transaction');
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction créée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
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
        setState(() => _isLoading = false);
      }
    }
  }
}
