import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/shop_service.dart';
import '../services/agent_service.dart';
import '../models/shop_model.dart';
import '../models/agent_model.dart';
import '../services/local_db.dart';
import 'create_shop_dialog.dart';
import 'create_agent_dialog.dart';

class ShopsAgentsManagementReal extends StatefulWidget {
  const ShopsAgentsManagementReal({super.key});

  @override
  State<ShopsAgentsManagementReal> createState() => _ShopsAgentsManagementRealState();
}

class _ShopsAgentsManagementRealState extends State<ShopsAgentsManagementReal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    Provider.of<ShopService>(context, listen: false).loadShops();
    Provider.of<AgentService>(context, listen: false).loadAgents();
  }

  Widget _buildHeader() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gestion des Shops & Agents',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gérez efficacement vos shops et agents',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Actualiser', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _verifyAdminExists,
                    icon: const Icon(Icons.admin_panel_settings, color: Colors.white),
                    label: const Text('Vérifier Admin', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white24,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Consumer2<ShopService, AgentService>(
      builder: (context, shopService, agentService, child) {
        final shopCount = shopService.shops.length;
        final agentCount = agentService.agents.length;
        // Since ShopModel doesn't have isActive, we'll show total shops
        final activeShops = shopCount;
        final activeAgents = agentService.agents.where((agent) => agent.isActive).length;
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 600;
                    
                    if (isCompact) {
                      return Column(
                        children: [
                          _buildStatCard('Shops', '$shopCount', Icons.store, Colors.blue, compact: true),
                          const SizedBox(height: 12),
                          _buildStatCard('Agents', '$agentCount', Icons.person, Colors.green, compact: true),
                          const SizedBox(height: 12),
                          _buildStatCard('Shops', '$activeShops', Icons.check_circle, Colors.orange, compact: true),
                          const SizedBox(height: 12),
                          _buildStatCard('Agents Actifs', '$activeAgents', Icons.verified, Colors.purple, compact: true),
                        ],
                      );
                    } else {
                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatCard('Shops', '$shopCount', Icons.store, Colors.blue),
                          _buildStatCard('Agents', '$agentCount', Icons.person, Colors.green),
                          _buildStatCard('Shops', '$activeShops', Icons.check_circle, Colors.orange),
                          _buildStatCard('Agents Actifs', '$activeAgents', Icons.verified, Colors.purple),
                        ],
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, {bool compact = false}) {
    return Container(
      width: compact ? double.infinity : null,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }


  Future<void> _verifyAdminExists() async {
    await LocalDB.instance.ensureAdminExists();
    final admin = await LocalDB.instance.getDefaultAdmin();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.green),
              SizedBox(width: 8),
              Text('Vérification Admin'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (admin != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                const Text('✅ Admin par défaut présent et protégé'),
                const SizedBox(height: 8),
                Text('Username: ${admin.username}'),
                Text('Role: ${admin.role}'),
                Text('ID: ${admin.id}'),
                const SizedBox(height: 8),
                const Text('🔐 Clé protégée: admin_default', 
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              ] else ...[
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                const Text('❌ Admin par défaut manquant !'),
                const SizedBox(height: 8),
                const Text('L\'admin sera recréé automatiquement.'),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _verifyMySQLCompatibility() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Colors.blue),
            SizedBox(width: 8),
            Text('Vérification MySQL'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Vérification de la compatibilité des données avec votre table MySQL agents...'),
            SizedBox(height: 16),
            Text('Consultez la console (F12) pour voir le rapport détaillé.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );

    // Lancer la vérification
    await LocalDB.instance.verifyMySQLCompatibility();
  }

  Future<void> _clearAllAgents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nettoyer tous les agents'),
        content: const Text('Êtes-vous sûr de vouloir supprimer TOUS les agents ? Cette action est irréversible.'),
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

    if (confirmed == true) {
      await LocalDB.instance.clearAllAgents();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tous les agents ont été supprimés'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 768;
            final isTablet = constraints.maxWidth >= 768 && constraints.maxWidth < 1024;
            
            if (isMobile) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatisticsSection(),
                  const SizedBox(height: 20),
                  _buildShopsSection(),
                  const SizedBox(height: 20),
                  _buildAgentsSection(),
                ],
              );
            } else {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildStatisticsSection(),
                  const SizedBox(height: 20),
                  if (isTablet)
                    Column(
                      children: [
                        _buildShopsSection(),
                        const SizedBox(height: 20),
                        _buildAgentsSection(),
                      ],
                    )
                  else
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 1, child: _buildShopsSection()),
                        const SizedBox(width: 20),
                        Expanded(flex: 1, child: _buildAgentsSection()),
                      ],
                    ),
                ],
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildShopsSection() {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestion des Shops',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showCreateShopDialog(context),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Nouveau'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Consumer<ShopService>(
            builder: (context, shopService, child) {
              if (shopService.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (shopService.errorMessage != null) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Erreur: ${shopService.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final shops = shopService.shops;
              if (shops.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Aucun shop créé',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: shops.map((shop) => _buildShopItem(shop)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsSection() {
    return Container(
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
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Gestion des Agents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _loadData,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser',
                      color: const Color(0xFFDC2626),
                    ),
                    IconButton(
                      onPressed: _verifyAdminExists,
                      icon: const Icon(Icons.admin_panel_settings),
                      tooltip: 'Vérifier Admin',
                      color: Colors.green,
                    ),
                    IconButton(
                      onPressed: _verifyMySQLCompatibility,
                      icon: const Icon(Icons.analytics),
                      tooltip: 'Vérifier compatibilité MySQL',
                      color: Colors.blue,
                    ),
                    IconButton(
                      onPressed: _clearAllAgents,
                      icon: const Icon(Icons.clear_all),
                      tooltip: 'Nettoyer tous les agents',
                      color: Colors.orange,
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () => _showCreateAgentDialog(context),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Nouveau'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Consumer<AgentService>(
            builder: (context, agentService, child) {
              if (agentService.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (agentService.errorMessage != null) {
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'Erreur: ${agentService.errorMessage}',
                    style: const TextStyle(color: Colors.red),
                  ),
                );
              }

              final agents = agentService.agents;
              if (agents.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Aucun agent créé',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Column(
                children: agents.map((agent) => _buildAgentItem(agent)).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(ShopModel shop) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.store,
                color: Color(0xFFDC2626),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shop.designation,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    shop.localisation ?? 'Non spécifié',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF388E3C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Capital: ${shop.capitalActuel.toStringAsFixed(0)} USD',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF388E3C),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  // TODO: Implement edit functionality
                } else if (value == 'delete') {
                  _confirmDeleteShop(shop);
                }
              },
              icon: const Icon(Icons.more_vert, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentItem(AgentModel agent) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1976D2).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person,
                color: Color(0xFF1976D2),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          agent.username,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1976D2),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (agent.isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Actif',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.green,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Inactif',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (agent.nom != null)
                    Text(
                      agent.nom!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    'Shop ID: ${agent.shopId}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                  if (agent.telephone != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Tél: ${agent.telephone}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text('Modifier'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 16, color: Colors.red),
                      SizedBox(width: 8),
                      Text('Supprimer'),
                    ],
                  ),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  // TODO: Implement edit functionality
                } else if (value == 'delete') {
                  _confirmDeleteAgent(agent);
                }
              },
              icon: const Icon(Icons.more_vert, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateShopDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateShopDialog(),
    ).then((_) {
      // Recharger les données après fermeture du dialog
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadData();
      });
    });
  }

  void _showCreateAgentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const CreateAgentDialog(),
    ).then((_) {
      // Recharger les données après fermeture du dialog
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadData();
      });
    });
  }

  void _confirmDeleteShop(ShopModel shop) {
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
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<ShopService>(context, listen: false).deleteShop(shop.id!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteAgent(AgentModel agent) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer l\'agent "${agent.username}" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              Provider.of<AgentService>(context, listen: false).deleteAgent(agent.id!);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}
