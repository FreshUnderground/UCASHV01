import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_auth_service.dart';
import '../widgets/rapport_cloture_widget.dart';
import '../widgets/rapportcloture.dart';
import '../services/rapportcloture_pdf_service.dart';

/// Widget pour le menu des rapports
class ReportsMenuWidget extends StatelessWidget {
  const ReportsMenuWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AgentAuthService>(context);
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Text(
            '📊 Rapports et Analyses',
            style: TextStyle(
              fontSize: isMobile ? 24 : 32,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFDC2626),
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            'Accédez à tous vos rapports financiers',
            style: TextStyle(
              fontSize: isMobile ? 14 : 16,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: isMobile ? 24 : 32),
          
          // Grille des rapports
          Expanded(
            child: GridView.count(
              crossAxisCount: isMobile ? 1 : (size.width > 1200 ? 3 : 2),
              crossAxisSpacing: isMobile ? 16 : 24,
              mainAxisSpacing: isMobile ? 16 : 24,
              children: [
                _buildReportCard(
                  context: context,
                  title: 'Rapport de Clôture',
                  subtitle: 'Clôture journalière avec soldes',
                  icon: Icons.receipt_long,
                  color: const Color(0xFF10B981),
                  onTap: () => _navigateToReport(context, 'cloture'),
                ),
                _buildReportCard(
                  context: context,
                  title: 'Mouvements FLOT',
                  subtitle: 'Suivi des approvisionnements entre shops',
                  icon: Icons.local_shipping,
                  color: const Color(0xFF9C27B0),
                  onTap: () => _navigateToReport(context, 'flot'),
                ),
                _buildReportCard(
                  context: context,
                  title: 'Opérations Clients',
                  subtitle: 'Dépôts, retraits et transferts',
                  icon: Icons.people,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => _navigateToReport(context, 'operations'),
                ),
                _buildReportCard(
                  context: context,
                  title: 'Rapport PDF',
                  subtitle: 'Générer et télécharger en PDF',
                  icon: Icons.picture_as_pdf,
                  color: const Color(0xFFEF4444),
                  onTap: () => _navigateToReport(context, 'pdf'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 20 : 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: isMobile ? 32 : 40,
                  color: color,
                ),
              ),
              SizedBox(height: isMobile ? 16 : 20),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToReport(BuildContext context, String reportType) {
    switch (reportType) {
      case 'cloture':
        // Naviguer vers le rapport de clôture
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const RapportCloture(),
          ),
        );
        break;
      case 'flot':
        // Naviguer vers les mouvements FLOT
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('💸 Affichage des Mouvements FLOT')),
        );
        break;
      case 'operations':
        // Naviguer vers les opérations clients
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('👥 Affichage des Opérations Clients')),
        );
        break;
      case 'pdf':
        // Générer le rapport PDF
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📄 Génération du Rapport PDF')),
        );
        break;
    }
  }
}