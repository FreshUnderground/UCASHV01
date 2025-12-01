import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';

/// Widget pour afficher la situation nette des partenaires
/// - Ceux qui nous doivent (solde négatif)
/// - Ceux que nous devons (solde positif)
class PartnerNetPositionWidget extends StatefulWidget {
  final int? shopId;

  const PartnerNetPositionWidget({
    super.key,
    this.shopId,
  });

  @override
  State<PartnerNetPositionWidget> createState() => _PartnerNetPositionWidgetState();
}

class _PartnerNetPositionWidgetState extends State<PartnerNetPositionWidget> {
  final _numberFormat = NumberFormat('#,##0.00', 'fr_FR');
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final clientService = Provider.of<ClientService>(context, listen: false);
    final operationService = Provider.of<OperationService>(context, listen: false);
    await Future.wait([
      clientService.loadClients(),
      operationService.loadOperations(),
    ]);
  }

  /// Calculer le solde réel d'un client à partir de ses opérations
  double _calculateClientBalance(int clientId, List<OperationModel> operations) {
    double balance = 0.0;
    
    for (final op in operations.where((o) => o.clientId == clientId)) {
      switch (op.type) {
        case OperationType.depot:
          // Dépôt augmente le solde du client
          balance += op.montantNet;
          break;
        case OperationType.retrait:
        case OperationType.retraitMobileMoney:
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Consumer3<ClientService, OperationService, ShopService>(
      builder: (context, clientService, operationService, shopService, child) {
        if (clientService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrer les clients par recherche uniquement (afficher tous les shops)
        var clients = clientService.clients.where((client) {
          if (_searchQuery.isNotEmpty) {
            return client.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                   client.telephone.contains(_searchQuery) ||
                   (client.numeroCompte?.contains(_searchQuery) ?? false);
          }
          return true;
        }).toList();

        // Calculer les soldes et séparer en deux catégories
        List<Map<String, dynamic>> partnersWeOwe = []; // Solde positif
        List<Map<String, dynamic>> partnersWhoOweUs = []; // Solde négatif

        for (final client in clients) {
          final balance = _calculateClientBalance(client.id!, operationService.operations);
          
          if (balance > 0) {
            partnersWeOwe.add({
              'client': client,
              'balance': balance,
            });
          } else if (balance < 0) {
            partnersWhoOweUs.add({
              'client': client,
              'balance': balance.abs(),
            });
          }
        }

        // Trier par montant décroissant
        partnersWeOwe.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));
        partnersWhoOweUs.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

        // Calculer les totaux
        final totalWeOwe = partnersWeOwe.fold(0.0, (sum, item) => sum + (item['balance'] as double));
        final totalWhoOweUs = partnersWhoOweUs.fold(0.0, (sum, item) => sum + (item['balance'] as double));
        final netPosition = totalWhoOweUs - totalWeOwe;

        return Column(
          children: [
            // En-tête et filtres
            _buildHeader(isMobile, shopService),
            
            const SizedBox(height: 16),
            
            // Résumé de la position nette
            _buildNetPositionSummary(totalWeOwe, totalWhoOweUs, netPosition, isMobile),
            
            const SizedBox(height: 16),
            
            // Listes des partenaires
            Expanded(
              child: isMobile 
                ? _buildMobileView(partnersWeOwe, partnersWhoOweUs, totalWeOwe, totalWhoOweUs)
                : _buildDesktopView(partnersWeOwe, partnersWhoOweUs, totalWeOwe, totalWhoOweUs),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile, ShopService shopService) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.balance,
                  color: const Color(0xFFDC2626),
                  size: isMobile ? 24 : 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Situation Nette des Partenaires',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loadData,
                  icon: const Icon(Icons.refresh),
                  color: const Color(0xFFDC2626),
                  tooltip: 'Actualiser',
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Filtre de recherche uniquement
            TextField(
              decoration: InputDecoration(
                labelText: 'Rechercher un partenaire (nom, téléphone, numéro de compte)',
                hintText: 'Entrez un nom, téléphone ou numéro de compte',
                prefixIcon: const Icon(Icons.search),
                border: const OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 8 : 12,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetPositionSummary(double totalWeOwe, double totalWhoOweUs, double netPosition, bool isMobile) {
    return Card(
      elevation: 4,
      color: netPosition >= 0 ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            Text(
              'Position Nette Globale',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  'Ils nous doivent',
                  totalWhoOweUs,
                  Colors.green,
                  Icons.arrow_downward,
                  isMobile,
                ),
                Container(
                  width: 2,
                  height: 60,
                  color: Colors.grey[300],
                ),
                _buildSummaryItem(
                  'Nous leur devons',
                  totalWeOwe,
                  Colors.red,
                  Icons.arrow_upward,
                  isMobile,
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  netPosition >= 0 ? Icons.trending_up : Icons.trending_down,
                  color: netPosition >= 0 ? Colors.green : Colors.red,
                  size: isMobile ? 24 : 32,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Position Nette',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${netPosition >= 0 ? '+' : ''}${_numberFormat.format(netPosition)} USD',
                      style: TextStyle(
                        fontSize: isMobile ? 20 : 28,
                        fontWeight: FontWeight.bold,
                        color: netPosition >= 0 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, IconData icon, bool isMobile) {
    return Column(
      children: [
        Icon(icon, color: color, size: isMobile ? 24 : 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            color: Colors.grey[600],
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          '${_numberFormat.format(amount)} USD',
          style: TextStyle(
            fontSize: isMobile ? 16 : 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopView(
    List<Map<String, dynamic>> partnersWeOwe,
    List<Map<String, dynamic>> partnersWhoOweUs,
    double totalWeOwe,
    double totalWhoOweUs,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildPartnerList(
            'Ceux qui nous doivent',
            partnersWhoOweUs,
            totalWhoOweUs,
            Colors.green,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPartnerList(
            'Ceux que nous devons',
            partnersWeOwe,
            totalWeOwe,
            Colors.red,
            Icons.arrow_upward,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileView(
    List<Map<String, dynamic>> partnersWeOwe,
    List<Map<String, dynamic>> partnersWhoOweUs,
    double totalWeOwe,
    double totalWhoOweUs,
  ) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            labelColor: const Color(0xFFDC2626),
            unselectedLabelColor: Colors.grey,
            indicatorColor: const Color(0xFFDC2626),
            tabs: const [
              Tab(
                icon: Icon(Icons.arrow_downward),
                text: 'Ils nous doivent',
              ),
              Tab(
                icon: Icon(Icons.arrow_upward),
                text: 'Nous leur devons',
              ),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildPartnerList(
                  'Ceux qui nous doivent',
                  partnersWhoOweUs,
                  totalWhoOweUs,
                  Colors.green,
                  Icons.arrow_downward,
                ),
                _buildPartnerList(
                  'Ceux que nous devons',
                  partnersWeOwe,
                  totalWeOwe,
                  Colors.red,
                  Icons.arrow_upward,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerList(
    String title,
    List<Map<String, dynamic>> partners,
    double total,
    Color color,
    IconData icon,
  ) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Card(
      elevation: 2,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: isMobile ? 20 : 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        '${partners.length} partenaire(s)',
                        style: TextStyle(
                          fontSize: isMobile ? 11 : 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${_numberFormat.format(total)} USD',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: partners.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 48, color: Colors.grey[300]),
                        const SizedBox(height: 8),
                        Text(
                          'Aucun partenaire dans cette catégorie',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    itemCount: partners.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = partners[index];
                      final client = item['client'] as ClientModel;
                      final balance = item['balance'] as double;
                      
                      return _buildPartnerItem(client, balance, color, isMobile);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerItem(ClientModel client, double balance, Color color, bool isMobile) {
    return Card(
      elevation: 1,
      margin: EdgeInsets.symmetric(vertical: isMobile ? 4 : 6),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              radius: isMobile ? 20 : 24,
              child: Text(
                client.nom[0].toUpperCase(),
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: isMobile ? 16 : 20,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Informations
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nom
                  Text(
                    client.nom,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 15 : 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Téléphone
                  Row(
                    children: [
                      Icon(Icons.phone, size: isMobile ? 14 : 16, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Text(
                        client.telephone,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  // Numéro de compte
                  if (client.numeroCompte != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.account_balance, size: isMobile ? 14 : 16, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Text(
                          client.numeroCompte!,
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Solde
            Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_numberFormat.format(balance)}',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  'USD',
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
