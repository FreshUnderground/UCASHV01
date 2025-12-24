import 'package:flutter/services.dart';
import '../models/user_model.dart';

class DocumentationService {
  static const String _basePath = 'assets/documentation/';
  
  // Documentation sections par rôle
  static const Map<String, List<DocumentationSection>> _documentationSections = {
    'ADMIN': [
      DocumentationSection(
        id: 'admin_overview',
        title: 'Vue d\'ensemble Administrateur',
        icon: 'admin_panel_settings',
        description: 'Introduction au tableau de bord administrateur',
      ),
      DocumentationSection(
        id: 'shop_management',
        title: 'Gestion des Shops',
        icon: 'store',
        description: 'Créer et gérer vos points de service',
      ),
      DocumentationSection(
        id: 'agent_management',
        title: 'Gestion des Agents',
        icon: 'people',
        description: 'Créer et gérer les agents',
      ),
      DocumentationSection(
        id: 'personnel_management',
        title: 'Gestion du Personnel',
        icon: 'badge',
        description: 'Gestion des employés et salaires',
      ),
      DocumentationSection(
        id: 'rates_commissions',
        title: 'Taux et Commissions',
        icon: 'currency_exchange',
        description: 'Configuration des taux de change',
      ),
      DocumentationSection(
        id: 'reports_admin',
        title: 'Rapports Administrateur',
        icon: 'analytics',
        description: 'Rapports financiers et opérationnels',
      ),
      DocumentationSection(
        id: 'validations_admin',
        title: 'Validations et Suppressions',
        icon: 'verified',
        description: 'Gestion des validations administratives',
      ),
    ],
    'AGENT': [
      DocumentationSection(
        id: 'agent_overview',
        title: 'Vue d\'ensemble Agent',
        icon: 'dashboard',
        description: 'Introduction au tableau de bord agent',
      ),
      DocumentationSection(
        id: 'operations',
        title: 'Opérations',
        icon: 'account_balance_wallet',
        description: 'Dépôts, retraits et transferts',
      ),
      DocumentationSection(
        id: 'virtual_transactions',
        title: 'Transactions Virtuelles',
        icon: 'phone_android',
        description: 'Gestion des transactions mobile money',
      ),
      DocumentationSection(
        id: 'validations_agent',
        title: 'Validations',
        icon: 'check_circle',
        description: 'Traitement des validations en attente',
      ),
      DocumentationSection(
        id: 'reports_agent',
        title: 'Rapports Agent',
        icon: 'assessment',
        description: 'Rapports quotidiens et analyses',
      ),
      DocumentationSection(
        id: 'flot_management',
        title: 'Gestion des Flots',
        icon: 'swap_horiz',
        description: 'Demandes et gestion des flots',
      ),
      DocumentationSection(
        id: 'inter_shop_debts',
        title: 'Dettes Intershop',
        icon: 'account_balance',
        description: 'Gestion des dettes entre shops',
      ),
    ],
    'CLIENT': [
      DocumentationSection(
        id: 'client_overview',
        title: 'Vue d\'ensemble Client',
        icon: 'person',
        description: 'Introduction à votre espace client',
      ),
      DocumentationSection(
        id: 'account_info',
        title: 'Informations du Compte',
        icon: 'account_circle',
        description: 'Consulter vos informations personnelles',
      ),
      DocumentationSection(
        id: 'transaction_history',
        title: 'Historique des Transactions',
        icon: 'history',
        description: 'Consulter vos transactions',
      ),
      DocumentationSection(
        id: 'services_request',
        title: 'Demande de Services',
        icon: 'request_quote',
        description: 'Comment demander des services',
      ),
    ],
  };

