import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/auth_service.dart';
import '../models/operation_model.dart';

/// Dialog pour rejeter une opération de retrait Mobile Money
class RejeterOperationDialog extends StatefulWidget {
  final OperationModel operation;
  
  const RejeterOperationDialog({
    super.key,
    required this.operation,
  });

  @override
  State<RejeterOperationDialog> createState() => _RejeterOperationDialogState();
}

class _RejeterOperationDialogState extends State<RejeterOperationDialog> {
  bool _isLoading = false;
  final _motifController = TextEditingController();
  String _selectedMotif = 'Capture invalide';
  
  final List<String> _motifs = [
    'Capture invalide',
    'Capture floue ou illisible',
    'Montant incorrect',
    'Numéro client incorrect',
    'Code transaction incorrect',
    'Transaction déjà servie',
    'Suspicion de fraude',
    'Autre',
  ];

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 450),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.cancel, color: Colors.red[700], size: 28),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Rejeter Opération',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Indiquer le motif du rejet',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            
            // Opération info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.operation.codeOps,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${widget.operation.montantNet.toStringAsFixed(2)} ${widget.operation.devise}',
                          style: TextStyle(color: Colors.grey[700], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Sélection du motif
            const Text(
              'MOTIF DU REJET',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _selectedMotif,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.report_problem),
              ),
              items: _motifs.map((motif) {
                return DropdownMenuItem(
                  value: motif,
                  child: Text(motif),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedMotif = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            
            // Détails supplémentaires
            TextField(
              controller: _motifController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Détails supplémentaires',
                border: OutlineInputBorder(),
                hintText: 'Expliquer le motif du rejet...',
              ),
            ),
            const SizedBox(height: 24),
            
            // Warning
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.red, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Cette action marquera l\'opération comme ANNULÉE et le client ne pourra PAS retirer le cash.',
                      style: TextStyle(fontSize: 12, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _rejeterOperation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.block),
                  label: Text(_isLoading ? 'Traitement...' : 'CONFIRMER LE REJET'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[700],
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rejeterOperation() async {
    setState(() => _isLoading = true);
    
    try {
      final operationService = Provider.of<OperationService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      final motifComplet = _selectedMotif + 
          (_motifController.text.isNotEmpty ? ' - ${_motifController.text}' : '');
      
      final updatedOperation = widget.operation.copyWith(
        statut: OperationStatus.annulee,
        observation: motifComplet,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );
      
      final success = await operationService.updateOperation(updatedOperation);
      
      if (!success) {
        throw Exception('Échec de la mise à jour de l\'opération');
      }
      
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Opération rejetée: $_selectedMotif'),
            backgroundColor: Colors.red[700],
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
