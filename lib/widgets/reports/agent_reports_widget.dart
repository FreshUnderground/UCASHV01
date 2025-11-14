import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/shop_service.dart';
import '../../services/client_service.dart';
import '../../models/shop_model.dart';
import 'report_filters_widget.dart';
import 'mouvements_caisse_report.dart';
import 'commissions_report.dart';
import 'evolution_capital_report.dart';
import '../../widgets/rapport_cloture_widget.dart';
import '../../widgets/flot_management_widget.dart';
import 'releve_compte_client_report.dart';

class AgentReportsWidget extends StatefulWidget {
  const AgentReportsWidget({super.key});

  @override
  State<AgentReportsWidget> createState() => _AgentReportsWidgetState();
}

class _AgentReportsWidgetState extends State<AgentReportsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showFilters = true; // Toggle pour afficher/cacher les filtres

  final List<Tab> _tabs = [
    const Tab(icon: Icon(Icons.account_balance), text: 'Mouvements de Caisse'),
    const Tab(icon: Icon(Icons.monetization_on), text: 'Commissions'),
    const Tab(icon: Icon(Icons.trending_up), text: 'Capital du Shop'),
    const Tab(icon: Icon(Icons.receipt_long), text: 'Clôture Journalière'),
    const Tab(icon: Icon(Icons.local_shipping), text: 'Mouvements FLOT'),
    const Tab(icon: Icon(Icons.account_circle), text: 'Relevés Clients'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final user = authService.currentUser;
        if (user == null || user.shopId == null) {
          return _buildNoShopError();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header avec titre et filtres
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec bouton toggle filtres
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        color: Colors.blue[700],
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Rapports Agent',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store, color: Colors.blue[700], size: 16),
                            const SizedBox(width: 4),
                            Consumer<ShopService>(
                              builder: (context, shopService, child) {
                                if (user.shopId == null) {
                                  return Text(
                                    'Shop: ⚠️ Non assigné',
                                    style: TextStyle(
                                      color: Colors.red[700],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  );
                                }
                                
                                final shop = shopService.shops.firstWhere(
                                  (s) => s.id == user.shopId,
                                  orElse: () => ShopModel(designation: '⚠️ Introuvable', localisation: ''),
                                );
                                
                                final isShopFound = shopService.shops.any((s) => s.id == user.shopId);
                                return Text(
                                  shop.designation,
                                  style: TextStyle(
                                    color: isShopFound ? Colors.blue[700] : Colors.red[700],
                                    fontSize: 12,
                                    fontWeight: isShopFound ? FontWeight.w600 : FontWeight.bold,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _showFilters = !_showFilters;
                          });
                        },
                        icon: Icon(
                          _showFilters ? Icons.filter_list_off : Icons.filter_list,
                          color: const Color(0xFFDC2626),
                        ),
                        tooltip: _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
                        style: IconButton.styleFrom(
                          backgroundColor: _showFilters ? Colors.red.shade50 : Colors.grey.shade100,
                        ),
                      ),
                    ],
                  ),
                  
                  // Filtres (avec animation)
                  if (_showFilters) ...[
                    const SizedBox(height: 16),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      child: ReportFiltersWidget(
                        showShopFilter: false,
                        startDate: _startDate,
                        endDate: _endDate,
                        onDateRangeChanged: (start, end) {
                          setState(() {
                            _startDate = start;
                            _endDate = end;
                          });
                          _refreshCurrentReport();
                        },
                        onReset: () {
                          setState(() {
                            _startDate = null;
                            _endDate = null;
                          });
                          _refreshCurrentReport();
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Onglets
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                tabs: _tabs,
                labelColor: const Color(0xFFDC2626),
                unselectedLabelColor: Colors.grey[600],
                indicatorColor: const Color(0xFFDC2626),
                onTap: (index) => _refreshCurrentReport(),
              ),
            ),
            
            // Contenu des onglets - Hauteur fixe
            SizedBox(
              height: 500,
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Mouvements de caisse du shop de l'agent
                  user.shopId != null 
                    ? MouvementsCaisseReport(
                        shopId: user.shopId!,
                        startDate: _startDate,
                        endDate: _endDate,
                        showAllShops: false,
                      )
                    : _buildNoShopAssignedError(),
                  
                  // Commissions du shop de l'agent
                  user.shopId != null
                    ? CommissionsReport(
                        shopId: user.shopId!,
                        startDate: _startDate,
                        endDate: _endDate,
                        showAllShops: false,
                      )
                    : _buildNoShopAssignedError(),
                  
                  // Capital du shop de l'agent
                  user.shopId != null
                    ? EvolutionCapitalReport(
                        shopId: user.shopId!,
                        startDate: _startDate,
                        endDate: _endDate,
                        showAllShops: false,
                      )
                    : _buildNoShopAssignedError(),
                  
                  // Rapport de clôture journalière
                  user.shopId != null
                    ? _buildClotureReport(user.shopId!)
                    : _buildNoShopAssignedError(),
                  
                  // Mouvements FLOT
                  user.shopId != null
                    ? _buildFlotReport(user.shopId!)
                    : _buildNoShopAssignedError(),
                  
                  // Relevés Clients
                  user.shopId != null
                    ? _buildClientStatements(user.shopId!)
                    : _buildNoShopAssignedError(),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoShopAssignedError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 64,
            color: Colors.orange[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Shop Non Assigné',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.orange[800],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Cet agent n\'est assigné à aucun shop.',
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          const Text(
            'Contactez l\'administrateur pour assigner un shop à cet agent.',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Recharger les données
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Actualiser'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoShopError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de configuration',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun shop assigné à cet agent.\nContactez l\'administrateur.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildClotureReport(int shopId) {
    return RapportClotureWidget(shopId: shopId);
  }

  Widget _buildFlotReport(int shopId) {
    // Pour les rapports FLOT, on peut afficher le widget de gestion avec un filtre
    return const FlotManagementWidget();
  }

  void _refreshCurrentReport() {
    // Déclencher le rechargement du rapport actuel
    setState(() {});
  }
  
  Widget _buildClientStatements(int shopId) {
    return Consumer<ClientService>(
      builder: (context, clientService, child) {
        // Charger les clients si ce n'est pas déjà fait
        if (!clientService.isLoading && clientService.clients.isEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            clientService.loadClients();
          });
        }
        
        return Column(
          children: [
            if (clientService.isLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Chargement des clients...'),
                    ],
                  ),
                ),
              )
            else if (clientService.errorMessage != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Erreur: ${clientService.errorMessage}',
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => clientService.loadClients(),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              )
            else if (clientService.clients.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('Aucun client trouvé'),
                      SizedBox(height: 8),
                      Text('Créez des clients pour voir leurs relevés de compte'),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ClientStatementsView(
                  clients: clientService.clients,
                  shopId: shopId,
                ),
              ),
          ],
        );
      },
    );
  }
}

