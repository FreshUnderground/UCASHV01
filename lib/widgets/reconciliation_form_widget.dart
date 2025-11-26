import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/reconciliation_model.dart';
import '../models/shop_model.dart';
import '../services/reconciliation_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';

/// Widget de formulaire de réconciliation bancaire
class ReconciliationFormWidget extends StatefulWidget {
  final int shopId;
  final VoidCallback? onSuccess;

  const ReconciliationFormWidget({
    Key? key,
    required this.shopId,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<ReconciliationFormWidget> createState() => _ReconciliationFormWidgetState();
}

class _ReconciliationFormWidgetState extends State<ReconciliationFormWidget> {
  final _formKey = GlobalKey<FormState>();
  final _cashController = TextEditingController();
  final _airtelController = TextEditingController();
  final _mpesaController = TextEditingController();
  final _orangeController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  ShopModel? _shop;

  @override
  void initState() {
    super.initState();
    _loadShop();
  }

  Future<void> _loadShop() async {
    final shopService = Provider.of<ShopService>(context, listen: false);
    final shop = shopService.shops.firstWhere((s) => s.id == widget.shopId);
    setState(() => _shop = shop);
  }

  @override
  void dispose() {
    _cashController.dispose();
    _airtelController.dispose();
    _mpesaController.dispose();
    _orangeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitReconciliation() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final reconciliationService = ReconciliationService.instance;
      final capitalReel = {
        'cash': double.tryParse(_cashController.text) ?? 0,
        'airtel': double.tryParse(_airtelController.text) ?? 0,
        'mpesa': double.tryParse(_mpesaController.text) ?? 0,
        'orange': double.tryParse(_orangeController.text) ?? 0,
      };

      final reconciliation = await reconciliationService.createReconciliation(
        shopId: widget.shopId,
        date: _selectedDate,
        capitalReel: capitalReel,
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      if (reconciliation != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Réconciliation créée: ${reconciliation.statut.name}'),
            backgroundColor: _getStatusColor(reconciliation.statut),
          ),
        );

        widget.onSuccess?.call();
        Navigator.pop(context, reconciliation);
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
      setState(() => _isLoading = false);
    }
  }

  Color _getStatusColor(ReconciliationStatut statut) {
    switch (statut) {
      case ReconciliationStatut.VALIDE:
        return Colors.green;
      case ReconciliationStatut.ECART_ACCEPTABLE:
        return Colors.blue;
      case ReconciliationStatut.ECART_ALERTE:
        return Colors.orange;
      case ReconciliationStatut.INVESTIGATION:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_shop == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nouvelle Réconciliation'),
        backgroundColor: const Color(0xFF2563EB),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Informations du shop
              _buildShopInfoCard(),
              const SizedBox(height: 24),

              // Date de réconciliation
              _buildDateSelector(),
              const SizedBox(height: 24),

              // Capital système vs réel
              const Text(
                'Comptage du Capital Réel',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              _buildCapitalComparison('CASH', _shop!.capitalCash, _cashController),
              const SizedBox(height: 12),
              _buildCapitalComparison('AIRTEL MONEY', _shop!.capitalAirtelMoney, _airtelController),
              const SizedBox(height: 12),
              _buildCapitalComparison('M-PESA', _shop!.capitalMPesa, _mpesaController),
              const SizedBox(height: 12),
              _buildCapitalComparison('ORANGE MONEY', _shop!.capitalOrangeMoney, _orangeController),
              const SizedBox(height: 24),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optionnel)',
                  hintText: 'Explications des écarts éventuels...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 32),

              // Bouton de soumission
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submitReconciliation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle),
                  label: Text(_isLoading ? 'Création...' : 'Créer la Réconciliation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShopInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.store, color: Color(0xFF2563EB), size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _shop!.designation,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Shop #${_shop!.id}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector() {
    final dateFormat = DateFormat('dd/MM/yyyy');

    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: _selectedDate,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
        );
        if (date != null) {
          setState(() => _selectedDate = date);
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFF2563EB)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date de réconciliation',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateFormat.format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCapitalComparison(String label, double capitalSysteme, TextEditingController controller) {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Système: ${capitalSysteme.toStringAsFixed(2)} USD',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Capital Réel (compté)',
                suffixText: 'USD',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Requis';
                }
                if (double.tryParse(value) == null) {
                  return 'Montant invalide';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }
}
