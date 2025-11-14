import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_auth_service.dart';
import '../services/shop_service.dart';

class AgentCapitalOverview extends StatelessWidget {
  const AgentCapitalOverview({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AgentAuthService, ShopService>(
      builder: (context, authService, shopService, child) {
        if (authService.currentShop == null) {
          return const SizedBox.shrink();
        }

        final shop = authService.currentShop!;
        
        return Container(
          padding: const EdgeInsets.all(24),
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFF388E3C),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Capital du Shop',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF388E3C),
                          ),
                        ),
                        Text(
                          'Vue d\'ensemble des liquidités disponibles',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Capital total
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF388E3C), Color(0xFF2E7D32)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.white,
                      size: 32,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Capital Total',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_formatCurrency(shop.capitalActuel)} USD',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              
              // Détail par mode de paiement
              LayoutBuilder(
                builder: (context, constraints) {
                  final isMobile = constraints.maxWidth <= 600;
                  
                  if (isMobile) {
                    return Column(
                      children: [
                        _buildCapitalCard(
                          'Capital Initial',
                          shop.capitalInitial,
                          Icons.savings,
                          const Color(0xFF9C27B0),
                        ),
                        const SizedBox(height: 12),
                        _buildCapitalCard(
                          'Cash',
                          shop.capitalCash,
                          Icons.money,
                          const Color(0xFF4CAF50),
                        ),
                        const SizedBox(height: 12),
                        _buildCapitalCard(
                          'Airtel Money',
                          shop.capitalAirtelMoney,
                          Icons.phone_android,
                          const Color(0xFFE65100),
                        ),
                        const SizedBox(height: 12),
                        _buildCapitalCard(
                          'M-Pesa',
                          shop.capitalMPesa,
                          Icons.phone_android,
                          const Color(0xFF1976D2),
                        ),
                        const SizedBox(height: 12),
                        _buildCapitalCard(
                          'Orange Money',
                          shop.capitalOrangeMoney,
                          Icons.phone_android,
                          const Color(0xFFFF9800),
                        ),
                      ],
                    );
                  } else {
                    return Column(
                      children: [
                        // Ligne 1: Capital Initial
                        Row(
                          children: [
                            _buildCapitalCard(
                              'Capital Initial',
                              shop.capitalInitial,
                              Icons.savings,
                              const Color(0xFF9C27B0),
                            ),
                            const SizedBox(width: 16),
                            _buildCapitalCard(
                              'Cash',
                              shop.capitalCash,
                              Icons.money,
                              const Color(0xFF4CAF50),
                            ),
                            const SizedBox(width: 16),
                            _buildCapitalCard(
                              'Airtel Money',
                              shop.capitalAirtelMoney,
                              Icons.phone_android,
                              const Color(0xFFE65100),
                            ),
                            const SizedBox(width: 16),
                            _buildCapitalCard(
                              'M-Pesa',
                              shop.capitalMPesa,
                              Icons.phone_android,
                              const Color(0xFF1976D2),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Ligne 2: Orange Money (seul sur la ligne)
                        Row(
                          children: [
                            _buildCapitalCard(
                              'Orange Money',
                              shop.capitalOrangeMoney,
                              Icons.phone_android,
                              const Color(0xFFFF9800),
                            ),
                          ],
                        ),
                      ],
                    );
                  }
                },
              ),
              const SizedBox(height: 20),
              
              // Créances et dettes
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_upward, color: Colors.blue[600], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Créances',
                                style: TextStyle(
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatCurrency(shop.creances)} USD',
                            style: TextStyle(
                              color: Colors.blue[800],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.arrow_downward, color: Colors.red[600], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Dettes',
                                style: TextStyle(
                                  color: Colors.red[600],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_formatCurrency(shop.dettes)} USD',
                            style: TextStyle(
                              color: Colors.red[800],
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCapitalCard(String title, double amount, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${_formatCurrency(amount)} USD',
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
