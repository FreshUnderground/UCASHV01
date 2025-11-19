import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../widgets/connectivity_indicator.dart';
import 'client_dashboard_page.dart';

class ClientLoginPage extends StatefulWidget {
  const ClientLoginPage({super.key});

  @override
  State<ClientLoginPage> createState() => _ClientLoginPageState();
}

class _ClientLoginPageState extends State<ClientLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 480;
    final isTablet = size.width > 480 && size.width <= 768;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Stack(
          children: [
            // Indicateur de connectivité
            const Positioned(
              top: 16,
              right: 16,
              child: ConnectivityIndicator(),
            ),
            
            // Contenu principal
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(isMobile ? 16 : isTablet ? 24 : 32),
                child: Container(
                  width: isMobile ? double.infinity : 400,
                  constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 400),
                  child: Card(
                    elevation: isMobile ? 4 : 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isMobile ? 20 : 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Logo et titre
                          Container(
                            width: isMobile ? 70 : 80,
                            height: isMobile ? 70 : 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(isMobile ? 12 : 16),
                            ),
                            child: Center(
                              child: Text(
                                '💸',
                                style: TextStyle(fontSize: isMobile ? 35 : 40),
                              ),
                            ),
                          ),
                          SizedBox(height: isMobile ? 16 : 24),
                          
                          Text(
                            'UCASH',
                            style: TextStyle(
                              fontSize: isMobile ? 24 : 28,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          SizedBox(height: isMobile ? 6 : 8),
                          
                          Text(
                            'Espace Partenaire',
                            style: TextStyle(
                              fontSize: isMobile ? 14 : 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: isMobile ? 24 : 32),
                          
                          // Formulaire de connexion
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                // Nom d'utilisateur
                                TextFormField(
                                  controller: _usernameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nom d\'utilisateur',
                                    hintText: 'Votre nom d\'utilisateur',
                                    prefixIcon: Icon(Icons.person_outline, size: isMobile ? 20 : 24),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFDC2626)),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: isMobile ? 12 : 16,
                                      vertical: isMobile ? 14 : 16,
                                    ),
                                  ),
                                  style: TextStyle(fontSize: isMobile ? 16 : 18),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez saisir votre nom d\'utilisateur';
                                    }
                                    return null;
                                  },
                                ),
                                SizedBox(height: isMobile ? 14 : 16),
                                
                                // Mot de passe
                                TextFormField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    hintText: 'Votre mot de passe',
                                    prefixIcon: Icon(Icons.lock_outline, size: isMobile ? 20 : 24),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        size: isMobile ? 20 : 24,
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.grey[300]!),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(color: Color(0xFFDC2626)),
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
                                ),
                                SizedBox(height: isMobile ? 12 : 16),
                                
                                // Se souvenir de moi
                                Row(
                                  children: [
                                    Checkbox(
                                      value: _rememberMe,
                                      onChanged: (value) {
                                        setState(() {
                                          _rememberMe = value ?? false;
                                        });
                                      },
                                      activeColor: const Color(0xFFDC2626),
                                    ),
                                    const Text('Se souvenir de moi'),
                                  ],
                                ),
                                SizedBox(height: isMobile ? 20 : 24),
                                
                                // Bouton de connexion
                                Consumer<AuthService>(
                                  builder: (context, authService, child) {
                                    return SizedBox(
                                      width: double.infinity,
                                      height: isMobile ? 48 : 50,
                                      child: ElevatedButton(
                                        onPressed: authService.isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFFDC2626),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          elevation: 2,
                                        ),
                                        child: authService.isLoading
                                            ? const SizedBox(
                                                width: 20,
                                                height: 20,
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
                                    );
                                  },
                                ),
                                
                                // Message d'erreur
                                Consumer<AuthService>(
                                  builder: (context, authService, child) {
                                    if (authService.errorMessage != null) {
                                      return Container(
                                        margin: const EdgeInsets.only(top: 16),
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red[50],
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: Colors.red[200]!),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                authService.errorMessage!,
                                                style: TextStyle(color: Colors.red[700]),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // Liens utiles
                          Column(
                            children: [
                              TextButton(
                                onPressed: _showForgotPasswordDialog,
                                child: const Text(
                                  'Mot de passe oublié ?',
                                  style: TextStyle(color: Color(0xFFDC2626)),
                                ),
                              ),
                              
                              const Divider(),
                              
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacementNamed('/login');
                                },
                                child: const Text(
                                  'Connexion Agent/Admin',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final clientService = Provider.of<ClientService>(context, listen: false);
    
    // Authentifier le client
    final success = await authService.loginClient(
      username: _usernameController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (success && mounted) {
      // Charger les données du client
      await clientService.loadClients();
      
      // Naviguer vers le dashboard client
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => const ClientDashboardPage(),
        ),
      );
    }
  }

  void _showForgotPasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mot de passe oublié'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pour récupérer votre mot de passe :'),
            SizedBox(height: 16),
            Text('1. Rendez-vous dans votre shop UCASH'),
            Text('2. Présentez une pièce d\'identité'),
            Text('3. L\'agent pourra réinitialiser votre mot de passe'),
            SizedBox(height: 16),
            Text(
              'Ou contactez le support partenaire au +243 XXX XXX XXX',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }
}
