import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/operation_service.dart';
import '../services/sim_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../models/operation_model.dart';
import '../models/sim_model.dart';
import 'create_retrait_dialog.dart';
import 'servir_operation_dialog.dart';
import 'servir_operation_par_ref_dialog.dart';
import 'rejeter_operation_dialog.dart';

/// Widget pour la gestion des retraits Mobile Money par les agents
class MobileMoneyRetraitsWidget extends StatefulWidget {
  const MobileMoneyRetraitsWidget({super.key});

  @override
  State<MobileMoneyRetraitsWidget> createState() => _MobileMoneyRetraitsWidgetState();
}

class _MobileMoneyRetraitsWidgetState extends State<MobileMoneyRetraitsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _filterStatut = 'NON_SERVI';
  DateTime? _simFilterDateDebut;
  DateTime? _simFilterDateFin;
  final Map<int, bool> _simExpandedState = {}; // Track expanded state per SIM ID
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final simService = SimService.instance;
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser?.shopId != null) {
      await simService.loadSims(shopId: currentUser!.shopId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Retraits Mobile Money'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Non Servis'),
              Tab(text: 'Servis'),
              Tab(text: 'Historique'),
              Tab(text: 'Commissions'),
              Tab(text: 'SIMs'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildOperationsNonServies(),
            _buildOperationsServies(),
            _buildHistorique(),
            _buildCommissions(),
            _buildSimsTab(),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "btn1",
              onPressed: _servirParReference,
              child: const Icon(Icons.search),
              backgroundColor: Colors.blue,
            ),
            const SizedBox(height: 8),
            FloatingActionButton.extended(
              heroTag: "btn2",
              onPressed: _creerNouvelleOperation,
              icon: const Icon(Icons.add),
              label: const Text('Créer Opération'),
              backgroundColor: Colors.orange[700],
            ),
          ],
        ),
      ),
    );
  }

  /// Servir une opération par référence
  Future<void> _servirParReference() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const ServirOperationParRefDialog(),
    );
    
    if (result == true) {
      // Recharger les données
      await Provider.of<OperationService>(context, listen: false).loadOperations();
    }
  }

  /// Liste des opérations NON_SERVI
  Widget _buildOperationsNonServies() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final operations = operationService.operations
            .where((op) => 
              op.type == OperationType.retrait &&
              op.statut == OperationStatus.enAttente)
            .toList();

        if (operations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune opération en attente',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les nouveaux retraits apparaîtront ici',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () => operationService.loadOperations(),
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: operations.length,
            itemBuilder: (context, index) {
              final operation = operations[index];
              return _buildOperationCard(operation, isNonServi: true);
            },
          ),
        );
      },
    );
  }

  /// Liste des opérations SERVI
  Widget _buildOperationsServies() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final operations = operationService.operations
            .where((op) => 
              op.type == OperationType.retrait &&
              op.statut == OperationStatus.terminee)
            .toList();

        if (operations.isEmpty) {
          return const Center(child: Text('Aucune opération servie'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: operations.length,
          itemBuilder: (context, index) {
            return _buildOperationCard(operations[index], isNonServi: false);
          },
        );
      },
    );
  }

  /// Card d'opération
  Widget _buildOperationCard(OperationModel operation, {required bool isNonServi}) {
    final montantColor = isNonServi ? Colors.orange : Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _afficherDetailsOperation(operation),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: montantColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isNonServi ? Icons.pending : Icons.check_circle,
                      color: montantColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: montantColor,
                          ),
                        ),
                        Text(
                          operation.observation ?? operation.notes ?? 'Code: ${operation.codeOps}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isNonServi)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'NON SERVI',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 16),
              Row(
                children: [
                  _buildInfoChip(Icons.phone_android, 'Réf: ${operation.reference ?? operation.codeOps}'),
                  const SizedBox(width: 8),
                  _buildInfoChip(Icons.person, operation.clientNom ?? operation.destinataire ?? 'Client'),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildInfoChip(Icons.calendar_today, DateFormat('dd/MM/yyyy HH:mm').format(operation.dateOp)),
                  const Spacer(),
                  if (isNonServi)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _servirOperation(operation),
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('SERVIR'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: () => _rejeterOperation(operation),
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('REJETER'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[700]),
          ),
        ],
      ),
    );
  }

  /// Historique complet
  Widget _buildHistorique() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final operations = operationService.operations
            .where((op) => op.type == OperationType.retrait)
            .toList()
          ..sort((a, b) => b.dateOp.compareTo(a.dateOp));

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: operations.length,
          itemBuilder: (context, index) {
            return _buildOperationCard(
              operations[index],
              isNonServi: operations[index].statut == OperationStatus.enAttente,
            );
          },
        );
      },
    );
  }

  /// Onglet Commissions
  Widget _buildCommissions() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        final operationsServies = operationService.operations
            .where((op) => 
              op.type == OperationType.retrait &&
              op.statut == OperationStatus.terminee &&
              op.agentId == currentUser?.id)
            .toList();

        final totalCommissions = operationsServies.fold<double>(
          0, 
          (sum, op) => sum + op.commission,
        );

        final totalCashSorti = operationsServies.fold<double>(
          0,
          (sum, op) => sum + op.montantNet,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              _buildStatCard(
                'Total Commissions',
                '${totalCommissions.toStringAsFixed(2)} USD',
                Icons.attach_money,
                Colors.green,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Cash Total Sorti',
                '${totalCashSorti.toStringAsFixed(2)} USD',
                Icons.money_off,
                Colors.orange,
              ),
              const SizedBox(height: 12),
              _buildStatCard(
                'Opérations Servies',
                '${operationsServies.length}',
                Icons.check_circle,
                Colors.blue,
              ),
              const SizedBox(height: 24),
              const Text(
                'Détail des Commissions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...operationsServies.map((op) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.green[100],
                    child: Text(
                      '${op.commission.toStringAsFixed(0)}\$',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text('${op.montantNet.toStringAsFixed(2)} ${op.devise}'),
                  subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(op.dateOp)),
                  trailing: Text(
                    '+${op.commission.toStringAsFixed(2)} USD',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              )),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Afficher détails d'une opération
  void _afficherDetailsOperation(OperationModel operation) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[700]),
            const SizedBox(width: 8),
            const Text('Détails Opération'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Code', operation.codeOps),
              _buildDetailRow('Montant', '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}'),
              _buildDetailRow('Commission', '${operation.commission.toStringAsFixed(2)} USD'),
              _buildDetailRow('Client', operation.clientNom ?? operation.destinataire ?? 'N/A'),
              _buildDetailRow('Référence', operation.reference ?? operation.codeOps),
              _buildDetailRow('Statut', operation.statutLabel),
              _buildDetailRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(operation.dateOp)),
              if (operation.observation != null)
                _buildDetailRow('Observation', operation.observation!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Servir une opération
  Future<void> _servirOperation(OperationModel operation) async {
    // Vérifier que l'opération n'est pas déjà servie
    if (operation.statut == OperationStatus.terminee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Opération déjà servie - Refuser le cash!'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ServirOperationDialog(operation: operation),
    );
    
    if (result == true) {
      // Recharger les données
      await Provider.of<OperationService>(context, listen: false).loadOperations();
    }
  }

  /// Rejeter une opération
  Future<void> _rejeterOperation(OperationModel operation) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => RejeterOperationDialog(operation: operation),
    );
    
    if (result == true) {
      // Recharger les données
      await Provider.of<OperationService>(context, listen: false).loadOperations();
    }
  }

  /// Créer nouvelle opération
  Future<void> _creerNouvelleOperation() async {
    final result = await showDialog(
      context: context,
      builder: (context) => const CreateRetraitDialog(),
    );
    
    // Recharger les données après création
    if (result != null && mounted) {
      await Provider.of<OperationService>(context, listen: false).loadOperations();
    }
  }

  /// Onglet SIMs - Soldes et opérations par SIM
  Widget _buildSimsTab() {
    return Consumer<SimService>(
      builder: (context, simService, child) {
        final sims = simService.sims.where((s) => s.statut == SimStatus.active).toList();

        if (sims.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sim_card_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune SIM active',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les SIMs sont créées par l\'administrateur',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: sims.length,
            itemBuilder: (context, index) {
              final sim = sims[index];
              return _buildSimCard(sim);
            },
          ),
        );
      },
    );
  }

  /// Card d'une SIM
  Widget _buildSimCard(SimModel sim) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.sim_card, color: Colors.green[700], size: 28),
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
            Text(
              'Solde: ${sim.soldeActuel.toStringAsFixed(2)} USD',
              style: TextStyle(
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSimDetailRow('Numéro', sim.numero),
                _buildSimDetailRow('Opérateur', sim.operateur),
                _buildSimDetailRow('Shop', ShopService.instance.getShopDesignation(sim.shopId, existingDesignation: sim.shopDesignation)),
                _buildSimDetailRow('Solde Initial', '${sim.soldeInitial.toStringAsFixed(2)} USD'),
                _buildSimDetailRow('Solde Actuel', '${sim.soldeActuel.toStringAsFixed(2)} USD'),
                _buildSimDetailRow('Créé le', DateFormat('dd/MM/yyyy HH:mm').format(sim.dateCreation)),
                const Divider(height: 24),
                const Text(
                  'Opérations liées à cette SIM',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                _buildSimOperations(sim),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
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

  /// Afficher les opérations liées à une SIM
  Widget _buildSimOperations(SimModel sim) {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        // Filtrer les opérations liées à cette SIM (par numéro de téléphone)
        var simOperations = operationService.operations
            .where((op) => 
              op.type == OperationType.retrait &&
              (op.telephoneDestinataire == sim.numero || 
               op.reference?.contains(sim.numero) == true))
            .toList();
        
        // Appliquer le filtre de date si défini
        if (_simFilterDateDebut != null) {
          simOperations = simOperations.where((op) => 
            op.dateOp.isAfter(_simFilterDateDebut!.subtract(const Duration(seconds: 1)))
          ).toList();
        }
        if (_simFilterDateFin != null) {
          final finJournee = DateTime(_simFilterDateFin!.year, _simFilterDateFin!.month, _simFilterDateFin!.day, 23, 59, 59);
          simOperations = simOperations.where((op) => 
            op.dateOp.isBefore(finJournee.add(const Duration(seconds: 1)))
          ).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filtres de date
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _simFilterDateDebut ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (date != null) {
                        setState(() => _simFilterDateDebut = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _simFilterDateDebut != null 
                                ? DateFormat('dd/MM/yyyy').format(_simFilterDateDebut!)
                                : 'Date début',
                              style: TextStyle(
                                fontSize: 12,
                                color: _simFilterDateDebut != null ? Colors.black87 : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (_simFilterDateDebut != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _simFilterDateDebut = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: _simFilterDateFin ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        locale: const Locale('fr', 'FR'),
                      );
                      if (date != null) {
                        setState(() => _simFilterDateFin = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _simFilterDateFin != null 
                                ? DateFormat('dd/MM/yyyy').format(_simFilterDateFin!)
                                : 'Date fin',
                              style: TextStyle(
                                fontSize: 12,
                                color: _simFilterDateFin != null ? Colors.black87 : Colors.grey[600],
                              ),
                            ),
                          ),
                          if (_simFilterDateFin != null)
                            IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => setState(() => _simFilterDateFin = null),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Compteur d'opérations
            if (_simFilterDateDebut != null || _simFilterDateFin != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${simOperations.length} opération(s) trouvée(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
              ),

            // Liste des opérations
            if (simOperations.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _simFilterDateDebut != null || _simFilterDateFin != null
                    ? 'Aucune opération trouvée pour cette période'
                    : 'Aucune opération liée à cette SIM',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              )
            else
              ...simOperations.take(10).map((op) {
                return ListTile(
                  dense: true,
                  leading: Icon(
                    op.statut == OperationStatus.enAttente 
                      ? Icons.pending 
                      : Icons.check_circle,
                    color: op.statut == OperationStatus.enAttente 
                      ? Colors.orange 
                      : Colors.green,
                    size: 20,
                  ),
                  title: Text(
                    '${op.montantNet.toStringAsFixed(2)} ${op.devise}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(op.dateOp),
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: Text(
                    op.statutLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: op.statut == OperationStatus.enAttente 
                        ? Colors.orange 
                        : Colors.green,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              }).toList(),
            
            if (simOperations.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... et ${simOperations.length - 10} autre(s) opération(s)',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                ),
              ),
          ],
        );
      },
    );
  }
}
