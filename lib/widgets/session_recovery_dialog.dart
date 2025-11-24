import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../utils/session_utils.dart';

class SessionRecoveryDialog extends StatefulWidget {
  final String message;
  final VoidCallback onRecoveryComplete;

  const SessionRecoveryDialog({
    Key? key,
    required this.message,
    required this.onRecoveryComplete,
  }) : super(key: key);

  @override
  State<SessionRecoveryDialog> createState() => _SessionRecoveryDialogState();
}

class _SessionRecoveryDialogState extends State<SessionRecoveryDialog> {
  bool _isRecovering = false;
  String _statusMessage = '';

  Future<void> _attemptRecovery() async {
    if (_isRecovering) return;

    setState(() {
      _isRecovering = true;
      _statusMessage = 'Tentative de récupération de la session...';
    });

    try {
      // Effacer toutes les données de session
      await SessionUtils.clearAllSessionData();
      
      // Déconnecter l'utilisateur
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.logout();
      
      setState(() {
        _statusMessage = 'Session récupérée avec succès. Veuillez vous reconnecter.';
      });
      
      // Attendre un peu pour que l'utilisateur voie le message
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pop();
        widget.onRecoveryComplete();
      }
    } catch (e) {
      setState(() {
        _statusMessage = 'Échec de la récupération: $e';
        _isRecovering = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Problème de Session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.message),
          const SizedBox(height: 16),
          if (_isRecovering)
            const Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Traitement en cours...'),
              ],
            )
          else
            Text(_statusMessage, style: const TextStyle(fontStyle: FontStyle.italic)),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isRecovering ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isRecovering ? null : _attemptRecovery,
          child: const Text('Récupérer la Session'),
        ),
      ],
    );
  }
}

// Fonction utilitaire pour afficher le dialogue de récupération
Future<void> showSessionRecoveryDialog(
  BuildContext context,
  String message,
  VoidCallback onRecoveryComplete,
) async {
  await showDialog(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext context) {
      return SessionRecoveryDialog(
        message: message,
        onRecoveryComplete: onRecoveryComplete,
      );
    },
  );
}