  // Contenu de documentation par section
  static const Map<String, DocumentationContent> _documentationContent = {
    // ADMIN SECTIONS
    'admin_overview': DocumentationContent(
      title: 'Vue d\'ensemble Administrateur',
      sections: [
        DocumentationSubSection(
          title: 'Tableau de Bord',
          content: '''
Le tableau de bord administrateur vous donne une vue d'ensemble complète de votre système UCASH :

**Statistiques Principales :**
• Nombre total de shops
• Nombre d'agents actifs
• Volume de transactions du jour
• Revenus et commissions

**Navigation Rapide :**
• Menu latéral pour accès direct aux fonctionnalités
• Notifications en temps réel
• Synchronisation automatique des données

**Première Connexion :**
Identifiants par défaut : admin / admin123
''',
        ),
        DocumentationSubSection(
          title: 'Ordre de Configuration',
          content: '''
**Séquence Recommandée :**

1️⃣ **Créer les Shops** (obligatoire en premier)
   • Définir les points de service
   • Configurer les capitaux initiaux

2️⃣ **Configurer Taux & Commissions**
   • Taux de change USD/CDF
   • Commissions par type d'opération

3️⃣ **Créer les Agents**
   • Assigner aux shops créés
   • Définir les identifiants de connexion

4️⃣ **Formation des Agents**
   • Expliquer les procédures
   • Tester les fonctionnalités

5️⃣ **Lancement Opérationnel**
   • Surveillance continue
   • Support aux agents
''',
        ),
      ],
    ),
    
    'shop_management': DocumentationContent(
      title: 'Gestion des Shops',
      sections: [
        DocumentationSubSection(
          title: 'Création d\'un Shop',
          content: '''
**Étapes de Création :**

1. **Accès au Menu**
   • Cliquez sur "Shops" dans le menu latéral
   • Bouton "Nouveau Shop" (rouge)

2. **Informations Requises :**
   • Désignation du shop (nom unique)
   • Adresse/localisation
   • Téléphone de contact
   • Capital initial par devise

3. **Configuration des Capitaux :**
   • Capital USD (obligatoire)
   • Capital CDF (optionnel)
   • Autres modes de paiement selon besoins

4. **Validation :**
   • Vérification des informations
   • Sauvegarde automatique
   • Attribution d'un ID unique
''',
        ),
        DocumentationSubSection(
          title: 'Gestion des Capitaux',
          content: '''
**Types de Capitaux :**

• **USD** : Capital principal en dollars
• **Cash CDF** : Capital en francs congolais
• **Airtel Money** : Solde mobile Airtel
• **M-Pesa** : Solde mobile Vodacom
• **Orange Money** : Solde mobile Orange

**Suivi en Temps Réel :**
• Évolution des soldes par mode
• Alertes de seuils bas
• Historique des mouvements
• Rapports de performance
''',
        ),
      ],
    ),

    'agent_management': DocumentationContent(
      title: 'Gestion des Agents',
      sections: [
        DocumentationSubSection(
          title: 'Création d\'un Agent',
          content: '''
**Processus de Création :**

1. **Navigation :**
   • Menu "Agents" → "Nouvel Agent"
   • Formulaire de création

2. **Informations Personnelles :**
   • Nom et prénom
   • Téléphone de contact
   • Adresse (optionnel)

3. **Informations Système :**
   • Nom d'utilisateur (unique)
   • Mot de passe (minimum 6 caractères)
   • Shop d'assignation
   • Matricule automatique (AGT[AA][MM][JJ][Shop][XXX])

4. **Validation :**
   • Vérification unicité username
   • Génération automatique matricule
   • Création du compte agent
''',
        ),
        DocumentationSubSection(
          title: 'Gestion des Matricules',
          content: '''
**Format Automatique :**
AGT[AA][MM][JJ][Shop][XXX]

• **AGT** : Préfixe agent
• **AA** : Année (2 chiffres)
• **MM** : Mois (01-12)
• **JJ** : Jour (01-31)
• **Shop** : ID du shop (2 chiffres)
• **XXX** : Suffixe aléatoire unique

**Fonctionnalités :**
• Génération automatique à la création
• Possibilité de modification manuelle
• Bouton de régénération
• Validation d'unicité
''',
        ),
      ],
    ),

    // AGENT SECTIONS
    'operations': DocumentationContent(
      title: 'Opérations',
      sections: [
        DocumentationSubSection(
          title: 'Dépôts',
          content: '''
**Processus de Dépôt :**

1. **Initiation :**
   • Bouton VERT "Dépôt"
   • Sélection du client

2. **Saisie des Informations :**
   • Montant à déposer
   • Devise (USD/CDF)
   • Mode de paiement reçu

3. **Modes de Paiement :**
   • USD/CDF
   • Airtel Money
   • M-Pesa
   • Orange Money

4. **Validation :**
   • Vérification du montant
   • Confirmation de l'opération
   • Mise à jour automatique des soldes

**Caractéristiques :**
✅ Aucune commission
✅ Mise à jour immédiate du solde client
✅ Augmentation du capital shop
''',
        ),
        DocumentationSubSection(
          title: 'Retraits',
          content: '''
**Processus de Retrait :**

1. **Initiation :**
   • Bouton ORANGE "Retrait"
   • Sélection du client

2. **Vérifications :**
   • Contrôle du solde disponible
   • Validation de l'identité client

3. **Saisie :**
   • Montant à retirer (≤ solde)
   • Mode de paiement de sortie

4. **Exécution :**
   • Déduction du solde client
   • Remise de l'argent
   • Réduction du capital shop

**Sécurité :**
🔒 Blocage si solde insuffisant
🔒 Validation obligatoire de l'identité
🔒 Traçabilité complète
''',
        ),
        DocumentationSubSection(
          title: 'Transferts',
          content: '''
**Types de Transferts :**

• **National** : Vers un autre shop RDC
• **International Sortant** : Vers l'étranger (3.5%)
• **International Entrant** : Depuis l'étranger (0%)

**Processus :**

1. **Préparation :**
   • Capture d'écran obligatoire (preuve)
   • Vérification des fonds

2. **Saisie :**
   • Nom du bénéficiaire
   • Shop de destination (si national)
   • Montant et devise

3. **Calcul Automatique :**
   • Commission selon le type
   • Taux de change si nécessaire
   • Montant final à recevoir

4. **Finalisation :**
   • Validation de l'opération
   • Génération de la référence
   • Notification au shop destinataire
''',
        ),
      ],
    ),

    'virtual_transactions': DocumentationContent(
      title: 'Transactions Virtuelles',
      sections: [
        DocumentationSubSection(
          title: 'Système Multi-Devises',
          content: '''
**Gestion USD/CDF :**

• **Captures** : Enregistrement en devise originale
• **Cash Disponible** : Toujours en USD
• **Conversions** : Automatiques selon taux

**Affichage :**
• Montants virtuels : Devise originale (USD/CDF)
• Montants cash : "USD"
• Totaux mixtes : "Mixte" avec détail

**Logique Métier :**
• Capture client → Enregistrement en devise choisie
• Validation agent → Impact cash en USD
• Frais → Toujours calculés en USD
''',
        ),
        DocumentationSubSection(
          title: 'Gestion par SIM',
          content: '''
**Organisation par Carte SIM :**

Chaque SIM a ses propres :
• Solde virtuel disponible
• Historique des transactions
• Statistiques quotidiennes
• Procédures de clôture

**Opérations Principales :**
• **Captures** : Enregistrement des demandes clients
• **Validations** : Traitement des captures en attente
• **Retraits** : Sortie d'argent du système virtuel
• **Dépôts** : Entrée d'argent dans le système

**Rapports par SIM :**
• Vue d'ensemble quotidienne
• Détail des transactions
• Calcul des frais
• Clôture journalière
''',
        ),
      ],
    ),

    // CLIENT SECTIONS
    'client_overview': DocumentationContent(
      title: 'Espace Client UCASH',
      sections: [
        DocumentationSubSection(
          title: 'Accès à votre Compte',
          content: '''
**Connexion :**
• Utilisez les identifiants fournis par votre agent
• Sélectionnez "Client" lors de la connexion
• Choisissez votre langue préférée

**Tableau de Bord :**
• Solde actuel de votre compte
• Dernières transactions
• Services disponibles
• Notifications importantes

**Sécurité :**
• Déconnexion automatique après inactivité
• Changement de mot de passe possible
• Historique des connexions
''',
        ),
        DocumentationSubSection(
          title: 'Services Disponibles',
          content: '''
**Consultation :**
• Solde en temps réel
• Historique complet des transactions
• Relevés de compte
• Informations personnelles

**Demandes de Services :**
• Transferts d'argent
• Retraits de fonds
• Mise à jour d'informations
• Support client

**Notifications :**
• Réception de transferts
• Confirmations d'opérations
• Alertes de sécurité
• Messages du service client
''',
        ),
      ],
    ),
  };