class ClientStatementsView extends StatefulWidget {
  final List<dynamic> clients;
  final int shopId;

  const ClientStatementsView({
    super.key,
    required this.clients,
    required this.shopId,
  });

  @override
  State<ClientStatementsView> createState() => _ClientStatementsViewState();
}

class _ClientStatementsViewState extends State<ClientStatementsView> {
  dynamic _selectedClient;
  DateTime? _startDate;
  DateTime? _endDate;
  bool _showReport = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Client selection and filters
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 3,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sélectionnez un client',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 16),
              // Client dropdown
              DropdownButtonFormField<dynamic>(
                value: _selectedClient,
                hint: const Text('Choisissez un client'),
                items: widget.clients.map<DropdownMenuItem<dynamic>>((client) {
                  return DropdownMenuItem(
                    value: client,
                    child: Text('${client.nom ?? ''} (${client.telephone ?? ''})'),
                  );
                }).toList(),
                onChanged: (client) {
                  setState(() {
                    _selectedClient = client;
                    _showReport = false;
                  });
                },
                decoration: const InputDecoration(
                  labelText: 'Client',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // Date filters
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Date de début',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
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
                      controller: TextEditingController(
                        text: _startDate != null 
                          ? '${_startDate!.day}/${_startDate!.month}/${_startDate!.year}' 
                          : '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Date de fin',
                        border: OutlineInputBorder(),
                      ),
                      readOnly: true,
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
                      controller: TextEditingController(
                        text: _endDate != null 
                          ? '${_endDate!.day}/${_endDate!.month}/${_endDate!.year}' 
                          : '',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // View button
              Center(
                child: ElevatedButton(
                  onPressed: _selectedClient != null
                      ? () {
                          setState(() {
                            _showReport = true;
                          });
                        }
                      : null,
                  child: const Text('Voir le relevé'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Report display
        if (_showReport && _selectedClient != null)
          Expanded(
            child: ReleveCompteClientReport(
              clientId: _selectedClient.id as int,
              startDate: _startDate,
              endDate: _endDate,
            ),
          ),
      ],
    );
  }
}