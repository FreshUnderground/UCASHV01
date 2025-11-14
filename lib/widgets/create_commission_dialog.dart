// ignore_for_file: sort_child_properties_last, prefer_const_declarations

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';

class CreateCommissionDialog extends StatefulWidget {
  const CreateCommissionDialog({super.key});

  @override
  State<CreateCommissionDialog> createState() => _CreateCommissionDialogState();
}

class _CreateCommissionDialogState extends State<CreateCommissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _tauxController = TextEditingController();
  String _selectedType = 'SORTANT';

  final List<Map<String, String>> _types = [
    {'value': 'SORTANT', 'label': 'Sortant (depuis RDC)', 'description': 'Transferts depuis la RDC vers l\'étranger'},
    {'value': 'ENTRANT', 'label': 'Entrant (vers RDC)', 'description': 'Transferts depuis l\'étranger vers la RDC (GRATUIT)'},
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
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
              Icon(Icons.percent, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Nouvelle Commission'),
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
                    value: _selectedType,
                    decoration: InputDecoration(
                      labelText: 'Type de transaction *',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.swap_horiz),
                    ),
                    items: _types.map((type) {
                      return DropdownMenuItem(
                        value: type['value'],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              type['label']!,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              type['description']!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          _selectedType = value;
                          // Si ENTRANT, forcer le taux à 0
                          if (value == 'ENTRANT') {
                            _tauxController.text = '0';
                          }
                        });
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Le type de transaction est requis';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description *',
                      hintText: 'Ex: Commission pour transferts sortants',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.description),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'La description est requise';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  TextFormField(
                    controller: _tauxController,
                    enabled: _selectedType != 'ENTRANT', // Désactiver si ENTRANT
                    decoration: InputDecoration(
                      labelText: 'Taux de commission *',
                      hintText: _selectedType == 'ENTRANT' ? 'GRATUIT (0%)' : 'Ex: 2.5',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.trending_up),
                      suffixText: '%',
                      helperText: _selectedType == 'ENTRANT' 
                          ? 'Les transferts entrants vers la RDC sont gratuits'
                          : null,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Le taux de commission est requis';
                      }
                      final taux = double.tryParse(value);
                      if (taux == null || taux < 0) {
                        return 'Le taux doit être un nombre positif ou zéro';
                      }
                      if (taux > 100) {
                        return 'Le taux ne peut pas dépasser 100%';
                      }
                      // Validation spécifique pour ENTRANT
                      if (_selectedType == 'ENTRANT' && taux != 0) {
                        return 'Les transferts entrants doivent être gratuits (0%)';
                      }
                      return null;
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Aperçu du calcul
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1976D2).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF1976D2).withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info, color: Color(0xFF1976D2), size: 16),
                            SizedBox(width: 8),
                            Text(
                              'Exemple de calcul:',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ValueListenableBuilder(
                          valueListenable: _tauxController,
                          builder: (context, value, child) {
                            final taux = double.tryParse(_tauxController.text) ?? 0.0;
                            final montantExample = 1000.0;
                            final commission = montantExample * (taux / 100);
                            final total = montantExample + commission;
                            
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('• Montant: ${montantExample.toStringAsFixed(0)} USD'),
                                Text('• Commission (${taux.toStringAsFixed(1)}%): ${commission.toStringAsFixed(2)} USD'),
                                Text(
                                  '• Total: ${total.toStringAsFixed(2)} USD',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          },
                  ),
                        ],
                      ),
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
    
    final success = await ratesService.createCommission(
      type: _selectedType,
      taux: double.parse(_tauxController.text.trim()),
      description: _descriptionController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commission "${_getTypeLabel(_selectedType)}" créée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'ENTRANT':
        return 'Entrant (vers RDC)';
      case 'SORTANT':
        return 'Sortant (depuis RDC)';
      default:
        return type;
    }
  }
}
