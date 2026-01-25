import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// Widget pour afficher un bouton d'installation PWA
/// Affiche un simple message pour installer l'app manuellement
class PwaInstallButton extends StatelessWidget {
  final bool isCompact;
  final bool showIcon;

  const PwaInstallButton({
    super.key,
    this.isCompact = false,
    this.showIcon = true,
  });

  /// Affiche le dialog d'information PWA
  void _showPwaInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.install_mobile, color: Colors.red),
            SizedBox(width: 12),
            Text('Installer l\'Application'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'Installez UCASH sur votre appareil pour un accès rapide, un support hors ligne et une expérience d\'application native'),
            const SizedBox(height: 20),
            _buildFeatureItem(Icons.wifi_off, 'Travailler Hors Ligne'),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.flash_on, 'Accès Rapide'),
            const SizedBox(height: 12),
            _buildFeatureItem(Icons.smartphone, 'Comme une App Native'),
            const SizedBox(height: 20),
            const Text(
              'Pour installer:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
                '• Chrome/Edge: Cliquez sur l\'icône d\'installation dans la barre d\'adresse'),
            const Text('• Safari: Partagez > Ajouter à l\'écran d\'accueil'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.red),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ne rien afficher si pas sur le web
    if (!kIsWeb) {
      return const SizedBox.shrink();
    }

    // Affichage compact (pour mobile)
    if (isCompact) {
      return IconButton(
        icon: const Icon(Icons.install_mobile, color: Colors.red),
        onPressed: () => _showPwaInfo(context),
        tooltip: 'Installer l\'App',
      );
    }

    // Affichage normal (pour desktop/tablet)
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ElevatedButton.icon(
        onPressed: () => _showPwaInfo(context),
        icon: showIcon
            ? const Icon(Icons.install_mobile, size: 18)
            : const SizedBox.shrink(),
        label: const Text('Installer l\'App'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}
