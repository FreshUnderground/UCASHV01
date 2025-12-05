import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/pdf_service.dart';
import '../services/shop_service.dart';
import '../services/agent_auth_service.dart';
import '../services/agent_service.dart';
import '../services/flot_service.dart';
import '../models/operation_model.dart';
import '../models/flot_model.dart' as flot_model;

import 'transfer_destination_dialog.dart';
import 'depot_dialog.dart';
import 'retrait_dialog.dart';
import 'operations_help_widget.dart';
import 'pdf_viewer_dialog.dart';


class AgentOperationsWidget extends StatefulWidget {
  const AgentOperationsWidget({super.key});

  @override
  State<AgentOperationsWidget> createState() => _AgentOperationsWidgetState();
}

class _AgentOperationsWidgetState extends State<AgentOperationsWidget> {
  String _searchQuery = '';
  OperationType? _typeFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOperations();
    });
  }

  void _loadOperations() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.id != null) {
      // Charger les opérations filtrées par shop
      // Cela affichera les opérations où le shop est source OU destination
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId!);
      debugPrint('📊 Widget: Chargement des opérations pour shop ${currentUser.shopId}');
    }
  }

  Future<void> _generateReportPdf() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final agentAuthService = Provider.of<AgentAuthService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      final currentAgent = agentAuthService.currentAgent;
      
      if (currentUser == null || currentAgent == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erreur: Utilisateur non connecté'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      
      final shop = shopService.shops.firstWhere((s) => s.id == currentUser.shopId);
      final operations = _getFilteredOperations(operationService.operations);
      
      final pdfService = PdfService();
      final pdfDoc = await pdfService.generateOperationsReportPdf(
        operations: operations,
        shop: shop,
        agent: currentAgent,
        filterType: _typeFilter?.toString(),
      );
      
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdfDoc,
          title: 'Rapport d\'Opérations',
          fileName: 'rapport_operations_${DateTime.now().millisecondsSinceEpoch}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<OperationModel> _getFilteredOperations(List<OperationModel> operations) {
    return operations.where((operation) {
      final matchesSearch = _searchQuery.isEmpty ||
          (operation.destinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
          operation.id.toString().contains(_searchQuery);
      
      final matchesType = _typeFilter == null || operation.type == _typeFilter;
      
      return matchesSearch && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final padding = isMobile ? 16.0 : (size.width <= 1024 ? 20.0 : 24.0);
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header avec boutons d'actions
          _buildHeader(),
          SizedBox(height: isMobile ? 16 : 24),
          
          // Statistiques
          _buildStats(),
          SizedBox(height: isMobile ? 16 : 24),
          
          // Liste des opérations - hauteur fixe pour éviter Expanded dans ScrollView
          SizedBox(
            height: 400,
            child: _buildOperationsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final isTablet = size.width > 768 && size.width <= 1024;
    
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey.shade50],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre avec icône
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet,
                      color: Color(0xFFDC2626),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Mes Opérations',
                    style: TextStyle(
                      fontSize: isMobile ? 20 : 22,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 12 : 16),
              
              // Boutons d'actions - Responsive
              if (isMobile)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildActionButton(
                      onPressed: () => _showDepotDialog(),
                      icon: Icons.add_circle,
                      label: 'Dépôt',
                      color: Colors.green,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      onPressed: () => _showRetraitDialog(),
                      icon: Icons.remove_circle,
                      label: 'Retrait',
                      color: Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      onPressed: () => _showTransfertDestinationDialog(),
                      icon: Icons.send,
                      label: 'Transfert',
                      color: Colors.purple,
                    ),
                  ],
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildActionButton(
                      onPressed: () => _showDepotDialog(),
                      icon: Icons.add_circle,
                      label: 'Dépôt',
                      color: Colors.green,
                    ),
                    _buildActionButton(
                      onPressed: () => _showRetraitDialog(),
                      icon: Icons.remove_circle,
                      label: 'Retrait',
                      color: Colors.orange,
                    ),
                    _buildActionButton(
                      onPressed: () => _showTransfertDestinationDialog(),
                      icon: Icons.send,
                      label: isTablet ? 'Transfert' : 'Transfert Destination',
                      color: Colors.purple,
                    ),
                    _buildActionButton(
                      onPressed: _generateReportPdf,
                      icon: Icons.picture_as_pdf,
                      label: 'Rapport PDF',
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
              SizedBox(height: isMobile ? 12 : 16),
              
              // Barre de recherche et filtres - Responsive
              if (isMobile)
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<OperationType?>(
                            value: _typeFilter,
                            decoration: const InputDecoration(
                              labelText: 'Type',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            items: const [
                              DropdownMenuItem(value: null, child: Text('Toutes')),
                              DropdownMenuItem(value: OperationType.depot, child: Text('Dépôts')),
                              DropdownMenuItem(value: OperationType.retrait, child: Text('Retraits')),
                              DropdownMenuItem(value: OperationType.transfertNational, child: Text('Nationaux')),
                              DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Sortants')),
                              DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Entrants')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _typeFilter = value;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _loadOperations,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualiser',
                          color: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ],
                )
              else
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Rechercher par client, destinataire ou référence...',
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
                    Expanded(
                      child: DropdownButtonFormField<OperationType?>(
                        value: _typeFilter,
                        decoration: const InputDecoration(
                          labelText: 'Type d\'opération',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Toutes')),
                          DropdownMenuItem(value: OperationType.depot, child: Text('Dépôts')),
                          DropdownMenuItem(value: OperationType.retrait, child: Text('Retraits')),
                          DropdownMenuItem(value: OperationType.transfertNational, child: Text('Transferts Nationaux')),
                          DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Transferts Sortants')),
                          DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Transferts Entrants')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _typeFilter = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: _loadOperations,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser',
                      color: const Color(0xFFDC2626),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper pour créer un bouton d'action
  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: isMobile ? 20 : 18),
      label: Text(
        label,
        style: TextStyle(
          fontSize: isMobile ? 16 : 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 12,
          vertical: isMobile ? 14 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }

  Widget _buildStats() {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final operations = operationService.operations;
        final totalOperations = operations.length;
        
        // Also get FLOTs for this shop
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        final flotService = FlotService.instance;
        
        // Filter FLOTs by current shop (source or destination)
        List<OperationModel> shopFlots = [];
        if (currentUser?.shopId != null) {
          shopFlots = flotService.flots.where((f) => 
            f.shopSourceId == currentUser!.shopId || 
            f.shopDestinationId == currentUser.shopId
          ).toList();
        } else {
          shopFlots = flotService.flots;
        }
        
        // Calcul par devise
        final montantUSD = operations.where((op) => op.devise == 'USD').fold<double>(0, (sum, op) => sum + op.montantBrut);
        final montantCDF = operations.where((op) => op.devise == 'CDF').fold<double>(0, (sum, op) => sum + op.montantBrut);
        
        final depots = operations.where((op) => op.type == OperationType.depot).length;
        final retraits = operations.where((op) => op.type == OperationType.retrait).length;
        final transferts = operations.where((op) => 
          op.type == OperationType.transfertNational ||
          op.type == OperationType.transfertInternationalSortant ||
          op.type == OperationType.transfertInternationalEntrant
        ).length;
        
        // Add FLOT count
        final flotsCount = shopFlots.length;

        if (isMobile) {
          // Layout mobile : Grid 3 colonnes x 2 lignes
          return Column(
            children: [
              // Ligne 1 : Total, Dépôts, Retraits
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total',
                      '$totalOperations',
                      Icons.analytics,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Dépôts',
                      '$depots',
                      Icons.add_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Retraits',
                      '$retraits',
                      Icons.remove_circle,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Ligne 2 : Transferts, FLOTs, Volume Total (3 colonnes)
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Transferts',
                      '$transferts',
                      Icons.send,
                      const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'FLOTs',
                      '$flotsCount',
                      Icons.local_shipping,
                      const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMultiDeviseCard(
                      'Volume Total',
                      montantUSD,
                      montantCDF,
                      Icons.attach_money,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ],
          );
        } else {
          // Layout desktop : Row
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Opérations',
                      '$totalOperations',
                      Icons.analytics,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Dépôts',
                      '$depots',
                      Icons.add_circle,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Retraits',
                      '$retraits',
                      Icons.remove_circle,
                      Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'Transferts',
                      '$transferts',
                      Icons.send,
                      const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildStatCard(
                      'FLOTs',
                      '$flotsCount',
                      Icons.local_shipping,
                      const Color(0xFF9C27B0),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildMultiDeviseCard(
                      'Volume Total',
                      montantUSD,
                      montantCDF,
                      Icons.attach_money,
                      Colors.purple,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isMobile ? 28 : 32),
          SizedBox(height: isMobile ? 6 : 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 18 : 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
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

  // Card pour affichage multi-devises
  Widget _buildMultiDeviseCard(String title, double montantUSD, double montantCDF, IconData icon, Color color) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: isMobile ? 28 : 32),
          SizedBox(height: isMobile ? 4 : 6),
          // USD
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${montantUSD.toStringAsFixed(0)} \$',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
            ),
          ),
          // CDF
          if (montantCDF > 0)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${montantCDF.toStringAsFixed(0)} FC',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: color.withOpacity(0.8),
                ),
                maxLines: 1,
              ),
            ),
          SizedBox(height: isMobile ? 2 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 11 : 12,
              color: Colors.grey[700],
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

  Widget _buildOperationsList() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        if (operationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (operationService.errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Erreur: ${operationService.errorMessage}',
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadOperations,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final filteredOperations = _getFilteredOperations(operationService.operations);

        // Get FLOTs for current shop
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        final flotService = FlotService.instance;
        
        // Filter FLOTs by current shop (source or destination)
        List<OperationModel> shopFlots = [];
        if (currentUser?.shopId != null) {
          shopFlots = flotService.flots.where((f) => 
            f.shopSourceId == currentUser!.shopId || 
            f.shopDestinationId == currentUser.shopId
          ).toList();
        } else {
          shopFlots = flotService.flots;
        }

        // Combine operations and FLOTs for display
        final allItems = <dynamic>[...filteredOperations, ...shopFlots];
        
        // Sort by date (most recent first)
        allItems.sort((a, b) {
          DateTime dateA, dateB;
          
          if (a is OperationModel) {
            dateA = a.dateOp;
          } else if (a is flot_model.FlotModel) {
            dateA = a.dateReception ?? a.dateEnvoi;
          } else {
            dateA = DateTime.now();
          }
          
          if (b is OperationModel) {
            dateB = b.dateOp;
          } else if (b is flot_model.FlotModel) {
            dateB = b.dateReception ?? b.dateEnvoi;
          } else {
            dateB = DateTime.now();
          }
          
          return dateB.compareTo(dateA);
        });

        if (allItems.isEmpty) {
          return operationService.operations.isEmpty 
              ? const SingleChildScrollView(child: OperationsHelpWidget())
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.search_off, color: Colors.grey, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucune opération trouvée avec ces critères',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Modifiez vos critères de recherche ou créez une nouvelle opération',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                );
        }

        return Card(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: allItems.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final item = allItems[index];
              if (item is OperationModel) {
                return _buildOperationItem(item);
              } else if (item is flot_model.FlotModel) {
                return _buildFlotItem(item);
              }
              return const SizedBox.shrink();
            },
          ),
        );
      },
    );
  }

  Widget _buildOperationItem(OperationModel operation) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    Color typeColor;
    IconData typeIcon;
    String typeText;
    
    switch (operation.type) {
      case OperationType.depot:
        typeColor = Colors.green;
        typeIcon = Icons.add_circle;
        typeText = 'Dépôt';
        break;
      case OperationType.retrait:
        typeColor = Colors.orange;
        typeIcon = Icons.remove_circle;
        typeText = 'Retrait';
        break;
      case OperationType.retraitMobileMoney:
        typeColor = Colors.orange;
        typeIcon = Icons.mobile_friendly;
        typeText = 'Retrait MM';
        break;
      case OperationType.transfertNational:
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.send;
        typeText = 'Transfert National';
        break;
      case OperationType.transfertInternationalSortant:
        typeColor = const Color(0xFFDC2626);
        typeIcon = Icons.send;
        typeText = 'Transfert Sortant';
        break;
      case OperationType.transfertInternationalEntrant:
        typeColor = Colors.blue;
        typeIcon = Icons.call_received;
        typeText = 'Transfert Entrant';
        break;
      case OperationType.virement:
        typeColor = Colors.purple;
        typeIcon = Icons.swap_horiz;
        typeText = 'Virement';
        break;
      case OperationType.flotShopToShop:
        typeColor = const Color(0xFF2563EB);
        typeIcon = Icons.local_shipping;
        typeText = 'FLOT Shop-to-Shop';
        break;
    }

    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (operation.statut) {
      case OperationStatus.validee:
        statusColor = Colors.green;
        statusText = 'Validée';
        statusIcon = Icons.check_circle;
        break;
      case OperationStatus.terminee:
        statusColor = Colors.green;
        statusText = 'Terminée';
        statusIcon = Icons.check_circle_outline;
        break;
      case OperationStatus.enAttente:
        statusColor = Colors.orange;
        statusText = 'En attente';
        statusIcon = Icons.pending;
        break;
      case OperationStatus.annulee:
        statusColor = Colors.red;
        statusText = 'Annulée';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 4,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(typeIcon, color: typeColor, size: isMobile ? 24 : 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                operation.destinataire != null 
                    ? '${operation.destinataire}'
                    : typeText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 15 : 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Text(
                typeText,
                style: TextStyle(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Montant principal avec icône
              Row(
                children: [
                  Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${operation.montantBrut.toStringAsFixed(2)} ${operation.devise}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 15 : 16,
                      color: typeColor,
                    ),
                  ),
                  if (operation.commission > 0)
                    Text(
                      '  -${operation.commission.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: isMobile ? 12 : 13,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              // Mode de paiement + Statut
              Row(
                children: [
                  // Mode
                  Icon(
                    _getPaymentIcon(operation.modePaiement),
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    operation.modePaiementLabel,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Statut
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(operation.dateOp),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Détails'),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleOperationAction(value, operation),
        ),
      ),
    );
  }

  IconData _getPaymentIcon(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return Icons.money;
      case ModePaiement.airtelMoney:
        return Icons.phone_android;
      case ModePaiement.mPesa:
        return Icons.account_balance_wallet;
      case ModePaiement.orangeMoney:
        return Icons.payment;
      default:
        return Icons.money;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleOperationAction(String action, OperationModel operation) {
    switch (action) {
      case 'details':
        _showOperationDetails(operation);
        break;
    }
  }

  Widget _buildFlotItem(flot_model.FlotModel flot) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    Color typeColor;
    IconData typeIcon;
    String typeText;
    String directionText;
    
    // Determine if this is an incoming or outgoing FLOT for the current shop
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isCurrentShopSource = currentUser?.shopId != null && flot.shopSourceId == currentUser!.shopId;
    final isCurrentShopDestination = currentUser?.shopId != null && flot.shopDestinationId == currentUser!.shopId;
    
    if (isCurrentShopSource) {
      // Outgoing FLOT (sent by current shop)
      typeColor = Colors.orange;
      typeIcon = Icons.local_shipping;
      typeText = 'FLOT Envoyé';
      directionText = 'Vers: ${flot.shopDestinationDesignation}';
    } else if (isCurrentShopDestination) {
      // Incoming FLOT (received by current shop)
      typeColor = Colors.green;
      typeIcon = Icons.local_shipping;
      typeText = 'FLOT Reçu';
      directionText = 'De: ${flot.shopSourceDesignation}';
    } else {
      // Should not happen with proper filtering
      typeColor = Colors.grey;
      typeIcon = Icons.local_shipping;
      typeText = 'FLOT';
      directionText = 'Inconnu';
    }
    
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statusColor = Colors.orange;
        statusText = 'En Route';
        statusIcon = Icons.pending;
        break;
      case flot_model.StatutFlot.servi:
        statusColor = Colors.green;
        statusText = 'Servi';
        statusIcon = Icons.check_circle;
        break;
      case flot_model.StatutFlot.annule:
        statusColor = Colors.red;
        statusText = 'Annulé';
        statusIcon = Icons.cancel;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 12 : 16,
          vertical: isMobile ? 8 : 4,
        ),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [typeColor.withOpacity(0.2), typeColor.withOpacity(0.1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(typeIcon, color: typeColor, size: isMobile ? 24 : 28),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                directionText,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: isMobile ? 15 : 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: typeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: typeColor.withOpacity(0.3)),
              ),
              child: Text(
                typeText,
                style: TextStyle(
                  color: typeColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Montant principal avec icône
              Row(
                children: [
                  Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${flot.montant.toStringAsFixed(2)} ${flot.devise}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 15 : 16,
                      color: typeColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Mode de paiement + Statut
              Row(
                children: [
                  // Mode
                  Icon(
                    _getFlotPaymentIcon(flot.modePaiement),
                    size: 14,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _getFlotModePaiementLabel(flot.modePaiement),
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Statut
                  Icon(statusIcon, size: 14, color: statusColor),
                  const SizedBox(width: 4),
                  Text(
                    statusText,
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 13,
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    _formatFlotDate(flot),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[600]),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.blue),
                  SizedBox(width: 8),
                  Text('Détails'),
                ],
              ),
            ),
          ],
          onSelected: (value) => _handleFlotAction(value, flot),
        ),
      ),
    );
  }

  IconData _getFlotPaymentIcon(flot_model.ModePaiement mode) {
    switch (mode) {
      case flot_model.ModePaiement.cash:
        return Icons.money;
      case flot_model.ModePaiement.airtelMoney:
        return Icons.phone_android;
      case flot_model.ModePaiement.mPesa:
        return Icons.account_balance_wallet;
      case flot_model.ModePaiement.orangeMoney:
        return Icons.payment;
      default:
        return Icons.money;
    }
  }

  String _getFlotModePaiementLabel(flot_model.ModePaiement mode) {
    switch (mode) {
      case flot_model.ModePaiement.cash:
        return 'Cash';
      case flot_model.ModePaiement.airtelMoney:
        return 'Airtel Money';
      case flot_model.ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case flot_model.ModePaiement.orangeMoney:
        return 'Orange Money';
      default:
        return 'Cash';
    }
  }

  String _formatFlotDate(flot_model.FlotModel flot) {
    final date = flot.dateReception ?? flot.dateEnvoi;
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleFlotAction(String action, flot_model.FlotModel flot) {
    switch (action) {
      case 'details':
        _showFlotDetails(flot);
        break;
    }
  }

  void _showFlotDetails(flot_model.FlotModel flot) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    final isCurrentShopSource = currentUser?.shopId != null && flot.shopSourceId == currentUser!.shopId;
    final isCurrentShopDestination = currentUser?.shopId != null && flot.shopDestinationId == currentUser!.shopId;
    
    String directionInfo = '';
    if (isCurrentShopSource) {
      directionInfo = 'Envoyé vers: ${flot.shopDestinationDesignation}';
    } else if (isCurrentShopDestination) {
      directionInfo = 'Reçu de: ${flot.shopSourceDesignation}';
    }
    
    String statusInfo = '';
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statusInfo = 'Statut: En Route (en attente de réception)';
        break;
      case flot_model.StatutFlot.servi:
        statusInfo = 'Statut: Servi (reçu par le shop destination)';
        break;
      case flot_model.StatutFlot.annule:
        statusInfo = 'Statut: Annulé';
        break;
    }
    
    String dateInfo = '';
    if (flot.statut == flot_model.StatutFlot.servi && flot.dateReception != null) {
      dateInfo = 'Date de réception: ${_formatFlotDate(flot)}';
    } else {
      dateInfo = 'Date d\'envoi: ${_formatDate(flot.dateEnvoi)}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails FLOT - ${flot.reference}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montant: ${flot.montant} ${flot.devise}'),
            Text(directionInfo),
            Text('Mode de paiement: ${_getFlotModePaiementLabel(flot.modePaiement)}'),
            Text(statusInfo),
            Text(dateInfo),
            if (flot.notes != null && flot.notes!.isNotEmpty)
              Text('Notes: ${flot.notes}'),
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

  void _showDepotDialog() {
    showDialog(
      context: context,
      builder: (context) => const DepotDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }

  void _showRetraitDialog() {
    showDialog(
      context: context,
      builder: (context) => const RetraitDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }



  void _showTransfertDestinationDialog() {
    showDialog(
      context: context,
      builder: (context) => const TransferDestinationDialog(),
    ).then((result) {
      if (result == true) {
        _loadOperations();
      }
    });
  }

  void _showOperationDetails(OperationModel operation) {
    final agentService = Provider.of<AgentService>(context, listen: false);
    final agent = agentService.getAgentById(operation.agentId);
    final agentName = agent?.nom ?? agent?.username ?? operation.lastModifiedBy ?? 'Agent inconnu';
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ID ${operation.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type: ${operation.typeLabel}'),
            if (operation.destinataire != null)
              Text('Destinataire: ${operation.destinataire}'),
            Text('Montant brut: ${operation.montantBrut} ${operation.devise}'),
            if (operation.commission > 0)
              Text('Commission: ${operation.commission} ${operation.devise}'),
            Text('Montant net: ${operation.montantNet} ${operation.devise}'),
            Text('Mode de paiement: ${operation.modePaiementLabel}'),
            Text('Statut: ${operation.statutLabel}'),
            Text('Agent: $agentName'),
            Text('Date: ${_formatDate(operation.dateOp)}'),
            if (operation.notes != null)
              Text('Notes: ${operation.notes}'),
            if (operation.observation != null && operation.observation!.isNotEmpty)
              Text('Observation: ${operation.observation}'),
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