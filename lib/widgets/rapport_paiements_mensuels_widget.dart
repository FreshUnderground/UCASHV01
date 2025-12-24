import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/salaire_service.dart';
import '../services/personnel_service.dart';
import '../models/salaire_model.dart';
import '../theme/ucash_typography.dart';

class RapportPaiementsMensuelsWidget extends StatefulWidget {
  const RapportPaiementsMensuelsWidget({super.key});

  @override
  State<RapportPaiementsMensuelsWidget> createState() => _RapportPaiementsMensuelsWidgetState();
}

class _RapportPaiementsMensuelsWidgetState extends State<RapportPaiementsMensuelsWidget> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  Map<String, dynamic>? _rapport;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadRapport();
  }

  Future<void> _loadRapport() async {
    setState(() => _isLoading = true);
    try {
      final rapport = await SalaireService.instance.getRapportMensuel(_selectedMonth, _selectedYear);
      setState(() {
        _rapport = rapport;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapport Mensuel des Paiements'),
        backgroundColor: Colors.indigo[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadRapport,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _rapport == null
                    ? const Center(child: Text('Aucune donnée'))
                    : _buildRapportContent(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showGenerateSalairesDialog,
        backgroundColor: Colors.green[700],
        icon: const Icon(Icons.add),
        label: const Text('Générer Salaires'),
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey[100],
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: InputDecoration(
                labelText: 'Mois',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: List.generate(12, (i) => i + 1).map((month) {
                return DropdownMenuItem(
                  value: month,
                  child: Text(_getMonthName(month)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _loadRapport();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: InputDecoration(
                labelText: 'Année',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: Colors.white,
              ),
              items: List.generate(5, (i) => DateTime.now().year - i).map((year) {
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedYear = value);
                  _loadRapport();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRapportContent() {
    if (_rapport == null) return const SizedBox();

    final nombreEmployes = _rapport!['nombre_employes'] as int;
    final salaireBrutTotal = _rapport!['salaire_brut_total'] as double;
    final totalDeductions = _rapport!['total_deductions'] as double;
    final salaireNetTotal = _rapport!['salaire_net_total'] as double;
    final montantPaye = _rapport!['montant_paye'] as double;
    final montantImpaye = _rapport!['montant_impaye'] as double;
    final nombrePayes = _rapport!['nombre_payes'] as int;
    final nombreEnAttente = _rapport!['nombre_en_attente'] as int;
    final salaires = _rapport!['salaires'] as List<SalaireModel>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Résumé Financier',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildSummaryCard(
                  'Employés',
                  nombreEmployes.toString(),
                  Icons.people,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildSummaryCard(
                  'Payés',
                  '$nombrePayes/${nombreEmployes}',
                  Icons.check_circle,
                  Colors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildAmountCard('Salaire Brut Total', salaireBrutTotal, Colors.blue),
          _buildAmountCard('Total Déductions', totalDeductions, Colors.orange),
          _buildAmountCard('Salaire Net Total', salaireNetTotal, Colors.purple),
          _buildAmountCard('Montant Payé', montantPaye, Colors.green),
          _buildAmountCard('Montant Impayé', montantImpaye, Colors.red),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Détail par Employé', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Text(
                '${salaires?.length ?? 0} salaires',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (salaires != null && salaires.isNotEmpty)
            ...salaires.map((salaire) => _buildSalaireCard(salaire))
          else
            Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text(
                        'Aucun salaire pour cette période',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _showGenerateSalairesDialog,
                        child: const Text('Générer les salaires'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountCard(String label, double amount, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.2),
          child: Icon(Icons.attach_money, color: color),
        ),
        title: Text(label),
        trailing: Text(
          '${amount.toStringAsFixed(2)} USD',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  Widget _buildSalaireCard(SalaireModel salaire) {
    final statusColor = _getStatusColor(salaire.statut);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(
            _getStatusIcon(salaire.statut),
            color: statusColor,
          ),
        ),
        title: Text(salaire.personnelNom ?? 'Personnel ${salaire.personnelMatricule}'),
        subtitle: Text('Net: ${salaire.salaireNet.toStringAsFixed(2)} USD'),
        trailing: Chip(
          label: Text(salaire.statut),
          backgroundColor: statusColor.withOpacity(0.2),
          labelStyle: TextStyle(color: statusColor, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildDetailRow('Salaire Brut', salaire.salaireBrut),
                _buildDetailRow('Avances Déduites', salaire.avancesDeduites, isNegative: true),
                _buildDetailRow('Crédits Déduits', salaire.creditsDeduits, isNegative: true),
                _buildDetailRow('Impôts', salaire.impots, isNegative: true),
                _buildDetailRow('CNSS', salaire.cotisationCnss, isNegative: true),
                const Divider(),
                _buildDetailRow('Salaire Net', salaire.salaireNet, isBold: true),
                _buildDetailRow('Montant Payé', salaire.montantPaye),
                if (salaire.montantRestant > 0)
                  _buildDetailRow('Reste à Payer', salaire.montantRestant, isNegative: true),
                const SizedBox(height: 12),
                if (salaire.statut != 'Paye')
                  ElevatedButton.icon(
                    onPressed: () => _showPaymentDialog(salaire),
                    icon: const Icon(Icons.payment),
                    label: const Text('Effectuer Paiement'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[700],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, double value, {bool isNegative = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal),
          ),
          Text(
            '${isNegative ? "-" : ""}${value.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isNegative ? Colors.red : (isBold ? Colors.green : null),
            ),
          ),
        ],
      ),
    );
  }

  void _showGenerateSalairesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Générer les Salaires'),
        content: Text(
          'Voulez-vous générer les salaires pour tous les employés actifs du mois de ${_getMonthName(_selectedMonth)} $_selectedYear ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final salaires = await SalaireService.instance.genererSalairesTousEmployes(
                  mois: _selectedMonth,
                  annee: _selectedYear,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${salaires.length} salaires générés avec succès')),
                  );
                  _loadRapport();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Générer'),
          ),
        ],
      ),
    );
  }

  void _showPaymentDialog(SalaireModel salaire) {
    final montantController = TextEditingController(
      text: salaire.montantRestant.toStringAsFixed(2),
    );
    String modePaiement = 'Especes';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effectuer un Paiement'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Employé: ${salaire.personnelNom}'),
            Text('Reste à payer: ${salaire.montantRestant.toStringAsFixed(2)} USD'),
            const SizedBox(height: 16),
            TextField(
              controller: montantController,
              decoration: const InputDecoration(
                labelText: 'Montant à payer',
                border: OutlineInputBorder(),
                suffixText: 'USD',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: modePaiement,
              decoration: const InputDecoration(
                labelText: 'Mode de paiement',
                border: OutlineInputBorder(),
              ),
              items: ['Especes', 'Virement', 'Cheque', 'Mobile_Money']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (value) => modePaiement = value!,
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
              final montant = double.tryParse(montantController.text);
              if (montant == null || montant <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Montant invalide')),
                );
                return;
              }

              Navigator.pop(context);
              try {
                await SalaireService.instance.payerSalaire(
                  salaireId: salaire.id!,
                  montant: montant,
                  modePaiement: modePaiement,
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Paiement enregistré avec succès')),
                  );
                  _loadRapport();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Erreur: $e')),
                  );
                }
              }
            },
            child: const Text('Payer'),
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

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'Paye':
        return Colors.green;
      case 'Partiel':
        return Colors.orange;
      case 'En_Attente':
        return Colors.blue;
      case 'Annule':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String statut) {
    switch (statut) {
      case 'Paye':
        return Icons.check_circle;
      case 'Partiel':
        return Icons.hourglass_bottom;
      case 'En_Attente':
        return Icons.pending;
      case 'Annule':
        return Icons.cancel;
      default:
        return Icons.help;
    }
  }
}
