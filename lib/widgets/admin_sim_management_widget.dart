import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/sim_service.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/sim_model.dart';
import '../models/sim_movement_model.dart';
import '../models/operation_model.dart';
import 'create_sim_dialog.dart';

/// Widget de gestion des SIMs pour l'administrateur
class AdminSimManagementWidget extends StatefulWidget {
  const AdminSimManagementWidget({super.key});

  @override
  State<AdminSimManagementWidget> createState() => _AdminSimManagementWidgetState();
}

class _AdminSimManagementWidgetState extends State<AdminSimManagementWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterOperateur = 'Tous';
  String _filterStatut = 'Tous';
  int? _filterShopId;
  String _filterSimNumero = '';
  String _filterType = 'Tous';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    // Charger TOUTES les SIMs (visibles par tous)
    await SimService.instance.loadSims();
    
    // Charger TOUS les mouvements (l'admin voit tout)
    // NOTE: Pour les agents, le filtrage sera fait dans leur vue spécifique
    await SimService.instance.loadMovements();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            children: [
              const Icon(Icons.sim_card, color: Colors.white, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gestion des Cartes SIM',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'Configuration et suivi des SIMs Mobile Money',
                      style: TextStyle(fontSize: 14, color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh),
                    color: Colors.white,
                    tooltip: 'Actualiser',
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _creerNouvelleSim,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvelle SIM'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFDC2626),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFDC2626),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFDC2626),
          tabs: const [
            Tab(icon: Icon(Icons.sim_card), text: 'Toutes les SIMs'),
            Tab(icon: Icon(Icons.history), text: 'Mouvements'),
          ],
        ),

        // Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildSimsTab(),
              _buildMovementsTab(),
            ],
          ),
        ),
      ],
    );
  }

  /// Onglet liste des SIMs
  Widget _buildSimsTab() {
    return Column(
      children: [
        // Filtres
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterOperateur,
                  decoration: const InputDecoration(
                    labelText: 'Opérateur',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['Tous', 'Airtel', 'Vodacom', 'Orange', 'Africell']
                      .map((op) => DropdownMenuItem(value: op, child: Text(op)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterOperateur = value!;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _filterStatut,
                  decoration: const InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: ['Tous', 'ACTIVE', 'SUSPENDUE', 'PERDUE', 'DESACTIVEE']
                      .map((st) => DropdownMenuItem(value: st, child: Text(st)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _filterStatut = value!;
                    });
                  },
                ),
              ),
            ],
          ),
        ),

        // Liste des SIMs
        Expanded(
          child: Consumer<SimService>(
            builder: (context, simService, child) {
              var sims = simService.sims;

              // Appliquer les filtres
              if (_filterOperateur != 'Tous') {
                sims = sims.where((s) => s.operateur == _filterOperateur).toList();
              }
              if (_filterStatut != 'Tous') {
                sims = sims.where((s) => s.statut.name.toUpperCase() == _filterStatut).toList();
              }
              if (_filterShopId != null) {
                sims = sims.where((s) => s.shopId == _filterShopId).toList();
              }

              if (sims.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sim_card_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Aucune SIM trouvée',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sims.length,
                  itemBuilder: (context, index) {
                    final sim = sims[index];
                    return _buildSimCard(sim);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Card d'une SIM
  Widget _buildSimCard(SimModel sim) {
    final statutColor = _getStatutColor(sim.statut);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: statutColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.sim_card, color: statutColor, size: 28),
        ),
        title: Text(
          sim.numero,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${sim.operateur} • ${ShopService.instance.getShopDesignation(sim.shopId, existingDesignation: sim.shopDesignation)}'),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statutColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    sim.statut.name.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Solde: ${sim.soldeActuel.toStringAsFixed(2)} USD',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Numéro', sim.numero),
                _buildDetailRow('Opérateur', sim.operateur),
                _buildDetailRow('Shop', ShopService.instance.getShopDesignation(sim.shopId, existingDesignation: sim.shopDesignation)),
                _buildDetailRow('Solde Initial', '${sim.soldeInitial.toStringAsFixed(2)} USD'),
                _buildDetailRow('Solde Actuel', '${sim.soldeActuel.toStringAsFixed(2)} USD'),
                _buildDetailRow('Statut', sim.statut.name.toUpperCase()),
                if (sim.motifSuspension != null)
                  _buildDetailRow('Motif Suspension', sim.motifSuspension!),
                _buildDetailRow('Créé le', DateFormat('dd/MM/yyyy HH:mm').format(sim.dateCreation)),
                if (sim.dateSuspension != null)
                  _buildDetailRow('Suspendu le', DateFormat('dd/MM/yyyy HH:mm').format(sim.dateSuspension!)),
                const Divider(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (sim.statut == SimStatus.active)
                      ElevatedButton.icon(
                        onPressed: () => _suspendreSimDialog(sim),
                        icon: const Icon(Icons.block, size: 16),
                        label: const Text('Suspendre'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    if (sim.statut == SimStatus.suspendue)
                      ElevatedButton.icon(
                        onPressed: () => _reactiverSim(sim),
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Réactiver'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _deplacerSimDialog(sim),
                      icon: const Icon(Icons.swap_horiz, size: 16),
                      label: const Text('Déplacer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _modifierSoldeDialog(sim),
                      icon: const Icon(Icons.attach_money, size: 16),
                      label: const Text('Modifier Solde'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _voirHistorique(sim),
                      icon: const Icon(Icons.history, size: 16),
                      label: const Text('Historique'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Color _getStatutColor(SimStatus statut) {
    switch (statut) {
      case SimStatus.active:
        return Colors.green;
      case SimStatus.suspendue:
        return Colors.orange;
      case SimStatus.perdue:
        return Colors.red;
      case SimStatus.desactivee:
        return Colors.grey;
    }
  }

  /// Onglet mouvements
  Widget _buildMovementsTab() {
    return Consumer2<SimService, OperationService>(
      builder: (context, simService, operationService, child) {
        // Combiner les mouvements de SIM et les opérations liées aux SIMs
        final List<dynamic> allItems = [];
        
        // Ajouter les mouvements de SIM
        allItems.addAll(simService.movements);
        
        // Ajouter les opérations de retrait liées aux SIMs
        final simOperations = <OperationModel>[];
        for (var sim in simService.sims) {
          final relatedOps = operationService.operations
              .where((op) => 
                op.type == OperationType.retrait &&
                (op.telephoneDestinataire == sim.numero || 
                 op.reference?.contains(sim.numero) == true))
              .toList();
          simOperations.addAll(relatedOps);
        }
        
        // Trier par date décroissante
        allItems.addAll(simOperations);
        allItems.sort((a, b) {
          DateTime dateA, dateB;
          
          if (a is SimMovementModel) {
            dateA = a.dateMovement;
          } else if (a is OperationModel) {
            dateA = a.dateOp;
          } else {
            dateA = DateTime.now();
          }
          
          if (b is SimMovementModel) {
            dateB = b.dateMovement;
          } else if (b is OperationModel) {
            dateB = b.dateOp;
          } else {
            dateB = DateTime.now();
          }
          
          return dateB.compareTo(dateA);
        });

        // Appliquer les filtres
        List<dynamic> filteredItems = List.from(allItems);
        
        // Filtrer par numéro de SIM
        if (_filterSimNumero.isNotEmpty) {
          filteredItems = filteredItems.where((item) {
            if (item is SimMovementModel) {
              return item.simNumero.contains(_filterSimNumero);
            } else if (item is OperationModel) {
              return (item.telephoneDestinataire?.contains(_filterSimNumero) ?? false) ||
                     (item.reference?.contains(_filterSimNumero) ?? false);
            }
            return false;
          }).toList();
        }
        
        // Filtrer par type
        if (_filterType != 'Tous') {
          if (_filterType == 'Mouvements SIM') {
            filteredItems = filteredItems.where((item) => item is SimMovementModel).toList();
          } else if (_filterType == 'Opérations') {
            filteredItems = filteredItems.where((item) => item is OperationModel).toList();
          }
        }

        if (filteredItems.isEmpty) {
          return const Center(child: Text('Aucun mouvement enregistré'));
        }

        return Column(
          children: [
            // Filtres
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Filtrer par numéro de SIM',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _filterSimNumero = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  DropdownButton<String>(
                    value: _filterType,
                    items: ['Tous', 'Mouvements SIM', 'Opérations']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _filterType = value!;
                      });
                    },
                  ),
                ],
              ),
            ),
            
            // Liste des mouvements
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final item = filteredItems[index];
                  
                  if (item is SimMovementModel) {
                    // Afficher un mouvement de SIM
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFDC2626),
                          child: Icon(Icons.swap_horiz, color: Colors.white),
                        ),
                        title: Text('SIM ${item.simNumero}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.movementDescription,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (item.motif != null)
                              Text(
                                'Motif: ${item.motif}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.adminResponsable,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(item.dateMovement),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else if (item is OperationModel) {
                    // Afficher une opération liée à une SIM
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: item.statut == OperationStatus.terminee ? Colors.green : 
                                         item.statut == OperationStatus.validee ? Colors.orange : Colors.grey,
                          child: Icon(
                            item.statut == OperationStatus.terminee ? Icons.check : 
                            item.statut == OperationStatus.validee ? Icons.pending : Icons.hourglass_empty,
                            color: Colors.white,
                          ),
                        ),
                        title: Text('${item.montantNet.toStringAsFixed(2)} ${item.devise}'),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Retrait - ${item.reference ?? item.codeOps}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              'SIM: ${item.telephoneDestinataire}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                            if (item.destinataire != null)
                              Text(
                                'Client: ${item.destinataire}',
                                style: const TextStyle(fontSize: 11, color: Colors.blue),
                              ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              item.statutLabel,
                              style: TextStyle(
                                fontSize: 11, 
                                fontWeight: FontWeight.bold,
                                color: item.statut == OperationStatus.terminee ? Colors.green : 
                                       item.statut == OperationStatus.validee ? Colors.orange : Colors.grey,
                              ),
                            ),
                            Text(
                              DateFormat('dd/MM/yyyy HH:mm').format(item.dateOp),
                              style: const TextStyle(fontSize: 10, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        );
      },
    );
  }

  // Actions
  Future<void> _creerNouvelleSim() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const CreateSimDialog(),
    );
    
    // Recharger la liste après création
    if (result != null && mounted) {
      await _loadData();
    }
  }

  Future<void> _suspendreSimDialog(SimModel sim) async {
    final motifController = TextEditingController();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Suspendre la SIM'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous suspendre la SIM ${sim.numero} ?'),
            const SizedBox(height: 16),
            TextField(
              controller: motifController,
              decoration: const InputDecoration(
                labelText: 'Motif de suspension',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Suspendre'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await SimService.instance.suspendSim(
        sim: sim,
        motif: motifController.text,
        suspendPar: authService.currentUser?.username ?? 'admin',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '✅ SIM suspendue' : '❌ Échec suspension'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _reactiverSim(SimModel sim) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await SimService.instance.reactivateSim(
      sim: sim,
      reactivePar: authService.currentUser?.username ?? 'admin',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? '✅ SIM réactivée' : '❌ Échec réactivation'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deplacerSimDialog(SimModel sim) async {
    // TODO: Dialog déplacement vers autre shop
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dialog déplacement - À implémenter')),
    );
  }

  Future<void> _modifierSoldeDialog(SimModel sim) async {
    // TODO: Dialog modification solde
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dialog modification solde - À implémenter')),
    );
  }

  void _voirHistorique(SimModel sim) {
    // Aller à l'onglet Mouvements et filtrer par cette SIM
    _tabController.animateTo(1);
  }
}
