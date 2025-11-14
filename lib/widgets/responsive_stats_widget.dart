import 'package:flutter/material.dart';
import 'responsive_card.dart';

/// Widget de statistiques responsive
class ResponsiveStatsWidget extends StatelessWidget {
  final List<StatCard> stats;
  final String? title;
  final EdgeInsetsGeometry? padding;

  const ResponsiveStatsWidget({
    super.key,
    required this.stats,
    this.title,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
        ResponsiveGrid(
          spacing: 16,
          runSpacing: 16,
          children: stats.map((stat) => _buildStatCard(context, stat)).toList(),
        ),
      ],
    );
  }

  Widget _buildStatCard(BuildContext context, StatCard stat) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    
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
                  color: stat.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isMobile ? 10 : 12),
                ),
                child: Icon(
                  stat.icon,
                  color: stat.color,
                  size: isMobile ? 20 : 24,
                ),
              ),
              if (stat.trend != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: stat.trend!.isPositive ? Colors.green[50] : Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        stat.trend!.isPositive ? Icons.trending_up : Icons.trending_down,
                        color: stat.trend!.isPositive ? Colors.green[700] : Colors.red[700],
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        stat.trend!.value,
                        style: TextStyle(
                          color: stat.trend!.isPositive ? Colors.green[700] : Colors.red[700],
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: isMobile ? 12 : 16),
          Text(
            stat.value,
            style: TextStyle(
              fontSize: isMobile ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            stat.title,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (stat.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              stat.subtitle!,
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modèle pour une carte de statistique
class StatCard {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final StatTrend? trend;

  const StatCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.trend,
  });
}

/// Modèle pour une tendance de statistique
class StatTrend {
  final String value;
  final bool isPositive;

  const StatTrend({
    required this.value,
    required this.isPositive,
  });
}

/// Widget de métriques avec graphiques simples
class ResponsiveMetricsWidget extends StatelessWidget {
  final List<MetricCard> metrics;
  final String? title;

  const ResponsiveMetricsWidget({
    super.key,
    required this.metrics,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: context.isMobile ? 20 : 24,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
          ),
        ],
        ResponsiveGrid(
          spacing: 16,
          runSpacing: 16,
          children: metrics.map((metric) => _buildMetricCard(context, metric)).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, MetricCard metric) {
    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                metric.title,
                style: TextStyle(
                  fontSize: context.isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              Icon(
                metric.icon,
                color: metric.color,
                size: context.isMobile ? 20 : 24,
              ),
            ],
          ),
          SizedBox(height: context.isMobile ? 8 : 12),
          Text(
            metric.value,
            style: TextStyle(
              fontSize: context.isMobile ? 24 : 28,
              fontWeight: FontWeight.bold,
              color: metric.color,
            ),
          ),
          if (metric.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.subtitle!,
              style: TextStyle(
                fontSize: context.isMobile ? 12 : 14,
                color: Colors.grey[500],
              ),
            ),
          ],
          SizedBox(height: context.isMobile ? 8 : 12),
          // Barre de progression simple
          if (metric.progress != null) ...[
            LinearProgressIndicator(
              value: metric.progress! / 100,
              backgroundColor: Colors.grey[200],
              valueColor: AlwaysStoppedAnimation<Color>(metric.color),
            ),
            const SizedBox(height: 4),
            Text(
              '${metric.progress!.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Modèle pour une carte de métrique
class MetricCard {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final double? progress;

  const MetricCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.progress,
  });
}

/// Widget de résumé financier responsive
class ResponsiveFinancialSummary extends StatelessWidget {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final String currency;
  final List<FinancialBreakdown>? breakdown;

  const ResponsiveFinancialSummary({
    super.key,
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    this.currency = 'USD',
    this.breakdown,
  });

  @override
  Widget build(BuildContext context) {
    final netChange = totalIncome - totalExpense;
    final isPositive = netChange >= 0;

    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé Financier',
            style: TextStyle(
              fontSize: context.isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
              color: const Color(0xFFDC2626),
            ),
          ),
          SizedBox(height: context.isMobile ? 16 : 20),
          
          // Solde principal
          Container(
            padding: EdgeInsets.all(context.isMobile ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFFDC2626),
                  const Color(0xFFB91C1C),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Solde Total',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: context.isMobile ? 14 : 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_formatAmount(totalBalance)} $currency',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: context.isMobile ? 24 : 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: context.isMobile ? 16 : 20),
          
          // Revenus et dépenses
          ResponsiveGrid(
            forceColumns: context.isMobile ? 1 : 2,
            children: [
              _buildFinancialCard(
                'Revenus',
                totalIncome,
                currency,
                Icons.trending_up,
                Colors.green,
                context,
              ),
              _buildFinancialCard(
                'Dépenses',
                totalExpense,
                currency,
                Icons.trending_down,
                Colors.red,
                context,
              ),
            ],
          ),
          
          SizedBox(height: context.isMobile ? 16 : 20),
          
          // Variation nette
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isPositive ? Colors.green[50] : Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isPositive ? Colors.green[200]! : Colors.red[200]!,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  color: isPositive ? Colors.green[700] : Colors.red[700],
                ),
                const SizedBox(width: 8),
                Text(
                  'Variation: ${_formatAmount(netChange)} $currency',
                  style: TextStyle(
                    color: isPositive ? Colors.green[700] : Colors.red[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          
          // Répartition détaillée
          if (breakdown != null && breakdown!.isNotEmpty) ...[
            SizedBox(height: context.isMobile ? 16 : 20),
            Text(
              'Répartition',
              style: TextStyle(
                fontSize: context.isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 12),
            ...breakdown!.map((item) => _buildBreakdownItem(item, context)),
          ],
        ],
      ),
    );
  }

  Widget _buildFinancialCard(
    String title,
    double amount,
    String currency,
    IconData icon,
    Color color,
    BuildContext context,
  ) {
    return Container(
      padding: EdgeInsets.all(context.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: context.isMobile ? 14 : 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatAmount(amount)} $currency',
            style: TextStyle(
              color: color,
              fontSize: context.isMobile ? 18 : 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdownItem(FinancialBreakdown item, BuildContext context) {
    final percentage = totalBalance > 0 ? (item.amount / totalBalance * 100) : 0.0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: item.color,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: context.isMobile ? 14 : 16,
                color: Colors.grey[700],
              ),
            ),
          ),
          Text(
            '${_formatAmount(item.amount)} $currency',
            style: TextStyle(
              fontSize: context.isMobile ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: context.isMobile ? 12 : 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount.abs() >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    } else if (amount.abs() >= 1000) {
      return '${(amount / 1000).toStringAsFixed(0)}K';
    } else {
      return amount.toStringAsFixed(0);
    }
  }
}

/// Modèle pour la répartition financière
class FinancialBreakdown {
  final String label;
  final double amount;
  final Color color;

  const FinancialBreakdown({
    required this.label,
    required this.amount,
    required this.color,
  });
}
