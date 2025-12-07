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
import '../calculation_tooltip.dart';

/// Widget pour afficher la Situation Nette de l'Entreprise
/// - Capital Net par Shop
/// - Liste des partenaires qui Nous qui Doivent
/// - Liste des partenaires que Nous que Devons
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

  /// Show details for Cash Disponible calculation
  void _showCashDisponibleDetails(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Cash Disponible Details',
          description: 'Cash Disponible represents the actual physical cash available in the shop.',
          formula: 'Cash Disponible = Solde Ouverture + Total Encaissements - Total Décaissements ± Ajustements',
          businessLogic: 'This calculation follows the daily closure report logic where:\n'
              '- Solde Ouverture: Starting cash balance\n'
              '- Total Encaissements: All money received (deposits, incoming transfers)\n'
              '- Total Décaissements: All money paid out (withdrawals, outgoing transfers)\n'
              '- Ajustements: Manual adjustments for discrepancies',
          components: [
            CalculationComponent(
              name: 'Solde Ouverture',
              description: 'Starting cash balance for the day',
              isPositive: true,
            ),
            CalculationComponent(
              name: 'Encaissements',
              description: 'Money received during the day (deposits, incoming transfers)',
              isPositive: true,
            ),
            CalculationComponent(
              name: 'Décaissements',
              description: 'Money paid out during the day (withdrawals, outgoing transfers)',
              isPositive: false,
            ),
            CalculationComponent(
              name: 'Ajustements',
              description: 'Manual adjustments for cash discrepancies',
              isPositive: true, // Can be positive or negative
            ),
          ],
        );
      },
    );
  }

  /// Show details for Clients Nous qui Doivent calculation
  void _showClientsNousDoiventDetails(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Clients Nous qui Doivent Details',
          description: 'Represents the total amount that clients owe to the company.',
          formula: 'Clients Nous qui Doivent = Σ(Client Balances < 0)',
          businessLogic: 'For each client, we calculate their balance:\n'
              '- Deposits and incoming transfers increase the balance\n'
              '- Withdrawals and outgoing transfers decrease the balance\n'
              'When a client\'s balance is negative, it means they owe money to the company.',
          components: [
            CalculationComponent(
              name: 'Client Balances',
              description: 'Individual client account balances',
              isPositive: true,
            ),
            CalculationComponent(
              name: 'Negative Balances',
              description: 'Only negative balances are counted as amounts owed to us',
              isPositive: true,
            ),
          ],
        );
      },
    );
  }

  /// Show details for Shops Nous qui Doivent calculation
  void _showShopsNousDoiventDetails(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Shops Nous qui Doivent Details',
          description: 'Represents amounts owed to our shops by other shops.',
          formula: 'Shops Nous qui Doivent = Σ(Transfert National Amounts where current shop is destination)',
          businessLogic: 'In national transfers:\n'
              '- The source shop receives money from a client and owes it to the destination shop\n'
              '- The destination shop is owed this amount until the transfer is completed',
          components: [
            CalculationComponent(
              name: 'Transferts Nationaux',
              description: 'National money transfers between shops',
              isPositive: true,
            ),
            CalculationComponent(
              name: 'Destination Shop',
              description: 'Current shop is the destination and is owed money',
              isPositive: true,
            ),
          ],
        );
      },
    );
  }

  /// Show details for Clients Nous que Devons calculation
  void _showClientsNousDevonsDetails(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Clients Nous que Devons Details',
          description: 'Represents the total amount that the company owes to clients.',
          formula: 'Clients Nous que Devons = Σ(Client Balances > 0)',
          businessLogic: 'For each client, we calculate their balance:\n'
              '- Deposits and incoming transfers increase the balance\n'
              '- Withdrawals and outgoing transfers decrease the balance\n'
              'When a client\'s balance is positive, it means we owe money to the client.',
          components: [
            CalculationComponent(
              name: 'Client Balances',
              description: 'Individual client account balances',
              isPositive: false,
            ),
            CalculationComponent(
              name: 'Positive Balances',
              description: 'Only positive balances are counted as amounts we owe',
              isPositive: false,
            ),
          ],
        );
      },
    );
  }

  /// Show details for Shops Nous que Devons calculation
  void _showShopsNousDevonsDetails(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Shops Nous que Devons Details',
          description: 'Represents amounts that our shops owe to other shops.',
          formula: 'Shops Nous que Devons = Σ(Transfert National Amounts where current shop is source)',
          businessLogic: 'In national transfers:\n'
              '- The source shop receives money from a client and owes it to the destination shop\n'
              '- The source shop has a debt obligation to the destination shop',
          components: [
            CalculationComponent(
              name: 'Transferts Nationaux',
              description: 'National money transfers between shops',
              isPositive: false,
            ),
            CalculationComponent(
              name: 'Source Shop',
              description: 'Current shop is the source and owes money',
              isPositive: false,
            ),
          ],
        );
      },
    );
  }

  /// Show details for Frais Retirés calculation
  void _showFraisRetiresDetails(BuildContext context, double amount) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Frais Retirés Details',
          description: 'Represents withdrawals from the FRAIS special account.',
          formula: 'Frais Retirés = Σ(Retraits from FRAIS account)',
          businessLogic: 'The FRAIS account accumulates transaction fees:\n'
              '- Fees are automatically credited to this special account\n'
              '- Authorized personnel can withdraw from this account\n'
              '- Withdrawals reduce the company\'s net capital',
          components: [
            CalculationComponent(
              name: 'FRAIS Account',
              description: 'Special account for accumulating transaction fees',
              isPositive: false,
            ),
            CalculationComponent(
              name: 'Withdrawals',
              description: 'Amounts withdrawn from the FRAIS account',
              isPositive: false,
            ),
          ],
        );
      },
    );
  }

  /// Calculer le capital net d'un shop selon la formule de clôture
  /// SITUATION NETTE = Cash Disponible + Partenaires Servis + Shops qui nous doivent 
  ///                   - Depots Partenaires - Shops que nous Devons - Frais du Jour - Transferts En Attente
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
    
    // 2. Utiliser les créances/dettes clients du rapport de clôture
    // Partenaires Servis = Clients qui nous doivent (solde négatif)
    // Depots Partenaires = Clients que nous devons (solde positif)
    final clientsNousDoivent = rapport.totalClientsNousDoivent;
    final clientsNousDevons = rapport.totalClientsNousDevons;
    
    // 3. Utiliser les créances/dettes inter-shops du rapport de clôture
    final shopsNousDoivent = rapport.totalShopsNousDoivent;
    final shopsNousDevons = rapport.totalShopsNousDevons;
    
    // 4. Frais du Jour du Rapport de Clôture
    // Solde Frais = Solde Antérieur + Commissions du Jour - Retraits du Jour
    final fraisDuJour = rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour;
    
    // 5. Calculer la SITUATION NETTE selon la formule demandée:
    // SITUATION NETTE = Cash Disponible + Partenaires Servis + Shops qui nous doivent 
    //                   - Depots Partenaires - Shops que nous Devons - Frais du Jour - Transferts En Attente
    final situationNette = cashDisponible + clientsNousDoivent + shopsNousDoivent 
                          - clientsNousDevons - shopsNousDevons - fraisDuJour - rapport.transfertsEnAttente;
    
    return {
      'shop': shop,
      'cashDisponible': cashDisponible,
      'clientsNousDoivent': clientsNousDoivent,  // Partenaires Servis
      'clientsNousDevons': clientsNousDevons,    // Depots Partenaires
      'shopsNousDoivent': shopsNousDoivent,      // Shops qui nous doivent
      'shopsNousDevons': shopsNousDevons,        // Shops que nous devons
      'fraisDuJour': fraisDuJour,                // Frais du Jour (Rapport Cloture)
      'transfertsEnAttente': rapport.transfertsEnAttente, // Transferts En Attente
      'soldeFraisAnterieur': rapport.soldeFraisAnterieur,
      'commissionsFraisDuJour': rapport.commissionsFraisDuJour,
      'retraitsFraisDuJour': rapport.retraitsFraisDuJour,
      'situationNette': situationNette,          // Nouvelle formule Situation Nette
      'capitalNet': rapport.capitalNet,          // Capital Net original (pour référence
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
            double totalSituationNette = 0.0;
            double totalCashDisponible = 0.0;
            double totalClientsNousDoivent = 0.0;
            double totalClientsNousDevons = 0.0;
            double totalShopsNousDoivent = 0.0;
            double totalShopsNousDevons = 0.0;
            double totalFraisDuJour = 0.0;

            for (final details in shopCapitals) {
              totalSituationNette += details['situationNette'] as double;
              totalCashDisponible += details['cashDisponible'] as double;
              totalClientsNousDoivent += details['clientsNousDoivent'] as double;
              totalClientsNousDevons += details['clientsNousDevons'] as double;
              totalShopsNousDoivent += details['shopsNousDoivent'] as double;
              totalShopsNousDevons += details['shopsNousDevons'] as double;
              totalFraisDuJour += details['fraisDuJour'] as double;
            }

        // Trier par capital net décroissant
        shopCapitals.sort((a, b) => (b['capitalNet'] as double).compareTo(a['capitalNet'] as double));

        // 2. Partenaires qui Nous qui Doivent / que Nous que Devons
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

        // Calcul de la Situation Nette de l'Entreprise
        // SITUATION NETTE = Cash Disponible + Partenaires Servis + Shops qui nous doivent 
        //                   - Depots Partenaires - Shops que nous Devons - Frais du Jour
        // Note: totalSituationNette est déjà calculé par shop avec la bonne formule
        final companySituationNette = totalSituationNette;

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
              totalFraisDuJour,
              companySituationNette,
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
                      'Partenaires Servis (Nous doivent)',
                      partnersWhoOweUs,
                      totalPartnersOweUs,
                      Colors.green,
                      isMobile,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildPartnersList(
                      'Dépôts Partenaires (Nous devons)',
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
                          'Partenaires Servis (Nous doivent)',
                          partnersWhoOweUs,
                          totalPartnersOweUs,
                          Colors.green,
                          isMobile,
                        ),
                        const SizedBox(height: 16),
                        _buildPartnersList(
                          'Dépôts Partenaires (Nous devons)',
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
    double totalFraisDuJour,
    double companySituationNette,
    bool isMobile,
  ) {
    return Card(
      elevation: 4,
      color: companySituationNette >= 0 ? Colors.green[50] : Colors.red[50],
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          children: [
            Text(
              'SITUATION NETTE DE L\'ENTREPRISE',
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 8),
            CalculationTooltip(
              title: 'Situation Nette Formula',
              description: 'La situation nette représente la position financière réelle de l\'entreprise',
              formula: 'Situation Nette = Cash Disponible + Partenaires Servis + Shops qui nous doivent - Dépôts Partenaires - Shops que nous Devons - Frais du Jour - Transferts En Attente',
              components: [
                'Cash Disponible: Cash physique disponible',
                'Partenaires Servis: Montants que les clients nous doivent',
                'Shops qui nous doivent: Créances inter-shops',
                'Dépôts Partenaires: Montants que nous devons aux clients',
                'Shops que nous Devons: Dettes inter-shops',
                'Frais du Jour: Solde du compte FRAIS (Rapport Clôture)',
              ],
              child: Text(
                'Formule: Cash Disponible + Partenaires Servis + Shops qui nous doivent - Dépôts Partenaires - Shops que nous Devons - Frais du Jour - Transferts En Attente',
                style: TextStyle(
                  fontSize: isMobile ? 10 : 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${_numberFormat.format(companySituationNette)} USD',
              style: TextStyle(
                fontSize: isMobile ? 32 : 48,
                fontWeight: FontWeight.bold,
                color: companySituationNette >= 0 ? Colors.green[700] : Colors.red[700],
              ),
            ),
            const Divider(height: 32),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () => _showCashDisponibleDetails(context, totalCashDisponible),
                  child: _buildSummaryItem('Cash Disponible', totalCashDisponible, Colors.blue, isMobile),
                ),
                GestureDetector(
                  onTap: () => _showClientsNousDoiventDetails(context, totalClientsNousDoivent),
                  child: _buildSummaryItem('+ Partenaires Servis', totalClientsNousDoivent, Colors.green, isMobile),
                ),
                GestureDetector(
                  onTap: () => _showShopsNousDoiventDetails(context, totalShopsNousDoivent),
                  child: _buildSummaryItem('+ Shops qui nous doivent', totalShopsNousDoivent, Colors.orange, isMobile),
                ),
                GestureDetector(
                  onTap: () => _showClientsNousDevonsDetails(context, totalClientsNousDevons),
                  child: _buildSummaryItem('- Dépôts Partenaires', totalClientsNousDevons, Colors.red, isMobile),
                ),
                GestureDetector(
                  onTap: () => _showShopsNousDevonsDetails(context, totalShopsNousDevons),
                  child: _buildSummaryItem('- Shops que nous Devons', totalShopsNousDevons, Colors.purple, isMobile),
                ),
                GestureDetector(
                  onTap: () => _showFraisRetiresDetails(context, totalFraisDuJour),
                  child: _buildSummaryItem('- Frais du Jour', totalFraisDuJour, Colors.deepOrange, isMobile),
                ),
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
    // Trier par situation nette décroissante
    shopCapitals.sort((a, b) => (b['situationNette'] as double).compareTo(a['situationNette'] as double));
    
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
                    'Situation Nette par Shop (${shopCapitals.length} shop(s))',
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
              final situationNette = item['situationNette'] as double;
              final cashDisponible = item['cashDisponible'] as double;
              final clientsNousDoivent = item['clientsNousDoivent'] as double;  // Partenaires Servis
              final clientsNousDevons = item['clientsNousDevons'] as double;    // Depots Partenaires
              final shopsNousDoivent = item['shopsNousDoivent'] as double;      // Shops qui nous doivent
              final shopsNousDevons = item['shopsNousDevons'] as double;        // Shops que nous devons
              final transfertsEnAttente = item['transfertsEnAttente'] as double;   // Transferts En Attente
              final shopsNousDevonsSansTransferts = shopsNousDevons - transfertsEnAttente; // Shops que nous devons sans transferts
              final fraisDuJour = item['fraisDuJour'] as double;                // Frais du Jour
              final soldeFraisAnterieur = item['soldeFraisAnterieur'] as double;
              final commissionsFraisDuJour = item['commissionsFraisDuJour'] as double;
              final retraitsFraisDuJour = item['retraitsFraisDuJour'] as double;
              
              return ExpansionTile(
                leading: CircleAvatar(
                  backgroundColor: situationNette >= 0 ? Colors.green[100] : Colors.red[100],
                  child: Icon(
                    Icons.store,
                    color: situationNette >= 0 ? Colors.green[700] : Colors.red[700],
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
                  '${_numberFormat.format(situationNette)} USD',
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: situationNette >= 0 ? Colors.green[700] : Colors.red[700],
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
                          'Détail de la Situation Nette',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Cash Disponible', cashDisponible, Colors.blue, isMobile,
                            onTap: () => _showCashDisponibleDetails(context, cashDisponible)),
                        _buildDetailRow('+ Partenaires Servis', clientsNousDoivent, Colors.green, isMobile,
                            onTap: () => _showClientsNousDoiventDetails(context, clientsNousDoivent)),
                        _buildDetailRow('+ Shops qui nous doivent', shopsNousDoivent, Colors.orange, isMobile,
                            onTap: () => _showShopsNousDoiventDetails(context, shopsNousDoivent)),
                        _buildDetailRow('- Dépôts Partenaires', -clientsNousDevons, Colors.red, isMobile,
                            onTap: () => _showClientsNousDevonsDetails(context, clientsNousDevons)),
                        _buildDetailRow('- Shops que nous Devons', -shopsNousDevonsSansTransferts, Colors.purple, isMobile,
                            onTap: () => _showShopsNousDevonsDetails(context, shopsNousDevonsSansTransferts)),
                        _buildDetailRow('- Transferts En Attente (Rapport Clôture)', -transfertsEnAttente, Colors.orange, isMobile,
                            onTap: () => _showTransfertsEnAttenteDetails(context, transfertsEnAttente)),
                        _buildDetailRow('- Frais du Jour (Rapport Clôture)', -fraisDuJour, Colors.deepOrange, isMobile,
                            onTap: () => _showFraisDuJourDetails(context, fraisDuJour, soldeFraisAnterieur, commissionsFraisDuJour, retraitsFraisDuJour)),
                        const Divider(),
                        _buildDetailRow(
                          '= SITUATION NETTE',
                          situationNette,
                          situationNette >= 0 ? Colors.green[700]! : Colors.red[700]!,
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

  /// Show details for Transferts En Attente
  void _showTransfertsEnAttenteDetails(BuildContext context, double transfertsEnAttente) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Transferts En Attente (Rapport Clôture)',
          description: 'Le montant total des transferts en attente de service pour ce shop.',
          formula: 'Transferts En Attente = Σ(Montants des transferts en attente)',
          businessLogic: 'Les transferts en attente représentent les transferts qui ont été initiés mais pas encore servis par le shop.\n'
              '- Montant: ${_numberFormat.format(transfertsEnAttente)} USD',
          components: [
            CalculationComponent(
              name: 'Transferts En Attente',
              description: 'Somme des montants des transferts en attente de service',
              isPositive: false,
            ),
          ],
        );
      },
    );
  }

  /// Show details for Frais du Jour calculation per shop
  void _showFraisDuJourDetails(BuildContext context, double fraisDuJour, double soldeFraisAnterieur, double commissionsFraisDuJour, double retraitsFraisDuJour) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CalculationDetailsDialog(
          title: 'Frais du Jour (Rapport Clôture)',
          description: 'Le solde du compte FRAIS du jour, calculé dans le rapport de clôture.',
          formula: 'Frais du Jour = Solde FRAIS Antérieur + Commissions du Jour - Retraits du Jour',
          businessLogic: 'Le compte FRAIS accumule les commissions:\n'
              '- Solde Antérieur: ${_numberFormat.format(soldeFraisAnterieur)} USD\n'
              '- Commissions du Jour: +${_numberFormat.format(commissionsFraisDuJour)} USD\n'
              '- Retraits du Jour: -${_numberFormat.format(retraitsFraisDuJour)} USD\n'
              '- = Frais du Jour: ${_numberFormat.format(fraisDuJour)} USD',
          components: [
            CalculationComponent(
              name: 'Solde FRAIS Antérieur',
              description: 'Solde du compte FRAIS au début de la journée',
              isPositive: true,
            ),
            CalculationComponent(
              name: 'Commissions du Jour',
              description: 'Commissions FRAIS encaissées sur les transferts servis',
              isPositive: true,
            ),
            CalculationComponent(
              name: 'Retraits du Jour',
              description: 'Montants retirés du compte FRAIS',
              isPositive: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, double amount, Color color, bool isMobile, {bool isBold = false, VoidCallback? onTap}) {
    Widget row = Padding(
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

    // Add tap gesture if onTap is provided
    if (onTap != null) {
      row = GestureDetector(
        onTap: onTap,
        child: row,
      );
    }

    return row;
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
