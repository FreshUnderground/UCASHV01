import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
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
          (agent.nom?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
              false);

      // Filtre par statut
      final matchesStatus = _statusFilter == 'all' ||
          (_statusFilter == 'active' && agent.isActive) ||
          (_statusFilter == 'inactive' && !agent.isActive);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(
                  l10n.agents,
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
                    label: Text(l10n.newAgent),
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
                Expanded(
                  child: Text(
                    l10n.agents,
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
                  label: Text(l10n.newAgent),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
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
    final l10n = AppLocalizations.of(context)!;
    if (isMobile) {
      return Column(
        children: [
          // Barre de recherche mobile
          TextField(
            decoration: InputDecoration(
              hintText: l10n.searchAgent,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            decoration: InputDecoration(
              labelText: l10n.filterByStatus,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(l10n.allAgents),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text(l10n.activeAgents),
              ),
              DropdownMenuItem(
                value: 'inactive',
                child: Text(l10n.inactiveAgents),
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
            decoration: InputDecoration(
              hintText: l10n.searchAgent,
              prefixIcon: const Icon(Icons.search, size: 18),
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            decoration: InputDecoration(
              labelText: l10n.status,
              border: const OutlineInputBorder(),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            items: [
              DropdownMenuItem(
                value: 'all',
                child: Text(l10n.all),
              ),
              DropdownMenuItem(
                value: 'active',
                child: Text(l10n.active),
              ),
              DropdownMenuItem(
                value: 'inactive',
                child: Text(l10n.inactive),
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
    final l10n = AppLocalizations.of(context)!;
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
                      ? l10n.noAgentsFound
                      : l10n.noAgentFound,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.clickNewAgentToCreate,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateAgentDialog,
                  icon: const Icon(Icons.person_add),
                  label: Text(l10n.createAnAgent),
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

        return LayoutBuilder(builder: (context, constraints) {
          return ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: constraints.maxWidth,
            ),
            child: DataTable(
              columnSpacing: 12,
              dataRowMinHeight: 56,
              dataRowMaxHeight: 56,
              headingRowHeight: 48,
              columns: [
                DataColumn(
                    label: Text(l10n.agent,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(
                    label: Text(l10n.shop,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(
                    label: Text(l10n.contact,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(
                    label: Text(l10n.status,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14))),
                DataColumn(
                    label: Text(l10n.actions,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14))),
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
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 12),
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: agent.isActive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.red.withOpacity(0.1),
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
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                          ),

                          // Activer/Désactiver
                          IconButton(
                            onPressed: () => _toggleAgentStatus(agent),
                            icon: Icon(
                              agent.isActive ? Icons.pause : Icons.play_arrow,
                              size: 14,
                            ),
                            tooltip: agent.isActive ? 'Désactiver' : 'Activer',
                            color:
                                agent.isActive ? Colors.orange : Colors.green,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                          ),

                          // Supprimer
                          IconButton(
                            onPressed: () => _deleteAgent(agent),
                            icon: const Icon(Icons.delete, size: 14),
                            tooltip: 'Supprimer',
                            color: Colors.red,
                            padding: const EdgeInsets.all(4),
                            constraints: const BoxConstraints(
                                minWidth: 24, minHeight: 24),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          );
        });
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
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Agent ${updatedAgent.isActive ? "activé" : "désactivé"} avec succès',
            ),
            backgroundColor: Colors.green,
          ),
        );
        _loadData(); // Reload data after successful update
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Erreur: ${agentService.errorMessage ?? "Impossible de modifier l\'agent"}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
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
            Text(
                'Êtes-vous sûr de vouloir supprimer l\'agent "${agent.username}" ?'),
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

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Agent supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadData(); // Reload data after successful deletion
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Erreur: ${agentService.errorMessage ?? "Impossible de supprimer l\'agent"}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Widget _buildMobileAgentsList(
      List<AgentModel> agents, ShopService shopService) {
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
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
                      const Icon(Icons.calendar_today,
                          size: 16, color: Colors.grey),
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
