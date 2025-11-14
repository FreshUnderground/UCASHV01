import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../widgets/footer_widget.dart';
import '../widgets/modern_widgets.dart';
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
      final authService = Provider.of<AuthService>(context, listen: false);
      final success = await authService.login(
        _usernameController.text.trim(),
        _passwordController.text.trim(),
        rememberMe: _rememberMe,
      );

      if (success && mounted) {
        Navigator.of(context).pushReplacementNamed('/dashboard');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _createDefaultAdmin() async {
    try {
      await LocalDB.instance.forceCreateAdmin();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Admin créé/recréé ! Username: admin, Password: admin123'),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
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
                        maxWidth: ResponsiveUtils.getMaxContainerWidth(context),
                      ),
                      child: context.adaptiveCard(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header moderne avec animation
                              TweenAnimationBuilder<double>(
                                duration: const Duration(milliseconds: 800),
                                tween: Tween(begin: 0.0, end: 1.0),
                                curve: AppTheme.bounceCurve,
                                builder: (context, value, child) {
                                  final iconSize = context.fluidIcon(mobile: 64, tablet: 80, desktop: 100);
                                  return Transform.scale(
                                    scale: value,
                                    child: Container(
                                      width: iconSize,
                                      height: iconSize,
                                      decoration: BoxDecoration(
                                        gradient: AppTheme.primaryGradient,
                                        borderRadius: BorderRadius.circular(context.fluidBorderRadius()),
                                        boxShadow: AppTheme.mediumShadow,
                                      ),
                                      child: Icon(
                                        Icons.account_balance_wallet,
                                        color: Colors.white,
                                        size: context.fluidIcon(mobile: 32, tablet: 40, desktop: 48),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              context.verticalSpace(mobile: 24, tablet: 28, desktop: 32),
                              
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
                                          context.verticalSpace(mobile: 6, tablet: 8, desktop: 10),
                                          Text(
                                            'Transfert d\'argent moderne et sécurisé',
                                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                              
                              context.verticalSpace(mobile: 32, tablet: 36, desktop: 40),
                              
                              // Champs de connexion modernes
                              ModernTextField(
                                label: 'Nom d\'utilisateur',
                                hint: 'Entrez votre nom d\'utilisateur',
                                controller: _usernameController,
                                prefixIcon: Icons.person_outline,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez saisir votre nom d\'utilisateur';
                                  }
                                  return null;
                                },
                              ),
                              
                              context.verticalSpace(mobile: 16, tablet: 18, desktop: 20),
                              
                              ModernTextField(
                                label: 'Mot de passe',
                                hint: 'Entrez votre mot de passe',
                                controller: _passwordController,
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline,
                                suffixIcon: _obscurePassword ? Icons.visibility : Icons.visibility_off,
                                onSuffixIconTap: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Veuillez saisir votre mot de passe';
                                  }
                                  return null;
                                },
                              ),
                              
                              context.verticalSpace(mobile: 12, tablet: 14, desktop: 16),
                              
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
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppTheme.spacing8),
                                  Text(
                                    'Se souvenir de moi',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                                  text: 'Se connecter',
                                  onPressed: _isLoading ? null : _handleLogin,
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
                                        text: 'Connexion Agent',
                                        onPressed: () {
                                          Navigator.pushNamed(context, '/agent-login');
                                        },
                                        style: ModernButtonStyle.outline,
                                      ),
                                    ),
                                    context.verticalSpace(mobile: 12, tablet: 14, desktop: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ModernButton(
                                        text: 'Connexion Client',
                                        onPressed: () {
                                          Navigator.pushNamed(context, '/client-login');
                                        },
                                        style: ModernButtonStyle.ghost,
                                      ),
                                    ),
                                  ],
                                )
                              else
                                Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
                                  runSpacing: context.fluidSpacing(mobile: 8, tablet: 12, desktop: 16),
                                  children: [
                                    ModernButton(
                                      text: 'Connexion Agent',
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/agent-login');
                                      },
                                      style: ModernButtonStyle.outline,
                                      size: const Size(140, 40),
                                    ),
                                    ModernButton(
                                      text: 'Connexion Client',
                                      onPressed: () {
                                        Navigator.pushNamed(context, '/client-login');
                                      },
                                      style: ModernButtonStyle.ghost,
                                      size: const Size(140, 40),
                                    ),
                                  ],
                                ),
                              
                              if (context.isSmallScreen) ...[
                                context.verticalSpace(mobile: 20, tablet: 22, desktop: 24),
                                TextButton(
                                  onPressed: _createDefaultAdmin,
                                  child: Text(
                                    'Créer Admin par défaut',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                                            margin: EdgeInsets.only(top: context.fluidSpacing(mobile: 12, tablet: 14, desktop: 16)),
                                            padding: context.fluidPadding(
                                              mobile: const EdgeInsets.all(12),
                                              tablet: const EdgeInsets.all(14),
                                              desktop: const EdgeInsets.all(16),
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppTheme.error.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
                                              border: Border.all(
                                                color: AppTheme.error.withOpacity(0.3),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.error_outline,
                                                  color: AppTheme.error,
                                                  size: 20,
                                                ),
                                                SizedBox(width: context.fluidSpacing(mobile: 6, tablet: 8, desktop: 10)),
                                                Expanded(
                                                  child: Text(
                                                    authService.errorMessage!,
                                                    style: TextStyle(
                                                      color: AppTheme.error,
                                                      fontWeight: FontWeight.w500,
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
    );
  }
}
