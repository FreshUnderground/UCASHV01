import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/rates_service.dart';
import '../services/sync_service.dart';
import '../models/taux_model.dart';

class AgentTauxWidget extends StatefulWidget {
  const AgentTauxWidget({super.key});

  @override
  State<AgentTauxWidget> createState() => _AgentTauxWidgetState();
}

class _AgentTauxWidgetState extends State<AgentTauxWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<RatesService>(context, listen: false).loadRatesAndCommissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 24),
          Expanded(child: _buildTauxList()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF9800).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.currency_exchange,
                color: Color(0xFFFF9800),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gestion des Taux de Change',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Configurez les taux USD ↔ CDF/UGX pour vos opérations de change',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: _showAddTauxDialog,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nouveau Taux'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF9800),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTauxList() {
    return Consumer<RatesService>(
      builder: (context, ratesService, child) {
        if (ratesService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final tauxList = ratesService.taux;

        if (tauxList.isEmpty) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.currency_exchange_outlined,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucun taux configuré',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Cliquez sur "Nouveau Taux" pour commencer',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Liste des Taux (${tauxList.length})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tauxList.length,
                  separatorBuilder: (context, index) => const Divider(height: 24),
                  itemBuilder: (context, index) {
                    final taux = tauxList[index];
                    return _buildTauxCard(taux);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTauxCard(TauxModel taux) {
    Color typeColor;
    IconData typeIcon;
    
    switch (taux.type) {
      case 'ACHAT':
        typeColor = Colors.green;
        typeIcon = Icons.arrow_downward;
        break;
      case 'VENTE':
        typeColor = Colors.red;
        typeIcon = Icons.arrow_upward;
        break;
      case 'MOYEN':
        typeColor = Colors.blue;
        typeIcon = Icons.swap_horiz;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: typeColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              typeIcon,
              color: typeColor,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '${taux.deviseSource} → ${taux.deviseCible}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D3748),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: typeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        taux.type,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: typeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '1 ${taux.deviseSource} = ',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                    Text(
                      '${taux.taux.toStringAsFixed(2)} ${taux.deviseCible}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: typeColor,
                      ),
                    ),
                  ],
                ),
                if (taux.dateEffet != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Text(
                        'Depuis le ${DateFormat('dd/MM/yyyy').format(taux.dateEffet!)}',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditTauxDialog(taux),
            icon: const Icon(Icons.edit, color: Color(0xFFFF9800)),
            tooltip: 'Modifier',
          ),
          IconButton(
            onPressed: () => _confirmDelete(taux),
            icon: const Icon(Icons.delete, color: Color(0xFFDC2626)),
            tooltip: 'Supprimer',
          ),
        ],
      ),
    );
  }

  void _showAddTauxDialog() {
    showDialog(
      context: context,
      builder: (context) => _TauxDialog(
        onSave: (devise, taux, type) async {
          final ratesService = RatesService.instance;
          debugPrint('🔄 Création taux: $type pour $devise = $taux');
          
          // 1️⃣ ENREGISTREMENT LOCAL (prioritaire)
          final success = await ratesService.createTaux(
            devise: devise,
            taux: taux,
            type: type,
          );
          
          debugPrint(success ? '✅ Taux créé localement' : '❌ Échec création taux');
          
          if (success && mounted) {
            // 2️⃣ AFFICHAGE IMMÉDIAT (recharger depuis la base locale)
            await ratesService.loadRatesAndCommissions();
            debugPrint('🔄 Liste des taux rechargée pour affichage');
            
            // 3️⃣ SYNCHRONISATION EN ARRIÈRE-PLAN (non bloquante)
            _syncInBackground();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Taux $type créé: 1 USD = ${taux.toStringAsFixed(2)} $devise\nSynchronisation en cours...'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(ratesService.errorMessage ?? 'Échec de la création du taux'),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
      ),
    );
  }

  void _syncInBackground() {
    // Synchronisation asynchrone en arrière-plan
    Future.delayed(Duration.zero, () async {
      try {
        debugPrint('🔄 Synchronisation en arrière-plan démarrée...');
        final syncService = SyncService();
        // Synchronisation globale qui inclut les taux
        await syncService.syncAll();
        debugPrint('✅ Synchronisation terminée');
      } catch (e) {
        debugPrint('⚠️ Erreur sync (non bloquante): $e');
      }
    });
  }

  void _showEditTauxDialog(TauxModel taux) {
    showDialog(
      context: context,
      builder: (context) => _TauxDialog(
        taux: taux,
        onSave: (devise, tauxValue, type) async {
          final ratesService = RatesService.instance;
          final updatedTaux = taux.copyWith(
            deviseCible: devise,
            taux: tauxValue,
            type: type,
            dateEffet: DateTime.now(),
          );
          
          debugPrint('🔄 Mise à jour taux ID=${taux.id}: $type pour $devise = $tauxValue');
          
          // 1️⃣ MISE À JOUR LOCALE (prioritaire)
          final success = await ratesService.updateTaux(updatedTaux);
          
          debugPrint(success ? '✅ Taux mis à jour localement' : '❌ Échec mise à jour');
          
          if (success && mounted) {
            // 2️⃣ AFFICHAGE IMMÉDIAT
            await ratesService.loadRatesAndCommissions();
            debugPrint('🔄 Liste des taux rechargée pour affichage');
            
            // 3️⃣ SYNCHRONISATION EN ARRIÈRE-PLAN
            _syncInBackground();
            
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Taux $type mis à jour: 1 USD = ${tauxValue.toStringAsFixed(2)} $devise\nSynchronisation en cours...'),
                    ),
                  ],
                ),
                backgroundColor: const Color(0xFF4CAF50),
                duration: const Duration(seconds: 3),
              ),
            );
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(ratesService.errorMessage ?? 'Échec de la mise à jour'),
                  ],
                ),
                backgroundColor: const Color(0xFFDC2626),
              ),
            );
          }
        },
      ),
    );
  }

  void _confirmDelete(TauxModel taux) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Voulez-vous vraiment supprimer le taux ${taux.deviseSource} → ${taux.deviseCible} (${taux.taux.toStringAsFixed(2)}) ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final ratesService = Provider.of<RatesService>(context, listen: false);
              if (taux.id != null) {
                final success = await ratesService.deleteTaux(taux.id!);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.white),
                          SizedBox(width: 12),
                          Text('Taux supprimé avec succès'),
                        ],
                      ),
                      backgroundColor: Color(0xFF4CAF50),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }
}

