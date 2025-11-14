import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/ucash_containers.dart';
import '../utils/responsive_utils.dart';

class PWAInstallPrompt extends StatefulWidget {
  const PWAInstallPrompt({super.key});

  @override
  State<PWAInstallPrompt> createState() => _PWAInstallPromptState();
}

class _PWAInstallPromptState extends State<PWAInstallPrompt>
    with SingleTickerProviderStateMixin {
  bool _isVisible = false;
  bool _canInstall = false;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    _checkInstallability();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _checkInstallability() {
    // Vérifier si l'application peut être installée
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPWAInstallability();
    });
  }

  void _checkPWAInstallability() {
    // Simuler la vérification d'installation PWA
    // En production, utiliser js interop pour vérifier beforeinstallprompt
    setState(() {
      _canInstall = true;
      _isVisible = true;
    });
    _animationController.forward();
  }

  void _installPWA() {
    // Déclencher l'installation PWA
    HapticFeedback.lightImpact();
    _showInstallDialog();
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildInstallDialog(),
    );
  }

  Widget _buildInstallDialog() {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          ResponsiveUtils.getFluidBorderRadius(context, mobile: 16, tablet: 20, desktop: 24),
        ),
      ),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: context.isSmallScreen ? double.infinity : 500,
        ),
        padding: context.fluidPadding(
          mobile: const EdgeInsets.all(20),
          tablet: const EdgeInsets.all(24),
          desktop: const EdgeInsets.all(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icône d'installation
            Container(
              padding: EdgeInsets.all(
                context.fluidSpacing(mobile: 16, tablet: 20, desktop: 24),
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.1),
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
                ),
              ),
              child: Icon(
                Icons.install_mobile,
                size: context.fluidIcon(mobile: 32, tablet: 40, desktop: 48),
                color: const Color(0xFFDC2626),
              ),
            ),
            
            context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
            
            // Titre
            Text(
              'Installer UCASH',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
              textAlign: TextAlign.center,
            ),
            
            context.verticalSpace(mobile: 12, tablet: 16, desktop: 20),
            
            // Description
            Text(
              'Installez UCASH sur votre appareil pour :\n\n'
              '• 📱 Accès rapide depuis l\'écran d\'accueil\n'
              '• 🚀 Démarrage instantané\n'
              '• 📶 Fonctionnement offline\n'
              '• 🔔 Notifications push\n'
              '• 💾 Synchronisation automatique\n'
              '• 🔒 Sécurité renforcée',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
              textAlign: TextAlign.left,
            ),
            
            context.verticalSpace(mobile: 20, tablet: 24, desktop: 28),
            
            // Boutons d'action
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _dismissInstallPrompt,
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        vertical: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
                      ),
                      side: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 12, desktop: 16),
                        ),
                      ),
                    ),
                    child: Text(
                      'Plus tard',
                      style: TextStyle(
                        fontSize: context.fluidFont(mobile: 14, tablet: 16, desktop: 18),
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                ),
                
                context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
                
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _confirmInstall,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 12, desktop: 16),
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.download,
                          size: context.fluidIcon(mobile: 16, tablet: 18, desktop: 20),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Installer',
                          style: TextStyle(
                            fontSize: context.fluidFont(mobile: 14, tablet: 16, desktop: 18),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmInstall() {
    Navigator.of(context).pop();
    _triggerPWAInstall();
  }

  void _dismissInstallPrompt() {
    Navigator.of(context).pop();
    setState(() {
      _isVisible = false;
    });
    _animationController.reverse();
  }

  void _triggerPWAInstall() {
    // Déclencher l'installation PWA native
    // En production, utiliser js interop pour appeler prompt()
    _showInstallInstructions();
  }

  void _showInstallInstructions() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                context.isSmallScreen
                    ? 'Appuyez sur "Ajouter à l\'écran d\'accueil" dans le menu de votre navigateur'
                    : 'Cliquez sur l\'icône d\'installation dans la barre d\'adresse de votre navigateur',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_canInstall || !_isVisible) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, 100 * _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: EdgeInsets.all(
                context.fluidSpacing(mobile: 16, tablet: 20, desktop: 24),
              ),
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
                ),
                child: Container(
                  padding: context.fluidPadding(
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    desktop: const EdgeInsets.all(24),
                  ),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(
                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 12, tablet: 16, desktop: 20),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Icône
                      Container(
                        padding: EdgeInsets.all(
                          context.fluidSpacing(mobile: 8, tablet: 10, desktop: 12),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 8, tablet: 10, desktop: 12),
                          ),
                        ),
                        child: Icon(
                          Icons.install_mobile,
                          color: Colors.white,
                          size: context.fluidIcon(mobile: 20, tablet: 24, desktop: 28),
                        ),
                      ),
                      
                      context.horizontalSpace(mobile: 12, tablet: 16, desktop: 20),
                      
                      // Texte
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Installer UCASH',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: context.fluidFont(mobile: 14, tablet: 16, desktop: 18),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Accès rapide et mode offline',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: context.fluidFont(mobile: 12, tablet: 14, desktop: 16),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Boutons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _dismissInstallPrompt,
                            icon: Icon(
                              Icons.close,
                              color: Colors.white.withOpacity(0.8),
                              size: context.fluidIcon(mobile: 18, tablet: 20, desktop: 22),
                            ),
                          ),
                          const SizedBox(width: 4),
                          ElevatedButton(
                            onPressed: _installPWA,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFFDC2626),
                              padding: EdgeInsets.symmetric(
                                horizontal: context.fluidSpacing(mobile: 12, tablet: 16, desktop: 20),
                                vertical: context.fluidSpacing(mobile: 8, tablet: 10, desktop: 12),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 8, desktop: 10),
                                ),
                              ),
                            ),
                            child: Text(
                              'Installer',
                              style: TextStyle(
                                fontSize: context.fluidFont(mobile: 12, tablet: 14, desktop: 16),
                                fontWeight: FontWeight.w600,
                              ),
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
        );
      },
    );
  }
}