  // Traductions anglaises des sections
  static const Map<String, Map<String, String>> _englishSectionTranslations = {
    'admin_overview': {
      'title': 'Administrator Overview',
      'description': 'Introduction to the administrator dashboard',
    },
    'shop_management': {
      'title': 'Shop Management',
      'description': 'Create and manage your service points',
    },
    'agent_management': {
      'title': 'Agent Management',
      'description': 'Create and manage agents',
    },
    'personnel_management': {
      'title': 'Personnel Management',
      'description': 'Employee and salary management',
    },
    'rates_commissions': {
      'title': 'Rates and Commissions',
      'description': 'Exchange rate configuration',
    },
    'reports_admin': {
      'title': 'Administrator Reports',
      'description': 'Financial and operational reports',
    },
    'validations_admin': {
      'title': 'Validations and Deletions',
      'description': 'Administrative validation management',
    },
    'agent_overview': {
      'title': 'Agent Overview',
      'description': 'Introduction to the agent dashboard',
    },
    'operations': {
      'title': 'Operations',
      'description': 'Deposits, withdrawals and transfers',
    },
    'virtual_transactions': {
      'title': 'Virtual Transactions',
      'description': 'Mobile money transaction management',
    },
    'validations_agent': {
      'title': 'Validations',
      'description': 'Processing pending validations',
    },
    'reports_agent': {
      'title': 'Agent Reports',
      'description': 'Daily reports and analysis',
    },
    'flot_management': {
      'title': 'Float Management',
      'description': 'Float requests and management',
    },
    'inter_shop_debts': {
      'title': 'Inter-shop Debts',
      'description': 'Management of debts between shops',
    },
    'client_overview': {
      'title': 'Client Overview',
      'description': 'Introduction to your client space',
    },
    'account_info': {
      'title': 'Account Information',
      'description': 'View your personal information',
    },
    'transaction_history': {
      'title': 'Transaction History',
      'description': 'View your transactions',
    },
    'services_request': {
      'title': 'Service Requests',
      'description': 'How to request services',
    },
  };

