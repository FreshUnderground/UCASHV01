import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/sim_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../models/operation_model.dart';
import '../models/sim_model.dart';

/// Dialog pour créer une nouvelle opération de retrait Mobile Money
class CreateRetraitDialog extends StatefulWidget {
  const CreateRetraitDialog({super.key});

  @override
  State<CreateRetraitDialog> createState() => _CreateRetraitDialogState();
}

class _CreateRetraitDialogState extends State<CreateRetraitDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _montantController = TextEditingController();
  final _codeTransactionController = TextEditingController();
  // Note: clientNom, clientTel et notes seront complétés lors du service de l'opération
  
  // Selected values
  SimModel? _selectedSim;
  // L'opérateur est automatiquement déduit de la SIM sélectionnée
  
  bool _isLoading = false;
  bool _isLoadingSims = true;

  @override
  void initState() {
    super.initState();
    _loadSims();
  }

  Future<void> _loadSims() async {
    try {
      final simService = Provider.of<SimService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      // IMPORTANT: Charger UNIQUEMENT les SIMs du shop de l'agent
      // Seuls les agents du même shop que la SIM peuvent faire des transactions
      if (currentUser?.shopId != null) {
        await simService.loadSims(shopId: currentUser!.shopId);
      } else {
        // Si pas de shopId (cas admin?), charger toutes les SIMs
        await simService.loadSims();
      }
      
      final activeSims = simService.sims.where((s) => s.statut == SimStatus.active).toList();
      debugPrint('✅ SIMs chargées pour création retrait:');
      debugPrint('   Shop ID utilisateur: ${currentUser?.shopId}');
      debugPrint('   Total SIMs: ${simService.sims.length}');
      debugPrint('   SIMs actives: ${activeSims.length}');
      if (simService.sims.isNotEmpty) {
        for (var sim in simService.sims) {
          debugPrint('   - ${sim.numero} (${sim.operateur}) - Shop: ${sim.shopId} - Statut: ${sim.statut.name}');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Erreur chargement SIMs: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoadingSims = false);
      }
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _codeTransactionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.add_circle, color: Colors.orange[700], size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Créer Opération Retrait',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Enregistrer un retrait - Infos client ajoutées lors du service',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // Form fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sélection SIM
                      _buildSectionTitle('Numéro SIM'),
                      if (_isLoadingSims)
                        const Card(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                                SizedBox(width: 12),
                                Text('Chargement des SIMs...'),
                              ],
                            ),
                          ),
                        )
                      else
                        Consumer<SimService>(
                        builder: (context, simService, child) {
                          final sims = simService.sims
                              .where((s) => s.statut == SimStatus.active)
                              .toList();
                          
                          if (sims.isEmpty) {
                            return Card(
                              color: Colors.orange[50],
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.warning, color: Colors.orange[700]),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Aucune SIM active disponible',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Veuillez créer une SIM dans "Configuration > Gestion des SIMs" avant de créer une opération.',
                                      style: TextStyle(fontSize: 13),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _isLoadingSims = true;
                                          });
                                          _loadSims();
                                        },
                                        icon: const Icon(Icons.refresh, size: 16),
                                        label: const Text('Recharger les SIMs'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.orange[700],
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }
                          
                          return DropdownButtonFormField<SimModel>(
                            value: _selectedSim,
                            decoration: const InputDecoration(
                              labelText: 'Sélectionner la SIM',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.sim_card),
                            ),
                            items: sims.map((sim) {
                              return DropdownMenuItem(
                                value: sim,
                                child: Text('${sim.numero} (${sim.operateur})'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setState(() {
                                _selectedSim = value;
                                // L'opérateur est automatiquement déduit de la SIM
                              });
                            },
                            validator: (value) {
                              if (value == null) return 'Veuillez sélectionner une SIM';
                              return null;
                            },
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Montant
                      _buildSectionTitle('Montant du Retrait'),
                      TextFormField(
                        controller: _montantController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'Montant',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'USD',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer le montant';
                          }
                          final montant = double.tryParse(value);
                          if (montant == null || montant <= 0) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Code Transaction
                      _buildSectionTitle('REF'),
                      TextFormField(
                        controller: _codeTransactionController,
                        decoration: const InputDecoration(
                          labelText: 'REF',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.confirmation_number),
                          hintText: 'Ex: MP123456789',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Veuillez entrer la référence';
                          }
                          if (value.length < 5) {
                            return 'Référence trop courte';
                          }
                          // Note: Duplicate check will be done during submission
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              
              const Divider(height: 32),
              
              // Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _creerOperation,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check),
                    label: Text(_isLoading ? 'Création...' : 'Créer Opération'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[700],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
    );
  }

  Future<void> _creerOperation() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Vérifier si la référence existe déjà
      final reference = _codeTransactionController.text;
      await operationService.loadOperations();
      final existingOperation = operationService.operations
          .where((op) => op.reference == reference || op.codeOps == reference)
          .firstOrNull;
      
      if (existingOperation != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Cette référence existe déjà. Veuillez en utiliser une autre.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() => _isLoading = false);
        return;
      }
      
      final montant = double.parse(_montantController.text);
      final commission = _calculateCommission(montant);
      
      // Récupérer la désignation du shop
      String? shopDesignation;
      if (currentUser.shopId != null) {
        final shop = await LocalDB.instance.getShopById(currentUser.shopId!);
        shopDesignation = shop?.designation;
      }
      
      final operation = OperationModel(
        type: OperationType.retrait,
        montantBrut: montant,
        commission: commission,
        montantNet: montant - commission,
        devise: 'USD',
        // Les informations client seront complétées lors du service
        clientNom: null,
        destinataire: 'En attente',
        telephoneDestinataire: null,
        reference: _codeTransactionController.text,
        shopSourceId: currentUser.shopId,
        shopSourceDesignation: shopDesignation ?? 'Shop ${currentUser.shopId}',
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        codeOps: _codeTransactionController.text,
        simNumero: _selectedSim?.numero, // Lier l'opération à la SIM
        modePaiement: _getModePaiement(),
        statut: OperationStatus.enAttente,
        notes: null, // Notes ajoutées lors du service
        dateOp: DateTime.now(),
      );
      
      final created = await operationService.createOperation(operation);
      
      if (created != null && mounted) {
        Navigator.pop(context, created);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Opération créée: ${created.codeOps}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        // Check if it's a day closed error
        final errorMessage = e.toString();
        if (errorMessage.contains('clôturée')) {
          // Show a prominent alert dialog for day closed
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
              content: Text('❌ Erreur: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  double _calculateCommission(double montant) {
    // Calcul simple de commission - à adapter selon vos besoins
    if (montant < 50) return 1.0;
    if (montant < 100) return 2.0;
    if (montant < 500) return 5.0;
    return montant * 0.02; // 2%
  }

  ModePaiement _getModePaiement() {
    // Récupérer l'opérateur depuis la SIM sélectionnée
    final operateur = _selectedSim?.operateur ?? '';
    
    switch (operateur) {
      case 'Airtel':
      case 'Airtel Money':
        return ModePaiement.airtelMoney;
      case 'Vodacom':
      case 'M-PESA':
      case 'M-PROVIDER':
        return ModePaiement.mPesa;
      case 'Orange':
      case 'Orange Money':
        return ModePaiement.orangeMoney;
      default:
        return ModePaiement.cash;
    }
  }
}
