import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';
import 'create_agent_dialog.dart';
import 'edit_agent_dialog.dart';

class AgentsTableWidget extends StatefulWidget {
  const AgentsTableWidget({super.key});

  @override
  State<AgentsTableWidget> createState() => _AgentsTableWidgetState();
}

class _AgentsTableWidgetState extends State<AgentsTableWidget> {
  String _searchQuery = '';
  String _statusFilter = 'all'; // all, active, inactive

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

  List<AgentModel> _filterAgents(List<AgentModel> agents) {
    return agents.where((agent) {
      // Filtre par recherche
      final matchesSearch = _searchQuery.isEmpty ||
          agent.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (agent.nom?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);

      // Filtre par statut
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && agent.isActive) ||
          (_statusFilter == 'inactive' && !agent.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Card(
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header avec filtres et actions responsive
          _buildResponsiveHeader(isMobile),
          const Divider(height: 1),
          
          // Tableau des agents
          _buildAgentsTable(isMobile),
        ],
      ),
    );
  }

  Widget _buildResponsiveHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titre et bouton nouveau responsive
          if (isMobile) ...[
            // Layout mobile vertical
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Liste des Agents',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC2626),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showCreateAgentDialog,
                    icon: const Icon(Icons.person_add, size: 16),
                    label: const Text('Nouvel Agent'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Layout desktop horizontal
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Liste des Agents',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showCreateAgentDialog,
                  icon: const Icon(Icons.person_add, size: 18),
                  label: const Text('Nouvel Agent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
          SizedBox(height: isMobile ? 12 : 16),
          
          // Filtres responsive
          _buildResponsiveFilters(isMobile),
        ],
      ),
    );
  }

  Widget _buildResponsiveFilters(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          // Barre de recherche mobile
          TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher un agent...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 8),
          // Filtre statut mobile
          DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Filtrer par statut',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Tous les agents'),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text('Agents actifs'),
              ),
              DropdownMenuItem(
                value: 'inactive',
                child: Text('Agents inactifs'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value!;
              });
            },
          ),
        ],
      );
    }

    return Row(
      children: [
        // Barre de recherche desktop
        Expanded(
          flex: 2,
          child: TextField(
            decoration: const InputDecoration(
              hintText: 'Rechercher un agent...',
              prefixIcon: Icon(Icons.search, size: 18),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        const SizedBox(width: 12),
        // Filtre statut desktop
        Expanded(
          flex: 1,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Statut',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: const [
              DropdownMenuItem(
                value: 'all',
                child: Text('Tous'),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text('Actifs'),
              ),
              DropdownMenuItem(
                value: 'inactive',
                child: Text('Inactifs'),
              ),
            ],
            onChanged: (value) {
              setState(() {
                _statusFilter = value!;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAgentsTable(bool isMobile) {
    return Consumer2<AgentService, ShopService>(
      builder: (context, agentService, shopService, child) {
        if (agentService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (agentService.errorMessage != null) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
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

        final filteredAgents = _filterAgents(agentService.agents);

        if (filteredAgents.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                Text(
                  agentService.agents.isEmpty 
                      ? 'Aucun agent créé'
                      : 'Aucun agent trouvé avec ces critères',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cliquez sur "Nouvel Agent" pour créer un agent',
                  style: TextStyle(color: Colors.grey),
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

        if (isMobile) {
          return _buildMobileAgentsList(filteredAgents, shopService);
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            return ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: constraints.maxWidth,
              ),
              child: DataTable(
                  columnSpacing: 12,
                  dataRowMinHeight: 56,
                  dataRowMaxHeight: 56,
                  headingRowHeight: 48,
                  columns: const [
                    DataColumn(label: Text('Agent', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    DataColumn(label: Text('Shop', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    DataColumn(label: Text('Contact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    DataColumn(label: Text('Statut', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    DataColumn(label: Text('Créé le', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  ],
                  rows: filteredAgents.map((agent) {
                    final shop = shopService.shops.firstWhere(
                      (s) => s.id == agent.shopId,
                      orElse: () => ShopModel(
                        id: 0,
                        designation: 'Shop Inconnu',
                        localisation: 'Localisation inconnue',
                        capitalInitial: 0,
                      ),
                    );

                    return DataRow(
                      cells: [
                        // Agent
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                agent.username,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (agent.nom != null)
                                Text(
                                  agent.nom!,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        
                        // Shop
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                shop.designation,
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                shop.localisation ?? 'Localisation inconnue',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[600],
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        
                        // Contact
                        DataCell(
                          Text(
                            agent.telephone ?? 'Non renseigné',
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Statut
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: agent.isActive ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: agent.isActive ? Colors.green : Colors.red,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              agent.isActive ? 'Actif' : 'Inactif',
                              style: TextStyle(
                                color: agent.isActive ? Colors.green : Colors.red,
                                fontWeight: FontWeight.w500,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ),
                        
                        // Date de création
                        DataCell(
                          Text(
                            agent.createdAt != null
                                ? '${agent.createdAt!.day}/${agent.createdAt!.month}/${agent.createdAt!.year}'
                                : 'Non renseigné',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
                        // Actions
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Modifier
                              IconButton(
                                onPressed: () => _editAgent(agent),
                                icon: const Icon(Icons.edit, size: 14),
                                tooltip: 'Modifier',
                                color: Colors.blue,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                              
                              // Activer/Désactiver
                              IconButton(
                                onPressed: () => _toggleAgentStatus(agent),
                                icon: Icon(
                                  agent.isActive ? Icons.pause : Icons.play_arrow,
                                  size: 14,
                                ),
                                tooltip: agent.isActive ? 'Désactiver' : 'Activer',
                                color: agent.isActive ? Colors.orange : Colors.green,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                              
                              // Supprimer
                              IconButton(
                                onPressed: () => _deleteAgent(agent),
                                icon: const Icon(Icons.delete, size: 14),
                                tooltip: 'Supprimer',
                                color: Colors.red,
                                padding: const EdgeInsets.all(4),
                                constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              );
          }
        );
      },
    );
  }

  void _showCreateAgentDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateAgentDialog(),
    ).then((result) {
      if (result == true) {
        _loadData();
      }
    });
  }

  void _editAgent(AgentModel agent) {
    showDialog(
      context: context,
      builder: (context) => EditAgentDialog(agent: agent),
    ).then((result) {
      if (result == true) {
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Êtes-vous sûr de vouloir supprimer l\'agent "${agent.username}" ?'),
            const SizedBox(height: 8),
            if (agent.nom != null) Text('Nom: ${agent.nom}'),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
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

    if (confirmed == true && agent.id != null && mounted) {
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

  Widget _buildMobileAgentsList(List<AgentModel> agents, ShopService shopService) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(agents.length, (index) {
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

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header avec nom et statut
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            agent.username,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (agent.nom != null)
                            Text(
                              agent.nom!,
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: agent.isActive ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        agent.isActive ? 'Actif' : 'Inactif',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // Informations du shop
                Row(
                  children: [
                    const Icon(Icons.store, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${shop.designation} (${shop.localisation ?? 'Localisation inconnue'})',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                
                // Date de création
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      'Créé le ${agent.createdAt?.day ?? 1}/${agent.createdAt?.month ?? 1}/${agent.createdAt?.year ?? DateTime.now().year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                
                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showEditAgentDialog(agent),
                        icon: const Icon(Icons.edit, size: 16),
                        label: const Text('Modifier'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue,
                          side: const BorderSide(color: Colors.blue),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _deleteAgent(agent),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Suppr.'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }),
      ),
    );
  }

  void _showEditAgentDialog(AgentModel agent) {
    showDialog(
      context: context,
      builder: (context) => EditAgentDialog(agent: agent),
    ).then((_) {
      _loadData(); // Recharger les données après modification
    });
  }
}
