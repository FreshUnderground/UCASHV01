import 'package:flutter/material.dart';
import '../models/personnel_model.dart';
import '../services/salaire_service.dart';

class MultiPeriodesSalaireWidget extends StatefulWidget {
  final PersonnelModel personnel;

  const MultiPeriodesSalaireWidget({
    Key? key,
    required this.personnel,
  }) : super(key: key);

  @override
  State<MultiPeriodesSalaireWidget> createState() => _MultiPeriodesSalaireWidgetState();
}

class _MultiPeriodesSalaireWidgetState extends State<MultiPeriodesSalaireWidget> {
  List<Map<String, dynamic>> _periodesDisponibles = [];
  List<Map<String, dynamic>> _periodesSelectionnees = [];
  Map<String, dynamic>? _calculTotal;
  bool _isLoading = false;
  final _montantServisController = TextEditingController();
  final _heuresSupController = TextEditingController(text: '0');
  final _bonusController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    _loadPeriodesDisponibles();
  }

  @override
  void dispose() {
    _montantServisController.dispose();
    _heuresSupController.dispose();
    _bonusController.dispose();
    super.dispose();
  }

  Future<void> _loadPeriodesDisponibles() async {
    setState(() => _isLoading = true);
    try {
      final periodes = await SalaireService.instance.getPeriodesDisponibles(widget.personnel.id!);
      setState(() {
        _periodesDisponibles = periodes;
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

  Future<void> _calculerTotal() async {
    if (_periodesSelectionnees.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final periodes = _periodesSelectionnees.map((p) => {
        'mois': p['mois'] as int,
        'annee': p['annee'] as int,
      }).toList();

      final calcul = await SalaireService.instance.calculerMontantTotalMultiPeriodes(
        personnelId: widget.personnel.id!,
        periodes: periodes,
        heuresSupplementaires: double.tryParse(_heuresSupController.text) ?? 0,
        bonus: double.tryParse(_bonusController.text) ?? 0,
      );

      setState(() {
        _calculTotal = calcul;
        _montantServisController.text = calcul['montantTotalNet'].toStringAsFixed(2);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur calcul: $e')),
        );
      }
    }
  }

  void _togglePeriode(Map<String, dynamic> periode) {
    setState(() {
      if (_periodesSelectionnees.any((p) => p['mois'] == periode['mois'] && p['annee'] == periode['annee'])) {
        _periodesSelectionnees.removeWhere((p) => p['mois'] == periode['mois'] && p['annee'] == periode['annee']);
      } else {
        _periodesSelectionnees.add(periode);
      }
    });
    _calculerTotal();
  }

  Future<void> _genererPaiement() async {
    if (_periodesSelectionnees.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez au moins une période')),
      );
      return;
    }

    final montantServi = double.tryParse(_montantServisController.text);
    if (montantServi == null || montantServi <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Montant servis invalide')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final periodes = _periodesSelectionnees.map((p) => {
        'mois': p['mois'] as int,
        'annee': p['annee'] as int,
      }).toList();

      final salaires = await SalaireService.instance.genererEtPayerSalaireMultiPeriodes(
        personnelId: widget.personnel.id!,
        periodes: periodes,
        montantTotalServi: montantServi,
        heuresSupplementaires: double.tryParse(_heuresSupController.text) ?? 0,
        bonus: double.tryParse(_bonusController.text) ?? 0,
        notes: 'Paiement multi-périodes généré le ${DateTime.now().toString().split(' ')[0]}',
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${salaires.length} salaires générés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Contrôles heures sup et bonus
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _heuresSupController,
                decoration: const InputDecoration(
                  labelText: 'Heures Sup.',
                  border: OutlineInputBorder(),
                  suffixText: 'USD',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculerTotal(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _bonusController,
                decoration: const InputDecoration(
                  labelText: 'Bonus',
                  border: OutlineInputBorder(),
                  suffixText: 'USD',
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculerTotal(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Liste des périodes
        const Text('Sélectionnez les périodes à payer:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        
        Expanded(
          child: ListView.builder(
            itemCount: _periodesDisponibles.length,
            itemBuilder: (context, index) {
              final periode = _periodesDisponibles[index];
              final isSelected = _periodesSelectionnees.any(
                (p) => p['mois'] == periode['mois'] && p['annee'] == periode['annee']
              );
              final peutEtrePaye = periode['peutEtrePaye'] as bool;

              return Card(
                color: isSelected ? Colors.blue[50] : null,
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: peutEtrePaye ? (_) => _togglePeriode(periode) : null,
                  title: Text('${periode['nomMois']} ${periode['annee']}'),
                  subtitle: Text(
                    'Statut: ${periode['statut']}' +
                    (periode['montantPaye'] > 0 ? ' - Payé: ${periode['montantPaye'].toStringAsFixed(2)} USD' : '')
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getStatusColor(periode['statut']).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _getStatusColor(periode['statut']).withOpacity(0.3)),
                    ),
                    child: Text(
                      periode['statut'],
                      style: TextStyle(
                        fontSize: 10,
                        color: _getStatusColor(periode['statut']),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),

        // Résumé du calcul
        if (_calculTotal != null) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RÉSUMÉ (${_calculTotal!['nombrePeriodes']} périodes)',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700]),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Brut:'),
                    Text('${_calculTotal!['montantTotalBrut'].toStringAsFixed(2)} USD', 
                         style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Avances déduites:'),
                    Text('-${_calculTotal!['totalAvances'].toStringAsFixed(2)} USD', 
                         style: TextStyle(color: Colors.red[600])),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Retenues:'),
                    Text('-${_calculTotal!['totalRetenues'].toStringAsFixed(2)} USD', 
                         style: TextStyle(color: Colors.red[600])),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('NET À PAYER:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${_calculTotal!['montantTotalNet'].toStringAsFixed(2)} USD', 
                         style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[700])),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Montant servis
          TextField(
            controller: _montantServisController,
            decoration: const InputDecoration(
              labelText: 'Montant Total Servis *',
              border: OutlineInputBorder(),
              suffixText: 'USD',
              prefixIcon: Icon(Icons.attach_money, color: Colors.green),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          // Boutons
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: _genererPaiement,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green[700]),
                  child: const Text('Générer Paiement'),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(String statut) {
    switch (statut) {
      case 'Payé':
        return Colors.green;
      case 'Partiellement payé':
        return Colors.orange;
      case 'En attente':
        return Colors.blue;
      case 'Non généré':
      default:
        return Colors.grey;
    }
  }
}
