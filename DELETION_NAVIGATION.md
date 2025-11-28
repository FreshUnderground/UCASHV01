# 🔧 Navigation - Système de Suppression d'Opérations

## 📍 Emplacement des Pages

Les pages de suppression d'opérations ont été ajoutées **UNIQUEMENT dans le menu latéral** (side menu) et **PAS dans la navigation du bas** (bottom navigation), conformément aux spécifications.

---

## 👤 Pour l'Admin

### Menu Latéral Admin
L'admin a accès à **2 nouvelles pages** dans son menu latéral:

1. **Suppressions** (icône: 🗑️ `Icons.delete_outline`)
   - Permet de créer des demandes de suppression
   - Filtres avancés disponibles:
     - Type d'opération (Dépôt, Retrait, Transfert, FLOT)
     - Destinataire
     - Expéditeur/Client
     - Montant (min/max)
   - Raison de suppression (optionnelle)

2. **Corbeille** (icône: ♻️ `Icons.restore_from_trash`)
   - Voir toutes les opérations supprimées
   - Restaurer les opérations supprimées

### Ordre du Menu Admin:
```
1. Dashboard
2. Frais & Dépenses
3. Shops
4. Agents
5. Partenaires
6. Taux & Commissions
7. Rapports
8. Configuration
9. 🆕 Suppressions
10. 🆕 Corbeille
```

---

## 👨‍💼 Pour l'Agent

### Menu Latéral Agent
L'agent a accès à **1 nouvelle page** dans son menu latéral:

1. **Suppressions** (icône: 🗑️ `Icons.delete_sweep`)
   - Voir les demandes de suppression en attente
   - Approuver ou refuser les demandes
   - Badge de notification pour les demandes en attente

### Ordre du Menu Agent:
```
1. Opérations
2. Validations
3. Rapports
4. FLOT
5. Frais (menu latéral uniquement)
6. VIRTUEL (menu latéral uniquement)
7. 🆕 Suppressions (menu latéral uniquement)
```

**⚠️ IMPORTANT:** 
- Les items **Frais**, **VIRTUEL** et **Suppressions** apparaissent UNIQUEMENT dans le menu latéral
- Ils ne sont PAS présents dans la navigation du bas (bottom navigation)
- La navigation du bas ne contient que: Opérations, Validations, Rapports, FLOT

---

## 🔄 Auto-Synchronisation

Le système de suppression est **automatiquement synchronisé toutes les 2 minutes**:

- ✅ Démarrage automatique au lancement de l'app
- ✅ Synchronisation des demandes de suppression
- ✅ Synchronisation de la corbeille
- ✅ Indicateur de statut visible dans l'interface

### Vérifier le statut de synchronisation:
- Indicateur visible en bas de la page Suppressions (Admin)
- Affiche: "Auto-sync: Actif (2 min)" en vert
- Heure du dernier sync affichée

---

## 🎯 Workflow d'Utilisation

### Scénario complet:

1. **Admin** ouvre le **menu latéral** → clique sur **Suppressions**
2. Filtre et sélectionne une opération
3. Entre une raison (optionnelle)
4. Clique sur "Créer demande"
5. → Demande créée avec statut "En Attente"

6. **Agent** ouvre le **menu latéral** → clique sur **Suppressions**
7. Voit la demande en attente avec badge de notification
8. Lit les détails et la raison
9. Clique sur "Approuver" ou "Refuser"
10. → Si approuvé: Opération supprimée et placée dans la corbeille

11. **Admin** (ou autre) ouvre le **menu latéral** → clique sur **Corbeille**
12. Voit l'opération supprimée
13. Clique sur "Restaurer"
14. → Opération restaurée dans la base de données

---

## 📱 Responsive Design

### Desktop (> 1024px):
- Menu latéral toujours visible à gauche
- Accès direct aux pages Suppressions et Corbeille

### Tablette (768px - 1024px):
- Menu latéral accessible via le hamburger menu
- Même fonctionnalités que desktop

### Mobile (< 768px):
- Menu latéral accessible via le hamburger menu
- Bottom navigation affiche: Opérations, Validations, Rapports, FLOT
- **Suppressions** accessible UNIQUEMENT via menu latéral

---

## ✅ Checklist d'Intégration

- [x] Pages ajoutées au menu latéral Admin
- [x] Page ajoutée au menu latéral Agent
- [x] **PAS** ajoutées à la navigation du bas
- [x] Auto-sync activé au démarrage
- [x] Provider ajouté dans main.dart
- [x] Imports corrects dans les dashboards
- [x] Indicateur de statut visible

---

## 🔍 Vérification Rapide

Pour vérifier que tout fonctionne:

1. Lancer l'app
2. Se connecter en tant qu'Admin
3. Ouvrir le menu latéral (hamburger ou sidebar desktop)
4. Vérifier la présence de "Suppressions" et "Corbeille"
5. Cliquer sur "Suppressions" → Interface de filtres s'affiche
6. Vérifier en bas: "Auto-sync: Actif (2 min)" en vert

Pour l'agent:
1. Se connecter en tant qu'Agent
2. Ouvrir le menu latéral
3. Vérifier la présence de "Suppressions"
4. Vérifier que la navigation du bas ne contient que 4 items

---

**Date:** 28 novembre 2025  
**Modifications:** Ajout navigation menu latéral uniquement (pas bottom navigation)
