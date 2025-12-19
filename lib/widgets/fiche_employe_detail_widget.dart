import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/personnel_model.dart';
import '../models/salaire_model.dart';
import '../models/avance_personnel_model.dart';
import '../models/credit_personnel_model.dart';
import '../models/retenue_personnel_model.dart';
import '../services/personnel_service.dart';
import '../services/salaire_service.dart';
import '../services/avance_service.dart';
import '../services/credit_service.dart';
import '../services/retenue_service.dart';
import '../services/fiche_paie_pdf_service.dart';
import '../services/historique_paiements_pdf_service.dart';
import '../services/tableau_paie_service.dart';
import 'pdf_viewer_dialog.dart';

class FicheEmployeDetailWidget extends StatefulWidget {
  final PersonnelModel personnel;
  final int initialTabIndex;

  const FicheEmployeDetailWidget({
    super.key,
    required this.personnel,
    this.initialTabIndex = 0,
  });

  @override
  State<FicheEmployeDetailWidget> createState() => _FicheEmployeDetailWidgetState();
}

class _FicheEmployeDetailWidgetState extends State<FicheEmployeDetailWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<SalaireModel> _salaires = [];
  List<AvancePersonnelModel> _avances = [];
  List<CreditPersonnelModel> _credits = [];
  List<RetenuePersonnelModel> _retenues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 5,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    
    // Listener pour suivre les changements d'onglet
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        // Rafraîchir les données si nécessaire
        // Par exemple pour les onglets dynamiques
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
    
    try {
      // Charger tous les services
      await SalaireService.instance.loadSalaires(forceRefresh: true);
      await AvanceService.instance.loadAvances(forceRefresh: true);
      await CreditService.instance.loadCredits(forceRefresh: true);
      await RetenueService.instance.loadRetenues(forceRefresh: true);

      // Filtrer par employé
      _salaires = SalaireService.instance.salaires
          .where((s) => s.personnelId == widget.personnel.id)
          .toList()
        ..sort((a, b) => b.annee.compareTo(a.annee) != 0 
            ? b.annee.compareTo(a.annee) 
            : b.mois.compareTo(a.mois));

      _avances = AvanceService.instance.avances
          .where((a) => a.personnelId == widget.personnel.id)
          .toList()
        ..sort((a, b) => b.dateAvance.compareTo(a.dateAvance));

      _credits = CreditService.instance.credits
          .where((c) => c.personnelId == widget.personnel.id)
          .toList()
        ..sort((a, b) => b.dateOctroi.compareTo(a.dateOctroi));
        
      _retenues = RetenueService.instance.retenues
          .where((r) => r.personnelId == widget.personnel.id)
          .toList()
        ..sort((a, b) => b.dateCreation.compareTo(a.dateCreation));

      setState(() => _isLoading = false);
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
        title: Text(
          widget.personnel.nomComplet,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 4,
        shadowColor: Colors.blue.withOpacity(0.3),
        actions: [
          // Bouton de rafraîchissement avec animation
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser les données',
            onPressed: () async {
              // Animation de rotation pendant le chargement
              setState(() => _isLoading = true);
              await _loadData();
              if (mounted) setState(() => _isLoading = false);
            },
          ),
          // Bouton d'options
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String result) {
              // À implémenter: actions supplémentaires
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'export',
                child: ListTile(
                  leading: Icon(Icons.picture_as_pdf, color: Colors.red),
                  title: Text('Exporter en PDF'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'share',
                child: ListTile(
                  leading: Icon(Icons.share, color: Colors.blue),
                  title: Text('Partager'),
                ),
              ),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: const [
            Tab(icon: Icon(Icons.person, size: 20), text: 'Informations'),
            Tab(icon: Icon(Icons.attach_money, size: 20), text: 'Salaires'),
            Tab(icon: Icon(Icons.fast_forward, size: 20), text: 'Avances'),
            Tab(icon: Icon(Icons.remove_circle, size: 20), text: 'Retenues'),
            Tab(icon: Icon(Icons.credit_card, size: 20), text: 'Crédits'),
          ],
        ),
      ),
      body: _isLoading
          ? Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animation de chargement moderne
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                          strokeWidth: 3,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Chargement des données...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Veuillez patienter',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildInformationsTab(),
                _buildSalairesTab(),
                _buildAvancesTab(),
                _buildRetenuesTab(),
                _buildCreditsTab(),
              ],
            ),
    );
  }

  // ============================================================================
  // ONGLET INFORMATIONS
  // ============================================================================

  Widget _buildInformationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header moderne avec photo et infos principales
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.blue[700]!, Colors.blue[400]!],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  // Avatar moderne
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Text(
                        widget.personnel.nom.substring(0, 1).toUpperCase(),
                        style: TextStyle(
                          fontSize: 40, 
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Informations principales
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.personnel.nomComplet,
                          style: const TextStyle(
                            fontSize: 26, 
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _getStatusColor(widget.personnel.statut).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _getStatusColor(widget.personnel.statut)),
                          ),
                          child: Text(
                            widget.personnel.statut,
                            style: TextStyle(
                              color: _getStatusColor(widget.personnel.statut),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.personnel.poste,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Matricule: ${widget.personnel.matricule}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Informations personnelles
          _buildModernSection(
            'Informations Personnelles', 
            Icons.person,
            [
              _buildModernInfoRow('Matricule', widget.personnel.matricule, Icons.badge),
              _buildModernInfoRow('Téléphone', widget.personnel.telephone, Icons.phone),
              if (widget.personnel.email != null)
                _buildModernInfoRow('Email', widget.personnel.email!, Icons.email),
              if (widget.personnel.adresse != null)
                _buildModernInfoRow('Adresse', widget.personnel.adresse!, Icons.location_on),
              if (widget.personnel.sexe != null)
                _buildModernInfoRow('Sexe', widget.personnel.sexe!, Icons.transgender),
              if (widget.personnel.etatCivil != null)
                _buildModernInfoRow('État Civil', widget.personnel.etatCivil!, Icons.family_restroom),
              if (widget.personnel.nombreEnfants != null)
                _buildModernInfoRow('Nombre d\'Enfants', widget.personnel.nombreEnfants.toString(), Icons.child_care),
            ],
          ),

          const SizedBox(height: 16),

          // Informations professionnelles
          _buildModernSection(
            'Informations Professionnelles', 
            Icons.work,
            [
              _buildModernInfoRow('Poste', widget.personnel.poste, Icons.work_outline),
              if (widget.personnel.departement != null)
                _buildModernInfoRow('Département', widget.personnel.departement!, Icons.business),
              _buildModernInfoRow('Type Contrat', widget.personnel.typeContrat, Icons.description),
              _buildModernInfoRow('Date Embauche', _formatDate(widget.personnel.dateEmbauche), Icons.calendar_today),
              if (widget.personnel.dateFinContrat != null)
                _buildModernInfoRow('Fin Contrat', _formatDate(widget.personnel.dateFinContrat!), Icons.event_busy),
            ],
          ),

          const SizedBox(height: 16),

          // Informations salariales
          _buildModernSection(
            'Informations Salariales', 
            Icons.account_balance_wallet,
            [
              _buildModernInfoRow('Salaire Base', '${widget.personnel.salaireBase} ${widget.personnel.deviseSalaire}', Icons.payments),
              _buildModernInfoRow('Prime Transport', '${widget.personnel.primeTransport} ${widget.personnel.deviseSalaire}', Icons.local_shipping),
              _buildModernInfoRow('Prime Logement', '${widget.personnel.primeLogement} ${widget.personnel.deviseSalaire}', Icons.home),
              _buildModernInfoRow('Prime Fonction', '${widget.personnel.primeFonction} ${widget.personnel.deviseSalaire}', Icons.business_center),
              _buildModernInfoRow('Autres Primes', '${widget.personnel.autresPrimes} ${widget.personnel.deviseSalaire}', Icons.card_giftcard),
              const Divider(thickness: 1, height: 24),
              _buildModernInfoRow(
                'TOTAL MENSUEL',
                '${widget.personnel.salaireTotal} ${widget.personnel.deviseSalaire}',
                Icons.calculate,
                isBold: true,
                valueColor: Colors.green[700],
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Statistiques globales
          _buildStatisticsCard(),
        ],
      ),
    );
  }

  Widget _buildStatisticsCard() {
    final totalSalaires = _salaires.fold<double>(0.0, (sum, s) => sum + s.salaireNet);
    final totalAvances = _avances.fold<double>(0.0, (sum, a) => sum + a.montant);
    final totalCredits = _credits.fold<double>(0.0, (sum, c) => sum + c.montantCredit);
    final totalRembourse = _avances.fold<double>(0.0, (sum, a) => sum + a.montantRembourse) +
                           _credits.fold<double>(0.0, (sum, c) => sum + c.montantRembourse);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue[50]!, Colors.blue[100]!],
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.analytics, color: Colors.blue[700], size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Statistiques Globales',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Grille des statistiques
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.2,
                children: [
                  _buildModernStatItem('Salaires', _salaires.length.toString(), Icons.attach_money, Colors.green),
                  _buildModernStatItem('Avances', _avances.length.toString(), Icons.fast_forward, Colors.orange),
                  _buildModernStatItem('Crédits', _credits.length.toString(), Icons.credit_card, Colors.purple),
                  _buildModernStatItem('Total Net', '${totalSalaires.toStringAsFixed(0)}', Icons.account_balance, Colors.blue),
                  _buildModernStatItem('Total Avances', '${totalAvances.toStringAsFixed(0)}', Icons.money_off, Colors.red),
                  _buildModernStatItem('Remboursé', '${totalRembourse.toStringAsFixed(0)}', Icons.check_circle, Colors.teal),
                ],
              ),
              const SizedBox(height: 20),
              // Détails financiers
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    _buildInfoRow('Total Salaires Net', '${totalSalaires.toStringAsFixed(2)} USD'),
                    _buildInfoRow('Total Avances', '${totalAvances.toStringAsFixed(2)} USD'),
                    _buildInfoRow('Total Crédits', '${totalCredits.toStringAsFixed(2)} USD'),
                    _buildInfoRow('Total Remboursé', '${totalRembourse.toStringAsFixed(2)} USD'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  // ============================================================================
  // ONGLET SALAIRES
  // ============================================================================

  Widget _buildSalairesTab() {
    if (_salaires.isEmpty) {
      return _buildEmptyState('Aucun salaire', Icons.attach_money);
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _salaires.length,
          itemBuilder: (context, index) {
            final salaire = _salaires[index];
            return _buildSalaireCard(salaire);
          },
        ),
        // Boutons flottants pour imprimer
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                onPressed: _imprimerTableauPaieAnnuel,
                icon: const Icon(Icons.table_chart),
                label: const Text('Tableau Annuel'),
                backgroundColor: Colors.green[700],
                foregroundColor: Colors.white,
                heroTag: 'tableau_annuel',
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                onPressed: _imprimerHistoriquePaiements,
                icon: const Icon(Icons.print),
                label: const Text('Historique'),
                backgroundColor: Colors.indigo[700],
                foregroundColor: Colors.white,
                heroTag: 'historique',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSalaireCard(SalaireModel salaire) {
    final statusColor = _getSalaireStatusColor(salaire.statut);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(Icons.attach_money, color: statusColor),
        ),
        title: Text('${_getMonthName(salaire.mois)} ${salaire.annee}'),
        subtitle: Text('Net: ${salaire.salaireNet.toStringAsFixed(2)} ${salaire.devise}'),
        trailing: Chip(
          label: Text(salaire.statut),
          backgroundColor: statusColor.withOpacity(0.2),
          labelStyle: TextStyle(color: statusColor, fontSize: 11),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Détails du salaire
                _buildSalaireDetailRow('Salaire Brut', salaire.salaireBrut, salaire.devise),
                const Divider(),
                _buildSalaireDetailRow('Avances Déduites', salaire.avancesDeduites, salaire.devise, isNegative: true),
                _buildSalaireDetailRow('Retenu', salaire.retenueDisciplinaire + salaire.retenueAbsences, salaire.devise, isNegative: true),
                _buildSalaireDetailRow('Impôts', salaire.impots, salaire.devise, isNegative: true),
                _buildSalaireDetailRow('CNSS', salaire.cotisationCnss, salaire.devise, isNegative: true),
                _buildSalaireDetailRow('Autres Déductions', salaire.autresDeductions, salaire.devise, isNegative: true),
                const Divider(),
                _buildSalaireDetailRow('Salaire Net', salaire.salaireNet, salaire.devise, isBold: true),
                const SizedBox(height: 12),
                
                // Historique des paiements
                Container(
                  padding: const EdgeInsets.all(12),
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
                          Icon(Icons.history, color: Colors.blue[700], size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'HISTORIQUE DES PAIEMENTS',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildSalaireDetailRow('Montant Payé', salaire.montantPaye, salaire.devise, valueColor: Colors.green[700]),
                      if (salaire.montantRestant > 0)
                        _buildSalaireDetailRow('Reste à Payer', salaire.montantRestant, salaire.devise, valueColor: Colors.red[700]),
                      
                      // Afficher tous les paiements de l'historique
                      if (salaire.historiquePaiements.isNotEmpty)
                        _buildHistoriquePaiements(salaire),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Boutons d'action
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _viewFichePaie(salaire),
                        icon: const Icon(Icons.description, size: 18),
                        label: const Text('Voir Fiche'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue[700],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _downloadFichePaie(salaire),
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Télécharger'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalaireDetailRow(String label, double value, String devise, {bool isNegative = false, bool isBold = false, Color? valueColor}) {
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
            '${isNegative ? "-" : ""}${value.toStringAsFixed(2)} $devise',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: valueColor ?? (isNegative ? Colors.red : (isBold ? Colors.green : null)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoriquePaiements(SalaireModel salaire) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const Divider(),
        const Text(
          'Détail des paiements:',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        ...salaire.historiquePaiements.asMap().entries.map((entry) {
          final index = entry.key + 1;
          final paiement = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.blue[700],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$index',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${paiement.montant.toStringAsFixed(2)} ${salaire.devise}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDate(paiement.datePaiement),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      if (paiement.notes != null)
                        Text(
                          paiement.notes!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  // ============================================================================
  // ONGLET AVANCES
  // ============================================================================

  Widget _buildAvancesTab() {
    if (_avances.isEmpty) {
      return _buildEmptyState('Aucune avance', Icons.fast_forward);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _avances.length,
      itemBuilder: (context, index) {
        final avance = _avances[index];
        return _buildAvanceCard(avance);
      },
    );
  }

  Widget _buildAvanceCard(AvancePersonnelModel avance) {
    final statusColor = _getAvanceStatusColor(avance.statut);
    final progress = avance.montant > 0 
        ? (avance.montantRembourse / avance.montant) 
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.fast_forward, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(avance.dateAvance),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Chip(
                  label: Text(avance.statut),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Montant Avance', '${avance.montant.toStringAsFixed(2)} USD'),
            _buildInfoRow('Montant Remboursé', '${avance.montantRembourse.toStringAsFixed(2)} USD'),
            _buildInfoRow('Montant Restant', '${avance.montantRestant.toStringAsFixed(2)} USD', valueColor: Colors.red[700]),
            _buildInfoRow('Mode Remboursement', avance.modeRemboursement),
            _buildInfoRow('Durée', '${avance.nombreMoisRemboursement} mois'),
            if (avance.notes != null && avance.notes!.isNotEmpty)
              _buildInfoRow('Notes', avance.notes!),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // ONGLET CRÉDITS
  // ============================================================================

  Widget _buildCreditsTab() {
    if (_credits.isEmpty) {
      return _buildEmptyState('Aucun crédit', Icons.credit_card);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _credits.length,
      itemBuilder: (context, index) {
        final credit = _credits[index];
        return _buildCreditCard(credit);
      },
    );
  }

  Widget _buildCreditCard(CreditPersonnelModel credit) {
    final statusColor = _getCreditStatusColor(credit.statut);
    final progress = credit.montantTotalARembourser > 0 
        ? (credit.montantRembourse / credit.montantTotalARembourser) 
        : 0.0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.credit_card, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(credit.dateOctroi),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Chip(
                  label: Text(credit.statut),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(statusColor),
            ),
            const SizedBox(height: 12),
            _buildInfoRow('Montant Crédit', '${credit.montantCredit.toStringAsFixed(2)} USD'),
            _buildInfoRow('Taux Intérêt', '${credit.tauxInteret}%'),
            _buildInfoRow('Durée', '${credit.dureeMois} mois'),
            _buildInfoRow('Mensualité', '${credit.mensualite.toStringAsFixed(2)} USD'),
            _buildInfoRow('Total à Rembourser', '${credit.montantTotalARembourser.toStringAsFixed(2)} USD'),
            _buildInfoRow('Montant Remboursé', '${credit.montantRembourse.toStringAsFixed(2)} USD'),
            _buildInfoRow('Montant Restant', '${credit.montantRestant.toStringAsFixed(2)} USD', valueColor: Colors.red[700]),
            if (credit.dateEcheance != null)
              _buildInfoRow('Date Échéance', _formatDate(credit.dateEcheance!)),
            if (credit.notes != null && credit.notes!.isNotEmpty)
              _buildInfoRow('Notes', credit.notes!),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // HELPERS
  // ============================================================================

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // ONGLET RETENUES
  // ============================================================================

  Widget _buildRetenuesTab() {
    if (_retenues.isEmpty) {
      return _buildEmptyState('Aucune retenue', Icons.remove_circle);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _retenues.length,
      itemBuilder: (context, index) {
        final retenue = _retenues[index];
        return _buildRetenueCard(retenue);
      },
    );
  }

  Widget _buildRetenueCard(RetenuePersonnelModel retenue) {
    final statusColor = _getRetenueStatusColor(retenue.statut);
    
    // Calculer le nombre de mois écoulés
    final now = DateTime.now();
    final periodeDebut = retenue.anneeDebut * 12 + retenue.moisDebut;
    final periodeActuelle = now.year * 12 + now.month;
    final moisEcoules = (periodeActuelle - periodeDebut + 1).clamp(0, retenue.nombreMois);
    final progression = (moisEcoules / retenue.nombreMois * 100).clamp(0, 100);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.remove_circle, color: statusColor),
                    const SizedBox(width: 8),
                    Text(
                      retenue.type,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                Chip(
                  label: Text(retenue.statut.replaceAll('_', ' ')),
                  backgroundColor: statusColor.withOpacity(0.2),
                  labelStyle: TextStyle(color: statusColor, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              retenue.motif,
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Montant Total', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '${retenue.montantTotal.toStringAsFixed(2)} USD',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Déduit', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '${retenue.montantDejaDeduit.toStringAsFixed(2)} USD',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Restant', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '${retenue.montantRestant.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: retenue.montantRestant > 0 ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Période', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '${_getMonthName(retenue.moisDebut)} ${retenue.anneeDebut}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Durée', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '${retenue.nombreMois} mois',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Progression', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 4),
                      Text(
                        '$moisEcoules / ${retenue.nombreMois} mois',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: progression >= 100 ? Colors.green[700] : Colors.orange[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Barre de progression
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progression / 100,
                minHeight: 8,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  progression >= 100 ? Colors.green : Colors.orange,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${progression.toStringAsFixed(0)}% complété',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
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

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(message, style: TextStyle(fontSize: 18, color: Colors.grey[600])),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
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

  Color _getSalaireStatusColor(String statut) {
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

  Color _getAvanceStatusColor(String statut) {
    switch (statut) {
      case 'En_Cours':
        return Colors.orange;
      case 'Rembourse':
        return Colors.green;
      case 'Annule':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getCreditStatusColor(String statut) {
    switch (statut) {
      case 'En_Cours':
        return Colors.orange;
      case 'En_Retard':
        return Colors.red;
      case 'Rembourse':
        return Colors.green;
      case 'Annule':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // ============================================================================
  // ACTIONS FICHE DE PAIE
  // ============================================================================

  void _viewFichePaie(SalaireModel salaire) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Générer le PDF
      final pdfDocument = await generateFichePaiePdf(
        salaire: salaire,
        personnel: widget.personnel,
      );

      // Fermer l'indicateur de chargement
      if (mounted) Navigator.pop(context);

      // Afficher le visualiseur PDF
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdfDocument,
          title: 'Fiche de Paie - ${widget.personnel.nomComplet}',
          fileName: 'FichePaie_${widget.personnel.nomComplet.replaceAll(' ', '_')}_${salaire.mois}_${salaire.annee}',
        );
      }
    } catch (e) {
      // Fermer l'indicateur si encore ouvert
      if (mounted) Navigator.pop(context);
      
      // Afficher l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la génération du PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _downloadFichePaie(SalaireModel salaire) async {
    try {
      // Afficher un indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Générer le PDF
      final pdfDocument = await generateFichePaiePdf(
        salaire: salaire,
        personnel: widget.personnel,
      );

      // Fermer l'indicateur de chargement
      if (mounted) Navigator.pop(context);

      // Afficher le visualiseur PDF (qui a le bouton télécharger)
      if (mounted) {
        await showPdfViewer(
          context: context,
          pdfDocument: pdfDocument,
          title: 'Fiche de Paie - ${widget.personnel.nomComplet}',
          fileName: 'FichePaie_${widget.personnel.nomComplet.replaceAll(' ', '_')}_${salaire.mois}_${salaire.annee}',
        );
      }
    } catch (e) {
      // Fermer l'indicateur si encore ouvert
      if (mounted) Navigator.pop(context);
      
      // Afficher l'erreur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la génération du PDF: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  /// Imprime l'historique complet des paiements
  Future<void> _imprimerTableauPaieAnnuel() async {
    try {
      // Sélectionner l'année
      final now = DateTime.now();
      int? selectedYear = await showDialog<int>(
        context: context,
        builder: (context) {
          int tempYear = now.year;
          return AlertDialog(
            title: const Text('Sélectionner l\'année'),
            content: StatefulBuilder(
              builder: (context, setState) {
                return DropdownButtonFormField<int>(
                  value: tempYear,
                  decoration: const InputDecoration(
                    labelText: 'Année',
                    border: OutlineInputBorder(),
                  ),
                  items: List.generate(5, (i) => now.year - i).map((y) {
                    return DropdownMenuItem(
                      value: y,
                      child: Text(y.toString()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      tempYear = value!;
                    });
                  },
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, tempYear),
                child: const Text('Générer'),
              ),
            ],
          );
        },
      );

      if (selectedYear == null) return;

      // Afficher indicateur de chargement
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(),
          ),
        );
      }

      // Filtrer les salaires de l'année sélectionnée
      final salairesAnnee = _salaires.where((s) => s.annee == selectedYear).toList()
        ..sort((a, b) => a.mois.compareTo(b.mois));

      if (salairesAnnee.isEmpty) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Aucun salaire trouvé pour l\'année $selectedYear'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Générer le PDF du tableau de paie
      final pdfDocument = await TableauPaieService.generateTableauPaiePdf(
        salaires: salairesAnnee,
        personnel: widget.personnel,
      );

      // Fermer l'indicateur de chargement
      if (mounted) Navigator.pop(context);

      // Afficher le visualiseur PDF
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => PdfViewerDialog(
            pdfDocument: pdfDocument,
            title: 'Tableau de Paie $selectedYear - ${widget.personnel.nomComplet}',
            fileName: 'tableau_paie_${widget.personnel.matricule}_$selectedYear.pdf',
          ),
        );
      }
    } catch (e) {
      // Fermer l'indicateur de chargement si erreur
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération du PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _imprimerHistoriquePaiements() async {
    try {
      // Afficher indicateur de chargement
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Générer le PDF de l'historique
      final pdfDocument = await HistoriquePaiementsPdfService.generateHistoriquePaiementsPdf(
        personnel: widget.personnel,
        salaires: _salaires,
      );

      // Fermer l'indicateur de chargement
      if (mounted) Navigator.pop(context);

      // Afficher le visualiseur PDF
      if (mounted) {
        await showDialog(
          context: context,
          builder: (context) => PdfViewerDialog(
            pdfDocument: pdfDocument,
            title: 'Historique des Paiements - ${widget.personnel.nomComplet}',
            fileName: 'Historique_Paiements_${widget.personnel.nomComplet.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.pdf',
          ),
        );
      }
    } catch (e) {
      // Fermer l'indicateur de chargement en cas d'erreur
      if (mounted) Navigator.pop(context);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur lors de la génération de l\'historique: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
  
  /// Construit une section moderne avec header et icône
  Widget _buildModernSection(String title, IconData icon, List<Widget> children) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec icône
            Row(
              children: [
                Icon(icon, color: Colors.blue[700], size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
  
  /// Construit un item de statistique moderne
  Widget _buildModernStatItem(String label, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 10,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
  
  /// Construit une ligne d'information moderne avec icône
  Widget _buildModernInfoRow(String label, String value, IconData icon, {bool isBold = false, Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            flex: 1,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ?? Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
