import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ucashv01/widgets/reports/releve_compte_client_report.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import 'create_client_dialog_responsive.dart';
import 'depot_dialog.dart';
import 'retrait_dialog.dart';
import 'edit_client_dialog.dart';
import 'initialize_balance_dialog.dart';

/// Widget pour que l'admin puisse voir tous les clients et leurs relevés
class AdminClientsWidget extends StatefulWidget {
  const AdminClientsWidget({super.key});

  @override
  State<AdminClientsWidget> createState() => _AdminClientsWidgetState();
}

class _AdminClientsWidgetState extends State<AdminClientsWidget> {
  String _searchQuery = '';
  int? _filterShopId;
  bool _showOnlyActive = false;
  ClientModel? _selectedClient;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = false;  // Filtres masqués par défaut
  bool _showReport = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final clientService = Provider.of<ClientService>(context, listen: false);
    final shopService = Provider.of<ShopService>(context, listen: false);
    final operationService = Provider.of<OperationService>(context, listen: false);
    
    await Future.wait([
      clientService.loadClients(),
      shopService.loadShops(),
      operationService.loadOperations(),  // Charger TOUTES les opérations (admin n'a pas de filtre par shop)
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(isMobile),
          const SizedBox(height: 20),
          
          // Afficher les filtres seulement si aucun client n'est sélectionné
          if (!_showReport) ...
          [
            // Bouton pour masquer/afficher les filtres
            _buildFilterToggle(isMobile),
            if (_showFilters) ...
            [
              const SizedBox(height: 12),
              _buildFilters(isMobile),
            ],
            const SizedBox(height: 20),
            Expanded(
              child: _buildClientsList(isMobile),
            ),
          ] else ...
          [
            // Section de relevé de compte client
            _buildClientStatementSection(isMobile),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.purple.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.people,
            color: Colors.purple,
            size: 32,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Partenaires',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vue d\'ensemble',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        ElevatedButton.icon(
          onPressed: _showCreateClientDialog,
          icon: Icon(Icons.person_add, size: isMobile ? 18 : 20),
          label: Text(isMobile ? 'Nouveau' : 'Nouveau Partenaire'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 20,
              vertical: isMobile ? 10 : 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterToggle(bool isMobile) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () {
          setState(() {
            _showFilters = !_showFilters;
          });
        },
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Row(
            children: [
              Icon(
                _showFilters ? Icons.filter_list_off : Icons.filter_list,
                color: Colors.purple,
              ),
              const SizedBox(width: 12),
              Text(
                _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.purple,
                ),
              ),
              const Spacer(),
              Icon(
                _showFilters ? Icons.expand_less : Icons.expand_more,
                color: Colors.grey[600],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          labelText: 'Rechercher',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        decoration: const InputDecoration(
                          labelText: 'Shop',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                        ),
                        value: _filterShopId,
                        isExpanded: true,  // Important pour éviter l'overflow
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tous'),
                          ),
                          ...shopService.shops.map((shop) => DropdownMenuItem<int?>(
                            value: shop.id,
                            child: Text(
                              shop.designation,
                              overflow: TextOverflow.ellipsis,
                            ),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _filterShopId = value;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Checkbox(
                      value: _showOnlyActive,
                      onChanged: (value) {
                        setState(() {
                          _showOnlyActive = value ?? true;
                        });
                      },
                    ),
                    const Text('Afficher Tout'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Calculer le solde d'un client depuis ses opérations
  double _calculateClientBalance(int clientId, List<OperationModel> operations) {
    double balance = 0.0;
    
    for (final op in operations.where((o) => o.clientId == clientId)) {
      switch (op.type) {
        case OperationType.depot:
          // Dépôt augmente le solde du client
          balance += op.montantNet;
          break;
        case OperationType.retrait:
          // Retrait diminue le solde du client
          balance -= op.montantNet;
          break;
        case OperationType.transfertNational:
        case OperationType.transfertInternationalSortant:
          // Transfert sortant diminue le solde (client paie)
          balance -= op.montantBrut;
          break;
        case OperationType.transfertInternationalEntrant:
          // Transfert entrant augmente le solde (client reçoit)
          balance += op.montantNet;
          break;
        default:
          break;
      }
    }
    
    return balance;
  }

  /// Calculer le solde initialisé d'un client pour un shop spécifique
  double _calculateInitializedBalance(int clientId, int shopId, List<OperationModel> operations) {
    double initializedBalance = 0.0;
    
    for (final op in operations.where((o) => 
        o.clientId == clientId && 
        o.shopSourceId == shopId &&
        o.isAdministrative &&
        o.type == OperationType.depot &&
        (o.observation?.contains('ouverture') == true || o.observation?.contains('initialisation') == true)
    )) {
      initializedBalance += op.montantNet;
    }
    
    return initializedBalance;
  }

  Widget _buildClientsList(bool isMobile) {
    return Consumer3<ClientService, ShopService, OperationService>(
      builder: (context, clientService, shopService, operationService, child) {
        if (clientService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Apply filters
        var filteredClients = clientService.clients.where((client) {
          if (_showOnlyActive && !client.isActive) return false;
          if (_filterShopId != null && client.shopId != _filterShopId) return false;
          if (_searchQuery.isNotEmpty) {
            return client.nom.toLowerCase().contains(_searchQuery) ||
                   client.telephone.toLowerCase().contains(_searchQuery) ||
                   client.numeroCompteFormate.toLowerCase().contains(_searchQuery);
          }
          return true;
        }).toList();

        // Sort by name
        filteredClients.sort((a, b) => a.nom.compareTo(b.nom));

        if (filteredClients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun partenaire trouvé',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: filteredClients.length,
          itemBuilder: (context, index) {
            final client = filteredClients[index];
            final shop = shopService.shops.firstWhere(
              (s) => s.id == client.shopId,
              orElse: () => shopService.shops.first,
            );
            
            // Calculer le solde réel depuis les opérations
            final calculatedBalance = _calculateClientBalance(
              client.id!,
              operationService.operations,
            );
            
            // Calculer le solde initialisé pour ce shop
            final initializedBalance = _calculateInitializedBalance(
              client.id!,
              shop.id!,
              operationService.operations,
            );

            return Card(
              margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: calculatedBalance >= 0 ? Colors.green : Colors.red,
                  child: Text(
                    client.nom[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.nom,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    if (!client.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Inactif',
                          style: TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text('📱 ${client.telephone}'),
                    Text('💳 ${client.numeroCompteFormate}'),
                    // ❌ NE PAS afficher le shop pour l'admin
                    // Text('🏪 ${shop.designation}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Solde: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          '${calculatedBalance >= 0 ? "+" : ""}${calculatedBalance.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: calculatedBalance >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    if (initializedBalance > 0) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, size: 12, color: Colors.orange),
                          const SizedBox(width: 4),
                          Text(
                            'Initialisé: ',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          Text(
                            '${initializedBalance.toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '(Shop #${shop.id})',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Boutons Dépôt et Retrait
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showDepotDialog(client),
                            icon: const Icon(Icons.add_circle, size: 16),
                            label: const Text('Dépôt', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _showRetraitDialog(client),
                            icon: const Icon(Icons.remove_circle, size: 16),
                            label: const Text('Retrait', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                              minimumSize: const Size(0, 32),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Bouton Modifier
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      tooltip: 'Modifier',
                      onPressed: () => _editClient(client),
                    ),
                    // Bouton Initialiser Solde
                    IconButton(
                      icon: const Icon(Icons.account_balance_wallet, color: Colors.orange),
                      tooltip: 'Initialiser Solde',
                      onPressed: () => _initializeClientBalance(client),
                    ),
                    // Bouton Supprimer
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      tooltip: 'Supprimer',
                      onPressed: () => _deleteClient(client),
                    ),
                    // Bouton Relevé
                    IconButton(
                      icon: const Icon(Icons.receipt_long, color: Colors.purple),
                      tooltip: 'Voir le relevé',
                      onPressed: () => _showClientStatement(client, shop.designation),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showClientStatement(ClientModel client, String shopName) {
    setState(() {
      _selectedClient = client;
      _showReport = true;
      _startDate = null;
      _endDate = null;
    });
  }

  void _showCreateClientDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: Utilisateur non connecté'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => CreateClientDialogResponsive(
        shopId: currentUser.shopId ?? 0, // Peut être 0 pour l'admin
        agentId: currentUser.id ?? 0,
      ),
    ).then((result) {
      if (result == true) {
        // Recharger la liste des clients après création
        _loadData();
      }
    });
  }
  
  Widget _buildClientStatementSection(bool isMobile) {
    if (_selectedClient == null) return const SizedBox.shrink();
    
    return Expanded(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Modern header with gradient background
            Container(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF7C3AED), Color(0xFF9333EA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Back button and title row
                Row(
                  children: [
                    Material(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _showReport = false;
                            _selectedClient = null;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                              if (!isMobile) ...[
                                const SizedBox(width: 8),
                                const Text(
                                  'Retour',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _selectedClient!.nom,
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.phone, color: Colors.white70, size: 16),
                              const SizedBox(width: 6),
                              Text(
                                _selectedClient!.telephone,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                // Date filters - responsive layout (collapsible)
                const SizedBox(height: 16),
                Material(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_list, color: Colors.white, size: 18),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Filtrer par période',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(
                            _showFilters ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_showFilters) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        isMobile
                          ? Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildDateField(
                                  label: 'Date de début',
                                  date: _startDate,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _startDate = date;
                                      });
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                _buildDateField(
                                  label: 'Date de fin',
                                  date: _endDate,
                                  onTap: () async {
                                    final date = await showDatePicker(
                                      context: context,
                                      initialDate: _endDate ?? DateTime.now(),
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime.now(),
                                    );
                                    if (date != null) {
                                      setState(() {
                                        _endDate = date;
                                      });
                                    }
                                  },
                                ),
                              ],
                            )
                          : Row(
                              children: [
                                Expanded(
                                  child: _buildDateField(
                                    label: 'Date de début',
                                    date: _startDate,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _startDate ?? DateTime.now().subtract(const Duration(days: 30)),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _startDate = date;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildDateField(
                                    label: 'Date de fin',
                                    date: _endDate,
                                    onTap: () async {
                                      final date = await showDatePicker(
                                        context: context,
                                        initialDate: _endDate ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                      );
                                      if (date != null) {
                                        setState(() {
                                          _endDate = date;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                        if (_startDate != null || _endDate != null) ...[
                          const SizedBox(height: 12),
                          Material(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                });
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.clear, color: Colors.white, size: 16),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Réinitialiser',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Statement report - embedded mode (no internal scroll)
          ReleveCompteClientReport(
            key: ValueKey('${_selectedClient!.id}_${_startDate}_${_endDate}'),
            clientId: _selectedClient!.id!,
            startDate: _startDate,
            endDate: _endDate,
            isAdmin: true,
            embedded: true,
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white.withOpacity(0.2),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.calendar_today, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      date != null
                        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                        : 'Sélectionner...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDepotDialog(ClientModel client) {
    showDialog<bool>(
      context: context,
      builder: (context) => DepotDialog(preselectedClient: client),
    ).then((result) async {
      // Rafraîchir l'affichage après la fermeture du dialogue
      if (mounted && result == true) {
        // Recharger les opérations pour mettre à jour les soldes
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  void _showRetraitDialog(ClientModel client) {
    showDialog<bool>(
      context: context,
      builder: (context) => RetraitDialog(preselectedClient: client),
    ).then((result) async {
      // Rafraîchir l'affichage après la fermeture du dialogue
      if (mounted && result == true) {
        // Recharger les opérations pour mettre à jour les soldes
        final operationService = Provider.of<OperationService>(context, listen: false);
        await operationService.loadOperations();
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

  void _editClient(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => EditClientDialog(client: client),
    ).then((result) {
      if (result == true) {
        // Recharger les données après modification
        _loadData();
      }
    });
  }

  Future<void> _deleteClient(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le partenaire "${client.nom}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed == true && client.id != null) {
      final clientService = Provider.of<ClientService>(context, listen: false);
      final success = await clientService.deleteClient(client.id!, client.shopId ?? 0);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partenaire supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        // Recharger les données après suppression
        _loadData();
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${clientService.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _initializeClientBalance(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => InitializeBalanceDialog(client: client),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

}

