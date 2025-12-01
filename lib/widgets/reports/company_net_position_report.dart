import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/shop_service.dart';
import '../../services/client_service.dart';
import '../../services/operation_service.dart';
import '../../services/compte_special_service.dart';
import '../../services/rapport_cloture_service.dart';
import '../../models/shop_model.dart';
import '../../models/client_model.dart';
import '../../models/operation_model.dart';
import '../../models/compte_special_model.dart';

/// Widget pour afficher la Situation Nette de l'Entreprise
/// - Capital Net par Shop
/// - Liste des partenaires qui nous doivent
/// - Liste des partenaires que nous devons
/// - Total des frais retirés
class CompanyNetPositionReport extends StatefulWidget {
  const CompanyNetPositionReport({super.key});

  @override
  State<CompanyNetPositionReport> createState() => _CompanyNetPositionReportState();
}

class _CompanyNetPositionReportState extends State<CompanyNetPositionReport> {
  final _numberFormat = NumberFormat('#,##0.00', 'fr_FR');
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final clientService = Provider.of<ClientService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      final compteSpecialService = CompteSpecialService.instance;

      await Future.wait([
        shopService.loadShops(),
        clientService.loadClients(),
        operationService.loadOperations(),
        compteSpecialService.loadTransactions(),
      ]);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Calculer le capital net d'un shop selon la formule de clôture
  /// Capital Net = Cash Disponible + Créances (clients + shops) - Dettes (clients + shops)
  /// UTILISE LA MÊME FORMULE QUE LE RAPPORT DE CLÔTURE JOURNALIÈRE
  Future<Map<String, dynamic>> _calculateShopNetCapitalDetails(
    ShopModel shop,
    List<OperationModel> operations,
    List<ClientModel> clients,
  ) async {
    final shopId = shop.id!;
    
    // 1. Générer le rapport de clôture pour ce shop à la date sélectionnée
    // Cela calculera automatiquement le Cash Disponible avec la formule correcte
    final rapport = await RapportClotureService.instance.genererRapport(
      shopId: shopId,
      date: _selectedDate,
      generePar: 'Situation Nette Entreprise',
      operations: operations,
    );
    
    // Utiliser le Cash Disponible calculé par le rapport de clôture
    final cashDisponible = rapport.cashDisponibleTotal;
    
    // 2. Calculer les créances/dettes clients
    double clientsNousDoivent = 0.0;
    double clientsNousDevons = 0.0;
    final List<Map<String, dynamic>> clientsCreances = [];
    final List<Map<String, dynamic>> clientsDettes = [];
    
    for (final client in clients) {
      final balance = _calculateClientBalance(client.id!, operations);
      
      if (balance < 0) {
        // Le client nous doit (balance négatif = créance)
        clientsNousDoivent += balance.abs();
        clientsCreances.add({
          'client': client,
          'montant': balance.abs(),
        });
      } else if (balance > 0) {
        // Nous devons au client (balance positif = dette)
        clientsNousDevons += balance;
        clientsDettes.add({
          'client': client,
          'montant': balance,
        });
      }
    }
    
    // 3. Calculer les créances/dettes inter-shops
    double shopsNousDoivent = 0.0;
    double shopsNousDevons = 0.0;
    final Map<int, double> soldesParShop = {};
    
    // Transferts nationaux
    for (final op in operations.where((o) => 
        o.type == OperationType.transfertNational &&
        (o.shopSourceId == shopId || o.shopDestinationId == shopId))) {
      
      if (op.shopSourceId == shopId) {
        // Ce shop a reçu le transfert du client → doit le montant brut au shop destination
        final destId = op.shopDestinationId!;
        soldesParShop[destId] = (soldesParShop[destId] ?? 0) - op.montantBrut;
      }
      
      if (op.shopDestinationId == shopId) {
        // Ce shop doit servir le transfert → créance sur le shop source
        final srcId = op.shopSourceId!;
        soldesParShop[srcId] = (soldesParShop[srcId] ?? 0) + op.montantBrut;
      }
    }
    
    // Séparer les créances et dettes shops
    for (final entry in soldesParShop.entries) {
      if (entry.value > 0) {
        shopsNousDoivent += entry.value;
      } else if (entry.value < 0) {
        shopsNousDevons += entry.value.abs();
      }
    }
    
    // 4. Le Capital Net est déjà calculé par le rapport de clôture avec la formule correcte
    // CAPITAL NET = CASH DISPONIBLE + CRÉANCES - DETTES
    final capitalNet = rapport.capitalNet;
    
    return {
      'shop': shop,
      'cashDisponible': cashDisponible,
      'clientsNousDoivent': clientsNousDoivent,
      'clientsNousDevons': clientsNousDevons,
      'shopsNousDoivent': shopsNousDoivent,
      'shopsNousDevons': shopsNousDevons,
      'capitalNet': capitalNet,
      'clientsCreances': clientsCreances,
      'clientsDettes': clientsDettes,
    };
  }

