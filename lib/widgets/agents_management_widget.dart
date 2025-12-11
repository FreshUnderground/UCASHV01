import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
                            l10n.agentsManagement,
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
    final l10n = AppLocalizations.of(context)!;
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
            tooltip: l10n.refresh,
            color: const Color(0xFFDC2626),
          ),
          
          // Bouton Vérifier Admin
          IconButton(
            onPressed: _verifyAdminExists,
            icon: Icon(Icons.admin_panel_settings,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: l10n.verifyAdmin,
            color: Colors.green,
          ),
          
          // Bouton Debug
          IconButton(
            onPressed: _showDebugInfo,
            icon: Icon(Icons.bug_report,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: l10n.debugInfo,
            color: Colors.purple,
          ),
          
          // Bouton Agents de Test
          IconButton(
            onPressed: _createTestAgents,
            icon: Icon(Icons.science,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
            ),
            tooltip: l10n.createTestAgents,
            color: Colors.cyan,
          ),
          
          // Bouton Nouveau Agent
          ElevatedButton.icon(
            onPressed: _showCreateAgentDialog,
            icon: Icon(Icons.person_add,
              size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
            label: Text(l10n.add,
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
          tooltip: l10n.refresh,
          color: const Color(0xFFDC2626),
        ),
        
        // Bouton Vérifier Admin
        IconButton(
          onPressed: _verifyAdminExists,
          icon: Icon(Icons.admin_panel_settings,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: l10n.verifyAdmin,
          color: Colors.green,
        ),
        
        // Bouton Debug
        IconButton(
          onPressed: _showDebugInfo,
          icon: Icon(Icons.bug_report,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: l10n.debugInfo,
          color: Colors.purple,
        ),
        
        // Bouton Agents de Test
        IconButton(
          onPressed: _createTestAgents,
          icon: Icon(Icons.science,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 20, tablet: 22, desktop: 24),
          ),
          tooltip: l10n.createTestAgents,
          color: Colors.cyan,
        ),
        
        SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
        
        // Bouton Nouveau Agent
        ElevatedButton.icon(
          onPressed: _showCreateAgentDialog,
          icon: Icon(Icons.person_add,
            size: ResponsiveUtils.getFluidIconSize(context, mobile: 14, tablet: 15, desktop: 16),
          ),
          label: Text(l10n.newAgent,
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
    final l10n = AppLocalizations.of(context)!;
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
                        l10n.totalAgents,
                        '${agents.length}',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                    SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                    Expanded(
                      child: _buildStatCard(
                        l10n.activeAgents,
                        '$activeAgents',
                        Icons.check_circle,
                        Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                _buildStatCard(
                  l10n.inactiveAgents,
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
                l10n.totalAgents,
                '${agents.length}',
                Icons.people,
                Colors.blue,
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              _buildStatCard(
                l10n.activeAgents,
                '$activeAgents',
                Icons.check_circle,
                Colors.green,
              ),
              SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              _buildStatCard(
                l10n.inactiveAgents,
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
    final l10n = AppLocalizations.of(context)!;
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        if (agentService.isLoading) {
          return Padding(
            padding: const EdgeInsets.all(40),
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
                  '${l10n.error}: ${agentService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadData,
                  child: Text(l10n.retry),
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
                Text(
                  l10n.noAgentsFound,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.createFirstAgent,
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateAgentDialog,
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.newAgent),
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
                    designation: l10n.notSpecified,
                    localisation: l10n.notSpecified,
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
    final l10n = AppLocalizations.of(context)!;
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
              agent.isActive ? "✓ ${l10n.active}" : "✗ ${l10n.inactive}",
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
                Text(l10n.edit,
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
                Text(agent.isActive ? l10n.deactivate : l10n.activate,
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
                Text(l10n.delete, 
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
    final l10n = AppLocalizations.of(context)!;
    final agentService = Provider.of<AgentService>(context, listen: false);
    final updatedAgent = agent.copyWith(isActive: !agent.isActive);
    
    final success = await agentService.updateAgent(updatedAgent);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              updatedAgent.isActive ? l10n.agentActivated : l10n.agentDeactivated,
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.error}: ${agentService.errorMessage ?? l10n.errorUpdatingAgent}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteAgent(AgentModel agent) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmDelete),
        content: Text(
          '${l10n.confirmDeleteAgent}\n\n'
          '${l10n.thisActionCannotBeUndone}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed == true && agent.id != null) {
      final agentService = Provider.of<AgentService>(context, listen: false);
      final success = await agentService.deleteAgent(agent.id!);
      
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.agentDeletedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Reload data after successful deletion
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${l10n.error}: ${agentService.errorMessage ?? l10n.errorDeletingAgent}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
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
    final l10n = AppLocalizations.of(context)!;
    await LocalDB.instance.ensureAdminExists();
    final admin = await LocalDB.instance.getDefaultAdmin();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.green),
              const SizedBox(width: 8),
              Text(l10n.verifyAdmin),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (admin != null) ...[
                const Icon(Icons.check_circle, color: Colors.green, size: 48),
                const SizedBox(height: 16),
                Text(l10n.adminExists),
                const SizedBox(height: 8),
                Text('${l10n.username}: ${admin.username}'),
                Text('${l10n.role}: ${admin.role}'),
                Text('ID: ${admin.id}'),
                const SizedBox(height: 8),
                const Text(
                  '🔐 Clé protégée: admin_default',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ] else ...[
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(l10n.adminNotFound),
                const SizedBox(height: 8),
                Text(l10n.adminWillBeRecreated),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.close),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _createTestAgents() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.science, color: Colors.cyan),
            const SizedBox(width: 8),
            Text(l10n.createTestAgents),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.createTestAgentsConfirm),
            const SizedBox(height: 16),
            Text(l10n.agentsToBeCreated),
            Text('• agent_test1 / test123'),
            Text('• agent_test2 / test123'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
            child: Text(l10n.save),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final agentService = Provider.of<AgentService>(context, listen: false);
      await agentService.createTestAgents();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.testAgentsCreatedSuccess),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _showDebugInfo() async {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bug_report, color: Colors.purple),
            const SizedBox(width: 8),
            Text(l10n.debugInfo),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l10n.debugInfoInConsole),
            const SizedBox(height: 16),
            Text(l10n.openConsoleF12),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );

    // Afficher les informations de debug
    await LocalDB.instance.debugListAllAgents();
    await LocalDB.instance.verifyMySQLCompatibility();
  }
}
