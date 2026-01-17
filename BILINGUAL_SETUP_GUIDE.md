# 🌐 Guide d'Installation du Support Bilingue (Français-Anglais)

## ✅ Installation Terminée

Le support bilingue Français-Anglais a été ajouté avec succès à votre application Flutter UCASH.

---

## 📁 Fichiers Créés/Modifiés

### Nouveaux Fichiers

1. **`l10n.yaml`** - Configuration de la génération de localisation
2. **`lib/l10n/app_en.arb`** - Traductions anglaises (118 chaînes)
3. **`lib/l10n/app_fr.arb`** - Traductions françaises (118 chaînes)
4. **`lib/services/language_service.dart`** - Service de gestion de langue (offline-first)
5. **`lib/widgets/language_selector.dart`** - Widget de sélection de langue
6. **`lib/pages/language_settings_page.dart`** - Page de paramètres de langue

### Fichiers Modifiés

1. **`pubspec.yaml`** - Ajout de `flutter_localizations` et `generate: true`
2. **`lib/main.dart`** - Configuration de la localisation dans MaterialApp

---

## 🚀 Comment Utiliser

### 1. Accéder aux Traductions dans vos Widgets

```dart
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Obtenir l'instance de localisation
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard), // Se traduit automatiquement
      ),
      body: Column(
        children: [
          Text(l10n.welcome),
          Text(l10n.operations),
          ElevatedButton(
            onPressed: () {},
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }
}
```

### 2. Afficher le Sélecteur de Langue

**Option A: Widget Complet**
```dart
import '../widgets/language_selector.dart';

// Dans votre page de paramètres
const LanguageSelector()
```

**Option B: Version Compacte (pour AppBar)**
```dart
// Dans votre AppBar
actions: [
  const LanguageSelector(compact: true),
],
```

**Option C: Dialog**
```dart
import '../widgets/language_selector.dart';

// Afficher le dialog
ElevatedButton(
  onPressed: () {
    LanguageSelectorDialog.show(context);
  },
  child: Text('Changer la langue'),
)
```

### 3. Naviguer vers la Page de Paramètres

```dart
Navigator.pushNamed(context, '/language-settings');
```

### 4. Changer la Langue Programmatiquement

```dart
import 'package:provider/provider.dart';
import '../services/language_service.dart';

// Obtenir le service
final languageService = context.read<LanguageService>();

// Changer vers le français
await languageService.setFrench();

// Changer vers l'anglais
await languageService.setEnglish();

// Basculer entre les langues
await languageService.toggleLanguage();

// Obtenir la langue actuelle
String currentLang = languageService.currentLanguageName; // "Français" ou "English"
bool isFr = languageService.isFrench;
bool isEn = languageService.isEnglish;
```

---

## 📝 Ajouter de Nouvelles Traductions

### Étape 1: Ajouter dans `lib/l10n/app_en.arb`

```json
{
  "myNewKey": "My new text in English",
  "@myNewKey": {
    "description": "Description of this translation"
  }
}
```

### Étape 2: Ajouter dans `lib/l10n/app_fr.arb`

```json
{
  "myNewKey": "Mon nouveau texte en français"
}
```

### Étape 3: Régénérer les Fichiers

```bash
flutter gen-l10n
```

### Étape 4: Utiliser dans le Code

```dart
final l10n = AppLocalizations.of(context)!;
Text(l10n.myNewKey)
```

---

## 🔥 Traductions avec Paramètres

### Exemple: Traduction avec Nom d'Utilisateur

**Dans app_en.arb:**
```json
{
  "welcomeUser": "Welcome, {username}!",
  "@welcomeUser": {
    "description": "Welcome message with username",
    "placeholders": {
      "username": {
        "type": "String",
        "example": "John"
      }
    }
  }
}
```

**Dans app_fr.arb:**
```json
{
  "welcomeUser": "Bienvenue, {username} !"
}
```

**Utilisation:**
```dart
Text(l10n.welcomeUser('Marie')) // "Bienvenue, Marie !"
```

---

## 💾 Persistance Offline

Le choix de langue est **automatiquement sauvegardé** dans `SharedPreferences` et **fonctionne offline**.

```dart
// Lors de l'initialisation de l'app (déjà fait dans main.dart)
final languageService = LanguageService.instance;
await languageService.initialize(); // Charge la langue sauvegardée

// Le changement de langue sauvegarde automatiquement
await languageService.setEnglish(); // Sauvegarde "en" dans SharedPreferences
```

**Clé de stockage:** `app_language` (valeurs: `'fr'` ou `'en'`)

---

## 🌍 Langues Supportées

| Code | Langue    | Drapeau |
|------|-----------|---------|
| `fr` | Français  | 🇫🇷      |
| `en` | English   | 🇬🇧      |

---

## 📊 Chaînes de Traduction Disponibles

