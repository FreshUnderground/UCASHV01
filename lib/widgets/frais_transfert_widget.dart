import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';
import '../services/shop_service.dart';
import '../models/commission_model.dart';
import '../models/shop_model.dart';

/// Widget pour afficher la liste des frais de transfert entre shops
class FraisTransfertWidget extends StatefulWidget {
  final int? shopId; // Shop ID de l'agent connecté (pour filtrer les commissions)

  const FraisTransfertWidget({super.key, this.shopId});

  @override
  State<FraisTransfertWidget> createState() => _FraisTransfertWidgetState();
}

class _FraisTransfertWidgetState extends State<FraisTransfertWidget> {
  bool _isLoading = false;
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
      // Charger les commissions et les shops
      await Future.wait([
        RatesService.instance.loadRatesAndCommissions(),
        ShopService.instance.loadShops(),
      ]);
    } catch (e) {
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

  String _getShopName(int? shopId) {
    if (shopId == null) return 'Tous';
    
    final shop = ShopService.instance.getShopById(shopId);
    return shop?.designation ?? 'Shop #$shopId';
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
          final sourceA = _getShopName(a.shopSourceId);
          final sourceB = _getShopName(b.shopSourceId);
          if (sourceA != sourceB) {
            return sourceA.compareTo(sourceB);
          }
          return _getShopName(a.shopDestinationId)
              .compareTo(_getShopName(b.shopDestinationId));
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
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Frais de Transfert',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Liste des commissions entre shops',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Bouton de rafraîchissement
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadData,
                tooltip: 'Actualiser',
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
                    final shopSource =
                        shopService.getShopById(commission.shopSourceId!);
                    final shopDestination =
                        shopService.getShopById(commission.shopDestinationId!);

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
                          '${shopSource?.designation ?? 'Shop #${commission.shopSourceId}'} → ${shopDestination?.designation ?? 'Shop #${commission.shopDestinationId}'}',
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