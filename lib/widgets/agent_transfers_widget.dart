import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import 'transfer_destination_dialog.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/printer_service.dart';
import '../services/connectivity_service.dart';
import '../services/rates_service.dart';
import '../services/sync_service.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import '../utils/responsive_utils.dart';

class AgentTransfersWidget extends StatefulWidget {
  const AgentTransfersWidget({super.key});

  @override
  State<AgentTransfersWidget> createState() => _AgentTransfersWidgetState();
}

class _AgentTransfersWidgetState extends State<AgentTransfersWidget> {
  String _searchQuery = '';
  String _statusFilter = 'all';
  
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
      Provider.of<OperationService>(context, listen: false).loadOperations(shopId: currentUser!.shopId);
    }
  }
  
  List<OperationModel> _getFilteredTransfers(OperationService operationService, AuthService authService) {
    final currentUser = authService.currentUser;
    if (currentUser == null) return [];
    
    // Filtrer les transferts (nationaux et internationaux)
    var transfers = operationService.operations.where((op) {
      return (op.type == OperationType.transfertNational ||
              op.type == OperationType.transfertInternationalSortant ||
              op.type == OperationType.transfertInternationalEntrant) &&
             op.agentId == currentUser.id;
    }).toList();
    
    // Appliquer les filtres de recherche
    if (_searchQuery.isNotEmpty) {
      transfers = transfers.where((op) {
        final dest = op.destinataire?.toLowerCase() ?? '';
        final id = op.id?.toString() ?? '';
        return dest.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery);
      }).toList();
    }
    
    // Appliquer le filtre de statut
    if (_statusFilter != 'all') {
      transfers = transfers.where((op) {
        switch (_statusFilter) {
          case 'EN_ATTENTE':
            return op.statut == OperationStatus.enAttente;
          case 'VALIDEE':
            return op.statut == OperationStatus.validee;
          default:
            return true;
        }
      }).toList();
    }
    
    // Trier par date décroissante
    transfers.sort((a, b) => b.dateOp.compareTo(a.dateOp));
    
    return transfers;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<OperationService, AuthService>(
      builder: (context, operationService, authService, child) {
        final transfers = _getFilteredTransfers(operationService, authService);
        
        return Padding(
          padding: ResponsiveUtils.getFluidPadding(
            context,
            mobile: const EdgeInsets.all(12),
            tablet: const EdgeInsets.all(16),
            desktop: const EdgeInsets.all(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec recherche et filtres
              _buildHeader(),
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
              
              // Statistiques
              _buildStats(transfers),
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 16, desktop: 20)),
              
              // Liste des transferts - Utiliser Expanded au lieu de SizedBox fixe
              Expanded(
                child: _buildTransfersList(transfers),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              // Titre et bouton - Responsive
              if (context.isSmallScreen)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Mes Transferts',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () => _showTransfertDestinationDialog(),
                      icon: const Icon(Icons.send, size: 22),
                      label: const Text(
                        'Nouveau Transfert',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mes Transferts',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1F2937),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showTransfertDestinationDialog(),
                      icon: const Icon(Icons.send, size: 22),
                      label: const Text(
                        'Nouveau Transfert',
                        style: TextStyle(
                          fontSize: 16,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              
              // Barre de recherche et filtres
              if (context.isSmallScreen)
                Column(
                  children: [
                    TextField(
                      decoration: InputDecoration(
                        hintText: 'Rechercher par destinataire ou référence...',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _statusFilter,
                            decoration: InputDecoration(
                              labelText: 'Statut',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            items: const [
                              DropdownMenuItem(value: 'all', child: Text('Tous')),
                              DropdownMenuItem(value: 'EN_ATTENTE', child: Text('En attente')),
                              DropdownMenuItem(value: 'VALIDEE', child: Text('Validée')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _statusFilter = value ?? 'all';
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              // Actualiser les données
                            });
                          },
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualiser',
                          color: const Color(0xFFDC2626),
                          style: IconButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626).withOpacity(0.1),
                            padding: const EdgeInsets.all(16),
                          ),
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
                        decoration: InputDecoration(
                          hintText: 'Rechercher par destinataire ou référence...',
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 20),
                    
                    // Filtre par statut
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: InputDecoration(
                          labelText: 'Statut',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade50,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Tous')),
                          DropdownMenuItem(value: 'EN_ATTENTE', child: Text('En attente')),
                          DropdownMenuItem(value: 'VALIDEE', child: Text('Validée')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _statusFilter = value ?? 'all';
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(width: 20),
                    
                    // Bouton actualiser
                    IconButton(
                      onPressed: () {
                        setState(() {
                          // Actualiser les données
                        });
                      },
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser',
                      color: const Color(0xFFDC2626),
                      style: IconButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626).withOpacity(0.1),
                        padding: const EdgeInsets.all(16),
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

  void _showTransfertDestinationDialog() async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Synchronisation des données...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Check internet connectivity
      final connectivityService = ConnectivityService.instance;
      final hasConnection = connectivityService.isOnline;

      if (hasConnection) {
        debugPrint('📥 Synchronisation commissions et shops pour transfert...');
        
        // NE PAS vider - juste synchroniser depuis le serveur
        // Le serveur enverra les modifiés, LocalDB les mergera
        debugPrint('🔄 Téléchargement depuis le serveur...');
        final syncService = SyncService();
        await Future.wait([
          syncService.downloadTableData('commissions', 'admin', 'admin'),
          syncService.downloadTableData('shops', 'admin', 'admin'),
        ]);
        
        // Recharger en mémoire
        final ratesService = RatesService.instance;
        final shopService = Provider.of<ShopService>(context, listen: false);
        await Future.wait([
          ratesService.loadRatesAndCommissions(),
          shopService.loadShops(),
        ]);

        debugPrint('✅ ${shopService.shops.length} shops et ${ratesService.commissions.length} commissions chargés');
      } else {
        debugPrint('ℹ️ Hors ligne - utilisation des données locales');
        // Charger depuis la base locale
        final ratesService = RatesService.instance;
        final shopService = Provider.of<ShopService>(context, listen: false);
        await Future.wait([
          ratesService.loadRatesAndCommissions(),
          shopService.loadShops(),
        ]);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors de la synchronisation: $e');
      // En cas d'erreur, charger depuis la base locale
      try {
        final ratesService = RatesService.instance;
        final shopService = Provider.of<ShopService>(context, listen: false);
        await Future.wait([
          ratesService.loadRatesAndCommissions(),
          shopService.loadShops(),
        ]);
        debugPrint('💾 Données chargées depuis la base locale');
      } catch (localError) {
        debugPrint('❌ Erreur chargement local: $localError');
      }
    }

    // Close loading dialog
    if (mounted) Navigator.of(context).pop();

    // Show transfer dialog
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => const TransferDestinationDialog(),
      ).then((result) {
        if (result == true) {
          _loadOperations();
        }
      });
    }
  }

  Widget _buildStats(List<OperationModel> transfers) {
    final totalTransfers = transfers.length;
    final totalMontant = transfers.fold<double>(0, (sum, t) => sum + t.montantBrut);
    final enAttente = transfers.where((t) => t.statut == OperationStatus.enAttente).length;
    final validees = transfers.where((t) => t.statut == OperationStatus.validee).length;

    return Card(
      elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 16),
        ),
      ),
      child: Padding(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(12),
          tablet: const EdgeInsets.all(16),
          desktop: const EdgeInsets.all(20),
        ),
        child: Row(
          children: [
            _buildStatCard(
              'Total Transferts',
              '$totalTransfers',
              Icons.send,
              Colors.blue,
            ),
            SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            _buildStatCard(
              'Montant Total',
              '${totalMontant.toStringAsFixed(0)} USD',
              Icons.attach_money,
              Colors.green,
            ),
            SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            _buildStatCard(
              'En Attente',
              '$enAttente',
              Icons.hourglass_empty,
              Colors.orange,
            ),
            SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
            _buildStatCard(
              'Validées',
              '$validees',
              Icons.check_circle,
              Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, 
                color: color, 
                size: 32,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersList(List<OperationModel> transfers) {
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.send_outlined, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            const Text(
              'Aucun transfert trouvé',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            const Text(
              'Cliquez sur "Nouveau Transfert" pour envoyer de l\'argent',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showTransfertDestinationDialog(),
              icon: const Icon(Icons.send),
              label: const Text('Nouveau Transfert'),
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
      elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 12, desktop: 16),
        ),
      ),
      child: ListView.separated(
        padding: ResponsiveUtils.getFluidPadding(
          context,
          mobile: const EdgeInsets.all(12),
          tablet: const EdgeInsets.all(14),
          desktop: const EdgeInsets.all(16),
        ),
        itemCount: transfers.length,
        separatorBuilder: (context, index) => const Divider(),
        itemBuilder: (context, index) {
          final transfer = transfers[index];
          return _buildTransferItem(transfer);
        },
      ),
    );
  }

  Widget _buildTransferItem(OperationModel transfer) {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (transfer.statut) {
      case OperationStatus.enAttente:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'En attente';
        break;
      case OperationStatus.validee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Validée';
        break;
      case OperationStatus.terminee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline;
        statusText = 'Terminée';
        break;
      case OperationStatus.annulee:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Annulée';
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help_outline;
        statusText = 'Inconnu';
    }
    
    // Nom du type de transfert
    String typeText;
    switch (transfer.type) {
      case OperationType.transfertNational:
        typeText = 'National';
        break;
      case OperationType.transfertInternationalSortant:
        typeText = 'International Sortant';
        break;
      case OperationType.transfertInternationalEntrant:
        typeText = 'International Entrant';
        break;
      default:
        typeText = 'Transfert';
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          leading: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          title: Text(
            'Transfert $typeText',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Montant avec icône
              Row(
                children: [
                  Icon(Icons.attach_money, size: 18, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    '${transfer.montantBrut.toStringAsFixed(2)} ${transfer.devise}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: statusColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // ID et Référence
              Row(
                children: [
                  Icon(Icons.info, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'ID: ${transfer.id ?? "N/A"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.tag, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Réf: ${transfer.reference ?? "N/A"}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Statut
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusText,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              // Date
              Row(
                children: [
                  Icon(Icons.access_time, size: 16, color: Colors.grey[500]),
                  const SizedBox(width: 6),
                  Text(
                    _formatDate(transfer.dateOp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              if (transfer.notes != null && transfer.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.note, size: 16, color: Colors.grey[500]),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Note: ${transfer.notes}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[600]),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'details',
                child: Row(
                  children: [
                    const Icon(Icons.info, size: 18, color: Colors.blue),
                    const SizedBox(width: 10),
                    const Text('Détails'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'reprint',
                child: Row(
                  children: [
                    const Icon(Icons.print, size: 18, color: Colors.green),
                    const SizedBox(width: 10),
                    const Text('Reimprimer'),
                  ],
                ),
              ),
            ],
            onSelected: (value) {
              if (value == 'reprint') {
                _reprintTransferReceipt(transfer);
              } else {
                _showTransferDetails(transfer);
              }
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _reprintTransferReceipt(OperationModel transfer) async {
    try {
      // Récupérer les services nécessaires
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      // Obtenir le shop de l'agent
      final shopId = authService.currentUser?.shopId;
      if (shopId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Shop non trouvé')),
        );
        return;
      }
      
      final shop = shopService.getShopById(shopId);
      if (shop == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Shop non trouvé')),
        );
        return;
      }
      
      // Obtenir l'agent
      final user = authService.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Agent non trouvé')),
        );
        return;
      }
      
      // Convertir UserModel en AgentModel
      final agent = AgentModel(
        id: user.id,
        username: user.username,
        password: user.password,
        shopId: user.shopId ?? 0,
        nom: user.nom,
        telephone: user.telephone,
      );
      
      // Enrichir l'opération avec les noms de shops si manquants (pour les transferts)
      OperationModel enrichedTransfer = transfer;
      String? sourceDesignation = transfer.shopSourceDesignation;
      String? destDesignation = transfer.shopDestinationDesignation;
      
      // Enrichir shop source si manquant
      if ((sourceDesignation == null || sourceDesignation.isEmpty) && transfer.shopSourceId != null) {
        final sourceShop = shopService.getShopById(transfer.shopSourceId!);
        if (sourceShop != null) {
          sourceDesignation = sourceShop.designation;
        }
      }
      
      // Enrichir shop destination si manquant
      if ((destDesignation == null || destDesignation.isEmpty) && transfer.shopDestinationId != null) {
        final destShop = shopService.getShopById(transfer.shopDestinationId!);
        if (destShop != null) {
          destDesignation = destShop.designation;
        }
      }
      
      // Créer une copie enrichie si nécessaire
      if (sourceDesignation != transfer.shopSourceDesignation || 
          destDesignation != transfer.shopDestinationDesignation) {
        enrichedTransfer = transfer.copyWith(
          shopSourceDesignation: sourceDesignation,
          shopDestinationDesignation: destDesignation,
        );
      }
      
      // Confirmation avant impression
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.print, color: Colors.green),
              SizedBox(width: 12),
              Text('Confirmer la réimpression'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Transfert #${enrichedTransfer.id}'),
              const SizedBox(height: 8),
              Text('Type: ${_getTransferTypeText(enrichedTransfer.type)}'),
              const SizedBox(height: 8),
              Text('Montant: ${enrichedTransfer.montantNet.toStringAsFixed(2)} ${enrichedTransfer.devise}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '🖨️ Le reçu sera imprimé sur l\'imprimante Q2I',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.print),
              label: const Text('Imprimer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;
      
      // Imprimer le reçu
      final printerService = PrinterService();
      final success = await printerService.printReceipt(
        operation: enrichedTransfer,
        shop: shop,
        agent: agent,
      );
      
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Reçu reimprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Échec de l\'impression'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur réimpression: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  String _getTransferTypeText(OperationType type) {
    switch (type) {
      case OperationType.transfertNational:
        return '🔄 Transfert National';
      case OperationType.transfertInternationalSortant:
        return '🌍 Transfert International Sortant';
      case OperationType.transfertInternationalEntrant:
        return '🌍 Transfert International Entrant';
      default:
        return 'Transfert';
    }
  }

  void _showTransferDetails(OperationModel transfer) {
    // Type de transfert
    String typeText;
    switch (transfer.type) {
      case OperationType.transfertNational:
        typeText = 'National';
        break;
      case OperationType.transfertInternationalSortant:
        typeText = 'International Sortant';
        break;
      case OperationType.transfertInternationalEntrant:
        typeText = 'International Entrant';
        break;
      default:
        typeText = 'Transfert';
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails - ID ${transfer.id ?? "N/A"}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Type', typeText),
              _buildDetailRow('Montant brut', '${transfer.montantBrut.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Montant net', '${transfer.montantNet.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Commission', '${transfer.commission.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Mode de paiement', _getModePaiementText(transfer.modePaiement)),
              _buildDetailRow('Statut', _getStatutText(transfer.statut)),
              _buildDetailRow('Date', _formatDate(transfer.dateOp)),
              _buildDetailRow('ID', transfer.id?.toString() ?? 'N/A'),
              _buildDetailRow('Référence', transfer.reference ?? 'N/A'), // Add reference field
              if (transfer.notes != null && transfer.notes!.isNotEmpty)
                _buildDetailRow('Notes', transfer.notes!),
            ],
          ),
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
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'N/A', // Fix N/A display
              style: const TextStyle(),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getModePaiementText(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'M-Paiement';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
      default:
        return 'Inconnu';
    }
  }
  
  String _getStatutText(OperationStatus statut) {
    switch (statut) {
      case OperationStatus.enAttente:
        return 'En attente';
      case OperationStatus.validee:
        return 'Validée';
      case OperationStatus.terminee:
        return 'Terminée';
      case OperationStatus.annulee:
        return 'Annulée';
      default:
        return 'Inconnu';
    }
  }
}
