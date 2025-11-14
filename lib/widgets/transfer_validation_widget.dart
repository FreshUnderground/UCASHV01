import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../services/sync_service.dart';
import '../models/operation_model.dart';
import '../models/shop_model.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class TransferValidationWidget extends StatefulWidget {
  const TransferValidationWidget({super.key});

  @override
  State<TransferValidationWidget> createState() => _TransferValidationWidgetState();
}

class _TransferValidationWidgetState extends State<TransferValidationWidget> {
  OperationType? _filterType;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingTransfers();
    });
  }

  void _loadPendingTransfers() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.shopId != null) {
      Provider.of<OperationService>(context, listen: false)
          .loadOperations(shopId: currentUser!.shopId!);
      Provider.of<ShopService>(context, listen: false).loadShops();
    }
  }

  List<OperationModel> _getPendingTransfers(List<OperationModel> operations) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    
    return operations.where((operation) {
      // Filtrer seulement les transferts en attente dont la destination est notre shop
      final matchesStatus = operation.statut == OperationStatus.enAttente;
      final matchesType = operation.type == OperationType.transfertNational ||
                         operation.type == OperationType.transfertInternationalSortant ||
                         operation.type == OperationType.transfertInternationalEntrant;
      final matchesDestination = operation.shopDestinationId == currentShopId;
      
      // Filtres additionnels
      final matchesTypeFilter = _filterType == null || operation.type == _filterType;
      final matchesSearch = _searchQuery.isEmpty ||
                           (operation.destinataire?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false) ||
                           operation.id.toString().contains(_searchQuery);
      
      return matchesStatus && matchesType && matchesDestination && matchesTypeFilter && matchesSearch;
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
          // Header
          _buildHeader(),
          SizedBox(height: isMobile ? 16 : 24),
          
          // Filtres
          _buildFilters(),
          SizedBox(height: isMobile ? 16 : 24),
          
          // Liste des transferts en attente - hauteur fixe
          SizedBox(
            height: 400,
            child: _buildTransfersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Consumer<OperationService>(
      builder: (context, operationService, child) {
        final pendingTransfers = _getPendingTransfers(operationService.operations);
        final totalAmount = pendingTransfers.fold<double>(0, (sum, op) => sum + op.montantNet);
        
        return context.adaptiveCard(
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Validation des Opérations',
                    style: context.titleAccent,
                  ),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.orange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${pendingTransfers.length} en attente',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: _loadPendingTransfers,
                          icon: const Icon(Icons.refresh),
                          tooltip: 'Actualiser',
                          color: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ],
                ),
              context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
              
              // Statistiques
              context.gridContainer(
                mobileColumns: 1,
                tabletColumns: 3,
                desktopColumns: 3,
                aspectRatio: context.isSmallScreen ? 2.5 : 1.8,
                children: [
                  _buildStatCard(
                    'Transferts en Attente',
                    '${pendingTransfers.length}',
                    Icons.pending_actions,
                    Colors.orange,
                  ),
                  _buildStatCard(
                    'Montant Total',
                    '${totalAmount.toStringAsFixed(2)} USD',
                    Icons.attach_money,
                    Colors.blue,
                  ),
                  _buildStatCard(
                    'Destination',
                    'Votre Shop',
                    Icons.location_on,
                    const Color(0xFFDC2626),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Container(
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon, 
            color: color, 
            size: isMobile ? 20 : 24,
          ),
          SizedBox(height: isMobile ? 4 : 8),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 4),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isMobile ? 10 : 12,
                color: Colors.grey[700],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return context.adaptiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filtres et Recherche',
            style: context.h4.copyWith(
              color: const Color(0xFFDC2626),
            ),
          ),
          context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
          
          if (context.isSmallScreen) ..._buildMobileFilters() else ..._buildDesktopFilters(),
        ],
      ),
    );
  }

  Widget _buildTransfersList() {
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
                  onPressed: _loadPendingTransfers,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          );
        }

        final pendingTransfers = _getPendingTransfers(operationService.operations);

        if (pendingTransfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.green, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'Aucun transfert en attente de validation',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tous les transferts vers votre shop ont été traités',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return context.adaptiveCard(
          child: ListView.separated(
            padding: context.fluidPadding(
              mobile: const EdgeInsets.all(12),
              tablet: const EdgeInsets.all(16),
              desktop: const EdgeInsets.all(20),
            ),
            itemCount: pendingTransfers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final transfer = pendingTransfers[index];
              return _buildTransferItem(transfer);
            },
          ),
        );
      },
    );
  }

  Widget _buildTransferItem(OperationModel transfer) {
    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        final sourceShop = shopService.shops.firstWhere(
          (shop) => shop.id == transfer.shopSourceId,
          orElse: () => ShopModel(designation: 'Shop Inconnu', localisation: ''),
        );
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header du transfert
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'EN ATTENTE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'ID: ${transfer.id}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _formatDate(transfer.dateOp),
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Informations du shop source
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.store, color: Colors.blue, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Provenance: ${sourceShop.designation}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            sourceShop.localisation,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Informations du transfert
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Type', _getTransferTypeLabel(transfer.type)),
                        const SizedBox(height: 4),
                        _buildInfoRow('Destinataire', transfer.destinataire ?? 'Non spécifié'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Montant brut', '${transfer.montantBrut.toStringAsFixed(2)} USD'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Commission', '${transfer.commission.toStringAsFixed(2)} USD'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Montant net', '${transfer.montantNet.toStringAsFixed(2)} USD'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Mode de paiement', transfer.modePaiementLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Actions
                  Column(
                    children: [
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _validateTransfer(transfer),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Valider'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _rejectTransfer(transfer),
                            icon: const Icon(Icons.close, size: 16),
                            label: const Text('Rejeter'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 13,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  String _getTransferTypeLabel(OperationType type) {
    switch (type) {
      case OperationType.transfertNational:
        return 'Transfert National';
      case OperationType.transfertInternationalSortant:
        return 'Transfert International Sortant';
      case OperationType.transfertInternationalEntrant:
        return 'Transfert International Entrant';
      default:
        return 'Transfert';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _showTransferImage(OperationModel transfer) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Preuve de Paiement - ID ${transfer.id}'),
        content: Container(
          width: 300,
          height: 400,
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.image, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Image de la preuve de paiement'),
                SizedBox(height: 8),
                Text(
                  '(Dans une vraie application, l\'image serait affichée ici)',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
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

  Future<void> _validateTransfer(OperationModel transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le Transfert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Êtes-vous sûr de vouloir valider ce transfert ?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${transfer.id}'),
                  Text('Destinataire: ${transfer.destinataire}'),
                  Text('Montant: ${transfer.montantNet.toStringAsFixed(2)} USD'),
                ],
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final operationService = Provider.of<OperationService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Sélection du mode de paiement
        final modePaiement = await _selectModePaiement();
        if (modePaiement == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Mode de paiement requis'),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
        
        // UTILISER validerTransfertServeur au lieu de updateOperation
        // pour forcer isSynced=false et synchronisation immédiate
        final success = await operationService.validerTransfertServeur(
          transfer.id!,
          modePaiement,
          currentShopId: authService.currentUser?.shopId,
        );
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Transfert ID ${transfer.id} validé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPendingTransfers();
        } else if (mounted) {
          throw Exception(operationService.errorMessage ?? 'Erreur lors de la validation');
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
      }
    }
  }

  // Sélecteur de mode de paiement
  Future<ModePaiement?> _selectModePaiement() async {
    return showDialog<ModePaiement>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mode de Paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.money, color: Colors.green),
              title: const Text('Cash'),
              onTap: () => Navigator.of(context).pop(ModePaiement.cash),
            ),
            ListTile(
              leading: const Icon(Icons.phone_android, color: Colors.red),
              title: const Text('Airtel Money'),
              onTap: () => Navigator.of(context).pop(ModePaiement.airtelMoney),
            ),
            ListTile(
              leading: const Icon(Icons.account_balance_wallet, color: Colors.green),
              title: const Text('M-Pesa'),
              onTap: () => Navigator.of(context).pop(ModePaiement.mPesa),
            ),
            ListTile(
              leading: const Icon(Icons.payment, color: Colors.orange),
              title: const Text('Orange Money'),
              onTap: () => Navigator.of(context).pop(ModePaiement.orangeMoney),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejectTransfer(OperationModel transfer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le Transfert'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Êtes-vous sûr de vouloir rejeter ce transfert ?'),
            const SizedBox(height: 8),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ID: ${transfer.id}'),
                  Text('Destinataire: ${transfer.destinataire}'),
                  Text('Montant: ${transfer.montantNet.toStringAsFixed(2)} USD'),
                ],
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
            child: const Text('Rejeter', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final operationService = Provider.of<OperationService>(context, listen: false);
        final authService = Provider.of<AuthService>(context, listen: false);
        
        // Mettre à jour le statut à rejeté avec isSynced=false
        final updatedTransfer = transfer.copyWith(
          statut: OperationStatus.annulee,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'agent_${authService.currentUser?.id}',
          isSynced: false,  // IMPORTANT: Forcer la synchronisation vers le serveur
        );
        
        // Sauvegarder via le service
        final success = await operationService.updateOperation(updatedTransfer);
        
        if (success) {
          // Synchronisation immédiate
          debugPrint('🔄 Synchronisation immédiate du transfert rejeté...');
          try {
            final syncService = SyncService();
            await syncService.syncAll();
            debugPrint('✅ Transfert ${transfer.id} rejeté et synchronisé avec le serveur');
          } catch (e) {
            debugPrint('⚠️ Erreur de synchronisation (transfert rejeté localement): $e');
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Transfert ID ${transfer.id} rejeté'),
                backgroundColor: Colors.orange,
              ),
            );
            _loadPendingTransfers();
          }
        } else if (mounted) {
          throw Exception('Erreur lors du rejet');
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
      }
    }
  }

  List<Widget> _buildMobileFilters() {
    return [
      // Recherche
      TextField(
        decoration: const InputDecoration(
          hintText: 'Rechercher par destinataire ou ID...',
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
      context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
      
      // Filtre par type
      DropdownButtonFormField<OperationType?>(
        value: _filterType,
        decoration: const InputDecoration(
          labelText: 'Type de transfert',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('Tous les types')),
          DropdownMenuItem(value: OperationType.transfertNational, child: Text('National')),
          DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Int. Sortant')),
          DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Int. Entrant')),
        ],
        onChanged: (value) {
          setState(() {
            _filterType = value;
          });
        },
      ),
      context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
      
      // Bouton reset
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () {
            setState(() {
              _filterType = null;
              _searchQuery = '';
            });
          },
          icon: const Icon(Icons.clear, size: 16),
          label: const Text('Effacer les filtres'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey,
            foregroundColor: Colors.white,
          ),
        ),
      ),
    ];
  }

  List<Widget> _buildDesktopFilters() {
    return [
      Row(
        children: [
          // Recherche
          Expanded(
            flex: 2,
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Rechercher par destinataire ou ID...',
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
          context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
          
          // Filtre par type
          Expanded(
            child: DropdownButtonFormField<OperationType?>(
              value: _filterType,
              decoration: const InputDecoration(
                labelText: 'Type de transfert',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: null, child: Text('Tous les types')),
                DropdownMenuItem(value: OperationType.transfertNational, child: Text('National')),
                DropdownMenuItem(value: OperationType.transfertInternationalSortant, child: Text('Int. Sortant')),
                DropdownMenuItem(value: OperationType.transfertInternationalEntrant, child: Text('Int. Entrant')),
              ],
              onChanged: (value) {
                setState(() {
                  _filterType = value;
                });
              },
            ),
          ),
          
          context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
          
          // Bouton reset
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                _filterType = null;
                _searchQuery = '';
              });
            },
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Reset'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    ];
  }
}
