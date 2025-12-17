import 'package:flutter/material.dart';
import '../services/currency_service.dart';

/// Dialog pour gérer le taux de change CDF/USD
class CurrencyRateDialog extends StatefulWidget {
  const CurrencyRateDialog({super.key});

  @override
  State<CurrencyRateDialog> createState() => _CurrencyRateDialogState();
}

class _CurrencyRateDialogState extends State<CurrencyRateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tauxController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentRate();
  }

  @override
  void dispose() {
    _tauxController.dispose();
    super.dispose();
  }

  void _loadCurrentRate() {
    final currentRate = CurrencyService.instance.tauxCdfToUsd;
    _tauxController.text = currentRate.toStringAsFixed(0);
  }

  Future<void> _updateRate() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final nouveauTaux = double.parse(_tauxController.text);
      final success = await CurrencyService.instance.updateTauxChange(nouveauTaux);

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Taux mis à jour: 1 USD = ${nouveauTaux.toStringAsFixed(0)} CDF'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ${CurrencyService.instance.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.currency_exchange, color: Color(0xFF48bb78)),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Taux de Change',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Information actuelle
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Taux actuel:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '1 USD = ${CurrencyService.instance.tauxCdfToUsd.toStringAsFixed(0)} CDF',
                        style: const TextStyle(fontSize: 16, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Nouveau taux
                TextFormField(
                  controller: _tauxController,
                  decoration: const InputDecoration(
                    labelText: 'Nouveau taux (CDF pour 1 USD) *',
                    hintText: '2500',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.monetization_on),
                    suffixText: 'CDF',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le taux est requis';
                    }
                    final taux = double.tryParse(value);
                    if (taux == null || taux <= 0) {
                      return 'Taux invalide';
                    }
                    if (taux < 100 || taux > 10000) {
                      return 'Taux doit être entre 100 et 10000';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Exemple de conversion
                if (_tauxController.text.isNotEmpty && double.tryParse(_tauxController.text) != null)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Exemples de conversion:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('100 USD = ${(double.tryParse(_tauxController.text) ?? 0 * 100).toStringAsFixed(0)} CDF'),
                        Text('50,000 CDF = \$${(50000 / (double.tryParse(_tauxController.text) ?? 1)).toStringAsFixed(2)} USD'),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                
                // Boutons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateRate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF48bb78),
                          foregroundColor: Colors.white,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Mettre à jour'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
