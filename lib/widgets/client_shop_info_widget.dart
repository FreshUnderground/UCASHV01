import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../models/shop_model.dart';

/// Widget pour afficher les informations du shop du client
/// Affiche le nom, la localisation et se met à jour automatiquement
/// quand l'admin modifie le shop
class ClientShopInfoWidget extends StatelessWidget {
  const ClientShopInfoWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final shopService = Provider.of<ShopService>(context);
    final client = authService.currentClient;
    
    if (client == null || client.shopId == null) {
      return const SizedBox.shrink();
    }
    
    // Récupérer le shop du client
    final shop = shopService.getShopById(client.shopId!);
    
    if (shop == null) {
      return _buildLoadingCard();
    }
    
    return _buildShopInfoCard(shop);
  }
  
  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        children: [
          Icon(Icons.store, color: Color(0xFFDC2626), size: 40),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chargement...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Récupération des informations du shop',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildShopInfoCard(ShopModel shop) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.store,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre Shop UCASH',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      'Informations',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              // Badge "Synchronisé"
              if (shop.isSynced == true)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green, width: 1),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 12),
                      SizedBox(width: 4),
                      Text(
                        'Sync',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24, thickness: 1),
          const SizedBox(height: 16),
          
          // Nom du shop
          _buildInfoRow(
            icon: Icons.business,
            label: 'Nom du Shop',
            value: shop.designation,
          ),
          const SizedBox(height: 12),
          
          // Localisation
          _buildInfoRow(
            icon: Icons.location_on,
            label: 'Localisation',
            value: shop.localisation,
          ),
          const SizedBox(height: 12),
          
          // Devise principale
          _buildInfoRow(
            icon: Icons.attach_money,
            label: 'Devise',
            value: shop.devisePrincipale,
          ),
          
          // Dernière mise à jour (si disponible)
          if (shop.lastModifiedAt != null) ...[
            const SizedBox(height: 16),
            const Divider(color: Colors.white24, thickness: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.update, color: Colors.white70, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Dernière mise à jour: ${_formatDate(shop.lastModifiedAt!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.white70,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
  
  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inHours < 1) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inDays < 1) {
      return 'Il y a ${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return 'Il y a ${difference.inDays}j';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}
