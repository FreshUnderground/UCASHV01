import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/personnel_rapport_service.dart';
import '../models/personnel_model.dart';
import '../services/personnel_service.dart';

/// Widget pour afficher les rapports de paiements du personnel
class PersonnelRapportWidget extends StatefulWidget {
  const PersonnelRapportWidget({Key? key}) : super(key: key);

  @override
  State<PersonnelRapportWidget> createState() => _PersonnelRapportWidgetState();
}

class _PersonnelRapportWidgetState extends State<PersonnelRapportWidget> {
  TypePeriodeRapport _periodeSelectionnee = TypePeriodeRapport.moisCourant;
  DateTime _dateReference = DateTime.now();
  List<PersonnelModel> _personnelsDisponibles = [];
  List<String> _personnelsSelectionnes = [];
  bool _grouperParAgent = true;
  bool _isLoading = false;
  bool _filtresVisibles = false; // Filtres masqués par défaut
  RapportPaiementsPersonnel? _rapportActuel;

  @override
  void initState() {
    super.initState();
    _chargerPersonnels();
  }

  Future<void> _chargerPersonnels() async {
    try {
      await PersonnelService.instance.loadPersonnel();
      setState(() {
        _personnelsDisponibles = PersonnelService.instance.personnel
            .where((p) => p.statut != 'Demissionne')
            .toList();
      });
    } catch (e) {
      debugPrint('Erreur chargement personnels: $e');
    }
  }

  Future<void> _genererRapport() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rapport = await PersonnelRapportService.instance.genererRapportPeriodePredefinie(
        typePeriode: _periodeSelectionnee,
        dateReference: _dateReference,
        personnelMatricules: _personnelsSelectionnes.isEmpty ? null : _personnelsSelectionnes,
        grouperParAgent: _grouperParAgent,
      );

