import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ucashv01/widgets/reports/releve_compte_client_report.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';

/// Widget pour que l'admin puisse voir tous les clients et leurs relevés
class AdminClientsWidget extends StatefulWidget {
  const AdminClientsWidget({super.key});

  @override
  State<AdminClientsWidget> createState() => _AdminClientsWidgetState();
}

class _AdminClientsWidgetState extends State<AdminClientsWidget> {
  String _searchQuery = '';
  int? _filterShopId;
  bool _showOnlyActive = true;
  ClientModel? _selectedClient;
  DateTime? _startDate;
  DateTime? _endDate;
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
    
    await Future.wait([
      clientService.loadClients(),
      shopService.loadShops(),
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
            _buildFilters(isMobile),
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
                'Gestion des Partenaires',
                style: TextStyle(
                  fontSize: isMobile ? 20 : 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Vue d\'ensemble de tous les partenaires',
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ],
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
                          labelText: 'Filtrer par Shop',
                          border: OutlineInputBorder(),
                        ),
                        value: _filterShopId,
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tous les shops'),
                          ),
                          ...shopService.shops.map((shop) => DropdownMenuItem<int?>(
                            value: shop.id,
                            child: Text(shop.designation),
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
                    const Text('Afficher uniquement les partenaires actifs'),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClientsList(bool isMobile) {
    return Consumer2<ClientService, ShopService>(
      builder: (context, clientService, shopService, child) {
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
                   client.numeroCompte?.toLowerCase().contains(_searchQuery) == true;
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

            return Card(
              margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: client.solde >= 0 ? Colors.green : Colors.red,
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
                    Text('📞 ${client.telephone}'),
                    if (client.numeroCompte != null)
                      Text('💳 ${client.numeroCompte}'),
                    Text('🏪 ${shop.designation}'),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Solde: ',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        Text(
                          '${client.solde >= 0 ? "+" : ""}${client.solde.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: client.solde >= 0 ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.receipt_long, color: Colors.purple),
                  tooltip: 'Voir le relevé',
                  onPressed: () => _showClientStatement(client, shop.designation),
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
  
  Widget _buildClientStatementSection(bool isMobile) {
    if (_selectedClient == null) return const SizedBox.shrink();
    
    return Expanded(
      child: Column(
        children: [
          // En-tête avec bouton retour
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.purple.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.purple.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _showReport = false;
                      _selectedClient = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back, color: Colors.purple),
                  tooltip: 'Retour à la liste',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relevé de ${_selectedClient!.nom}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                      Text(
                        '📞 ${_selectedClient!.telephone}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Filtres de dates
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
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    decoration: const InputDecoration(
                      labelText: 'Date de début',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
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
                      prefixIcon: Icon(Icons.calendar_today),
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
          ),
          const SizedBox(height: 16),
          
          // Relevé de compte
          Expanded(
            child: ReleveCompteClientReport(
              clientId: _selectedClient!.id!,
              startDate: _startDate,
              endDate: _endDate,
            ),
          ),
        ],
      ),
    );
  }

}

