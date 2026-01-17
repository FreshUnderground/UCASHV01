import 'package:flutter/material.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../widgets/language_selector.dart';

/// EXEMPLE D'UTILISATION DU SYSTÈME BILINGUE
///
/// Cette page démontre toutes les façons d'utiliser le système de localisation
/// dans votre application UCASH

class BilingualUsageExamplePage extends StatelessWidget {
  const BilingualUsageExamplePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 1. OBTENIR LES TRADUCTIONS
    final l10n = AppLocalizations.of(context)!;

    // 2. OBTENIR LE SERVICE DE LANGUE
    final languageService = context.watch<LanguageService>();

    return Scaffold(
      appBar: AppBar(
        // Utiliser une traduction dans l'AppBar
        title: Text(l10n.settings),

        // Option 1: Sélecteur compact dans l'AppBar
        actions: [
          const LanguageSelector(compact: true),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== EXEMPLE 1: AFFICHER LA LANGUE ACTUELLE ==========
            _buildSectionTitle(context, 'Langue Actuelle / Current Language'),
            Card(
              child: ListTile(
                leading: const Icon(Icons.language, color: Colors.blue),
                title: Text(languageService.currentLanguageName),
                subtitle: Text(
                  'Code: ${languageService.currentLanguageCode.toUpperCase()}',
                ),
                trailing: Text(
                  languageService.isFrench ? '🇫🇷' : '🇬🇧',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ========== EXEMPLE 2: UTILISER LES TRADUCTIONS ==========
            _buildSectionTitle(
                context, 'Exemples de Traductions / Translation Examples'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTranslationRow('Bienvenue / Welcome:', l10n.welcome),
                    _buildTranslationRow('Connexion / Login:', l10n.login),
                    _buildTranslationRow(
                        'Tableau de bord / Dashboard:', l10n.dashboard),
                    _buildTranslationRow(
                        'Opérations / Operations:', l10n.operations),
                    _buildTranslationRow('Clients / Clients:', l10n.clients),
                    _buildTranslationRow('Enregistrer / Save:', l10n.save),
                    _buildTranslationRow('Annuler / Cancel:', l10n.cancel),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ========== EXEMPLE 3: SÉLECTEUR DE LANGUE COMPLET ==========
            _buildSectionTitle(
                context, 'Sélecteur de Langue / Language Selector'),
            const LanguageSelector(),

            const SizedBox(height: 24),

            // ========== EXEMPLE 4: BOUTONS AVEC TRADUCTIONS ==========
            _buildSectionTitle(context, 'Actions / Actions'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _showMessage(context, l10n.syncSuccess);
                  },
                  icon: const Icon(Icons.sync),
                  label: Text(l10n.synchronization),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    _showMessage(context, l10n.loading);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(l10n.refresh),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(context, l10n.success);
                  },
                  icon: const Icon(Icons.check_circle),
                  label: Text(l10n.save),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _showMessage(context, l10n.error);
                  },
                  icon: const Icon(Icons.cancel),
                  label: Text(l10n.cancel),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ========== EXEMPLE 5: CHANGEMENT PROGRAMMATIQUE ==========
            _buildSectionTitle(
                context, 'Changement Programmatique / Programmatic Change'),
            Card(
              color: Colors.purple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Méthodes Disponibles / Available Methods:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: 12),

                    // Bouton Français
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await languageService.setFrench();
                          if (context.mounted) {
                            _showMessage(
                                context, 'Langue changée vers le Français');
                          }
                        },
                        icon:
                            const Text('🇫🇷', style: TextStyle(fontSize: 20)),
                        label: const Text('languageService.setFrench()'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue.shade100,
                          foregroundColor: Colors.blue.shade900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bouton Anglais
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await languageService.setEnglish();
                          if (context.mounted) {
                            _showMessage(
                                context, 'Language changed to English');
                          }
                        },
                        icon:
                            const Text('🇬🇧', style: TextStyle(fontSize: 20)),
                        label: const Text('languageService.setEnglish()'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade100,
                          foregroundColor: Colors.red.shade900,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Bouton Basculer
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await languageService.toggleLanguage();
                          if (context.mounted) {
                            _showMessage(
                              context,
                              'Basculé vers / Switched to: ${languageService.currentLanguageName}',
                            );
                          }
                        },
                        icon: const Icon(Icons.swap_horiz),
                        label: const Text('languageService.toggleLanguage()'),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ========== EXEMPLE 6: DIALOG DE SÉLECTION ==========
            _buildSectionTitle(
                context, 'Dialog de Sélection / Selection Dialog'),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  LanguageSelectorDialog.show(context);
                },
                icon: const Icon(Icons.settings),
                label: Text(l10n.languageSettings),
              ),
            ),

            const SizedBox(height: 24),

            // ========== EXEMPLE 7: INFORMATIONS TECHNIQUES ==========
            _buildSectionTitle(
                context, 'Informations Techniques / Technical Info'),
            Card(
              color: Colors.green.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoRow('Locale actuelle / Current:',
                        languageService.currentLocale.toString()),
                    _buildInfoRow('Est Français / Is French:',
                        languageService.isFrench.toString()),
                    _buildInfoRow('Est Anglais / Is English:',
                        languageService.isEnglish.toString()),
                    _buildInfoRow('Code langue / Language code:',
                        languageService.currentLanguageCode),
                    _buildInfoRow('Nom langue / Language name:',
                        languageService.currentLanguageName),
                    _buildInfoRow(
                        'Stockage / Storage:', 'SharedPreferences (offline)'),
                    _buildInfoRow('Clé / Key:', 'app_language'),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade900,
            ),
      ),
    );
  }

  Widget _buildTranslationRow(String label, String translation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              translation,
              style: const TextStyle(color: Colors.blue),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontFamily: 'monospace',
                color: Colors.green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
