import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';
import '../models/taux_model.dart';
import '../models/commission_model.dart';

class RatesCommissionsReal extends StatefulWidget {
  const RatesCommissionsReal({super.key});

  @override
  State<RatesCommissionsReal> createState() => _RatesCommissionsRealState();
}

class _RatesCommissionsRealState extends State<RatesCommissionsReal> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _loadData() {
    Provider.of<RatesService>(context, listen: false).loadRatesAndCommissions();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 768;

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Taux & Commissions',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1976D2),
            ),
          ),
          const SizedBox(height: 32),
          if (isMobile)
            Column(
              children: [
                _buildRatesSection(),
                const SizedBox(height: 20),
                _buildCommissionsSection(),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildRatesSection()),
                const SizedBox(width: 20),
                Expanded(child: _buildCommissionsSection()),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildRatesSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Taux de Change',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1976D2),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddRateDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1976D2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Consumer<RatesService>(
            builder: (context, ratesService, child) {
              if (ratesService.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final taux = ratesService.taux;
              if (taux.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Aucun taux créé. Cliquez sur "Ajouter" pour créer un taux.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ...taux.map((taux) => _buildRateItem(taux)).toList(),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionsSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Commissions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE65100),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showAddCommissionDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Ajouter'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE65100),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Consumer<RatesService>(
            builder: (context, ratesService, child) {
              if (ratesService.isLoading) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              final commissions = ratesService.commissions;
              if (commissions.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'Aucune commission créée. Cliquez sur "Ajouter" pour créer une commission.',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    ...commissions.map((commission) => _buildCommissionItem(commission)).toList(),
                    const SizedBox(height: 20),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRateItem(TauxModel taux) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${taux.deviseSource} → ${taux.deviseCible}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  taux.type,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    taux.taux.toStringAsFixed(2),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF388E3C),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _editRate(taux),
                  icon: const Icon(Icons.edit, size: 14),
                  color: Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionItem(CommissionModel commission) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12, top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              commission.description,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    '${commission.taux.toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFFE65100),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => _editCommission(commission),
                  icon: const Icon(Icons.edit, size: 14),
                  color: Colors.grey[600],
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showAddRateDialog() {
    // TODO: Implémenter le dialog d'ajout de taux
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dialog d\'ajout de taux à implémenter')),
    );
  }

  void _showAddCommissionDialog() {
    // TODO: Implémenter le dialog d'ajout de commission
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dialog d\'ajout de commission à implémenter')),
    );
  }

  void _editRate(TauxModel taux) {
    // TODO: Implementer l'edition de taux
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Edition du taux ${taux.deviseSource} -> ${taux.deviseCible} a implementer')),
    );
  }

  void _editCommission(CommissionModel commission) {
    // TODO: Implémenter l'édition de commission
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Édition de la commission ${commission.description} à implémenter')),
    );
  }
}
