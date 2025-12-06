import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../models/flot_model.dart' as flot_model;
import '../models/operation_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../services/flot_service.dart';
import '../services/flot_notification_service.dart';
import '../services/transfer_sync_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../services/local_db.dart';
import 'flot_dialog.dart';
import '../utils/responsive_utils.dart';
import 'package:intl/intl.dart';

/// Widget pour gérer les FLOTS (approvisionnement de liquidité entre shops)
class FlotManagementWidget extends StatefulWidget {
  const FlotManagementWidget({super.key});

  @override
  State<FlotManagementWidget> createState() => _FlotManagementWidgetState();
}

class _FlotManagementWidgetState extends State<FlotManagementWidget> {
  flot_model.StatutFlot? _filtreStatut;
  bool _isInitialized = false;
  Timer? _autoRefreshTimer;
  int _selectedTab = 0; // 0 = En attente, 1 = Mes Validations, 2 = Mes FLOTs
  FlotNotificationService? _flotNotificationService;

  @override
  void initState() {
    super.initState();
    _initializeService();
  }
  
  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _flotNotificationService?.stopMonitoring();
    _flotNotificationService?.onNewFlotDetected = null; // Clear callback
    super.dispose();
  }
  
  Future<void> _initializeService() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final operationService = Provider.of<OperationService>(context, listen: false);
    final shopId = authService.currentUser?.shopId ?? 0;
    
    if (shopId > 0) {
      try {
        // Charger les opérations du shop
        debugPrint('📥 [FLOT-INIT] Chargement des opérations du shop $shopId...');
        await operationService.loadOperations(shopId: shopId);
        debugPrint('✅ [FLOT-INIT] ${operationService.operations.length} opérations chargées');
        
        // Initialiser le service de transferts (inclut les FLOTs)
        final transferSync = Provider.of<TransferSyncService>(context, listen: false);
        await transferSync.initialize(shopId);
        
        // Forcer un refresh immédiat depuis l'API
        try {
          await transferSync.forceRefreshFromAPI();
        } catch (e) {
          debugPrint('⚠️ [FLOT-INIT] Première synchronisation échouée: $e');
        }
        
        // Démarrer le rafraîchissement automatique toutes les 5 minutes
        _startAutoRefresh(transferSync);
        
        // Démarrer les notifications pour les FLOTs entrants
        _startFlotNotifications(authService, operationService);
        
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      } catch (e) {
        debugPrint('❌ [FLOT-INIT] Erreur d\'initialisation: $e');
        if (mounted) {
          setState(() => _isInitialized = true);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    }
  }
  
  void _startAutoRefresh(TransferSyncService transferSync) {
    _autoRefreshTimer?.cancel();
    
    _autoRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted && !transferSync.isSyncing) {
        debugPrint('⏰ [FLOT-AUTO-REFRESH] Rafraîchissement automatique depuis l\'API...');
        transferSync.forceRefreshFromAPI();
      }
    });
    
    debugPrint('✅ [FLOT-AUTO-REFRESH] Timer démarré (5 minutes)');
  }
  
  void _startFlotNotifications(AuthService authService, OperationService operationService) {
    _flotNotificationService = FlotNotificationService();
    final flotService = FlotService.instance;
    
    // Listen for changes in the FlotNotificationService
    _flotNotificationService!.addListener(() {
      // Force a refresh of the UI when the FlotNotificationService updates
      if (mounted) {
        setState(() {});
      }
    });
    
    // Démarrer la surveillance avec startMonitoring (maintenant compatible avec AuthService)
    _flotNotificationService!.startMonitoring(
      shopId: authService.currentUser?.shopId ?? 0,
      getFlots: () => flotService.flots,
    );
    
    // Démarrer la surveillance avec un callback pour afficher les notifications
    _flotNotificationService!.onNewFlotDetected = (title, message, flotId) {
      // CRITICAL: Check if widget is still mounted before accessing context
      if (!mounted) {
        debugPrint('⚠️ [FLOT-NOTIF] Widget disposed, ignoring notification');
        return;
      }
      
      // Force a refresh of the UI when a new FLOT is detected
      if (mounted) {
        setState(() {});
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 4),
              Text(message),
            ],
          ),
          backgroundColor: Colors.purple.shade700,
          duration: const Duration(seconds: 8),
          action: SnackBarAction(
            label: 'VOIR',
            textColor: Colors.white,
            onPressed: () {
              // Basculer sur l'onglet "En attente"
              if (mounted) {
                setState(() => _selectedTab = 0);
              }
            },
          ),
        ),
      );
    };
    
    debugPrint('✅ [FLOT-NOTIF] Surveillance des notifications FLOT démarrée');
  }

  Future<void> _chargerFlots() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final userRole = authService.currentUser?.role;
    final isAdmin = userRole == 'ADMIN' || userRole == 'admin';
    
    debugPrint('🔄 Chargement des FLOTs - ShopID: $shopId, Role: $userRole, isAdmin: $isAdmin');
    debugPrint('   Current User: ${authService.currentUser?.username}');
    
    await FlotService.instance.loadFlots(shopId: shopId, isAdmin: isAdmin);
    
    final flotService = Provider.of<FlotService>(context, listen: false);
    debugPrint('✅ FLOTs chargés: ${flotService.flots.length} total');
    
    // Debug: Afficher tous les FLOTs en détail
    for (var flot in flotService.flots) {
      debugPrint('   FLOT: ${flot.reference ?? flot.codeOps} - Source: ${flot.shopSourceId}, Dest: ${flot.shopDestinationId}, Statut: ${flot.statutLabel}');
    }
    
    if (shopId != null && !isAdmin) {
      final mesFlots = flotService.flots.where((f) => 
        f.shopSourceId == shopId || f.shopDestinationId == shopId
      ).toList();
      debugPrint('   → Mes FLOTs (filtrés): ${mesFlots.length}');
      
      final flotsEnCours = mesFlots.where((f) => f.statut == OperationStatus.enAttente).toList();
      debugPrint('   → En cours: ${flotsEnCours.length}');
      
      final flotsServis = mesFlots.where((f) => f.statut == OperationStatus.validee).toList();
      debugPrint('   → Servis: ${flotsServis.length}');
      
      final flotsAnnules = mesFlots.where((f) => f.statut == OperationStatus.annulee).toList();
      debugPrint('   → Annulés: ${flotsAnnules.length}');
    }
    
    // Force UI refresh
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    
    if (!_isInitialized) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gestion des FLOT')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return Consumer<TransferSyncService>(
      builder: (context, transferSync, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final operationService = Provider.of<OperationService>(context, listen: false);
        final shopId = authService.currentUser?.shopId ?? 0;
        
        debugPrint('🔄 [FLOT-WIDGET] Build called with shopId: $shopId');
        debugPrint('   Selected tab: $_selectedTab');
        debugPrint('   TransferSync pending count: ${transferSync.pendingCount}');
        
        // Déterminer les FLOTs à afficher selon l'onglet
        List<OperationModel> displayedFlots;
        
        if (_selectedTab == 0) {
          // Onglet 1: FLOTs EN ATTENTE que je dois servir (destination = moi)
          // Utiliser la méthode spécifique pour les FLOTs
          displayedFlots = transferSync.getPendingFlotsForShop(shopId);
          
          debugPrint('🔍 [FLOT] Onglet En Attente: ${displayedFlots.length} FLOTs');
        } else if (_selectedTab == 1) {
          // Onglet 2: MES VALIDATIONS (FLOTs que j'ai validés, destination = moi)
          displayedFlots = operationService.operations.where((op) {
            // Uniquement les FLOTs
            if (op.type != OperationType.flotShopToShop) return false;
            
            // FLOTs validés/terminés
            final isValidated = op.statut == OperationStatus.validee || 
                op.statut == OperationStatus.terminee;
            // Validés dans ce shop (destination = shop qui reçoit et valide)
            final isForThisShop = op.shopDestinationId == shopId;
            
            return isValidated && isForThisShop;
          }).toList();
          
          // Trier par date de modification (plus récents en premier)
          displayedFlots.sort((a, b) => 
            (b.lastModifiedAt ?? b.dateOp).compareTo(a.lastModifiedAt ?? a.dateOp)
          );
          
          debugPrint('🔍 [FLOT] Onglet Mes Validations: ${displayedFlots.length} FLOTs');
        } else {
          // Onglet 3: MES FLOTs (FLOTs que j'ai initiés, source = moi)
          displayedFlots = operationService.operations.where((op) {
            // Uniquement les FLOTs
            if (op.type != OperationType.flotShopToShop) return false;
            
            // FLOTs initiés par ce shop (source = moi)
            final isMyFlot = op.shopSourceId == shopId;
            
            return isMyFlot;
          }).toList();
          
          // Trier par date de création (plus récents en premier)
          displayedFlots.sort((a, b) => b.dateOp.compareTo(a.dateOp));
          
          debugPrint('🔍 [FLOT] Onglet Mes FLOTs: ${displayedFlots.length} FLOTs');
        }
        
        // Appliquer le filtre de statut si sélectionné
        if (_filtreStatut != null) {
          displayedFlots = displayedFlots.where((flot) {
            if (_filtreStatut == flot_model.StatutFlot.enRoute) {
              return flot.statut == OperationStatus.enAttente;
            } else if (_filtreStatut == flot_model.StatutFlot.servi) {
              return flot.statut == OperationStatus.validee || flot.statut == OperationStatus.terminee;
            } else if (_filtreStatut == flot_model.StatutFlot.annule) {
              return flot.statut == OperationStatus.annulee;
            }
            return false;
          }).toList();
          
          debugPrint('🔍 [FLOT] Après filtrage par statut: ${displayedFlots.length} FLOTs');
        }
        
        // Obtenir le nombre de FLOTs en attente depuis TransferSyncService
        final pendingFlotsCount = transferSync.getPendingFlotsForShop(shopId).length;
        
        debugPrint('📊 [FLOT-WIDGET] Final display: ${displayedFlots.length} FLOTs, pending count: $pendingFlotsCount');

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          body: Padding(
            padding: EdgeInsets.all(isMobile ? 2 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Onglets pour basculer entre En attente et Mes Validations
                _buildTabBar(isMobile, pendingFlotsCount),
                
                SizedBox(height: isMobile ? 4 : 16),
                
                // Compteur de FLOTs
                _buildStatusBar(isMobile, transferSync, displayedFlots.length),
                
                SizedBox(height: isMobile ? 4 : 20),
                
                // Liste des FLOTs
                Expanded(
                  child: displayedFlots.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              _selectedTab == 0 
                                ? 'Aucun FLOT en attente' 
                                : _selectedTab == 1
                                  ? 'Aucun FLOT à valider'
                                  : 'Aucun de mes FLOTs',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: displayedFlots.length,
                        itemBuilder: (context, index) => _buildFlotCard(displayedFlots[index]),
                      ),
                ),
              ],
            ),
          ),
          floatingActionButton: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.purple.shade600, Colors.blue.shade500],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.purple.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton.extended(
              onPressed: () => _afficherDialogueNouveauFlot(),
              backgroundColor: Colors.transparent,
              elevation: 0,
              icon: const Icon(Icons.add_rounded, size: 24),
              label: Text(
                isMobile ? 'Nouveau' : 'Nouveau FLOT',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _buildTabBar(bool isMobile, int pendingFlotsCount) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 6 : 10),
        child: Row(
          children: [
            // Onglet 1: En attente
            Expanded(
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
            // Onglet 2: Validation
            Expanded(
              child: _buildTabButton(
                label: 'Validation',
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
            SizedBox(width: isMobile ? 8 : 12),
            // Onglet 3: Mes Flots
            Expanded(
              child: _buildTabButton(
                label: 'Mes Flots',
                icon: Icons.send,
                isSelected: _selectedTab == 2,
                onTap: () {
                  if (mounted) {
                    setState(() => _selectedTab = 2);
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
    int? badgeCount,
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
          color: isSelected ? Colors.purple.shade600 : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.purple.shade600 : Colors.grey[300]!,
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
            if (badgeCount != null && badgeCount > 0) ...[
              SizedBox(width: isMobile ? 4 : 6),
              Container(
                padding: EdgeInsets.all(isMobile ? 4 : 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.orange,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.purple.shade600 : Colors.orange.shade700,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                constraints: BoxConstraints(
                  minWidth: isMobile ? 18 : 24,
                  minHeight: isMobile ? 18 : 24,
                ),
                child: Center(
                  child: Text(
                    badgeCount.toString(),
                    style: TextStyle(
                      color: isSelected ? Colors.purple.shade600 : Colors.white,
                      fontSize: isMobile ? 11 : 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBar(bool isMobile, TransferSyncService transferSync, int count) {
    // Get the pending FLOT count for display
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    int pendingFlotsCount = 0;
    
    if (currentShopId != null) {
      pendingFlotsCount = transferSync.getPendingFlotsForShop(currentShopId).length;
    }
    
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
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.local_shipping,
                color: Colors.purple[700],
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _selectedTab == 0 
                        ? '$count FLOT(s) en attente'
                        : _selectedTab == 1
                          ? '$count FLOT(s) à valider'
                          : '$count de mes FLOTs',
                    style: TextStyle(
                      fontSize: isMobile ? 15 : 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[800],
                    ),
                  ),
                  // Add specific pending count information
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
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    
    if (currentShopId == null) return const SizedBox.shrink();
    
    return FutureBuilder<List<RetraitVirtuelModel>>(
      future: LocalDB.instance.getAllRetraitsVirtuels(shopSourceId: currentShopId),
      builder: (context, retraitsSnapshot) {
        return Consumer4<FlotService, AuthService, ShopService, OperationService>(
          builder: (context, flotService, authService, shopService, operationService, child) {
            if (currentShopId == null) return const SizedBox.shrink();
            
            final currentShop = shopService.getShopById(currentShopId);
            if (currentShop == null) return const SizedBox.shrink();
            
            // NOUVELLE LOGIQUE: Calculer les dettes et créances inter-shop
            final Map<int, double> soldesParShop = {};
            
            // 1. TRANSFERTS SERVIS PAR NOUS (shop source nous doit le montant BRUT)
            for (final op in operationService.operations) {
              if ((op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalEntrant) &&
                  op.shopDestinationId == currentShopId && // Nous servons le client
                  op.devise == 'USD') {
                final autreShopId = op.shopSourceId; // Shop qui a reçu l'argent du client
                if (autreShopId != null) {
                  // IMPORTANT: Montant BRUT (montantNet + commission)
                  soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + op.montantBrut;
                }
              }
            }
            
            // 2. TRANSFERTS REÇUS/INITIÉS PAR NOUS (on doit le montant BRUT à l'autre shop)
            for (final op in operationService.operations) {
              if ((op.type == OperationType.transfertNational || op.type == OperationType.transfertInternationalSortant) &&
                  op.shopSourceId == currentShopId && // Client nous a payé
                  op.devise == 'USD') {
                final autreShopId = op.shopDestinationId; // Shop qui va servir
                if (autreShopId != null) {
                  // IMPORTANT: Montant BRUT (montantNet + commission)
                  soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - op.montantBrut;
                }
              }
            }
            
            // 2.5 NOUVEAU: FLOTS EN ATTENTE (Autres shops Nous qui Doivent)
            if (retraitsSnapshot.hasData) {
              final retraitsVirtuels = retraitsSnapshot.data!;
              for (final retrait in retraitsVirtuels) {
                if (retrait.statut == RetraitVirtuelStatus.enAttente) {
                  // Le shop débiteur nous doit ce montant
                  soldesParShop[retrait.shopDebiteurId] = (soldesParShop[retrait.shopDebiteurId] ?? 0.0) + retrait.montant;
                }
              }
            }
            
            // 3. FLOTS EN COURS - Deux sens selon qui a initié
            for (final flot in flotService.flots) {
              if (flot.statut == OperationStatus.enAttente && flot.devise == 'USD') {
                if (flot.shopSourceId == currentShopId) {
                  // NOUS avons envoyé en cours → Ils Nous qui Doivent rembourser
                  final autreShopId = flot.shopDestinationId;
                  if (autreShopId != null) {
                    soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
                  }
                } else if (flot.shopDestinationId == currentShopId) {
                  // ILS ont envoyé en cours → On leur doit rembourser
                  final autreShopId = flot.shopSourceId;
                  if (autreShopId != null) {
                    soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
                  }
                }
              }
            }
            
            // 4. FLOTS REÇUS ET SERVIS (shopDestinationId = nous) → On leur doit rembourser
            for (final flot in flotService.flots) {
              if (flot.shopDestinationId == currentShopId &&
                  flot.statut == OperationStatus.validee &&
                  flot.devise == 'USD') {
                final autreShopId = flot.shopSourceId;
                if (autreShopId != null) {
                  soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
                }
              }
            }
            
            // 5. FLOTS ENVOYÉS ET SERVIS (shopSourceId = nous) → Ils Nous qui Doivent rembourser
            for (final flot in flotService.flots) {
              if (flot.shopSourceId == currentShopId &&
                  flot.statut == OperationStatus.validee &&
                  flot.devise == 'USD') {
                final autreShopId = flot.shopDestinationId;
                if (autreShopId != null) {
                  soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
                }
              }
            }
            
            // Calculer les totaux
            double totalCreance = 0.0; // Ils Nous qui Doivent (solde > 0)
            double totalDette = 0.0;   // On leur doit (solde < 0)
            
            for (final solde in soldesParShop.values) {
              if (solde > 0) {
                totalCreance += solde;
              } else if (solde < 0) {
                totalDette += solde.abs();
              }
            }
            
            return Card(
              margin: EdgeInsets.all(ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              elevation: ResponsiveUtils.getFluidSpacing(context, mobile: 2, tablet: 3, desktop: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
                ),
              ),
              child: Padding(
                padding: ResponsiveUtils.getFluidPadding(
                  context,
                  mobile: const EdgeInsets.all(16),
                  tablet: const EdgeInsets.all(20),
                  desktop: const EdgeInsets.all(24),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📊 Votre Position Financière',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 20, desktop: 22),
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    // Add prominent pending FLOT count display
                    FutureBuilder<TransferSyncService>(
                      future: Future.value(Provider.of<TransferSyncService>(context, listen: false)),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) return const SizedBox.shrink();
                        
                        final transferSync = snapshot.data!;
                        final authService = Provider.of<AuthService>(context, listen: false);
                        final currentShopId = authService.currentUser?.shopId;
                        int pendingFlotsCount = 0;
                        
                        if (currentShopId != null) {
                          pendingFlotsCount = transferSync.getPendingFlotsForShop(currentShopId).length;
                        }
                        
                        if (pendingFlotsCount > 0) {
                          return Container(
                            margin: const EdgeInsets.only(top: 8, bottom: 4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.orange.withOpacity(0.4)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.notification_important,
                                  color: Colors.orange[700],
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '$pendingFlotsCount FLOT(s) en attente de traitement',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 16, tablet: 18, desktop: 20)),
                    if (context.isSmallScreen)
                      Column(
                        children: [
                          _buildFinancialCard(
                            title: 'Vous devez',
                            amount: totalDette,
                            color: Colors.red,
                            icon: Icons.arrow_upward,
                          ),
                          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          _buildFinancialCard(
                            title: 'On vous doit',
                            amount: totalCreance,
                            color: Colors.green,
                            icon: Icons.arrow_downward,
                          ),
                          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          _buildFinancialCard(
                            title: 'Solde net',
                            amount: totalCreance - totalDette,
                            color: (totalCreance - totalDette) >= 0 ? Colors.blue : Colors.orange,
                            icon: Icons.account_balance,
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: _buildFinancialCard(
                              title: 'Vous devez',
                              amount: totalDette,
                              color: Colors.red,
                              icon: Icons.arrow_upward,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          Expanded(
                            child: _buildFinancialCard(
                              title: 'On vous doit',
                              amount: totalCreance,
                              color: Colors.green,
                              icon: Icons.arrow_downward,
                            ),
                          ),
                          SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                          Expanded(
                            child: _buildFinancialCard(
                              title: 'Solde net',
                              amount: totalCreance - totalDette,
                              color: (totalCreance - totalDette) >= 0 ? Colors.blue : Colors.orange,
                              icon: Icons.account_balance,
                            ),
                          ),
                        ],
                      ),
                    SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                    Container(
                      padding: ResponsiveUtils.getFluidPadding(
                        context,
                        mobile: const EdgeInsets.all(12),
                        tablet: const EdgeInsets.all(14),
                        desktop: const EdgeInsets.all(16),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 14, desktop: 16),
                        ),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info, 
                            color: Colors.blue, 
                            size: ResponsiveUtils.getFluidIconSize(context, mobile: 16, tablet: 18, desktop: 20),
                          ),
                          SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 8, tablet: 10, desktop: 12)),
                          Expanded(
                            child: Text(
                              'ℹ️ Les approvisionnements (FLOT) réduisent vos dettes envers d\'autres shops',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
  
  Widget _buildFinancialCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlotCard(OperationModel flot) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopService = Provider.of<ShopService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId ?? 0;
    
    // Determine if we are the source or destination
    final bool isSource = flot.shopSourceId == currentShopId;
    final bool isDestination = flot.shopDestinationId == currentShopId;
    
    // Determine status color
    final Color statusColor = flot.statut == OperationStatus.enAttente 
        ? Colors.orange 
        : flot.statut == OperationStatus.validee 
            ? Colors.green 
            : Colors.grey;
    
    // Get shop names
    String sourceShopName = 'Shop #${flot.shopSourceId}';
    String destinationShopName = 'Shop #${flot.shopDestinationId}';
    
    // Safely get shop source ID
    if (flot.shopSourceId != null) {
      try {
        final sourceShop = shopService.getShopById(flot.shopSourceId!);
        if (sourceShop != null) {
          sourceShopName = sourceShop.designation;
        }
      } catch (e) {
        // Use default name
      }
    }
    
    // Safely get shop destination ID
    if (flot.shopDestinationId != null) {
      try {
        final destinationShop = shopService.getShopById(flot.shopDestinationId!);
        if (destinationShop != null) {
          destinationShopName = destinationShop.designation;
        }
      } catch (e) {
        // Use default name
      }
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // Show FLOT details dialog
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Détails FLOT - ${flot.reference ?? flot.codeOps}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montant: \$${flot.montantNet.toStringAsFixed(2)} ${flot.devise}'),
                  Text('Expéditeur: $sourceShopName'),
                  Text('Destinataire: $destinationShopName'),
                  Text('Statut: ${flot.statut?.name ?? 'Inconnu'}'),
                  Text('Date: ${DateFormat('dd/MM/yyyy HH:mm').format(flot.dateOp)}'),
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
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isSource ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isSource ? Colors.red : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isSource 
                              ? 'FLOT ENVOYÉ à $destinationShopName'
                              : 'FLOT REÇU de $sourceShopName',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isSource ? Colors.red : Colors.green,
                          ),
                        ),
                        Text(
                          'Ref: ${flot.reference ?? flot.codeOps}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${flot.montantNet.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          flot.statut?.name ?? 'Inconnu',
                          style: TextStyle(
                            fontSize: 12,
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.calendar_today,
                    size: 14,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(flot.dateOp),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
              // Afficher les notes si présentes
              if (flot.notes != null && flot.notes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.notes,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        flot.notes!,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Bouton de validation pour les FLOTs reçus en attente
              if (isDestination && flot.statut == OperationStatus.enAttente) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _validerFlot(flot),
                    icon: const Icon(Icons.check_circle, size: 18),
                    label: const Text('Valider la réception'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Valider un FLOT reçu
  Future<void> _validerFlot(OperationModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final agentId = authService.currentUser?.id ?? 0;
    final agentUsername = authService.currentUser?.username;
    
    // Demander confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la réception'),
        content: Text(
          'Confirmez-vous la réception du FLOT de \$${flot.montantNet.toStringAsFixed(2)} ${flot.devise}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    // Valider le FLOT via FlotService
    final flotService = Provider.of<FlotService>(context, listen: false);
    final success = await flotService.marquerFlotServi(
      flotId: flot.id!,
      agentRecepteurId: agentId,
      agentRecepteurUsername: agentUsername,
    );
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ FLOT validé avec succès!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Rafraîchir les données
        final transferSync = Provider.of<TransferSyncService>(context, listen: false);
        transferSync.forceRefreshFromAPI();
        setState(() {});
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${flotService.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _afficherDialogueNouveauFlot() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    
    if (currentShopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de créer un FLOT: Shop ID non disponible')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => FlotDialog(currentShopId: currentShopId),
    ).then((result) {
      if (result == true) {
        // Refresh the data after creating a new FLOT
        final transferSync = Provider.of<TransferSyncService>(context, listen: false);
        transferSync.forceRefreshFromAPI();
        
        if (mounted) {
          setState(() {});
        }
      }
    });
  }

}