class _TauxDialog extends StatefulWidget {
  final TauxModel? taux;
  final Function(String devise, double taux, String type) onSave;

  const _TauxDialog({
    this.taux,
    required this.onSave,
  });

  @override
  State<_TauxDialog> createState() => _TauxDialogState();
}

class _TauxDialogState extends State<_TauxDialog> {
  final _formKey = GlobalKey<FormState>();
  final _tauxController = TextEditingController();
  
  String _devise = 'CDF';
  String _type = 'MOYEN';

  @override
  void initState() {
    super.initState();
    if (widget.taux != null) {
      _devise = widget.taux!.deviseCible;
      _type = widget.taux!.type;
      _tauxController.text = widget.taux!.taux.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF9800).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.currency_exchange,
                          color: Color(0xFFFF9800),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.taux == null ? 'Nouveau Taux' : 'Modifier le Taux',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Devise
                  const Text(
                    'Devise cible',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _devise,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.monetization_on, color: Color(0xFFFF9800)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    items: const [
                      DropdownMenuItem(value: 'CDF', child: Text('Franc Congolais (CDF)')),
                      DropdownMenuItem(value: 'UGX', child: Text('Shilling Ougandais (UGX)')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _devise = value ?? 'CDF';
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Type
                  const Text(
                    'Type de taux',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                        value: 'ACHAT',
                        label: Text('Achat'),
                        icon: Icon(Icons.arrow_downward, size: 16),
                      ),
                      ButtonSegment(
                        value: 'MOYEN',
                        label: Text('Moyen'),
                        icon: Icon(Icons.swap_horiz, size: 16),
                      ),
                      ButtonSegment(
                        value: 'VENTE',
                        label: Text('Vente'),
                        icon: Icon(Icons.arrow_upward, size: 16),
                      ),
                    ],
                    selected: {_type},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _type = newSelection.first;
                      });
                    },
                  ),
                  const SizedBox(height: 16),

                  // Taux
                  const Text(
                    'Taux de change',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _tauxController,
                    decoration: InputDecoration(
                      labelText: '1 USD = ? $_devise',
                      prefixIcon: const Icon(Icons.calculate, color: Color(0xFFFF9800)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                      helperText: 'Exemple: 2500',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir le taux';
                      }
                      final taux = double.tryParse(value);
                      if (taux == null || taux <= 0) {
                        return 'Taux invalide';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _handleSave,
                        icon: const Icon(Icons.check),
                        label: Text(widget.taux == null ? 'Créer' : 'Modifier'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFF9800),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  }

  void _handleSave() {
    if (_formKey.currentState!.validate()) {
      final taux = double.parse(_tauxController.text);
      widget.onSave(_devise, taux, _type);
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _tauxController.dispose();
    super.dispose();
  }
}