  // Traductions anglaises du contenu
  static const Map<String, Map<String, dynamic>> _englishContentTranslations = {
    'admin_overview': {
      'title': 'Administrator Overview',
      'sections': [
        {
          'title': 'Dashboard',
          'content': '''
The administrator dashboard gives you a complete overview of your UCASH system:

**Main Statistics:**
• Total number of shops
• Active agents count
• Daily transaction volume
• Revenue and commissions

**Quick Navigation:**
• Sidebar menu for direct access to features
• Real-time notifications
• Automatic data synchronization

**First Login:**
Default credentials: admin / admin123
''',
        },
        {
          'title': 'Configuration Order',
          'content': '''
**Recommended Sequence:**

1️⃣ **Create Shops** (mandatory first)
   • Define service points
   • Configure initial capital

2️⃣ **Configure Rates & Commissions**
   • USD/CDF exchange rates
   • Commissions by operation type

3️⃣ **Create Agents**
   • Assign to created shops
   • Define login credentials

4️⃣ **Agent Training**
   • Explain procedures
   • Test functionalities

5️⃣ **Operational Launch**
   • Continuous monitoring
   • Agent support
''',
        },
      ],
    },
    'operations': {
      'title': 'Operations',
      'sections': [
        {
          'title': 'Deposits',
          'content': '''
**Deposit Process:**

1. **Initiation:**
   • GREEN "Deposit" button
   • Client selection

2. **Information Entry:**
   • Amount to deposit
   • Currency (USD/CDF)
   • Payment method received

3. **Payment Methods:**
   • USD/CDF
   • Airtel Money
   • M-Pesa
   • Orange Money

4. **Validation:**
   • Amount verification
   • Operation confirmation
   • Automatic balance update

**Features:**
✅ No commission
✅ Immediate client balance update
✅ Shop capital increase
''',
        },
        {
          'title': 'Withdrawals',
          'content': '''
**Withdrawal Process:**

1. **Initiation:**
   • ORANGE "Withdrawal" button
   • Client selection

2. **Verifications:**
   • Available balance check
   • Client identity validation

3. **Entry:**
   • Amount to withdraw (≤ balance)
   • Output payment method

4. **Execution:**
   • Client balance deduction
   • Cash delivery
   • Shop capital reduction

**Security:**
🔒 Blocking if insufficient balance
🔒 Mandatory identity validation
🔒 Complete traceability
''',
        },
      ],
    },
  };

