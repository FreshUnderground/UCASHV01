import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/personnel_service.dart';
import '../services/salaire_service.dart';
import '../services/avance_service.dart';
import '../services/retenue_service.dart';
import '../services/credit_service.dart';
import '../models/personnel_model.dart';
import '../models/salaire_model.dart';
import '../models/avance_personnel_model.dart';
import '../models/retenue_personnel_model.dart';
import '../models/credit_personnel_model.dart';
import 'fiche_employe_detail_widget.dart';
import 'multi_periodes_salaire_widget.dart';
import 'personnel_rapport_widget.dart';

class GestionPersonnelWidget extends StatefulWidget {
  const GestionPersonnelWidget({super.key});

  @override
  State<GestionPersonnelWidget> createState() => _GestionPersonnelWidgetState();
}

class _GestionPersonnelWidgetState extends State<GestionPersonnelWidget> {
  @override
  void initState() {
    super.initState();
    // Nettoyer les doublons de salaires au démarrage
    Future.delayed(Duration.zero, () {
      SalaireService.instance.cleanDuplicateSalaires();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmployesTab(),
    );
  }
}

// ============================================================================
// ONGLET EMPLOYÉS
// ============================================================================

class EmployesTab extends StatefulWidget {
  const EmployesTab({super.key});

  @override
  State<EmployesTab> createState() => _EmployesTabState();
}

class _EmployesTabState extends State<EmployesTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedStatut;
  String? _selectedPoste;
  bool _isGeneratingMatricule = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPersonnel();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPersonnel() async {
    await PersonnelService.instance.loadPersonnel(forceRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
      preferredSize: const Size.fromHeight(75),
      child:  AppBar(
        backgroundColor: Colors.blue[700],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 2,
          labelColor: Colors.white,
          labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
          unselectedLabelColor: Colors.white70,
          unselectedLabelStyle: const TextStyle(fontSize: 10),
          tabs: const [
            Tab(icon: Icon(Icons.people), text: 'Agents'),
            Tab(icon: Icon(Icons.add_circle), text: 'Ajouter'),
            Tab(icon: Icon(Icons.bar_chart), text: 'Rapport'),
          ],
        ),
      ),),
      body: ChangeNotifierProvider.value(
        value: PersonnelService.instance,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildPersonnelList(),
            _buildAddPersonnel(),
            const PersonnelRapportWidget(),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonnelList() {
    return Consumer<PersonnelService>(
      builder: (context, service, child) {
        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var personnel = service.personnel;

        // Apply filters
        if (_searchQuery.isNotEmpty) {
          personnel = service.searchPersonnel(_searchQuery);
        }
        if (_selectedStatut != null) {
          personnel = personnel.where((p) => p.statut == _selectedStatut).toList();
        }
        if (_selectedPoste != null) {
          personnel = personnel.where((p) => p.poste == _selectedPoste).toList();
        }

        return Column(
          children: [
            _buildFilters(service),
            Expanded(
              child: personnel.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      itemCount: personnel.length,
                      itemBuilder: (context, index) {
                        return _buildPersonnelCard(personnel[index]);
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(PersonnelService service) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Rechercher un agent (nom, matricule, téléphone...)',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedStatut,
                  decoration: InputDecoration(
                    labelText: 'Statut',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: ['Actif', 'Suspendu', 'Conge', 'Demissionne', 'Licencie']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStatut = value;
                    });
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedPoste,
                  decoration: InputDecoration(
                    labelText: 'Poste',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: service.postesUniques
                      .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedPoste = value;
                    });
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonnelCard(PersonnelModel personnel) {
    final statusColor = _getStatusColor(personnel.statut);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Partie principale cliquable
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              onTap: () => _showPersonnelDetails(personnel),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Avatar avec initiale
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            statusColor.withOpacity(0.3),
                            statusColor.withOpacity(0.15),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(
                          color: statusColor.withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          personnel.nom.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Informations principales
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  personnel.nomComplet,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  personnel.statut,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.work_outline, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  personnel.poste,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone_outlined, size: 14, color: Colors.grey[600]),
                              const SizedBox(width: 4),
                              Text(
                                personnel.telephone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[700],
                                ),
                              ),
                              const Spacer(),
                              Icon(Icons.attach_money, size: 16, color: Colors.green[700]),
                              Text(
                                '${personnel.salaireTotal.toStringAsFixed(0)} ${personnel.deviseSalaire}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Icône flèche
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 18,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Séparateur
          Divider(height: 1, color: Colors.grey[300]),
          
          // Boutons d'action
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                _buildActionButton(
                  icon: Icons.attach_money,
                  label: 'Salaire',
                  color: Colors.green,
                  onTap: () => _showSalaireOptionsDialog(personnel),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.fast_forward,
                  label: 'Avance',
                  color: Colors.orange,
                  onTap: () => _showCreateAvanceDialog(personnel),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.remove_circle,
                  label: 'Retenue',
                  color: Colors.red,
                  onTap: () => _showCreateRetenueDialog(personnel),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.description,
                  label: 'Fiche',
                  color: Colors.indigo,
                  onTap: () => _showPersonnelSalaires(personnel),
                ),
                const SizedBox(width: 8),
                _buildActionButton(
                  icon: Icons.delete_outline,
                  label: 'Supprimer',
                  color: Colors.red,
                  onTap: () => _showDeletePersonnelDialog(personnel),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: color.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun employé trouvé',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Ajoutez votre premier employé',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAddPersonnel() {
    final formKey = GlobalKey<FormState>();
    final controllers = {
      'matricule': TextEditingController(),
      'nom': TextEditingController(),
      'prenom': TextEditingController(),
      'telephone': TextEditingController(),
      'email': TextEditingController(),
      'adresse': TextEditingController(),
      'etatCivil': TextEditingController(),
      'poste': TextEditingController(),
      'salaireBase': TextEditingController(text: '0'),
      'primeTransport': TextEditingController(text: '0'),
      'primeLogement': TextEditingController(text: '0'),
    };

    // Le matricule sera généré uniquement si l'utilisateur clique sur le bouton refresh
    // Pas de génération automatique pour éviter les crashes

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informations Personnelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: controllers['matricule'],
              decoration: InputDecoration(
                labelText: 'Matricule',
                hintText: 'Cliquez sur 🔄 pour générer automatiquement',
                border: const OutlineInputBorder(),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_isGeneratingMatricule)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () => _generateMatriculeAutomatiquement(controllers['matricule']!),
                        tooltip: 'Générer un matricule automatique',
                      ),
                  ],
                ),
                helperText: 'Optionnel - Format suggéré: EMP24XXX',
              ),
              // Retirer la validation obligatoire pour éviter les blocages
              // validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers['nom'],
                    decoration: const InputDecoration(
                      labelText: 'Nom *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers['prenom'],
                    decoration: const InputDecoration(
                      labelText: 'Prénom *',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controllers['telephone'],
              decoration: const InputDecoration(
                labelText: 'Téléphone *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controllers['email'],
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: controllers['adresse'],
              decoration: const InputDecoration(
                labelText: 'Adresse',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                labelText: 'État Civil',
                border: OutlineInputBorder(),
              ),
              items: ['Célibataire', 'Marié(e)', 'Divorcé(e)', 'Veuf/Veuve']
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (value) {
                controllers['etatCivil']!.text = value ?? '';
              },
            ),
            const SizedBox(height: 24),
            const Text('Informations Professionnelles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: controllers['poste'],
              decoration: const InputDecoration(
                labelText: 'Poste *',
                border: OutlineInputBorder(),
              ),
              validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 24),
            const Text('Informations Salariales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextFormField(
              controller: controllers['salaireBase'],
              decoration: const InputDecoration(
                labelText: 'Salaire Base *',
                border: OutlineInputBorder(),
                suffixText: 'USD',
              ),
              keyboardType: TextInputType.number,
              validator: (v) => v?.isEmpty ?? true ? 'Requis' : null,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controllers['primeTransport'],
                    decoration: const InputDecoration(
                      labelText: 'Prime Transport',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: controllers['primeLogement'],
                    decoration: const InputDecoration(
                      labelText: 'Prime Logement',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  if (formKey.currentState!.validate()) {
                    try {
                      // Générer un matricule si vide
                      String matricule = controllers['matricule']!.text.trim();
                      bool matriculeGenere = false;
                      
                      if (matricule.isEmpty) {
                        try {
                          matricule = await PersonnelService.instance.generateMatricule();
                          matriculeGenere = true;
                          debugPrint('✅ Matricule généré automatiquement: $matricule');
                        } catch (e) {
                          // Matricule de secours si la génération échoue
                          matricule = 'EMP${DateTime.now().year.toString().substring(2)}${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                          matriculeGenere = true;
                          debugPrint('🔄 Matricule de secours généré: $matricule');
                        }
                      }
                      
                      final personnel = PersonnelModel(
                        matricule: matricule,
                        nom: controllers['nom']!.text.trim(),
                        prenom: controllers['prenom']!.text.trim(),
                        telephone: controllers['telephone']!.text.trim(),
                        email: controllers['email']!.text.trim().isEmpty ? null : controllers['email']!.text.trim(),
                        adresse: controllers['adresse']!.text.trim().isEmpty ? null : controllers['adresse']!.text.trim(),
                        etatCivil: controllers['etatCivil']!.text.trim().isEmpty ? 'Celibataire' : controllers['etatCivil']!.text.trim(),
                        poste: controllers['poste']!.text.trim(),
                        dateEmbauche: DateTime.now(),
                        salaireBase: double.tryParse(controllers['salaireBase']!.text) ?? 0,
                        primeTransport: double.tryParse(controllers['primeTransport']!.text) ?? 0,
                        primeLogement: double.tryParse(controllers['primeLogement']!.text) ?? 0,
                      );

                      await PersonnelService.instance.createPersonnel(personnel);

                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Employé ${personnel.nomComplet} ajouté avec succès',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                if (matriculeGenere) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Matricule généré: $matricule',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ],
                            ),
                            backgroundColor: Colors.green,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        
                        _tabController.animateTo(0);
                        for (var controller in controllers.values) {
                          controller.clear();
                        }
                        controllers['salaireBase']!.text = '0';
                        controllers['primeTransport']!.text = '0';
                        controllers['primeLogement']!.text = '0';
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur: $e')),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.save),
                label: const Text('Enregistrer'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.blue[700],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Générer automatiquement un matricule unique
  Future<void> _generateMatriculeAutomatiquement(TextEditingController controller) async {
    if (_isGeneratingMatricule) return;
    
    setState(() {
      _isGeneratingMatricule = true;
    });
    
    try {
      debugPrint('🔄 Début génération matricule automatique');
      
      // Vérifier que le service est disponible
      if (PersonnelService.instance == null) {
        throw Exception('Service Personnel non disponible');
      }
      
      final matricule = await PersonnelService.instance.generateMatricule()
          .timeout(const Duration(seconds: 10)); // Timeout de sécurité
      
      if (matricule.isEmpty) {
        throw Exception('Matricule vide généré');
      }
      
      controller.text = matricule;
      debugPrint('✅ Matricule généré avec succès: $matricule');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Matricule généré: $matricule'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Erreur génération matricule UI: $e');
      
      // Générer un matricule de secours en cas d'échec total
      final fallbackMatricule = 'EMP${DateTime.now().year.toString().substring(2)}${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
      controller.text = fallbackMatricule;
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Erreur génération matricule',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Matricule de secours généré: $fallbackMatricule',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingMatricule = false;
        });
      }
    }
  }

  /// Afficher les options de paiement de salaire
  void _showSalaireOptionsDialog(PersonnelModel personnel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Options de Paiement - ${personnel.nomComplet}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_today, color: Colors.green),
              title: const Text('Paiement Mensuel'),
              subtitle: const Text('Payer un mois spécifique'),
              onTap: () {
                Navigator.pop(context);
                _showGenerateSalaireDialog(personnel);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.blue),
              title: const Text('Paiement Multi-Périodes'),
              subtitle: const Text('Payer plusieurs mois en une fois'),
              onTap: () {
                Navigator.pop(context);
                _showMultiPeriodesSalaireDialog(personnel);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Dialog pour paiement multi-périodes
  void _showMultiPeriodesSalaireDialog(PersonnelModel personnel) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Paiement Multi-Périodes - ${personnel.nomComplet}'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: MultiPeriodesSalaireWidget(personnel: personnel),
            ),
          );
        },
      ),
    );
  }

  void _showGenerateSalaireDialog(PersonnelModel personnel) {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;
    final heuresSupController = TextEditingController(text: '0');
    final bonusController = TextEditingController(text: '0');
    final montantServisController = TextEditingController();
    double avancesDeduites = 0;
    double retenuesDeduites = 0;
    double totalArrieres = 0;
    double netAPayer = 0;

    // Fonction pour calculer les déductions et le salaire brut/net
    Future<bool> calculateDeductions() async {
      // Vérifier si un salaire existe déjà pour cette période
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      SalaireModel? salaireExistant;
      try {
        salaireExistant = SalaireService.instance.salaires.firstWhere(
          (s) => s.personnelId == personnel.id && 
                 s.mois == selectedMonth && 
                 s.annee == selectedYear,
        );
      } catch (e) {
        salaireExistant = null;
      }
      
      // Bloquer seulement si le salaire est TOTALEMENT payé
      if (salaireExistant != null && salaireExistant.reference.isNotEmpty && salaireExistant.statut == 'Paye') {
        return false; // Salaire existe et est totalement payé
      }
      
      // Si partiellement payé, pré-remplir avec le montant restant
      if (salaireExistant != null && salaireExistant.reference.isNotEmpty && salaireExistant.statut == 'Paye_Partiellement') {
        totalArrieres = salaireExistant.montantRestant;
      }
      
      // Calculer les avances
      avancesDeduites = await AvanceService.instance.calculerDeductionMensuelle(
        personnel.id!,
        selectedMonth,
        selectedYear,
      );
      
      // Calculer les retenues
      retenuesDeduites = RetenueService.instance.calculerTotalRetenuesPourPeriode(
        personnelId: personnel.id!,
        mois: selectedMonth,
        annee: selectedYear,
      );
      
      // Calculer les arriérés (salaires impayés)
      final salairesImpayes = SalaireService.instance.salaires
          .where((s) => s.personnelId == personnel.id && s.montantRestant > 0)
          .toList();
      totalArrieres = salairesImpayes.fold<double>(0.0, (sum, s) => sum + s.montantRestant);
      
      return true; // OK, peut continuer
    }
    
    // Fonction pour recalculer le salaire brut/net en temps réel
    void recalculateSalaire() {
      final heuresSup = double.tryParse(heuresSupController.text) ?? 0;
      final bonusAmount = double.tryParse(bonusController.text) ?? 0;
      
      // Calcul du salaire brut (salaire base + primes + heures sup + bonus)
      final salaireBrut = personnel.salaireTotal + heuresSup + bonusAmount;
      
      // Calcul des déductions totales
      final totalDeductions = avancesDeduites + retenuesDeduites;
      
      // Calcul du net à payer
      netAPayer = salaireBrut - totalDeductions;
      
      // Auto-remplir montant servis avec net à payer
      montantServisController.text = netAPayer.toStringAsFixed(2);
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          // Charger les déductions au changement de mois/année
          calculateDeductions().then((canProceed) {
            if (context.mounted) {
              if (!canProceed) {
                // Salaire existe déjà et est totalement payé
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'SALAIRE DÉJÀ TOTALEMENT PAYÉ POUR ${_getMonthName(selectedMonth).toUpperCase()} ${selectedYear}',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 3),
                  ),
                );
              } else {
                setState(() {});
              }
            }
          });

          return AlertDialog(
            title: Text('Générer Salaire - ${personnel.nomComplet}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sélection période
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedMonth,
                          decoration: const InputDecoration(
                            labelText: 'Mois',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(12, (i) => i + 1).map((m) {
                            return DropdownMenuItem(
                              value: m,
                              child: Text(_getMonthName(m)),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedMonth = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedYear,
                          decoration: const InputDecoration(
                            labelText: 'Année',
                            border: OutlineInputBorder(),
                          ),
                          items: List.generate(3, (i) => now.year - i).map((y) {
                            return DropdownMenuItem(
                              value: y,
                              child: Text(y.toString()),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() => selectedYear = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Affichage du calcul automatique
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calculate, color: Colors.blue[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'CALCUL AUTOMATIQUE',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildCalculRow('Salaire Base + Primes', '${personnel.salaireTotal.toStringAsFixed(2)} USD'),
                        _buildCalculRow('Heures Supplémentaires', '${(double.tryParse(heuresSupController.text) ?? 0).toStringAsFixed(2)} USD'),
                        _buildCalculRow('Bonus', '${(double.tryParse(bonusController.text) ?? 0).toStringAsFixed(2)} USD'),
                        const Divider(),
                        _buildCalculRow('SALAIRE BRUT', '${(personnel.salaireTotal + (double.tryParse(heuresSupController.text) ?? 0) + (double.tryParse(bonusController.text) ?? 0)).toStringAsFixed(2)} USD', isBold: true, color: Colors.green[700]),
                        const SizedBox(height: 8),
                        _buildCalculRow('Avances Déduites', '-${avancesDeduites.toStringAsFixed(2)} USD', color: Colors.red[600]),
                        _buildCalculRow('Retenues', '-${retenuesDeduites.toStringAsFixed(2)} USD', color: Colors.red[600]),
                        const Divider(),
                        _buildCalculRow('NET À PAYER', '${netAPayer.toStringAsFixed(2)} USD', isBold: true, color: Colors.blue[700]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Heures supplémentaires et Bonus sur la même ligne
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: heuresSupController,
                          decoration: const InputDecoration(
                            labelText: 'Heures Supplémentaires',
                            border: OutlineInputBorder(),
                            suffixText: 'USD',
                            isDense: true,
                            helperText: 'Recalcul automatique du brut/net',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              recalculateSalaire();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: bonusController,
                          decoration: const InputDecoration(
                            labelText: 'Bonus',
                            border: OutlineInputBorder(),
                            suffixText: 'USD',
                            isDense: true,
                            helperText: 'Recalcul automatique du brut/net',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            setState(() {
                              recalculateSalaire();
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  // Section Déductions
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      border: Border.all(color: Colors.orange[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDeductionRow('Avances à déduire', avancesDeduites),
                        if (retenuesDeduites > 0) ...[
                          const SizedBox(height: 4),
                          _buildDeductionRow('Retenues (Pertes/Dettes/Sanctions)', retenuesDeduites),
                        ],
                      ],
                    ),
                  ),
                  
                  // Arriérés
                  if (totalArrieres > 0) const SizedBox(height: 12),
                  if (totalArrieres > 0)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        border: Border.all(color: Colors.red[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'ARRIÉRÉS',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red[900],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Salaires impayés: ${totalArrieres.toStringAsFixed(2)} USD',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red[900],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  
                  // Résumé
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      border: Border.all(color: Colors.blue[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        _buildSummaryRow(
                          'Salaire Base',
                          personnel.salaireBase,
                        ),
                        _buildSummaryRow(
                          'Primes Total',
                          personnel.primeTransport + personnel.primeLogement + 
                          personnel.primeFonction + personnel.autresPrimes,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'SALAIRE BRUT (estimé)',
                          personnel.salaireTotal + 
                          (double.tryParse(heuresSupController.text) ?? 0) +
                          (double.tryParse(bonusController.text) ?? 0),
                          isBold: true,
                        ),
                        _buildSummaryRow(
                          'Déductions',
                          -avancesDeduites,
                          isNegative: true,
                        ),
                        const Divider(),
                        _buildSummaryRow(
                          'NET À PAYER (estimé)',
                          personnel.salaireTotal + 
                          (double.tryParse(heuresSupController.text) ?? 0) +
                          (double.tryParse(bonusController.text) ?? 0) -
                          avancesDeduites -
                          retenuesDeduites,
                          isBold: true,
                          valueColor: Colors.green[700],
                        ),
                      ],
                    ),
                  ),
                  
                  // Montant Servis
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: Colors.green[300]!, width: 2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.payments, color: Colors.green[700], size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'MONTANT SERVIS',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.green[900],
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: montantServisController,
                          decoration: InputDecoration(
                            labelText: 'Montant réellement payé à l\'employé *',
                            border: const OutlineInputBorder(),
                            suffixText: 'USD',
                            filled: true,
                            fillColor: Colors.white,
                            prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                            helperText: 'Si différent du net, un arriéré sera créé',
                            helperStyle: TextStyle(color: Colors.orange[700]),
                          ),
                          keyboardType: TextInputType.number,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
                onPressed: () async {
                  final montantServis = double.tryParse(montantServisController.text);
                  
                  if (montantServis == null || montantServis < 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Montant servis invalide'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    return;
                  }
                  
                  try {
                    // Vérifier si c'est un complément de paiement ou nouvelle génération
                    await SalaireService.instance.loadSalaires(forceRefresh: true);
                    SalaireModel? salaireExistant;
                    try {
                      salaireExistant = SalaireService.instance.salaires.firstWhere(
                        (s) => s.personnelId == personnel.id && 
                               s.mois == selectedMonth && 
                               s.annee == selectedYear,
                      );
                    } catch (e) {
                      salaireExistant = null;
                    }
                    
                    // Validation AVANT de fermer le dialog
                    if (salaireExistant != null && salaireExistant.reference.isNotEmpty) {
                      if (salaireExistant.statut == 'Paye') {
                        // Salaire déjà entièrement payé - autoriser un nouveau paiement pour un mois différent
                        // (ceci est normalement géré par la sélection du mois/année)
                        if (montantServis > netAPayer) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le montant payé (${montantServis.toStringAsFixed(2)}) ne peut pas dépasser le net à payer (${netAPayer.toStringAsFixed(2)})'
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                      } else if (salaireExistant.statut == 'Paye_Partiellement') {
                        // Complément de paiement - valider contre le montant restant
                        final montantRestant = salaireExistant.montantRestant;
                        if (montantServis > montantRestant) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le montant payé (${montantServis.toStringAsFixed(2)}) ne peut pas dépasser le reste à payer (${montantRestant.toStringAsFixed(2)})'
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                      } else {
                        // Salaire existe mais pas encore payé - valider contre le net à payer
                        if (montantServis > netAPayer) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Le montant payé (${montantServis.toStringAsFixed(2)}) ne peut pas dépasser le net à payer (${netAPayer.toStringAsFixed(2)})'
                              ),
                              backgroundColor: Colors.red,
                              duration: const Duration(seconds: 4),
                            ),
                          );
                          return;
                        }
                      }
                    } else {
                      // Nouvelle génération - valider contre le net à payer
                      if (montantServis > netAPayer) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Le montant payé (${montantServis.toStringAsFixed(2)}) ne peut pas dépasser le net à payer (${netAPayer.toStringAsFixed(2)})'
                            ),
                            backgroundColor: Colors.red,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                        return;
                      }
                    }
                    
                    // Validation OK - fermer le dialog
                    if (mounted) {
                      Navigator.pop(context);
                    }
                    
                    SalaireModel? salaireResult;
                    bool isComplement = false;
                    
                    if (salaireExistant != null && salaireExistant.reference.isNotEmpty && salaireExistant.statut == 'Paye_Partiellement') {
                      // Complément de paiement sur salaire existant
                      isComplement = true;
                      final nouveauMontantPaye = salaireExistant.montantPaye + montantServis;
                      final salaireNet = salaireExistant.salaireNet;
                      
                      // Ajouter ce paiement à l'historique
                      final historique = List<PaiementSalaireModel>.from(salaireExistant.historiquePaiements);
                      historique.add(PaiementSalaireModel(
                        datePaiement: DateTime.now(),
                        montant: montantServis,
                        modePaiement: 'Especes',
                        agentPaiement: 'Admin',
                        notes: isComplement ? 'Paiement complémentaire' : 'Paiement initial',
                      ));
                      
                      // Convertir l'historique en JSON
                      final historiqueJson = jsonEncode(
                        historique.map((p) => p.toJson()).toList()
                      );
                      
                      salaireResult = salaireExistant.copyWith(
                        montantPaye: nouveauMontantPaye,
                        statut: nouveauMontantPaye >= salaireNet ? 'Paye' : 'Paye_Partiellement',
                        datePaiement: DateTime.now(),
                        historiquePaiementsJson: historiqueJson,
                        lastModifiedAt: DateTime.now(),
                      );
                      
                      // Sauvegarder le salaire mis à jour dans LocalDB
                      await SalaireService.instance.updateSalaire(salaireResult);
                      
                      // Enregistrer les déductions de retenues (seulement pour le complément)
                      try {
                        if (retenuesDeduites > 0) {
                          final retenuesActives = RetenueService.instance.getRetenuesActivesParPeriode(
                            personnelId: personnel.id!,
                            mois: selectedMonth,
                            annee: selectedYear,
                          );
                          for (final retenue in retenuesActives) {
                            final montantADeduire = retenue.getMontantPourPeriode(selectedMonth, selectedYear);
                            if (montantADeduire > 0) {
                              await RetenueService.instance.enregistrerDeduction(
                                retenueId: retenue.id!,
                                montantDeduit: montantADeduire,
                              );
                            }
                          }
                        }
                      } catch (e) {
                        debugPrint('⚠️ Erreur enregistrement retenues: $e');
                        // Ne pas faire échouer le paiement pour les retenues
                      }
                    } else {
                      // Nouvelle génération de salaire
                      final heuresSup = double.tryParse(heuresSupController.text) ?? 0;
                      final bonusAmount = double.tryParse(bonusController.text) ?? 0;
                      
                      final salaireGenere = await SalaireService.instance.genererSalaireMensuel(
                        personnelId: personnel.id!,
                        mois: selectedMonth,
                        annee: selectedYear,
                        heuresSupplementaires: heuresSup,
                        bonus: bonusAmount,
                        notes: 'Généré avec heures sup: ${heuresSup.toStringAsFixed(2)} USD, bonus: ${bonusAmount.toStringAsFixed(2)} USD',
                      );
                      
                      // Créer l'historique avec le premier paiement
                      final historique = [PaiementSalaireModel(
                        datePaiement: DateTime.now(),
                        montant: montantServis,
                        modePaiement: 'Especes',
                        agentPaiement: 'Admin',
                        notes: 'Paiement initial',
                      )];
                      
                      final historiqueJson = jsonEncode(
                        historique.map((p) => p.toJson()).toList()
                      );
                      
                      // Mettre à jour avec le montant servis
                      final salaireAvecPaiement = salaireGenere.copyWith(
                        montantPaye: montantServis,
                        statut: montantServis >= salaireGenere.salaireNet ? 'Paye' : 'Paye_Partiellement',
                        datePaiement: DateTime.now(),
                        historiquePaiementsJson: historiqueJson,
                        lastModifiedAt: DateTime.now(),
                      );
                      
                      // Sauvegarder le salaire mis à jour dans LocalDB
                      await SalaireService.instance.updateSalaire(salaireAvecPaiement);
                      salaireResult = salaireAvecPaiement;
                      
                      // Enregistrer les déductions de retenues
                      try {
                        if (retenuesDeduites > 0) {
                          final retenuesActives = RetenueService.instance.getRetenuesActivesParPeriode(
                            personnelId: personnel.id!,
                            mois: selectedMonth,
                            annee: selectedYear,
                          );
                          for (final retenue in retenuesActives) {
                            final montantADeduire = retenue.getMontantPourPeriode(selectedMonth, selectedYear);
                            if (montantADeduire > 0) {
                              await RetenueService.instance.enregistrerDeduction(
                                retenueId: retenue.id!,
                                montantDeduit: montantADeduire,
                              );
                            }
                          }
                        }
                      } catch (e) {
                        debugPrint('⚠️ Erreur enregistrement retenues: $e');
                        // Ne pas faire échouer le paiement pour les retenues
                      }
                    }
                    
                    // Message de confirmation
                    final arriereRestant = salaireResult?.montantRestant ?? 0;
                    
                    if (mounted) {
                      String message;
                      if (isComplement) {
                        message = 'Complément payé: ${montantServis.toStringAsFixed(2)} USD\n';
                        message += 'Total payé: ${salaireResult?.montantPaye.toStringAsFixed(2) ?? '0.00'} USD';
                      } else {
                        message = 'Salaire généré: ${montantServis.toStringAsFixed(2)} USD payé';
                      }
                      
                      if (arriereRestant > 0) {
                        message += '\nArriéré: ${arriereRestant.toStringAsFixed(2)} USD';
                      }
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: arriereRestant > 0 ? Colors.orange : Colors.green,
                          duration: const Duration(seconds: 4),
                        ),
                      );
                      
                      // Réinitialiser les contrôleurs du dialog
                      heuresSupController.clear();
                      bonusController.clear();
                      montantServisController.clear();
                    }
                  } catch (e) {
                    debugPrint('❌ Erreur génération salaire: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Erreur lors du paiement: ${e.toString()}'),
                          backgroundColor: Colors.red,
                          duration: const Duration(seconds: 6),
                        ),
                      );
                    }
                  } finally {
                    // Recharger les données pour éviter les incohérences
                    try {
                      await SalaireService.instance.loadSalaires(forceRefresh: true);
                      await PersonnelService.instance.loadPersonnel(forceRefresh: true);
                    } catch (e) {
                      debugPrint('⚠️ Erreur rechargement données: $e');
                    }
                  }
                },
                child: const Text('Générer'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDeductionRow(String label, double amount, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isBold ? Colors.orange[900] : Colors.orange[800],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, {bool isBold = false, bool isNegative = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${isNegative && amount > 0 ? "-" : ""}${amount.abs().toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (isNegative ? Colors.red[700] : Colors.blue[900]),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateAvanceDialog(PersonnelModel personnel) {
    final now = DateTime.now();
    final montantController = TextEditingController();
    final montantRemisController = TextEditingController();
    final dureeMoisController = TextEditingController(text: '1');
    final motifController = TextEditingController();
    String modeRemboursement = 'Mensuel';
    int selectedMonth = now.month;
    int selectedYear = now.year;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Nouvelle Avance - ${personnel.nomComplet}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Période de l'avance
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    border: Border.all(color: Colors.blue[200]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.calendar_today, color: Colors.blue[700], size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'PÉRIODE DE L\'AVANCE',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedMonth,
                              decoration: const InputDecoration(
                                labelText: 'Mois',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(12, (i) => i + 1).map((m) {
                                return DropdownMenuItem(
                                  value: m,
                                  child: Text(_getMonthName(m)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => selectedMonth = value!);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              value: selectedYear,
                              decoration: const InputDecoration(
                                labelText: 'Année',
                                border: OutlineInputBorder(),
                                isDense: true,
                              ),
                              items: List.generate(3, (i) => now.year - i).map((y) {
                                return DropdownMenuItem(
                                  value: y,
                                  child: Text(y.toString()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => selectedYear = value!);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Montant demandé
                TextField(
                  controller: montantController,
                  decoration: InputDecoration(
                    labelText: 'Montant Demandé *',
                    border: const OutlineInputBorder(),
                    suffixText: 'USD',
                    prefixIcon: const Icon(Icons.request_quote),
                    helperText: 'Montant à rembourser',
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    // Auto-remplir montant remis si vide
                    if (montantRemisController.text.isEmpty) {
                      montantRemisController.text = value;
                    }
                  },
                ),
                const SizedBox(height: 12),
                
                // Montant réellement remis
                TextField(
                  controller: montantRemisController,
                  decoration: InputDecoration(
                    labelText: 'Montant Remis *',
                    border: const OutlineInputBorder(),
                    suffixText: 'USD',
                    prefixIcon: const Icon(Icons.attach_money, color: Colors.green),
                    helperText: 'Montant réellement donné à l\'employé',
                    fillColor: Colors.green[50],
                    filled: true,
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                
                // Motif
                TextField(
                  controller: motifController,
                  decoration: const InputDecoration(
                    labelText: 'Motif',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.comment),
                    helperText: 'Raison de l\'avance (optionnel)',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                
                // Mode de remboursement
                DropdownButtonFormField<String>(
                  value: modeRemboursement,
                  decoration: const InputDecoration(
                    labelText: 'Mode Remboursement',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.payment),
                  ),
                  items: [
                    const DropdownMenuItem(value: 'Mensuel', child: Text('Mensuel')),
                    const DropdownMenuItem(value: 'Unique', child: Text('Unique (1 fois)')),
                    const DropdownMenuItem(value: 'Progressif', child: Text('Progressif')),
                  ],
                  onChanged: (value) {
                    setState(() => modeRemboursement = value!);
                  },
                ),
                const SizedBox(height: 12),
                
                // Durée
                if (modeRemboursement != 'Unique')
                  TextField(
                    controller: dureeMoisController,
                    decoration: const InputDecoration(
                      labelText: 'Durée Remboursement (mois)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.schedule),
                    ),
                    keyboardType: TextInputType.number,
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
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
              onPressed: () async {
                final montant = double.tryParse(montantController.text);
                final montantRemis = double.tryParse(montantRemisController.text);
                
                if (montant == null || montant <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Montant demandé invalide')),
                  );
                  return;
                }
                
                if (montantRemis == null || montantRemis <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Montant remis invalide')),
                  );
                  return;
                }
                
                if (montantRemis > montant) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le montant remis ne peut pas dépasser le montant demandé'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  return;
                }
                
                // Vérifier si le mois visé par l'avance est déjà payé
                await SalaireService.instance.loadSalaires(forceRefresh: true);
                final salaireExistant = SalaireService.instance.salaires.firstWhere(
                  (s) => s.personnelId == personnel.id && 
                         s.mois == selectedMonth && 
                         s.annee == selectedYear,
                  orElse: () => SalaireModel(
                    reference: '',
                    personnelId: 0,
                    personnelNom: '',
                    mois: 0,
                    annee: 0,
                    periode: '',
                    statut: '',
                  ),
                );
                
                if (salaireExistant.reference.isNotEmpty && salaireExistant.statut == 'Paye') {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Impossible de créer une avance pour $selectedMonth/$selectedYear car le salaire est déjà intégralement payé',
                        style: const TextStyle(fontSize: 13),
                      ),
                      backgroundColor: Colors.red[700],
                      duration: const Duration(seconds: 4),
                    ),
                  );
                  return;
                }
                
                // Fermer le dialog après validation
                Navigator.pop(context);
                
                try {
                  final avance = AvancePersonnelModel(
                    reference: 'AV${DateTime.now().millisecondsSinceEpoch}',
                    personnelId: personnel.id!,
                    montant: montant,
                    dateAvance: DateTime.now(),
                    moisAvance: selectedMonth,
                    anneeAvance: selectedYear,
                    montantRembourse: 0,
                    montantRestant: montant,
                    statut: 'En_Cours',
                    modeRemboursement: modeRemboursement,
                    nombreMoisRemboursement: modeRemboursement == 'Unique' ? 1 : (int.tryParse(dureeMoisController.text) ?? 1),
                    motif: motifController.text.isNotEmpty ? motifController.text : null,
                    notes: montantRemis < montant 
                        ? 'Montant demandé: ${montant.toStringAsFixed(2)} USD, Montant remis: ${montantRemis.toStringAsFixed(2)} USD (Différence: ${(montant - montantRemis).toStringAsFixed(2)} USD)'
                        : 'Montant remis: ${montantRemis.toStringAsFixed(2)} USD',
                  );
                  await AvanceService.instance.createAvance(avance);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Avance créée: ${montantRemis.toStringAsFixed(2)} USD remis (sur ${montant.toStringAsFixed(2)} USD)'
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Erreur: $e')),
                    );
                  }
                }
              },
              child: const Text('Créer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateCreditDialog(PersonnelModel personnel) {
    final montantController = TextEditingController();
    final tauxController = TextEditingController(text: '0');
    final dureeMoisController = TextEditingController(text: '12');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouveau Crédit - ${personnel.nomComplet}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: montantController,
                decoration: const InputDecoration(
                  labelText: 'Montant Crédit *',
                  border: OutlineInputBorder(),
                  suffixText: 'USD',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: tauxController,
                decoration: const InputDecoration(
                  labelText: 'Taux Intérêt Annuel',
                  border: OutlineInputBorder(),
                  suffixText: '%',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dureeMoisController,
                decoration: const InputDecoration(
                  labelText: 'Durée (mois)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
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
            onPressed: () async {
              final montant = double.tryParse(montantController.text);
              if (montant == null || montant <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Montant invalide')),
                );
                return;
              }
              Navigator.pop(context);
              try {
                final dureeMois = int.tryParse(dureeMoisController.text) ?? 12;
                final tauxInteret = double.tryParse(tauxController.text) ?? 0;
                // Calcul simple de la mensualité (montant / durée + intérêts)
                final totalARembourser = montant + (montant * tauxInteret / 100 * dureeMois / 12);
                final mensualite = dureeMois > 0 ? totalARembourser / dureeMois : montant;
                final credit = CreditPersonnelModel(
                  reference: 'CR${DateTime.now().millisecondsSinceEpoch}',
                  personnelId: personnel.id!,
                  montantCredit: montant,
                  tauxInteret: tauxInteret,
                  dateOctroi: DateTime.now(),
                  dateEcheance: DateTime.now().add(Duration(days: 30 * dureeMois)),
                  montantRembourse: 0,
                  interetsPayes: 0,
                  montantRestant: totalARembourser,
                  statut: 'En_Cours',
                  dureeMois: dureeMois,
                  mensualite: mensualite,
                );
                await CreditService.instance.createCredit(credit);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Crédit créé avec succès')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
      'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'
    ];
    return months[month - 1];
  }

  void _showPersonnelDetails(PersonnelModel personnel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FicheEmployeDetailWidget(personnel: personnel),
      ),
    );
  }

  /// Construire une ligne de calcul pour l'affichage
  Widget _buildCalculRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }


  void _showPersonnelSalaires(PersonnelModel personnel) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FicheEmployeDetailWidget(
          personnel: personnel,
          initialTabIndex: 1, // Index 1 = Onglet Salaires
        ),
      ),
    );
  }

  /// Afficher le dialog de confirmation de suppression
  void _showDeletePersonnelDialog(PersonnelModel personnel) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red[700]),
            const SizedBox(width: 8),
            const Text('Confirmer la suppression'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Êtes-vous sûr de vouloir supprimer cet employé ?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    personnel.nomComplet,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text('Matricule: ${personnel.matricule}'),
                  Text('Poste: ${personnel.poste}'),
                  Text('Téléphone: ${personnel.telephone}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Information importante',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• Cette action changera le statut à "Démissionné"\n'
                    '• Les données seront synchronisées sur tous les appareils\n'
                    '• La suppression définitive aura lieu après synchronisation\n'
                    '• Toutes les données liées (salaires, avances, retenues) seront également supprimées',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deletePersonnel(personnel);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
  }

  /// Supprimer un employé avec synchronisation
  Future<void> _deletePersonnel(PersonnelModel personnel) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Suppression en cours...'),
            ],
          ),
        ),
      );

      // Effectuer la suppression
      await PersonnelService.instance.deletePersonnel(personnel.id!);

      // Fermer l'indicateur de chargement
      if (mounted) {
        Navigator.pop(context);
      }

      // Afficher le message de succès
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${personnel.nomComplet} supprimé',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Synchronisation en cours sur tous les appareils',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green[700],
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      // Fermer l'indicateur de chargement si ouvert
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      // Afficher l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la suppression: $e'),
            backgroundColor: Colors.red[700],
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'Actif':
        return Colors.green;
      case 'Suspendu':
        return Colors.orange;
      case 'Conge':
        return Colors.blue;
      case 'Demissionne':
      case 'Licencie':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  void _showCreateRetenueDialog(PersonnelModel personnel) {
    final now = DateTime.now();
    int selectedMonth = now.month;
    int selectedYear = now.year;
    final typeController = TextEditingController(text: 'Perte');
    final montantTotalController = TextEditingController();
    final nombreMoisController = TextEditingController(text: '1');
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Nouvelle Retenue - ${personnel.nomComplet}'),
        content: SingleChildScrollView(
          child: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Type de retenue
                DropdownButtonFormField<String>(
                  value: typeController.text,
                  decoration: const InputDecoration(
                    labelText: 'Type de retenue',
                    border: OutlineInputBorder(),
                  ),
                  items: ['Perte', 'Dette', 'Sanction', 'Autre'].map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type),
                    );
                  }).toList(),
                  onChanged: (value) => typeController.text = value!,
                ),
                const SizedBox(height: 16),
                
                // Montant total
                TextField(
                  controller: montantTotalController,
                  decoration: const InputDecoration(
                    labelText: 'Montant total *',
                    border: OutlineInputBorder(),
                    suffixText: 'USD',
                    helperText: 'Montant total à retenir',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // Nombre de mois
                TextField(
                  controller: nombreMoisController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre de mois *',
                    border: OutlineInputBorder(),
                    helperText: 'Répartir sur combien de mois',
                  ),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                
                // Période de début
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedMonth,
                        decoration: const InputDecoration(
                          labelText: 'Mois de début',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(12, (i) => i + 1).map((m) {
                          return DropdownMenuItem(
                            value: m,
                            child: Text(_getMonthName(m)),
                          );
                        }).toList(),
                        onChanged: (value) => selectedMonth = value!,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<int>(
                        value: selectedYear,
                        decoration: const InputDecoration(
                          labelText: 'Année',
                          border: OutlineInputBorder(),
                        ),
                        items: List.generate(3, (i) => now.year - i).map((y) {
                          return DropdownMenuItem(
                            value: y,
                            child: Text(y.toString()),
                          );
                        }).toList(),
                        onChanged: (value) => selectedYear = value!,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Description
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                    helperText: 'Motif de la retenue',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              final montantTotal = double.tryParse(montantTotalController.text);
              final nombreMois = int.tryParse(nombreMoisController.text);
              
              if (montantTotal == null || montantTotal <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Montant invalide'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              if (nombreMois == null || nombreMois <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Nombre de mois invalide'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              Navigator.pop(context);
              
              try {
                await RetenueService.instance.createRetenue(
                  RetenuePersonnelModel(
                    reference: RetenuePersonnelModel.generateReference(),
                    personnelId: personnel.id!,
                    personnelNom: personnel.nomComplet,
                    type: typeController.text,
                    montantTotal: montantTotal,
                    nombreMois: nombreMois,
                    moisDebut: selectedMonth,
                    anneeDebut: selectedYear,
                    motif: descriptionController.text.isEmpty ? 'Retenue ${typeController.text}' : descriptionController.text,
                    statut: 'En_Cours',
                  ),
                );
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Retenue créée: ${montantTotal.toStringAsFixed(2)} USD sur $nombreMois mois\n'
                        'Déduction mensuelle: ${(montantTotal / nombreMois).toStringAsFixed(2)} USD'
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Créer'),
          ),
        ],
      ),
    );
  }
}
