# 🚀 Quick Start - Support Bilingue

## ✅ Installation Terminée

Votre application supporte maintenant **Français 🇫🇷** et **Anglais 🇬🇧** avec persistance offline.

---

## 🎯 Usage Rapide en 3 Étapes

### 1️⃣ Importer AppLocalizations

```dart
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
```

### 2️⃣ Obtenir l'Instance dans votre Widget

```dart
@override
Widget build(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  
  return Text(l10n.welcome); // "Bienvenue" ou "Welcome"
}
```

### 3️⃣ Utiliser les Traductions

```dart
Text(l10n.dashboard)    // Tableau de bord / Dashboard
Text(l10n.operations)   // Opérations / Operations
Text(l10n.save)         // Enregistrer / Save
Text(l10n.cancel)       // Annuler / Cancel
```

---

## 🎨 Ajouter le Sélecteur de Langue

### Option A: Dans un AppBar

```dart
import '../widgets/language_selector.dart';

AppBar(
  title: Text('Mon App'),
  actions: [
    const LanguageSelector(compact: true), // 🇫🇷 ▼
  ],
)
```

### Option B: Dans une Page

```dart
import '../widgets/language_selector.dart';

// Widget complet avec cartes de sélection
const LanguageSelector()
```

### Option C: Page Complète de Paramètres

```dart
// Navigation vers la page de paramètres de langue
Navigator.pushNamed(context, '/language-settings');
```

---

## ⚙️ Changer la Langue Programmatiquement

```dart
import 'package:provider/provider.dart';
import '../services/language_service.dart';

// Obtenir le service
final languageService = context.read<LanguageService>();

// Changer vers le français
await languageService.setFrench();

// Changer vers l'anglais
await languageService.setEnglish();

// Basculer automatiquement
await languageService.toggleLanguage();
```

---

## 📋 118 Traductions Disponibles

### Connexion
`login`, `logout`, `username`, `password`, `enterUsername`, `enterPassword`

### Navigation
`dashboard`, `operations`, `clients`, `agents`, `shops`, `reports`, `settings`

### Opérations
`deposit`, `withdrawal`, `transfer`, `payment`, `amount`, `balance`, `commission`

### Actions
`search`, `filter`, `export`, `print`, `refresh`, `add`, `edit`, `delete`, `save`, `cancel`

### Statuts
`pending`, `completed`, `cancelled`, `failed`, `online`, `offline`

### Messages
`loading`, `error`, `success`, `warning`, `info`, `noData`, `retry`

### Langue
`languageSettings`, `selectLanguage`, `french`, `english`, `languageChanged`

**[Liste complète dans lib/l10n/app_en.arb et app_fr.arb]**

---

## ➕ Ajouter Vos Propres Traductions

### 1. Éditer `lib/l10n/app_en.arb`

```json
{
  "myCustomText": "My custom text in English",
  "@myCustomText": {
    "description": "My custom description"
  }
}
```

### 2. Éditer `lib/l10n/app_fr.arb`

```json
{
  "myCustomText": "Mon texte personnalisé en français"
}
```

### 3. Régénérer

```bash
flutter gen-l10n
```

### 4. Utiliser

```dart
Text(l10n.myCustomText)
```

---

## 🔥 Traductions avec Paramètres

### Définir dans app_en.arb:

```json
{
  "welcomeUser": "Welcome, {username}!",
  "@welcomeUser": {
    "placeholders": {
      "username": {"type": "String"}
    }
  }
}
```

### Définir dans app_fr.arb:

```json
{
  "welcomeUser": "Bienvenue, {username} !"
}
```

### Utiliser:

```dart
Text(l10n.welcomeUser('Marie')) // "Bienvenue, Marie !"
```

---

## 💾 Persistance Offline

✅ **Automatique** - Le choix est sauvegardé dans SharedPreferences  
✅ **Offline** - Fonctionne sans connexion Internet  
✅ **Persistant** - Survit au redémarrage de l'app  

Clé: `app_language` | Valeurs: `'fr'` ou `'en'`

---

## 🧪 Test Rapide

### Tester le Changement de Langue:

```dart
// Naviguer vers la page d'exemples
Navigator.pushNamed(context, '/bilingual-example');
```

Cette page contient:
- Affichage de la langue actuelle
- Exemples de traductions
- Sélecteur de langue complet
- Boutons de changement programmatique
- Informations techniques

---

## 🌐 Routes Disponibles

| Route | Page |
|-------|------|
| `/language-settings` | Page de paramètres de langue |
| `/bilingual-example` | Page d'exemples et démonstrations |

---

## 🎯 Exemple Complet

```dart
import 'package:flutter/material.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import '../widgets/language_selector.dart';

class MyPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          const LanguageSelector(compact: true),
        ],
      ),
      body: Column(
        children: [
          Text(l10n.welcome),
          Text(l10n.dashboard),
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

---

## 📚 Documentation Complète

- **Guide d'installation:** `BILINGUAL_SETUP_GUIDE.md`
- **Résumé:** `BILINGUAL_INSTALLATION_SUMMARY.md`
- **Code source:**
  - Service: `lib/services/language_service.dart`
  - Widget: `lib/widgets/language_selector.dart`
  - Traductions: `lib/l10n/app_en.arb`, `lib/l10n/app_fr.arb`

---

## ⚡ Commandes Utiles

```bash
# Installer les dépendances
flutter pub get

# Générer les traductions
flutter gen-l10n

# Analyser le code
flutter analyze

# Lancer l'app
flutter run
```

---

## 🎉 C'est Tout!

Votre application est maintenant **100% bilingue** avec support offline.

**Langues:** Français 🇫🇷 | English 🇬🇧  
**Traductions:** 118+ chaînes prêtes à l'emploi  
**Persistance:** Offline via SharedPreferences  
**Status:** ✅ Production-Ready