### Connexion & Navigation
- `login`, `logout`, `username`, `password`, `enterUsername`, `enterPassword`
- `dashboard`, `operations`, `clients`, `agents`, `shops`, `reports`, `settings`

### Opérations
- `deposit`, `withdrawal`, `transfer`, `payment`
- `amount`, `balance`, `commission`, `total`, `date`, `status`, `reference`

### Statuts
- `pending`, `completed`, `cancelled`, `failed`
- `online`, `offline`, `syncing`, `syncSuccess`, `syncFailed`

### Actions
- `search`, `filter`, `export`, `print`, `refresh`
- `add`, `edit`, `delete`, `save`, `cancel`, `confirm`

### Langue
- `languageSettings`, `selectLanguage`, `french`, `english`, `languageChanged`

### Messages
- `loading`, `noData`, `retry`, `error`, `success`, `warning`, `info`
- `yes`, `no`, `ok`

**Total: 118+ traductions prêtes à l'emploi**

---

## 🧪 Test de Validation

### Test 1: Changement de Langue Online
1. Lancer l'application
2. Naviguer vers `/language-settings`
3. Sélectionner "English"
4. Vérifier que l'interface change immédiatement
5. Fermer et relancer l'app
6. Vérifier que la langue "English" est toujours active

### Test 2: Changement de Langue Offline
1. Mettre le téléphone en mode avion ✈️
2. Ouvrir l'application
3. Changer la langue
4. Fermer et relancer l'app (toujours offline)
5. Vérifier que la langue choisie est conservée

### Test 3: Traductions dans Différentes Pages
```dart
// Vérifier que ces pages utilisent bien les traductions
- LoginPage: l10n.login, l10n.username, l10n.password
- DashboardAdminPage: l10n.adminDashboard
- DashboardAgentPage: l10n.agentDashboard
```

---

## 🔧 Migration de Code Existant

Pour migrer une page existante:

### Avant
```dart
Text('Bienvenue')
```

### Après
```dart
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';

final l10n = AppLocalizations.of(context)!;
Text(l10n.welcome)
```

---

## ⚡ Exemple Complet

```dart
import 'package:flutter/material.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../services/language_service.dart';
import '../widgets/language_selector.dart';

class MyDemoPage extends StatelessWidget {
  const MyDemoPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageService = context.watch<LanguageService>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          // Sélecteur compact dans l'AppBar
          const LanguageSelector(compact: true),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Afficher la langue actuelle
            Card(
              child: ListTile(
                leading: const Icon(Icons.language),
                title: Text(l10n.languageSettings),
                subtitle: Text(
                  '${l10n.selectLanguage}: ${languageService.currentLanguageName}',
                ),
                trailing: Text(
                  languageService.isFrench ? '🇫🇷' : '🇬🇧',
                  style: const TextStyle(fontSize: 32),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Sélecteur de langue complet
            const LanguageSelector(),
            
            const SizedBox(height: 24),
            
            // Boutons avec traductions
            Row(
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: Text(l10n.save),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () {},
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
```

---

## 🐛 Dépannage

### Erreur: "Undefined name 'AppLocalizations'"

**Solution:**
```bash
flutter clean
flutter pub get
flutter gen-l10n
```

### La langue ne change pas immédiatement

**Vérification:**
1. Assurez-vous que `LanguageService` est dans `MultiProvider`
2. Utilisez `context.watch<LanguageService>()` dans MaterialApp
3. Vérifiez que `locale` est bien défini dans MaterialApp

### Les traductions ne s'affichent pas

**Vérification:**
1. Vérifiez que les fichiers `.arb` contiennent bien la clé
2. Régénérez avec `flutter gen-l10n`
3. Importez `package:flutter_gen/gen_l10n/app_localizations.dart`

---

## 📚 Ressources

- [Flutter Internationalization Guide](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [ARB File Format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- Fichiers du projet:
  - Traductions: `lib/l10n/app_*.arb`
  - Service: `lib/services/language_service.dart`
  - Widget: `lib/widgets/language_selector.dart`

---

## ✨ Avantages

✅ **Offline-First**: La langue est sauvegardée localement  
✅ **Réactivité**: Changement instantané sans redémarrage  
✅ **Type-Safe**: Auto-complétion et vérification à la compilation  
✅ **118+ Traductions**: Prêtes à l'emploi  
✅ **Extensible**: Facile d'ajouter de nouvelles langues  
✅ **Production-Ready**: Aucun impact sur les performances  

---

## 🎯 Prochaines Étapes

1. **Migrer les pages existantes** pour utiliser `AppLocalizations`
2. **Ajouter les traductions manquantes** dans les fichiers `.arb`
3. **Tester sur différents appareils** (Android/iOS/Web)
4. **Ajouter d'autres langues** si nécessaire (ex: Lingala, Swahili)

---

**Développé pour UCASH v1.0.0**  
Support: Français 🇫🇷 | English 🇬🇧
