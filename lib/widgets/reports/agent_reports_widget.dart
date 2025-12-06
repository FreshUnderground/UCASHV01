import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../../services/shop_service.dart';
import '../../services/client_service.dart';
import '../../services/operation_service.dart';
import '../../models/shop_model.dart';
import '../../models/rapport_cloture_model.dart';
import '../../services/rapport_cloture_service.dart';
import 'report_filters_widget.dart';
import 'mouvements_caisse_report.dart';

import '../../widgets/rapport_cloture_widget.dart';
import '../../widgets/rapportcloture.dart';
import '../../widgets/flot_management_widget.dart';
import '../../widgets/cloture_agent_widget.dart';
import '../../services/rapportcloture_pdf_service.dart';
import 'releve_compte_client_report.dart';
import '../../widgets/frais_transfert_widget.dart'; // Add this import for Frais Transfert

class AgentReportsWidget extends StatefulWidget {
  const AgentReportsWidget({super.key});

  @override
  State<AgentReportsWidget> createState() => _AgentReportsWidgetState();
}

class _AgentReportsWidgetState extends State<AgentReportsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  DateTime? _startDate;
  DateTime? _endDate;

  final List<Map<String, dynamic>> _tabsData = [
    {'icon': Icons.account_balance, 'text': 'Caisse'},
    {'icon': Icons.lock, 'text': 'Clôtures'},
    {'icon': Icons.percent, 'text': 'Frais'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabsData.length, vsync: this);
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

        final isMobile = MediaQuery.of(context).size.width < 600;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.grey[50]!,
                Colors.white,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 0 : 24,
              vertical: isMobile ? 4 : 20,
            ),
            child: Column(
              children: [
                // Filtres (sans sélection de shop)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                  child: ReportFiltersWidget(
                    showShopFilter: false,
                    startDate: _startDate,
                    endDate: _endDate,
                    onDateRangeChanged: (start, end) {
                      setState(() {
                        _startDate = start;
                        _endDate = end;
                      });
                    },
                    onReset: () {
                      setState(() {
                        _startDate = null;
                        _endDate = null;
                      });
                    },
                  ),
                ),
                
                SizedBox(height: isMobile ? 4 : 20),
                
                // Onglets
                Container(
                  margin: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                  height: isMobile ? 80 : 120,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(isMobile ? 20 : 24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.12),
                        blurRadius: isMobile ? 16 : 24,
                        offset: Offset(0, isMobile ? 4 : 6),
                        spreadRadius: -2,
                      ),
                    ],
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.15),
                      width: 1.5,
                    ),
                  ),
                  child: 
                  
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 20, vertical: isMobile ? 10 : 14),
                    tabAlignment: TabAlignment.center,
                    tabs: _tabsData.map((tabData) {
                      return Tab(
                        icon: Icon(tabData['icon'] as IconData, size: isMobile ? 25 : 42),
                        text: tabData['text'] as String,
                        height: isMobile ? 70 : 100,
                      );
                    }).toList(),
                    labelColor: const Color(0xFFDC2626),
                    unselectedLabelColor: Colors.grey[600],
                    labelStyle: TextStyle(
                      fontSize: isMobile ? 14 : 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                    ),
                    unselectedLabelStyle: TextStyle(
                      fontSize: isMobile ? 13 : 15,
                      fontWeight: FontWeight.w500,
                    ),
                    indicator: BoxDecoration(
                      borderRadius: BorderRadius.circular(isMobile ? 18 : 22),
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFDC2626).withOpacity(0.18),
                          const Color(0xFFDC2626).withOpacity(0.10),
                        ],
                      ),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                  ),
                ),
                
                SizedBox(height: isMobile ? 4 : 20),
                
                // Contenu des onglets
                Flexible(
                  fit: FlexFit.loose,
                  child: Container(
                    margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.08),
                          blurRadius: isMobile ? 10 : 20,
                          offset: Offset(0, isMobile ? 2 : 4),
                          spreadRadius: -4,
                        ),
                      ],
                      border: Border.all(
                        color: Colors.grey.withOpacity(0.1),
                        width: 1,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isMobile ? 14 : 20),
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
                              
                          // Gestion des clôtures
                          user.shopId != null
                            ? ClotureAgentWidget(shopId: user.shopId!)
                            : _buildNoShopAssignedError(),
                              
                          // Frais - Liste des frais de transfert
                          user.shopId != null
                            ? FraisTransfertWidget(
                                shopId: user.shopId!,
                              )
                            : _buildNoShopAssignedError(),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(height: isMobile ? 8 : 0),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoShopAssignedError() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange[100]!, Colors.orange[50]!],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: isMobile ? 12 : 20,
                    offset: Offset(0, isMobile ? 4 : 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: isMobile ? 30 : 64,
                color: Colors.orange[700],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),
            Text(
              'Shop Non Assigné',
              style: TextStyle(
                fontSize: isMobile ? 18 : 24,
                fontWeight: FontWeight.bold,
                color: Colors.orange[900],
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              'Cet agent n\'est assigné à aucun shop.',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 6 : 8),
            Text(
              'Contactez l\'administrateur pour assigner un shop à cet agent.',
              style: TextStyle(
                fontSize: isMobile ? 12 : 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isMobile ? 20 : 32),
            ElevatedButton.icon(
              onPressed: () {
                setState(() {});
              },
              icon: Icon(Icons.refresh, size: isMobile ? 18 : 20),
              label: Text('Actualiser', style: TextStyle(fontSize: isMobile ? 14 : 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 32,
                  vertical: isMobile ? 12 : 16,
                ),
                elevation: 4,
                shadowColor: Colors.orange.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoShopError() {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 20 : 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.grey[50]!,
            Colors.white,
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red[100]!, Colors.red[50]!],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.3),
                    blurRadius: isMobile ? 12 : 20,
                    offset: Offset(0, isMobile ? 4 : 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline,
                size: isMobile ? 48 : 64,
                color: Colors.red[700],
              ),
            ),
            SizedBox(height: isMobile ? 16 : 24),
            Text(
              'Erreur de configuration',
              style: TextStyle(
                fontSize: isMobile ? 20 : 28,
                fontWeight: FontWeight.bold,
                color: Colors.red[800],
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            Text(
              'Aucun shop assigné à cet agent.\nContactez l\'administrateur.',
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                color: Colors.grey[700],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClotureReport(int shopId) {
    return RapportCloture(shopId: shopId);
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
                      Text('Chargement des partenaires...'),
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
                      Text('Aucun partenaire trouvé'),
                      SizedBox(height: 8),
                      Text('Créez des partenaires pour voir leurs relevés de compte'),
                    ],
                  ),
                ),
              )
            else
              Flexible(
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
                hint: const Text('Choisissez un partenaire'),
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
                  labelText: 'Partenaire',
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
          Flexible(
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

class RapportClotureEmbedded extends StatefulWidget {
  final int? shopId;
  
  const RapportClotureEmbedded({super.key, this.shopId});

  @override
  State<RapportClotureEmbedded> createState() => _RapportClotureEmbeddedState();
}

class _RapportClotureEmbeddedState extends State<RapportClotureEmbedded> {
  DateTime _selectedDate = DateTime.now();
  RapportClotureModel? _rapport;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _genererRapport();
    });
  }

  Future<void> _genererRapport() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      // Charger les opérations de "Mes Ops" pour ce shop
      await operationService.loadOperations(shopId: shopId);
      if (!mounted) return;
      
      final rapport = await RapportClotureService.instance.genererRapport(
        shopId: shopId,
        date: _selectedDate,
        generePar: authService.currentUser?.username ?? 'Admin',
        operations: operationService.operations, // Utiliser les données de "Mes Ops"
      );
      if (!mounted) return;

      setState(() {
        _rapport = rapport;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sélection de date
          _buildDateSelector(isMobile),
          const SizedBox(height: 16),

          // Contenu du rapport
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            _buildError(_errorMessage!)
          else if (_rapport != null)
            _buildRapport(_rapport!, isMobile)
          else
            const Center(child: Text('Aucun rapport disponible')),
        ],
      ),
    );
  }

  Widget _buildDateSelector(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFFDC2626)),
            const SizedBox(width: 8),
            const Text(
              'Date du rapport:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _selectedDate = date);
                  _genererRapport();
                }
              },
              icon: const Icon(Icons.edit_calendar, size: 16),
              label: const Text('Changer', style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildRapport(RapportClotureModel rapport, bool isMobile) {
    return Column(
      children: [
        // En-tête
        _buildSection(
          'Shop: ${rapport.shopDesignation}',
          [
            Text(
              'Rapport du ${rapport.dateRapport.day}/${rapport.dateRapport.month}/${rapport.dateRapport.year}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
          Colors.blue,
        ),
        const SizedBox(height: 12),

        // Cash Disponible (TOTAL)
        _buildCashDisponibleCard(rapport),
        const SizedBox(height: 12),

        // Détails par section
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLeftColumn(rapport)),
              const SizedBox(width: 12),
              Expanded(child: _buildRightColumn(rapport)),
            ],
          )
        else
          Column(
            children: [
              _buildLeftColumn(rapport),
              const SizedBox(height: 12),
              _buildRightColumn(rapport),
            ],
          ),
        
        const SizedBox(height: 16),
        
        // Capital Net Final
        _buildCapitalNetCard(rapport),
      ],
    );
  }

  Widget _buildCashDisponibleCard(RapportClotureModel rapport) {
    return Card(
      elevation: 4,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '💰 CASH DISPONIBLE TOTAL',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${rapport.cashDisponibleTotal.toStringAsFixed(2)} USD',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 4),
            _buildCashBreakdown('Cash', rapport.cashDisponibleCash),
            _buildCashBreakdown('Airtel Money', rapport.cashDisponibleAirtelMoney),
            _buildCashBreakdown('M-Pesa', rapport.cashDisponibleMPesa),
            _buildCashBreakdown('Orange Money', rapport.cashDisponibleOrangeMoney),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalNetCard(RapportClotureModel rapport) {
    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              '📈 CAPITAL NET FINAL',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Formule: Cash Disponible + Ceux qui Nous qui Doivent - Ceux que Nous que Devons',
              style: TextStyle(
                fontSize: 10,
                fontStyle: FontStyle.italic,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              '${rapport.capitalNet.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: rapport.capitalNet >= 0 ? Colors.blue[700] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 6),
            _buildCapitalBreakdown('Cash Disponible', rapport.cashDisponibleTotal, Colors.green),
            _buildCapitalBreakdown('+ Partenaires Servis', rapport.totalClientsNousDoivent, Colors.red),
            _buildCapitalBreakdown('+ Shops Nous qui Doivent', rapport.totalShopsNousDoivent, Colors.orange),
            _buildCapitalBreakdown('- Dépôts Partenaires', -rapport.totalClientsNousDevons, Colors.green),
            _buildCapitalBreakdown('- Shops Nous que Devons', -rapport.totalShopsNousDevons, Colors.purple),
            const SizedBox(height: 6),
            const Divider(thickness: 2),
            const SizedBox(height: 6),
            _buildCapitalBreakdown('= CAPITAL NET', rapport.capitalNet, rapport.capitalNet >= 0 ? Colors.blue : Colors.red, bold: true),
          ],
        ),
      ),
    );
  }

  Widget _buildCashBreakdown(String label, double montant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCapitalBreakdown(String label, double montant, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: bold ? 14 : 12,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 14 : 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        _buildSection(
          '1️⃣ Solde Antérieur',
          [
            _buildLine('Cash', rapport.soldeAnterieurCash),
            _buildLine('Airtel Money', rapport.soldeAnterieurAirtelMoney),
            _buildLine('M-Pesa', rapport.soldeAnterieurMPesa),
            _buildLine('Orange Money', rapport.soldeAnterieurOrangeMoney),
            const Divider(),
            _buildLine('TOTAL', rapport.soldeAnterieurTotal, bold: true),
          ],
          Colors.grey,
        ),
        const SizedBox(height: 12),
        _buildSection(
          '2️⃣ Flots',
          [
            _buildLine('Reçus', rapport.flotRecu, color: Colors.green),
            _buildLine('Envoyés', rapport.flotEnvoye, color: Colors.red, prefix: '-'),
          ],
          Colors.purple,
        ),
        const SizedBox(height: 12),
        _buildSection(
          '3️⃣ Transferts',
          [
            _buildLine('Reçus', rapport.transfertsRecus, color: Colors.green),
            _buildLine('Servis', rapport.transfertsServis, color: Colors.red, prefix: '-'),
          ],
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildRightColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        // Masqué: Opérations Clients
        // Partenaires Servis (anciennement Clients Nous qui Doivent)
        _buildSection(
          '5️⃣ Partenaires Servis',
          [
            Text(
              '${rapport.clientsNousDoivent.length} partenaire(s)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ...rapport.clientsNousDoivent.take(3).map((client) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(client.nom, style: const TextStyle(fontSize: 10))),
                  Text(
                    '${client.solde.toStringAsFixed(2)} USD',
                    style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
            if (rapport.clientsNousDoivent.length > 3)
              Text('... et ${rapport.clientsNousDoivent.length - 3} autre(s)', style: const TextStyle(fontSize: 10)),
            const Divider(),
            _buildLine('TOTAL', rapport.totalClientsNousDoivent, color: Colors.red),
          ],
          Colors.red,
        ),
        const SizedBox(height: 12),
        // Dépôts Partenaires (anciennement Clients Nous que Devons)
        _buildSection(
          '6️⃣ Dépôts Partenaires',
          [
            Text(
              '${rapport.clientsNousDevons.length} partenaire(s)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(height: 4),
            ...rapport.clientsNousDevons.take(3).map((client) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 1),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(client.nom, style: const TextStyle(fontSize: 10))),
                  Text(
                    '${client.solde.toStringAsFixed(2)} USD',
                    style: const TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
            if (rapport.clientsNousDevons.length > 3)
              Text('... et ${rapport.clientsNousDevons.length - 3} autre(s)', style: const TextStyle(fontSize: 10)),
            const Divider(),
            _buildLine('TOTAL', rapport.totalClientsNousDevons, color: Colors.green),
          ],
          Colors.green,
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildLine(String label, double montant, {bool bold = false, Color? color, String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 14 : 12,
            ),
          ),
          Text(
            '$prefix${montant.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 14 : 12,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
