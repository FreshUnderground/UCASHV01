import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/personnel_model.dart';
import '../models/salaire_model.dart';
import '../models/avance_personnel_model.dart';
import '../models/retenue_personnel_model.dart';
import '../services/personnel_service.dart';
import '../services/salaire_service.dart';
import '../services/avance_service.dart';
import '../services/retenue_service.dart';
import '../services/statistics_pdf_service.dart';
import '../services/tableau_paie_service.dart';
import 'pdf_viewer_dialog.dart';

class StatisticsPersonnelWidget extends StatefulWidget {
  const StatisticsPersonnelWidget({super.key});

  @override
  State<StatisticsPersonnelWidget> createState() => _StatisticsPersonnelWidgetState();
}

class _StatisticsPersonnelWidgetState extends State<StatisticsPersonnelWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // Filtres
  DateTime? _dateDebut;
  DateTime? _dateFin;
  String? _selectedPersonnelMatricule;
  int? _selectedMonth;
  int? _selectedYear;
  String _selectedStatut = 'Tous';
  
  bool _isLoading = false;
  
  // Données
  List<PersonnelModel> _personnel = [];
  List<SalaireModel> _salaires = [];
  List<AvancePersonnelModel> _avances = [];
  List<RetenuePersonnelModel> _retenues = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _resetFilters();
        });
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    await PersonnelService.instance.loadPersonnel();
    await SalaireService.instance.loadSalaires(forceRefresh: true);
    await AvanceService.instance.loadAvances(forceRefresh: true);
    await RetenueService.instance.loadRetenues(forceRefresh: true);
    
    setState(() {
      _personnel = PersonnelService.instance.personnel;
      _salaires = SalaireService.instance.salaires;
      _avances = AvanceService.instance.avances;
      _retenues = RetenueService.instance.retenues;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(75),
        child: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.indigo[700],
          flexibleSpace: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                indicatorWeight: 2,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                labelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 10),
                tabs: const [
                  Tab(icon: Icon(Icons.payment, size: 18), text: 'Paiements'),
                  Tab(icon: Icon(Icons.fast_forward, size: 18), text: 'Avances'),
                  Tab(icon: Icon(Icons.remove_circle, size: 18), text: 'Retenues'),
                  Tab(icon: Icon(Icons.warning, size: 18), text: 'Arrières'),
                  Tab(icon: Icon(Icons.list_alt, size: 18), text: 'Liste'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Filtres
                _buildFilters(),
                
                // Contenu du rapport
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPaiementsMensuels(),
                      _buildAvancesSalaires(),
                      _buildRetenues(),
                      _buildArrieres(),
                      _buildListePaie(),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, color: Colors.indigo[700]),
              const SizedBox(width: 8),
              Text(
                'Filtres',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.refresh),
                label: const Text('Réinitialiser'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _generatePdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Générer PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red[700],
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _buildPeriodFilter(),
              _buildPersonnelFilter(),
              if (_tabController.index == 0 || _tabController.index == 3)
                _buildStatutFilter(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodFilter() {
    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<int>(
        value: _selectedMonth,
        decoration: const InputDecoration(
          labelText: 'Mois',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.calendar_month),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem(value: null, child: Text('Tous les mois')),
          ...List.generate(12, (index) {
            final month = index + 1;
            return DropdownMenuItem(
              value: month,
              child: Text(_getMonthName(month)),
            );
          }),
        ],
        onChanged: (value) => setState(() => _selectedMonth = value),
      ),
    );
  }

  Widget _buildPersonnelFilter() {
    return SizedBox(
      width: 250,
      child: DropdownButtonFormField<String?>(
        value: _selectedPersonnelMatricule,
        decoration: const InputDecoration(
          labelText: 'Agent',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.person),
          isDense: true,
        ),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('Tous les agents')),
          ..._personnel.map((p) => DropdownMenuItem<String?>(
                value: p.matricule,
                child: Text(p.nomComplet),
              )),
        ],
        onChanged: (value) => setState(() => _selectedPersonnelMatricule = value),
      ),
    );
  }

  Widget _buildStatutFilter() {
    return SizedBox(
      width: 180,
      child: DropdownButtonFormField<String>(
        value: _selectedStatut,
        decoration: const InputDecoration(
          labelText: 'Statut',
          border: OutlineInputBorder(),
          prefixIcon: Icon(Icons.check_circle),
          isDense: true,
        ),
        items: const [
          DropdownMenuItem(value: 'Tous', child: Text('Tous')),
          DropdownMenuItem(value: 'Paye', child: Text('Payé')),
          DropdownMenuItem(value: 'Paye_Partiellement', child: Text('Partiel')),
          DropdownMenuItem(value: 'En_Attente', child: Text('En attente')),
        ],
        onChanged: (value) => setState(() => _selectedStatut = value!),
      ),
    );
  }


  void _resetFilters() {
    setState(() {
      _dateDebut = null;
      _dateFin = null;
      _selectedPersonnelMatricule = null;
      _selectedMonth = null;
      _selectedYear = null;
      _selectedStatut = 'Tous';
    });
  }

  Future<void> _generatePdf() async {
    try {
      // Afficher loader
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Préparer les données
      final personnelMap = {for (var p in _personnel) if (p.id != null) p.id!: p};
      pw.Document pdfDocument;
      String title;
      String fileName;
      
      // Générer selon le type
      switch (_tabController.index) {
        case 0: // Paiements Mensuels
          final salairesFiltered = _applyFilters();
          pdfDocument = await generateRapportPaiementsMensuels(
            salaires: salairesFiltered,
            personnelMap: personnelMap,
            mois: _selectedMonth,
            annee: _selectedYear,
            filtreStatut: _selectedStatut != 'Tous' ? _selectedStatut : null,
          );
          title = 'Rapport des Paiements Mensuels';
          fileName = 'Rapport_Paiements_${DateTime.now().millisecondsSinceEpoch}';
          break;
          
        case 1: // Avances
          final avancesFiltered = _avances.where((a) {
            if (_selectedPersonnelMatricule != null && a.personnelMatricule != _selectedPersonnelMatricule) return false;
            if (_selectedMonth != null && a.moisAvance != _selectedMonth) return false;
            if (_selectedYear != null && a.anneeAvance != _selectedYear) return false;
            return true;
          }).toList();
          pdfDocument = await generateRapportAvances(
            avances: avancesFiltered,
            personnelMap: personnelMap,
            mois: _selectedMonth,
            annee: _selectedYear,
          );
          title = 'Rapport des Avances sur Salaires';
          fileName = 'Rapport_Avances_${DateTime.now().millisecondsSinceEpoch}';
          break;
          
        case 2: // Retenues
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Génération PDF des retenues non implémentée'),
              backgroundColor: Colors.orange,
            ),
          );
          if (mounted) Navigator.pop(context);
          return;
          
        case 3: // Arrières
          final salairesAvecArrieres = _salaires.where((s) {
            if (s.montantRestant <= 0) return false;
            if (_selectedPersonnelMatricule != null && s.personnelMatricule != _selectedPersonnelMatricule) return false;
            return true;
          }).toList();
          pdfDocument = await generateRapportArrieres(
            salaires: salairesAvecArrieres,
            personnelMap: personnelMap,
          );
          title = 'Rapport des Arrières de Paie';
          fileName = 'Rapport_Arrieres_${DateTime.now().millisecondsSinceEpoch}';
          break;
          
        case 4: // Liste de Paie
          final salairesFiltered = _applyFilters();
          final avancesFiltered = _avances.where((a) {
            if (_selectedMonth != null && a.moisAvance != _selectedMonth) return false;
            if (_selectedYear != null && a.anneeAvance != _selectedYear) return false;
            return true;
          }).toList();
          pdfDocument = await generateListePaie(
            salaires: salairesFiltered,
            avances: avancesFiltered,
            personnelMap: personnelMap,
            mois: _selectedMonth,
            annee: _selectedYear,
          );
          title = 'Liste de Paie Détaillée';
          fileName = 'Liste_Paie_${DateTime.now().millisecondsSinceEpoch}';
          break;
          
        default:
          if (mounted) Navigator.pop(context);
          return;
      }
      
      // Fermer loader
      if (mounted) Navigator.pop(context);
      
      // Afficher le PDF
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdfDocument,
          title: title,
          fileName: fileName,
        );
      }
    } catch (e) {
      // Fermer loader si erreur
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  List<SalaireModel> _applyFilters() {
    return _salaires.where((salaire) {
      // Filtre par personnel
      if (_selectedPersonnelMatricule != null && salaire.personnelMatricule != _selectedPersonnelMatricule) {
        return false;
      }
      
      // Filtre par mois
      if (_selectedMonth != null && salaire.mois != _selectedMonth) {
        return false;
      }
      
      // Filtre par année
      if (_selectedYear != null && salaire.annee != _selectedYear) {
        return false;
      }
      
      // Filtre par statut
      if (_selectedStatut != 'Tous' && salaire.statut != _selectedStatut) {
        return false;
      }
      
      return true;
    }).toList();
  }
  
  Widget _buildStatCard(String title, String subtitle, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: color, width: 4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatutChip(String statut) {
    Color color;
    String label;
    
    switch (statut) {
      case 'Paye':
        color = Colors.green;
        label = 'Payé';
        break;
      case 'Paye_Partiellement':
        color = Colors.orange;
        label = 'Partiel';
        break;
      case 'En_Attente':
        color = Colors.grey;
        label = 'En attente';
        break;
      default:
        color = Colors.blue;
        label = statut;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildTotalBox(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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

  // Report builders will be in separate methods
  Widget _buildPaiementsMensuels() {
    final salairesFiltered = _applyFilters();
    
    if (salairesFiltered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun paiement pour les filtres sélectionnés',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }
    
    // Calculer statistiques
    double totalComplets = 0;
    double totalPartiels = 0;
    double totalArrieres = 0;
    int nbComplets = 0;
    int nbPartiels = 0;
    
    for (var salaire in salairesFiltered) {
      if (salaire.statut == 'Paye') {
        totalComplets += salaire.montantPaye;
        nbComplets++;
      } else if (salaire.statut == 'Paye_Partiellement') {
        totalPartiels += salaire.montantPaye;
        totalArrieres += salaire.montantRestant;
        nbPartiels++;
      }
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartes statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Paiements Complets',
                  '$nbComplets agents',
                  '${totalComplets.toStringAsFixed(2)} USD',
                  Colors.green,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Paiements Partiels',
                  '$nbPartiels agents',
                  '${totalPartiels.toStringAsFixed(2)} USD',
                  Colors.orange,
                  Icons.timelapse,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Arrières Totaux',
                  '',
                  '${totalArrieres.toStringAsFixed(2)} USD',
                  Colors.red,
                  Icons.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          // Tableau des paiements
          Text(
            'Détail des Paiements',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo[900],
            ),
          ),
          const SizedBox(height: 12),
          
          Card(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final availableWidth = constraints.maxWidth;
                final bool isWideScreen = availableWidth > 900;
                final bool isMediumScreen = availableWidth > 600;
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: availableWidth,
                    ),
                    child: DataTable(
                      columnSpacing: isWideScreen ? 16 : (isMediumScreen ? 10 : 6),
                      dataTextStyle: TextStyle(
                        fontSize: isWideScreen ? 12 : (isMediumScreen ? 11 : 10),
                      ),
                      headingTextStyle: TextStyle(
                        fontSize: isWideScreen ? 12 : (isMediumScreen ? 11 : 10),
                        fontWeight: FontWeight.bold,
                      ),
                      columns: const [
                        DataColumn(label: Text('Période')),
                        DataColumn(label: Text('Base')),
                        DataColumn(label: Text('Indemn.')),
                        DataColumn(label: Text('Avance')),
                        DataColumn(label: Text('Retenu')),
                        DataColumn(label: Text('Net')),
                        DataColumn(label: Text('Payé')),
                        DataColumn(label: Text('Reste')),
                      ],
                      rows: salairesFiltered.map((salaire) {
                        // Calculer les indemnités
                        final indemnites = salaire.primeTransport +
                            salaire.primeLogement +
                            salaire.primeFonction +
                            salaire.autresPrimes +
                            salaire.bonus;
                        
                        // Calculer les retenues
                        final retenues = salaire.retenueDisciplinaire + salaire.retenueAbsences;
                        
                        return DataRow(
                          cells: [
                            DataCell(Text('${_getMonthName(salaire.mois)} ${salaire.annee}')),
                            DataCell(Text('${salaire.salaireBase.toStringAsFixed(0)}')),
                            DataCell(Text('${indemnites.toStringAsFixed(0)}')),
                            DataCell(Text('${salaire.avancesDeduites.toStringAsFixed(0)}')),
                            DataCell(Text('${retenues.toStringAsFixed(0)}')),
                            DataCell(Text('${salaire.salaireNet.toStringAsFixed(0)}')),
                            DataCell(Text(
                              '${salaire.montantPaye.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: Colors.green[700],
                                fontWeight: FontWeight.bold,
                              ),
                            )),
                            DataCell(Text(
                              '${salaire.montantRestant.toStringAsFixed(0)}',
                              style: TextStyle(
                                color: salaire.montantRestant > 0 ? Colors.red[700] : Colors.grey,
                                fontWeight: salaire.montantRestant > 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            )),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvancesSalaires() {
    var avancesFiltered = _avances.where((avance) {
      if (_selectedPersonnelMatricule != null && avance.personnelMatricule != _selectedPersonnelMatricule) return false;
      if (_selectedMonth != null && avance.moisAvance != _selectedMonth) return false;
      if (_selectedYear != null && avance.anneeAvance != _selectedYear) return false;
      return true;
    }).toList();
    
    if (avancesFiltered.isEmpty) {
      return const Center(child: Text('Aucune avance trouvée'));
    }
    
    double totalAvances = 0;
    double totalRembourse = 0;
    double totalRestant = 0;
    
    for (var avance in avancesFiltered) {
      totalAvances += avance.montant;
      totalRembourse += avance.montantRembourse;
      totalRestant += avance.montantRestant;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Avancé',
                  '${avancesFiltered.length} avances',
                  '${totalAvances.toStringAsFixed(2)} USD',
                  Colors.orange,
                  Icons.fast_forward,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Total Remboursé',
                  '',
                  '${totalRembourse.toStringAsFixed(2)} USD',
                  Colors.green,
                  Icons.check,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Reste à Rembourser',
                  '',
                  '${totalRestant.toStringAsFixed(2)} USD',
                  Colors.red,
                  Icons.pending,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Agent')),
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Période')),
                  DataColumn(label: Text('Montant')),
                  DataColumn(label: Text('Remboursé')),
                  DataColumn(label: Text('Restant')),
                ],
                rows: avancesFiltered.map((avance) {
                  final personnel = _personnel.firstWhere(
                    (p) => p.matricule == avance.personnelMatricule,
                    orElse: () => PersonnelModel(
                      matricule: 'N/A',
                      nom: 'N',
                      prenom: 'A',
                      telephone: '',
                      poste: '',
                      dateEmbauche: DateTime.now(),
                    ),
                  );
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(personnel.nomComplet)),
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(avance.dateAvance))),
                      DataCell(Text('${_getMonthName(avance.moisAvance)} ${avance.anneeAvance}')),
                      DataCell(Text('${avance.montant.toStringAsFixed(2)} USD')),
                      DataCell(Text('${avance.montantRembourse.toStringAsFixed(2)} USD')),
                      DataCell(Text(
                        '${avance.montantRestant.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: avance.montantRestant > 0 ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArrieres() {
    final salairesAvecArrieres = _salaires.where((s) {
      if (s.montantRestant <= 0) return false;
      if (_selectedPersonnelMatricule != null && s.personnelMatricule != _selectedPersonnelMatricule) return false;
      return true;
    }).toList();
    
    if (salairesAvecArrieres.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle, size: 64, color: Colors.green[400]),
            const SizedBox(height: 16),
            Text(
              'Aucun arrière de paie!',
              style: TextStyle(fontSize: 18, color: Colors.green[700], fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }
    
    double totalArrieres = salairesAvecArrieres.fold(0, (sum, s) => sum + s.montantRestant);
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              border: Border.all(color: Colors.red[700]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.warning, color: Colors.red[700], size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SITUATION DES ARRIÈRES',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red[900],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${salairesAvecArrieres.length} salaires impayés',
                        style: TextStyle(fontSize: 14, color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'TOTAL ARRIÈRES',
                      style: TextStyle(fontSize: 12, color: Colors.red[700]),
                    ),
                    Text(
                      '${totalArrieres.toStringAsFixed(2)} USD',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[900],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Agent')),
                  DataColumn(label: Text('Période')),
                  DataColumn(label: Text('Net à Payer')),
                  DataColumn(label: Text('Payé')),
                  DataColumn(label: Text('Arrière')),
                  DataColumn(label: Text('% Impayé')),
                ],
                rows: salairesAvecArrieres.map((salaire) {
                  final personnel = _personnel.firstWhere(
                    (p) => p.matricule == salaire.personnelMatricule,
                    orElse: () => PersonnelModel(
                      matricule: 'N/A',
                      nom: 'N',
                      prenom: 'A',
                      telephone: '',
                      poste: '',
                      dateEmbauche: DateTime.now(),
                    ),
                  );
                  
                  final pourcentageImpaye = (salaire.montantRestant / salaire.salaireNet * 100);
                  final isCritique = pourcentageImpaye > 50;
                  
                  return DataRow(
                    color: MaterialStateProperty.all(
                      isCritique ? Colors.red[50] : null,
                    ),
                    cells: [
                      DataCell(Text(personnel.nomComplet)),
                      DataCell(Text('${_getMonthName(salaire.mois)} ${salaire.annee}')),
                      DataCell(Text('${salaire.salaireNet.toStringAsFixed(2)} USD')),
                      DataCell(Text('${salaire.montantPaye.toStringAsFixed(2)} USD')),
                      DataCell(Text(
                        '${salaire.montantRestant.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: Colors.red[900],
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isCritique ? Colors.red[700] : Colors.orange[700],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${pourcentageImpaye.toStringAsFixed(1)}%',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListePaie() {
    final salairesFiltered = _applyFilters();
    
    if (salairesFiltered.isEmpty) {
      return const Center(child: Text('Aucune donnée pour la liste de paie'));
    }
    
    // Grouper par personnel
    final Map<String, List<SalaireModel>> salairesByPersonnel = {};
    for (var salaire in salairesFiltered) {
      salairesByPersonnel.putIfAbsent(salaire.personnelMatricule, () => []).add(salaire);
    }
    
    double grandTotalPaiements = 0;
    double grandTotalArrieres = 0;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...salairesByPersonnel.entries.map((entry) {
            final personnelMatricule = entry.key;
            final salairesPers = entry.value;
            
            final personnel = _personnel.firstWhere(
              (p) => p.matricule == personnelMatricule,
              orElse: () => PersonnelModel(
                matricule: personnelMatricule,
                nom: 'Agent',
                prenom: 'Inconnu',
                telephone: '',
                poste: '',
                dateEmbauche: DateTime.now(),
              ),
            );
            
            double totalPaiements = salairesPers.fold(0, (sum, s) => sum + s.montantPaye);
            double totalArrieres = salairesPers.fold(0, (sum, s) => sum + s.montantRestant);
            
            grandTotalPaiements += totalPaiements;
            grandTotalArrieres += totalArrieres;
            
            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.indigo[700],
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          personnel.nomComplet,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          personnel.poste,
                          style: const TextStyle(fontSize: 14, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Calculer la largeur disponible
                      final availableWidth = constraints.maxWidth;
                      
                      // Déterminer si on a assez d'espace pour afficher toutes les colonnes
                      final bool isWideScreen = availableWidth > 900;
                      final bool isMediumScreen = availableWidth > 600;
                      
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: availableWidth,
                            maxWidth: isWideScreen ? availableWidth : double.infinity,
                          ),
                          child: DataTable(
                            columnSpacing: isWideScreen ? 20 : (isMediumScreen ? 12 : 8),
                            headingRowHeight: 40,
                            dataRowMinHeight: 35,
                            dataRowMaxHeight: 35,
                            columns: [
                              DataColumn(label: Text('Période', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Base', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Indemn.', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Avance', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Retenu', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Net', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Payé', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Reste', style: TextStyle(fontSize: isWideScreen ? 12 : 11, fontWeight: FontWeight.bold))),
                            ],
                            rows: salairesPers.map((s) {
                              final indemnites = s.primeTransport + s.primeLogement + s.primeFonction + s.autresPrimes + s.bonus;
                              final retenues = s.retenueDisciplinaire + s.retenueAbsences;
                              final fontSize = isWideScreen ? 11.0 : 10.0;
                              
                              return DataRow(
                                cells: [
                                  DataCell(Text('${_getMonthName(s.mois)} ${s.annee}', style: TextStyle(fontSize: fontSize))),
                                  DataCell(Text('${s.salaireBase.toStringAsFixed(0)}', style: TextStyle(fontSize: fontSize))),
                                  DataCell(Text('${indemnites.toStringAsFixed(0)}', style: TextStyle(fontSize: fontSize))),
                                  DataCell(Text('${s.avancesDeduites.toStringAsFixed(0)}', style: TextStyle(fontSize: fontSize))),
                                  DataCell(Text('${retenues.toStringAsFixed(0)}', style: TextStyle(fontSize: fontSize))),
                                  DataCell(Text('${s.salaireNet.toStringAsFixed(0)}', style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.bold, color: Colors.green[700]))),
                                  DataCell(Text('${s.montantPaye.toStringAsFixed(0)}', style: TextStyle(fontSize: fontSize, color: Colors.blue[700]))),
                                  DataCell(Text(
                                    '${s.montantRestant.toStringAsFixed(0)}',
                                    style: TextStyle(
                                      fontSize: fontSize,
                                      color: s.montantRestant > 0 ? Colors.red[700] : Colors.grey,
                                    ),
                                  )),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Text('TOTAUX:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo[900])),
                            Text(
                              'Payé: ${totalPaiements.toStringAsFixed(2)} USD',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                            ),
                            if (totalArrieres > 0)
                              Text(
                                'Arrière: ${totalArrieres.toStringAsFixed(2)} USD',
                                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red[700]),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () => _generateTableauPaiePdf(personnel, salairesPers),
                          icon: const Icon(Icons.picture_as_pdf, size: 18),
                          label: const Text('Tableau de Paie PDF'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo[700],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          
          // Totaux globaux
          LayoutBuilder(
            builder: (context, constraints) {
              final isWideScreen = constraints.maxWidth > 600;
              
              return Container(
                margin: const EdgeInsets.only(top: 24),
                padding: EdgeInsets.all(isWideScreen ? 16 : 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.indigo[900]!, Colors.indigo[700]!],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      'TOTAUX GÉNÉRAUX',
                      style: TextStyle(
                        fontSize: isWideScreen ? 18 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: isWideScreen ? 16 : 12),
                    isWideScreen
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildTotalBox('Total Paiements', grandTotalPaiements, Colors.green),
                              _buildTotalBox('Total Arrières', grandTotalArrieres, Colors.red),
                            ],
                          )
                        : Column(
                            children: [
                              _buildTotalBox('Total Paiements', grandTotalPaiements, Colors.green),
                              const SizedBox(height: 12),
                              _buildTotalBox('Total Arrières', grandTotalArrieres, Colors.red),
                            ],
                          ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildRetenues() {
    var retenuesFiltered = _retenues.where((retenue) {
      if (_selectedPersonnelMatricule != null && retenue.personnelMatricule != _selectedPersonnelMatricule) return false;
      if (_selectedMonth != null && !retenue.isActivePourPeriode(_selectedMonth!, _selectedYear ?? DateTime.now().year)) return false;
      return true;
    }).toList();
    
    if (retenuesFiltered.isEmpty) {
      return const Center(child: Text('Aucune retenue trouvée'));
    }
    
    double totalMontant = 0;
    double totalDeduit = 0;
    double totalRestant = 0;
    
    for (var retenue in retenuesFiltered) {
      totalMontant += retenue.montantTotal;
      totalDeduit += retenue.montantDejaDeduit;
      totalRestant += retenue.montantRestant;
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cartes statistiques
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Retenues Actives',
                  '${retenuesFiltered.where((r) => r.statut == 'En_Cours').length}',
                  '${totalMontant.toStringAsFixed(2)} USD',
                  Colors.orange,
                  Icons.remove_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Déjà Déduit',
                  '',
                  '${totalDeduit.toStringAsFixed(2)} USD',
                  Colors.blue,
                  Icons.check_circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Restant à Déduire',
                  '',
                  '${totalRestant.toStringAsFixed(2)} USD',
                  Colors.red,
                  Icons.pending,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          Card(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Agent')),
                  DataColumn(label: Text('Type')),
                  DataColumn(label: Text('Motif')),
                  DataColumn(label: Text('Début')),
                  DataColumn(label: Text('Mois Prévus')),
                  DataColumn(label: Text('Mois Écoulés')),
                  DataColumn(label: Text('Montant Total')),
                  DataColumn(label: Text('Déduit')),
                  DataColumn(label: Text('Restant')),
                  DataColumn(label: Text('Statut')),
                ],
                rows: retenuesFiltered.map((retenue) {
                  final personnel = _personnel.firstWhere(
                    (p) => p.matricule == retenue.personnelMatricule,
                    orElse: () => PersonnelModel(
                      matricule: 'N/A',
                      nom: 'N',
                      prenom: 'A',
                      telephone: '',
                      poste: '',
                      dateEmbauche: DateTime.now(),
                    ),
                  );
                  
                  // Calculer le nombre de mois écoulés
                  final now = DateTime.now();
                  final periodeDebut = retenue.anneeDebut * 12 + retenue.moisDebut;
                  final periodeActuelle = now.year * 12 + now.month;
                  final moisEcoules = (periodeActuelle - periodeDebut + 1).clamp(0, retenue.nombreMois);
                  
                  return DataRow(
                    cells: [
                      DataCell(Text(personnel.nomComplet)),
                      DataCell(Text(retenue.type)),
                      DataCell(
                        SizedBox(
                          width: 150,
                          child: Text(
                            retenue.motif,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                          ),
                        ),
                      ),
                      DataCell(Text('${_getMonthName(retenue.moisDebut)} ${retenue.anneeDebut}')),
                      DataCell(Text('${retenue.nombreMois}')),
                      DataCell(Text(
                        '$moisEcoules',
                        style: TextStyle(
                          color: moisEcoules >= retenue.nombreMois ? Colors.green[700] : Colors.orange[700],
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                      DataCell(Text('${retenue.montantTotal.toStringAsFixed(2)} USD')),
                      DataCell(Text(
                        '${retenue.montantDejaDeduit.toStringAsFixed(2)} USD',
                        style: TextStyle(color: Colors.blue[700]),
                      )),
                      DataCell(Text(
                        '${retenue.montantRestant.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: retenue.montantRestant > 0 ? Colors.red[700] : Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      )),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRetenueStatusColor(retenue.statut).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            retenue.statut.replaceAll('_', ' '),
                            style: TextStyle(
                              color: _getRetenueStatusColor(retenue.statut),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getRetenueStatusColor(String statut) {
    switch (statut) {
      case 'En_Cours':
        return Colors.orange;
      case 'Termine':
        return Colors.green;
      case 'Annule':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }
  
  Future<void> _generateTableauPaiePdf(PersonnelModel personnel, List<SalaireModel> salaires) async {
    try {
      final pdf = await TableauPaieService.generateTableauPaiePdf(
        salaires: salaires,
        personnel: personnel,
      );
      
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => PdfViewerDialog(
          pdfDocument: pdf,
          title: 'Tableau de Paie - ${personnel.nomComplet}',
          fileName: 'tableau_paie_${personnel.matricule}_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la génération du PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
