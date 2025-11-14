import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

import 'report_filters_widget.dart';
import 'releve_compte_client_report.dart' as releve_compte;

class ClientReportsWidget extends StatefulWidget {
  const ClientReportsWidget({super.key});

  @override
  State<ClientReportsWidget> createState() => _ClientReportsWidgetState();
}

class _ClientReportsWidgetState extends State<ClientReportsWidget> {
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final client = authService.currentClient;
        if (client == null) {
          return _buildNoClientError();
        }

        return Column(
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
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFDC2626),
                        child: Text(
                          client.nom.isNotEmpty ? client.nom[0].toUpperCase() : 'C',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Mon Relevé de Compte',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1F2937),
                              ),
                            ),
                            Text(
                              client.nom,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: client.solde >= 0 ? Colors.green[100] : Colors.red[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: client.solde >= 0 ? Colors.green[300]! : Colors.red[300]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.account_balance_wallet,
                              color: client.solde >= 0 ? Colors.green[700] : Colors.red[700],
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${client.solde.toStringAsFixed(2)} USD',
                              style: TextStyle(
                                color: client.solde >= 0 ? Colors.green[700] : Colors.red[700],
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Filtres de période
                  ReportFiltersWidget(
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
                ],
              ),
            ),
            
            // Relevé de compte
            Expanded(
              child: releve_compte.ReleveCompteClientReport(
                clientId: client.id!,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNoClientError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_off_outlined,
            size: 64,
            color: Colors.red[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Erreur de session',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.red[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Aucun client connecté.\nVeuillez vous reconnecter.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/client-login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Se reconnecter'),
          ),
        ],
      ),
    );
  }
}
