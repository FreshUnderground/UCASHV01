import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/sim_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../models/sim_model.dart';
import '../models/shop_model.dart';
import '../models/retrait_virtuel_model.dart';

/// Dialog pour créer un retrait virtuel (diminue le solde de la SIM)
class CreateRetraitVirtuelDialog extends StatefulWidget {
  const CreateRetraitVirtuelDialog({super.key});

  @override
  State<CreateRetraitVirtuelDialog> createState() => _CreateRetraitVirtuelDialogState();
}

class _CreateRetraitVirtuelDialogState extends State<CreateRetraitVirtuelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();
  
  SimModel? _selectedSim;
  ShopModel? _shopDestinataire; // Shop qui devra nous rembourser
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedSim == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez sélectionner une SIM'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    if (_shopDestinataire == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Veuillez sélectionner le shop débiteur'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final montant = double.parse(_montantController.text);

    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Voulez-vous confirmer ce retrait virtuel?'),
            const SizedBox(height: 16),
            Text('SIM: ${_selectedSim!.numero} (${_selectedSim!.operateur})', 
              style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('Solde actuel: \$${_selectedSim!.soldeActuel.toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            Text('Montant du retrait: \$${montant.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
            Text('Nouveau solde: \$${(_selectedSim!.soldeActuel - montant).toStringAsFixed(2)}'),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Text('${_shopDestinataire!.designation} vous devra:', 
              style: const TextStyle(fontWeight: FontWeight.w600)),
            Text('\$${montant.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.green)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Confirmer Retrait'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Calculer le nouveau solde (pour le tracking, même si on recalculera automatiquement)
      final nouveauSolde = _selectedSim!.soldeActuel - montant;
      
      debugPrint('💰 [Flot] AVANT:');
      debugPrint('   SIM: ${_selectedSim!.numero}');
      debugPrint('   Solde actuel: ${_selectedSim!.soldeActuel}');
      debugPrint('   Montant retrait: $montant');
      debugPrint('   Nouveau solde (calculé): $nouveauSolde');
      
      // Obtenir la désignation du shop source
      final shopService = Provider.of<ShopService>(context, listen: false);
      final currentShop = shopService.shops.firstWhere(
        (shop) => shop.id == currentUser.shopId,
        orElse: () => ShopModel(designation: 'Shop', localisation: ''),
      );

      // Créer l'enregistrement du retrait virtuel
      final retrait = RetraitVirtuelModel(
        simNumero: _selectedSim!.numero,
        simOperateur: _selectedSim!.operateur,
        shopSourceId: currentUser.shopId ?? 0,
        shopSourceDesignation: currentShop.designation,
        shopDebiteurId: _shopDestinataire!.id!,
        shopDebiteurDesignation: _shopDestinataire!.designation,
        montant: montant,
        soldeAvant: _selectedSim!.soldeActuel,
        soldeApres: nouveauSolde,  // Note: Ce sera recalculé automatiquement après
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        statut: RetraitVirtuelStatus.enAttente,
        dateRetrait: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );

      await LocalDB.instance.saveRetraitVirtuel(retrait);
      debugPrint('✅ Flot sauvegardé: ID=${retrait.id}');
      
      // IMPORTANT: Recalculer le solde automatiquement basé sur toutes les captures et retraits
      final wasUpdated = await SimService.instance.updateSoldeAutomatiquement(_selectedSim!);
      if (wasUpdated) {
        debugPrint('✅ Solde de la SIM ${_selectedSim!.numero} recalculé automatiquement');
      } else {
        debugPrint('ℹ️ Solde de la SIM ${_selectedSim!.numero} déjà à jour');
      }
      
      // Vérifier le solde après recalcul
      final simApres = await LocalDB.instance.getSimByNumero(_selectedSim!.numero);
      if (simApres != null) {
        debugPrint('💰 [Flot] APRÈS:');
        debugPrint('   Solde dans BD: ${simApres.soldeActuel}');
      }
      
      // CRITICAL: Attendre que le service notifie tous les listeners
      await Future.delayed(const Duration(milliseconds: 100));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Flot effectué!\n'
              'Montant: \$${montant.toStringAsFixed(2)}\n'
              '${_shopDestinataire!.designation} vous doit cet argent.\n'
              'Un flot devra être créé pour le remboursement.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 6),
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
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
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.remove_circle, color: Colors.orange, size: 32),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Flot',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Sélection de la SIM
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
                          child: const Text(
                            'Aucune SIM active disponible',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }
                      
                      // IMPORTANT: Si la SIM sélectionnée existe dans la nouvelle liste, mettre à jour sa référence
                      if (_selectedSim != null) {
                        final updatedSim = activeSims.firstWhere(
                          (s) => s.numero == _selectedSim!.numero,
                          orElse: () => _selectedSim!,
                        );
                        // Mettre à jour si le solde a changé
                        if (updatedSim.soldeActuel != _selectedSim!.soldeActuel) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (mounted) {
                              setState(() {
                                _selectedSim = updatedSim;
                              });
                            }
                          });
                        }
                      }

                      return DropdownButtonFormField<SimModel>(
                        value: _selectedSim,
                        decoration: const InputDecoration(
                          labelText: 'SIM à débiter *',
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
                    decoration: const InputDecoration(
                      labelText: 'Montant du retrait *',
                      hintText: '100.00',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.attach_money),
                      suffixText: 'USD',
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
                  const SizedBox(height: 16),
                  
                  // Shop destinataire (qui devra rembourser)
                  Consumer<ShopService>(
                    builder: (context, shopService, child) {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final currentShopId = authService.currentUser?.shopId;
                      
                      final otherShops = shopService.shops
                          .where((s) => s.id != currentShopId)
                          .toList();

                      if (otherShops.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.orange),
                          ),
                          child: const Text(
                            'Aucun autre shop disponible',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        );
                      }

                      return DropdownButtonFormField<ShopModel>(
                        value: _shopDestinataire,
                        decoration: const InputDecoration(
                          labelText: 'Shop débiteur (qui vous devra) *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.store),
                        ),
                        items: otherShops.map((shop) {
                          return DropdownMenuItem(
                            value: shop,
                            child: Text(shop.designation),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _shopDestinataire = value);
                        },
                        validator: (value) {
                          if (value == null) return 'Veuillez sélectionner le shop débiteur';
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  
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
                  const SizedBox(height: 24),
                  
                  // Info
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Important',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text('• Le solde de la SIM sera diminué'),
                        const SizedBox(height: 4),
                        const Text('• Le shop sélectionné vous devra cet argent'),
                        const SizedBox(height: 4),
                        const Text('• Il devra créer un FLOT pour vous rembourser'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Boutons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Annuler'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
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
                              : const Text('Effectuer Retrait'),
                        ),
                      ),
                    ],
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
