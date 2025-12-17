import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/virtual_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/sim_service.dart';
import '../models/sim_model.dart';

/// Dialog pour créer une nouvelle transaction virtuelle (capture client)
class CreateVirtualTransactionDialog extends StatefulWidget {
  const CreateVirtualTransactionDialog({super.key});

  @override
  State<CreateVirtualTransactionDialog> createState() => _CreateVirtualTransactionDialogState();
}

class _CreateVirtualTransactionDialogState extends State<CreateVirtualTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();
  
  SimModel? _selectedSim;
  String _selectedDevise = 'USD'; // Par défaut USD
  bool _isLoading = false;
  bool _isLoadingSims = true;
  bool _isDisposed = false; // Track disposal state

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed && mounted) {
        _loadSims();
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _referenceController.dispose();
    _montantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSims() async {
    if (_isDisposed || !mounted) return;
    
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      debugPrint('🔄 [CreateVirtualTransactionDialog] Chargement SIMs...');
      debugPrint('   User shopId: ${currentUser?.shopId}');
      
      if (currentUser?.shopId != null) {
        await SimService.instance.loadSims(shopId: currentUser!.shopId);
        debugPrint('✅ [CreateVirtualTransactionDialog] SIMs chargées: ${SimService.instance.sims.length}');
        if (SimService.instance.sims.isNotEmpty) {
          for (var sim in SimService.instance.sims.take(3)) {
            debugPrint('   - ${sim.numero} (${sim.operateur}) - Shop: ${sim.shopId}, Statut: ${sim.statut.name}');
          }
        }
      }
      
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingSims = false);
      }
    } catch (e) {
      debugPrint('❌ [CreateVirtualTransactionDialog] Erreur chargement SIMs: $e');
      
      if (!_isDisposed && mounted) {
        setState(() => _isLoadingSims = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur chargement SIMs: $e'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Réessayer',
              textColor: Colors.white,
              onPressed: () {
                setState(() => _isLoadingSims = true);
                _loadSims();
              },
            ),
          ),
        );
      }
    }
  }



  Future<void> _submit() async {
    if (_isDisposed || !mounted) return;
    
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSim == null) {
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Veuillez sélectionner une SIM'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    // Vérifier l'unicité de la référence
    final reference = _referenceController.text.trim();
    final vtService = Provider.of<VirtualTransactionService>(context, listen: false);
    final existingTransaction = vtService.transactions.where((t) => t.reference == reference).firstOrNull;
    
    if (existingTransaction != null) {
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Cette référence existe déjà!\nRÉF: $reference déjà utilisée'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    if (!_isDisposed && mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final montantVirtuel = double.parse(_montantController.text);

      debugPrint('📦 [CreateVirtualTransaction] Création transaction...');
      debugPrint('   Référence: $reference');
      debugPrint('   Montant virtuel: $montantVirtuel ${_selectedDevise}');
      debugPrint('   Devise: $_selectedDevise');
      debugPrint('   SIM: ${_selectedSim!.numero}');
      debugPrint('   Shop ID: ${currentUser.shopId}');
      debugPrint('   Agent: ${currentUser.username}');
      
      // Afficher le montant cash qui sera donné (toujours en USD)
      if (_selectedDevise == 'CDF') {
        final montantUsd = montantVirtuel / 2500; // Estimation avec taux par défaut
        debugPrint('   💰 Cash à donner (estimation): \$${montantUsd.toStringAsFixed(2)} USD');
      } else {
        debugPrint('   💰 Cash à donner: \$${montantVirtuel.toStringAsFixed(2)} USD');
      }

      final transaction = await VirtualTransactionService.instance.createTransaction(
        reference: reference,
        montantVirtuel: montantVirtuel,
        frais: 0.0, // Frais = 0, commission saisie lors du service
        devise: _selectedDevise, // NOUVEAU: Devise sélectionnée
        simNumero: _selectedSim!.numero,
        shopId: currentUser.shopId!,
        shopDesignation: _selectedSim!.shopDesignation,
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      debugPrint('✅ [CreateVirtualTransaction] Résultat: ${transaction != null ? "SUCCÈS" : "ÉCHEC"}');
      if (transaction != null) {
        debugPrint('   Transaction créée - ID: ${transaction.id}, RÉF: ${transaction.reference}');
      } else {
        debugPrint('   Erreur: ${VirtualTransactionService.instance.errorMessage}');
      }

      if (!_isDisposed && mounted) {
        if (transaction != null) {
          debugPrint('🔄 [CreateVirtualTransaction] Rechargement des transactions...');
          // Recharger pour mettre à jour l'affichage
          await VirtualTransactionService.instance.loadTransactions(shopId: currentUser.shopId);
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Capture enregistrée!\nRÉF: ${transaction.reference}\nMontant: \$${transaction.montantVirtuel.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
          Navigator.pop(context, true);
        } else {
          final errorMsg = VirtualTransactionService.instance.errorMessage ?? 'Erreur inconnue';
          debugPrint('❌ [CreateVirtualTransaction] Affichage erreur: $errorMsg');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ $errorMsg'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ [CreateVirtualTransaction] Exception: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (!_isDisposed && mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_photo_alternate, color: Color(0xFF48bb78)),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Enregistrer Capture Client',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Référence
                  TextFormField(
                    controller: _referenceController,
                    decoration: const InputDecoration(
                      labelText: 'Référence *',
                      hintText: 'Ex: REF12345',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.qr_code),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La référence est requise';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // SIM
                  if (_isLoadingSims)
                    const LinearProgressIndicator()
                  else
                    Consumer<SimService>(
                      builder: (context, simService, child) {
                        final authService = Provider.of<AuthService>(context, listen: false);
                        final currentShopId = authService.currentUser?.shopId;
                        
                        final activeSims = simService.sims
                            .where((s) => s.shopId == currentShopId && s.statut == SimStatus.active)
                            .toList();

                        if (activeSims.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.orange[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.orange),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.warning, color: Colors.orange[700]),
                                    const SizedBox(width: 12),
                                    const Expanded(
                                      child: Text(
                                        'Aucune SIM active disponible',
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Veuillez créer une SIM dans "SIMs" (admin) avant de créer une transaction virtuelle.',
                                  style: TextStyle(fontSize: 12),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() => _isLoadingSims = true);
                                    _loadSims();
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Recharger les SIMs'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange[700],
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return DropdownButtonFormField<SimModel>(
                          value: _selectedSim,
                          decoration: const InputDecoration(
                            labelText: 'SIM *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.sim_card),
                          ),
                          items: activeSims.map((sim) {
                            return DropdownMenuItem(
                              value: sim,
                              child: Text('${sim.numero} (${sim.operateur})'),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => _selectedSim = value);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Veuillez sélectionner une SIM';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  
                  // Devise
                  DropdownButtonFormField<String>(
                    value: _selectedDevise,
                    decoration: const InputDecoration(
                      labelText: 'Devise *',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.currency_exchange),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'USD',
                        child: Text('USD (\$) - Dollar Américain'),
                      ),
                      DropdownMenuItem(
                        value: 'CDF',
                        child: Text('CDF (FC) - Franc Congolais'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() => _selectedDevise = value!);
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Montant
                  TextFormField(
                    controller: _montantController,
                    decoration: InputDecoration(
                      labelText: 'Montant Virtuel *',
                      hintText: _selectedDevise == 'CDF' ? '250000' : '100.00',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money),
                      suffixText: _selectedDevise == 'CDF' ? 'FC' : 'USD',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le montant est requis';
                      }
                      final montant = double.tryParse(value);
                      if (montant == null || montant <= 0) {
                        return 'Montant invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  
                  // Aperçu du cash à remettre (toujours en USD)
                  if (_montantController.text.isNotEmpty && double.tryParse(_montantController.text) != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.info_outline, color: Colors.green[700], size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Cash à remettre au client:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Builder(
                            builder: (context) {
                              final montant = double.tryParse(_montantController.text) ?? 0;
                              if (_selectedDevise == 'CDF') {
                                final cashUsd = montant / 2500; // Estimation avec taux par défaut
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${montant.toStringAsFixed(0)} CDF → \$${cashUsd.toStringAsFixed(2)} USD'),
                                    Text(
                                      '(Conversion automatique selon le taux)',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                );
                              } else {
                                return Text(
                                  '\$${montant.toStringAsFixed(2)} USD',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  
                  // Notes
                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      hintText: 'Informations supplémentaires...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.note),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 15),
                  
                  // Boutons
                  Consumer<SimService>(
                    builder: (context, simService, child) {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final currentShopId = authService.currentUser?.shopId;
                      final hasActiveSims = simService.sims
                          .any((s) => s.shopId == currentShopId && s.statut == SimStatus.active);
                      
                      return Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('Annuler'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: (_isLoading || !hasActiveSims) ? null : _submit,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF48bb78),
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Save'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
