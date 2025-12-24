import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'help_button_widget.dart';

class ContextualHelpWidget extends StatelessWidget {
  final String section;
  final Widget child;
  final String? helpText;
  final bool showFloatingButton;

  const ContextualHelpWidget({
    super.key,
    required this.section,
    required this.child,
    this.helpText,
    this.showFloatingButton = false,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        final contextualHelp = _getContextualHelp(section, authService.currentUser?.role ?? 'CLIENT');
        
        return Stack(
          children: [
            child,
            if (showFloatingButton)
              FloatingHelpButton(
                contextualHelp: helpText ?? contextualHelp,
              ),
          ],
        );
      },
    );
  }

  String _getContextualHelp(String section, String role) {
    final helpContent = _contextualHelpContent[role]?[section];
    return helpContent ?? _getDefaultHelp(section);
  }

  String _getDefaultHelp(String section) {
    switch (section) {
      case 'operations':
        return '''
**Guide des Opérations UCASH**

**Dépôts :**
• Bouton VERT "Dépôt"
• Sélectionner le client
• Saisir le montant et la devise
• Choisir le mode de paiement
• Aucune commission appliquée

**Retraits :**
• Bouton ORANGE "Retrait"
• Vérifier le solde client
• Saisir le montant (≤ solde disponible)
• Confirmer l'opération

**Transferts :**
• Capture d'écran obligatoire
• Commission selon le type :
  - National : Variable
  - International Sortant : 3.5%
  - International Entrant : 0%

**Important :** Toutes les opérations mettent à jour les soldes en temps réel.
''';

      case 'virtual':
        return '''
**Transactions Virtuelles UCASH**

**Système Multi-Devises :**
• Captures : Enregistrement en devise originale (USD/CDF)
• Cash disponible : Toujours affiché en USD
• Conversions automatiques selon les taux

**Gestion par SIM :**
• Chaque SIM a son solde virtuel
• Historique des transactions séparé
• Procédures de clôture quotidienne

**Opérations Principales :**
• **Captures** : Demandes clients
• **Validations** : Traitement des captures
• **Retraits** : Sortie du système virtuel
• **Dépôts** : Entrée dans le système

**Rapports :** Vue d'ensemble, par SIM, frais, clôtures
''';

      case 'reports':
        return '''
**Rapports UCASH**

**Types de Rapports :**
• Rapports quotidiens : Transactions du jour
• Rapports mensuels : Analyses de performance
• Rapports personnalisés : Filtres avancés

**Fonctionnalités :**
• Export PDF, Excel, CSV
• Filtrage par dates, montants, devises
• Statistiques en temps réel
• Graphiques et analyses

**Synchronisation :**
• Données automatiquement synchronisées
• Mode hors-ligne disponible
• Mise à jour en temps réel

**Accès :** Selon votre rôle (Admin/Agent/Client)
''';

      default:
        return '''
**Aide UCASH**

Bienvenue dans le système UCASH. Cette section fournit une aide contextuelle pour vous guider dans l'utilisation de l'application.

**Navigation :**
• Utilisez le menu latéral pour accéder aux différentes sections
• Les icônes indiquent le type de fonctionnalité
• Les notifications apparaissent en temps réel

**Support :**
• Documentation complète disponible via le bouton d'aide
• Guides spécifiques à votre rôle
• Aide contextuelle dans chaque section

Pour plus d'informations, consultez la documentation complète.
''';
    }
  }

  static const Map<String, Map<String, String>> _contextualHelpContent = {
    'ADMIN': {
      'dashboard': '''
**Tableau de Bord Administrateur**

**Vue d'ensemble :**
• Statistiques globales du système
• Nombre de shops et agents actifs
• Volume de transactions quotidiennes
• Revenus et commissions

**Actions Rapides :**
• Créer un nouveau shop
• Ajouter un agent
• Consulter les rapports
• Gérer les validations

**Surveillance :**
• Synchronisation en temps réel
• Alertes système
• Monitoring des performances

**Configuration :**
• Taux de change USD/CDF
• Commissions par type d'opération
• Paramètres système
''',

      'shops': '''
**Gestion des Shops**

**Création d'un Shop :**
1. Cliquez sur "Nouveau Shop"
2. Remplissez les informations :
   • Désignation (nom unique)
   • Adresse/localisation
   • Téléphone de contact
3. Configurez les capitaux initiaux :
   • Capital USD (obligatoire)
   • Capital CDF (optionnel)
   • Autres modes de paiement

**Gestion :**
• Modifier les informations
• Ajuster les capitaux
• Consulter les performances
• Gérer les agents assignés

**Suivi :**
• Évolution des soldes en temps réel
• Alertes de seuils bas
• Rapports de performance
''',

      'agents': '''
**Gestion des Agents**

**Création d'un Agent :**
1. Menu "Agents" → "Nouvel Agent"
2. Informations personnelles :
   • Nom et prénom
   • Téléphone de contact
3. Informations système :
   • Username unique
   • Mot de passe (min 6 caractères)
   • Shop d'assignation
   • Matricule automatique

**Matricule Automatique :**
Format : AGT[AA][MM][JJ][Shop][XXX]
• Génération automatique
• Modification possible
• Validation d'unicité

**Gestion :**
• Modifier les informations
• Changer de shop
• Activer/désactiver
• Consulter les performances
''',

      'personnel': '''
**Gestion du Personnel**

**Ajout d'Employé :**
• Informations personnelles complètes
• Poste et responsabilités
• Salaire de base et primes
• Date d'embauche

**Gestion des Salaires :**
• Calcul automatique des salaires
• Gestion des avances
• Retenues et déductions
• Historique des paiements

**Rapports :**
• Masse salariale mensuelle
• Évolution des coûts
• Statistiques du personnel
• Export des données

**Matricules :**
• Génération automatique
• Format standardisé
• Traçabilité complète
''',
    },

    'AGENT': {
      'operations': '''
**Opérations Agent**

**Dépôts (Bouton VERT) :**
1. Sélectionner le client
2. Saisir le montant et devise
3. Choisir le mode de paiement :
   • USD/CDF
   • Airtel Money, M-Pesa, Orange Money
4. Confirmer l'opération
• Aucune commission
• Mise à jour automatique des soldes

**Retraits (Bouton ORANGE) :**
1. Sélectionner le client
2. Vérifier le solde disponible
3. Saisir le montant (≤ solde)
4. Confirmer et remettre l'argent
• Validation automatique du solde
• Blocage si fonds insuffisants

**Transferts :**
• Capture d'écran obligatoire (preuve)
• Commission selon destination :
  - National : Variable selon shop
  - International Sortant : 3.5%
  - International Entrant : 0% (gratuit)
• Sélection du shop de destination
''',

      'virtual': '''
**Transactions Virtuelles Agent**

**Captures (Enregistrement) :**
• Client demande une transaction mobile money
• Enregistrer en devise originale (USD/CDF)
• Frais calculés automatiquement
• Status : En attente de validation

**Validations (Traitement) :**
• Traiter les captures en attente
• Vérifier les informations client
• Valider et servir le client
• Impact sur le cash disponible

**Gestion par SIM :**
• Chaque SIM = solde virtuel séparé
• Historique des transactions
• Clôture quotidienne obligatoire
• Rapports détaillés

**Devises :**
• Captures : Devise originale (USD/CDF)
• Cash servi : Toujours en USD
• Conversions automatiques
• Affichage "USD" vs "Mixte"
''',

      'validations': '''
**Validations Agent**

**Transferts en Attente :**
• Vérifier les captures d'écran
• Confirmer les informations
• Valider ou rejeter
• Notifier l'expéditeur

**Opérations à Valider :**
• Contrôler les montants
• Vérifier l'identité des clients
• Confirmer les modes de paiement
• Tracer toutes les actions

**Notifications :**
• Alertes en temps réel
• Nouveaux transferts entrants
• Demandes de validation
• Rappels de traitement

**Sécurité :**
• Validation obligatoire de l'identité
• Vérification des documents
• Traçabilité complète
• Audit des actions
''',

      'reports': '''
**Rapports Agent**

**Rapports Quotidiens :**
• Transactions du jour par type
• Cash flow et soldes
• Commissions générées
• Statistiques de performance

**Clôtures :**
• Clôture quotidienne obligatoire
• Réconciliation des soldes
• Validation des opérations
• Génération des rapports

**Analyses :**
• Évolution des volumes
• Performance par client
• Rentabilité par service
• Tendances mensuelles

**Export :**
• PDF pour impression
• Excel pour analyse
• Envoi par email
• Archivage automatique
''',

      'flot': '''
**Gestion des Flots**

**Demande de Flot :**
• Évaluer les besoins en liquidité
• Calculer le montant nécessaire
• Soumettre la demande à l'admin
• Suivre le statut de la demande

**Types de Flots :**
• Flot entrant : Réception de liquidité
• Flot sortant : Envoi vers autre shop
• Flot d'urgence : Demande prioritaire
• Flot programmé : Demande récurrente

**Validation :**
• Approbation administrative
• Vérification des fonds
• Traçabilité complète
• Notification de traitement

**Suivi :**
• Historique des demandes
• Statuts en temps réel
• Impact sur les soldes
• Rapports de flot
''',
    },

    'CLIENT': {
      'dashboard': '''
**Espace Client UCASH**

**Tableau de Bord :**
• Solde actuel de votre compte
• Dernières transactions
• Services disponibles
• Notifications importantes

**Sécurité :**
• Connexion sécurisée
• Déconnexion automatique
• Historique des connexions
• Protection des données

**Navigation :**
• Menu simple et intuitif
• Accès rapide aux services
• Aide contextuelle
• Support client

**Notifications :**
• Réception de transferts
• Confirmations d'opérations
• Alertes de sécurité
• Messages du service
''',

      'account': '''
**Gestion du Compte**

**Informations Personnelles :**
• Consulter vos données
• Mettre à jour le téléphone
• Modifier l'adresse email
• Changer le mot de passe

**Solde et Transactions :**
• Solde en temps réel
• Historique complet
• Détails des opérations
• Relevés de compte

**Services :**
• Demande de transfert
• Retrait de fonds
• Consultation de solde
• Support client

**Sécurité :**
• Mot de passe fort obligatoire
• Vérification d'identité
• Notifications de sécurité
• Signalement d'incidents
''',
    },
  };
}

// Widget pour aide contextuelle dans les formulaires
class FormHelpWidget extends StatelessWidget {
  final String helpText;
  final IconData icon;
  final Color? color;

  const FormHelpWidget({
    super.key,
    required this.helpText,
    this.icon = Icons.help_outline,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: 20,
        color: color ?? Colors.grey[600],
      ),
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.help_outline, color: color ?? const Color(0xFFDC2626)),
                const SizedBox(width: 8),
                const Text('Aide'),
              ],
            ),
            content: SingleChildScrollView(
              child: Text(
                helpText,
                style: const TextStyle(height: 1.5),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Fermer'),
              ),
            ],
          ),
        );
      },
      tooltip: 'Aide',
    );
  }
}

// Widget pour tips rapides
class QuickTipWidget extends StatelessWidget {
  final String tip;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  const QuickTipWidget({
    super.key,
    required this.tip,
    this.icon = Icons.lightbulb_outline,
    this.backgroundColor = const Color(0xFFF3F4F6),
    this.textColor = const Color(0xFF374151),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: backgroundColor.withOpacity(0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: textColor.withOpacity(0.7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              tip,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
