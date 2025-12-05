import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/operation_model.dart';
import '../services/operation_service.dart';
import '../services/auth_service.dart';

/// Dialog pour modifier une opération sur le relevé client
class EditOperationDialog extends StatefulWidget {
  final Map<String, dynamic> transaction;
  
  const EditOperationDialog({
    super.key,
    required this.transaction,
  });

  @override
  State<EditOperationDialog> createState() => _EditOperationDialogState();
}

class _EditOperationDialogState extends State<EditOperationDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _montantController;
  late TextEditingController _observationController;
  late DateTime _selectedDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _montantController = TextEditingController(
      text: (widget.transaction['montant'] as double).toString(),
    );
    _observationController = TextEditingController(
      text: widget.transaction['observation']?.toString() ?? '',
    );
    // Initialize with current date or provided date
    _selectedDate = widget.transaction['date_op'] as DateTime? ?? DateTime.now();
  }

  @override
  void dispose() {
    _montantController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.transaction['type'] as String;
    final codeOps = widget.transaction['code_ops'] as String;
    
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit, color: Colors.blue[700], size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Modifier',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Code: $codeOps',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Type d'opération (read-only)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey[600], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Type: ${_getTypeLabel(type)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Montant field
              TextFormField(
                controller: _montantController,
                decoration: InputDecoration(
                  labelText: 'Montant *',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez entrer un montant';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Montant invalide';
                  }
                  if (double.parse(value) <= 0) {
                    return 'Le montant doit être positif';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Date field
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date de l\'opération *',
                    prefixIcon: const Icon(Icons.calendar_today),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  child: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year} ${_selectedDate.hour.toString().padLeft(2, '0')}:${_selectedDate.minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Observation field
              TextFormField(
                controller: _observationController,
                decoration: InputDecoration(
                  labelText: 'Observation (Bordéreau)',
                  prefixIcon: const Icon(Icons.description_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveChanges,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text(
                              'Enregistrer',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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

  String _getTypeLabel(String type) {
    switch (type) {
      case 'depot':
        return 'Dépôt';
      case 'retrait':
        return 'Retrait';
      case 'transfertNational':
        return 'Transfert National';
      case 'transfertInternationalSortant':
        return 'Transfert International Sortant';
      case 'transfertInternationalEntrant':
        return 'Transfert International Entrant';
      default:
        return type;
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Sélectionner la date',
      cancelText: 'Annuler',
      confirmText: 'OK',
    );

    if (pickedDate != null) {
      if (!mounted) return;
      
      // Now pick time
      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDate),
        helpText: 'Sélectionner l\'heure',
        cancelText: 'Annuler',
        confirmText: 'OK',
      );

      if (pickedTime != null) {
        setState(() {
          _selectedDate = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime.hour,
            pickedTime.minute,
          );
        });
      }
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final codeOps = widget.transaction['code_ops'] as String;
      
      // Get the full operation from the service
      final operation = await operationService.getOperationByCodeOpsFromDB(codeOps);
      if (operation == null) {
        throw Exception('Opération non trouvée');
      }
      
      // Create updated operation
      final updatedOperation = operation.copyWith(
        montantNet: double.parse(_montantController.text),
        montantBrut: double.parse(_montantController.text),
        dateOp: _selectedDate,
        observation: _observationController.text.trim().isEmpty 
            ? null 
            : _observationController.text.trim(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );
      
      // Update operation using CodeOps
      final success = await operationService.updateOperationByCodeOps(updatedOperation);
      
      if (!success) {
        throw Exception('Échec de la mise à jour de l\'opération');
      }
      
      if (mounted) {
        Navigator.pop(context, true); // Return true to indicate success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Opération modifiée avec succès'),
            backgroundColor: Colors.green,
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
}
