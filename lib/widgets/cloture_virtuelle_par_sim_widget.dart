import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cloture_virtuelle_par_sim_model.dart';
import '../models/sim_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../models/operation_model.dart';
import '../models/compte_special_model.dart';
import '../models/virtual_transaction_model.dart';
import '../models/depot_client_model.dart';
import '../services/cloture_virtuelle_par_sim_service.dart';
import '../services/sim_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import '../services/compte_special_service.dart';

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
                    _buildInfoRow('Cash Physique Compté', '\$${cloture.cashDisponible.toStringAsFixed(2)}', Colors.blue),
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

    setState(() => _isGenerating = true);

    try {
      // Générer les clôtures avec les frais calculés automatiquement
      final cloturesGenerees = await ClotureVirtuelleParSimService.instance.genererClotureParSim(
        shopId: authService.currentUser!.shopId!,
        agentId: authService.currentUser!.id!,
        cloturePar: authService.currentUser!.username,
        date: _dateCloture,
      );

      // Afficher le dialog de saisie pour chaque SIM avec les frais calculés
      final saisies = await _showSaisieDialog(shopSims, cloturesGenerees);
      
      if (saisies == null) {
        setState(() => _isGenerating = false);
        return; // Annulé
      }

      // Appliquer les valeurs saisies pour chaque SIM
      // Le cash global est le même pour toutes les SIMs (on le divise)
      final cashGlobal = saisies.values.first['cashGlobal'] as double;
      final cashParSim = cloturesGenerees.isNotEmpty ? cashGlobal / cloturesGenerees.length : 0.0;
      
      for (int i = 0; i < cloturesGenerees.length; i++) {
        final simNumero = cloturesGenerees[i].simNumero;
        final saisie = saisies[simNumero];
        
        if (saisie != null) {
          cloturesGenerees[i] = cloturesGenerees[i].copyWith(
            soldeActuel: saisie['solde'] as double,
            cashDisponible: cashParSim, // Cash réparti équitablement
            notes: (saisie['notes'] as String).isNotEmpty ? saisie['notes'] as String : null,
          );
        }
      }

      setState(() {
        _cloturesGenerees = cloturesGenerees;
        _isGenerating = false;
      });

      if (cloturesGenerees.isEmpty) {
        _showError('Aucune clôture générée. Vérifiez que des SIMs existent.');
      }
    } catch (e) {
      setState(() => _isGenerating = false);
      _showError('Erreur lors de la génération: $e');
    }
  }

  /// Dialog de saisie: afficher chaque SIM avec solde calculé modifiable
  /// Cash global + Soldes par SIM (frais automatiques)
  Future<Map<String, Map<String, dynamic>>?> _showSaisieDialog(List<SimModel> sims, List<ClotureVirtuelleParSimModel> cloturesGenerees) async {
    // Controllers pour chaque SIM
    final controllers = <String, Map<String, TextEditingController>>{};
    
    // Créer un mapping des clôtures par numéro de SIM pour accès rapide
    final Map<String, ClotureVirtuelleParSimModel> cloturesParSim = {
      for (var cloture in cloturesGenerees) cloture.simNumero: cloture
    };
    
    // Pré-calculer les valeurs pour chaque SIM depuis les clôtures générées
    final dateDebut = DateTime(_dateCloture.year, _dateCloture.month, _dateCloture.day);
    final dateFin = DateTime(_dateCloture.year, _dateCloture.month, _dateCloture.day, 23, 59, 59);
    
    // Cash GLOBAL (utiliser la MÊME formule que virtual_transactions_widget.dart ligne 3344)
    // FORMULE: Cash Dispo = Solde Antérieur + FLOT Reçu - FLOT Envoyé + Dépôts Clients - Cash Servi
    double cashGlobalInitial = 0.0;
    try {
      // 1. Solde Antérieur (capitalInitialCash) - de la dernière clôture CAISSE
      final yesterday = dateDebut.subtract(const Duration(days: 1));
      final clotureHier = await LocalDB.instance.getClotureCaisseByDate(sims.first.shopId, yesterday);
      final soldeAnterieur = clotureHier?.soldeSaisiTotal ?? 0.0;
      
      // 2. FLOTs (flotsRecus et flotsEnvoyes) - Opérations de type FLOT
      final operations = await LocalDB.instance.getAllOperations();
      
      final flotsRecus = operations.where((op) =>
        op.type == OperationType.flotShopToShop &&
        op.shopDestinationId == sims.first.shopId &&
        (op.statut == OperationStatus.validee || op.statut == OperationStatus.enAttente) &&
        op.createdAt != null &&
        op.createdAt!.isAfter(dateDebut.subtract(const Duration(seconds: 1))) &&
        op.createdAt!.isBefore(dateFin.add(const Duration(seconds: 1)))
      ).fold<double>(0.0, (sum, op) => sum + op.montantNet);
      
      final flotsEnvoyes = operations.where((op) =>
        op.type == OperationType.flotShopToShop &&
        op.shopSourceId == sims.first.shopId &&
        (op.statut == OperationStatus.validee || op.statut == OperationStatus.enAttente) &&
        op.createdAt != null &&
        op.createdAt!.isAfter(dateDebut.subtract(const Duration(seconds: 1))) &&
        op.createdAt!.isBefore(dateFin.add(const Duration(seconds: 1)))
      ).fold<double>(0.0, (sum, op) => sum + op.montantNet);
      
      // 3. Dépôts Clients (depotsClients)
      final depots = await LocalDB.instance.getAllDepotsClients(shopId: sims.first.shopId);
      final depotsClients = depots.where((d) =>
        d.dateDepot.isAfter(dateDebut.subtract(const Duration(seconds: 1))) &&
        d.dateDepot.isBefore(dateFin.add(const Duration(seconds: 1)))
      ).fold<double>(0.0, (sum, d) => sum + d.montant);
      
      // 4. Cash Servi (cashServiValue) - Montant virtuel servi (après capture)
      final transactionsDuJour = await LocalDB.instance.getAllVirtualTransactions(
        shopId: sims.first.shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      
      final cashServi = transactionsDuJour
          .where((t) => t.statut == VirtualTransactionStatus.validee)
          .fold<double>(0.0, (sum, t) => sum + t.montantVirtuel);
      
      // APPLIQUER LA FORMULE EXACTE (ligne 3344 de virtual_transactions_widget.dart)
      cashGlobalInitial = soldeAnterieur + flotsRecus - flotsEnvoyes + depotsClients - cashServi;
      
      debugPrint('💰 Cash Disponible (formule Vue d\'Ensemble - ligne 3344):');
      debugPrint('   Solde Antérieur (capitalInitialCash): \$${soldeAnterieur.toStringAsFixed(2)}');
      debugPrint('   + FLOTs Reçus: \$${flotsRecus.toStringAsFixed(2)}');
      debugPrint('   - FLOTs Envoyés: \$${flotsEnvoyes.toStringAsFixed(2)}');
      debugPrint('   + Dépôts Clients: \$${depotsClients.toStringAsFixed(2)}');
      debugPrint('   - Cash Servi: \$${cashServi.toStringAsFixed(2)}');
      debugPrint('   = Cash Disponible: \$${cashGlobalInitial.toStringAsFixed(2)}');
    } catch (e) {
      debugPrint('❌ Erreur calcul cash disponible: $e');
      cashGlobalInitial = 0.0;
    }
    
    final cashGlobalController = TextEditingController(text: cashGlobalInitial.toStringAsFixed(2));
    
    // Récupérer les données communes pour tous les SIMs (pour le calcul du Virtuel Disponible)
    final transactionsDuJour = await LocalDB.instance.getAllVirtualTransactions(
      shopId: sims.first.shopId,
      dateDebut: dateDebut,
      dateFin: dateFin,
    );
    
    final depots = await LocalDB.instance.getAllDepotsClients(shopId: sims.first.shopId);
    final depotsDuJour = depots.where((d) =>
      d.dateDepot.isAfter(dateDebut.subtract(const Duration(seconds: 1))) &&
      d.dateDepot.isBefore(dateFin.add(const Duration(seconds: 1)))
    ).toList();
    
    for (var sim in sims) {
      // Récupérer la dernière clôture pour obtenir le solde, cash et frais
      final derniereClotureMap = await LocalDB.instance.getDerniereClotureParSim(
        simNumero: sim.numero,
        avant: dateDebut,
      );
      
      final derniereCloture = derniereClotureMap != null
          ? ClotureVirtuelleParSimModel.fromMap(derniereClotureMap as Map<String, dynamic>)
          : null;
      
      final soldeCalcule = derniereCloture?.soldeActuel ?? sim.soldeActuel;
      
      // CALCULER LE VIRTUEL DISPONIBLE (formule ligne 3610 de virtual_transactions_widget.dart)
      // FORMULE: Virtuel Dispo = Solde Antérieur + Captures - Retraits - Dépôts Clients
      
      // 1. Solde Antérieur Virtuel (de la dernière clôture)
      final soldeAnterieurVirtuel = derniereCloture?.soldeActuel ?? 0.0;
      
      // 2. Captures du jour pour cette SIM
      final capturesSim = transactionsDuJour.where((t) => 
        t.simNumero == sim.numero &&
        t.statut == VirtualTransactionStatus.validee
      ).fold<double>(0.0, (sum, t) => sum + t.montantVirtuel);
      
      // 3. Retraits du jour pour cette SIM
      final retraitsSim = await LocalDB.instance.getAllRetraitsVirtuels(
        shopSourceId: sims.first.shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
      );
      final retraitsMontantSim = retraitsSim.where((r) => r.simNumero == sim.numero)
          .fold<double>(0.0, (sum, r) => sum + r.montant);
      
      // 4. Dépôts Clients du jour pour cette SIM
      final depotsSim = depotsDuJour.where((d) => d.simNumero == sim.numero)
          .fold<double>(0.0, (sum, d) => sum + d.montant);
      
      // FORMULE FINALE
      final virtuelDisponible = soldeAnterieurVirtuel + capturesSim - retraitsMontantSim - depotsSim;
      
      controllers[sim.numero] = {
        'solde': TextEditingController(text: soldeCalcule.toStringAsFixed(2)),
        'notes': TextEditingController(),
        // Stocker les valeurs de la dernière clôture pour affichage
        'cashDisponible': TextEditingController(text: (derniereCloture?.cashDisponible ?? 0.0).toStringAsFixed(2)),
        'fraisAnterieur': TextEditingController(text: (derniereCloture?.fraisTotal ?? 0.0).toStringAsFixed(2)),
        'soldeAnterieur': TextEditingController(text: (derniereCloture?.soldeActuel ?? 0.0).toStringAsFixed(2)),
        // Stocker les composantes du Virtuel Disponible
        'virtuelDisponible': TextEditingController(text: virtuelDisponible.toStringAsFixed(2)),
        'capturesDuJour': TextEditingController(text: capturesSim.toStringAsFixed(2)),
        'retraitsDuJour': TextEditingController(text: retraitsMontantSim.toStringAsFixed(2)),
        'depotsDuJour': TextEditingController(text: depotsSim.toStringAsFixed(2)),
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
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              child: Column(
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
                                  fontSize: isMobile ? 10 : 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${sims.length} SIM(s) • Cash global + Soldes individuels',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Contenu scrollable
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Cash Global Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.amber.shade50, Colors.orange.shade50],
                              ),
                              border: Border(
                                bottom: BorderSide(color: Colors.orange.shade200, width: 2),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.account_balance_wallet, color: Colors.orange.shade700, size: 24),
                                    const SizedBox(width: 8),
                                    const Expanded(
                                      child: Text(
                                        'Cash Global',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: cashGlobalController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFDC6B19),
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Comptage cash physique',
                                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                    hintText: '0.00',
                                    prefixText: r'$ ',
                                    prefixStyle: const TextStyle(
                                      color: Color(0xFFDC6B19),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade300, width: 2),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade300, width: 2),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(color: Colors.orange.shade600, width: 2),
                                    ),
                                    filled: true,
                                    fillColor: Colors.white,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Liste des SIMs avec saisie
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.all(isMobile ? 12 : 16),
                            itemCount: sims.length,
                            itemBuilder: (context, index) {
                              final sim = sims[index];
                              final simControllers = controllers[sim.numero]!;
                              final soldeCalcule = double.tryParse(simControllers['solde']!.text) ?? 0.0;
                              
                              // Récupérer les frais calculés pour cette SIM (clôture en cours de génération)
                              final clotureSim = cloturesParSim[sim.numero];
                              final fraisCalcules = clotureSim?.fraisTotal ?? 0.0;
                              final fraisAnterieur = clotureSim?.fraisAnterieur ?? 0.0;
                              final fraisDuJour = clotureSim?.fraisDuJour ?? 0.0;
                              
                              // Récupérer les valeurs de la dernière clôture (stockées dans controllers)
                              final cashDisponibleAnterieur = double.tryParse(simControllers['cashDisponible']!.text) ?? 0.0;
                              final fraisAnterieurDerniereCloture = double.tryParse(simControllers['fraisAnterieur']!.text) ?? 0.0;
                              final soldeAnterieur = double.tryParse(simControllers['soldeAnterieur']!.text) ?? 0.0;
                              
                              // Récupérer les valeurs du Virtuel Disponible
                              final virtuelDisponible = double.tryParse(simControllers['virtuelDisponible']!.text) ?? 0.0;
                              final capturesDuJour = double.tryParse(simControllers['capturesDuJour']!.text) ?? 0.0;
                              final retraitsDuJour = double.tryParse(simControllers['retraitsDuJour']!.text) ?? 0.0;
                              final depotsDuJour = double.tryParse(simControllers['depotsDuJour']!.text) ?? 0.0;
                              
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
                                      const SizedBox(height: 16),
                                      
                                      // VIRTUEL DISPONIBLE (formule ligne 3610 de virtual_transactions_widget.dart)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.purple.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.cloud_upload, color: Colors.purple.shade700, size: 18),
                                                const SizedBox(width: 8),
                                                const Text(
                                                  'Virtuel Disponible',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            // Solde Antérieur
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  'Solde Antérieur:',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${soldeAnterieur.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.grey.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // Captures
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '+ Captures du jour:',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${capturesDuJour.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.green.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // Retraits
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '- Retraits (FLOT):',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${retraitsDuJour.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 4),
                                            // Dépôts Clients
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(
                                                  '- Dépôts Clients:',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.grey.shade700,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${depotsDuJour.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            const Divider(height: 1),
                                            const SizedBox(height: 8),
                                            // Résultat final
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  '= Virtuel Disponible:',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${virtuelDisponible.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: virtuelDisponible >= 0 ? Colors.purple.shade700 : Colors.red.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Solde Virtuel (seul champ modifiable)
                                      TextField(
                                        controller: simControllers['solde'],
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: soldeCalcule >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Solde Virtuel',
                                          labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                                          hintText: '0.00',
                                          prefixText: r'$ ',
                                          prefixStyle: TextStyle(
                                            color: soldeCalcule >= 0 ? Colors.green : Colors.red,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18,
                                          ),
                                          helperText: 'Solde dans la SIM • Calculé: \$${sim.soldeActuel.toStringAsFixed(2)}',
                                          helperStyle: const TextStyle(fontSize: 11),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          filled: true,
                                          fillColor: (soldeCalcule >= 0 ? Colors.green : Colors.red).withOpacity(0.05),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Frais calculés automatiquement (affichage seulement)
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.purple.shade50,
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(
                                            color: Colors.purple.shade200,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.calculate, color: Colors.purple.shade700, size: 20),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'Frais Calculés',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.purple,
                                                    ),
                                                  ),
                                                 
                                                  Text(
                                                    'Total: \$${fraisCalcules.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.purple,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
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
                          const SizedBox(height: 8),

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
                                      padding: EdgeInsets.symmetric(vertical: isMobile ? 10 : 14),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
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
      final cashGlobal = double.tryParse(cashGlobalController.text) ?? 0.0;
      
      saisies = <String, Map<String, dynamic>>{};
      for (var sim in sims) {
        final simControllers = controllers[sim.numero]!;
        saisies[sim.numero] = {
          'solde': double.tryParse(simControllers['solde']!.text) ?? 0.0,
          'cashGlobal': cashGlobal, // CASH GLOBAL partagé
          'notes': notesGlobales.text.trim(),
        };
      }
    }
    
    // Maintenant disposer les controllers
    for (var simControllers in controllers.values) {
      simControllers.values.forEach((c) => c.dispose());
    }
    cashGlobalController.dispose();
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
  void _afficherHistorique() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shop ID non disponible')),
      );
      return;
    }
    
    try {
      // Récupérer les clôtures pour la date sélectionnée
      final clotures = await ClotureVirtuelleParSimService.instance.getCloturesParDate(
        shopId: shopId,
        date: _dateCloture,
      );
      
      if (!mounted) return;
      
      if (clotures.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Aucune clôture trouvée pour le ${DateFormat('dd/MM/yyyy').format(_dateCloture)}')),
        );
        return;
      }
      
      // Afficher les clôtures dans un dialog
      await showDialog(
        context: context,
        builder: (context) => _buildHistoriqueDialog(clotures),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }
  
  /// Construire le dialog d'historique
  Widget _buildHistoriqueDialog(List<ClotureVirtuelleParSimModel> clotures) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF48bb78), Color(0xFF38a169)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.history, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Historique Clôtures - ${DateFormat('dd/MM/yyyy').format(_dateCloture)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (Provider.of<AuthService>(context, listen: false).currentUser?.role == 'ADMIN')
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: Colors.white),
                      onPressed: () => _supprimerToutesLesClotures(clotures),
                      tooltip: 'Supprimer toutes les clôtures de cette date',
                    ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Liste des clôtures
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: clotures.length,
                itemBuilder: (context, index) {
                  final cloture = clotures[index];
                  return _buildClotureCard(cloture, false);
                },
              ),
            ),
            
            // Bouton fermer
            Padding(
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF48bb78),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Fermer'),
              ),
            ),
          ],
        ),
      ),
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
  
  /// Supprimer toutes les clôtures de la date sélectionnée
  Future<void> _supprimerToutesLesClotures(List<ClotureVirtuelleParSimModel> clotures) async {
    if (clotures.isEmpty) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    
    // Vérifier que l'utilisateur est admin
    if (authService.currentUser?.role != 'ADMIN') {
      _showError('Seul un administrateur peut supprimer des clôtures');
      return;
    }
    
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      _showError('Shop ID non disponible');
      return;
    }
    
    // Confirmation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Supprimer toutes les clôtures'),
        content: Text(
          'Voulez-vous vraiment supprimer les ${clotures.length} clôture(s) du ${DateFormat('dd/MM/yyyy').format(_dateCloture)} ?\n\n'
          'Cette action est IRRÉVERSIBLE.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      await ClotureVirtuelleParSimService.instance.deleteCloturesParDate(
        shopId: shopId,
        date: _dateCloture,
      );
      
      if (mounted) {
        Navigator.of(context).pop(); // Fermer le dialog historique
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Clôtures supprimées avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Recharger les données
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        _showError('Erreur lors de la suppression: $e');
      }
    }
  }
}
