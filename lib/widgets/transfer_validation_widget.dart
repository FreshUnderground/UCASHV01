import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../services/transfer_sync_service.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/shop_service.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import '../utils/auto_print_helper.dart';

/// Widget de validation des transferts en attente
class TransferValidationWidget extends StatefulWidget {
  const TransferValidationWidget({super.key});

  @override
  State<TransferValidationWidget> createState() => _TransferValidationWidgetState();
}

class _TransferValidationWidgetState extends State<TransferValidationWidget> {
  bool _isInitialized = false;
  String? _filterType;
  String _searchDestinataire = '';
  bool _showFilters = false;
  Timer? _autoRefreshTimer;
  int _selectedTab = 0; // 0 = Transferts en attente, 1 = Mes Validations
  
  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeService() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final operationService = Provider.of<OperationService>(context, listen: false);
    final shopId = authService.currentUser?.shopId ?? 0;
    final userRole = authService.currentUser?.role ?? '';
    
    if (shopId > 0) {
      try {
        // Charger les opérations du shop (pour "Mes Validations")
        debugPrint('📥 [INIT] Chargement des opérations du shop $shopId...');
        await operationService.loadOperations(shopId: shopId);
        debugPrint('✅ [INIT] ${operationService.operations.length} opérations chargées');
        
        // Initialiser le service de transferts (pour "En attente")
        final transferSync = Provider.of<TransferSyncService>(context, listen: false);
        await transferSync.initialize(shopId);
        
        // Forcer un refresh immédiat depuis l'API (pas de cache)
        try {
          await transferSync.forceRefreshFromAPI();
        } catch (e) {
          // Si le premier refresh échoue, ce n'est pas grave, on continuera avec le cache
          debugPrint('⚠️ [INIT] Première synchronisation échouée: $e');
          debugPrint('   💡 Le service continuera avec les données en cache (si disponibles)');
        }
        
        // Démarrer le rafraîchissement automatique toutes les 5 minutes
        _startAutoRefresh(transferSync);
        
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      } catch (e) {
        debugPrint('❌ [INIT] Erreur d\'initialisation: $e');
        if (mounted) {
          setState(() => _isInitialized = true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('⚠️ Erreur d\'initialisation: ${e.toString()}'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Réessayer',
                textColor: Colors.white,
                onPressed: _initializeService,
              ),
            ),
          );
        }
      }
    } else {
      // Handle case where shopId is not initialized
      debugPrint('⚠️ [INIT] Shop ID non initialisé, affichage d\'un message d\'erreur');
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }

  void _startAutoRefresh(TransferSyncService transferSync) {
    _autoRefreshTimer?.cancel();
    
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !transferSync.isSyncing) {
        debugPrint('⏰ [AUTO-REFRESH] Rafraîchissement automatique depuis l\'API...');
        transferSync.forceRefreshFromAPI();
      }
    });
    
    debugPrint('✅ [AUTO-REFRESH] Timer démarré (5 minutes)');
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Consumer<TransferSyncService>(
      builder: (context, transferSync, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final operationService = Provider.of<OperationService>(context, listen: false);
        final shopId = authService.currentUser?.shopId ?? 0;
        final userRole = authService.currentUser?.role ?? '';
        final agentId = authService.currentUser?.id ?? 0;
        
        // Handle case where shopId is not initialized
        if (shopId <= 0) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    userRole == 'ADMIN' ? Icons.admin_panel_settings : Icons.error_outline,
                    size: 60,
                    color: userRole == 'ADMIN' ? Colors.blue[700] : Colors.orange[700],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    userRole == 'ADMIN' ? 'Accès non autorisé' : 'Erreur d\'initialisation',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    userRole == 'ADMIN' 
                        ? 'Cette fonctionnalité est réservée aux agents avec un shop assigné.'
                        : 'Impossible de charger les transferts: Shop ID non initialisé',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  if (userRole != 'ADMIN') ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _initializeService,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        
        // Déterminer les opérations à afficher selon l'onglet
        List<OperationModel> displayedOperations;
        
        if (_selectedTab == 0) {
          // Onglet 1: Transferts en attente (depuis TransferSyncService)
          displayedOperations = transferSync.getPendingTransfersForShop(shopId);
        } else {
          // Onglet 2: Mes Validations (opérations validées dans ce shop)
          debugPrint('🔍 [MES VALIDATIONS] Filtrage des opérations...');
          debugPrint('🔍 [MES VALIDATIONS] Total opérations: ${operationService.operations.length}');
          debugPrint('🔍 [MES VALIDATIONS] ShopId: $shopId');
          
          displayedOperations = operationService.operations.where((op) {
            // Transferts validés/terminés
            final isTransfer = op.type == OperationType.transfertNational ||
                op.type == OperationType.transfertInternationalEntrant ||
                op.type == OperationType.transfertInternationalSortant;
            final isValidated = op.statut == OperationStatus.validee || 
                op.statut == OperationStatus.terminee;
            // Validés dans ce shop (destination = shop qui reçoit et valide)
            final isForThisShop = op.shopDestinationId == shopId;
            
            return isTransfer && isValidated && isForThisShop;
          }).toList();
          
          debugPrint('✅ [MES VALIDATIONS] Trouvé: ${displayedOperations.length} opérations validées dans le shop');
          
          // Trier par date de modification (plus récents en premier)
          displayedOperations.sort((a, b) => 
            (b.lastModifiedAt ?? b.dateOp).compareTo(a.lastModifiedAt ?? a.dateOp)
          );
        }
        
        // Filtrer par nom de destinataire si recherche active
        if (_searchDestinataire.isNotEmpty) {
          displayedOperations = displayedOperations.where((op) {
            final destinataire = op.destinataire?.toLowerCase() ?? '';
            return destinataire.contains(_searchDestinataire.toLowerCase());
          }).toList();
        }
        
        // Filtrer par type si sélectionné
        if (_filterType != null) {
          displayedOperations = displayedOperations.where((op) {
            return op.type.toString().split('.').last == _filterType;
          }).toList();
        }

        return Padding(
          padding: EdgeInsets.all(isMobile ? 2 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Onglets pour basculer entre En attente et Mes Validations
              _buildTabBar(isMobile),
              
              SizedBox(height: isMobile ? 4 : 16),
              
              // Compteur et bouton pour afficher/masquer filtres
              _buildStatusBar(isMobile, transferSync, displayedOperations.length),
              
              SizedBox(height: isMobile ? 4 : 20),
              
              // Filtres et actions (affichés conditionnellement)
              if (_showFilters) ...[
                _buildFiltersAndActions(isMobile, transferSync),
                SizedBox(height: isMobile ? 7 : 20)
              ],
              
              // Liste des transferts
              Flexible(
                fit: FlexFit.loose,
                child: _buildTransfersList(isMobile, displayedOperations, transferSync),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTabBar(bool isMobile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 6 : 10),
        child: Row(
          children: [
            Flexible(
              child: _buildTabButton(
                label: 'En attente',
                icon: Icons.pending_actions,
                isSelected: _selectedTab == 0,
                onTap: () {
                  if (mounted) {
                    setState(() => _selectedTab = 0);
                  }
                },
                isMobile: isMobile,
              ),
            ),
            SizedBox(width: isMobile ? 8 : 12),
            Flexible(
              child: _buildTabButton(
                label: 'Mes Validations',
                icon: Icons.check_circle,
                isSelected: _selectedTab == 1,
                onTap: () {
                  if (mounted) {
                    setState(() => _selectedTab = 1);
                  }
                },
                isMobile: isMobile,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isMobile,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(
          vertical: isMobile ? 10 : 12,
          horizontal: isMobile ? 8 : 12,
        ),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : Colors.grey[300]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey[700],
              size: isMobile ? 18 : 20,
            ),
            SizedBox(width: isMobile ? 6 : 8),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: isMobile ? 13 : 14,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(bool isMobile, TransferSyncService transferSync, int count) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.notification_important,
                color: Colors.orange[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTab == 0 
                        ? '$count en attente'
                        : '$count validée(s)',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  if (transferSync.lastSyncTime != null)
                    Text(
                      'Dernière mise à jour: ${DateFormat('HH:mm:ss').format(transferSync.lastSyncTime!)}',
                      style: TextStyle(
                        fontSize: isMobile ? 11 : 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            // Bouton pour afficher/masquer les filtres
            IconButton(
              onPressed: () {
                if (mounted) {
                  setState(() => _showFilters = !_showFilters);
                }
              },
              icon: Icon(
                _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                color: const Color(0xFFDC2626),
              ),
              tooltip: _showFilters ? 'Masquer filtres' : 'Afficher filtres',
            ),
            // Bouton de rafraîchissement manuel
            IconButton(
              onPressed: transferSync.isSyncing ? null : () => transferSync.forceRefreshFromAPI(),
              icon: transferSync.isSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              color: const Color(0xFFDC2626),
              tooltip: 'Rafraîchir depuis l\'API',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltersAndActions(bool isMobile, TransferSyncService transferSync) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Recherche par nom de destinataire
            TextField(
              decoration: InputDecoration(
                labelText: 'Rechercher par destinataire',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchDestinataire.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          if (mounted) {
                            setState(() => _searchDestinataire = '');
                          }
                        },
                      )
                    : null,
                border: const OutlineInputBorder(),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              onChanged: (value) {
                if (mounted) {
                  setState(() => _searchDestinataire = value);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransfersList(bool isMobile, List<OperationModel> transfers, TransferSyncService transferSync) {
    // Vérifier s'il y a une erreur sur la première utilisation (onglet "En attente" uniquement)
    if (_selectedTab == 0 && transfers.isEmpty && transferSync.error != null) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: isMobile ? 60 : 80,
                color: Colors.orange[400],
              ),
              const SizedBox(height: 16),
              Text(
                'Erreur de synchronisation',
                style: TextStyle(
                  fontSize: isMobile ? 16 : 18,
                  color: Colors.grey[800],
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Impossible de charger les transferts depuis le serveur',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isMobile ? 13 : 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Solutions possibles:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.orange[700],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Vérifiez votre connexion internet',
                      style: TextStyle(fontSize: isMobile ? 12 : 13),
                    ),
                    Text(
                      '• Vérifiez que le serveur API est accessible',
                      style: TextStyle(fontSize: isMobile ? 12 : 13),
                    ),
                    Text(
                      '• Réessayez en utilisant le bouton ci-dessous',
                      style: TextStyle(fontSize: isMobile ? 12 : 13),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: transferSync.isSyncing ? null : () async {
                  try {
                    await transferSync.forceRefreshFromAPI();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ Synchronisation réussie'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Erreur: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 3),
                        ),
                      );
                    }
                  }
                },
                icon: transferSync.isSyncing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(Icons.refresh),
                label: Text(transferSync.isSyncing ? 'Synchronisation...' : 'Réessayer'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Cas normal: aucune donnée (pas d'erreur)
    if (transfers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _selectedTab == 0 ? Icons.check_circle_outline : Icons.history,
              size: isMobile ? 60 : 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedTab == 0 
                  ? 'Aucun transfert en attente'
                  : 'Aucune validation effectuée',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _selectedTab == 0
                  ? 'Les transferts en attente apparaîtront ici'
                  : 'Vos validations de transferts apparaîtront ici',
              style: TextStyle(
                fontSize: isMobile ? 13 : 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => transferSync.forceRefreshFromAPI(),
      child: ListView.builder(
        itemCount: transfers.length,
        itemBuilder: (context, index) {
          final transfer = transfers[index];
          return _buildTransferCard(isMobile, transfer, transferSync);
        },
      ),
    );
  }

  Widget _buildTransferCard(bool isMobile, OperationModel transfer, TransferSyncService transferSync) {
    // Les transferts sont déjà filtrés pour être entrants, donc on peut afficher les boutons
    final isIncoming = true;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: EdgeInsets.symmetric(
        horizontal: isMobile ? 4 : 8,
        vertical: isMobile ? 8 : 10,
      ),
      child: Card(
        elevation: 5,
        shadowColor: Colors.green.withOpacity(0.3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.green.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: InkWell(
          onTap: () => _showTransferDetails(transfer, transferSync),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Colors.green.withOpacity(0.02),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isMobile ? 18 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              // En-tête: Code de l'opération
              Text(
                transfer.codeOps ?? 'N/A',
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                ),
              ),
              
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              
              // Informations du transfert
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.person, 'Destinataire', transfer.destinataire ?? 'N/A', isMobile),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.person_outline, 'Expéditeur', transfer.clientNom ?? 'N/A', isMobile),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow(Icons.calendar_today, 'Date', DateFormat('dd/MM/yyyy').format(transfer.dateOp), isMobile),
                        const SizedBox(height: 8),
                        _buildInfoRow(Icons.attach_money, 'Montant', '${transfer.montantNet.toStringAsFixed(2)} ${transfer.devise}', isMobile),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // Route: Shop source → Shop destination
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        transfer.shopSourceDesignation ?? 'N/A',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(Icons.arrow_forward, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        transfer.shopDestinationDesignation ?? 'N/A',
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Boutons d'action (seulement dans l'onglet "En attente")
              if (_selectedTab == 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _rejectTransfer(transfer, transferSync),
                        icon: const Icon(Icons.close, size: 16),
                        label: const Text('Rejeter', style: TextStyle(fontSize: 13)),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _validateTransfer(transfer, transferSync),
                        icon: const Icon(Icons.check, size: 16),
                        label: const Text('Valider', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, bool isMobile) {
    return Row(
      children: [
        Icon(icon, size: isMobile ? 14 : 16, color: Colors.grey[600]),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            '$label: $value',
            style: TextStyle(
              fontSize: isMobile ? 12 : 13,
              color: Colors.grey[700],
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showTransferDetails(OperationModel transfer, TransferSyncService transferSync) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails du transfert ${transfer.codeOps}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Code', transfer.codeOps ?? 'N/A'),
              _buildDetailRow('Type', transfer.typeLabel),
              _buildDetailRow('Date', DateFormat('dd/MM/yyyy HH:mm').format(transfer.dateOp)),
              const Divider(),
              _buildDetailRow('Destinataire', transfer.destinataire ?? 'N/A'),
              _buildDetailRow('Téléphone', transfer.telephoneDestinataire ?? 'N/A'),
              const Divider(),
              _buildDetailRow('Shop source', transfer.shopSourceDesignation ?? 'N/A'),
              _buildDetailRow('Shop destination', transfer.shopDestinationDesignation ?? 'N/A'),
              const Divider(),
              _buildDetailRow('Montant', '${transfer.montantNet.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Commission', '${transfer.commission.toStringAsFixed(2)} ${transfer.devise}'),
              _buildDetailRow('Total', '${transfer.montantBrut.toStringAsFixed(2)} ${transfer.devise}'),
              if (transfer.observation != null && transfer.observation!.isNotEmpty) ...[
                const Divider(),
                _buildDetailRow('Observation', transfer.observation!),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
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
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Future<void> _validateTransfer(OperationModel transfer, TransferSyncService transferSync) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Valider le transfert'),
        content: Text('Confirmez-vous la réception de ce transfert ?\n\nMontant: ${transfer.montantNet.toStringAsFixed(2)} ${transfer.devise}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Valider'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateTransferStatus(transfer, 'PAYE', transferSync);
    }
  }

  Future<void> _rejectTransfer(OperationModel transfer, TransferSyncService transferSync) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rejeter le transfert'),
        content: const Text('Voulez-vous vraiment rejeter ce transfert ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Rejeter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _updateTransferStatus(transfer, 'ANNULE', transferSync);
    }
  }

  Future<void> _updateTransferStatus(OperationModel transfer, String newStatus, TransferSyncService transferSync) async {
    try {
      debugPrint('🔄 [VALIDATION] Début validation: ${transfer.codeOps} → $newStatus');
      
      // Utiliser le service pour valider (server-first)
      final success = await transferSync.validateTransfer(transfer.codeOps ?? '', newStatus);
      
      if (success) {
        debugPrint('✅ [VALIDATION] Validation réussie');
        
        // Si validation réussie, imprimer automatiquement le reçu
        if (newStatus == 'PAYE' && mounted) {
          await _printValidatedTransferReceipt(transfer);
        }
        
        // Afficher le succès
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ Transfert ${newStatus == 'PAYE' ? 'validé' : 'rejeté'} avec succès'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        
        // Le service a déjà rechargé les données depuis l'API
        debugPrint('✅ [VALIDATION] Données rafraîchies automatiquement');
      } else {
        throw Exception('Échec de la validation sur le serveur');
      }
      
    } catch (e) {
      debugPrint('❌ [VALIDATION] Erreur: $e');
      
      // En cas d'erreur serveur, afficher message d'erreur clair
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '❌ Échec de la validation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Erreur: $e',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Vérifiez votre connexion et réessayez',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  // Méthode pour imprimer automatiquement le reçu de transfert validé
  Future<void> _printValidatedTransferReceipt(OperationModel transfer) async {
    try {
      debugPrint('🖨️ Impression automatique du reçu de transfert validé...');
      
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      if (currentUser == null) {
        debugPrint('⚠️ Utilisateur non connecté');
        return;
      }
      
      final shop = shopService.getShopById(currentUser.shopId ?? 0);
      if (shop == null) {
        debugPrint('⚠️ Shop introuvable');
        return;
      }
      
      // Créer l'agent model
      final agent = AgentModel(
        id: currentUser.id,
        username: currentUser.username,
        password: '',
        shopId: currentUser.shopId!,
        nom: currentUser.nom,
        telephone: currentUser.telephone,
      );
      
      // Créer une nouvelle opération pour le reçu avec toutes les données du transfert
      // IMPORTANT: Ne pas utiliser l'opération existante, créer une nouvelle avec les bonnes données
      final receiptOperation = OperationModel(
        id: transfer.id,
        type: transfer.type,
        montantBrut: transfer.montantBrut,
        commission: transfer.commission,
        montantNet: transfer.montantNet,
        devise: transfer.devise,
        clientId: transfer.clientId,
        clientNom: transfer.clientNom,
        shopSourceId: transfer.shopSourceId,
        shopSourceDesignation: transfer.shopSourceDesignation,
        shopDestinationId: transfer.shopDestinationId,
        shopDestinationDesignation: transfer.shopDestinationDesignation,
        agentId: currentUser.id ?? transfer.agentId,
        agentUsername: currentUser.username ?? transfer.agentUsername,
        codeOps: transfer.codeOps,
        destinataire: transfer.destinataire,
        telephoneDestinataire: transfer.telephoneDestinataire,
        reference: transfer.reference,
        modePaiement: transfer.modePaiement,
        statut: OperationStatus.validee,  // Statut validé
        notes: transfer.notes,
        observation: transfer.observation,
        dateOp: transfer.dateOp,
        createdAt: transfer.createdAt,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
        isSynced: transfer.isSynced,
        syncedAt: transfer.syncedAt,
      );
      
      // Utiliser AutoPrintHelper pour imprimer automatiquement
      await AutoPrintHelper.autoPrintWithDialog(
        context: context,
        operation: receiptOperation,
        shop: shop,
        agent: agent,
        clientName: transfer.observation ?? transfer.destinataire,  // Nom du destinataire
        isWithdrawalReceipt: true,  // BON DE RETRAIT pour validation de transfert
      );
      
      debugPrint('✅ Reçu de transfert validé imprimé avec succès');
    } catch (e) {
      debugPrint('❌ Erreur lors de l\'impression du reçu: $e');
      // Ne pas bloquer si l'impression échoue
    }
  }
}
