import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import '../services/language_service.dart';

/// Widget pour la sélection de langue
///
/// Affiche un sélecteur bilingue Français/Anglais avec:
/// - Icône de drapeau pour chaque langue
/// - Nom de la langue
/// - Indication visuelle de la langue actuellement sélectionnée
/// - Sauvegarde automatique du choix (fonctionne offline)
class LanguageSelector extends StatelessWidget {
  final bool showTitle;
  final bool compact;

  const LanguageSelector({
    Key? key,
    this.showTitle = true,
    this.compact = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final languageService = context.watch<LanguageService>();
    final l10n = AppLocalizations.of(context)!;

    if (compact) {
      return _buildCompactSelector(context, languageService);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            l10n.selectLanguage,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
        ],
        _buildLanguageOptions(context, languageService),
      ],
    );
  }

  Widget _buildCompactSelector(
      BuildContext context, LanguageService languageService) {
    return PopupMenuButton<String>(
      icon: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            languageService.isFrench ? '🇫🇷' : '🇬🇧',
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.arrow_drop_down, size: 20),
        ],
      ),
      onSelected: (String languageCode) async {
        await _changeLanguage(context, languageService, languageCode);
      },
      itemBuilder: (BuildContext context) => [
        PopupMenuItem<String>(
          value: 'fr',
          child: Row(
            children: [
              const Text('🇫🇷', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              const Text('Français'),
              if (languageService.isFrench) ...[
                const Spacer(),
                const Icon(Icons.check, color: Colors.green, size: 20),
              ],
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: 'en',
          child: Row(
            children: [
              const Text('🇬🇧', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 12),
              const Text('English'),
              if (languageService.isEnglish) ...[
                const Spacer(),
                const Icon(Icons.check, color: Colors.green, size: 20),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLanguageOptions(
      BuildContext context, LanguageService languageService) {
    return Column(
      children: [
        _buildLanguageCard(
          context,
          languageService,
          'fr',
          '🇫🇷',
          'Français',
          languageService.isFrench,
        ),
        const SizedBox(height: 12),
        _buildLanguageCard(
          context,
          languageService,
          'en',
          '🇬🇧',
          'English',
          languageService.isEnglish,
        ),
      ],
    );
  }

  Widget _buildLanguageCard(
    BuildContext context,
    LanguageService languageService,
    String languageCode,
    String flag,
    String languageName,
    bool isSelected,
  ) {
    return InkWell(
      onTap: () async {
        await _changeLanguage(context, languageService, languageCode);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? Colors.blue.shade50 : Colors.white,
        ),
        child: Row(
          children: [
            Text(
              flag,
              style: const TextStyle(fontSize: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                languageName,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? Colors.blue.shade900 : Colors.black87,
                    ),
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Colors.blue,
                size: 28,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _changeLanguage(
    BuildContext context,
    LanguageService languageService,
    String languageCode,
  ) async {
    if (languageService.currentLanguageCode == languageCode) {
      return; // Déjà sélectionné
    }

    final success = await languageService.changeLanguage(languageCode);

    if (success && context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(l10n.languageChanged),
            ],
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    } else if (!success && context.mounted) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Text(l10n.error),
            ],
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// Dialog pour la sélection de langue
class LanguageSelectorDialog extends StatelessWidget {
  const LanguageSelectorDialog({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (context) => const LanguageSelectorDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return AlertDialog(
      title: Row(
        children: [
          const Icon(Icons.language, color: Colors.blue),
          const SizedBox(width: 12),
          Text(l10n.languageSettings),
        ],
      ),
      content: const SizedBox(
        width: 300,
        child: LanguageSelector(showTitle: false),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.ok),
        ),
      ],
    );
  }
}
