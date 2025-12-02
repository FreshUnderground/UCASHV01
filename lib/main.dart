import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'services/auth_service.dart';
import 'services/language_service.dart';
import 'services/local_db.dart';
import 'services/shop_service.dart';
import 'services/agent_service.dart';
import 'services/client_service.dart';
import 'services/transaction_service.dart';
import 'services/operation_service.dart';
import 'services/rates_service.dart';
import 'services/report_service.dart';
import 'services/sync_service.dart';
import 'services/transfer_notification_service.dart';
import 'services/flot_notification_service.dart';
import 'services/flot_service.dart';
import 'services/document_header_service.dart';
import 'services/transfer_sync_service.dart';
import 'services/depot_retrait_sync_service.dart';
import 'services/compte_special_service.dart';
import 'services/robust_sync_service.dart';
import 'services/connectivity_service.dart';
import 'services/sim_service.dart';
import 'services/virtual_transaction_service.dart';
import 'services/deletion_service.dart';
import 'pages/login_page.dart';
import 'pages/agent_login_page.dart';
import 'pages/client_login_page.dart';
import 'pages/dashboard_admin.dart';
import 'pages/dashboard_agent.dart';
import 'pages/dashboard_compte.dart';
import 'pages/agent_dashboard_page.dart';
import 'pages/client_dashboard_page.dart';
import 'pages/reports_page.dart';
import 'pages/language_settings_page.dart';
import 'pages/bilingual_usage_example_page.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';
import 'widgets/loading_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Configuration de la barre de statut pour une apparence moderne
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(const UCashApp());
}

class UCashApp extends StatefulWidget {
  const UCashApp({super.key});

  @override
  State<UCashApp> createState() => _UCashAppState();
}

class _UCashAppState extends State<UCashApp> {
  bool _isInitialized = false;
  String _loadingMessage = 'Démarrage de l\'application...';
  double _loadingProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Update loading state
      _updateLoadingState('Initialisation de la base de données...', 0.1);

      // Initialiser le service de langue (doit être fait en premier)
      final languageService = LanguageService.instance;
      await languageService.initialize();
      debugPrint('✅ LanguageService initialisé - Langue: ${languageService.currentLanguageName}');

      // Initialiser et vérifier l'admin par défaut (PROTÉGÉ)
      await LocalDB.instance.initializeDefaultAdmin();
      await LocalDB.instance.ensureAdminExists();
      
      _updateLoadingState('Initialisation des services de base...', 0.2);

      // Initialize the sync service (base uniquement, pas de sync auto)
      final syncService = SyncService();
      await syncService.initialize();
      
      _updateLoadingState('Démarrage de la synchronisation...', 0.3);

      // Initialize RobustSyncService (synchronisation automatique)
      debugPrint('🚀 Initialisation de RobustSyncService...');
      final robustSyncService = RobustSyncService();
      await robustSyncService.initialize();
      debugPrint('✅ RobustSyncService initialisé');
      
      _updateLoadingState('Initialisation du service de connectivité...', 0.4);

      // Initialize ConnectivityService
      final connectivityService = ConnectivityService.instance;
      connectivityService.startMonitoring();
      
      // Initialize DeletionService et démarrer l'auto-sync (toutes les 2 minutes)
      debugPrint('🗑️ Initialisation de DeletionService...');
      final deletionService = DeletionService.instance;
      deletionService.startAutoSync();
      debugPrint('✅ DeletionService initialisé avec auto-sync activé');
      
      _updateLoadingState('Chargement des données initiales...', 0.5);

      // Initialize the document header service
      final documentHeaderService = DocumentHeaderService();
      await documentHeaderService.initialize();
      
      _updateLoadingState('Chargement des shops...', 0.6);

      // Charger les données initiales (shops, agents, rates) - en parallèle
      await Future.wait([
        ShopService.instance.loadShops().then((_) {
          _updateLoadingState('Chargement des agents...', 0.7);
        }),
        AgentService.instance.loadAgents().then((_) {
          _updateLoadingState('Chargement des taux...', 0.8);
        }),
        RatesService.instance.loadRatesAndCommissions().then((_) {
          _updateLoadingState('Finalisation...', 0.9);
        }),
      ]);
      
      debugPrint('✅ Données initiales chargées');
      
      // Configuration de production
      AppConfig.logInfo('UCASH ${AppConfig.appVersion} - Démarrage en mode ${AppConfig.isProduction ? 'PRODUCTION' : 'DEBUG'}');
      AppConfig.logConfig();  // Afficher la configuration complète
      
