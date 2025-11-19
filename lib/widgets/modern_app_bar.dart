import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;

  const ModernAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 20,
        ),
      ),
      actions: [
        if (actions != null) ...actions!,
        PopupMenuButton<String>(
          icon: const CircleAvatar(
            backgroundColor: Colors.transparent,
            child: Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 32,
            ),
          ),
          onSelected: (value) {
            if (value == 'logout') {
              _handleLogout(context);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: ListTile(
                leading: Icon(Icons.person, size: 20),
                title: Text('Profil'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: ListTile(
                leading: Icon(Icons.logout, size: 20, color: Colors.red),
                title: Text('Déconnexion', style: TextStyle(color: Colors.red)),
              ),
            ),
          ],
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
            ],
          ),
        ),
      ),
      elevation: 0,
      centerTitle: false,
    );
  }

  void _handleLogout(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    authService.logout();
    
    // Navigate to login screen
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}