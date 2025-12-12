import 'package:flutter/material.dart';
import '../services/sync_service.dart';
import '../config/app_config.dart';

/// Widget de configuration de la synchronisation
/// Permet d'activer/désactiver l'auto-sync et de configurer l'URL du serveur
class SyncConfigWidget extends StatefulWidget {
  const SyncConfigWidget({super.key});

  @override
  State<SyncConfigWidget> createState() => _SyncConfigWidgetState();
}

class _SyncConfigWidgetState extends State<SyncConfigWidget> {
  final SyncService _syncService = SyncService();
  bool _autoSyncEnabled = false;
  bool _isSyncing = false;
  String _customApiUrl = '';
  final _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCurrentSettings();
    _listenToSyncStatus();
  }

  Future<void> _loadCurrentSettings() async {
    // Charger l'URL personnalisée
    _customApiUrl = await AppConfig.getApiBaseUrl();
    _urlController.text = _customApiUrl;
    
    // Charger l'état de l'auto-sync
    setState(() {
      _autoSyncEnabled = _syncService.isAutoSyncEnabled;
    });
  }

  void _listenToSyncStatus() {
    _syncService.syncStatusStream.listen((status) {
      if (mounted) {
        setState(() {
          _isSyncing = status == SyncStatus.syncing;
        });
      }
    });
  }

  Future<void> _saveCustomUrl() async {
    final newUrl = _urlController.text.trim();
    if (newUrl.isEmpty) return;
    
    await AppConfig.setCustomApiUrl(newUrl);
    
    if (mounted) {
      setState(() {
        _customApiUrl = newUrl;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ URL du serveur sauvegardée'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _resetToDefault() async {
    await AppConfig.resetToDefaultApiUrl();
    _urlController.text = AppConfig.apiBaseUrl;
    
    if (mounted) {
      setState(() {
        _customApiUrl = AppConfig.apiBaseUrl;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🔄 URL réinitialisée à la valeur par défaut'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    setState(() {
      _autoSyncEnabled = value;
    });
    
    _syncService.setAutoSync(value);
    
    if (value) {
      _syncService.startAutoSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Synchronisation automatique activée (30s)'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _syncService.stopAutoSync();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⏸️ Synchronisation automatique désactivée'),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _manualSync() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final result = await _syncService.syncAll();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success ? '✅ ${result.message}' : '❌ ${result.message}'),
            backgroundColor: result.success ? Colors.green : Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.sync,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Configuration Synchronisation',
                  style: TextStyle(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            // Configuration de l'URL du serveur
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'URL du Serveur',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Configurez l\'URL du serveur de synchronisation',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _urlController,
                          decoration: const InputDecoration(
                            hintText: 'https://mahanaimeservice.investee-group.com/server/api',
                            prefixIcon: Icon(Icons.link),
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _saveCustomUrl,
                        icon: const Icon(Icons.save, color: Colors.green),
                        tooltip: 'Sauvegarder l\'URL',
                      ),
                      IconButton(
                        onPressed: _resetToDefault,
                        icon: const Icon(Icons.refresh, color: Colors.orange),
                        tooltip: 'Réinitialiser',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'URL actuelle: $_customApiUrl',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Auto-sync toggle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Synchronisation Automatique',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _autoSyncEnabled
                              ? 'Activée - Sync toutes les 30 secondes'
                              : 'Désactivée - Mode offline uniquement',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _autoSyncEnabled,
                    onChanged: _isSyncing ? null : _toggleAutoSync,
                    activeColor: const Color(0xFFDC2626),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Sync manuelle
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Synchronisation Manuelle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Lancez une synchronisation immédiate avec le serveur',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSyncing ? null : _manualSync,
                      icon: _isSyncing
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.sync, size: 20),
                      label: Text(
                        _isSyncing ? 'Synchronisation...' : 'Synchroniser Maintenant',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Mode offline-first: Toutes les opérations sont sauvegardées localement et synchronisées automatiquement quand le serveur est disponible.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.orange.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}