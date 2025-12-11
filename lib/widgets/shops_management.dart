import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header responsive
        _buildHeader(),
        context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
        
        // Statistiques rapides
        _buildStats(),
        context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
        
        // Tableau des shops
        _buildShopsTable(),
      ],
    );
  }

  Widget _buildHeader() {
    final l10n = AppLocalizations.of(context)!;
    return context.adaptiveCard(
      child: Row(
        children: [
          Expanded(
            child: Text(
              l10n.shopsManagement,
              style: context.titleAccent,
            ),
          ),
          if (!context.isSmallScreen) ...[
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: Icon(Icons.refresh, size: context.fluidIcon(mobile: 16, tablet: 18, desktop: 20)),
              label: Text(l10n.refresh),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(context.fluidBorderRadius()),
                ),
              ),
            ),
            context.horizontalSpace(mobile: 8, tablet: 12, desktop: 16),
          ],
          ElevatedButton.icon(
            onPressed: _showCreateDialog,
            icon: Icon(Icons.add, size: context.fluidIcon(mobile: 16, tablet: 18, desktop: 20)),
            label: Text(context.isSmallScreen ? l10n.add : l10n.newShop),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(context.fluidBorderRadius()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStats() {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        final stats = shopService.getShopsStats();
        return context.gridContainer(
          mobileColumns: 2,
          tabletColumns: 4,
          desktopColumns: 4,
          aspectRatio: context.isSmallScreen ? 1.4 : 1.1,
          children: [
            _buildStatCard(
              l10n.totalShops,
              '${stats['totalShops']}',
              Icons.store,
              const Color(0xFF1976D2),
            ),
            _buildStatCard(
              l10n.totalCapital,
              '${_formatCurrency(stats['totalCapital'].round())} USD',
              Icons.monetization_on,
              const Color(0xFF388E3C),
            ),
            _buildStatCard(
              l10n.averageCapital,
              '${_formatCurrency(stats['averageCapital'].round())} USD',
              Icons.trending_up,
              const Color(0xFFFF9800),
            ),
            _buildStatCard(
              l10n.activeShops,
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
    final isMobile = MediaQuery.of(context).size.width <= 600;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 16),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 8 : 10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon, 
              color: color, 
              size: isMobile ? 18 : 24,
            ),
          ),
          SizedBox(height: isMobile ? 8 : 12),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 14 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isMobile ? 4 : 6),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 9 : 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
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
          child: SingleChildScrollView(
            child: context.isSmallScreen ? _buildMobileShopsList(shops) : _buildDesktopShopsTable(shops),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.people_outline,
            size: context.fluidIcon(mobile: 48, tablet: 56, desktop: 64),
            color: Colors.grey[400],
          ),
          context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
          Text(
            l10n.noShopsFound,
            style: context.h3.copyWith(color: Colors.grey[600]),
          ),
          context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
          Text(
            l10n.clickNewShopToCreate,
            style: context.bodySecondary,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileShopsList(List<ShopModel> shops) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shops.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) => _buildMobileShopCard(shops[index]),
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
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit, size: 18),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.edit),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'adjust_capital',
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance, size: 18, color: Colors.green),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.adjustCapital),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 18, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(AppLocalizations.of(context)!.delete, style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              shop.localisation ?? AppLocalizations.of(context)!.notSpecified,
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
      crossAxisCount: 1,  // Changé de 2 à 1 car on n'affiche que Cash
      childAspectRatio: 5.0,  // Ajusté pour une seule ligne
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      children: [
        _buildCapitalItem('Cash', shop.capitalCash, const Color(0xFF388E3C)),
        // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
        // _buildCapitalItem('Airtel', shop.capitalAirtelMoney, const Color(0xFFE65100)),
        // _buildCapitalItem('M-Pesa', shop.capitalMPesa, const Color(0xFF1976D2)),
        // _buildCapitalItem('Orange', shop.capitalOrangeMoney, const Color(0xFFFF9800)),
      ],
    );
  }

  Widget _buildCapitalItem(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${_formatCurrency(amount.round())} USD',
            style: TextStyle(
              fontSize: 13,
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
    final l10n = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: BoxConstraints(
        minWidth: MediaQuery.of(context).size.width - 100,
      ),
      child: DataTable(
        headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
        columns: [
            DataColumn(
              label: Text(
                l10n.shopName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                l10n.location,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                l10n.capitalCash,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
            // DataColumn(
            //   label: Text(
            //     'Airtel Money',
            //     style: TextStyle(fontWeight: FontWeight.bold),
            //   ),
            // ),
            // DataColumn(
            //   label: Text(
            //     'M-Pesa',
            //     style: TextStyle(fontWeight: FontWeight.bold),
            //   ),
            // ),
            // DataColumn(
            //   label: Text(
            //     'Orange Money',
            //     style: TextStyle(fontWeight: FontWeight.bold),
            //   ),
            // ),
            DataColumn(
              label: Text(
                l10n.totalCapital,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            DataColumn(
              label: Text(
                l10n.actions,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
        ],
        rows: shops.map((shop) => _buildShopRow(shop)).toList(),
      ),
    );
  }

  DataRow _buildShopRow(ShopModel shop) {
    final l10n = AppLocalizations.of(context)!;
    return DataRow(
      cells: [
        DataCell(
          Text(
            shop.designation,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        DataCell(Text(shop.localisation ?? l10n.notSpecified)),
        DataCell(
          Text(
            '${_formatCurrency(shop.capitalCash.round())} USD',
            style: const TextStyle(
              color: Color(0xFF388E3C),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
        // DataCell(
        //   Text(
        //     '${_formatCurrency(shop.capitalAirtelMoney.round())} USD',
        //     style: const TextStyle(
        //       color: Color(0xFFE65100),
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        // ),
        // DataCell(
        //   Text(
        //     '${_formatCurrency(shop.capitalMPesa.round())} USD',
        //     style: const TextStyle(
        //       color: Color(0xFF1976D2),
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        // ),
        // DataCell(
        //   Text(
        //     '${_formatCurrency(shop.capitalOrangeMoney.round())} USD',
        //     style: const TextStyle(
        //       color: Color(0xFFFF9800),
        //       fontWeight: FontWeight.w500,
        //     ),
        //   ),
        // ),
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
              IconButton(
                onPressed: () => _showEditDialog(shop),
                icon: const Icon(Icons.edit, size: 18),
                tooltip: AppLocalizations.of(context)!.edit,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1976D2).withOpacity(0.1),
                  foregroundColor: const Color(0xFF1976D2),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showCapitalAdjustmentDialog(shop),
                icon: const Icon(Icons.account_balance, size: 18),
                tooltip: AppLocalizations.of(context)!.adjustCapital,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.green.withOpacity(0.1),
                  foregroundColor: Colors.green,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _showDeleteDialog(shop),
                icon: const Icon(Icons.delete, size: 18),
                tooltip: AppLocalizations.of(context)!.delete,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.red.withOpacity(0.1),
                  foregroundColor: Colors.red,
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
    final l10n = AppLocalizations.of(context)!;
    final reasonController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.red),
            const SizedBox(width: 12),
            Text(l10n.confirmDelete),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.confirmDeleteShop,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              shop.designation,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.thisActionCannotBeUndone,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 16),
            // Raison de la suppression (obligatoire)
            Text(
              '${l10n.reason} *',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Ex: Shop fermé définitivement, fusion avec un autre shop...',
                hintStyle: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              
              // Validation de la raison
              if (reason.isEmpty || reason.length < 10) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.reasonMinLength),
                    backgroundColor: Colors.orange,
                  ),
                );
                return;
              }
              
              Navigator.of(context).pop();
              
              // Afficher un indicateur de chargement
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );
              
              try {
                final shopService = Provider.of<ShopService>(context, listen: false);
                final authService = Provider.of<AuthService>(context, listen: false);
                final user = authService.currentUser;
                
                if (user == null) {
                  throw Exception(l10n.userNotConnected);
                }
                
                // Utiliser la nouvelle API avec audit trail
                final result = await shopService.deleteShopViaAPI(
                  shop.id!,
                  adminId: user.id.toString(),
                  adminUsername: user.username,
                  reason: reason,
                  deleteType: 'soft', // Soft delete par défaut
                  forceDelete: false,
                );
                
                // Fermer le loader
                if (mounted) Navigator.of(context).pop();
                
                if (result != null && result['success'] == true) {
                  if (mounted) {
                    final affectedAgents = result['affected_agents']['count'] ?? 0;
                    
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('✅ ${l10n.shopDeletedSuccessfully}'),
                            if (affectedAgents > 0) ...[
                              const SizedBox(height: 4),
                              Text(
                                '👥 $affectedAgents ${affectedAgents > 1 ? "agents désassignés" : "agent désassigné"}',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                    _loadData();
                  }
                } else {
                  // Fermer le loader si erreur
                  if (mounted) Navigator.of(context).pop();
                  
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${l10n.error}: ${result?['message'] ?? 'Erreur inconnue'}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              } catch (e) {
                // Fermer le loader si exception
                if (mounted) Navigator.of(context).pop();
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${l10n.error}: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.white)),
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
