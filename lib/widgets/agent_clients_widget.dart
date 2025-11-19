import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/client_service.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../models/client_model.dart';
import '../models/operation_model.dart';
import '../widgets/simple_transfer_dialog.dart';
import 'edit_client_dialog.dart';

class AgentClientsWidget extends StatefulWidget {
  const AgentClientsWidget({super.key});

  @override
  State<AgentClientsWidget> createState() => _AgentClientsWidgetState();
}

class _AgentClientsWidgetState extends State<AgentClientsWidget> {
  String _searchQuery = '';
  bool _showActiveOnly = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClients();
    });
  }

  void _loadClients() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.shopId != null) {
      // Charger TOUS les clients (globaux - accessible depuis tous les shops)
      Provider.of<ClientService>(context, listen: false).loadClients();
    }
  }

  List<ClientModel> _filterClients(List<ClientModel> clients) {
    return clients.where((client) {
      final matchesSearch = _searchQuery.isEmpty ||
          client.nom.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          client.telephone.contains(_searchQuery);
      
      final matchesStatus = !_showActiveOnly || client.isActive;
      
      return matchesSearch && matchesStatus;
    }).toList();
  }
  
  /// Calculer le solde réel d'un client à partir de ses opérations
  Map<String, double> _calculateClientRealBalance(int clientId, OperationService operationService) {
    // Filtrer les opérations du client
    final clientOperations = operationService.operations.where((op) => op.clientId == clientId).toList();
    
    double soldeUSD = 0.0;
    double soldeCDF = 0.0;
    double soldeUGX = 0.0;
    
    for (final op in clientOperations) {
      // Dépôts: augmentent le solde
      // Retraits: diminuent le solde
      final montant = op.montantNet;
      final devise = op.devise;
      
      if (op.type == OperationType.depot) {
        // Dépôt augmente le solde
        if (devise == 'USD') soldeUSD += montant;
        else if (devise == 'CDF') soldeCDF += montant;
        else if (devise == 'UGX') soldeUGX += montant;
      } else if (op.type == OperationType.retrait) {
        // Retrait diminue le solde
        if (devise == 'USD') soldeUSD -= montant;
        else if (devise == 'CDF') soldeCDF -= montant;
        else if (devise == 'UGX') soldeUGX -= montant;
      }
    }
    
    return {
      'USD': soldeUSD,
      'CDF': soldeCDF,
      'UGX': soldeUGX,
    };
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final padding = isMobile ? 16.0 : (size.width <= 1024 ? 20.0 : 24.0);
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec recherche et filtres
          _buildHeader(),
          const SizedBox(height: 16),
          
          // Statistiques
          _buildStats(),
          const SizedBox(height: 16),
          
          // Liste des clients - Expanded pour remplir tout l'espace disponible et permettre le scroll
          Expanded(
            child: _buildClientsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Titre et bouton - Responsive
            if (isMobile)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mes Clients',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showCreateClientDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Nouveau Partenaire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Mes Clients',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateClientDialog,
                    icon: const Icon(Icons.person_add, size: 18),
                    label: const Text('Nouveau Partenaire'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            
            // Barre de recherche et filtres
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Rechercher par nom ou téléphone...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 16),
                
                // Filtre actifs seulement
                Row(
                  children: [
                    Checkbox(
                      value: _showActiveOnly,
                      onChanged: (value) {
                        setState(() {
                          _showActiveOnly = value ?? false;
                        });
                      },
                    ),
                    const Text('Actifs seulement'),
                  ],
                ),
                
                const SizedBox(width: 16),
                
                // Bouton actualiser
                IconButton(
                  onPressed: _loadClients,
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Actualiser',
                  color: const Color(0xFFDC2626),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Consumer<ClientService>(
      builder: (context, clientService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        
        if (currentUser?.shopId == null) {
          return const SizedBox.shrink();
        }
        
        final stats = clientService.getClientsStats(currentUser!.shopId!);
        
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildStatCard(
                  'Total Clients',
                  '${stats['totalClients']}',
                  Icons.people,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Clients Actifs',
                  '${stats['activeClients']}',
                  Icons.check_circle,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Avec Comptes',
                  '${stats['withAccounts']}',
                  Icons.account_circle,
                  Colors.orange,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
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

  Widget _buildClientsList() {
    return Consumer<ClientService>(
      builder: (context, clientService, child) {
        if (clientService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (clientService.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${clientService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadClients,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final filteredClients = _filterClients(clientService.clients);

        if (filteredClients.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.people_outline, color: Colors.grey, size: 64),
                const SizedBox(height: 16),
                Text(
                  clientService.clients.isEmpty 
                      ? 'Aucun client enregistré'
                      : 'Aucun client trouvé avec ces critères',
                  style: const TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cliquez sur "Nouveau Client" pour ajouter un client',
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _showCreateClientDialog,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Nouveau Partenaire'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Card(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredClients.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final client = filteredClients[index];
              return _buildClientItem(client);
            },
          ),
        );
      },
    );
  }

  Widget _buildClientItem(ClientModel client) {
    // Calculer le solde réel à partir des opérations
    final operationService = Provider.of<OperationService>(context, listen: false);
    final realBalance = _calculateClientRealBalance(client.id!, operationService);
    
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: client.isActive 
            ? Colors.green.withOpacity(0.2)
            : Colors.grey.withOpacity(0.2),
        child: Icon(
          Icons.person,
          color: client.isActive ? Colors.green : Colors.grey,
        ),
      ),
      title: Text(
        client.nom,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 4),
          // N° de Compte en premier
          Row(
            children: [
              const Icon(Icons.credit_card, size: 14, color: Color(0xFFDC2626)),
              const SizedBox(width: 6),
              Text(
                'N° ${client.id?.toString().padLeft(6, '0') ?? 'N/A'}',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFDC2626),
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.phone, size: 14, color: Colors.grey),
              const SizedBox(width: 6),
              Text('Tél: ${client.telephone}'),
            ],
          ),
          if (client.adresse != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.location_on, size: 14, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(child: Text('${client.adresse}', maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            ),
          ],
          const SizedBox(height: 4),
          // Solde USD
          Row(
            children: [
              const Icon(Icons.account_balance_wallet, size: 14, color: Colors.green),
              const SizedBox(width: 6),
              Text(
                'Solde: ${realBalance['USD']!.toStringAsFixed(2)} \$',
                style: TextStyle(
                  color: realBalance['USD']! >= 0 ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              // Solde CDF si disponible
              if (realBalance['CDF']! > 0) ...[
                const SizedBox(width: 8),
                const Text('•', style: TextStyle(color: Colors.grey)),
                const SizedBox(width: 8),
                Text(
                  '${realBalance['CDF']!.toStringAsFixed(0)} FC',
                  style: TextStyle(
                    color: realBalance['CDF']! >= 0 ? Colors.green.withOpacity(0.8) : Colors.red.withOpacity(0.8),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
          if (client.username != null) ...[
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.account_circle, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'Compte: ${client.username}',
                  style: const TextStyle(color: Colors.blue, fontSize: 13),
                ),
              ],
            ),
          ],
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: client.isActive ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              client.isActive ? '✓ Actif' : '⚠ Inactif',
              style: TextStyle(
                color: client.isActive ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
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
          const PopupMenuItem(
            value: 'statement',
            child: Row(
              children: [
                Icon(Icons.receipt_long, size: 16, color: Colors.purple),
                SizedBox(width: 8),
                Text('Voir le relevé'),
              ],
            ),
          ),
          const PopupMenuItem(
            value: 'transfer',
            child: Row(
              children: [
                Icon(Icons.send, size: 16, color: Colors.green),
                SizedBox(width: 8),
                Text('Nouveau Transfert'),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'toggle_status',
            child: Row(
              children: [
                Icon(
                  client.isActive ? Icons.pause : Icons.play_arrow,
                  size: 16,
                  color: client.isActive ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 8),
                Text(client.isActive ? 'Désactiver' : 'Activer'),
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
        onSelected: (value) => _handleClientAction(value, client),
      ),
    
    
    );
  }

  void _handleClientAction(String action, ClientModel client) {
    switch (action) {
      case 'edit':
        _editClient(client);
        break;
      case 'statement':
        _showClientStatement(client);
        break;
      case 'transfer':
        _createTransferForClient(client);
        break;
      case 'toggle_status':
        _toggleClientStatus(client);
        break;
      case 'delete':
        _deleteClient(client);
        break;
    }
  }

  void _showCreateClientDialog() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser?.shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur: Shop non défini'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CreateClientDialog(
        shopId: currentUser!.shopId!,
        agentId: currentUser.id!,
      ),
    ).then((result) {
      if (result == true) {
        _loadClients();
      }
    });
  }

  void _editClient(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => EditClientDialog(client: client),
    ).then((result) {
      if (result == true) {
        _loadClients();
      }
    });
  }

  void _createTransferForClient(ClientModel client) {
    showDialog(
      context: context,
      builder: (context) => const SimpleTransferDialog(),
    ).then((result) {
      if (result == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transfert créé pour ${client.nom}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showClientStatement(ClientModel client) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Row(
              children: [
                const Icon(Icons.receipt_long, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Relevé de ${client.nom}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.purple,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: _ClientStatementView(client: client),
        ),
      ),
    );
  }

  Future<void> _toggleClientStatus(ClientModel client) async {
    final clientService = Provider.of<ClientService>(context, listen: false);
    final updatedClient = client.copyWith(isActive: !client.isActive);
    
    final success = await clientService.updateClient(updatedClient);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Client ${updatedClient.isActive ? "activé" : "désactivé"} avec succès',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteClient(ClientModel client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le client "${client.nom}" ?\n\n'
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

    if (confirmed == true && client.id != null) {
      final clientService = Provider.of<ClientService>(context, listen: false);
      final success = await clientService.deleteClient(client.id!, client.shopId);
      
      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partenaire supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }
}

// Dialog de création de client
class _CreateClientDialog extends StatefulWidget {
  final int shopId;
  final int agentId;

  const _CreateClientDialog({
    required this.shopId,
    required this.agentId,
  });

  @override
  State<_CreateClientDialog> createState() => _CreateClientDialogState();
}

class _CreateClientDialogState extends State<_CreateClientDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _adresseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _createAccount = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 500,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_add, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Nouveau Client',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Nom
                      TextFormField(
                        controller: _nomController,
                        decoration: const InputDecoration(
                          labelText: 'Nom complet *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Téléphone
                      TextFormField(
                        controller: _telephoneController,
                        decoration: const InputDecoration(
                          labelText: 'Téléphone *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.phone),
                        ),
                        keyboardType: TextInputType.phone,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le téléphone est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      
                      // Adresse
                      TextFormField(
                        controller: _adresseController,
                        decoration: const InputDecoration(
                          labelText: 'Adresse (optionnel)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.location_on),
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 16),
                      
                      // Créer un compte
                      CheckboxListTile(
                        title: const Text('Créer un compte utilisateur'),
                        subtitle: const Text('Permettre au partenaire de se connecter'),
                        value: _createAccount,
                        onChanged: (value) {
                          setState(() {
                            _createAccount = value ?? false;
                          });
                        },
                      ),
                      
                      if (_createAccount) ...[
                        const SizedBox(height: 16),
                        
                        // Username
                        TextFormField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Nom d\'utilisateur *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.account_circle),
                          ),
                          validator: _createAccount ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le nom d\'utilisateur est requis';
                            }
                            return null;
                          } : null,
                        ),
                        const SizedBox(height: 16),
                        
                        // Password
                        TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Mot de passe *',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                          validator: _createAccount ? (value) {
                            if (value == null || value.isEmpty) {
                              return 'Le mot de passe est requis';
                            }
                            if (value.length < 6) {
                              return 'Le mot de passe doit contenir au moins 6 caractères';
                            }
                            return null;
                          } : null,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Créer'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final clientService = Provider.of<ClientService>(context, listen: false);
      
      final success = await clientService.createClient(
        nom: _nomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
        username: _createAccount ? _usernameController.text.trim() : null,
        password: _createAccount ? _passwordController.text : null,
        shopId: widget.shopId,
        agentId: widget.agentId,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Partenaire créé avec succès !'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${clientService.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Widget pour afficher le relevé d'un client spécifique
class _ClientStatementView extends StatelessWidget {
  final ClientModel client;

  const _ClientStatementView({required this.client});

  @override
  Widget build(BuildContext context) {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        // Filtrer les opérations du client
        final clientOperations = operationService.operations
            .where((op) => op.clientId == client.id)
            .toList()
          ..sort((a, b) => b.dateOp.compareTo(a.dateOp));

        if (operationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (clientOperations.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.receipt_long_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Aucune transaction pour ${client.nom}',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            // Informations client
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.purple[50],
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.purple,
                    child: Text(
                      client.nom.substring(0, 1).toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          client.nom,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          client.telephone,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Total transactions',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '${clientOperations.length}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Liste des transactions
            Expanded(
              child: ListView.builder(
                itemCount: clientOperations.length,
                itemBuilder: (context, index) {
                  final operation = clientOperations[index];
                  return _buildOperationTile(operation);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationTile(OperationModel operation) {
    IconData icon;
    Color iconColor;
    String typeLabel;

    switch (operation.type) {
      case OperationType.depot:
        icon = Icons.arrow_downward;
        iconColor = Colors.green;
        typeLabel = 'Dépôt';
        break;
      case OperationType.retrait:
        icon = Icons.arrow_upward;
        iconColor = Colors.orange;
        typeLabel = 'Retrait';
        break;
      case OperationType.transfertNational:
        icon = Icons.send;
        iconColor = Colors.blue;
        typeLabel = 'Transfert National';
        break;
      case OperationType.transfertInternationalSortant:
        icon = Icons.flight_takeoff;
        iconColor = Colors.purple;
        typeLabel = 'Transfert International';
        break;
      case OperationType.transfertInternationalEntrant:
        icon = Icons.flight_land;
        iconColor = Colors.teal;
        typeLabel = 'Réception International';
        break;
      default:
        icon = Icons.swap_horiz;
        iconColor = Colors.grey;
        typeLabel = operation.type.name;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.1),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          typeLabel,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _formatDate(operation.dateOp),
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            if (operation.destinataire != null)
              Text(
                operation.destinataire!,
                style: const TextStyle(fontSize: 12),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${operation.montantNet.toStringAsFixed(2)} ${operation.devise}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: operation.type == OperationType.depot
                    ? Colors.green
                    : Colors.orange,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getStatusColor(operation.statut).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _getStatusLabel(operation.statut),
                style: TextStyle(
                  fontSize: 10,
                  color: _getStatusColor(operation.statut),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  Color _getStatusColor(OperationStatus statut) {
    switch (statut) {
      case OperationStatus.enAttente:
        return Colors.orange;
      case OperationStatus.validee:
        return Colors.blue;
      case OperationStatus.terminee:
        return Colors.green;
      case OperationStatus.annulee:
        return Colors.red;
    }
  }

  String _getStatusLabel(OperationStatus statut) {
    switch (statut) {
      case OperationStatus.enAttente:
        return 'En attente';
      case OperationStatus.validee:
        return 'Validée';
      case OperationStatus.terminee:
        return 'Terminée';
      case OperationStatus.annulee:
        return 'Annulée';
    }
  }
}