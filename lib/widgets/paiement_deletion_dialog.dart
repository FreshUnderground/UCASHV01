import 'package:flutter/material.dart';
import '../services/paiement_deletion_service.dart';

/// Dialog pour confirmer et gérer la suppression des paiements
class PaiementDeletionDialog extends StatefulWidget {
  final TypePaiement typePaiement;
  final int paiementId;
  final String nomPaiement;
  final String detailsPaiement;
  final int? indexPaiementPartiel;

  const PaiementDeletionDialog({
    Key? key,
    required this.typePaiement,
    required this.paiementId,
    required this.nomPaiement,
    required this.detailsPaiement,
    this.indexPaiementPartiel,
  }) : super(key: key);

  @override
  State<PaiementDeletionDialog> createState() => _PaiementDeletionDialogState();
}

class _PaiementDeletionDialogState extends State<PaiementDeletionDialog> {
  final _motifController = TextEditingController();
  bool _isValidating = false;
  bool _isDeleting = false;
  ValidationResult? _validationResult;

  @override
  void initState() {
    super.initState();
    _validerSuppression();
  }

  @override
  void dispose() {
    _motifController.dispose();
    super.dispose();
  }

  Future<void> _validerSuppression() async {
    setState(() {
      _isValidating = true;
    });

    try {
      final result = await PaiementDeletionService.instance.peutSupprimerPaiement(
        type: widget.typePaiement,
        id: widget.paiementId,
      );

      setState(() {
        _validationResult = result;
      });
    } catch (e) {
      setState(() {
        _validationResult = ValidationResult(
          isValid: false,
          message: 'Erreur lors de la validation: $e',
        );
      });
    } finally {
      setState(() {
        _isValidating = false;
      });
    }
  }

  Future<void> _confirmerSuppression() async {
    if (_motifController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez saisir un motif de suppression'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isDeleting = true;
    });

    try {
      bool success = false;
      final motif = _motifController.text.trim();
      const utilisateur = 'Admin'; // TODO: Récupérer l'utilisateur connecté

      switch (widget.typePaiement) {
        case TypePaiement.salaire:
          success = await PaiementDeletionService.instance.supprimerSalaire(
            salaireId: widget.paiementId,
            motifSuppression: motif,
            utilisateurSuppression: utilisateur,
          );
          break;

        case TypePaiement.avance:
          success = await PaiementDeletionService.instance.supprimerAvance(
            avanceId: widget.paiementId,
            motifSuppression: motif,
            utilisateurSuppression: utilisateur,
          );
          break;

        case TypePaiement.retenue:
          success = await PaiementDeletionService.instance.supprimerRetenue(
            retenueId: widget.paiementId,
            motifSuppression: motif,
            utilisateurSuppression: utilisateur,
          );
          break;

        case TypePaiement.paiementPartiel:
          if (widget.indexPaiementPartiel != null) {
            success = await PaiementDeletionService.instance.supprimerPaiementPartiel(
              salaireId: widget.paiementId,
              indexPaiement: widget.indexPaiementPartiel!,
              motifSuppression: motif,
              utilisateurSuppression: utilisateur,
            );
          }
          break;
      }

      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_getTypePaiementLabel()} supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  String _getTypePaiementLabel() {
    switch (widget.typePaiement) {
      case TypePaiement.salaire:
        return 'Salaire';
      case TypePaiement.avance:
        return 'Avance';
      case TypePaiement.retenue:
        return 'Retenue';
      case TypePaiement.paiementPartiel:
        return 'Paiement';
    }
  }

  IconData _getTypePaiementIcon() {
    switch (widget.typePaiement) {
      case TypePaiement.salaire:
        return Icons.payments;
      case TypePaiement.avance:
        return Icons.trending_up;
      case TypePaiement.retenue:
        return Icons.remove_circle;
      case TypePaiement.paiementPartiel:
        return Icons.payment;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.delete_forever,
            color: Colors.red[700],
          ),
          const SizedBox(width: 8),
          Text('Supprimer ${_getTypePaiementLabel()}'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations sur le paiement
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _getTypePaiementIcon(),
                        color: Colors.blue[700],
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.nomPaiement,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.detailsPaiement,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Validation de la suppression
            if (_isValidating)
              const Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text('Validation en cours...'),
                ],
              )
            else if (_validationResult != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _validationResult!.isValid 
                      ? Colors.green[50] 
                      : Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _validationResult!.isValid 
                        ? Colors.green[300]! 
                        : Colors.red[300]!,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _validationResult!.isValid 
                          ? Icons.check_circle 
                          : Icons.error,
                      color: _validationResult!.isValid 
                          ? Colors.green[700] 
                          : Colors.red[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationResult!.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: _validationResult!.isValid 
                              ? Colors.green[700] 
                              : Colors.red[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Motif de suppression (seulement si la validation est OK)
            if (_validationResult?.isValid == true) ...[
              const Text(
                'Motif de suppression *',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _motifController,
                decoration: const InputDecoration(
                  hintText: 'Expliquez pourquoi vous supprimez ce paiement...',
                  border: OutlineInputBorder(),
                  helperText: 'Ce motif sera enregistré pour audit',
                ),
                maxLines: 3,
                maxLength: 200,
              ),
              const SizedBox(height: 16),

              // Avertissement
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange[300]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning,
                      color: Colors.orange[700],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Cette action est irréversible. Le paiement sera définitivement supprimé et un enregistrement d\'audit sera créé.',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.orange[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Annuler'),
        ),
        if (_validationResult?.isValid == true)
          ElevatedButton(
            onPressed: _isDeleting ? null : _confirmerSuppression,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Text('Supprimer'),
          ),
      ],
    );
  }
}

/// Fonction utilitaire pour afficher le dialog de suppression
Future<bool?> showPaiementDeletionDialog({
  required BuildContext context,
  required TypePaiement typePaiement,
  required int paiementId,
  required String nomPaiement,
  required String detailsPaiement,
  int? indexPaiementPartiel,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PaiementDeletionDialog(
      typePaiement: typePaiement,
      paiementId: paiementId,
      nomPaiement: nomPaiement,
      detailsPaiement: detailsPaiement,
      indexPaiementPartiel: indexPaiementPartiel,
    ),
  );
}
