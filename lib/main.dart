import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/local_db.dart';
import 'services/shop_service.dart';
import 'services/agent_service.dart';
import 'services/client_service.dart';
import 'services/transaction_service.dart';
import 'services/operation_service.dart';
import 'services/rates_service.dart';
import 'services/report_service.dart';
import 'services/sync_service.dart'; // Add this import
import 'services/flot_service.dart';
import 'pages/login_page.dart';
import 'pages/agent_login_page.dart';
import 'pages/client_login_page.dart';
import 'pages/dashboard_admin.dart';
import 'pages/dashboard_agent.dart';
import 'pages/dashboard_compte.dart';
import 'pages/agent_dashboard_page.dart';
import 'pages/client_dashboard_page.dart';
import 'pages/reports_page.dart';
import 'config/app_config.dart';
import 'config/app_theme.dart';

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
  
  // Initialiser et vérifier l'admin par défaut (PROTÉGÉ)
  await LocalDB.instance.initializeDefaultAdmin();
  await LocalDB.instance.ensureAdminExists();
  
  // Initialize the sync service
  final syncService = SyncService();
  await syncService.initialize();
  
  // Configuration de production
  AppConfig.logInfo('UCASH ${AppConfig.appVersion} - Démarrage en mode ${AppConfig.isProduction ? 'PRODUCTION' : 'DEBUG'}');
  AppConfig.logConfig();  // Afficher la configuration complète
  
  runApp(const UCashApp());
}

class UCashApp extends StatelessWidget {
  const UCashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => ShopService.instance),
        ChangeNotifierProvider(create: (_) => AgentService.instance),
        ChangeNotifierProvider(create: (_) => ClientService()),
        ChangeNotifierProvider(create: (_) => TransactionService()),
        ChangeNotifierProvider(create: (_) => OperationService()),
        ChangeNotifierProvider(create: (_) => RatesService.instance),
        ChangeNotifierProvider(create: (_) => ReportService()),
        ChangeNotifierProvider(create: (_) => FlotService.instance),
      ],
      child: MaterialApp(
        title: 'UCASH - Transfert d\'Argent Moderne',
        debugShowCheckedModeBanner: false,
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
      ),
    );
  }
}