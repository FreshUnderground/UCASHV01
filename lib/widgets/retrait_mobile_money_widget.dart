import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/operation_model.dart';
import '../models/sim_model.dart';
import '../services/operation_service.dart';
import '../services/sim_service.dart';
import '../services/agent_auth_service.dart';

/// Widget pour gérer les retraits Mobile Money (Cash-Out)
/// Flux: Agent reçoit message → Enregistre (EN_ATTENTE) → Client arrive → Valide → Cash sort + SIM augmente
class RetraitMobileMoneyWidget extends StatefulWidget {
  const RetraitMobileMoneyWidget({super.key});

  @override
  State<RetraitMobileMoneyWidget> createState() => _RetraitMobileMoneyWidgetState();
}

class _RetraitMobileMoneyWidgetState extends State<RetraitMobileMoneyWidget> {
  final _formKey = GlobalKey<FormState>();
  
  // Form fields for NEW retrait
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  final _destinataireController = TextEditingController();
  final _notesController = TextEditingController();
  
  SimModel? _selectedSim;
  ModePaiement _selectedOperateur = ModePaiement.airtelMoney;
  String _selectedDevise = 'USD';
  
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadData();
  }
  
  Future<void> _loadData() async {
    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final shopId = authService.currentAgent?.shopId;
    
    if (shopId != null) {
      await Provider.of<SimService>(context, listen: false).loadSims(shopId: shopId);
      await Provider.of<OperationService>(context, listen: false).loadOperations(shopId: shopId);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Retrait Mobile Money (Cash-Out)'),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          // LEFT: Formulaire d'enregistrement
          Expanded(
            flex: 2,
            child: _buildFormulaire(),
          ),
          
          // DIVIDER
          const VerticalDivider(width: 1),
          
          // RIGHT: Liste des retraits en attente
          Expanded(
            flex: 3,
            child: _buildListeRetraitsEnAttente(),
          ),
        ],
      ),
    );
  }
  
  /// FORMULAIRE: Enregistrer un nouveau retrait (EN_ATTENTE)
  Widget _buildFormulaire() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Enregistrer un Retrait',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Vous avez reçu un message de retrait ? Enregistrez-le ici.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 24),
            
            // Opérateur / SIM
            Consumer<SimService>(
              builder: (context, simService, child) {
                final sims = simService.sims.where((s) => s.statut == SimStatus.active).toList();
                
                return DropdownButtonFormField<SimModel>(
                  value: _selectedSim,
                  decoration: const InputDecoration(
                    labelText: 'SIM *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.sim_card),
                  ),
                  items: sims.map((sim) {
                    return DropdownMenuItem(
                      value: sim,
                      child: Text('${sim.numero} (${sim.operateur}) - ${sim.soldeActuel.toStringAsFixed(2)} USD'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSim = value;
                      // Auto-select operateur
                      if (value != null) {
                        switch (value.operateur.toLowerCase()) {
                          case 'airtel':
                            _selectedOperateur = ModePaiement.airtelMoney;
                            break;
                          case 'vodacom':
                          case 'mpesa':
                            _selectedOperateur = ModePaiement.mPesa;
                            break;
                          case 'orange':
                            _selectedOperateur = ModePaiement.orangeMoney;
                            break;
                          default:
                            _selectedOperateur = ModePaiement.airtelMoney;
                        }
                      }
                    });
                  },
                  validator: (value) => value == null ? 'Sélectionnez une SIM' : null,
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Référence
            TextFormField(
              controller: _referenceController,
              decoration: const InputDecoration(
                labelText: 'Référence du retrait *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.tag),
                hintText: 'Ex: MP123456789',
              ),
              validator: (value) => value == null || value.isEmpty ? 'Référence obligatoire' : null,
            ),
            const SizedBox(height: 16),
            
            // Montant
            TextFormField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant $_selectedDevise *',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Montant obligatoire';
                if (double.tryParse(value) == null) return 'Montant invalide';
                if (double.parse(value) <= 0) return 'Montant doit être > 0';
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Destinataire (Client)
            TextFormField(
              controller: _destinataireController,
              decoration: const InputDecoration(
                labelText: 'Nom du client (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            
            // Notes
            TextFormField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optionnel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
              ),
            ),
            const SizedBox(height: 24),
            
            // BOUTON ENREGISTRER
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _enregistrerRetrait,
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save),
              label: Text(_isLoading ? 'Enregistrement...' : 'Enregistrer (EN ATTENTE)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.orange,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Le retrait sera enregistré EN ATTENTE. Validez-le quand le client arrive.',
              style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
  
  /// LISTE: Retraits en attente (à valider)
  Widget _buildListeRetraitsEnAttente() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final retraitsEnAttente = operationService.operations
            .where((op) =>
                op.type == OperationType.retraitMobileMoney &&
                op.statut == OperationStatus.enAttente)
            .toList();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  const Icon(Icons.pending_actions, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Retraits en Attente (${retraitsEnAttente.length})',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    onPressed: _loadData,
                    tooltip: 'Actualiser',
                  ),
                ],
              ),
            ),
            Expanded(
              child: retraitsEnAttente.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'Aucun retrait en attente',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: retraitsEnAttente.length,
                      itemBuilder: (context, index) {
                        return _buildRetraitCard(retraitsEnAttente[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
  
  /// CARD: Un retrait en attente
  Widget _buildRetraitCard(OperationModel retrait) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Référence + Montant
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.pending, color: Colors.orange[700], size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Réf: ${retrait.reference ?? "N/A"}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'SIM: ${retrait.simNumero ?? "N/A"}',
                        style: const TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${retrait.montantBrut.toStringAsFixed(2)} ${retrait.devise}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    Text(
                      'Virtuel SIM',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
            
            // Détail des montants
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Virtuel (SIM):', style: TextStyle(fontSize: 13)),
                      Text(
                        '+${retrait.montantBrut.toStringAsFixed(2)} ${retrait.devise}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Frais:', style: TextStyle(fontSize: 13)),
                      Text(
                        '-${retrait.commission.toStringAsFixed(2)} ${retrait.devise}',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cash à donner:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      Text(
                        '${retrait.montantNet.toStringAsFixed(2)} ${retrait.devise}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            if (retrait.destinataire != null && retrait.destinataire!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text('Client: ${retrait.destinataire}'),
                ],
              ),
            ],
            
            if (retrait.notes != null && retrait.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.note, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Expanded(child: Text(retrait.notes!, style: const TextStyle(fontSize: 13))),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            
            // BOUTON VALIDER
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _validerRetrait(retrait),
                icon: const Icon(Icons.check_circle),
                label: const Text('VALIDER LE RETRAIT (Donner le cash)'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  /// ACTION: Enregistrer un nouveau retrait (statut EN_ATTENTE)
  Future<void> _enregistrerRetrait() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSim == null) return;
    
    setState(() => _isLoading = true);
    
    try {
      final authService = Provider.of<AgentAuthService>(context, listen: false);
      final currentAgent = authService.currentAgent;
      
      if (currentAgent == null) {
        throw Exception('Agent non connecté');
      }
      
      final montantVirtuel = double.parse(_montantController.text);
      
      // Calculer les frais selon l'opérateur
      final tauxFrais = _getTauxFrais(_selectedOperateur);
      final frais = (montantVirtuel * tauxFrais / 100);
      final montantCash = montantVirtuel - frais;
      
      final operation = OperationModel(
        type: OperationType.retraitMobileMoney,
        montantBrut: montantVirtuel, // Montant virtuel reçu sur SIM
        commission: double.parse(frais.toStringAsFixed(2)), // Frais
        montantNet: double.parse(montantCash.toStringAsFixed(2)), // Cash à donner
        devise: _selectedDevise,
        agentId: currentAgent.id!,
        agentUsername: currentAgent.username,
        shopSourceId: currentAgent.shopId,
        destinataire: _destinataireController.text.trim().isEmpty ? null : _destinataireController.text.trim(),
        reference: _referenceController.text.trim(),
        simNumero: _selectedSim!.numero,
        modePaiement: _selectedOperateur,
        statut: OperationStatus.enAttente, // EN ATTENTE !
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        dateOp: DateTime.now(),
        codeOps: '', // Will be generated by service
      );
      
      await Provider.of<OperationService>(context, listen: false).createOperation(operation);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Retrait enregistré EN ATTENTE.\nVirtuel: $montantVirtuel \$, Frais: ${frais.toStringAsFixed(2)} \$, Cash: ${montantCash.toStringAsFixed(2)} \$'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
        
        // Clear form
        _montantController.clear();
        _referenceController.clear();
        _destinataireController.clear();
        _notesController.clear();
        setState(() => _selectedSim = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  /// Obtenir le taux de frais selon l'opérateur
  double _getTauxFrais(ModePaiement operateur) {
    switch (operateur) {
      case ModePaiement.airtelMoney:
        return 4.0;
      case ModePaiement.mPesa:
        return 3.5;
      case ModePaiement.orangeMoney:
        return 4.0;
      case ModePaiement.cash:
        return 0.0;
    }
  }
  
  /// ACTION: Valider un retrait (passer de EN_ATTENTE à VALIDEE)
  /// Cette action déclenche: +SIM virtuel, -Cash agent
  Future<void> _validerRetrait(OperationModel retrait) async {
    // Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le Retrait'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Avez-vous donné le cash au client ?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Référence: ${retrait.reference}'),
                  Text('SIM: ${retrait.simNumero}'),
                  const Divider(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Virtuel (SIM):'),
                      Text('+${retrait.montantBrut.toStringAsFixed(2)} ${retrait.devise}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Frais:'),
                      Text('-${retrait.commission.toStringAsFixed(2)} ${retrait.devise}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Cash donné:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text('${retrait.montantNet.toStringAsFixed(2)} ${retrait.devise}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFFDC2626))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '⚠️ Actions automatiques :',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('  • Solde SIM +${retrait.montantBrut.toStringAsFixed(2)} (virtuel)'),
                  Text('  • Capital CASH -${retrait.montantNet.toStringAsFixed(2)}'),
                  Text('  • Frais +${retrait.commission.toStringAsFixed(2)} pour l\'agent'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('VALIDER'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    setState(() => _isLoading = true);
    
    try {
      // PROTECTION: Ne pas permettre de revalider une opération déjà validée
      if (retrait.dateValidation != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Ce retrait a déjà été validé le ${retrait.dateValidation}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Update status to VALIDEE
      final updatedRetrait = retrait.copyWith(
        statut: OperationStatus.validee,
        dateValidation: DateTime.now(), // Définie UNE SEULE FOIS
      );
      
      // Save and trigger balance updates
      await Provider.of<OperationService>(context, listen: false).updateOperation(updatedRetrait);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Retrait validé avec succès! SIM et capital mis à jour.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  void dispose() {
    _montantController.dispose();
    _referenceController.dispose();
    _destinataireController.dispose();
    _notesController.dispose();
    super.dispose();
  }
}
