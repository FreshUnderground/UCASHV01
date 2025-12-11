import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:ucashv01/services/language_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le service de langue
  final languageService = LanguageService.instance;
  await languageService.initialize();
  
  runApp(const TestLanguageApp());
}

class TestLanguageApp extends StatelessWidget {
  const TestLanguageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LanguageService.instance,
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'Test Language Change',
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LanguageService.supportedLocales,
            locale: context.watch<LanguageService>().currentLocale,
            home: const TestLanguagePage(),
          );
        },
      ),
    );
  }
}

class TestLanguagePage extends StatelessWidget {
  const TestLanguagePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageService = context.watch<LanguageService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageSettings),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Langue actuelle / Current Language:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(
              languageService.currentLanguageName,
              style: TextStyle(fontSize: 32, color: Colors.blue),
            ),
            SizedBox(height: 32),
            Text(
              l10n.welcome,
              style: TextStyle(fontSize: 24),
            ),
            SizedBox(height: 16),
            Text(
              l10n.dashboard,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 16),
            Text(
              l10n.operations,
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () async {
                    await languageService.setFrench();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Langue changée: ${languageService.currentLanguageName}')),
                    );
                  },
                  icon: Text('🇫🇷', style: TextStyle(fontSize: 24)),
                  label: Text('Français'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: languageService.isFrench ? Colors.blue : Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
                SizedBox(width: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    await languageService.setEnglish();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Language changed: ${languageService.currentLanguageName}')),
                    );
                  },
                  icon: Text('🇬🇧', style: TextStyle(fontSize: 24)),
                  label: Text('English'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: languageService.isEnglish ? Colors.blue : Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32),
            Card(
              margin: EdgeInsets.all(24),
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Test Translations:',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    _buildTranslationTest(l10n.save, 'save'),
                    _buildTranslationTest(l10n.cancel, 'cancel'),
                    _buildTranslationTest(l10n.confirm, 'confirm'),
                    _buildTranslationTest(l10n.error, 'error'),
                    _buildTranslationTest(l10n.success, 'success'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationTest(String translation, String key) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('$key: ', style: TextStyle(fontWeight: FontWeight.bold)),
          Text(translation, style: TextStyle(color: Colors.blue)),
        ],
      ),
    );
  }
}
