import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';

class CreateTauxDialog extends StatefulWidget {
  const CreateTauxDialog({super.key});

  @override
  State<CreateTauxDialog> createState() => _CreateTauxDialogState();
}

class _CreateTauxDialogState extends State<CreateTauxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tauxController = TextEditingController();
  String _selectedDevise = 'USD';
  String _selectedType = 'NATIONAL';

  final List<String> _devises = ['USD', 'EUR', 'GBP', 'CAD', 'CHF', 'JPY', 'AUD'];
  final List<Map<String, String>> _types = [
    {'value': 'NATIONAL', 'label': 'National'},
    {'value': 'INTERNATIONAL_ENTRANT', 'label': 'International Entrant'},
    {'value': 'INTERNATIONAL_SORTANT', 'label': 'International Sortant'},
  ];

  @override
  void dispose() {
    _tauxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<RatesService>(
      builder: (context, ratesService, child) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.currency_exchange, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Nouveau Taux'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedDevise,
                    decoration: InputDecoration(
                      labelText: 'Devise *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    items: _devises.map((devise) {
                      return DropdownMenuItem(
                        value: devise,
                        child: Text(devise),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedDevise = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'La devise est requise';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _tauxController,
                    decoration: InputDecoration(
                      labelText: 'Taux *',
                      hintText: 'Ex: 2850',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.trending_up),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le taux est requis';
                      }
                      final taux = double.tryParse(value);
                      if (taux == null || taux <= 0) {
                        return 'Le taux doit être un nombre positif';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Type *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.category),
                    ),
                    items: _types.map((type) {
                      return DropdownMenuItem(
                        value: type['value'],
                        child: Text(type['label']!),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le type est requis';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: ratesService.isLoading ? null : () {
                Navigator.of(context).pop();
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: ratesService.isLoading ? null : _handleSubmit,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              child: ratesService.isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Créer'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final ratesService = Provider.of<RatesService>(context, listen: false);
    
    final success = await ratesService.createTaux(
      devise: _selectedDevise,
      taux: double.parse(_tauxController.text.trim()),
      type: _selectedType,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Taux $_selectedDevise créé avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la création du taux'),
          backgroundColor: Colors.red,
        ),
      );
    }}}
