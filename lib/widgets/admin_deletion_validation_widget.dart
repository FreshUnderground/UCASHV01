import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/deletion_request_model.dart';
import '../services/deletion_service.dart';
import '../services/auth_service.dart';

/// Widget Admin: Valider les demandes de suppression (inter-admin)
/// Supporte les opérations ET les transactions virtuelles avec filtres
class AdminDeletionValidationWidget extends StatefulWidget {
  const AdminDeletionValidationWidget({Key? key}) : super(key: key);

  @override
  State<AdminDeletionValidationWidget> createState() => _AdminDeletionValidationWidgetState();
}

class _AdminDeletionValidationWidgetState extends State<AdminDeletionValidationWidget> {
  DeletionType _selectedFilter = DeletionType.all;
  
  // Filtres avancés
  final TextEditingController _montantMinController = TextEditingController();
  final TextEditingController _montantMaxController = TextEditingController();
  final TextEditingController _destinataireController = TextEditingController();
  final TextEditingController _expediteurController = TextEditingController();
  final TextEditingController _shopController = TextEditingController();
  bool _showAdvancedFilters = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<DeletionService>(
      builder: (context, service, _) {
        final allRequests = service.getAllAdminPendingRequests(type: _selectedFilter);
        final operationsCount = service.adminPendingRequests.length;
        final virtualCount = service.adminPendingVirtualRequests.length;

        return Scaffold(
          appBar: AppBar(
            title: Text('Validations Admin (${allRequests.length})'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () => service.syncAll(),
              ),
            ],
          ),
          body: Column(
            children: [
              // Filtres par type
              Container(
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text('Type: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Expanded(
                          child: SegmentedButton<DeletionType>(
                            segments: [
                              ButtonSegment(
                                value: DeletionType.all,
                                label: Text('Tout (${_getFilteredRequests(allRequests).length})'),
                              ),
                              ButtonSegment(
                                value: DeletionType.operations,
                                label: Text('Opérations ($operationsCount)'),
                              ),
                              ButtonSegment(
                                value: DeletionType.virtualTransactions,
                                label: Text('Virtuelles ($virtualCount)'),
                              ),
                            ],
                            selected: {_selectedFilter},
                            onSelectionChanged: (Set<DeletionType> selection) {
                              setState(() {
                                _selectedFilter = selection.first;
                              });
                            },
                          ),
                        ),
                        IconButton(
                          icon: Icon(_showAdvancedFilters ? Icons.expand_less : Icons.expand_more),
                          onPressed: () {
                            setState(() {
                              _showAdvancedFilters = !_showAdvancedFilters;
                            });
                          },
                          tooltip: 'Filtres avancés',
                        ),
                      ],
                    ),
                    // Filtres avancés
                    if (_showAdvancedFilters) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Filtres avancés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            // Filtre par montant
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _montantMinController,
                                    decoration: InputDecoration(
                                      labelText: 'Montant min',
                                      hintText: '0',
                                      prefixIcon: Icon(Icons.attach_money),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _montantMaxController,
                                    decoration: InputDecoration(
                                      labelText: 'Montant max',
                                      hintText: '∞',
                                      prefixIcon: Icon(Icons.attach_money),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    keyboardType: TextInputType.number,
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Filtre par destinataire et expéditeur
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _destinataireController,
                                    decoration: InputDecoration(
                                      labelText: 'Destinataire',
                                      hintText: 'Nom du destinataire',
                                      prefixIcon: Icon(Icons.person_outline),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _expediteurController,
                                    decoration: InputDecoration(
                                      labelText: 'Expéditeur',
                                      hintText: 'Nom de l\'expéditeur',
                                      prefixIcon: Icon(Icons.person),
                                      border: OutlineInputBorder(),
                                      isDense: true,
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Filtre par shop
                            TextField(
                              controller: _shopController,
                              decoration: InputDecoration(
                                labelText: 'Shop',
                                hintText: 'Nom du shop',
                                prefixIcon: Icon(Icons.store),
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            const SizedBox(height: 12),
                            // Boutons d'action
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: _clearFilters,
                                  child: Text('Effacer'),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () => setState(() {}),
                                  child: Text('Appliquer'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: Builder(
                  builder: (context) {
                    final filteredRequests = _getFilteredRequests(allRequests);
                    return filteredRequests.isEmpty
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle, size: 64, color: Colors.green),
                                SizedBox(height: 16),
                                Text(
                                  'Aucune demande en attente de validation',
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Les demandes de suppression apparaîtront ici\nune fois créées par les administrateurs.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey, fontSize: 12),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: filteredRequests.length,
                            itemBuilder: (context, index) {
                              final request = filteredRequests[index];
                              return _buildRequestCard(context, request);
                            },
                          );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestCard(BuildContext context, dynamic request) {
    // Gérer les deux types: DeletionRequestModel et VirtualTransactionDeletionRequestModel
    final bool isVirtualTransaction = request.runtimeType.toString().contains('VirtualTransaction');
    
    final String identifier = isVirtualTransaction ? request.reference : request.codeOps;
    final String type = isVirtualTransaction ? request.transactionType : request.operationType;
    final double amount = request.montant;
    final String currency = request.devise;
    final String requestedBy = request.requestedByAdminName;
    final DateTime requestDate = request.requestDate;
    final String? destinataire = isVirtualTransaction ? request.destinataire : request.destinataire;
    final String? expediteur = isVirtualTransaction ? request.expediteur : request.expediteur;
    final String? clientNom = request.clientNom;
    final String? reason = request.reason;
    
    return Card(
      margin: const EdgeInsets.all(8),
      child: ExpansionTile(
        leading: Icon(
          isVirtualTransaction ? Icons.account_balance_wallet : Icons.swap_horiz, 
          color: isVirtualTransaction ? Colors.purple : Colors.orange
        ),
        title: Text(
          '${isVirtualTransaction ? "VT" : "OP"} - $type - ${amount.toStringAsFixed(2)} $currency',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Demandé par: $requestedBy'),
            Text('Date: ${_formatDate(requestDate)}'),
            if (destinataire != null)
              Text('Destinataire: $destinataire'),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow(
                  isVirtualTransaction ? 'Référence' : 'Code opération', 
                  identifier
                ),
                if (expediteur != null)
                  _buildDetailRow('Expéditeur', expediteur!)
                else
                  _buildDetailRow('Expéditeur', 'Non spécifié'),
                if (clientNom != null)
                  _buildDetailRow('Client', clientNom!),
                if (reason != null) ...[
                  const SizedBox(height: 8),
                  const Text('Raison:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(reason!),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _validateRequest(context, request, false),
                      icon: const Icon(Icons.close),
                      label: const Text('Refuser'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _validateRequest(context, request, true),
                      icon: const Icon(Icons.check),
                      label: const Text('Valider'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _validateRequest(BuildContext context, dynamic request, bool approve) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(approve ? 'Valider la suppression' : 'Refuser la suppression'),
        content: Text(
          approve
              ? 'Confirmer la validation de cette demande de suppression ?\nElle sera ensuite envoyée à l\'agent pour traitement final.'
              : 'Refuser cette demande de suppression ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final authService = Provider.of<AuthService>(context, listen: false);
              final admin = authService.currentUser;
              
              if (admin == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin non connecté')),
                );
                return;
              }
              
              final deletionService = Provider.of<DeletionService>(context, listen: false);
              bool success;
              
              // Détecter le type de demande
              final bool isVirtualTransaction = request.runtimeType.toString().contains('VirtualTransaction');
              
              if (isVirtualTransaction) {
                // Validation pour les transactions virtuelles
                if (approve) {
                  success = await deletionService.validateAdminVirtualTransactionDeletionRequest(
                    reference: request.reference,
                    validatorAdminId: admin.id ?? 0,
                    validatorAdminName: admin.username,
                  );
                } else {
                  success = await deletionService.refuseAdminVirtualTransactionDeletionRequest(
                    reference: request.reference,
                    validatorAdminId: admin.id ?? 0,
                    validatorAdminName: admin.username,
                  );
                }
              } else {
                // Validation pour les opérations
                if (approve) {
                  success = await deletionService.validateAdminDeletionRequest(
                    codeOps: request.codeOps,
                    validatorAdminId: admin.id ?? 0,
                    validatorAdminName: admin.username,
                  );
                } else {
                  success = await deletionService.refuseAdminDeletionRequest(
                    codeOps: request.codeOps,
                    validatorAdminId: admin.id ?? 0,
                    validatorAdminName: admin.username,
                  );
                }
              }
              
              Navigator.pop(context);
              
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(approve 
                        ? 'Demande validée avec succès' 
                        : 'Demande refusée'),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Erreur lors de la validation')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
            ),
            child: Text(approve ? 'Confirmer' : 'Refuser'),
          ),
        ],
      ),
    );
  }

  /// Appliquer les filtres avancés aux demandes
  List<dynamic> _getFilteredRequests(List<dynamic> requests) {
    return requests.where((request) {
      final bool isVirtualTransaction = request.runtimeType.toString().contains('VirtualTransaction');
      
      // Extraire les données selon le type
      final double amount = request.montant;
      final String? destinataire = isVirtualTransaction ? request.destinataire : request.destinataire;
      final String? expediteur = isVirtualTransaction ? request.expediteur : request.expediteur;
      final String? clientNom = request.clientNom;
      
      // Filtre par montant minimum
      if (_montantMinController.text.isNotEmpty) {
        final double? minAmount = double.tryParse(_montantMinController.text);
        if (minAmount != null && amount < minAmount) {
          return false;
        }
      }
      
      // Filtre par montant maximum
      if (_montantMaxController.text.isNotEmpty) {
        final double? maxAmount = double.tryParse(_montantMaxController.text);
        if (maxAmount != null && amount > maxAmount) {
          return false;
        }
      }
      
      // Filtre par destinataire
      if (_destinataireController.text.isNotEmpty) {
        final String filterText = _destinataireController.text.toLowerCase();
        if (destinataire == null || !destinataire.toLowerCase().contains(filterText)) {
          return false;
        }
      }
      
      // Filtre par expéditeur
      if (_expediteurController.text.isNotEmpty) {
        final String filterText = _expediteurController.text.toLowerCase();
        if (expediteur == null || !expediteur.toLowerCase().contains(filterText)) {
          return false;
        }
      }
      
      // Filtre par shop (recherche dans client ou expéditeur)
      if (_shopController.text.isNotEmpty) {
        final String filterText = _shopController.text.toLowerCase();
        final bool matchesClient = clientNom?.toLowerCase().contains(filterText) ?? false;
        final bool matchesExpediteur = expediteur?.toLowerCase().contains(filterText) ?? false;
        if (!matchesClient && !matchesExpediteur) {
          return false;
        }
      }
      
      return true;
    }).toList();
  }
  
  /// Effacer tous les filtres avancés
  void _clearFilters() {
    setState(() {
      _montantMinController.clear();
      _montantMaxController.clear();
      _destinataireController.clear();
      _expediteurController.clear();
      _shopController.clear();
    });
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}