      setState(() {
        _rapportActuel = rapport;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur génération rapport: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport Paiements Personnel'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilterToggle(),
          if (_filtresVisibles) _buildFiltres(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rapportActuel == null
                    ? _buildMessageVide()
                    : _buildRapport(),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Filtres et Options',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _filtresVisibles = !_filtresVisibles;
              });
            },
            icon: Icon(
              _filtresVisibles ? Icons.expand_less : Icons.expand_more,
              size: 20,
            ),
            label: Text(
              _filtresVisibles ? 'Masquer' : 'Afficher',
              style: const TextStyle(fontSize: 14),
            ),
            style: TextButton.styleFrom(
              foregroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            onPressed: _isLoading ? null : _genererRapport,
            icon: const Icon(Icons.analytics, size: 18),
            label: const Text('Générer Rapport', style: TextStyle(fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltres() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 400), // Increased height limit
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: SingleChildScrollView( // Permet le défilement si nécessaire
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Prevent unnecessary expansion
          children: [
            // Première ligne: Période et Date de référence
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Période', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 60),
                        child: DropdownButtonFormField<TypePeriodeRapport>(
                          value: _periodeSelectionnee,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            isDense: true,
                          ),
                          isExpanded: true,
                          items: [
                            const DropdownMenuItem(
                              value: TypePeriodeRapport.moisCourant,
                              child: Text('Mois courant', style: TextStyle(fontSize: 14)),
                            ),
                            const DropdownMenuItem(
                              value: TypePeriodeRapport.derniersMois3,
                              child: Text('3 derniers mois', style: TextStyle(fontSize: 14)),
                            ),
                            const DropdownMenuItem(
                              value: TypePeriodeRapport.derniersMois6,
                              child: Text('6 derniers mois', style: TextStyle(fontSize: 14)),
                            ),
                            const DropdownMenuItem(
                              value: TypePeriodeRapport.derniersMois12,
                              child: Text('12 derniers mois', style: TextStyle(fontSize: 14)),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              _periodeSelectionnee = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Date de référence', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _dateReference,
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              _dateReference = date;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                              const SizedBox(width: 6),
                              Text(DateFormat('dd/MM/yyyy').format(_dateReference), style: const TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Deuxième ligne: Agents et options
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Agents sélectionnés', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const SizedBox(height: 6),
                      Container(
                        height: 150, // Fixed height instead of flexible constraints
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: _personnelsDisponibles.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: Text('Aucun agent disponible', style: TextStyle(fontSize: 14))),
                              )
                            : ListView.builder(
                                itemCount: _personnelsDisponibles.length,
                                itemBuilder: (context, index) {
                                  final personnel = _personnelsDisponibles[index];
                                  final isSelected = _personnelsSelectionnes.contains(personnel.matricule);
                                  
                                  return CheckboxListTile(
                                    dense: true,
                                    visualDensity: VisualDensity.compact,
                                    title: Text(
                                      '${personnel.nom} ${personnel.prenom}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                    subtitle: Text(
                                      personnel.poste,
                                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                    ),
                                    value: isSelected,
                                    onChanged: (value) {
                                      setState(() {
                                        if (value == true) {
                                          _personnelsSelectionnes.add(personnel.matricule);
                                        } else {
                                          _personnelsSelectionnes.remove(personnel.matricule);
                                        }
                                      });
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 1,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SwitchListTile(
                        dense: true,
                        title: const Text('Grouper par agent', style: TextStyle(fontSize: 14)),
                        value: _grouperParAgent,
                        onChanged: (value) {
                          setState(() {
                            _grouperParAgent = value;
                          });
                        },
                      ),
                      if (_personnelsSelectionnes.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Chip(
                          label: Text(
                            '${_personnelsSelectionnes.length} sélectionné(s)',
                            style: const TextStyle(fontSize: 12),
                          ),
                          backgroundColor: Colors.indigo[100],
                          visualDensity: VisualDensity.compact,
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _personnelsSelectionnes.clear();
                            });
                          },
                          child: const Text('Tout désélectionner', style: TextStyle(fontSize: 12)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageVide() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Aucun rapport généré',
            style: TextStyle(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Configurez les filtres et cliquez sur "Générer Rapport"',
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildRapport() {
    final rapport = _rapportActuel!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildEnTeteRapport(rapport),
          const SizedBox(height: 24),
          _buildStatistiquesGlobales(rapport.statistiques),
          const SizedBox(height: 24),
          if (_grouperParAgent && rapport.statistiques.statistiquesParAgent.isNotEmpty) ...[
            _buildStatistiquesParAgent(rapport.statistiques.statistiquesParAgent),
            const SizedBox(height: 24),
          ],
          _buildListePaiements(rapport.paiements),
        ],
      ),
    );
  }

  Widget _buildEnTeteRapport(RapportPaiementsPersonnel rapport) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.analytics, color: Colors.indigo),
                SizedBox(width: 8),
                Text(
                  'Rapport de Paiements Personnel',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem(
                    'Période',
                    '${DateFormat('dd/MM/yyyy').format(rapport.dateDebut)} - ${DateFormat('dd/MM/yyyy').format(rapport.dateFin)}',
                    Icons.date_range,
                  ),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'Généré le',
                    DateFormat('dd/MM/yyyy à HH:mm').format(rapport.dateGeneration),
                    Icons.schedule,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatistiquesGlobales(StatistiquesPaiementsPersonnel stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques Globales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Agents',
                    stats.nombrePersonnels.toString(),
                    Icons.people,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Paiements',
                    stats.nombrePaiements.toString(),
                    Icons.payment,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Payé',
                    '${stats.totalMontantPaye.toStringAsFixed(2)} USD',
                    Icons.attach_money,
                    Colors.indigo,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildStatCard(
                    'Total Brut',
                    '${stats.totalMontantBrut.toStringAsFixed(2)} USD',
                    Icons.account_balance_wallet,
                    Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Déductions Totales',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDeductionItem('Avances', stats.totalDeductionsAvances),
                ),
                Expanded(
                  child: _buildDeductionItem('Retenues', stats.totalDeductionsRetenues),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDeductionItem('Impôts', stats.totalDeductionsImpots),
                ),
                Expanded(
                  child: _buildDeductionItem('CNSS', stats.totalDeductionsCnss),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionItem(String label, double montant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistiquesParAgent(Map<String, StatistiquesParAgent> statsParAgent) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques par Agent',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...statsParAgent.values.map((stats) => _buildAgentStatItem(stats)),
          ],
        ),
      ),
    );
  }

  Widget _buildAgentStatItem(StatistiquesParAgent stats) {
    return ExpansionTile(
      title: Text(
        '${stats.personnel.nom} ${stats.personnel.prenom}',
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${stats.nombrePaiements} paiement(s) - ${stats.totalMontantPaye.toStringAsFixed(2)} USD',
      ),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildAgentStatDetail('Montant Brut', stats.totalMontantBrut),
                  ),
                  Expanded(
                    child: _buildAgentStatDetail('Montant Net', stats.totalMontantNet),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildAgentStatDetail('Avances', stats.totalDeductionsAvances),
                  ),
                  Expanded(
                    child: _buildAgentStatDetail('Retenues', stats.totalDeductionsRetenues),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAgentStatDetail(String label, double montant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildListePaiements(List<PaiementDetailPersonnel> paiements) {
    if (paiements.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.payment_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun paiement trouvé',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Liste des Paiements (${paiements.length})',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Agent')),
                  DataColumn(label: Text('Période')),
                  DataColumn(label: Text('Montant Payé')),
                  DataColumn(label: Text('Montant Brut')),
                  DataColumn(label: Text('Déductions')),
                  DataColumn(label: Text('Type')),
                ],
                rows: paiements.map((paiement) {
                  final personnel = _personnelsDisponibles.firstWhere(
                    (p) => p.matricule == paiement.personnelMatricule,
                    orElse: () => PersonnelModel(
                      matricule: 'N/A',
                      nom: 'Inconnu',
                      prenom: '',
                      telephone: '',
                      poste: '',
                      dateEmbauche: DateTime.now(),
                      salaireBase: 0,
                    ),
                  );
                  
                  final totalDeductions = paiement.deductionsAvances +
                      paiement.deductionsRetenues +
                      paiement.deductionsImpots +
                      paiement.deductionsCnss;

                  return DataRow(
                    cells: [
                      DataCell(Text(DateFormat('dd/MM/yyyy').format(paiement.datePaiement))),
                      DataCell(Text('${personnel.nom} ${personnel.prenom}')),
                      DataCell(Text('${paiement.mois.toString().padLeft(2, '0')}/${paiement.annee}')),
                      DataCell(Text('${paiement.montantPaye.toStringAsFixed(2)} USD')),
                      DataCell(Text('${paiement.montantBrut.toStringAsFixed(2)} USD')),
                      DataCell(Text('${totalDeductions.toStringAsFixed(2)} USD')),
                      DataCell(Text(paiement.type)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
