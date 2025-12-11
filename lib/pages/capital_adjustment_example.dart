import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/shop_model.dart';
import '../services/shop_service.dart';
import '../widgets/capital_adjustment_dialog_tracked.dart';
import '../widgets/reports/capital_adjustments_history.dart';

/// Exemple d'utilisation du système de traçabilité des ajustements de capital
/// 
/// Ce widget peut être intégré dans n'importe quelle page admin qui gère les shops
class CapitalAdjustmentExample extends StatelessWidget {
  const CapitalAdjustmentExample({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Gestion du Capital des Shops'),
        backgroundColor: Color(0xFFDC2626),
      ),
      body: Consumer<ShopService>(
        builder: (context, shopService, _) {
          if (shopService.isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (shopService.shops.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.store, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Aucun shop disponible'),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: shopService.shops.length,
            itemBuilder: (context, index) {
              final shop = shopService.shops[index];
              return _buildShopCard(context, shop);
            },
          );
        },
      ),
    );
  }

  Widget _buildShopCard(BuildContext context, ShopModel shop) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête avec nom du shop
            Row(
              children: [
                Icon(Icons.store, color: Color(0xFFDC2626), size: 32),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shop.designation,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (shop.localisation.isNotEmpty)
                        Text(
                          shop.localisation,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(height: 24),

            // Informations du capital
            Text(
              'Capital actuel',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildCapitalRow(
                    'Total',
                    shop.capitalActuel,
                    Colors.blue[700]!,
                    isBold: true,
                  ),
                  Divider(height: 16),
                  _buildCapitalRow('Cash', shop.capitalCash, Colors.green),
                  _buildCapitalRow('Airtel Money', shop.capitalAirtelMoney, Colors.red),
                  _buildCapitalRow('M-Pesa', shop.capitalMPesa, Colors.green[700]!),
                  _buildCapitalRow('Orange Money', shop.capitalOrangeMoney, Colors.orange),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showAdjustmentDialog(context, shop),
                    icon: Icon(Icons.account_balance_wallet),
                    label: Text('Ajuster le Capital'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showHistory(context, shop),
                    icon: Icon(Icons.history),
                    label: Text('Voir l\'Historique'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Color(0xFFDC2626),
                      side: BorderSide(color: Color(0xFFDC2626)),
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalRow(String label, double amount, Color color, {bool isBold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? color : Colors.grey[700],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: isBold ? 16 : 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  void _showAdjustmentDialog(BuildContext context, ShopModel shop) {
    showDialog(
      context: context,
      builder: (context) => CapitalAdjustmentDialogWithTracking(
        shop: shop,
      ),
    ).then((result) {
      if (result == true) {
        // L'ajustement a été effectué avec succès
        // Le ShopService a déjà été rafraîchi dans le dialogue
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Capital mis à jour et tracé dans l\'audit log'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showHistory(BuildContext context, ShopModel shop) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Historique - ${shop.designation}'),
            backgroundColor: Color(0xFFDC2626),
          ),
          body: CapitalAdjustmentsHistory(shop: shop),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// EXEMPLE D'INTÉGRATION DANS UN DASHBOARD EXISTANT
// ═══════════════════════════════════════════════════════════════════════════════

/// Widget simple pour ajouter un bouton d'ajustement de capital
/// dans un menu contextuel existant
class ShopActionsMenu extends StatelessWidget {
  final ShopModel shop;

  const ShopActionsMenu({super.key, required this.shop});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: Icon(Icons.more_vert),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 12),
              Text('Modifier'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'adjust_capital',
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet, size: 20, color: Color(0xFFDC2626)),
              SizedBox(width: 12),
              Text('Ajuster le Capital', style: TextStyle(color: Color(0xFFDC2626))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'history',
          child: Row(
            children: [
              Icon(Icons.history, size: 20),
              SizedBox(width: 12),
              Text('Historique des Ajustements'),
            ],
          ),
        ),
        PopupMenuDivider(),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Supprimer', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'edit':
            // Logique d'édition existante
            break;
          case 'adjust_capital':
            _showAdjustmentDialog(context);
            break;
          case 'history':
            _showHistory(context);
            break;
          case 'delete':
            // Logique de suppression existante
            break;
        }
      },
    );
  }

  void _showAdjustmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => CapitalAdjustmentDialogWithTracking(shop: shop),
    );
  }

  void _showHistory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Historique - ${shop.designation}'),
            backgroundColor: Color(0xFFDC2626),
          ),
          body: CapitalAdjustmentsHistory(shop: shop),
        ),
      ),
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// EXEMPLE POUR UN DASHBOARD GLOBAL (TOUS LES SHOPS)
// ═══════════════════════════════════════════════════════════════════════════════

class GlobalCapitalAdjustmentsPage extends StatelessWidget {
  const GlobalCapitalAdjustmentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tous les Ajustements de Capital'),
        backgroundColor: Color(0xFFDC2626),
      ),
      body: CapitalAdjustmentsHistory(), // Sans paramètre = tous les shops
    );
  }
}


// ═══════════════════════════════════════════════════════════════════════════════
// COMMENT UTILISER DANS VOTRE CODE EXISTANT
// ═══════════════════════════════════════════════════════════════════════════════

/*

OPTION 1: Page complète dédiée
------------------------------
Dans votre navigation principale (drawer, bottom nav, etc.), ajoutez:

NavigationMenuItem(
  icon: Icons.account_balance_wallet,
  title: 'Gestion du Capital',
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CapitalAdjustmentExample()),
    );
  },
)


OPTION 2: Menu contextuel dans une liste de shops existante
------------------------------------------------------------
Dans votre ListView.builder des shops:

ListTile(
  title: Text(shop.designation),
  subtitle: Text('Capital: ${shop.capitalActuel} USD'),
  trailing: ShopActionsMenu(shop: shop), // ← Ajouter ici
)


OPTION 3: Bouton flottant dans une page de détails d'un shop
-------------------------------------------------------------
Dans votre page de détails de shop:

floatingActionButton: FloatingActionButton.extended(
  onPressed: () {
    showDialog(
      context: context,
      builder: (context) => CapitalAdjustmentDialogWithTracking(shop: currentShop),
    );
  },
  icon: Icon(Icons.account_balance_wallet),
  label: Text('Ajuster le Capital'),
  backgroundColor: Color(0xFFDC2626),
)


OPTION 4: Onglet dans un TabBar
--------------------------------
TabBar(
  tabs: [
    Tab(text: 'Informations'),
    Tab(text: 'Opérations'),
    Tab(text: 'Ajustements Capital'),  // ← Nouvel onglet
  ],
)

TabBarView(
  children: [
    ShopInfoTab(),
    ShopOperationsTab(),
    CapitalAdjustmentsHistory(shop: currentShop),  // ← Contenu
  ],
)


OPTION 5: Card dans un dashboard récapitulatif
-----------------------------------------------
Column(
  children: [
    ShopSummaryCard(),
    RecentOperationsCard(),
    RecentCapitalAdjustmentsCard(),  // ← Nouvelle card
  ],
)

class RecentCapitalAdjustmentsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('Ajustements Récents'),
            trailing: TextButton(
              child: Text('Voir tout'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => GlobalCapitalAdjustmentsPage(),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: 200,
            child: CapitalAdjustmentsHistory(limit: 5),
          ),
        ],
      ),
    );
  }
}

*/
