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

    // Sync agents and shops before login if online
    await _syncBeforeLogin();

    final authService = Provider.of<AgentAuthService>(context, listen: false);
    final success = await authService.login(
      _usernameController.text.trim(),
      _passwordController.text,
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
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
  }

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
      body: Center(
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
    );
  }
}
