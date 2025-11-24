import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';

class AgentsStatsWidget extends StatelessWidget {
  const AgentsStatsWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 600;
    final isTablet = size.width > 600 && size.width <= 900;
    
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        final agents = agentService.agents;
        final activeAgents = agents.where((a) => a.isActive).length;
        final inactiveAgents = agents.length - activeAgents;
        
        final agentsByShop = <int, int>{};
        for (var agent in agents) {
          if (agent.shopId != null) {
            agentsByShop[agent.shopId!] = (agentsByShop[agent.shopId!] ?? 0) + 1;
          }
        }
        
        final shopsWithAgents = agentsByShop.keys.length;
        final shopsWithoutAgents = shopService.shops.where((shop) => shop.id != null).length - shopsWithAgents;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.analytics,
                        color: Color(0xFFDC2626),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Statistiques des Agents',
                      style: TextStyle(
                        fontSize: isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[900],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 16 : 20),
                
                LayoutBuilder(
                  builder: (context, constraints) {
                    return _buildResponsiveStatsGrid(
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
                      constraints.maxWidth,
                    );
                  },
                ),
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
    double availableWidth,
  ) {
    final stats = [
      {'title': 'Total', 'value': '$totalAgents', 'icon': Icons.people, 'color': const Color(0xFF2563EB)},
      {'title': 'Actifs', 'value': '$activeAgents', 'icon': Icons.check_circle, 'color': const Color(0xFF059669)},
      {'title': 'Inactifs', 'value': '$inactiveAgents', 'icon': Icons.pause_circle, 'color': const Color(0xFFEA580C)},
      {'title': 'Avec Agents', 'value': '$shopsWithAgents', 'icon': Icons.store, 'color': const Color(0xFF7C3AED)},
      {'title': 'Sans Agents', 'value': '$shopsWithoutAgents', 'icon': Icons.store_outlined, 'color': const Color(0xFF9CA3AF)},
      {'title': 'Taux', 'value': occupationRate, 'icon': Icons.pie_chart, 'color': const Color(0xFFDC2626)},
    ];

    if (isMobile) {
      // 3 colonnes : largeur disponible / 3 - espacement
      final spacing = 8.0;
      final cardWidth = (availableWidth - (spacing * 2)) / 3;
      
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: stats.map((stat) => 
          SizedBox(
            width: cardWidth,
            child: _buildStatCard(
              stat['title'] as String,
              stat['value'] as String,
              stat['icon'] as IconData,
              stat['color'] as Color,
              isMobile,
            ),
          ),
        ).toList(),
      );
    }

    return Wrap(
      spacing: isTablet ? 10 : 12,
      runSpacing: isTablet ? 10 : 12,
      children: stats.map((stat) => 
        SizedBox(
          width: (availableWidth - (isTablet ? 20 : 24)) / 3,
          child: _buildStatCard(
            stat['title'] as String,
            stat['value'] as String,
            stat['icon'] as IconData,
            stat['color'] as Color,
            isMobile,
          ),
        ),
      ).toList(),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 6 : 12,
        vertical: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 6 : 8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isMobile ? 14 : 18),
          ),
          SizedBox(height: isMobile ? 6 : 8),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 9 : 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
