import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';
import 'create_agent_dialog.dart';
import 'edit_agent_dialog.dart';

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
    return Card(
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec boutons d'action
          Container(
            padding: const EdgeInsets.all(20),
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
                const Text(
                  'Gestion des Agents',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
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
          _buildAgentsList(),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        // Bouton Actualiser
        IconButton(
          onPressed: _loadData,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualiser',
          color: const Color(0xFFDC2626),
        ),
        
        // Bouton Vérifier Admin
        IconButton(
          onPressed: _verifyAdminExists,
          icon: const Icon(Icons.admin_panel_settings),
          tooltip: 'Vérifier Admin',
          color: Colors.green,
        ),
        
        // Bouton Debug
        IconButton(
          onPressed: _showDebugInfo,
          icon: const Icon(Icons.bug_report),
          tooltip: 'Debug Info',
          color: Colors.purple,
        ),
        
        // Bouton Agents de Test
        IconButton(
          onPressed: _createTestAgents,
          icon: const Icon(Icons.science),
          tooltip: 'Créer Agents de Test',
          color: Colors.cyan,
        ),
        
        const SizedBox(width: 8),
        
        // Bouton Nouveau Agent
        ElevatedButton.icon(
          onPressed: _showCreateAgentDialog,
          icon: const Icon(Icons.person_add, size: 16),
          label: const Text('Nouveau Agent'),
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
    );
  }

  Widget _buildAgentStats() {
    return Consumer<AgentService>(
      builder: (context, agentService, child) {
        final agents = agentService.agents;
        final activeAgents = agents.where((a) => a.isActive).length;
        
        return Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              _buildStatCard(
                'Total Agents',
                '${agents.length}',
                Icons.people,
                Colors.blue,
              ),
              const SizedBox(width: 16),
              _buildStatCard(
                'Agents Actifs',
                '$activeAgents',
                Icons.check_circle,
                Colors.green,
              ),
              const SizedBox(width: 16),
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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

        return Container(
          constraints: const BoxConstraints(maxHeight: 400),
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: agents.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final agent = agents[index];
              final shop = shopService.shops.firstWhere(
                (s) => s.id == agent.shopId,
                orElse: () => ShopModel(
                  id: 0,
                  designation: 'Shop Inconnu',
                  localisation: 'Localisation inconnue',
                  capitalInitial: 0,
                ),
              );
              
              return _buildAgentItem(agent, shop);
            },
          ),
        );
      },
    );
  }

  Widget _buildAgentItem(AgentModel agent, ShopModel shop) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: agent.isActive 
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        child: Icon(
          Icons.person,
          color: agent.isActive ? Colors.green : Colors.grey,
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
          Text('Shop: ${shop.designation}'),
          if (agent.telephone != null) Text('Tél: ${agent.telephone}'),
          Text(
            'Statut: ${agent.isActive ? "Actif" : "Inactif"}',
            style: TextStyle(
              color: agent.isActive ? Colors.green : Colors.orange,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: PopupMenuButton<String>(
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
          PopupMenuItem(
            value: 'toggle_status',
            child: Row(
              children: [
                Icon(
                  agent.isActive ? Icons.pause : Icons.play_arrow,
                  size: 16,
                  color: agent.isActive ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(agent.isActive ? 'Désactiver' : 'Activer'),
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
            child: const Text('Supprimer'),
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
