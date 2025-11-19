import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shop_service.dart';
import '../services/rates_service.dart';
import '../services/agent_service.dart';
import 'responsive_card.dart';

class AdminStatsCards extends StatelessWidget {
  const AdminStatsCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<ShopService, RatesService, AgentService>(
      builder: (context, shopService, ratesService, agentService, child) {
        // Calcul des données réelles
        final shops = shopService.shops;
        final taux = ratesService.taux;
        final commissions = ratesService.commissions;
        final agents = agentService.agents;
        
        // Capital total de tous les shops
        final capitalTotal = shops.fold(0.0, (sum, shop) => sum + shop.capitalActuel);
        
        // Nombre de taux configurés
        final nombreTaux = taux.length;
        
        // Nombre de commissions configurées
        final nombreCommissions = commissions.length;
        
        // Nombre d'agents actifs
        final nombreAgents = agents.length;
        
        // Créer la liste des cartes de statistiques
        final List<Widget> statCards = [
          _buildStatCard(
            'Shops Actifs',
            '${shops.length}',
            Icons.store,
            const Color(0xFF0D47A1),
          ),
          if (nombreAgents > 0)
            _buildStatCard(
              'Agents',
              '${nombreAgents}',
              Icons.people,
              const Color(0xFF1976D2),
            ),
          if (capitalTotal > 0)
            _buildStatCard(
              'Capital Total',
              '${_formatMoney(capitalTotal)} USD',
              Icons.trending_up,
              const Color(0xFF388E3C),
            ),
          if (nombreTaux > 0)
            _buildStatCard(
              'Taux Configurés',
              '${nombreTaux}',
              Icons.currency_exchange,
              const Color(0xFFE65100),
            ),
          if (nombreCommissions > 0)
            _buildStatCard(
              'Commissions',
              '${nombreCommissions}',
              Icons.percent,
              const Color(0xFF7B1FA2),
            ),
        ];

        return ResponsiveGrid(
          spacing: 16,
          runSpacing: 16,
          children: statCards,
        );
      },
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Builder(
      builder: (context) {
        final isMobile = MediaQuery.of(context).size.width < 600;
        
        return ResponsiveCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 10 : 12),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: isMobile ? 20 : 24,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 6 : 8,
                      vertical: isMobile ? 3 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                    ),
                    child: Icon(
                      Icons.trending_up,
                      color: Colors.green[700],
                      size: isMobile ? 14 : 16,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              Text(
                value,
                style: TextStyle(
                  fontSize: isMobile ? 18 : 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey[800],
                ),
              ),
              SizedBox(height: isMobile ? 2 : 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: isMobile ? 12 : 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
