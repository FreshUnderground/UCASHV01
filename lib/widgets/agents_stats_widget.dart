import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';

class AgentsStatsWidget extends StatelessWidget {
  const AgentsStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        final agents = agentService.agents;
        final activeAgents = agents.where((a) => a.isActive).length;
        final inactiveAgents = agents.length - activeAgents;
        
        // Calculer les agents par shop
        final agentsByShop = <int, int>{};
        for (var agent in agents) {
          agentsByShop[agent.shopId] = (agentsByShop[agent.shopId] ?? 0) + 1;
        }
        
        final shopsWithAgents = agentsByShop.keys.length;
        final shopsWithoutAgents = shopService.shops.length - shopsWithAgents;

        return Card(
          elevation: 2,
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Statistiques des Agents',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDC2626),
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                
                // Grille responsive de statistiques
                _buildResponsiveStatsGrid(
                  isMobile, 
                  isTablet,
                  agents.length,
                  activeAgents,
                  inactiveAgents,
                  shopsWithAgents,
                  shopsWithoutAgents,
                  shopService.shops.isEmpty 
                      ? '0%' 
                      : '${((shopsWithAgents / shopService.shops.length) * 100).toStringAsFixed(0)}%',
                ),
                
                // Détails par shop (si il y a des agents)
                if (agents.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  
                  const Text(
                    'Répartition par Shop',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF374151),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  Container(
                    constraints: const BoxConstraints(maxHeight: 150),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: shopService.shops.length,
                      itemBuilder: (context, index) {
                        final shop = shopService.shops[index];
                        final agentCount = agentsByShop[shop.id] ?? 0;
                        final activeInShop = agents
                            .where((a) => a.shopId == shop.id && a.isActive)
                            .length;
                        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: agentCount > 0 
                                ? const Color(0xFFDC2626).withOpacity(0.05)
                                : Colors.grey.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: agentCount > 0 
                                  ? const Color(0xFFDC2626).withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.store,
                                color: agentCount > 0 
                                    ? const Color(0xFFDC2626)
                                    : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      shop.designation,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      shop.localisation,
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: agentCount > 0 
                                      ? const Color(0xFFDC2626)
                                      : Colors.grey,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '$agentCount agent${agentCount > 1 ? 's' : ''}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (agentCount > 0) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$activeInShop actif${activeInShop > 1 ? 's' : ''}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildResponsiveStatsGrid(
    bool isMobile,
    bool isTablet,
    int totalAgents,
    int activeAgents,
    int inactiveAgents,
    int shopsWithAgents,
    int shopsWithoutAgents,
    String occupationRate,
  ) {
    final stats = [
      {'title': 'Total Agents', 'value': '$totalAgents', 'icon': Icons.people, 'color': const Color(0xFF2563EB)},
      {'title': 'Agents Actifs', 'value': '$activeAgents', 'icon': Icons.check_circle, 'color': const Color(0xFF059669)},
      {'title': 'Agents Inactifs', 'value': '$inactiveAgents', 'icon': Icons.pause_circle, 'color': const Color(0xFFEA580C)},
      {'title': 'Shops avec Agents', 'value': '$shopsWithAgents', 'icon': Icons.store_mall_directory, 'color': const Color(0xFF7C3AED)},
      {'title': 'Shops sans Agents', 'value': '$shopsWithoutAgents', 'icon': Icons.store_outlined, 'color': const Color(0xFF9CA3AF)},
      {'title': 'Taux d\'Occupation', 'value': occupationRate, 'icon': Icons.analytics, 'color': const Color(0xFFDC2626)},
    ];

    if (isMobile) {
      return Column(
        children: [
          // Première ligne mobile (2 colonnes)
          Row(
            children: [
              _buildStatCard(stats[0]['title'] as String, stats[0]['value'] as String, stats[0]['icon'] as IconData, stats[0]['color'] as Color, isMobile),
              const SizedBox(width: 8),
              _buildStatCard(stats[1]['title'] as String, stats[1]['value'] as String, stats[1]['icon'] as IconData, stats[1]['color'] as Color, isMobile),
            ],
          ),
          const SizedBox(height: 8),
          // Deuxième ligne mobile
          Row(
            children: [
              _buildStatCard(stats[2]['title'] as String, stats[2]['value'] as String, stats[2]['icon'] as IconData, stats[2]['color'] as Color, isMobile),
              const SizedBox(width: 8),
              _buildStatCard(stats[3]['title'] as String, stats[3]['value'] as String, stats[3]['icon'] as IconData, stats[3]['color'] as Color, isMobile),
            ],
          ),
          const SizedBox(height: 8),
          // Troisième ligne mobile
          Row(
            children: [
              _buildStatCard(stats[4]['title'] as String, stats[4]['value'] as String, stats[4]['icon'] as IconData, stats[4]['color'] as Color, isMobile),
              const SizedBox(width: 8),
              _buildStatCard(stats[5]['title'] as String, stats[5]['value'] as String, stats[5]['icon'] as IconData, stats[5]['color'] as Color, isMobile),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        // Première ligne desktop/tablet
        Row(
          children: [
            _buildStatCard(stats[0]['title'] as String, stats[0]['value'] as String, stats[0]['icon'] as IconData, stats[0]['color'] as Color, isMobile),
            SizedBox(width: isTablet ? 12 : 16),
            _buildStatCard(stats[1]['title'] as String, stats[1]['value'] as String, stats[1]['icon'] as IconData, stats[1]['color'] as Color, isMobile),
            SizedBox(width: isTablet ? 12 : 16),
            _buildStatCard(stats[2]['title'] as String, stats[2]['value'] as String, stats[2]['icon'] as IconData, stats[2]['color'] as Color, isMobile),
          ],
        ),
        SizedBox(height: isTablet ? 8 : 12),
        // Deuxième ligne desktop/tablet
        Row(
          children: [
            _buildStatCard(stats[3]['title'] as String, stats[3]['value'] as String, stats[3]['icon'] as IconData, stats[3]['color'] as Color, isMobile),
            SizedBox(width: isTablet ? 12 : 16),
            _buildStatCard(stats[4]['title'] as String, stats[4]['value'] as String, stats[4]['icon'] as IconData, stats[4]['color'] as Color, isMobile),
            SizedBox(width: isTablet ? 12 : 16),
            _buildStatCard(stats[5]['title'] as String, stats[5]['value'] as String, stats[5]['icon'] as IconData, stats[5]['color'] as Color, isMobile),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(isMobile ? 8 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: isMobile ? 20 : 24),
            SizedBox(height: isMobile ? 4 : 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 16 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            SizedBox(height: isMobile ? 2 : 2),
            Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
