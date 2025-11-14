import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/report_service.dart';
import '../widgets/reports/admin_reports_widget.dart';
import '../widgets/reports/agent_reports_widget.dart';
import '../widgets/reports/client_reports_widget.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  void initState() {
    super.initState();
    _initializeReports();
  }

  Future<void> _initializeReports() async {
    final reportService = Provider.of<ReportService>(context, listen: false);
    await reportService.loadReportData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Rapports UCASH',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _refreshReports,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les rapports',
          ),
        ],
      ),
      body: Consumer<AuthService>(
        builder: (context, authService, child) {
          // Déterminer le type d'utilisateur connecté
          if (authService.currentClient != null) {
            // Client connecté
            return const ClientReportsWidget();
          } else if (authService.currentUser != null) {
            final user = authService.currentUser!;
            switch (user.role) {
              case 'ADMIN':
                return const AdminReportsWidget();
              case 'AGENT':
                return const AgentReportsWidget();
              case 'COMPTE':
                return const AgentReportsWidget(); // Même accès qu'un agent
              default:
                return _buildUnauthorized();
            }
          } else {
            return _buildUnauthorized();
          }
        },
      ),
    );
  }

  Widget _buildUnauthorized() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Accès non autorisé',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Vous devez être connecté pour accéder aux rapports',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pushReplacementNamed('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Se connecter'),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshReports() async {
    final reportService = Provider.of<ReportService>(context, listen: false);
    await reportService.loadReportData();
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Rapports actualisés'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }
}
