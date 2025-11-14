import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_auth_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';

class AgentStatsCards extends StatelessWidget {
  const AgentStatsCards({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer3<AgentAuthService, OperationService, ShopService>(
      builder: (context, authService, operationService, shopService, child) {
        if (authService.currentAgent == null) {
          return const SizedBox.shrink();
        }

        // UTILISE LES DONNEES LOCALES REELLES
        final stats = operationService.getDailyStats(authService.currentAgent!.id!);
        
        // Determiner les devises du shop pour affichage correct
        final currentShop = shopService.shops.where((s) => s.id == authService.currentAgent!.shopId).firstOrNull;
        final hasMultiDevise = currentShop?.hasDeviseSecondaire ?? false;
        final devise2 = currentShop?.deviseSecondaire;
        
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 1024;
            final isTablet = constraints.maxWidth > 768 && constraints.maxWidth <= 1024;
            final isMobile = constraints.maxWidth <= 768;
            
            if (isWide) {
              return Row(
                children: _buildAllCards(stats, hasMultiDevise, devise2),
              );
            } else if (isTablet) {
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Transferts',
                          '${stats['transferts']}',
                          Icons.send,
                          const Color(0xFF1976D2),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildStatCard(
                          'Dépôts',
                          '${stats['depots']}',
                          Icons.arrow_downward,
                          const Color(0xFF388E3C),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Retraits',
                          '${stats['retraits']}',
                          Icons.arrow_upward,
                          const Color(0xFFFF9800),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildCommissionCard(stats, hasMultiDevise, devise2),
                      ),
                    ],
                  ),
                ],
              );
            } else {
              return Column(
                children: [
                  _buildStatCard(
                    'Total Opérations',
                    '${stats['totalOperations']}',
                    Icons.list_alt,
                    const Color(0xFF1976D2),
                  ),
                  const SizedBox(height: 12),
                  _buildCommissionCard(stats, hasMultiDevise, devise2),
                ],
              );
            }
          },
        );
      },
    );
  }

  List<Widget> _buildAllCards(Map<String, dynamic> stats, bool hasMultiDevise, String? devise2) {
    return [
      Expanded(
        child: _buildStatCard(
          'Transferts',
          '${stats['transferts']}',
          Icons.send,
          const Color(0xFF1976D2),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatCard(
          'Depots',
          '${stats['depots']}',
          Icons.arrow_downward,
          const Color(0xFF388E3C),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatCard(
          'Retraits',
          '${stats['retraits']}',
          Icons.arrow_upward,
          const Color(0xFFFF9800),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildStatCard(
          'Virements',
          '${stats['virements']}',
          Icons.swap_horiz,
          const Color(0xFF9C27B0),
        ),
      ),
      const SizedBox(width: 16),
      Expanded(
        child: _buildCommissionCard(stats, hasMultiDevise, devise2),
      ),
    ];
  }
  
  // Widget pour afficher les commissions (multi-devises si necessaire)
  Widget _buildCommissionCard(Map<String, dynamic> stats, bool hasMultiDevise, String? devise2) {
    if (!hasMultiDevise || devise2 == null) {
      // Une seule devise (USD)
      return _buildStatCard(
        'Commissions',
        '${_formatMoney(stats['commissionsUSD'] ?? stats['commissionsEncaissees'])} USD',
        Icons.monetization_on,
        const Color(0xFFE91E63),
      );
    }
    
    // Multi-devises: afficher les deux
    final commissionsUSD = stats['commissionsUSD'] ?? 0.0;
    final commissionsDevise2 = stats['commissions$devise2'] ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE91E63).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.monetization_on,
                  color: Color(0xFFE91E63),
                  size: 24,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Aujourd\'hui',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${_formatMoney(commissionsUSD)} USD',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatMoney(commissionsDevise2)} $devise2',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Commissions',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Aujourd\'hui',
                    style: TextStyle(
                      color: Colors.green[700],
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
    );
  }

  String _formatMoney(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(1)}K';
    } else {
      return amount.toStringAsFixed(2);
    }
  }
}
