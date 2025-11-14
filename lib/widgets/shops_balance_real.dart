import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';
import '../models/shop_model.dart';

class ShopsBalanceReal extends StatefulWidget {
  const ShopsBalanceReal({super.key});

  @override
  State<ShopsBalanceReal> createState() => _ShopsBalanceRealState();
}

class _ShopsBalanceRealState extends State<ShopsBalanceReal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    await shopService.loadShops();
    // Plus de création de données par défaut - seulement les vraies données
  }

  void _clearAllData() async {
    // Demander confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer toutes les données'),
        content: const Text(
          'Êtes-vous sûr de vouloir supprimer toutes les données (shops, agents, taux, commissions) ?\n\nSeul l\'admin sera conservé.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer tout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Supprimer toutes les données sauf l'admin
      await LocalDB.instance.clearAllDataExceptAdmin();
      
      // Recharger les données
      _loadData();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Toutes les données ont été supprimées (admin conservé)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Soldes par Shop',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1976D2),
                ),
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1976D2),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('CSV'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF388E3C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _clearAllData,
                    icon: const Icon(Icons.delete_sweep, size: 16),
                    label: const Text('Nettoyer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 2,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Consumer<ShopService>(
              builder: (context, shopService, child) {
                if (shopService.isLoading) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final shops = shopService.shops;
                if (shops.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(
                      child: Text(
                        'Aucun shop créé. Allez dans "Shops" pour créer votre premier shop.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(Colors.grey[100]),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Shop',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Localisation',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Capital Cash',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Airtel Money',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'M-Pesa',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Orange Money',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Total Capital',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                    rows: shops.map((shop) => _buildShopRow(shop)).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildShopRow(ShopModel shop) {
    return DataRow(
      cells: [
        DataCell(
          Text(
            shop.designation,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(shop.localisation ?? 'Non spécifié')),
        DataCell(
          Text(
            '${_formatCurrency(shop.capitalCash.round())} USD',
            style: const TextStyle(
              color: Color(0xFF388E3C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            '${_formatCurrency(shop.capitalAirtelMoney.round())} USD',
            style: const TextStyle(
              color: Color(0xFFE65100),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            '${_formatCurrency(shop.capitalMPesa.round())} USD',
            style: const TextStyle(
              color: Color(0xFF1976D2),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            '${_formatCurrency(shop.capitalOrangeMoney.round())} USD',
            style: const TextStyle(
              color: Color(0xFFFF9800),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DataCell(
          Text(
            '${_formatCurrency(shop.capitalActuel.round())} USD',
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
