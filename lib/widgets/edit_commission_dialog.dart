import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/rates_service.dart';
import '../models/commission_model.dart';

class EditCommissionDialog extends StatefulWidget {
  final CommissionModel commission;
  
  const EditCommissionDialog({super.key, required this.commission});

  @override
  State<EditCommissionDialog> createState() => _EditCommissionDialogState();
}

class _EditCommissionDialogState extends State<EditCommissionDialog> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _tauxController = TextEditingController();
  late String _selectedType;

  final List<Map<String, String>> _types = [
    {'value': 'SORTANT', 'label': 'Sortant (depuis RDC)', 'description': 'Transferts depuis la RDC vers l\'étranger'},
    {'value': 'ENTRANT', 'label': 'Entrant (vers RDC)', 'description': 'Transferts depuis l\'étranger vers la RDC (GRATUIT)'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.commission.type;
    _descriptionController.text = widget.commission.description;
    _tauxController.text = widget.commission.taux.toString();
  }

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
          title: Row(
            children: [
              Icon(Icons.edit, color: Color(0xFF1976D2)),
              SizedBox(width: 8),
              Text('Modifier Commission ${_getTypeLabel(_selectedType)}'),
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
                      prefixIcon: Icon(Icons.swap_horiz),
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
                              style: TextStyle(fontWeight: FontWeight.w600),
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
                      prefixIcon: Icon(Icons.description),
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
                    enabled: _selectedType != 'ENTRANT',
                    decoration: InputDecoration(
                      labelText: 'Taux de commission *',
                      hintText: _selectedType == 'ENTRANT' ? 'GRATUIT (0%)' : 'Ex: 2.5',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.trending_up),
                      suffixText: '%',
                      helperText: _selectedType == 'ENTRANT' 
                          ? 'Les transferts entrants vers la RDC sont gratuiti (0%)'
                          : null,
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
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
                      if (_selectedType == 'ENTRANT' && taux != 0) {
                        return 'Les transferts entrants doivent être gratuiti (0%)';
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
                backgroundColor: const Color(0xFF1976D2),
                foregroundColor: Colors.white,
              ),
              child: ratesService.isLoading
                  ? SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Modifier'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final ratesService = Provider.of<RatesService>(context, listen: false);
    
    final updatedCommission = widget.commission.copyWith(
      type: _selectedType,
      taux: double.parse(_tauxController.text.trim()),
      description: _descriptionController.text.trim(),
    );
    
    final success = await ratesService.updateCommission(updatedCommission);

    if (success && mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Commission "${_getTypeLabel(_selectedType)}" modifiée avec succès!'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la modification de la commission'),
          backgroundColor: Colors.red,
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
