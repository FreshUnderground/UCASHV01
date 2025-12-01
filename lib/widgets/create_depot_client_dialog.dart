import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/depot_client_model.dart';
import '../models/sim_model.dart';
import '../services/auth_service.dart';
import '../services/sim_service.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';

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
      
      // Déclencher la synchronisation en arrière-plan
      _syncInBackground(userId.toString());
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
  
  /// Synchronisation en arrière-plan (non bloquante)
  void _syncInBackground(String userId) {
    Future.delayed(const Duration(milliseconds: 500), () async {
      try {
        debugPrint('🔄 [DEPOT CLIENT] Déclenchement sync en arrière-plan...');
        final syncService = SyncService();
        await syncService.uploadTableData('depot_clients', userId);
        debugPrint('✅ [DEPOT CLIENT] Synchronisation terminée');
      } catch (e) {
        debugPrint('❌ [DEPOT CLIENT] Erreur sync: $e');
        // Ne pas bloquer l'utilisateur en cas d'erreur
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SingleChildScrollView(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête simple
                Text(
                  widget.depotToEdit != null ? 'Éditer le Dépôt Client' : 'Nouveau Dépôt Client',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Cash reçu → Virtuel envoyé',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SIM',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<SimModel>(
                          value: _selectedSim,
                          decoration: InputDecoration(
                            hintText: 'Sélectionner la SIM',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          isExpanded: true,
                          items: sims.map((sim) {
                            return DropdownMenuItem(
                              value: sim,
                              child: Text(
                                '${sim.numero} (${sim.operateur}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: widget.depotToEdit != null ? null : (sim) {
                            setState(() => _selectedSim = sim);
                          },
                          validator: (value) {
                            if (value == null) return 'Veuillez sélectionner une SIM';
                            return null;
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Montant
                const Text(
                  'Montant (USD)',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _montantController,
                  decoration: InputDecoration(
                    hintText: '0.00',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    prefixText: r'$ ',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    return null;
                  },
                  onChanged: (value) {
                    _formKey.currentState?.validate();
                  },
                ),
                const SizedBox(height: 20),

                // Numéro de téléphone
                const Text(
                  'Téléphone Client',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _telephoneController,
                  decoration: InputDecoration(
                    hintText: '+243...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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


                // Boutons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isLoading ? null : _enregistrerDepot,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF48bb78),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
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
                          : Text(widget.depotToEdit != null ? 'Modifier' : 'Enregistrer'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
