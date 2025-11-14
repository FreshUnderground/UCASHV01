import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shop_service.dart';
import '../models/shop_model.dart';
import 'create_shop_dialog.dart';
import 'edit_shop_dialog.dart';
import 'capital_adjustment_dialog.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class ShopsManagement extends StatefulWidget {
  const ShopsManagement({super.key});

  @override
  State<ShopsManagement> createState() => _ShopsManagementState();
}

class _ShopsManagementState extends State<ShopsManagement> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    await shopService.loadShops();
  }



  @override
  Widget build(BuildContext context) {
    return context.pageContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header responsive
          _buildHeader(),
          context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
          
          // Statistiques rapides
          _buildStats(),
          context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
          
          // Tableau des shops
          Expanded(
            child: _buildShopsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.store,
                    color: Color(0xFFDC2626),
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🏪 Gestion des Shops',
                        style: TextStyle(
                          fontSize: isMobile ? 18 : 22,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Créer, modifier, supprimer les shops',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 16 : 20),
            
            // Boutons d'action CRUD bien visibles
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: const Text('➕ Créer un Shop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualiser'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              )
            else
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: const Text('➕ Créer un Shop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualiser la liste'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF1976D2),
                      side: const BorderSide(color: Color(0xFF1976D2), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const Spacer(),
                  // Info sur les actions disponibles
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Actions: ✏️ Modifier | 💰 Ajuster Capital | 🗑️ Supprimer',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        final stats = shopService.getShopsStats();
        return context.gridContainer(
          mobileColumns: 2,
          tabletColumns: 4,
          desktopColumns: 4,
          aspectRatio: context.isSmallScreen ? 1.3 : 1.1,
          children: [
            _buildStatCard(
              'Total Shops',
              '${stats['totalShops']}',
              Icons.store,
              const Color(0xFF1976D2),
            ),
            _buildStatCard(
              'Capital Total',
              '${_formatCurrency(stats['totalCapital'].round())} USD',
              Icons.monetization_on,
              const Color(0xFF388E3C),
            ),
            _buildStatCard(
              'Capital Moyen',
              '${_formatCurrency(stats['averageCapital'].round())} USD',
              Icons.trending_up,
              const Color(0xFFFF9800),
            ),
            _buildStatCard(
              'Shops Actifs',
              '${stats['activeShops']}',
              Icons.check_circle,
              const Color(0xFF4CAF50),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return context.statContainer(
      backgroundColor: color.withOpacity(0.1),
      borderColor: color.withOpacity(0.3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon, 
            color: color, 
            size: context.fluidIcon(mobile: 20, tablet: 24, desktop: 28),
          ),
          context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
          Text(
            value,
            style: context.statValue.copyWith(color: color),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          context.verticalSpace(mobile: 4, tablet: 6, desktop: 8),
          Text(
            title,
            style: context.statLabel,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildShopsTable() {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        if (shopService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final shops = shopService.shops;
        if (shops.isEmpty) {
          return _buildEmptyState();
        }

        return context.adaptiveCard(
          child: context.isSmallScreen ? _buildMobileShopsList(shops) : _buildDesktopShopsTable(shops),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.store_outlined,
            size: context.fluidIcon(mobile: 48, tablet: 56, desktop: 64),
            color: Colors.grey[400],
          ),
          context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
          Text(
            'Aucun shop créé',
            style: context.h3.copyWith(color: Colors.grey[600]),
          ),
          context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
          Text(
            'Cliquez sur "Nouveau Shop" pour créer votre premier shop',
            style: context.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShopsList(List<ShopModel> shops) {
    return ListView.separated(
      padding: context.fluidPadding(
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(16),
        desktop: const EdgeInsets.all(20),
      ),
      itemCount: shops.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final shop = shops[index];
        return _buildMobileShopCard(shop);
      },
    );
  }

  Widget _buildMobileShopCard(ShopModel shop) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    shop.designation,
                    style: context.h4,
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'edit') {
                      _showEditDialog(shop);
                    } else if (value == 'adjust_capital') {
                      _showCapitalAdjustmentDialog(shop);
                    } else if (value == 'delete') {
                      _showDeleteDialog(shop);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Modifier'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'adjust_capital',
                      child: Row(
                        children: [
                          Icon(Icons.account_balance, size: 18, color: Colors.green),
                          SizedBox(width: 8),
                          Text('Ajuster Capital'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Supprimer', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              shop.localisation ?? 'Non spécifié',
              style: context.bodySecondary,
            ),
            const SizedBox(height: 12),
            _buildCapitalGrid(shop),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalGrid(ShopModel shop) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.5,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildCapitalItem('Cash', shop.capitalCash, const Color(0xFF388E3C)),
        _buildCapitalItem('Airtel', shop.capitalAirtelMoney, const Color(0xFFE65100)),
        _buildCapitalItem('M-Pesa', shop.capitalMPesa, const Color(0xFF1976D2)),
        _buildCapitalItem('Orange', shop.capitalOrangeMoney, const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _buildCapitalItem(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${_formatCurrency(amount.round())} USD',
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopShopsTable(List<ShopModel> shops) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 100,
          ),
          child: DataTable(
            headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
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
              DataColumn(
                label: Text(
                  'Actions',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
            rows: shops.map((shop) => _buildShopRow(shop)).toList(),
          ),
        ),
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
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Modifier
              Tooltip(
                message: 'Modifier le shop',
                child: ElevatedButton.icon(
                  onPressed: () => _showEditDialog(shop),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('Modifier', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              
              // Ajuster Capital
              Tooltip(
                message: 'Ajuster le capital',
                child: ElevatedButton.icon(
                  onPressed: () => _showCapitalAdjustmentDialog(shop),
                  icon: const Icon(Icons.account_balance, size: 14),
                  label: const Text('Capital', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              
              // Supprimer
              Tooltip(
                message: 'Supprimer le shop',
                child: ElevatedButton.icon(
                  onPressed: () => _showDeleteDialog(shop),
                  icon: const Icon(Icons.delete, size: 14),
                  label: const Text('Supprimer', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    minimumSize: const Size(0, 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateShopDialog(),
    ).then((_) => _loadData());
  }

  void _showEditDialog(ShopModel shop) {
    showDialog(
      context: context,
      builder: (context) => EditShopDialog(shop: shop),
    ).then((_) => _loadData());
  }

  void _showDeleteDialog(ShopModel shop) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le shop "${shop.designation}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                final shopService = Provider.of<ShopService>(context, listen: false);
                await shopService.deleteShop(shop.id!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Shop supprimé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
                _loadData();
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showCapitalAdjustmentDialog(ShopModel shop) {
    showDialog(
      context: context,
      builder: (context) => CapitalAdjustmentDialog(shop: shop),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  String _formatCurrency(int amount) {
    return amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }
}