  // Méthodes publiques avec support multilingue
  static List<DocumentationSection> getSectionsForRole(String role, [String language = 'fr']) {
    final sections = _documentationSections[role] ?? [];
    if (language == 'en') {
      return sections.map((section) => _translateSectionToEnglish(section)).toList();
    }
    return sections;
  }

  static DocumentationContent? getContentForSection(String sectionId, [String language = 'fr']) {
    final content = _documentationContent[sectionId];
    if (content == null) return null;
    
    if (language == 'en') {
      return _translateContentToEnglish(content, sectionId);
    }
    return content;
  }

  static List<DocumentationSection> searchSections(String query, String role, [String language = 'fr']) {
    final sections = getSectionsForRole(role, language);
    if (query.isEmpty) return sections;
    
    return sections.where((section) {
      return section.title.toLowerCase().contains(query.toLowerCase()) ||
             section.description.toLowerCase().contains(query.toLowerCase());
    }).toList();
  }

  static bool hasDocumentationForRole(String role) {
    return _documentationSections.containsKey(role);
  }

  // Méthodes de traduction
  static DocumentationSection _translateSectionToEnglish(DocumentationSection section) {
    final translations = _englishSectionTranslations[section.id];
    if (translations != null) {
      return DocumentationSection(
        id: section.id,
        title: translations['title'] ?? section.title,
        icon: section.icon,
        description: translations['description'] ?? section.description,
      );
    }
    return section;
  }

  static DocumentationContent _translateContentToEnglish(DocumentationContent content, String sectionId) {
    final translations = _englishContentTranslations[sectionId];
    if (translations != null) {
      return DocumentationContent(
        title: translations['title'] ?? content.title,
        sections: content.sections.asMap().entries.map((entry) {
          final index = entry.key;
          final section = entry.value;
          final sectionTranslations = translations['sections'] as List<Map<String, String>>?;
          
          if (sectionTranslations != null && index < sectionTranslations.length) {
            final sectionTranslation = sectionTranslations[index];
            return DocumentationSubSection(
              title: sectionTranslation['title'] ?? section.title,
              content: sectionTranslation['content'] ?? section.content,
            );
          }
          return section;
        }).toList(),
      );
    }
    return content;
  }
}

class DocumentationSection {
  final String id;
  final String title;
  final String icon;
  final String description;

  const DocumentationSection({
    required this.id,
    required this.title,
    required this.icon,
    required this.description,
  });
}

class DocumentationContent {
  final String title;
  final List<DocumentationSubSection> sections;

  const DocumentationContent({
    required this.title,
    required this.sections,
  });
}

class DocumentationSubSection {
  final String title;
  final String content;

  const DocumentationSubSection({
    required this.title,
    required this.content,
  });
}
