import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';
import 'create_agent_dialog.dart';
import 'edit_agent_dialog.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class AgentsManagementWidget extends StatefulWidget {
  const AgentsManagementWidget({super.key});

  @override
  State<AgentsManagementWidget> createState() => _AgentsManagementWidgetState();
}

class _AgentsManagementWidgetState extends State<AgentsManagementWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    Provider.of<AgentService>(context, listen: false).loadAgents();
    Provider.of<ShopService>(context, listen: false).loadShops();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight,
            ),
            child: IntrinsicHeight(
              child: Card(
                elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 1, tablet: 1.5, desktop: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header avec boutons d'action
                    Container(
                      padding: ResponsiveUtils.getFluidPadding(
                        context,
                        mobile: const EdgeInsets.all(16),
                        tablet: const EdgeInsets.all(18),
                        desktop: const EdgeInsets.all(20),
                      ),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Gestion des Agents',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 16, tablet: 17, desktop: 18),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          _buildActionButtons(),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    
                    // Statistiques des agents
                    _buildAgentStats(),
                    
                    const Divider(height: 1),
                    
                    // Liste des agents
                    Expanded(
                      child: _buildAgentsList(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButtons() {
    if (context.isSmallScreen) {
      return Wrap(
        spacing: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8),
        runSpacing: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8),
        children: [
          // Bouton Actualiser
          IconButton(
            onPressed: _loadData,
            icon: Icon(Icons.refresh,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: 'Actualiser',
            color: const Color(0xFFDC2626),
          ),
          
          // Bouton Vérifier Admin
          IconButton(
            onPressed: _verifyAdminExists,
            icon: Icon(Icons.admin_panel_settings,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: 'Vérifier Admin',
            color: Colors.green,
          ),
          
          // Bouton Debug
          IconButton(
            onPressed: _showDebugInfo,
            icon: Icon(Icons.bug_report,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: 'Debug Info',
            color: Colors.purple,
          ),
          
          // Bouton Agents de Test
          IconButton(
            onPressed: _createTestAgents,
            icon: Icon(Icons.science,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: 'Créer Agents de Test',
            color: Colors.cyan,
          ),
          
          // Bouton Nouveau Agent
          ElevatedButton.icon(
            onPressed: _showCreateAgentDialog,
            icon: Icon(Icons.person_add,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
            label: Text('Nouveau',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                ),
              ),
            ),
          ),
        ],
      );
    }
    
    return Row(
      children: [
        // Bouton Actualiser
        IconButton(
          onPressed: _loadData,
          icon: Icon(Icons.refresh,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: 'Actualiser',
          color: const Color(0xFFDC2626),
        ),
        
        // Bouton Vérifier Admin
        IconButton(
          onPressed: _verifyAdminExists,
          icon: Icon(Icons.admin_panel_settings,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: 'Vérifier Admin',
          color: Colors.green,
        ),
        
        // Bouton Debug
        IconButton(
          onPressed: _showDebugInfo,
          icon: Icon(Icons.bug_report,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: 'Debug Info',
          color: Colors.purple,
        ),
        
        // Bouton Agents de Test
        IconButton(
          onPressed: _createTestAgents,
          icon: Icon(Icons.science,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: 'Créer Agents de Test',
          color: Colors.cyan,
        ),
        
        SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
        
        // Bouton Nouveau Agent
        ElevatedButton.icon(
          onPressed: _showCreateAgentDialog,
          icon: Icon(Icons.person_add,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
          ),
          label: Text('Nouveau Agent',
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
            padding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              tablet: const EdgeInsets.symmetric(horizontal: 15, vertical: 7.5),
              desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAgentStats() {
    return Consumer<AgentService>(
      builder: (context, agentService, child) {
        final agents = agentService.agents;
        final activeAgents = agents.where((a) => a.isActive).length;
        
        if (context.isSmallScreen) {
          return Container(
            padding: ResponsiveUtils.getFluidPadding(
              context,
              mobile: const EdgeInsets.all(16),
              tablet: const EdgeInsets.all(18),
              desktop: const EdgeInsets.all(20),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Total Agents',
                        '${agents.length}',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                    Expanded(
                      child: _buildStatCard(
                        'Agents Actifs',
                        '$activeAgents',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                _buildStatCard(
                  'Agents Inactifs',
                  '${agents.length - activeAgents}',
                  Icons.person_off,
                  Colors.orange,
                ),
              ],
            ),
          );
        }
        
        return Container(
          padding: ResponsiveUtils.getFluidPadding(
            context,
            mobile: const EdgeInsets.all(16),
            tablet: const EdgeInsets.all(18),
            desktop: const EdgeInsets.all(20),
          ),
          child: Row(
            children: [
              _buildStatCard(
                'Total Agents',
                '${agents.length}',
                Icons.people,
                Colors.blue,
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              _buildStatCard(
                'Agents Actifs',
                '$activeAgents',
                Icons.check_circle,
                Colors.green,
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              _buildStatCard(
                'Agents Inactifs',
                '${agents.length - activeAgents}',
                Icons.person_off,
                Colors.orange,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.all(12),
        tablet: const EdgeInsets.all(14),
        desktop: const EdgeInsets.all(16),
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
        ),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, 
            color: color, 
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 19, desktop: 20),
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 3, tablet: 3.5, desktop: 4)),
          Text(
            title,
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAgentsList() {
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        if (agentService.isLoading) {
          return const Padding(
            padding: EdgeInsets.all(40),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (agentService.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${agentService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final agents = agentService.agents;
        if (agents.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.people_outline, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Aucun agent créé',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cliquez sur "Nouveau Agent" pour créer votre premier agent',
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateAgentDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Créer un Agent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        // Liste des agents dans une colonne (déjà dans un SingleChildScrollView)
        return Column(
          children: [
            for (int i = 0; i < agents.length; i++) ...[
              _buildAgentItem(
                agents[i],
                shopService.shops.firstWhere(
                  (s) => s.id == agents[i].shopId,
                  orElse: () => ShopModel(
                    id: 0,
                    designation: 'Shop Inconnu',
                    localisation: 'Localisation inconnue',
                    capitalInitial: 0,
                  ),
                ),
              ),
              if (i < agents.length - 1) const Divider(height: 1),
            ],
          ],
        );
      },
    );
  }

  Widget _buildAgentItem(AgentModel agent, ShopModel shop) {
    return ListTile(
      contentPadding: ResponsiveUtils.getFluidPadding(
        context,
        mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      leading: CircleAvatar(
        radius: ResponsiveUtils.getFluidSpacing(context, mobile: 20, tablet: 22, desktop: 24),
        backgroundColor: agent.isActive 
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        child: Icon(
          Icons.person,
          color: agent.isActive ? Colors.green : Colors.grey,
          size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
        ),
      ),
      title: Text(
        agent.username,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Shop ID: ${agent.shopId} - ${shop.designation}',
              style: TextStyle(
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              agent.isActive ? "✓ Actif" : "✗ Inactif",
              style: TextStyle(
                color: agent.isActive ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
              ),
            ),
          ],
        ),
      ),
      trailing: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert,
          size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
        ),
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, 
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: Colors.blue,
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
                Text('Modifier',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'toggle_status',
            child: Row(
              children: [
                Icon(
                  agent.isActive ? Icons.pause : Icons.play_arrow,
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
                  color: agent.isActive ? Colors.orange : Colors.green,
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
                Text(agent.isActive ? 'Désactiver' : 'Activer',
                  style: TextStyle(
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 12, tablet: 13, desktop: 14),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, 
                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 8, tablet: 15, desktop: 16),
                  color: Colors.red,
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 5, tablet: 7, desktop: 8)),
                Text('Suppr.', 
                  style: TextStyle(
                    color: Colors.red,
                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 8, tablet: 13, desktop: 14),
                  ),
                ),
              ],
            ),
          ),
        ],
        onSelected: (value) => _handleAgentAction(value, agent),
      ),
    );
  }

  void _handleAgentAction(String action, AgentModel agent) {
    switch (action) {
      case 'edit':
        _editAgent(agent);
        break;
      case 'toggle_status':
        _toggleAgentStatus(agent);
        break;
      case 'delete':
        _deleteAgent(agent);
        break;
    }
  }

  void _editAgent(AgentModel agent) {
    showDialog(
      context: context,
      builder: (context) => EditAgentDialog(agent: agent),
    ).then((result) {
      if (result == true) {
        // L'agent a été modifié avec succès, recharger les données
        _loadData();
      }
    });
  }

  Future<void> _toggleAgentStatus(AgentModel agent) async {
    final agentService = Provider.of<AgentService>(context, listen: false);
    final updatedAgent = agent.copyWith(isActive: !agent.isActive);
    
    final success = await agentService.updateAgent(updatedAgent);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agent ${updatedAgent.isActive ? "activé" : "désactivé"} avec succès',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteAgent(AgentModel agent) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer l\'agent "${agent.username}" ?\n\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Suppr.'),
          ),
        ],
      ),
    );

    if (confirmed == true && agent.id != null) {
      final agentService = Provider.of<AgentService>(context, listen: false);
      final success = await agentService.deleteAgent(agent.id!);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agent supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  void _showCreateAgentDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateAgentDialog(),
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
                const Text(
                  '🔐 Clé protégée: admin_default',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
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

  Future<void> _createTestAgents() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.science, color: Colors.cyan),
            SizedBox(width: 8),
            Text('Créer Agents de Test'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Voulez-vous créer 2 agents de test pour vérifier le système ?'),
            SizedBox(height: 16),
            Text('Agents qui seront créés:'),
            Text('• agent_test1 / test123'),
            Text('• agent_test2 / test123'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: const Text('Créer'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final agentService = Provider.of<AgentService>(context, listen: false);
      await agentService.createTestAgents();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Agents de test créés avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showDebugInfo() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.purple),
            SizedBox(width: 8),
            Text('Debug Info'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Informations de debug affichées dans la console...'),
            SizedBox(height: 16),
            Text('Ouvrez la console (F12) pour voir les détails.'),
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

    // Afficher les informations de debug
    await LocalDB.instance.debugListAllAgents();
    await LocalDB.instance.verifyMySQLCompatibility();
  }
}
