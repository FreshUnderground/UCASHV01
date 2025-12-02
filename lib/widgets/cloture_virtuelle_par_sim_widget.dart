import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cloture_virtuelle_par_sim_model.dart';
import '../models/sim_model.dart';
import '../services/cloture_virtuelle_par_sim_service.dart';
import '../services/sim_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';

/// Widget pour la clôture virtuelle détaillée par SIM
class ClotureVirtuelleParSimWidget extends StatefulWidget {
  const ClotureVirtuelleParSimWidget({Key? key}) : super(key: key);

  @override
  State<ClotureVirtuelleParSimWidget> createState() => _ClotureVirtuelleParSimWidgetState();
}

class _ClotureVirtuelleParSimWidgetState extends State<ClotureVirtuelleParSimWidget> {
  DateTime _dateCloture = DateTime.now();
  bool _isGenerating = false;
  bool _isSaving = false;
  List<ClotureVirtuelleParSimModel>? _cloturesGenerees;
  String? _notes;

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final simService = Provider.of<SimService>(context);

    // Filtrer les SIMs du shop de l'agent
    final shopSims = simService.sims.where((sim) => sim.shopId == authService.currentUser?.shopId).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Header avec gradient
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF48bb78), const Color(0xFF48bb78).withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(5.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phonelink_lock, color: Colors.white, size: 28),
                        const SizedBox(width: 4),
                        const Expanded(
                          child: Text(
                            'Clôture Virtuelle par SIM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.history, color: Colors.white),
                          onPressed: _afficherHistorique,
                          tooltip: 'Historique',
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${shopSims.length} SIM(s) actives',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sélecteur de date
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFF48bb78)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Date de clôture: ${_dateCloture.day}/${_dateCloture.month}/${_dateCloture.year}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
                TextButton.icon(
                  onPressed: _selectionnerDate,
                  icon: const Icon(Icons.edit),
                  label: const Text('Modifier'),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Contenu principal
          Expanded(
            child: _cloturesGenerees == null
                ? _buildVueSims(shopSims, authService)
                : _buildVueClotures(_cloturesGenerees!),
          ),

          // Actions
          if (_cloturesGenerees == null)
            _buildBoutonGenerer(authService)
          else
            _buildBoutonsSauvegarder(),
        ],
      ),
    );
  }

  /// Vue des SIMs avant génération
  Widget _buildVueSims(List<SimModel> sims, AuthService authService) {
    if (sims.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sim_card_alert, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune SIM trouvée',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive: déterminer le nombre de colonnes selon la largeur
        int crossAxisCount = 1;
        if (constraints.maxWidth >= 1200) {
          crossAxisCount = 3; // Desktop: 3 colonnes
        } else if (constraints.maxWidth >= 600) {
          crossAxisCount = 2; // Tablette: 2 colonnes
        }

        if (crossAxisCount == 1) {
          // Mobile: Liste verticale
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: sims.length,
            itemBuilder: (context, index) {
              final sim = sims[index];
              return _buildSimCard(sim);
            },
          );
        } else {
          // Tablette/Desktop: Grille
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1.5,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: sims.length,
            itemBuilder: (context, index) {
              final sim = sims[index];
              return _buildSimCard(sim);
            },
          );
        }
      },
    );
  }

  /// Carte d'une SIM avec plus de détails
  Widget _buildSimCard(SimModel sim) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Colors.white,
              _getOperatorColor(sim.operateur).withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _getOperatorColor(sim.operateur).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _getOperatorColor(sim.operateur).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.sim_card,
                      color: _getOperatorColor(sim.operateur),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sim.numero,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getOperatorColor(sim.operateur).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                sim.operateur,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _getOperatorColor(sim.operateur),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        'Solde Actuel',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${sim.soldeActuel.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: sim.soldeActuel >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              // Statistiques supplémentaires
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSimMiniStat(
                    'Shop',
                    'ID ${sim.shopId}',
                    Icons.store,
                    Colors.blue,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildSimMiniStat(
                    'Statut',
                    'Actif',
                    Icons.check_circle,
                    Colors.green,
                  ),
                  Container(width: 1, height: 40, color: Colors.grey[300]),
                  _buildSimMiniStat(
                    'Type',
                    'Virtuel',
                    Icons.phonelink,
                    Colors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Mini statistique pour la carte SIM
  Widget _buildSimMiniStat(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Vue des clôtures générées avec responsive
  Widget _buildVueClotures(List<ClotureVirtuelleParSimModel> clotures) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        
        return ListView.builder(
          padding: EdgeInsets.all(isMobile ? 12 : 16),
          itemCount: clotures.length,
          itemBuilder: (context, index) {
            final cloture = clotures[index];
            return _buildClotureCard(cloture, isMobile);
          },
        );
      },
    );
  }

  /// Carte de clôture générée (responsive)
  Widget _buildClotureCard(ClotureVirtuelleParSimModel cloture, bool isMobile) {
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 12 : 16),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            decoration: BoxDecoration(
              color: _getOperatorColor(cloture.operateur).withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(Icons.sim_card, color: _getOperatorColor(cloture.operateur)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cloture.simNumero,
                        style: TextStyle(
                          fontSize: isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cloture.operateur,
                        style: TextStyle(
                          fontSize: isMobile ? 12 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Contenu
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              children: [
                // Soldes
                _buildSection(
                  'Soldes',
                  Icons.account_balance_wallet,
                  [
                    _buildInfoRow('Solde Antérieur', '\$${cloture.soldeAnterieur.toStringAsFixed(2)}', Colors.grey),
                    _buildInfoRow('Solde Actuel', '\$${cloture.soldeActuel.toStringAsFixed(2)}', 
                      cloture.soldeActuel >= 0 ? Colors.green : Colors.red, bold: true),
                    _buildInfoRow('Cash Disponible', '\$${cloture.cashDisponible.toStringAsFixed(2)}', Colors.blue),
                  ],
                  isMobile,
                ),
                Divider(height: isMobile ? 20 : 24),

                // Frais
                _buildSection(
                  'Frais',
                  Icons.attach_money,
                  [
                    _buildInfoRow('Frais Antérieur', '\$${cloture.fraisAnterieur.toStringAsFixed(2)}', Colors.grey),
                    _buildInfoRow('Frais du Jour', '\$${cloture.fraisDuJour.toStringAsFixed(2)}', Colors.orange),
                    _buildInfoRow('Frais Total', '\$${cloture.fraisTotal.toStringAsFixed(2)}', Colors.deepOrange, bold: true),
                  ],
                  isMobile,
                ),
                Divider(height: isMobile ? 20 : 24),

                // Transactions
                _buildSection(
                  'Transactions du Jour',
                  Icons.compare_arrows,
                  [
                    _buildInfoRow('Captures', '${cloture.nombreCaptures} (\$${cloture.montantCaptures.toStringAsFixed(2)})', Colors.green),
                    _buildInfoRow('Servies', '${cloture.nombreServies} (\$${cloture.montantServies.toStringAsFixed(2)})', Colors.blue),
                    _buildInfoRow('Cash Servi', '\$${cloture.cashServi.toStringAsFixed(2)}', Colors.purple),
                    _buildInfoRow('En Attente', '${cloture.nombreEnAttente} (\$${cloture.montantEnAttente.toStringAsFixed(2)})', Colors.orange),
                  ],
                  isMobile,
                ),
                Divider(height: isMobile ? 20 : 24),

                // Mouvements
                _buildSection(
                  'Mouvements',
                  Icons.swap_horiz,
                  [
                    _buildInfoRow('Retraits', '${cloture.nombreRetraits} (\$${cloture.montantRetraits.toStringAsFixed(2)})', Colors.red),
                    _buildInfoRow('Dépôts Clients', '${cloture.nombreDepots} (\$${cloture.montantDepots.toStringAsFixed(2)})', Colors.teal),
                  ],
                  isMobile,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String titre, IconData icon, List<Widget> rows, bool isMobile) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: isMobile ? 18 : 20, color: const Color(0xFF48bb78)),
            const SizedBox(width: 8),
            Text(
              titre,
              style: TextStyle(
                fontSize: isMobile ? 14 : 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: isMobile ? 8 : 12),
        ...rows,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Bouton pour générer la clôture
  Widget _buildBoutonGenerer(AuthService authService) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isGenerating ? null : () => _genererClotures(authService),
            icon: _isGenerating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.calculate),
            label: Text(_isGenerating ? 'Génération en cours...' : 'Générer la Clôture'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF48bb78),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ),
      ),
    );
  }

  /// Boutons pour sauvegarder ou annuler
  Widget _buildBoutonsSauvegarder() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _isSaving ? null : _annuler,
                icon: const Icon(Icons.cancel),
                label: const Text('Annuler'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _sauvegarderClotures,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSaving ? 'Sauvegarde...' : 'Sauvegarder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Sélectionner la date
  Future<void> _selectionnerDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dateCloture,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('fr', 'FR'),
    );

    if (date != null) {
      setState(() {
        _dateCloture = date;
        _cloturesGenerees = null; // Réinitialiser si la date change
      });
    }
  }

  /// Générer les clôtures avec dialog de saisie par SIM
  Future<void> _genererClotures(AuthService authService) async {
    if (authService.currentUser == null) {
      _showError('Utilisateur non connecté');
      return;
    }

    final simService = Provider.of<SimService>(context, listen: false);
    final shopSims = simService.sims.where((sim) => sim.shopId == authService.currentUser?.shopId).toList();

    if (shopSims.isEmpty) {
      _showError('Aucune SIM trouvée pour ce shop');
      return;
    }

    // Afficher le dialog de saisie pour chaque SIM
    final saisies = await _showSaisieDialog(shopSims);
    
    if (saisies == null) return; // Annulé

    setState(() => _isGenerating = true);

    try {
      final clotures = await ClotureVirtuelleParSimService.instance.genererClotureParSim(
        shopId: authService.currentUser!.shopId!,
        agentId: authService.currentUser!.id!,
        cloturePar: authService.currentUser!.username,
        date: _dateCloture,
      );

      // Appliquer les valeurs saisies pour chaque SIM
      for (int i = 0; i < clotures.length; i++) {
        final simNumero = clotures[i].simNumero;
        final saisie = saisies[simNumero];
        
        if (saisie != null) {
          clotures[i] = clotures[i].copyWith(
            soldeActuel: saisie['solde'] as double,
            cashDisponible: saisie['cashDisponible'] as double,
            notes: (saisie['notes'] as String).isNotEmpty ? saisie['notes'] as String : null,
          );
        }
      }

      setState(() {
        _cloturesGenerees = clotures;
        _isGenerating = false;
      });

      if (clotures.isEmpty) {
        _showError('Aucune clôture générée. Vérifiez que des SIMs existent.');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showError('Erreur lors de la génération: $e');
    }
  }

  /// Dialog de saisie: afficher chaque SIM avec solde calculé modifiable
  /// Similaire au formulaire de clôture caisse
  Future<Map<String, Map<String, dynamic>>?> _showSaisieDialog(List<SimModel> sims) async {
    // Controllers pour chaque SIM
    final controllers = <String, Map<String, TextEditingController>>{};
    
    // Pré-calculer les valeurs pour chaque SIM depuis les clôtures générées
    // On utilise le service pour calculer automatiquement
    final dateDebut = DateTime(_dateCloture.year, _dateCloture.month, _dateCloture.day);
    final dateFin = DateTime(_dateCloture.year, _dateCloture.month, _dateCloture.day, 23, 59, 59);
    
    for (var sim in sims) {
      // Récupérer la dernière clôture pour obtenir les valeurs calculées
      final derniereClotureMap = await LocalDB.instance.getDerniereClotureParSim(
        simNumero: sim.numero,
        avant: dateDebut,
      );
      
      final derniereCloture = derniereClotureMap != null
          ? ClotureVirtuelleParSimModel.fromMap(derniereClotureMap as Map<String, dynamic>)
          : null;
      
      // Calculer le cash disponible: on prend le solde de la dernière clôture ou le solde actuel
      final soldeCalcule = derniereCloture?.soldeActuel ?? sim.soldeActuel;
      final cashDisponibleCalcule = derniereCloture?.cashDisponible ?? 0.0;
      
      controllers[sim.numero] = {
        'solde': TextEditingController(text: soldeCalcule.toStringAsFixed(2)),
        'cashDisponible': TextEditingController(text: cashDisponibleCalcule.toStringAsFixed(2)),
        'notes': TextEditingController(),
      };
    }
    
    final notesGlobales = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth < 700 ? constraints.maxWidth : 700.0;
            final isMobile = constraints.maxWidth < 600;
            
            return Container(
              width: maxWidth,
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(isMobile ? 16 : 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF48bb78), Color(0xFF38a169)],
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phonelink_lock, color: Colors.white, size: 28),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Clôture Virtuelle par SIM',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: isMobile ? 18 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${sims.length} SIM(s) • Vérifiez et ajustez les montants',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Info banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 18, color: Colors.blue.shade700),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Montants calculés automatiquement. Modifiez si nécessaire.',
                            style: TextStyle(fontSize: 12, color: Colors.blue.shade800),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Liste des SIMs avec saisie
                  Expanded(
                    child: ListView.builder(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      itemCount: sims.length,
                      itemBuilder: (context, index) {
                        final sim = sims[index];
                        final simControllers = controllers[sim.numero]!;
                        final soldeCalcule = double.tryParse(simControllers['solde']!.text) ?? 0.0;
                        
                        return Card(
                          margin: const EdgeInsets.only(bottom: 16),
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _getOperatorColor(sim.operateur).withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 14 : 18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header SIM
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: _getOperatorColor(sim.operateur).withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: _getOperatorColor(sim.operateur),
                                          width: 2,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.sim_card,
                                        color: _getOperatorColor(sim.operateur),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            sim.numero,
                                            style: TextStyle(
                                              fontSize: isMobile ? 15 : 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: _getOperatorColor(sim.operateur).withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              sim.operateur,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: _getOperatorColor(sim.operateur),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                const Divider(height: 24),
                                
                                // Champs de saisie côte à côte
                                Row(
                                  children: [
                                    // Solde Calculé
                                    Expanded(
                                      child: TextField(
                                        controller: simControllers['solde'],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: soldeCalcule >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Solde Virtuel',
                                          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          hintText: '0.00',
                                          prefixText: '\$ ',
                                          prefixStyle: TextStyle(
                                            color: soldeCalcule >= 0 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          helperText: 'Calculé: \$${sim.soldeActuel.toStringAsFixed(2)}',
                                          helperStyle: const TextStyle(fontSize: 11),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          filled: true,
                                          fillColor: (soldeCalcule >= 0 ? Colors.green : Colors.red).withOpacity(0.05),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    
                                    // Cash Disponible
                                    Expanded(
                                      child: TextField(
                                        controller: simControllers['cashDisponible'],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2563eb),
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Cash Disponible',
                                          labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                          hintText: '0.00',
                                          prefixText: '\$ ',
                                          prefixStyle: const TextStyle(
                                            color: Color(0xFF2563eb),
                                            fontWeight: FontWeight.bold,
                                          ),
                                          helperText: 'Comptage physique',
                                          helperStyle: const TextStyle(fontSize: 11),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          filled: true,
                                          fillColor: Colors.blue.withOpacity(0.05),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Notes globales
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
                    child: TextField(
                      controller: notesGlobales,
                      maxLines: 2,
                      decoration: InputDecoration(
                        labelText: '📝 Notes globales (optionnel)',
                        hintText: 'Remarques sur cette clôture...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        contentPadding: const EdgeInsets.all(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Actions
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).pop(false),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Annuler'),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ElevatedButton.icon(
                            onPressed: () => Navigator.of(context).pop(true),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Clôturer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF48bb78),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: isMobile ? 12 : 14),
                              textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // Récupérer les valeurs AVANT de disposer les controllers
    Map<String, Map<String, dynamic>>? saisies;
    
    if (result == true) {
      saisies = <String, Map<String, dynamic>>{};
      for (var sim in sims) {
        final simControllers = controllers[sim.numero]!;
        saisies[sim.numero] = {
          'solde': double.tryParse(simControllers['solde']!.text) ?? 0.0,
          'cashDisponible': double.tryParse(simControllers['cashDisponible']!.text) ?? 0.0,
          'notes': notesGlobales.text.trim(),
        };
      }
    }
    
    // Maintenant disposer les controllers
    for (var simControllers in controllers.values) {
      simControllers.values.forEach((c) => c.dispose());
    }
    notesGlobales.dispose();

    return saisies;
  }

  /// Sauvegarder les clôtures
  Future<void> _sauvegarderClotures() async {
    if (_cloturesGenerees == null || _cloturesGenerees!.isEmpty) return;

    setState(() => _isSaving = true);

    try {
      await ClotureVirtuelleParSimService.instance.sauvegarderClotures(_cloturesGenerees!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${_cloturesGenerees!.length} clôture(s) sauvegardée(s)'),
            backgroundColor: Colors.green,
          ),
        );

        // Réinitialiser
        setState(() {
          _cloturesGenerees = null;
          _isSaving = false;
        });
      }
    } catch (e) {
      setState(() => _isSaving = false);
      _showError('Erreur lors de la sauvegarde: $e');
    }
  }

  /// Annuler
  void _annuler() {
    setState(() {
      _cloturesGenerees = null;
    });
  }

  /// Afficher l'historique
  void _afficherHistorique() {
    // TODO: Implémenter l'affichage de l'historique
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Historique à venir')),
    );
  }

  /// Afficher une erreur
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// Couleur selon l'opérateur
  Color _getOperatorColor(String operateur) {
    switch (operateur.toUpperCase()) {
      case 'AIRTEL':
        return Colors.red;
      case 'VODACOM':
        return Colors.red.shade900;
      case 'ORANGE':
        return Colors.orange;
      case 'AFRICELL':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
