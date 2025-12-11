import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/client_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';

/// Widget pour afficher la situation nette des partenaires
/// - Ceux qui Nous qui Doivent (solde négatif)
/// - Ceux que Nous que Devons (solde positif)
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
                   client.numeroCompteFormate.contains(_searchQuery);
          }
          return true;
        }).toList();

        // Calculer les soldes et séparer en deux catégories
        // IMPORTANT: Solde négatif (-) = Ils Nous qui Doivent, Solde positif (+) = Nous leur devons
        List<Map<String, dynamic>> partnersWeOwe = []; // Solde positif (+) = Nous leur devons
        List<Map<String, dynamic>> partnersWhoOweUs = []; // Solde négatif (-) = Ils Nous qui Doivent

        for (final client in clients) {
          final balance = _calculateClientBalance(client.id!, operationService.operations);
          
          if (balance > 0) {
            // Solde POSITIF = Nous leur devons (le client a plus déposé que retiré)
            partnersWeOwe.add({
              'client': client,
              'balance': balance,
            });
          } else if (balance < 0) {
            // Solde NÉGATIF = Ils Nous qui Doivent (le client a plus retiré que déposé)
            partnersWhoOweUs.add({
              'client': client,
              'balance': balance.abs(), // Afficher en valeur absolue
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

        return CustomScrollView(
          slivers: [
            // En-tête et filtres
            SliverToBoxAdapter(
              child: _buildHeader(isMobile, shopService),
            ),
            
            SliverToBoxAdapter(
              child: const SizedBox(height: 16),
            ),
            
            // Résumé de la position nette
            SliverToBoxAdapter(
              child: _buildNetPositionSummary(totalWeOwe, totalWhoOweUs, netPosition, isMobile),
            ),
            
            SliverToBoxAdapter(
              child: const SizedBox(height: 16),
            ),
            
            // Listes des partenaires
            SliverFillRemaining(
              hasScrollBody: true,
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
                  'Ils Nous qui Doivent',
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
            'Ceux qui Nous qui Doivent',
            partnersWhoOweUs,
            totalWhoOweUs,
            Colors.green,
            Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildPartnerList(
            'Ceux que Nous que Devons',
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
          Material(
            color: Colors.white,
            elevation: 2,
            child: TabBar(
              labelColor: const Color(0xFFDC2626),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFFDC2626),
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(
                  icon: Icon(Icons.arrow_downward, size: 20),
                  text: 'Ils Nous qui Doivent',
                ),
                Tab(
                  icon: Icon(Icons.arrow_upward, size: 20),
                  text: 'Nous leur devons',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPartnerList(
                  'Ceux qui Nous qui Doivent',
                  partnersWhoOweUs,
                  totalWhoOweUs,
                  Colors.green,
                  Icons.arrow_downward,
                ),
                _buildPartnerList(
                  'Ceux que Nous que Devons',
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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isMobile ? 8 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  color.withOpacity(0.1),
                  color.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: isMobile ? 20 : 24),
                ),
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
                      const SizedBox(height: 2),
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
                        fontWeight: FontWeight.w500,
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
          Divider(height: 1, color: Colors.grey[200]),
          // List
          Expanded(
            child: partners.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun partenaire',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'dans cette catégorie',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.all(isMobile ? 8 : 12),
                    itemCount: partners.length,
                    itemBuilder: (context, index) {
                      final item = partners[index];
                      final client = item['client'] as ClientModel;
                      final balance = item['balance'] as double;
                      
                      return _buildPartnerItem(client, balance, color, isMobile, index);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnerItem(ClientModel client, double balance, Color color, bool isMobile, int index) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            // Optionally add navigation or details
          },
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Avatar
                Container(
                  width: isMobile ? 48 : 56,
                  height: isMobile ? 48 : 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        color.withOpacity(0.3),
                        color.withOpacity(0.15),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      client.nom[0].toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: isMobile ? 20 : 24,
                      ),
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
                          color: Colors.grey[900],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      // Téléphone
                      Row(
                        children: [
                          Icon(
                            Icons.phone_rounded,
                            size: isMobile ? 14 : 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            client.telephone,
                            style: TextStyle(
                              fontSize: isMobile ? 12 : 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      // Numéro de compte
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.credit_card,
                            size: isMobile ? 14 : 16,
                            color: Colors.grey[500],
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              client.numeroCompteFormate,
                              style: TextStyle(
                                fontSize: isMobile ? 12 : 13,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Solde
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 10 : 12,
                    vertical: isMobile ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
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
                          fontSize: isMobile ? 10 : 11,
                          color: color.withOpacity(0.7),
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
      ),
    );
  }
}
