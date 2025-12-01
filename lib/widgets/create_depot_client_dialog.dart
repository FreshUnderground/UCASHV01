import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/depot_client_model.dart';
import '../models/sim_model.dart';
import '../services/auth_service.dart';
import '../services/sim_service.dart';
import '../services/local_db.dart';

class CreateDepotClientDialog extends StatefulWidget {
  final DepotClientModel? depotToEdit;
  
  const CreateDepotClientDialog({super.key, this.depotToEdit});

  @override
  State<CreateDepotClientDialog> createState() => _CreateDepotClientDialogState();
}

class _CreateDepotClientDialogState extends State<CreateDepotClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _telephoneController = TextEditingController();
  
  SimModel? _selectedSim;
  bool _isLoading = false;
  double? _montantOriginal; // Pour édition: montant d'origine

  @override
  void initState() {
    super.initState();
    // Si en mode édition, pré-remplir les champs
    if (widget.depotToEdit != null) {
      _montantController.text = widget.depotToEdit!.montant.toString();
      _telephoneController.text = widget.depotToEdit!.telephoneClient;
      _montantOriginal = widget.depotToEdit!.montant;
      // Note: _selectedSim sera défini dans le build via Consumer
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _telephoneController.dispose();
    super.dispose();
  }

  Future<void> _enregistrerDepot() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une SIM')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = authService.currentUser?.shopId;
      final userId = authService.currentUser?.id;

      if (shopId == null || userId == null) {
        throw Exception('Shop ID ou User ID non disponible');
      }

      final montant = double.parse(_montantController.text);
      final telephone = _telephoneController.text.trim();
      
      final isEditing = widget.depotToEdit != null;

      // En mode édition, calculer la différence de montant
      if (isEditing) {
        final diff = montant - _montantOriginal!;
        
        // Vérifier que la SIM a assez de solde pour la différence
        if (diff > 0 && _selectedSim!.soldeActuel < diff) {
          throw Exception('Solde virtuel insuffisant pour cette modification');
        }
        
        // Mettre à jour le dépôt
        final depotUpdated = widget.depotToEdit!.copyWith(
          montant: montant,
          telephoneClient: telephone,
        );
        
        await LocalDB.instance.updateDepotClient(depotUpdated);
        
        // Ajuster le solde SIM selon la différence
        if (diff != 0) {
          final nouveauSolde = _selectedSim!.soldeActuel - diff;
          await LocalDB.instance.updateSimSolde(
            _selectedSim!.numero,
            nouveauSolde,
          );
        }
        
        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dépôt modifié: \$${montant.toStringAsFixed(2)}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        // Mode création
        // Vérifier que la SIM a assez de solde virtuel
        if (_selectedSim!.soldeActuel < montant) {
          throw Exception('Solde virtuel insuffisant sur cette SIM');
        }

        // Créer le modèle de dépôt
        final depot = DepotClientModel(
          shopId: shopId,
          simNumero: _selectedSim!.numero,
          montant: montant,
          telephoneClient: telephone,
          dateDepot: DateTime.now(),
          userId: userId,
        );

        // Enregistrer le dépôt
        await LocalDB.instance.insertDepotClient(depot);

        // Mettre à jour le solde de la SIM (diminuer le virtuel)
        final nouveauSolde = _selectedSim!.soldeActuel - montant;
        await LocalDB.instance.updateSimSolde(
          _selectedSim!.numero,
          nouveauSolde,
        );

        if (mounted) {
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Dépôt de \$${montant.toStringAsFixed(2)} enregistré avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      // Recharger les SIMs
      await SimService.instance.loadSims(shopId: shopId);
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF48bb78).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance,
                      color: Color(0xFF48bb78),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.depotToEdit != null ? 'Éditer le Dépôt Client' : 'Dépôt Client',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Cash reçu → Virtuel envoyé',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Sélection de la SIM
              Consumer<SimService>(
                builder: (context, simService, child) {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final shopId = authService.currentUser?.shopId;
                  final sims = shopId != null
                      ? simService.sims.where((s) => s.shopId == shopId).toList()
                      : simService.sims;

                  // En mode édition, définir la SIM sélectionnée si pas encore définie
                  if (widget.depotToEdit != null && _selectedSim == null) {
                    _selectedSim = sims.where((s) => s.numero == widget.depotToEdit!.simNumero).firstOrNull;
                  }

                  return DropdownButtonFormField<SimModel>(
                    value: _selectedSim,
                    decoration: InputDecoration(
                      labelText: 'Sélectionner la SIM',
                      prefixIcon: const Icon(Icons.sim_card, color: Color(0xFF48bb78)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: sims.map((sim) {
                      return DropdownMenuItem(
                        value: sim,
                        child: Row(
                          children: [
                            Text(
                              sim.numero,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${sim.operateur})',
                              style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            ),
                            const Spacer(),
                            Text(
                              '\$${sim.soldeActuel.toStringAsFixed(2)}',
                              style: TextStyle(
                                color: sim.soldeActuel > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: widget.depotToEdit != null ? null : (sim) { // Désactiver en mode édition
                      setState(() => _selectedSim = sim);
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
              TextFormField(
                controller: _montantController,
                decoration: InputDecoration(
                  labelText: 'Montant (USD)',
                  prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF48bb78)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: '0.00',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le montant';
                  }
                  final montant = double.tryParse(value);
                  if (montant == null || montant <= 0) {
                    return 'Montant invalide';
                  }
                  if (_selectedSim != null && montant > _selectedSim!.soldeActuel) {
                    return 'Solde virtuel insuffisant';
                  }
                  return null;
                },
                onChanged: (value) {
                  // Revalider quand le montant change
                  _formKey.currentState?.validate();
                },
              ),
              const SizedBox(height: 16),

              // Numéro de téléphone
              TextFormField(
                controller: _telephoneController,
                decoration: InputDecoration(
                  labelText: 'Numéro de téléphone du client',
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFF48bb78)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                  hintText: '+243...',
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                ],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer le numéro de téléphone';
                  }
                  if (value.length < 10) {
                    return 'Numéro de téléphone invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Info box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Le dépôt va diminuer le virtuel de la SIM et augmenter le cash disponible',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Boutons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _enregistrerDepot,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading 
                        ? (widget.depotToEdit != null ? 'Modification...' : 'Enregistrement...') 
                        : (widget.depotToEdit != null ? 'Modifier' : 'Enregistrer')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF48bb78),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
}
