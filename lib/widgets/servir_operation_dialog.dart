import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/operation_service.dart';
import '../services/flot_service.dart';
import '../services/auth_service.dart';
import '../services/sim_service.dart';
import '../services/sync_service.dart';
import '../models/operation_model.dart';
import '../models/flot_model.dart' as flot_model;

/// Dialog pour servir une opération de retrait Mobile Money
/// Crée automatiquement une dette entre shop SIM et shop central
class ServirOperationDialog extends StatefulWidget {
  final OperationModel operation;
  
  const ServirOperationDialog({
    super.key,
    required this.operation,
  });

  @override
  State<ServirOperationDialog> createState() => _ServirOperationDialogState();
}

class _ServirOperationDialogState extends State<ServirOperationDialog> {
  bool _isLoading = false;
  final _observationController = TextEditingController();
  final _tauxController = TextEditingController();
  final _nomClientController = TextEditingController();
  final _telephoneClientController = TextEditingController();
  bool _captureVerifiee = false;
  bool _montantVerifie = false;
  bool _numeroVerifie = false;
  double? _montantBrutSaisi;
  double? _tauxCommission;
  double? _montantNetCalcule;
  double? _commissionCalculee;

  @override
  void initState() {
    super.initState();
    // Pré-remplir avec les valeurs de l'opération si elles existent
    _montantBrutSaisi = widget.operation.montantBrut;
    // Pré-remplir les champs client avec les valeurs existantes
    _nomClientController.text = widget.operation.clientNom ?? widget.operation.destinataire ?? '';
    _telephoneClientController.text = widget.operation.telephoneDestinataire ?? '';
    
    // Si commission existe, calculer le taux à partir de montantBrut et commission
    if (widget.operation.commission > 0 && widget.operation.montantBrut > 0) {
      _tauxCommission = (widget.operation.commission / widget.operation.montantBrut) * 100;
      _tauxController.text = _tauxCommission!.toStringAsFixed(2);
      // Calculer les montants automatiquement
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculerMontants();
      });
    }
  }

  @override
  void dispose() {
    _observationController.dispose();
    _tauxController.dispose();
    _nomClientController.dispose();
    _telephoneClientController.dispose();
    super.dispose();
  }
  
  void _calculerMontants() {
    if (_montantBrutSaisi == null || _tauxCommission == null) return;
    
    // Commission = Montant Brut × (Taux / 100)
    _commissionCalculee = _montantBrutSaisi! * (_tauxCommission! / 100);
    // Montant Net = Montant Brut - Commission
    _montantNetCalcule = _montantBrutSaisi! - _commissionCalculee!;
    
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final operation = widget.operation;
    final canServir = _captureVerifiee && _montantVerifie && _numeroVerifie && 
                      _montantNetCalcule != null && _commissionCalculee != null;
    final size = MediaQuery.of(context).size;
    
    return Dialog(
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 500,
          maxHeight: size.height * 0.9, // Limite à 90% de la hauteur de l'écran
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header (non scrollable)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Icons.check_circle, color: Colors.green[700], size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Servir Opération',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Vérifier et donner le cash au client',
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'MONTANT À DONNER',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          operation.statutLabel.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const Divider(height: 24),
                  _buildInfoRow('Code', operation.codeOps),
                  _buildInfoRow('Client', operation.clientNom ?? operation.destinataire ?? 'N/A'),
                  _buildInfoRow('Téléphone', operation.telephoneDestinataire ?? 'N/A'),
                  _buildInfoRow('Référence', operation.reference ?? 'N/A'),
                  _buildInfoRow('Frais', '${operation.commission.toStringAsFixed(2)} USD'),
                  _buildInfoRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(operation.dateOp)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Informations du client bénéficiaire
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
                    'INFORMATIONS CLIENT BÉNÉFICIAIRE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
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
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // SAISIE DU TAUX DE COMMISSION
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
                    'CALCUL DES FRAIS',
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Montant Brut Reçu',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: TextField(
                          controller: _tauxController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Taux (%)',
                            hintText: 'Ex: 2.5',
                            border: OutlineInputBorder(),
                            suffixText: '%',
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                      ),
                    ],
                  ),
                  if (_commissionCalculee != null && _montantNetCalcule != null)
                    const Divider(height: 24),
                  if (_commissionCalculee != null && _montantNetCalcule != null)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Frais Encaissés',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_commissionCalculee!.toStringAsFixed(2)} ${operation.devise}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[700],
                              ),
                            ),
                          ],
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Montant à Servir',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${_montantNetCalcule!.toStringAsFixed(2)} ${operation.devise}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Checklist de vérification
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
            const SizedBox(height: 24),
            
            // Warning
            if (!canServir)
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
                        'Veuillez saisir le taux et cocher toutes les vérifications',
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
            
            // Buttons FIXES en bas (non scrollables)
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
                    onPressed: (_isLoading || !canServir) ? null : _servirOperation,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check, size: 16),
                    label: _isLoading ? const Text('Service...') : const Text('SERVIR'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
          const Text(': ', style: TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _servirOperation() async {
    setState(() => _isLoading = true);
    
    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      final flotService = FlotService.instance;
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      if (_montantNetCalcule == null || _commissionCalculee == null) {
        throw Exception('Veuillez saisir le taux de commission');
      }
      
      // 1. Marquer l'opération comme SERVIE avec les montants recalculés
      final updatedOperation = widget.operation.copyWith(
        statut: OperationStatus.terminee,
        commission: _commissionCalculee!, // Commission recalculée
        montantNet: _montantNetCalcule!,   // Montant net recalculé
        observation: _observationController.text.isEmpty ? null : _observationController.text,
        clientNom: _nomClientController.text.isEmpty ? widget.operation.clientNom : _nomClientController.text,
        telephoneDestinataire: _telephoneClientController.text.isEmpty ? widget.operation.telephoneDestinataire : _telephoneClientController.text,
        // dateValidation: DateTime.now(), // Champ n'existe plus dans OperationModel
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );
      
      final success = await operationService.updateOperation(updatedOperation);
      
      if (!success) {
        throw Exception('Échec de la mise à jour de l\'opération');
      }
      
      // 2. Créer la dette entre shop de la SIM et SHOP CENTRAL (SHOP C)
      // TODO: Récupérer l'ID du shop central depuis la config
      const shopCentralId = 1; // À remplacer par la vraie valeur
      
      final success2 = await flotService.createFlot(
        shopSourceId: widget.operation.shopSourceId!,
        shopSourceDesignation: widget.operation.shopSourceDesignation ?? 'Shop Source',
        shopDestinationId: shopCentralId,
        shopDestinationDesignation: 'SHOP C',
        montant: _montantNetCalcule!, // Utiliser le montant net recalculé
        devise: widget.operation.devise,
        modePaiement: _convertModePaiement(widget.operation.modePaiement),
        agentEnvoyeurId: currentUser.id!,
        agentEnvoyeurUsername: currentUser.username,
        notes: 'Dette retrait Mobile Money - Réf: ${widget.operation.codeOps}',
      );
      
      if (!success2) {
        debugPrint('⚠️ Échec création du flot dette (non bloquant)');
      }
      
      // 3. Mettre à jour le solde de la SIM automatiquement (si le champ simNumero existe)
      // Note: Le champ simNumero n'existe plus dans OperationModel actuel
      /*
      if (updatedOperation.simNumero != null) {
        debugPrint('📱 Mise à jour du solde de la SIM ${updatedOperation.simNumero}...');
        try {
          final simService = SimService.instance;
          
          // S'assurer que les SIMs sont chargées en mémoire
          if (simService.sims.isEmpty) {
            debugPrint('🔄 Rechargement des SIMs...');
            await simService.loadSims();
          }
          
          final sim = simService.getSimByNumero(updatedOperation.simNumero!);
          if (sim != null) {
            // calculateAutomaticSolde() va recharger les opérations automatiquement
            final wasUpdated = await simService.updateSoldeAutomatiquement(sim);
            if (wasUpdated) {
              debugPrint('✅ Solde de la SIM mis à jour automatiquement');
            } else {
              debugPrint('ℹ️ Solde de la SIM inchangé (aucune différence)');
            }
          } else {
            debugPrint('⚠️ SIM ${updatedOperation.simNumero} non trouvée en mémoire');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur mise à jour solde SIM (non bloquant): $e');
        }
      }
      */
      
      // 4. Synchroniser automatiquement avec le serveur
      debugPrint('🔄 Synchronisation automatique...');
      try {
        final syncService = SyncService();
        await syncService.syncAll();
        debugPrint('✅ Synchronisation automatique terminée avec succès');
      } catch (e) {
        debugPrint('⚠️ Erreur synchronisation automatique (non bloquant): $e');
        // La synchronisation échouera silencieusement, les données seront sync plus tard
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Opération servie\nMontant: ${_montantNetCalcule!.toStringAsFixed(2)} ${widget.operation.devise}\nCommission: ${_commissionCalculee!.toStringAsFixed(2)} USD'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
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
  
  /// Convertir ModePaiement d'opération vers ModePaiement de flot
  flot_model.ModePaiement _convertModePaiement(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return flot_model.ModePaiement.cash;
      case ModePaiement.airtelMoney:
        return flot_model.ModePaiement.airtelMoney;
      case ModePaiement.mPesa:
        return flot_model.ModePaiement.mPesa;
      case ModePaiement.orangeMoney:
        return flot_model.ModePaiement.orangeMoney;
    }
  }
}