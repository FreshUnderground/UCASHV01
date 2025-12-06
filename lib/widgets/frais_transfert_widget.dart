import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/rates_service.dart';
import '../services/shop_service.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';
import '../models/commission_model.dart';
import '../models/shop_model.dart';
import '../utils/shop_designation_resolver.dart';

/// Widget pour afficher la liste des frais de transfert entre shops
class FraisTransfertWidget extends StatefulWidget {
  final int? shopId; // Shop ID de l'agent connecté (pour filtrer les commissions)

  const FraisTransfertWidget({super.key, this.shopId});

  @override
  State<FraisTransfertWidget> createState() => _FraisTransfertWidgetState();
}

class _FraisTransfertWidgetState extends State<FraisTransfertWidget> {
  bool _isLoading = false;
  bool _isSyncing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Check internet connectivity
      final connectivityService = ConnectivityService.instance;
      final hasConnection = connectivityService.isOnline;

      if (hasConnection) {
        // Sync commissions and shops if online
        await Future.wait([
          RatesService.instance.loadRatesAndCommissions(),
          ShopService.instance.loadShops(),
        ]);
        debugPrint('✅ Frais et shops synchronisés');
      } else {
        // Load from local cache if offline
        await Future.wait([
          RatesService.instance.loadRatesAndCommissions(),
          ShopService.instance.loadShops(),
        ]);
        debugPrint('ℹ️ Pas de connexion - utilisation des données locales');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur lors du chargement des frais: $e');
      setState(() {
        _errorMessage = 'Erreur lors du chargement: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Synchronise les frais (commissions) depuis le serveur
  Future<void> _syncFromServer() async {
    if (_isSyncing) return;
    
    final connectivityService = ConnectivityService.instance;
    if (!connectivityService.isOnline) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 12),
                Text('Pas de connexion internet'),
              ],
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }
    
    setState(() => _isSyncing = true);
    
    try {
      debugPrint('🔄 Synchronisation des frais depuis le serveur...');
      
      // Réinitialiser le timestamp pour forcer un téléchargement complet
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('last_sync_commissions');
      debugPrint('🗑️ Timestamp commissions réinitialisé');
      
      // Télécharger les commissions depuis le serveur
      final syncService = SyncService();
      await syncService.downloadTableData('commissions', 'agent_sync', 'admin');
      
      // Recharger en mémoire
      await RatesService.instance.loadRatesAndCommissions();
      
      debugPrint('✅ ${RatesService.instance.commissions.length} commissions téléchargées');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('✅ ${RatesService.instance.commissions.length} frais synchronisés'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur sync frais: $e');
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
        setState(() => _isSyncing = false);
      }
    }
  }

  String _getShopName(int? shopId, List<ShopModel> shops) {
    if (shopId == null) return 'Tous';
    
    // Utiliser le resolver centralisé pour résoudre la désignation
    return ShopDesignationResolver.resolve(
      shopId: shopId,
      designation: null,
      shops: shops,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<RatesService, ShopService>(
      builder: (context, ratesService, shopService, child) {
        if (_isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_errorMessage != null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
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

        // Filtrer les commissions de type SORTANT qui sont spécifiques aux routes shop-to-shop
        final shopToShopCommissions = ratesService.commissions
            .where((commission) =>
                commission.type == 'SORTANT' &&
                commission.shopSourceId != null &&
                commission.shopDestinationId != null)
            .toList();

        // Trier par shop source puis par shop destination
        shopToShopCommissions.sort((a, b) {
          final sourceA = _getShopName(a.shopSourceId, shopService.shops);
          final sourceB = _getShopName(b.shopSourceId, shopService.shops);
          if (sourceA != sourceB) {
            return sourceA.compareTo(sourceB);
          }
          return _getShopName(a.shopDestinationId, shopService.shops)
              .compareTo(_getShopName(b.shopDestinationId, shopService.shops));
        });

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.percent,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bouton de rafraîchissement - Synchronise depuis le serveur
            Align(
              alignment: Alignment.centerRight,
              child: _isSyncing
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFDC2626)),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
                      onPressed: _syncFromServer,
                      tooltip: 'Synchroniser les frais depuis le serveur',
                    ),
            ),

            // Liste des frais de transfert
            if (shopToShopCommissions.isEmpty)
              const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.info_outline, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aucun frais de transfert configuré',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Les commissions shop-to-shop apparaîtront ici',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                  ],
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: shopToShopCommissions.length,
                  itemBuilder: (context, index) {
                    final commission = shopToShopCommissions[index];
                    
                    // Résoudre les désignations des shops avec fallback automatique
                    final shopSourceDesignation = ShopDesignationResolver.resolve(
                      shopId: commission.shopSourceId,
                      designation: null,
                      shops: shopService.shops,
                    );
                    
                    final shopDestinationDesignation = ShopDesignationResolver.resolve(
                      shopId: commission.shopDestinationId,
                      designation: null,
                      shops: shopService.shops,
                    );

                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      elevation: 2,
                      child: ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.swap_horiz,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        title: Text(
                          '$shopSourceDesignation → $shopDestinationDesignation',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          commission.description.isNotEmpty
                              ? commission.description
                              : 'Transfert sortant',
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF3B82F6).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${commission.taux}%',
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}