import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_auth_service.dart';
import '../services/connectivity_service.dart';
import '../services/agent_service.dart';
import '../services/shop_service.dart';
import 'agent_dashboard_page.dart';

class AgentLoginPage extends StatefulWidget {
  const AgentLoginPage({super.key});

  @override
  State<AgentLoginPage> createState() => _AgentLoginPageState();
}

class _AgentLoginPageState extends State<AgentLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

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
      // OPTIMISATION: Login immédiat, sync en arrière-plan
      final authService = Provider.of<AgentAuthService>(context, listen: false);
      final success = await authService.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (success && mounted) {
        // Démarrer la synchronisation en arrière-plan APRÈS login réussi
        _syncAfterLogin();
        
        // Navigation immédiate vers le dashboard
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AgentDashboardPage()),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authService.errorMessage ?? 'Erreur de connexion'),
            backgroundColor: Colors.red,
          ),
        );
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
          debugPrint('🔄 Démarrage synchronisation arrière-plan post-login agent...');
          
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
        debugPrint('⚠️ Erreur sync arrière-plan post-login agent: $e');
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

        debugPrint('✅ Agents et shops synchronisés avant login agent');
      }
    } catch (e) {
      debugPrint('⚠️ Erreur sync avant login agent: $e');
      // Continue with login even if sync fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 480;
    final isTablet = size.width > 480 && size.width <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: Stack(
        children: [
          Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
              child: Container(
                constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
                child: Card(
                  elevation: isMobile ? 4 : 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(isMobile ? 20 : 32),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo et titre
                          Container(
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              '💸',
                              style: TextStyle(fontSize: isMobile ? 40 : 48),
                            ),
                          ),
                          SizedBox(height: isMobile ? 16 : 24),
                          
                          Text(
                            'UCASH Agent',
                            style: TextStyle(
                              fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          
                          Text(
                            'Connectez-vous à votre espace agent',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.grey[600],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: isMobile ? 24 : 32),
                          
                          // Champ nom d'utilisateur
                          TextFormField(
                            controller: _usernameController,
                            decoration: InputDecoration(
                              labelText: 'Nom d\'utilisateur',
                              prefixIcon: Icon(Icons.person_outline, size: isMobile ? 20 : 24),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDC2626),
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 14 : 16,
                              ),
                            ),
                            style: TextStyle(fontSize: isMobile ? 16 : 18),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Veuillez saisir votre nom d\'utilisateur';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.next,
                          ),
                          SizedBox(height: isMobile ? 14 : 16),
                          
                          // Champ mot de passe
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Mot de passe',
                              prefixIcon: Icon(Icons.lock_outline, size: isMobile ? 20 : 24),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                  size: isMobile ? 20 : 24,
                                ),
                                onPressed: () {
                                  setState(() => _obscurePassword = !_obscurePassword);
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Color(0xFFDC2626),
                                  width: 2,
                                ),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: isMobile ? 12 : 16,
                                vertical: isMobile ? 14 : 16,
                              ),
                            ),
                            style: TextStyle(fontSize: isMobile ? 16 : 18),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Veuillez saisir votre mot de passe';
                              }
                              return null;
                            },
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleLogin(),
                          ),
                          SizedBox(height: isMobile ? 20 : 24),
                          
                          // Bouton de connexion
                          SizedBox(
                            width: double.infinity,
                            height: isMobile ? 48 : 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC2626),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 2,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      'Se connecter',
                                      style: TextStyle(
                                        fontSize: isMobile ? 16 : 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Lien vers l'admin
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pushReplacementNamed('/admin-login');
                            },
                            child: const Text(
                              'Accès Administrateur',
                              style: TextStyle(
                                color: Color(0xFFDC2626),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
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
                icon: const Icon(
                  Icons.help_outline,
                  color: Color(0xFFDC2626),
                ),
                onPressed: () {
                  _showBilingualHelpDialog(context);
                },
                tooltip: 'Aide',
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBilingualHelpDialog(BuildContext context) {
    bool isEnglish = false;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Expanded(
                child: Text(isEnglish ? 'Help - Agent Login' : 'Aide - Connexion Agent'),
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
            child: Text(isEnglish ? _getEnglishHelpText() : _getFrenchHelpText()),
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
    return '''GUIDE COMPLET AGENT UCASH

═══════════════════════════════════════
CONNEXION ET ACCÈS
═══════════════════════════════════════
• Identifiants fournis par l'administrateur
• Nom d'utilisateur et mot de passe personnalisés
• Système de rôles et permissions par shop
• Accès conditionné par les clôtures quotidiennes

┌─────────────────────────────────────────┐
│          NAVIGATION AGENT               │
├─────────────────────────────────────────┤
│  📊 Opérations     [🔒 Clôture requise] │
│  ✅ Validations    [🔔 5 en attente]    │
│  📈 Rapports                            │
│  🚚 FLOT          [🔔 2 reçus]         │
│  💰 Frais                               │
│  📱 VIRTUEL                             │
│  🔄 Dettes Intershop                    │
│  ⚙️ Règlements                          │
│  🗑️ Suppressions                        │
└─────────────────────────────────────────┘

═══════════════════════════════════════
📊 MODULE OPÉRATIONS - Transactions quotidiennes
═══════════════════════════════════════
DÉPÔTS CLIENTS :
• Réception d'argent des clients (USD/CDF)
• Saisie du montant et informations client
• Gestion automatique des billetages
• Impression automatique des reçus
• Mise à jour temps réel du cash disponible

RETRAITS CLIENTS :
• Distribution d'argent aux clients (USD/CDF)
• Vérification des fonds disponibles
• Contrôle des billetages sortants
• Traçabilité complète des mouvements
• Alertes de seuils de liquidité

TRANSFERTS INTER-SHOPS :
• Envoi d'argent vers d'autres shops
• Calcul automatique des commissions
• Workflow de validation à deux niveaux
• Suivi en temps réel des statuts
• Notifications push des validations

BILLETAGES :
• Gestion détaillée par coupures
• Contrôle des entrées/sorties
• Équilibrage automatique
• Rapports de discordance
• Validation des montants

═══════════════════════════════════════
✅ MODULE VALIDATIONS - Traitement des demandes
═══════════════════════════════════════
TRANSFERTS EN ATTENTE :
• Liste des transferts à valider
• Vérification des fonds disponibles
• Validation/refus avec commentaires
• Notification automatique des expéditeurs
• Historique des décisions

TRANSFERTS REÇUS :
• Réception des transferts d'autres shops
• Validation de la réception
• Mise à jour automatique des soldes
• Impression des justificatifs
• Traçabilité des mouvements

WORKFLOW DE VALIDATION :
• Système à deux niveaux (admin → agent)
• Délais de traitement configurables
• Escalade automatique si retard
• Audit trail complet

═══════════════════════════════════════
📈 MODULE RAPPORTS - Analyses et clôtures
═══════════════════════════════════════
CLÔTURE QUOTIDIENNE :
• Récapitulatif complet de la journée
• Calcul automatique des soldes
• Vérification des écarts
• Export PDF des rapports
• Synchronisation serveur obligatoire

MOUVEMENTS DE CAISSE :
• Détail de tous les flux financiers
• Séparation cash/virtuel
• Analyse par devise (USD/CDF)
• Graphiques de tendances
• Comparaisons périodiques

COMMISSIONS ET FRAIS :
• Calcul automatique par type d'opération
• Répartition par shop/agent
• Suivi des performances
• Projections de revenus

═══════════════════════════════════════
🚚 MODULE FLOT - Gestion des liquidités
═══════════════════════════════════════
ENVOI DE FLOTS :
• Transfert de liquidités entre shops
• Calcul des besoins de trésorerie
• Optimisation des routes de transport
• Suivi GPS des convoyeurs
• Confirmation de réception

RÉCEPTION DE FLOTS :
• Validation des montants reçus
• Contrôle des billetages
• Mise à jour des stocks de cash
• Réconciliation automatique
• Gestion des écarts

PLANIFICATION :
• Prévision des besoins de liquidité
• Optimisation des circuits
• Alertes de rupture de stock
• Historique des mouvements

═══════════════════════════════════════
💰 MODULE FRAIS - Gestion financière
═══════════════════════════════════════
FRAIS DE SERVICE :
• Configuration par type d'opération
• Calcul automatique des montants
• Répartition entre shops/agents
• Suivi des performances
• Rapports de rentabilité

RETRAITS DE FRAIS :
• Extraction des commissions générées
• Validation hiérarchique
• Traçabilité des sorties
• Mise à jour des soldes
• Justificatifs automatiques

═══════════════════════════════════════
📱 MODULE VIRTUEL - Mobile Money
═══════════════════════════════════════
CAPTURES CLIENTS :
• Réception de paiements mobiles
• Support multi-opérateurs (Orange, Airtel, etc.)
• Conversion automatique USD/CDF
• Validation en temps réel
• Gestion des échecs de transaction

SERVICES VIRTUELS :
• Distribution de crédit mobile
• Paiement de factures
• Transferts P2P
• Recharges téléphoniques
• Services bancaires mobiles

RAPPORTS VIRTUELS :
• Statistiques par opérateur
• Analyse des volumes
• Taux de réussite des transactions
• Commissions générées
• Tendances d'utilisation

CLÔTURES PAR SIM :
• Réconciliation par carte SIM
• Soldes virtuels vs cash
• Écarts et ajustements
• Synchronisation opérateurs
• Rapports de performance

═══════════════════════════════════════
🔄 MODULE DETTES INTERSHOP - Positions financières
═══════════════════════════════════════
SUIVI DES CRÉANCES :
• Montants dus par d'autres shops
• Échéances et retards
• Relances automatiques
• Historique des paiements
• Provisions pour créances douteuses

SUIVI DES DETTES :
• Montants dus à d'autres shops
• Planification des remboursements
• Négociation des délais
• Alertes d'échéances
• Impact sur la trésorerie

POSITIONS NETTES :
• Calcul automatique des soldes
• Compensation des flux croisés
• Optimisation des règlements
• Tableaux de bord temps réel
• Analyses de risque

═══════════════════════════════════════
⚙️ MODULE RÈGLEMENTS TRIANGULAIRES - Optimisation
═══════════════════════════════════════
COMPENSATION DE DETTES :
• Identification des opportunités
• Calcul des gains d'optimisation
• Proposition automatique de circuits
• Validation multi-parties
• Exécution sécurisée

WORKFLOW TRIANGULAIRE :
• Shop A doit à Shop C
• Shop B doit à Shop A
• Shop B paie directement Shop C
• Réduction des flux physiques
• Économies de transport

═══════════════════════════════════════
🗑️ MODULE SUPPRESSIONS - Gestion des erreurs
═══════════════════════════════════════

┌─────────────────────────────────────────┐
│       WORKFLOW SUPPRESSION SÉCURISÉE   │
├─────────────────────────────────────────┤
│ ADMIN → VALIDATION → AGENT → EXÉCUTION │
│   │         │         │         │      │
│   ▼         ▼         ▼         ▼      │
│ Demande   Contrôle  Validation  Suppres│
│ Justif.   Cohérence  Finale    sion    │
│ EN_ATTENTE ADMIN_VAL AGENT_VAL EXÉCUTÉE│
└─────────────────────────────────────────┘

DEMANDES DE SUPPRESSION :
• Workflow à deux niveaux (admin → agent)
• Justification obligatoire
• Traçabilité complète
• Sauvegarde en corbeille
• Possibilité de restauration

VALIDATION AGENT :
• Vérification des demandes admin
• Contrôle de cohérence
• Validation/refus motivé
• Notification automatique
• Audit des décisions

TYPES SUPPORTÉS :
• Opérations classiques (dépôts, retraits, transferts)
• Transactions virtuelles (captures, services)
• Mouvements de flot
• Écritures comptables

═══════════════════════════════════════
SYSTÈME DE CLÔTURES
═══════════════════════════════════════
VÉRIFICATION AUTOMATIQUE :
• Contrôle avant accès aux menus sensibles
• Blocage préventif si clôtures manquantes
• Workflow de régularisation
• Synchronisation obligatoire

MENUS CONCERNÉS :
• Opérations (index 0)
• Validations (index 1)  
• FLOT (index 3)

═══════════════════════════════════════
PREMIÈRE UTILISATION
═══════════════════════════════════════
1. Connexion avec identifiants fournis
2. Vérification des clôtures en retard
3. Régularisation si nécessaire
4. Exploration progressive des modules
5. Formation sur les workflows métier
6. Test des fonctionnalités principales
7. Configuration des préférences

═══════════════════════════════════════
SUPPORT ET ASSISTANCE
═══════════════════════════════════════
• Documentation contextuelle dans chaque module
• Tooltips et guides intégrés
• Hotline administrateur
• Formation continue
• Mises à jour automatiques
• Sauvegarde cloud sécurisée''';
  }

  String _getEnglishHelpText() {
    return '''COMPLETE UCASH AGENT GUIDE

═══════════════════════════════════════
LOGIN AND ACCESS
═══════════════════════════════════════
• Credentials provided by administrator
• Custom username and password
• Role and permission system per shop
• Access conditional on daily closures

┌─────────────────────────────────────────┐
│           AGENT NAVIGATION              │
├─────────────────────────────────────────┤
│  📊 Operations     [🔒 Closure needed]  │
│  ✅ Validations    [🔔 5 pending]       │
│  📈 Reports                             │
│  🚚 FLOT          [🔔 2 received]      │
│  💰 Fees                                │
│  📱 VIRTUAL                             │
│  🔄 Intershop Debts                     │
│  ⚙️ Settlements                         │
│  🗑️ Deletions                           │
└─────────────────────────────────────────┘

═══════════════════════════════════════
📊 OPERATIONS MODULE - Daily transactions
═══════════════════════════════════════
CLIENT DEPOSITS:
• Receiving money from clients (USD/CDF)
• Amount entry and client information
• Automatic cash denomination management
• Automatic receipt printing
• Real-time cash available updates

CLIENT WITHDRAWALS:
• Cash distribution to clients (USD/CDF)
• Available funds verification
• Outgoing cash denomination control
• Complete movement traceability
• Liquidity threshold alerts

INTER-SHOP TRANSFERS:
• Money transfers to other shops
• Automatic commission calculation
• Two-level validation workflow
• Real-time status tracking
• Push notifications for validations

CASH DENOMINATIONS:
• Detailed management by bills/coins
• Input/output control
• Automatic balancing
• Discrepancy reports
• Amount validation

═══════════════════════════════════════
✅ VALIDATIONS MODULE - Request processing
═══════════════════════════════════════
PENDING TRANSFERS:
• List of transfers to validate
• Available funds verification
• Validation/rejection with comments
• Automatic sender notifications
• Decision history

RECEIVED TRANSFERS:
• Reception of transfers from other shops
• Reception validation
• Automatic balance updates
• Receipt printing
• Movement traceability

VALIDATION WORKFLOW:
• Two-level system (admin → agent)
• Configurable processing delays
• Automatic escalation if delayed
• Complete audit trail

═══════════════════════════════════════
📈 REPORTS MODULE - Analysis and closures
═══════════════════════════════════════
DAILY CLOSURE:
• Complete day summary
• Automatic balance calculation
• Discrepancy verification
• PDF report export
• Mandatory server synchronization

CASH MOVEMENTS:
• Detail of all financial flows
• Cash/virtual separation
• Analysis by currency (USD/CDF)
• Trend charts
• Period comparisons

COMMISSIONS AND FEES:
• Automatic calculation by operation type
• Distribution by shop/agent
• Performance tracking
• Revenue projections

═══════════════════════════════════════
🚚 FLOT MODULE - Liquidity management
═══════════════════════════════════════
SENDING FLOTS:
• Liquidity transfers between shops
• Treasury needs calculation
• Transport route optimization
• Courier GPS tracking
• Reception confirmation

RECEIVING FLOTS:
• Received amount validation
• Cash denomination control
• Cash stock updates
• Automatic reconciliation
• Discrepancy management

PLANNING:
• Liquidity needs forecasting
• Circuit optimization
• Stock shortage alerts
• Movement history

═══════════════════════════════════════
💰 FEES MODULE - Financial management
═══════════════════════════════════════
SERVICE FEES:
• Configuration by operation type
• Automatic amount calculation
• Distribution between shops/agents
• Performance tracking
• Profitability reports

FEE WITHDRAWALS:
• Generated commission extraction
• Hierarchical validation
• Output traceability
• Balance updates
• Automatic receipts

═══════════════════════════════════════
📱 VIRTUAL MODULE - Mobile Money
═══════════════════════════════════════
CLIENT CAPTURES:
• Mobile payment reception
• Multi-operator support (Orange, Airtel, etc.)
• Automatic USD/CDF conversion
• Real-time validation
• Transaction failure management

VIRTUAL SERVICES:
• Mobile credit distribution
• Bill payments
• P2P transfers
• Phone top-ups
• Mobile banking services

VIRTUAL REPORTS:
• Statistics by operator
• Volume analysis
• Transaction success rates
• Generated commissions
• Usage trends

SIM CLOSURES:
• Reconciliation by SIM card
• Virtual vs cash balances
• Discrepancies and adjustments
• Operator synchronization
• Performance reports

═══════════════════════════════════════
🔄 INTERSHOP DEBTS MODULE - Financial positions
═══════════════════════════════════════
RECEIVABLES TRACKING:
• Amounts owed by other shops
• Due dates and delays
• Automatic reminders
• Payment history
• Doubtful debt provisions

DEBT TRACKING:
• Amounts owed to other shops
• Repayment planning
• Deadline negotiation
• Due date alerts
• Treasury impact

NET POSITIONS:
• Automatic balance calculation
• Cross-flow compensation
• Settlement optimization
• Real-time dashboards
• Risk analysis

═══════════════════════════════════════
⚙️ TRIANGULAR SETTLEMENTS MODULE - Optimization
═══════════════════════════════════════
DEBT COMPENSATION:
• Opportunity identification
• Optimization gain calculation
• Automatic circuit proposals
• Multi-party validation
• Secure execution

TRIANGULAR WORKFLOW:
• Shop A owes Shop C
• Shop B owes Shop A
• Shop B pays Shop C directly
• Physical flow reduction
• Transport savings

═══════════════════════════════════════
🗑️ DELETIONS MODULE - Error management
═══════════════════════════════════════

┌─────────────────────────────────────────┐
│       SECURE DELETION WORKFLOW         │
├─────────────────────────────────────────┤
│ ADMIN → VALIDATION → AGENT → EXECUTION │
│   │         │         │         │      │
│   ▼         ▼         ▼         ▼      │
│ Request   Control   Final     Deletion │
│ Justify   Coherence Validation         │
│ PENDING   ADMIN_VAL AGENT_VAL EXECUTED │
└─────────────────────────────────────────┘

DELETION REQUESTS:
• Two-level workflow (admin → agent)
• Mandatory justification
• Complete traceability
• Trash bin backup
• Restoration possibility

AGENT VALIDATION:
• Admin request verification
• Consistency control
• Motivated validation/rejection
• Automatic notification
• Decision audit

SUPPORTED TYPES:
• Classic operations (deposits, withdrawals, transfers)
• Virtual transactions (captures, services)
• Flot movements
• Accounting entries

═══════════════════════════════════════
CLOSURE SYSTEM
═══════════════════════════════════════
AUTOMATIC VERIFICATION:
• Control before sensitive menu access
• Preventive blocking if closures missing
• Regularization workflow
• Mandatory synchronization

AFFECTED MENUS:
• Operations (index 0)
• Validations (index 1)
• FLOT (index 3)

═══════════════════════════════════════
FIRST USE
═══════════════════════════════════════
1. Login with provided credentials
2. Check for overdue closures
3. Regularize if necessary
4. Progressive module exploration
5. Business workflow training
6. Main functionality testing
7. Preference configuration

═══════════════════════════════════════
SUPPORT AND ASSISTANCE
═══════════════════════════════════════
• Contextual documentation in each module
• Integrated tooltips and guides
• Administrator hotline
• Continuous training
• Automatic updates
• Secure cloud backup''';
  }
}
