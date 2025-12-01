import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/flot_service.dart';
import '../services/auth_service.dart';
import '../models/operation_model.dart';

/// Dialog pour servir une opération de retrait Mobile Money par référence
/// Si la référence n'existe pas, crée d'abord le retrait avant de le servir
class ServirOperationParRefDialog extends StatefulWidget {
  const ServirOperationParRefDialog({super.key});

  @override
  State<ServirOperationParRefDialog> createState() => _ServirOperationParRefDialogState();
}

class _ServirOperationParRefDialogState extends State<ServirOperationParRefDialog> {
  bool _isLoading = false;
  final _referenceController = TextEditingController();
  final _montantController = TextEditingController();
  final _nomClientController = TextEditingController();
  final _telephoneClientController = TextEditingController();
  final _observationController = TextEditingController();
  final _tauxController = TextEditingController();
  bool _captureVerifiee = false;
  bool _montantVerifie = false;
  bool _numeroVerifie = false;
  double? _tauxCommission;
  double? _montantNetCalcule;
  double? _commissionCalculee;
  OperationModel? _existingOperation;

  @override
  void dispose() {
    _referenceController.dispose();
    _montantController.dispose();
    _nomClientController.dispose();
    _telephoneClientController.dispose();
    _observationController.dispose();
    _tauxController.dispose();
    super.dispose();
  }

  void _calculerMontants() {
    final montant = double.tryParse(_montantController.text);
    if (montant == null || _tauxCommission == null) {
      setState(() {
        _montantNetCalcule = null;
        _commissionCalculee = null;
      });
      return;
    }
    
    // Commission = Montant × (Taux / 100)
    _commissionCalculee = montant * (_tauxCommission! / 100);
    // Montant Net = Montant - Commission
    _montantNetCalcule = montant - _commissionCalculee!;
    
    setState(() {});
  }

