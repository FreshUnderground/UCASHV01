import 'package:flutter/material.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';
import '../models/user_model.dart';
import '../config/app_theme.dart';

class AdminManagementWidget extends StatefulWidget {
  const AdminManagementWidget({super.key});

  @override
  State<AdminManagementWidget> createState() => _AdminManagementWidgetState();
}

class _AdminManagementWidgetState extends State<AdminManagementWidget> {
  List<UserModel> _admins = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadAdmins();
  }

  Future<void> _loadAdmins() async {
    setState(() => _isLoading = true);
    try {
      // D'abord télécharger les admins depuis le serveur
      await _downloadAdminsFromServer();
      
      // Ensuite charger les admins locaux
      final admins = await LocalDB.instance.getAllAdmins();
      setState(() {
        _admins = admins;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Télécharge les admins depuis le serveur
  Future<void> _downloadAdminsFromServer() async {
    try {
      debugPrint('📥 Téléchargement des admins depuis le serveur...');
      final syncService = SyncService();
      await syncService.downloadAdmins();
      debugPrint('✅ Admins téléchargés avec succès');
    } catch (e) {
      debugPrint('⚠️ Erreur téléchargement admins (mode hors ligne ?): $e');
      // Continuer avec les données locales si le serveur n'est pas accessible
    }
  }

  /// Synchronise les admins vers le serveur
  Future<void> _syncAdminsToServer() async {
    if (_isSyncing) return;
    
    setState(() => _isSyncing = true);
    try {
      debugPrint('📤 Synchronisation des admins vers le serveur...');
      final syncService = SyncService();
      await syncService.syncAdmins();
      debugPrint('✅ Admins synchronisés avec succès');
    } catch (e) {
      debugPrint('⚠️ Erreur sync admins: $e');
      _showMessage('Sync serveur échouée. Les données seront synchronisées ultérieurement.', isError: true);
    } finally {
      setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.admin_panel_settings, 
                      color: AppTheme.primaryRed, 
                      size: 28
                    ),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Gestion des Administrateurs',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Maximum 2 administrateurs',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: _loadAdmins,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'Actualiser',
                    ),
                    const SizedBox(width: 8),
                    if (_admins.length < LocalDB.maxAdmins)
                      ElevatedButton.icon(
                        onPressed: _showCreateAdminDialog,
                        icon: const Icon(Icons.add),
                        label: Text(_admins.isEmpty ? 'Créer 1er Admin' : 'Créer Admin'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_admins.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 64,
                        color: Colors.orange,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Admin par défaut actif',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Username: admin / Password: admin123',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.withOpacity(0.3)),
                        ),
                        child: const Column(
                          children: [
                            Icon(Icons.warning_amber, color: Colors.orange, size: 32),
                            SizedBox(height: 8),
                            Text(
                              '⚠️ L\'admin par défaut sera automatiquement supprimé',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 4),
                            Text(
                              'dès que vous créerez votre premier administrateur personnalisé.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _showCreateAdminDialog,
                        icon: const Icon(Icons.person_add),
                        label: const Text('Créer votre 1er Administrateur'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryRed,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              _buildAdminsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _admins.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final admin = _admins[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryRed.withOpacity(0.1),
            child: Text(
              admin.username.substring(0, 1).toUpperCase(),
              style: const TextStyle(
                color: AppTheme.primaryRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Row(
            children: [
              Text(
                admin.username,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              if (admin.id == 1)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Principal',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (admin.nom != null && admin.nom!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Nom: ${admin.nom}'),
              ],
              if (admin.telephone != null && admin.telephone!.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text('Tél: ${admin.telephone}'),
              ],
              const SizedBox(height: 4),
              Text(
                'Créé le: ${_formatDate(admin.createdAt)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                onPressed: () => _showEditAdminDialog(admin),
                icon: const Icon(Icons.edit, color: Colors.blue),
                tooltip: 'Modifier',
              ),
              if (_admins.length > 1)
                IconButton(
                  onPressed: () => _confirmDeleteAdmin(admin),
                  icon: const Icon(Icons.delete, color: Colors.red),
                  tooltip: 'Supprimer',
                ),
            ],
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _showCreateAdminDialog() {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final nomController = TextEditingController();
    final telephoneController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: AppTheme.primaryRed),
            SizedBox(width: 8),
            Text('Créer un Administrateur'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telephoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Admins: ${_admins.length}/${LocalDB.maxAdmins}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _createAdmin(
              username: usernameController.text.trim(),
              password: passwordController.text,
              nom: nomController.text.trim(),
              telephone: telephoneController.text.trim(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryRed,
              foregroundColor: Colors.white,
            ),
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  Future<void> _createAdmin({
    required String username,
    required String password,
    required String nom,
    required String telephone,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      _showMessage('Veuillez remplir tous les champs obligatoires', isError: true);
      return;
    }

    Navigator.pop(context);

    setState(() => _isLoading = true);
    try {
      final result = await LocalDB.instance.createAdmin(
        username: username,
        password: password,
        nom: nom.isEmpty ? null : nom,
        telephone: telephone.isEmpty ? null : telephone,
      );

      if (result['success']) {
        _showMessage(result['message']);
        await _loadAdmins();
        
        // Synchroniser vers le serveur après création
        await _syncAdminsToServer();
        _showMessage('Admin créé et synchronisé avec le serveur');
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Erreur: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showEditAdminDialog(UserModel admin) {
    final usernameController = TextEditingController(text: admin.username);
    final passwordController = TextEditingController(text: admin.password);
    final nomController = TextEditingController(text: admin.nom ?? '');
    final telephoneController = TextEditingController(text: admin.telephone ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit, color: Colors.blue),
            SizedBox(width: 8),
            Text('Modifier l\'Administrateur'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: usernameController,
                decoration: const InputDecoration(
                  labelText: 'Nom d\'utilisateur *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                enabled: admin.id != 1, // Ne pas modifier le username de l'admin principal
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Mot de passe *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nomController,
                decoration: const InputDecoration(
                  labelText: 'Nom complet',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: telephoneController,
                decoration: const InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _updateAdmin(
              admin: admin,
              username: usernameController.text.trim(),
              password: passwordController.text,
              nom: nomController.text.trim(),
              telephone: telephoneController.text.trim(),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAdmin({
    required UserModel admin,
    required String username,
    required String password,
    required String nom,
    required String telephone,
  }) async {
    if (username.isEmpty || password.isEmpty) {
      _showMessage('Veuillez remplir tous les champs obligatoires', isError: true);
      return;
    }

    Navigator.pop(context);

    setState(() => _isLoading = true);
    try {
      final updatedAdmin = admin.copyWith(
        username: username,
        password: password,
        nom: nom.isEmpty ? null : nom,
        telephone: telephone.isEmpty ? null : telephone,
      );

      final result = await LocalDB.instance.updateAdmin(updatedAdmin);

      if (result['success']) {
        _showMessage(result['message']);
        await _loadAdmins();
        
        // Synchroniser vers le serveur après modification
        await _syncAdminsToServer();
        _showMessage('Admin modifié et synchronisé avec le serveur');
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Erreur: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _confirmDeleteAdmin(UserModel admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Confirmer la suppression'),
          ],
        ),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer l\'administrateur "${admin.username}" ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => _deleteAdmin(admin),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteAdmin(UserModel admin) async {
    Navigator.pop(context);

    setState(() => _isLoading = true);
    try {
      final result = await LocalDB.instance.deleteAdmin(admin.id!);

      if (result['success']) {
        _showMessage(result['message']);
        await _loadAdmins();
        
        // Synchroniser vers le serveur après suppression
        await _syncAdminsToServer();
        _showMessage('Admin supprimé et synchronisé avec le serveur');
      } else {
        _showMessage(result['message'], isError: true);
      }
    } catch (e) {
      _showMessage('Erreur: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
