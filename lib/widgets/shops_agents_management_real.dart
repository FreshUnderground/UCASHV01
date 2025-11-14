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
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    if (isMobile) {
      return Column(
        children: [
          _buildShopsSection(),
          const SizedBox(height: 20),
          _buildAgentsSection(),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildShopsSection()),
        const SizedBox(width: 20),
        Expanded(child: _buildAgentsSection()),
      ],
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

              return Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: shops.length,
                  itemBuilder: (context, index) {
                    final shop = shops[index];
                    return _buildShopItem(shop);
                  },
                ),
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

              return Container(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    return _buildAgentItem(agent);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(ShopModel shop) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.store,
          color: Color(0xFFDC2626),
          size: 20,
        ),
      ),
      title: Text(
        shop.designation,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(shop.localisation ?? 'Non spécifié'),
          Text(
            'Capital: ${shop.capitalActuel.toStringAsFixed(0)} USD',
            style: const TextStyle(
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16),
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
                Text('Supprimer', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'delete') {
            _confirmDeleteShop(shop);
          }
        },
      ),
    );
  }

  Widget _buildAgentItem(AgentModel agent) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFFDC2626).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.person,
          color: Color(0xFFDC2626),
          size: 20,
        ),
      ),
      title: Text(
        agent.username,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (agent.nom != null) Text('Nom: ${agent.nom}'),
          Text('Shop ID: ${agent.shopId}'),
          if (agent.telephone != null) Text('Tél: ${agent.telephone}'),
        ],
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, size: 16),
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
                Text('Supprimer', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        ],
        onSelected: (value) {
          if (value == 'delete') {
            _confirmDeleteAgent(agent);
          }
        },
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
