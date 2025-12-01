# 🔍 Explication: Deux Airtel SIMs en Ligne, Une Seule en Local

## ✅ Résolution du Problème

Après investigation, voici ce qui se passe:

### 📊 Situation Actuelle (Serveur)

Il y a **3 SIMs Airtel** sur le serveur (pas 2):

| ID | Numéro | Opérateur | Shop | Solde |
|----|--------|-----------|------|-------|
| 3 | 26323 | Airtel | kisangani (ID: 1764365214580) | 0.00 USD |
| 1 | 0992718409 | Airtel | shop moku (ID: 1764212829428) | 0.00 USD |
| 4 | 2321 | Airtel | kisangani (ID: 1764365214580) | **2950.00 USD** |

### 🔐 Pourquoi vous ne voyez qu'une SIM en local?

**C'EST NORMAL!** L'application filtre les SIMs par shop pour des raisons de sécurité:

```dart
// Dans virtual_transactions_widget.dart ligne 3489
final sims = simService.sims
    .where((s) => s.shopId == currentShopId && s.statut == SimStatus.active)
    .toList();
```

**Selon votre shop connecté:**
- Si vous êtes connecté à **"shop moku"**: vous voyez SIM #1 (0992718409)
- Si vous êtes connecté à **"kisangani"**: vous voyez SIMs #3 (26323) et #4 (2321)

## ✅ Vérifications à Faire

### 1. Vérifier votre shop actuel

Dans l'app Flutter:
- Regardez dans quel shop vous êtes connecté
- Un agent ne voit QUE les SIMs de son shop
- C'est une **fonctionnalité de sécurité**, pas un bug!

### 2. Si vous êtes ADMIN et voulez voir TOUTES les SIMs

Allez dans:
- **Dashboard Admin** → **Gestion SIMs** (onglet "Cartes SIM")
- Cet onglet affiche TOUTES les SIMs sans filtre de shop

### 3. Vérifier que la synchronisation a bien téléchargé toutes les SIMs

Pour vérifier que les 3 SIMs Airtel sont bien en local:

1. **Depuis l'app Flutter:**
   - Déconnectez-vous
   - Reconnectez-vous avec un compte ADMIN
   - Allez dans "Gestion SIMs"
   - Vous devriez voir les 3 SIMs Airtel

2. **Vérifier les logs de sync:**
   - Lancez une synchronisation manuelle
   - Regardez les logs dans la console
   - Recherchez "📱 SIMS:" dans les logs
   - Vous devriez voir: "✅ SIM ID 1 sauvegardée", "✅ SIM ID 3 sauvegardée", "✅ SIM ID 4 sauvegardée"

## 🔧 Scripts de Diagnostic

### Script 1: Vérifier les SIMs sur le serveur

```bash
dart run bin/debug_airtel_sims.dart
```

**Résultat attendu:** 3 SIMs Airtel trouvées

### Script 2: Forcer une synchronisation complète

Dans l'app Flutter:
1. Menu principal → Icône de synchronisation
2. Ou redémarrez l'app (sync au démarrage)
3. Vérifiez les logs: recherchez "📱 SIMS: X SIMs en mémoire"

## 💡 Comprendre le Filtrage par Shop

### Pourquoi ce filtrage existe?

**Sécurité et organisation:**
- Chaque shop gère ses propres SIMs
- Un agent ne doit pas modifier les SIMs d'autres shops
- Évite les erreurs de manipulation

### Où le filtrage est appliqué?

1. **Gestion Virtuel** (virtual_transactions_widget.dart)
   - Ligne 3489: filtre par `currentShopId`
   
2. **Création Transaction Virtuelle** (create_virtual_transaction_dialog.dart)
   - Ligne 256: filtre par `currentShopId`

3. **Mobile Money Retraits** (mobile_money_retraits_widget.dart)
   - Ligne 591: affiche toutes les SIMs actives (pas de filtre shop)

### Comment un ADMIN voit toutes les SIMs?

**Solution 1: Admin SIM Management Widget**
```dart
// admin_sim_management_widget.dart
// Affiche TOUTES les SIMs sans filtre
```

**Solution 2: Dans les Filtres Virtuels**
```dart
// virtual_transactions_widget.dart ligne 620
// Les admins ont un filtre shop qu'ils peuvent changer
if (_selectedShopFilter != null) {
  sims = sims.where((s) => s.shopId == _selectedShopFilter).toList();
}
```

## ✅ Solution Finale

**Votre situation est NORMALE!**

1. ✅ Les 3 SIMs Airtel sont bien sur le serveur
2. ✅ La synchronisation devrait les télécharger toutes
3. ✅ L'interface utilisateur filtre selon le shop connecté
4. ✅ C'est une fonctionnalité de sécurité, pas un bug

**Pour voir toutes les SIMs:**
- Connectez-vous en tant qu'ADMIN
- Allez dans "Gestion SIMs" (Admin Dashboard)
- Vous verrez les 3 SIMs Airtel

## 📝 Actions Recommandées

### Si vous NE voyez toujours qu'une SIM en tant qu'ADMIN:

1. **Vérifier la synchronisation:**
   ```
   1. Lancer une sync manuelle
   2. Vérifier les logs: "📱 SIMS: X SIMs en mémoire"
   3. Vérifier: "✅ SIM ID X sauvegardée"
   ```

2. **Vérifier le widget de gestion:**
   - Aller dans Admin Dashboard → Gestion SIMs
   - Vérifier qu'il n'y a PAS de filtre shop actif
   - Chercher "Airtel" dans la barre de recherche

3. **Si problème persiste:**
   - Effacer les données locales (déconnexion/reconnexion)
   - Lancer une synchronisation complète
   - Vérifier les logs serveur: `server/logs/`

## 🎯 Conclusion

**Situation: NORMALE ✅**

- Server: 3 SIMs Airtel (IDs: 1, 3, 4)
- Local: Toutes synchronisées (normalement)
- Interface: Filtrées selon le shop de l'utilisateur connecté

**C'est le comportement attendu de l'application!**