      _updateLoadingState('Prêt !', 1.0);
      
      // Small delay to show completion
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      debugPrint('❌ Erreur d\'initialisation: $e');
      // Even if there's an error, we still want to show the app
      setState(() {
        _isInitialized = true;
      });
    }
  }

  void _updateLoadingState(String message, double progress) {
    setState(() {
      _loadingMessage = message;
      _loadingProgress = progress;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: LoadingScreen(
          message: _loadingMessage,
          progress: _loadingProgress,
        ),
        theme: AppTheme.lightTheme,
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => LanguageService.instance),
        ChangeNotifierProvider(create: (_) => ShopService.instance),
        ChangeNotifierProvider(create: (_) => AgentService.instance),
        ChangeNotifierProvider(create: (_) => ClientService()),
        ChangeNotifierProvider(create: (_) => TransactionService()),
        ChangeNotifierProvider(create: (_) => OperationService()),
        ChangeNotifierProvider(create: (_) => RatesService.instance),
        ChangeNotifierProvider(create: (_) => ReportService()),
        ChangeNotifierProvider(create: (_) => FlotService.instance),
        ChangeNotifierProvider(create: (_) => TransferNotificationService()),
        ChangeNotifierProvider(create: (_) => FlotNotificationService()),
        ChangeNotifierProvider(create: (_) => DocumentHeaderService()),
        ChangeNotifierProvider(create: (_) => TransferSyncService()),
        ChangeNotifierProvider(create: (_) => DepotRetraitSyncService()),
        ChangeNotifierProvider(create: (_) => CompteSpecialService.instance),
        ChangeNotifierProvider(create: (_) => ConnectivityService.instance),
        ChangeNotifierProvider(create: (_) => SimService.instance),
        ChangeNotifierProvider(create: (_) => VirtualTransactionService.instance),
        ChangeNotifierProvider(create: (_) => DeletionService.instance),
      ],
      child: Builder(
        builder: (context) {
          return MaterialApp(
            title: 'UCASH - Transfert d\'Argent Moderne',
            debugShowCheckedModeBanner: false,
            
            // Configuration de la localisation
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: LanguageService.supportedLocales,
            locale: context.watch<LanguageService>().currentLocale,
        
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.light, // Peut être changé dynamiquement
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaleFactor: MediaQuery.of(context).textScaleFactor.clamp(0.8, 1.2),
            ),
            child: child!,
          );
        },
        home: Consumer<AuthService>(
          builder: (context, authService, child) {
            if (authService.isAuthenticated) {
              // Si c'est un client connecté
              if (authService.currentClient != null) {
                return const ClientDashboardPage();
              }
              
              // Si c'est un utilisateur (admin/agent) connecté
              final user = authService.currentUser!;
              switch (user.role) {
                case 'ADMIN':
                  return const DashboardAdminPage();
                case 'AGENT':
                  return const DashboardAgentPage();
                case 'COMPTE':
                  return const DashboardComptePage();
                default:
                  return const LoginPage();
              }
            }
            return const LoginPage();
          },
        ),
        routes: {
          '/login': (context) => const LoginPage(),
          '/agent-login': (context) => const AgentLoginPage(),
          '/client-login': (context) => const ClientLoginPage(),
          '/admin-login': (context) => const LoginPage(), // This should be LoginPage for admin
          '/agent-dashboard': (context) => const AgentDashboardPage(),
          '/client-dashboard': (context) => const ClientDashboardPage(),
          '/reports': (context) => const ReportsPage(),
          '/language-settings': (context) => const LanguageSettingsPage(),
          '/bilingual-example': (context) => const BilingualUsageExamplePage(),
          '/dashboard': (context) => Consumer<AuthService>(
            builder: (context, authService, child) {
              if (!authService.isAuthenticated) {
                return const LoginPage();
              }
              
              // Si c'est un client connecté
              if (authService.currentClient != null) {
                return const ClientDashboardPage();
              }
              
              final user = authService.currentUser!;
              switch (user.role) {
                case 'ADMIN':
                  return const DashboardAdminPage();
                case 'AGENT':
                  return const DashboardAgentPage();
                case 'COMPTE':
                  return const DashboardComptePage();
                default:
                  return const LoginPage();
              }
            },
          ),
        },
          );
        },
      ),
    );
  }
}