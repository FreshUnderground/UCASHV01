import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/connectivity_service.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import '../widgets/footer_widget.dart';
import '../widgets/modern_widgets.dart';
import '../widgets/language_selector.dart';
import 'package:ucashv01/flutter_gen/gen_l10n/app_localizations.dart';
import '../config/app_theme.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // OPTIMISATION #1: Login immédiat, sync en arrière-plan
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        rememberMe: _rememberMe,
      );

      if (success && mounted) {
        // Démarrer la synchronisation en arrière-plan APRÈS login réussi
        _syncAfterLogin();
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Synchronisation non-bloquante en arrière-plan après login réussi
  /// Cette méthode remplace _syncBeforeLogin() pour améliorer les performances
  void _syncAfterLogin() {
    // Exécuter la synchronisation en arrière-plan sans bloquer l'UI
    Future.delayed(Duration.zero, () async {
      try {
        final connectivityService = ConnectivityService.instance;
        if (connectivityService.isOnline) {
          debugPrint('🔄 Démarrage synchronisation arrière-plan post-login...');

          // Sync agents and shops silently en arrière-plan
          final agentService = AgentService.instance;
          final shopService = ShopService.instance;

          await Future.wait([
            agentService.loadAgents(),
            shopService.loadShops(),
          ]);

          debugPrint('✅ Agents et shops synchronisés en arrière-plan');
        }
      } catch (e) {
        debugPrint('⚠️ Erreur sync arrière-plan post-login: $e');
        // Sync en arrière-plan - les erreurs ne bloquent pas l'utilisateur
      }
    });
  }

  /// Ancienne méthode de sync bloquante - conservée pour référence
  /// DEPRECATED: Remplacée par _syncAfterLogin() pour de meilleures performances
  Future<void> _syncBeforeLogin() async {
    try {
      final connectivityService = ConnectivityService.instance;
      if (connectivityService.isOnline) {
        // Sync agents and shops silently
        final agentService = AgentService.instance;
        final shopService = ShopService.instance;

        await Future.wait([
          agentService.loadAgents(),
          shopService.loadShops(),
        ]);

        debugPrint('✅ Agents et shops synchronisés avant login');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur sync avant login: $e');
      // Continue with login even if sync fails
    }
  }

  Future<void> _createDefaultAdmin() async {
    try {
      await LocalDB.instance.forceCreateAdmin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Admin créé/recréé ! Username: admin, Password: admin123'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la création: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showBilingualHelpDialog(BuildContext context) {
    bool isEnglish = Localizations.localeOf(context).languageCode == 'en';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(
                    isEnglish ? 'UCASH Complete Guide' : 'Guide Complet UCASH'),
              ),
              ToggleButtons(
                isSelected: [!isEnglish, isEnglish],
                onPressed: (index) {
                  setState(() {
                    isEnglish = index == 1;
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('FR'),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Text('EN'),
                  ),
                ],
              ),
            ],
          ),
          content: SingleChildScrollView(
            child:
                Text(isEnglish ? _getEnglishHelpText() : _getFrenchHelpText()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(isEnglish ? 'Close' : 'Fermer'),
            ),
          ],
        ),
      ),
    );
  }

  String _getFrenchHelpText() {
    return '''GUIDE COMPLET SYSTÈME UCASH

═══════════════════════════════════════
CONNEXION ET ACCÈS INITIAL
═══════════════════════════════════════
**Connexion Administrateur par défaut :**
• Username : admin
• Password : admin123

**Types d'Accès Disponibles :**
• **Administrateur** : Gestion complète du système
• **Agent** : Opérations quotidiennes et transactions  
• **Client** : Consultation de compte et services

┌─────────────────────────────────────────┐
│            ARCHITECTURE SYSTÈME         │
├─────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌──────┐ │
│  │   ADMIN   │  │   AGENT   │  │CLIENT│ │
│  │           │  │           │  │      │ │
│  │ Dashboard │  │Opérations │  │Consul│ │
│  │ Gestion   │  │Validations│  │tation│ │
│  │ Config    │  │ Rapports  │  │      │ │
│  └───────────┘  └───────────┘  └──────┘ │
│       │              │            │     │
│       └──────────────┼────────────┘     │
│                      │                  │
│  ┌─────────────────────────────────────┐ │
│  │         BASE DE DONNÉES             │ │
│  │ • Opérations  • Agents  • Clients  │ │
│  │ • Shops      • Taux    • Rapports  │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

═══════════════════════════════════════
🔧 FONCTIONNALITÉS ADMINISTRATEUR COMPLÈTES
═══════════════════════════════════════

📊 **DASHBOARD ADMIN** :
• Vue d'ensemble des statistiques système
• Cartes de performance en temps réel
• Actions rapides vers modules principaux
• Indicateurs de santé du système

💰 **GESTION DES DÉPENSES/FRAIS** :
• Suivi des frais de service par shop
• Configuration des seuils de frais
• Rapports de rentabilité détaillés
• Gestion des retraits de commissions

🏪 **GESTION DES SHOPS** :
• Création et modification des points de vente
• Configuration des paramètres par shop
• Suivi des performances individuelles
• Gestion des autorisations et limites

👥 **GESTION DES AGENTS** :
• Création/modification des comptes agents
• Attribution des rôles et permissions
• Génération automatique de matricules
• Suivi des performances agents

👨‍💼 **GESTION DES ADMINISTRATEURS** :
• Création d'autres comptes admin
• Gestion des droits d'accès
• Synchronisation serveur des admins
• Audit des actions administratives

📱 **MODULE VIRTUEL ADMIN** :
• Supervision des transactions mobile money
• Configuration des opérateurs (Orange, Airtel, etc.)
• Gestion des cartes SIM
• Rapports consolidés multi-opérateurs
• Clôtures virtuelles centralisées

👤 **GESTION DES PARTENAIRES** :
• Base de données clients complète
• Historique des transactions par client
• Positions nettes des comptes clients
• Synchronisation automatique

💱 **TAUX & COMMISSIONS** :
• Configuration des taux de change USD/CDF
• Paramétrage des commissions par type d'opération
• Mise à jour en temps réel
• Historique des modifications

📈 **RAPPORTS ADMINISTRATION** :
• Rapports consolidés multi-shops
• Analyses de performance globales
• Statistiques financières détaillées
• Export PDF des rapports

🔄 **DETTES INTERSHOP** :
• Suivi des créances/dettes entre shops
• Positions nettes consolidées
• Règlements triangulaires automatiques
• Optimisation des flux financiers

⚙️ **CONFIGURATION SYSTÈME** :
• Paramètres généraux du système
• Configuration des seuils et limites
• Gestion des SIM cards
• Audit trail complet
• Réconciliation des données

🗑️ **SUPPRESSIONS ADMIN** :
• Gestion des demandes de suppression
• Workflow de validation à deux niveaux
• Traçabilité complète des suppressions
• Sauvegarde en corbeille

✅ **VALIDATIONS ADMIN** :
• Validation des demandes inter-admin
• Contrôle des opérations sensibles
• Workflow d'approbation hiérarchique
• Notifications automatiques

🗂️ **CORBEILLE SYSTÈME** :
• Récupération des éléments supprimés
• Restauration sélective
• Purge automatique programmée
• Audit des restaurations

🔧 **INITIALISATION SYSTÈME** :
• Initialisation des soldes virtuels
• Configuration des comptes clients
• Paramétrage des crédits intershops
• Règlements triangulaires

👨‍💼 **GESTION DU PERSONNEL** :
• Fiches employés complètes
• Gestion des salaires multi-périodes
• Avances et retenues personnalisées
• Crédits personnel
• Rapports RH détaillés

═══════════════════════════════════════
🏢 FONCTIONNALITÉS AGENT COMPLÈTES
═══════════════════════════════════════

📊 **OPÉRATIONS QUOTIDIENNES** :
• Dépôts clients (USD/CDF)
• Retraits clients (USD/CDF)
• Transferts inter-shops
• Gestion des billetages détaillée
• Impression automatique des reçus

✅ **VALIDATIONS AGENT** :
• Validation des transferts en attente
• Traitement des demandes inter-shops
• Gestion des transferts reçus/envoyés
• Historique des validations

📈 **RAPPORTS AGENT** :
• Clôture quotidienne obligatoire
• Mouvements de caisse détaillés
• Statistiques des opérations
• Suivi des commissions
• Export PDF des rapports

🚚 **GESTION FLOT** :
• Envoi/réception de liquidités
• Suivi des mouvements de fonds
• Validation des flots reçus
• Optimisation des circuits

💰 **GESTION DES FRAIS** :
• Suivi des commissions générées
• Retraits de frais autorisés
• Historique des frais
• Rapports de rentabilité

📱 **TRANSACTIONS VIRTUELLES** :
• Captures clients mobile money
• Services virtuels multi-opérateurs
• Rapports virtuels détaillés
• Clôtures par SIM
• Gestion des échecs de transaction

🔄 **DETTES INTERSHOP AGENT** :
• Consultation des positions
• Suivi des créances/dettes
• Historique des mouvements
• Impact sur la trésorerie

⚙️ **RÈGLEMENTS TRIANGULAIRES** :
• Participation aux règlements
• Validation des circuits
• Optimisation des flux
• Économies de transport

🗑️ **SUPPRESSIONS AGENT** :
• Validation des demandes admin
• Contrôle de cohérence
• Workflow de validation final
• Audit des décisions

═══════════════════════════════════════
SYSTÈME DE CLÔTURES ET SÉCURITÉ
═══════════════════════════════════════
**Vérification Automatique** :
• Contrôle avant accès aux menus sensibles
• Blocage préventif si clôtures manquantes
• Workflow de régularisation
• Synchronisation obligatoire

**Menus Concernés (Agents)** :
• Opérations (index 0)
• Validations (index 1)
• FLOT (index 3)

═══════════════════════════════════════
PREMIÈRE UTILISATION - GUIDE COMPLET
═══════════════════════════════════════

┌─────────────────────────────────────────┐
│          WORKFLOW PRINCIPAL             │
├─────────────────────────────────────────┤
│ CONNEXION → VÉRIFICATION → OPÉRATION    │
│   AGENT       CLÔTURES      QUOTIDIENNE │
│     │            │              │      │
│     ▼            ▼              ▼      │
│ Username     Clôtures      • Dépôts    │
│ Password     manquantes?   • Retraits  │
│ Shop ID      Blocage       • Transferts│
│              préventif     • Billetages│
└─────────────────────────────────────────┘

**Phase 1 - Configuration Initiale** :
1. Connexion avec admin/admin123
2. Création des shops principaux
3. Configuration des taux de change
4. Paramétrage des commissions

**Phase 2 - Gestion des Utilisateurs** :
5. Création des comptes agents
6. Attribution des shops aux agents
7. Configuration des permissions
8. Test des connexions agents

**Phase 3 - Configuration Opérationnelle** :
9. Initialisation des soldes virtuels
10. Configuration des cartes SIM
11. Paramétrage des opérateurs mobiles
12. Test des opérations de base

**Phase 4 - Formation et Déploiement** :
13. Formation des agents sur les workflows
14. Test des clôtures quotidiennes
15. Vérification des rapports
16. Mise en production

┌─────────────────────────────────────────┐
│        FLUX VALIDATION TRANSFERTS      │
├─────────────────────────────────────────┤
│ SHOP A (Initie) → EN_ATTENTE → SHOP B  │
│   Agent A           │         Agent B  │
│   • Montant        │         • Vérifie │
│   • Commission     │         • Valide  │
│   • Total débité   ▼         • Sert    │
│                VALIDÉE                  │
│ Résultat: A doit à B, B créance sur A  │
└─────────────────────────────────────────┘

═══════════════════════════════════════
SUPPORT ET MAINTENANCE
═══════════════════════════════════════
• Documentation contextuelle dans chaque module
• Guides spécifiques par rôle
• Support technique intégré
• Mises à jour automatiques
• Sauvegarde cloud sécurisée
• Audit trail complet
• Formation continue disponible

═══════════════════════════════════════
PROBLÈMES COURANTS ET SOLUTIONS
═══════════════════════════════════════
**Connexion** :
• Vérifier la connexion internet
• Utiliser "Créer Admin par Défaut" si nécessaire
• Contacter le support technique

**Synchronisation** :
• Vérifier la connectivité serveur
• Forcer la synchronisation manuelle
• Consulter les logs d'erreur

**Clôtures** :
• Effectuer les clôtures quotidiennes
• Vérifier les écarts de caisse
• Synchroniser avant validation''';
  }

  String _getEnglishHelpText() {
    return '''COMPLETE UCASH SYSTEM GUIDE

═══════════════════════════════════════
LOGIN AND INITIAL ACCESS
═══════════════════════════════════════
**Default Administrator Login:**
• Username: admin
• Password: admin123

**Available Access Types:**
• **Administrator**: Complete system management
• **Agent**: Daily operations and transactions
• **Client**: Account consultation and services

┌─────────────────────────────────────────┐
│           SYSTEM ARCHITECTURE           │
├─────────────────────────────────────────┤
│  ┌───────────┐  ┌───────────┐  ┌──────┐ │
│  │   ADMIN   │  │   AGENT   │  │CLIENT│ │
│  │           │  │           │  │      │ │
│  │ Dashboard │  │Operations │  │Query │ │
│  │Management │  │Validations│  │      │ │
│  │ Config    │  │ Reports   │  │      │ │
│  └───────────┘  └───────────┘  └──────┘ │
│       │              │            │     │
│       └──────────────┼────────────┘     │
│                      │                  │
│  ┌─────────────────────────────────────┐ │
│  │           DATABASE                  │ │
│  │ • Operations • Agents   • Clients  │ │
│  │ • Shops     • Rates    • Reports   │ │
│  └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘

═══════════════════════════════════════
🔧 COMPLETE ADMINISTRATOR FEATURES
═══════════════════════════════════════

📊 **ADMIN DASHBOARD**:
• System statistics overview
• Real-time performance cards
• Quick actions to main modules
• System health indicators

💰 **EXPENSES/FEES MANAGEMENT**:
• Service fees tracking per shop
• Fee threshold configuration
• Detailed profitability reports
• Commission withdrawal management

🏪 **SHOP MANAGEMENT**:
• Point of sale creation and modification
• Per-shop parameter configuration
• Individual performance tracking
• Authorization and limit management

👥 **AGENT MANAGEMENT**:
• Agent account creation/modification
• Role and permission assignment
• Automatic matricule generation
• Agent performance tracking

👨‍💼 **ADMINISTRATOR MANAGEMENT**:
• Other admin account creation
• Access rights management
• Admin server synchronization
• Administrative action audit

📱 **VIRTUAL ADMIN MODULE**:
• Mobile money transaction supervision
• Operator configuration (Orange, Airtel, etc.)
• SIM card management
• Consolidated multi-operator reports
• Centralized virtual closures

👤 **PARTNER MANAGEMENT**:
• Complete client database
• Transaction history per client
• Client account net positions
• Automatic synchronization

💱 **RATES & COMMISSIONS**:
• USD/CDF exchange rate configuration
• Commission setup by operation type
• Real-time updates
• Modification history

📈 **ADMINISTRATION REPORTS**:
• Multi-shop consolidated reports
• Global performance analysis
• Detailed financial statistics
• PDF report export

🔄 **INTERSHOP DEBTS**:
• Receivables/debts tracking between shops
• Consolidated net positions
• Automatic triangular settlements
• Financial flow optimization

⚙️ **SYSTEM CONFIGURATION**:
• General system parameters
• Threshold and limit configuration
• SIM card management
• Complete audit trail
• Data reconciliation

🗑️ **ADMIN DELETIONS**:
• Deletion request management
• Two-level validation workflow
• Complete deletion traceability
• Trash bin backup

✅ **ADMIN VALIDATIONS**:
• Inter-admin request validation
• Sensitive operation control
• Hierarchical approval workflow
• Automatic notifications

🗂️ **SYSTEM TRASH BIN**:
• Deleted item recovery
• Selective restoration
• Scheduled automatic purge
• Restoration audit

🔧 **SYSTEM INITIALIZATION**:
• Virtual balance initialization
• Client account configuration
• Intershop credit setup
• Triangular settlements

👨‍💼 **PERSONNEL MANAGEMENT**:
• Complete employee records
• Multi-period salary management
• Custom advances and deductions
• Personnel credits
• Detailed HR reports

═══════════════════════════════════════
🏢 COMPLETE AGENT FEATURES
═══════════════════════════════════════

📊 **DAILY OPERATIONS**:
• Client deposits (USD/CDF)
• Client withdrawals (USD/CDF)
• Inter-shop transfers
• Detailed cash denomination management
• Automatic receipt printing

✅ **AGENT VALIDATIONS**:
• Pending transfer validation
• Inter-shop request processing
• Received/sent transfer management
• Validation history

📈 **AGENT REPORTS**:
• Mandatory daily closure
• Detailed cash movements
• Operation statistics
• Commission tracking
• PDF report export

🚚 **FLOT MANAGEMENT**:
• Liquidity sending/receiving
• Fund movement tracking
• Received flot validation
• Circuit optimization

💰 **FEE MANAGEMENT**:
• Generated commission tracking
• Authorized fee withdrawals
• Fee history
• Profitability reports

📱 **VIRTUAL TRANSACTIONS**:
• Mobile money client captures
• Multi-operator virtual services
• Detailed virtual reports
• SIM closures
• Transaction failure management

🔄 **AGENT INTERSHOP DEBTS**:
• Position consultation
• Receivables/debts tracking
• Movement history
• Treasury impact

⚙️ **TRIANGULAR SETTLEMENTS**:
• Settlement participation
• Circuit validation
• Flow optimization
• Transport savings

🗑️ **AGENT DELETIONS**:
• Admin request validation
• Consistency control
• Final validation workflow
• Decision audit

═══════════════════════════════════════
CLOSURE SYSTEM AND SECURITY
═══════════════════════════════════════
**Automatic Verification**:
• Control before sensitive menu access
• Preventive blocking if closures missing
• Regularization workflow
• Mandatory synchronization

**Affected Menus (Agents)**:
• Operations (index 0)
• Validations (index 1)
• FLOT (index 3)

═══════════════════════════════════════
FIRST USE - COMPLETE GUIDE
═══════════════════════════════════════

┌─────────────────────────────────────────┐
│           MAIN WORKFLOW                 │
├─────────────────────────────────────────┤
│ LOGIN → VERIFICATION → DAILY OPERATION  │
│ AGENT     CLOSURES      PROCESSING      │
│   │          │              │           │
│   ▼          ▼              ▼           │
│ Username   Missing       • Deposits     │
│ Password   closures?     • Withdrawals  │
│ Shop ID    Preventive    • Transfers    │
│            blocking      • Cash mgmt    │
└─────────────────────────────────────────┘

**Phase 1 - Initial Configuration**:
1. Login with admin/admin123
2. Create main shops
3. Configure exchange rates
4. Set up commissions

**Phase 2 - User Management**:
5. Create agent accounts
6. Assign shops to agents
7. Configure permissions
8. Test agent connections

**Phase 3 - Operational Configuration**:
9. Initialize virtual balances
10. Configure SIM cards
11. Set up mobile operators
12. Test basic operations

**Phase 4 - Training and Deployment**:
13. Train agents on workflows
14. Test daily closures
15. Verify reports
16. Go live

┌─────────────────────────────────────────┐
│       TRANSFER VALIDATION FLOW         │
├─────────────────────────────────────────┤
│ SHOP A (Init) → PENDING → SHOP B       │
│  Agent A          │        Agent B     │
│  • Amount        │        • Verify    │
│  • Commission    │        • Validate  │
│  • Total debited ▼        • Serve     │
│              VALIDATED                  │
│ Result: A owes B, B has claim on A     │
└─────────────────────────────────────────┘

═══════════════════════════════════════
SUPPORT AND MAINTENANCE
═══════════════════════════════════════
• Contextual documentation in each module
• Role-specific guides
• Integrated technical support
• Automatic updates
• Secure cloud backup
• Complete audit trail
• Continuous training available

═══════════════════════════════════════
COMMON ISSUES AND SOLUTIONS
═══════════════════════════════════════
**Connection**:
• Check internet connection
• Use "Create Default Admin" if necessary
• Contact technical support

**Synchronization**:
• Check server connectivity
• Force manual synchronization
• Check error logs

**Closures**:
• Perform daily closures
• Check cash discrepancies
• Synchronize before validation''';
  }

  String _getLoginHelpText(BuildContext context) {
    // Return static help text instead of triggering dialog
    return '''GUIDE RAPIDE UCASH

Connexion Administrateur par défaut :
• Username : admin
• Password : admin123

Types d'Accès :
• Administrateur : Gestion complète
• Agent : Opérations quotidiennes  
• Client : Consultation de compte

Pour plus d'aide, cliquez sur le bouton d'aide.''';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryRed,
                  AppTheme.primaryRedDark,
                ],
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        padding: context.fluidPadding(
                          mobile: const EdgeInsets.all(16),
                          tablet: const EdgeInsets.all(32),
                          desktop: const EdgeInsets.all(48),
                        ),
                        child: Container(
                          constraints: BoxConstraints(
                            maxWidth:
                                ResponsiveUtils.getMaxContainerWidth(context),
                          ),
                          child: context.adaptiveCard(
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Header moderne avec logo
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 800),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    curve: AppTheme.bounceCurve,
                                    builder: (context, value, child) {
                                      final logoSize = context.fluidIcon(
                                          mobile: 100,
                                          tablet: 120,
                                          desktop: 140);
                                      return Transform.scale(
                                        scale: value,
                                        child: Container(
                                          width: logoSize,
                                          height: logoSize,
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                                context.fluidBorderRadius()),
                                            boxShadow: AppTheme.mediumShadow,
                                          ),
                                          padding: const EdgeInsets.all(8),
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  context.verticalSpace(
                                      mobile: 24, tablet: 28, desktop: 32),

                                  // Titre avec animation
                                  TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 600),
                                    tween: Tween(begin: 0.0, end: 1.0),
                                    curve: Curves.easeOutQuart,
                                    builder: (context, value, child) {
                                      return Opacity(
                                        opacity: value,
                                        child: Transform.translate(
                                          offset: Offset(0, 20 * (1 - value)),
                                          child: Column(
                                            children: [
                                              Text(
                                                'UCASH',
                                                style: context.h1.copyWith(
                                                  color: AppTheme.textPrimary,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              context.verticalSpace(
                                                  mobile: 6,
                                                  tablet: 8,
                                                  desktop: 10),
                                              Text(
                                                l10n.modernSecureTransfer,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge
                                                    ?.copyWith(
                                                      color: AppTheme
                                                          .textSecondary,
                                                    ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),

                                  context.verticalSpace(
                                      mobile: 32, tablet: 36, desktop: 40),

                                  // Champs de connexion modernes
                                  ModernTextField(
                                    label: l10n.username,
                                    hint: l10n.enterUsername,
                                    controller: _usernameController,
                                    prefixIcon: Icons.person_outline,
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n.pleaseEnterUsername;
                                      }
                                      return null;
                                    },
                                  ),

                                  context.verticalSpace(
                                      mobile: 16, tablet: 18, desktop: 20),

                                  ModernTextField(
                                    label: l10n.password,
                                    hint: l10n.enterPassword,
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    prefixIcon: Icons.lock_outline,
                                    suffixIcon: _obscurePassword
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                    onSuffixIconTap: () {
                                      setState(() {
                                        _obscurePassword = !_obscurePassword;
                                      });
                                    },
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return l10n.pleaseEnterPassword;
                                      }
                                      return null;
                                    },
                                  ),

                                  context.verticalSpace(
                                      mobile: 12, tablet: 14, desktop: 16),

                                  // Se souvenir de moi
                                  Row(
                                    children: [
                                      Transform.scale(
                                        scale: 1.2,
                                        child: Checkbox(
                                          value: _rememberMe,
                                          onChanged: (value) {
                                            setState(() {
                                              _rememberMe = value ?? false;
                                            });
                                          },
                                          activeColor: AppTheme.primaryRed,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: AppTheme.spacing8),
                                      Text(
                                        l10n.rememberMe,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: AppTheme.spacing32),

                                  // Bouton de connexion moderne
                                  SizedBox(
                                    width: double.infinity,
                                    child: ModernButton(
                                      text: l10n.login,
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      isLoading: _isLoading,
                                      icon: Icons.login,
                                      style: ModernButtonStyle.primary,
                                    ),
                                  ),

                                  const SizedBox(height: AppTheme.spacing24),

                                  // Liens d'accès rapide
                                  if (context.isSmallScreen)
                                    Column(
                                      children: [
                                        SizedBox(
                                          width: double.infinity,
                                          child: ModernButton(
                                            text: l10n.agentLogin,
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                  context, '/agent-login');
                                            },
                                            style: ModernButtonStyle.outline,
                                          ),
                                        ),
                                        context.verticalSpace(
                                            mobile: 12,
                                            tablet: 14,
                                            desktop: 16),
                                        SizedBox(
                                          width: double.infinity,
                                          child: ModernButton(
                                            text: l10n.clientLogin,
                                            onPressed: () {
                                              Navigator.pushNamed(
                                                  context, '/client-login');
                                            },
                                            style: ModernButtonStyle.ghost,
                                          ),
                                        ),
                                      ],
                                    )
                                  else
                                    Wrap(
                                      alignment: WrapAlignment.center,
                                      spacing: context.fluidSpacing(
                                          mobile: 12, tablet: 16, desktop: 20),
                                      runSpacing: context.fluidSpacing(
                                          mobile: 8, tablet: 12, desktop: 16),
                                      children: [
                                        ModernButton(
                                          text: l10n.agentLogin,
                                          onPressed: () {
                                            Navigator.pushNamed(
                                                context, '/agent-login');
                                          },
                                          style: ModernButtonStyle.outline,
                                          size: const Size(140, 40),
                                        ),
                                        ModernButton(
                                          text: l10n.clientLogin,
                                          onPressed: () {
                                            Navigator.pushNamed(
                                                context, '/client-login');
                                          },
                                          style: ModernButtonStyle.ghost,
                                          size: const Size(140, 40),
                                        ),
                                      ],
                                    ),

                                  if (context.isSmallScreen) ...[
                                    context.verticalSpace(
                                        mobile: 20, tablet: 22, desktop: 24),
                                    TextButton(
                                      onPressed: _createDefaultAdmin,
                                      child: Text(
                                        l10n.createDefaultAdmin,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppTheme.textLight,
                                            ),
                                      ),
                                    ),
                                  ],

                                  // Message d'erreur moderne
                                  Consumer<AuthService>(
                                    builder: (context, authService, child) {
                                      if (authService.errorMessage != null) {
                                        return TweenAnimationBuilder<double>(
                                          duration: AppTheme.normalAnimation,
                                          tween: Tween(begin: 0.0, end: 1.0),
                                          builder: (context, value, child) {
                                            return Transform.scale(
                                              scale: value,
                                              child: Container(
                                                margin: EdgeInsets.only(
                                                    top: context.fluidSpacing(
                                                        mobile: 12,
                                                        tablet: 14,
                                                        desktop: 16)),
                                                padding: context.fluidPadding(
                                                  mobile:
                                                      const EdgeInsets.all(12),
                                                  tablet:
                                                      const EdgeInsets.all(14),
                                                  desktop:
                                                      const EdgeInsets.all(16),
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.error
                                                      .withOpacity(0.1),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          AppTheme
                                                              .radiusMedium),
                                                  border: Border.all(
                                                    color: AppTheme.error
                                                        .withOpacity(0.3),
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: AppTheme.error,
                                                      size: 20,
                                                    ),
                                                    SizedBox(
                                                        width: context
                                                            .fluidSpacing(
                                                                mobile: 6,
                                                                tablet: 8,
                                                                desktop: 10)),
                                                    Expanded(
                                                      child: Text(
                                                        authService
                                                            .errorMessage!,
                                                        style: const TextStyle(
                                                          color: AppTheme.error,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const FooterWidget(),
                ],
              ),
            ),
          ),

          // Sélecteur de langue en haut à droite
          const Positioned(
            top: 16,
            right: 16,
            child: LanguageSelector(compact: true),
          ),

          // Bouton d'aide en haut à gauche
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.9),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: IconButton(
                onPressed: () => _showBilingualHelpDialog(context),
                icon: const Icon(
                  Icons.help_outline,
                  color: AppTheme.primaryRed,
                  size: 24,
                ),
                tooltip: 'Ouvrir l\'aide',
                padding: const EdgeInsets.all(8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