  /// Calculer le solde d'un client
  double _calculateClientBalance(int clientId, List<OperationModel> operations) {
    double balance = 0.0;
    
    for (final op in operations.where((o) => o.clientId == clientId)) {
      switch (op.type) {
        case OperationType.depot:
          balance += op.montantNet;
          break;
        case OperationType.retrait:
        case OperationType.retraitMobileMoney:
          balance -= op.montantNet;
          break;
        case OperationType.transfertNational:
        case OperationType.transfertInternationalSortant:
          balance -= op.montantBrut;
          break;
        case OperationType.transfertInternationalEntrant:
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

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(isMobile),
                  const SizedBox(height: 24),
                  _buildDateSelector(isMobile),
                  const SizedBox(height: 24),
                  _buildCompanyNetPosition(isMobile),
                ],
              ),
            ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Icon(
          Icons.business,
          size: isMobile ? 28 : 32,
          color: const Color(0xFFDC2626),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'Situation Nette de l\'Entreprise',
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
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
    );
  }

  Widget _buildDateSelector(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate)}',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                }
              },
              icon: const Icon(Icons.edit_calendar, size: 18),
              label: const Text('Changer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyNetPosition(bool isMobile) {
    return Consumer3<ShopService, ClientService, OperationService>(
      builder: (context, shopService, clientService, operationService, child) {
        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _calculateAllShopsCapital(
            shopService.shops,
            operationService.operations,
            clientService.clients,
          ),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final shopCapitals = snapshot.data!;
            double totalCompanyCapital = 0.0;
            double totalCashDisponible = 0.0;
            double totalClientsNousDoivent = 0.0;
            double totalClientsNousDevons = 0.0;
            double totalShopsNousDoivent = 0.0;
            double totalShopsNousDevons = 0.0;

            for (final details in shopCapitals) {
              totalCompanyCapital += details['capitalNet'] as double;
              totalCashDisponible += details['cashDisponible'] as double;
              totalClientsNousDoivent += details['clientsNousDoivent'] as double;
              totalClientsNousDevons += details['clientsNousDevons'] as double;
              totalShopsNousDoivent += details['shopsNousDoivent'] as double;
              totalShopsNousDevons += details['shopsNousDevons'] as double;
            }

        // Trier par capital net décroissant
        shopCapitals.sort((a, b) => (b['capitalNet'] as double).compareTo(a['capitalNet'] as double));

        // 2. Partenaires qui nous doivent / que nous devons
        final partnersWhoOweUs = <Map<String, dynamic>>[];
        final partnersWeOwe = <Map<String, dynamic>>[];
        double totalPartnersOweUs = 0.0;
        double totalWeOwePartners = 0.0;

        for (final client in clientService.clients) {
          final balance = _calculateClientBalance(client.id!, operationService.operations);
          
          if (balance < 0) {
            partnersWhoOweUs.add({'client': client, 'balance': balance.abs()});
            totalPartnersOweUs += balance.abs();
          } else if (balance > 0) {
            partnersWeOwe.add({'client': client, 'balance': balance});
            totalWeOwePartners += balance;
          }
        }

        // Trier par montant décroissant
        partnersWhoOweUs.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));
        partnersWeOwe.sort((a, b) => (b['balance'] as double).compareTo(a['balance'] as double));

        // 3. Total Frais Retirés
        final compteSpecialService = CompteSpecialService.instance;
        final totalFraisRetires = compteSpecialService.transactions
            .where((t) => 
                t.type == TypeCompteSpecial.FRAIS &&
                t.typeTransaction == TypeTransactionCompte.RETRAIT &&
                t.dateTransaction?.year == _selectedDate.year &&
                t.dateTransaction?.month == _selectedDate.month &&
                t.dateTransaction?.day == _selectedDate.day)
            .fold(0.0, (sum, t) => sum + t.montant.abs());

        // Calcul du Capital Net de l'Entreprise
        // Note: Les créances/dettes inter-shops sont déjà comptabilisées dans chaque shop
        // donc on utilise directement totalCompanyCapital
        final companyNetCapital = totalCompanyCapital - totalFraisRetires;

            return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Résumé Global avec détails
            _buildGlobalSummaryDetailed(
              totalCashDisponible,
              totalClientsNousDoivent,
              totalClientsNousDevons,
              totalShopsNousDoivent,
              totalShopsNousDevons,
              totalFraisRetires,
              companyNetCapital,
              isMobile,
            ),
            const SizedBox(height: 24),

            // Capital Net par Shop
            _buildShopCapitals(shopCapitals, isMobile),
            const SizedBox(height: 24),

            // Partenaires
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!isMobile) ...[
                  Expanded(
                    child: _buildPartnersList(
                      'Ceux qui nous doivent',
                      partnersWhoOweUs,
                      totalPartnersOweUs,
                      Colors.green,
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPartnersList(
                      'Ceux que nous devons',
                      partnersWeOwe,
                      totalWeOwePartners,
                      Colors.red,
                      isMobile,
                    ),
                  ),
                ] else
                  Expanded(
                    child: Column(
                      children: [
                        _buildPartnersList(
                          'Ceux qui nous doivent',
                          partnersWhoOweUs,
                          totalPartnersOweUs,
                          Colors.green,
                          isMobile,
                        ),
                        const SizedBox(height: 16),
                        _buildPartnersList(
                          'Ceux que nous devons',
                          partnersWeOwe,
                          totalWeOwePartners,
                          Colors.red,
                          isMobile,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
            );
          },
        );
      },
    );
  }
  
  /// Calculer le capital de tous les shops en parallèle
  Future<List<Map<String, dynamic>>> _calculateAllShopsCapital(
    List<ShopModel> shops,
    List<OperationModel> operations,
    List<ClientModel> clients,
  ) async {
    final results = <Map<String, dynamic>>[];
    
    for (final shop in shops) {
      final details = await _calculateShopNetCapitalDetails(
        shop,
        operations,
        clients,
      );
      results.add(details);
    }
    
    return results;
  }

  Widget _buildGlobalSummaryDetailed(
    double totalCashDisponible,
    double totalClientsNousDoivent,
    double totalClientsNousDevons,
    double totalShopsNousDoivent,
    double totalShopsNousDevons,
    double totalFraisRetires,
    double companyNetCapital,
    bool isMobile,
  ) {
    return Card(
      elevation: 4,
      color: companyNetCapital >= 0 ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            Text(
              'CAPITAL NET DE L\'ENTREPRISE',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Formule: Cash Disponible + Créances - Dettes - Frais Retirés',
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                fontStyle: FontStyle.italic,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              '${_numberFormat.format(companyNetCapital)} USD',
              style: TextStyle(
                fontSize: isMobile ? 32 : 48,
                fontWeight: FontWeight.bold,
                color: companyNetCapital >= 0 ? Colors.green[700] : Colors.red[700],
              ),
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                _buildSummaryItem('Cash Disponible', totalCashDisponible, Colors.blue, isMobile),
                _buildSummaryItem('+ Clients Nous Doivent', totalClientsNousDoivent, Colors.green, isMobile),
                _buildSummaryItem('+ Shops Nous Doivent', totalShopsNousDoivent, Colors.orange, isMobile),
                _buildSummaryItem('- Clients Nous Devons', totalClientsNousDevons, Colors.red, isMobile),
                _buildSummaryItem('- Shops Nous Devons', totalShopsNousDevons, Colors.purple, isMobile),
                _buildSummaryItem('- Frais Retirés', totalFraisRetires, Colors.deepOrange, isMobile),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, double amount, Color color, bool isMobile) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isMobile ? 11 : 13,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${_numberFormat.format(amount)} USD',
          style: TextStyle(
            fontSize: isMobile ? 14 : 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildShopCapitals(List<Map<String, dynamic>> shopCapitals, bool isMobile) {
    return Card(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            ),
            child: Row(
              children: [
                const Icon(Icons.store, color: Colors.blue),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Capital Net par Shop (${shopCapitals.length} shop(s))',
                    style: TextStyle(
                      fontSize: isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(isMobile ? 8 : 12),
            itemCount: shopCapitals.length,
            separatorBuilder: (context, index) => const Divider(height: 1, thickness: 1),
            itemBuilder: (context, index) {
              final item = shopCapitals[index];
              final shop = item['shop'] as ShopModel;
              final capitalNet = item['capitalNet'] as double;
              final cashDisponible = item['cashDisponible'] as double;
              final clientsNousDoivent = item['clientsNousDoivent'] as double;
              final clientsNousDevons = item['clientsNousDevons'] as double;
              final shopsNousDoivent = item['shopsNousDoivent'] as double;
              final shopsNousDevons = item['shopsNousDevons'] as double;
              
              return ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: capitalNet >= 0 ? Colors.green[100] : Colors.red[100],
                  child: Icon(
                    Icons.store,
                    color: capitalNet >= 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                title: Text(
                  shop.designation,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  shop.localisation,
                  style: TextStyle(fontSize: isMobile ? 11 : 12, color: Colors.grey[600]),
                ),
                trailing: Text(
                  '${_numberFormat.format(capitalNet)} USD',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: capitalNet >= 0 ? Colors.green[700] : Colors.red[700],
                  ),
                ),
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Détail du Capital Net',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Cash Disponible', cashDisponible, Colors.blue, isMobile),
                        _buildDetailRow('+ Clients Nous Doivent', clientsNousDoivent, Colors.green, isMobile),
                        _buildDetailRow('+ Shops Nous Doivent', shopsNousDoivent, Colors.orange, isMobile),
                        _buildDetailRow('- Clients Nous Devons', -clientsNousDevons, Colors.red, isMobile),
                        _buildDetailRow('- Shops Nous Devons', -shopsNousDevons, Colors.purple, isMobile),
                        const Divider(),
                        _buildDetailRow(
                          '= Capital Net',
                          capitalNet,
                          capitalNet >= 0 ? Colors.green[700]! : Colors.red[700]!,
                          isMobile,
                          isBold: true,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double amount, Color color, bool isMobile, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${_numberFormat.format(amount)} USD',
            style: TextStyle(
              fontSize: isMobile ? 11 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPartnersList(
    String title,
    List<Map<String, dynamic>> partners,
    double total,
    Color color,
    bool isMobile,
  ) {
    return Card(
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
                Icon(Icons.people, color: color),
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
                        style: TextStyle(fontSize: isMobile ? 11 : 12),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${_numberFormat.format(total)} USD',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (partners.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Aucun partenaire',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: isMobile ? 400 : 500,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.all(isMobile ? 8 : 12),
                itemCount: partners.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = partners[index];
                  final client = item['client'] as ClientModel;
                  final balance = item['balance'] as double;
                  
                  return ListTile(
                    dense: isMobile,
                    leading: CircleAvatar(
                      radius: isMobile ? 16 : 20,
                      backgroundColor: color.withOpacity(0.2),
                      child: Text(
                        client.nom[0].toUpperCase(),
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ),
                    title: Text(
                      client.nom,
                      style: TextStyle(fontSize: isMobile ? 13 : 14),
                    ),
                    subtitle: Text(
                      client.telephone,
                      style: TextStyle(fontSize: isMobile ? 11 : 12),
                    ),
                    trailing: Text(
                      '${_numberFormat.format(balance)} USD',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