  /// Rechercher une opération par référence
  Future<void> _rechercherOperation() async {
    if (_referenceController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez entrer une référence'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      await operationService.loadOperations(); // Recharger pour s'assurer d'avoir les dernières données
      
      // Rechercher l'opération par référence
      final operation = operationService.operations
          .where((op) => op.reference == _referenceController.text || op.codeOps == _referenceController.text)
          .firstOrNull;

      if (operation != null) {
        // Opération trouvée, la pré-remplir
        setState(() {
          _existingOperation = operation;
          _montantController.text = operation.montantBrut.toString();
          _nomClientController.text = operation.clientNom ?? operation.destinataire ?? '';
          _telephoneClientController.text = operation.telephoneDestinataire ?? '';
          
          // Si commission existe, calculer le taux
          if (operation.commission > 0 && operation.montantBrut > 0) {
            _tauxCommission = (operation.commission / operation.montantBrut) * 100;
            _tauxController.text = _tauxCommission!.toStringAsFixed(2);
            _calculerMontants();
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opération trouvée! Veuillez compléter les informations.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Opération non trouvée, préparer la création
        setState(() {
          _existingOperation = null;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opération non trouvée. Veuillez entrer les détails pour créer le retrait.'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la recherche: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Créer un retrait et le servir
  Future<void> _creerEtServirRetrait() async {
    if (_referenceController.text.isEmpty || 
        _montantController.text.isEmpty || 
        _nomClientController.text.isEmpty || 
        _telephoneClientController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez remplir tous les champs obligatoires'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final montant = double.parse(_montantController.text);
      final commission = _commissionCalculee ?? _calculateCommission(montant);

      // Créer l'opération de retrait
      final operation = OperationModel(
        type: OperationType.retrait,
        montantBrut: montant,
        commission: commission,
        montantNet: montant - commission,
        devise: 'USD',
        clientNom: _nomClientController.text,
        destinataire: _nomClientController.text,
        telephoneDestinataire: _telephoneClientController.text,
        reference: _referenceController.text,
        shopSourceId: currentUser.shopId,
        shopSourceDesignation: 'Shop ${currentUser.shopId}',
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        codeOps: _referenceController.text,
        modePaiement: ModePaiement.cash, // Par défaut, peut être modifié
        statut: OperationStatus.enAttente,
        notes: _observationController.text.isEmpty ? null : _observationController.text,
        dateOp: DateTime.now(),
      );

      // Créer l'opération
      final createdOperation = await operationService.createOperation(operation);
      
      if (createdOperation != null) {
        // Marquer comme servie immédiatement
        final updatedOperation = createdOperation.copyWith(
          statut: OperationStatus.terminee,
          // dateValidation: DateTime.now(), // Champ n'existe plus dans OperationModel
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: currentUser.username,
        );
        
        final success = await operationService.updateOperation(updatedOperation);
        
        if (success) {
          // Créer la dette (flot) si nécessaire
          final flotService = FlotService.instance;
          const shopCentralId = 1; // TODO: Récupérer l'ID du shop central depuis la config
          
          await flotService.createFlot(
            shopSourceId: updatedOperation.shopSourceId!,
            shopSourceDesignation: updatedOperation.shopSourceDesignation ?? 'Shop Source',
            shopDestinationId: shopCentralId,
            shopDestinationDesignation: 'SHOP C',
            montant: updatedOperation.montantNet,
            devise: updatedOperation.devise,
            modePaiement: updatedOperation.modePaiement,
            agentEnvoyeurId: currentUser.id!,
            agentEnvoyeurUsername: currentUser.username,
            notes: 'Dette retrait Mobile Money - Réf: ${updatedOperation.codeOps}',
          );
          
          if (context.mounted) {
            Navigator.pop(context, true);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('✅ Retrait créé et servi: ${updatedOperation.codeOps}'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          throw Exception('Échec de la mise à jour de l\'opération');
        }
      } else {
        throw Exception('Échec de la création du retrait');
      }
    } catch (e) {
      if (context.mounted) {
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
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Servir une opération existante
  Future<void> _servirOperationExistante() async {
    if (_existingOperation == null) return;
    
    if (!_captureVerifiee || !_montantVerifie || !_numeroVerifie || 
        _montantNetCalcule == null || _commissionCalculee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez cocher toutes les vérifications et saisir le taux'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      // Marquer l'opération comme SERVIE avec les montants recalculés
      final updatedOperation = _existingOperation!.copyWith(
        statut: OperationStatus.terminee,
        commission: _commissionCalculee!, // Commission recalculée
        montantNet: _montantNetCalcule!,   // Montant net recalculé
        observation: _observationController.text.isEmpty ? null : _observationController.text,
        clientNom: _nomClientController.text.isEmpty ? _existingOperation!.clientNom : _nomClientController.text,
        telephoneDestinataire: _telephoneClientController.text.isEmpty ? _existingOperation!.telephoneDestinataire : _telephoneClientController.text,
        // dateValidation: DateTime.now(), // Champ n'existe plus dans OperationModel
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );

      final success = await operationService.updateOperation(updatedOperation);

      if (!success) {
        throw Exception('Échec de la mise à jour de l\'opération');
      }

      // Créer la dette entre shop de la SIM et SHOP CENTRAL (SHOP C)
      final flotService = FlotService.instance;
      const shopCentralId = 1; // TODO: Récupérer l'ID du shop central depuis la config

      final success2 = await flotService.createFlot(
        shopSourceId: updatedOperation.shopSourceId!,
        shopSourceDesignation: updatedOperation.shopSourceDesignation ?? 'Shop Source',
        shopDestinationId: shopCentralId,
        shopDestinationDesignation: 'SHOP C',
        montant: _montantNetCalcule!, // Utiliser le montant net recalculé
        devise: updatedOperation.devise,
        modePaiement: updatedOperation.modePaiement,
        agentEnvoyeurId: currentUser.id!,
        agentEnvoyeurUsername: currentUser.username,
        notes: 'Dette retrait Mobile Money - Réf: ${updatedOperation.codeOps}',
      );

      if (!success2) {
        debugPrint('⚠️ Échec création du flot dette (non bloquant)');
      }

      if (context.mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Opération servie\nMontant: ${_montantNetCalcule!.toStringAsFixed(2)} ${updatedOperation.devise}\nCommission: ${_commissionCalculee!.toStringAsFixed(2)} USD'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (context.mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Calculer la commission par défaut
  double _calculateCommission(double montant) {
    // Calcul simple de commission - à adapter selon vos besoins
    if (montant < 50) return 1.0;
    if (montant < 100) return 2.0;
    if (montant < 500) return 5.0;
    return montant * 0.02; // 2%
  }

  @override
  Widget build(BuildContext context) {
    final canServir = _captureVerifiee && _montantVerifie && _numeroVerifie && 
                      _montantNetCalcule != null && _commissionCalculee != null;
    
    final size = MediaQuery.of(context).size;
    
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.search, color: Colors.blue[700], size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servir par Référence',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Rechercher ou créer un retrait',
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
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Divider(height: 32),
            ),
            
            // Contenu scrollable
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Recherche par référence
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'RECHERCHE PAR RÉFÉRENCE',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _referenceController,
                                  decoration: const InputDecoration(
                                    labelText: 'Référence (REF)',
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.confirmation_number),
                                    hintText: 'Ex: MP123456789',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              ElevatedButton.icon(
                                onPressed: _isLoading ? null : _rechercherOperation,
                                icon: _isLoading 
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.search, size: 16),
                                label: const Text('Chercher'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    
                    // Formulaire de création/serving
                    if (_existingOperation != null || _referenceController.text.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _existingOperation != null 
                                  ? 'OPÉRATION TROUVÉE' 
                                  : 'CRÉER UN RETRAIT',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Montant
                            TextField(
                              controller: _montantController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Montant Brut',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.attach_money),
                                suffixText: 'USD',
                              ),
                              onChanged: (value) {
                                if (_tauxCommission != null) {
                                  _calculerMontants();
                                }
                              },
                            ),
                            const SizedBox(height: 12),
                            
                            // Informations client
                            TextField(
                              controller: _nomClientController,
                              decoration: const InputDecoration(
                                labelText: 'Nom du client',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.person),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            TextField(
                              controller: _telephoneClientController,
                              keyboardType: TextInputType.phone,
                              decoration: const InputDecoration(
                                labelText: 'Téléphone du client',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.phone),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // Taux de commission
                            TextField(
                              controller: _tauxController,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                labelText: 'Taux de commission (%)',
                                hintText: 'Ex: 2.5',
                                border: OutlineInputBorder(),
                                suffixText: '%',
                              ),
                              onChanged: (value) {
                                final taux = double.tryParse(value);
                                if (taux != null && taux >= 0 && taux <= 100) {
                                  setState(() {
                                    _tauxCommission = taux;
                                    _calculerMontants();
                                  });
                                } else {
                                  setState(() {
                                    _tauxCommission = null;
                                    _montantNetCalcule = null;
                                    _commissionCalculee = null;
                                  });
                                }
                              },
                            ),
                            const SizedBox(height: 16),
                            
                            // Résultats du calcul
                            if (_commissionCalculee != null && _montantNetCalcule != null)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.green[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Frais Encaissés:', style: TextStyle(fontSize: 12)),
                                        Text('${_commissionCalculee!.toStringAsFixed(2)} USD', 
                                            style: const TextStyle(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        const Text('Montant à Servir:', style: TextStyle(fontSize: 12)),
                                        Text('${_montantNetCalcule!.toStringAsFixed(2)} USD', 
                                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            const SizedBox(height: 16),
                            
                            // Checklist de vérification (uniquement pour les opérations existantes)
                            if (_existingOperation != null) ...[
                              const Text(
                                'VÉRIFICATIONS OBLIGATOIRES',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 12),
                              CheckboxListTile(
                                value: _captureVerifiee,
                                onChanged: (value) => setState(() => _captureVerifiee = value ?? false),
                                title: const Text('Capture d\'écran vérifiée'),
                                subtitle: const Text('Le client a montré le SMS/capture valide'),
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                              ),
                              CheckboxListTile(
                                value: _montantVerifie,
                                onChanged: (value) => setState(() => _montantVerifie = value ?? false),
                                title: const Text('Montant vérifié'),
                                subtitle: const Text('Le montant correspond à la capture'),
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                              ),
                              CheckboxListTile(
                                value: _numeroVerifie,
                                onChanged: (value) => setState(() => _numeroVerifie = value ?? false),
                                title: const Text('Numéro client vérifié'),
                                subtitle: const Text('Le numéro de téléphone correspond'),
                                controlAffinity: ListTileControlAffinity.leading,
                                dense: true,
                              ),
                              const SizedBox(height: 16),
                            ],
                            
                            // Observation
                            TextField(
                              controller: _observationController,
                              maxLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Observation (optionnel)',
                                border: OutlineInputBorder(),
                                hintText: 'Notes supplémentaires...',
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    const SizedBox(height: 24),
                    
                    // Warning
                    if (_existingOperation != null && !canServir)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.amber[300]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.amber),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Veuillez cocher toutes les vérifications et saisir le taux',
                                style: TextStyle(fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading 
                        ? null 
                        : (_existingOperation != null ? _servirOperationExistante : _creerEtServirRetrait),
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(_existingOperation != null ? Icons.check : Icons.add, size: 16),
                    label: Text(_isLoading 
                        ? 'Traitement...' 
                        : (_existingOperation != null ? 'SERVIR' : 'CRÉER & SERVIR')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _existingOperation != null ? Colors.green : Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}