import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../services/virtual_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/sim_service.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';
import '../models/virtual_transaction_model.dart';
import '../models/sim_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../models/cloture_virtuelle_model.dart';
import '../models/flot_model.dart' as flot_model;
import 'create_virtual_transaction_dialog.dart';
import 'serve_client_dialog.dart';
import 'create_retrait_virtuel_dialog.dart';
import 'cloture_virtuelle_moderne_widget.dart';
import 'modern_transaction_card.dart';
import 'pdf_viewer_dialog.dart';


/// Widget pour la gestion des transactions virtuelles par les agents
class VirtualTransactionsWidget extends StatefulWidget {
  const VirtualTransactionsWidget({super.key});

  @override
  State<VirtualTransactionsWidget> createState() => _VirtualTransactionsWidgetState();
}

class _VirtualTransactionsWidgetState extends State<VirtualTransactionsWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _selectedSimFilter;
  int? _selectedShopFilter; // NOUVEAU: Pour les admins
  DateTime? _dateDebutFilter;
  DateTime? _dateFinFilter;
  Key _retraitsTabKey = UniqueKey(); // Pour forcer le rechargement
  bool _showFilters = false; // Masquer les filtres par défaut
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser?.shopId != null) {
      await VirtualTransactionService.instance.loadTransactions(shopId: currentUser!.shopId);
      await SimService.instance.loadSims(shopId: currentUser.shopId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.account_balance_wallet, size: 24),
            ),
          ],
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF48bb78), Color(0xFF38a169)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.white.withOpacity(0.1),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              isScrollable: isMobile,
              labelStyle: TextStyle(
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w600,
              ),
              tabs: [
                Tab(
                  icon: Icon(Icons.swap_horiz, size: isMobile ? 18 : 22),
                  text: 'Trans.',
                ),
                Tab(
                  icon: Icon(Icons.send, size: isMobile ? 18 : 22),
                  text: 'Flot',
                ),
                Tab(
                  icon: Icon(Icons.receipt_long, size: isMobile ? 18 : 22),
                  text: 'Clôture',
                ),
                Tab(
                  icon: Icon(Icons.analytics, size: isMobile ? 18 : 22),
                  text: 'Rapport',
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTransactionsTab(),
          _buildFlotTab(),
          _buildClotureTab(),
          _buildRapportTab(),
        ],
      ),
      floatingActionButton: _tabController.index == 0
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isMobile) ...[
                  FloatingActionButton(
                    heroTag: 'btn_search',
                    onPressed: _searchByReference,
                    backgroundColor: Colors.blue,
                    elevation: 4,
                    child: const Icon(Icons.search),
                  ),
                  const SizedBox(height: 12),
                ],
                FloatingActionButton.extended(
                  heroTag: 'btn_create',
                  onPressed: _createTransaction,
                  icon: const Icon(Icons.add_circle_outline),
                  label: Text(isMobile ? 'Capture' : 'Nouvelle Capture'),
                  backgroundColor: const Color(0xFF48bb78),
                  elevation: 4,
                ),
              ],
            )
          : null,
    );
  }

  /// Onglet Transactions (avec sous-onglets: Tout, En Attente, Servies, Retrait)
  Widget _buildTransactionsTab() {
    return DefaultTabController(
      length: 4,
      child: Column(
        children: [
          Container(
            color: Colors.grey[200],
            child: const TabBar(
              labelColor: Color(0xFF48bb78),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF48bb78),
              isScrollable: true,
              tabs: [
                Tab(text: 'Tout', icon: Icon(Icons.list, size: 18)),
                Tab(text: 'En Attente', icon: Icon(Icons.hourglass_empty, size: 18)),
                Tab(text: 'Servies', icon: Icon(Icons.check_circle, size: 18)),
                Tab(text: 'Retrait', icon: Icon(Icons.remove_circle, size: 18)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildHistoriqueTab(), // Tout
                _buildEnAttenteTab(),  // En Attente
                _buildServiesTab(),    // Servies
                _buildRetraitsTab(),   // Retrait
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet des transactions en attente
  Widget _buildEnAttenteTab() {
    return Consumer<VirtualTransactionService>(
      builder: (BuildContext context, service, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        final transactions = service.transactions
            .where((t) => t.statut == VirtualTransactionStatus.enAttente && t.shopId == currentShopId)
            .toList();

        // Appliquer les filtres
        var filteredTransactions = transactions;
        if (_selectedSimFilter != null) {
          filteredTransactions = filteredTransactions.where((t) => t.simNumero == _selectedSimFilter).toList();
        }
        if (_dateDebutFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.dateEnregistrement.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.dateEnregistrement.isBefore(_dateFinFilter!))
              .toList();
        }

        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (filteredTransactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucune transaction en attente',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les nouvelles captures apparaîtront ici',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            _buildFilters(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: filteredTransactions.length,
                  itemBuilder: (context, index) {
                    return ModernTransactionCard(
                      transaction: filteredTransactions[index],
                      isEnAttente: true,
                      onTap: () => _showTransactionDetails(filteredTransactions[index]),
                      onServe: () => _serveClient(filteredTransactions[index]),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// Onglet des transactions servies
  Widget _buildServiesTab() {
    return Consumer<VirtualTransactionService>(
      builder: (BuildContext context, service, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        var transactions = service.transactions
            .where((t) => t.statut == VirtualTransactionStatus.validee && t.shopId == currentShopId)
            .toList();

        // Appliquer les filtres
        if (_selectedSimFilter != null) {
          transactions = transactions.where((t) => t.simNumero == _selectedSimFilter).toList();
        }
        if (_dateDebutFilter != null) {
          transactions = transactions
              .where((t) => t.dateValidation != null && t.dateValidation!.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          transactions = transactions
              .where((t) => t.dateValidation != null && t.dateValidation!.isBefore(_dateFinFilter!))
              .toList();
        }

        if (transactions.isEmpty) {
          return const Center(child: Text('Aucune transaction servie'));
        }

        return Column(
          children: [
            _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  return ModernTransactionCard(
                    transaction: transactions[index],
                    isEnAttente: false,
                    onTap: () => _showTransactionDetails(transactions[index]),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Onglet Retraits Virtuels
  Widget _buildRetraitsTab() {
    return FutureBuilder<List<RetraitVirtuelModel>>(
      key: _retraitsTabKey, // Utiliser la clé pour forcer le rechargement
      future: LocalDB.instance.getAllRetraitsVirtuels(
        shopSourceId: Provider.of<AuthService>(context, listen: false).currentUser?.shopId,
      ),
      builder: (BuildContext context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final retraits = snapshot.data ?? [];

        if (retraits.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.remove_circle_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun retrait virtuel',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: retraits.length,
          itemBuilder: (context, index) {
            return _buildRetraitCard(retraits[index]);
          },
        );
      },
    );
  }

  /// Onglet historique (toutes les transactions)
  Widget _buildHistoriqueTab() {
    return Consumer<VirtualTransactionService>(
      builder: (BuildContext context, service, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        var transactions = service.transactions
            .where((t) => t.shopId == currentShopId)
            .toList();

        // Appliquer les filtres
        if (_selectedSimFilter != null) {
          transactions = transactions.where((t) => t.simNumero == _selectedSimFilter).toList();
        }
        if (_dateDebutFilter != null) {
          transactions = transactions
              .where((t) => t.dateEnregistrement.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          transactions = transactions
              .where((t) => t.dateEnregistrement.isBefore(_dateFinFilter!))
              .toList();
        }

        return Column(
          children: [
            _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  return ModernTransactionCard(
                    transaction: transactions[index],
                    isEnAttente: transactions[index].statut == VirtualTransactionStatus.enAttente,
                    onTap: () => _showTransactionDetails(transactions[index]),
                    onServe: transactions[index].statut == VirtualTransactionStatus.enAttente
                        ? () => _serveClient(transactions[index])
                        : null,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Filtres de dates (pour les rapports)
  Widget _buildDateFilters() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isAdmin = currentUser?.isAdmin ?? false;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.filter_list, size: 20, color: Color(0xFF48bb78)),
              const SizedBox(width: 8),
              Text(
                isAdmin ? 'Filtres (Admin)' : 'Filtrer par période',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              // Bouton pour afficher/masquer les filtres
              IconButton(
                icon: Icon(_showFilters ? Icons.expand_less : Icons.expand_more),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                tooltip: _showFilters ? 'Masquer les filtres' : 'Afficher les filtres',
              ),
              if (_dateDebutFilter != null || _dateFinFilter != null || _selectedShopFilter != null || _selectedSimFilter != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Effacer', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _dateDebutFilter = null;
                      _dateFinFilter = null;
                      _selectedShopFilter = null;
                      _selectedSimFilter = null;
                    });
                  },
                ),
            ],
          ),
          
          // Afficher les filtres uniquement si _showFilters est true
          if (_showFilters) ...[
            const SizedBox(height: 8),
            
            // FILTRE PAR SHOP (Admin uniquement)
            if (isAdmin) ...[
            Consumer<ShopService>(
              builder: (BuildContext context, shopService, child) {
                return DropdownButtonFormField<int>(
                  value: _selectedShopFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filtrer par Shop',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.store),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Tous les shops')),
                    ...shopService.shops.map((shop) => DropdownMenuItem(
                      value: shop.id,
                      child: Text(shop.designation),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedShopFilter = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          
          // FILTRE PAR SIM (Admin uniquement)
          if (isAdmin) ...[
            Consumer<SimService>(
              builder: (BuildContext context, simService, child) {
                // Filtrer les SIMs selon le shop sélectionné
                var sims = simService.sims.where((s) => s.statut == SimStatus.active).toList();
                if (_selectedShopFilter != null) {
                  sims = sims.where((s) => s.shopId == _selectedShopFilter).toList();
                }

                return DropdownButtonFormField<String>(
                  value: _selectedSimFilter,
                  decoration: const InputDecoration(
                    labelText: 'Filtrer par SIM',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.sim_card),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Toutes les SIMs')),
                    ...sims.map((sim) => DropdownMenuItem(
                      value: sim.numero,
                      child: Text('${sim.numero} (${sim.operateur}${_selectedShopFilter == null ? " - Shop ${sim.shopId}" : ""})'),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedSimFilter = value;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: 8),
          ],
          
          // FILTRES DE DATES (tous les utilisateurs)

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _dateDebutFilter != null
                        ? DateFormat('dd/MM/yyyy').format(_dateDebutFilter!)
                        : 'Date début',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _dateDebutFilter != null ? const Color(0xFF48bb78).withOpacity(0.1) : null,
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateDebutFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dateDebutFilter = DateTime(date.year, date.month, date.day));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(
                    _dateFinFilter != null
                        ? DateFormat('dd/MM/yyyy').format(_dateFinFilter!)
                        : 'Date fin',
                    style: const TextStyle(fontSize: 13),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _dateFinFilter != null ? const Color(0xFF48bb78).withOpacity(0.1) : null,
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateFinFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dateFinFilter = DateTime(date.year, date.month, date.day, 23, 59, 59));
                    }
                  },
                ),
              ),
            ],
          ),
          ], // Fermeture du if (_showFilters)
        ],
      ),
    );
  }

  /// Onglet Flot - Transferts et floats reçus avec solde par shop
  Widget _buildFlotTab() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final isAdmin = authService.currentUser?.role == 'ADMIN';
    
    return FutureBuilder<List<RetraitVirtuelModel>>(
      // IMPORTANT: Charger TOUS les retraits (pas de filtre ici)
      // On a besoin de voir les retraits où on est source ET débiteur
      future: LocalDB.instance.getAllRetraitsVirtuels(),
      builder: (builderContext, retraitsSnapshot) {
        if (retraitsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final retraits = retraitsSnapshot.data ?? [];
        
        return FutureBuilder<List<flot_model.FlotModel>>(
          future: LocalDB.instance.getAllFlots(),
          builder: (builderContext2, flotsSnapshot) {
            final allFlots = flotsSnapshot.data ?? [];
            
            // Filtrer les FLOTs pertinents pour ce shop
            final flots = shopId != null
                ? allFlots.where((f) => 
                    f.shopSourceId == shopId || f.shopDestinationId == shopId
                  ).toList()
                : allFlots;
            
            return _buildFlotContent(retraits, flots, shopId, isAdmin);
          },
        );
      },
    );
  }
  
  Widget _buildFlotContent(
    List<RetraitVirtuelModel> retraits,
    List<flot_model.FlotModel> flots,
    int? shopId,
    bool isAdmin,
  ) {
    // Récupérer le ShopService pour résoudre les désignations
    final shopService = Provider.of<ShopService>(context, listen: false);
    
    // Fonction helper pour résoudre la désignation d'un shop
    String getShopDesignation(int shopId, String? designation) {
      if (designation != null && designation.isNotEmpty) {
        return designation;
      }
      
      // Chercher dans ShopService
      try {
        final shop = shopService.shops.firstWhere((s) => s.id == shopId);
        return shop.designation;
      } catch (e) {
        return 'Shop #$shopId';
      }
    }
    
    // FILTRER les retraits pour ne garder que ceux qui concernent notre shop
    // (soit comme source, soit comme débiteur)
    var retraitsFiltresParShop = retraits;
    if (shopId != null && !isAdmin) {
      retraitsFiltresParShop = retraits.where((r) => 
        r.shopSourceId == shopId || r.shopDebiteurId == shopId
      ).toList();
    } else if (isAdmin && _selectedShopFilter != null) {
      retraitsFiltresParShop = retraits.where((r) => 
        r.shopSourceId == _selectedShopFilter || r.shopDebiteurId == _selectedShopFilter
      ).toList();
    }
    
    
    // IMPORTANT: Pour les SOLDES, on utilise TOUTES les données (sans filtre de date)
    // Les filtres de dates s'appliquent UNIQUEMENT aux listes d'historique
    
    // Calculer les soldes par shop (SANS filtres de dates)
    final Map<int, Map<String, dynamic>> soldesParShop = {};
    
    // 1. RETRAITS VIRTUELS - Traiter selon la perspective de notre shop
    for (final retrait in retraitsFiltresParShop) {
      // Déterminer l'autre shop (celui avec qui on traite)
      int autreShopId;
      String autreShopName;
      double montantSigne; // Positif = ils nous doivent, Négatif = on leur doit
      
      if (shopId != null) {
        if (retrait.shopSourceId == shopId) {
          // On est le shop SOURCE (créancier) : l'autre nous DOIT
          autreShopId = retrait.shopDebiteurId;
          autreShopName = getShopDesignation(autreShopId, retrait.shopDebiteurDesignation);
          montantSigne = retrait.montant; // POSITIF
        } else {
          // On est le shop DÉBITEUR : on DOIT à l'autre
          autreShopId = retrait.shopSourceId;
          autreShopName = getShopDesignation(autreShopId, retrait.shopSourceDesignation);
          montantSigne = -retrait.montant; // NÉGATIF
        }
      } else {
        // Admin sans shop spécifique
        autreShopId = retrait.shopDebiteurId;
        autreShopName = getShopDesignation(autreShopId, retrait.shopDebiteurDesignation);
        montantSigne = retrait.montant;
      }
      
      if (!soldesParShop.containsKey(autreShopId)) {
        soldesParShop[autreShopId] = {
          'shopId': autreShopId,
          'shopName': autreShopName,
          'totalRetraits': 0.0,
          'totalFlotRecu': 0.0,
          'totalFlotsPhysiques': 0.0,
          'flotsEnvoyes': 0.0,
          'solde': 0.0,
          'retraitsEnAttente': 0,
          'retraitsRembourses': 0,
          'flotsRecus': 0,
          'flotsEnvoyesCount': 0,
        };
      }
      
      soldesParShop[autreShopId]!['totalRetraits'] += montantSigne;
      
      if (retrait.statut == RetraitVirtuelStatus.rembourse) {
        soldesParShop[autreShopId]!['totalFlotRecu'] += retrait.montant;
        soldesParShop[autreShopId]!['retraitsRembourses'] += 1;
      } else if (retrait.statut == RetraitVirtuelStatus.enAttente) {
        soldesParShop[autreShopId]!['retraitsEnAttente'] += 1;
      }
    }
    
    // 2. FLOTS PHYSIQUES (cash envoyé ou reçu) - SANS filtres pour le calcul des soldes
    if (shopId != null) {
      for (final flot in flots) {
        // CAS 1: On a REÇU un FLOT (on est destination) → L'autre shop nous a payé
        if (flot.shopDestinationId == shopId && flot.statut == flot_model.StatutFlot.servi) {
          final autreShopId = flot.shopSourceId;
          
          if (!soldesParShop.containsKey(autreShopId)) {
            soldesParShop[autreShopId] = {
              'shopId': autreShopId,
              'shopName': getShopDesignation(autreShopId, flot.shopSourceDesignation),
              'totalRetraits': 0.0,
              'totalFlotRecu': 0.0,
              'totalFlotsPhysiques': 0.0,  // FLOT reçu (réduit la dette)
              'flotsEnvoyes': 0.0,  // NOUVEAU: FLOT envoyé (augmente ce qu'ils doivent)
              'solde': 0.0,
              'retraitsEnAttente': 0,
              'retraitsRembourses': 0,
              'flotsRecus': 0,
              'flotsEnvoyesCount': 0,
            };
          }
          
          // On a REÇU du cash → réduit ce qu'ils nous doivent
          soldesParShop[autreShopId]!['totalFlotsPhysiques'] += flot.montant;
          soldesParShop[autreShopId]!['flotsRecus'] += 1;
        }
        
        // CAS 2: On a ENVOYÉ un FLOT (on est source) → On leur a donné du cash
        if (flot.shopSourceId == shopId && flot.statut == flot_model.StatutFlot.servi) {
          final autreShopId = flot.shopDestinationId;
          
          if (!soldesParShop.containsKey(autreShopId)) {
            soldesParShop[autreShopId] = {
              'shopId': autreShopId,
              'shopName': getShopDesignation(autreShopId, flot.shopDestinationDesignation),
              'totalRetraits': 0.0,
              'totalFlotRecu': 0.0,
              'totalFlotsPhysiques': 0.0,
              'flotsEnvoyes': 0.0,
              'solde': 0.0,
              'retraitsEnAttente': 0,
              'retraitsRembourses': 0,
              'flotsRecus': 0,
              'flotsEnvoyesCount': 0,
            };
          }
          
          // On leur a ENVOYÉ du cash → augmente ce qu'ils nous doivent
          soldesParShop[autreShopId]!['flotsEnvoyes'] += flot.montant;
          soldesParShop[autreShopId]!['flotsEnvoyesCount'] += 1;
        }
      }
    }
    
    // 3. Calculer le solde FINAL
    // Formule CORRECTE: Solde = Retraits + FLOTs envoyés - FLOTs reçus
    // NOTE: totalFlotRecu (remboursements virtuels) n'est PAS utilisé dans le calcul du solde
    // car quand un retrait est remboursé, ça signifie juste qu'il est validé, pas qu'on a reçu du cash
    // Le cash reçu est comptabilisé dans totalFlotsPhysiques
    for (final shopData in soldesParShop.values) {
      final flotsEnvoyes = shopData['flotsEnvoyes'] ?? 0.0;
      shopData['solde'] = shopData['totalRetraits'] + 
                          flotsEnvoyes - 
                          shopData['totalFlotsPhysiques'];
    }
    
    final soldesParShopList = soldesParShop.values.toList();
    soldesParShopList.sort((a, b) => (b['solde'] as double).compareTo(a['solde'] as double));
    
    // MAINTENANT appliquer les filtres UNIQUEMENT pour les listes d'historique
    var retraitsFiltres = retraitsFiltresParShop;
    if (_dateDebutFilter != null) {
      retraitsFiltres = retraitsFiltres.where((r) => 
        r.dateRetrait.isAfter(_dateDebutFilter!)
      ).toList();
    }
    if (_dateFinFilter != null) {
      retraitsFiltres = retraitsFiltres.where((r) => 
        r.dateRetrait.isBefore(_dateFinFilter!)
      ).toList();
    }
    if (_selectedSimFilter != null) {
      retraitsFiltres = retraitsFiltres.where((r) => 
        r.simNumero == _selectedSimFilter
      ).toList();
    }
    
    var flotsFiltres = flots;
    if (_dateDebutFilter != null) {
      flotsFiltres = flotsFiltres.where((f) => 
        f.dateEnvoi.isAfter(_dateDebutFilter!)
      ).toList();
    }
    if (_dateFinFilter != null) {
      flotsFiltres = flotsFiltres.where((f) => 
        f.dateEnvoi.isBefore(_dateFinFilter!)
      ).toList();
    }
    if (isAdmin && _selectedShopFilter != null) {
      flotsFiltres = flotsFiltres.where((f) => 
        f.shopSourceId == _selectedShopFilter || f.shopDestinationId == _selectedShopFilter
      ).toList();
    }
    
    return SingleChildScrollView(
      child: Column(
        children: [
          // NOUVEAU: Filtres de dates
          Padding(
            padding: const EdgeInsets.all(16),
            child: _buildDateFilters(),
          ),
          
          // Header avec bouton créer retrait
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF48bb78), Color(0xFF38a169)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF48bb78).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.send, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Retraits Virtuels & Flots',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Solde = Retraits + FLOTs envoyés - FLOTs reçus',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isAdmin) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _createRetraitVirtuel,
                          icon: const Icon(Icons.remove_circle, size: 20),
                          label: const Text(
                            'Créer un Retrait Virtuel',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF48bb78),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              
              // Soldes par shop
              if (soldesParShopList.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.account_balance, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _dateDebutFilter != null || _dateFinFilter != null || _selectedSimFilter != null || _selectedShopFilter != null
                          ? 'Aucun résultat pour les filtres sélectionnés'
                          : 'Aucun retrait virtuel enregistré',
                        style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '💰 Soldes par Shop',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...soldesParShopList.map((shopData) => _buildShopBalanceCard(shopData)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Liste des retraits
              if (retraitsFiltres.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📋 Historique des Retraits Virtuels',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...retraitsFiltres.map((retrait) => _buildRetraitCard(retrait)),
                    ],
                  ),
                ),
              
              // NOUVEAU: Liste des FLOTs physiques
              if (flotsFiltres.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const Text(
                        '💵 Historique des FLOTs Physiques (Cash)',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...flotsFiltres.map((flot) => _buildFlotCard(flot, shopId)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 80),
            ],
          ),
        );
  }
  
  Widget _buildShopBalanceCard(Map<String, dynamic> shopData) {
    final solde = shopData['solde'] as double;
    final totalRetraits = shopData['totalRetraits'] as double;
    final totalFlotRecu = shopData['totalFlotRecu'] as double;
    final totalFlotsPhysiques = shopData['totalFlotsPhysiques'] as double;
    final flotsEnvoyes = shopData['flotsEnvoyes'] ?? 0.0;  // NOUVEAU
    final retraitsEnAttente = shopData['retraitsEnAttente'] as int;
    final retraitsRembourses = shopData['retraitsRembourses'] as int;
    final flotsRecus = shopData['flotsRecus'] as int;
    final flotsEnvoyesCount = shopData['flotsEnvoyesCount'] ?? 0;  // NOUVEAU
    final shopName = shopData['shopName'] as String;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: solde > 0 ? Colors.orange.withOpacity(0.3) : Colors.green.withOpacity(0.3),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: solde > 0 ? Colors.orange.withOpacity(0.1) : Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  solde > 0 ? Icons.arrow_upward : Icons.check_circle,
                  color: solde > 0 ? Colors.orange : Colors.green,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shopName,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${retraitsEnAttente + retraitsRembourses} retrait(s) | ${flotsRecus + flotsEnvoyesCount} FLOT(s)',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    solde > 0 ? 'Ils doivent' : solde < 0 ? 'Vous devez' : 'Équilibré',
                    style: TextStyle(
                      fontSize: 11,
                      color: solde > 0 ? Colors.orange : solde < 0 ? Colors.red : Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '\$${solde.abs().toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: solde > 0 ? Colors.orange : Colors.green,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildShopStat('Retraits', totalRetraits, Colors.orange),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildShopStat('FLOT Reçu', totalFlotsPhysiques, Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildShopStat('FLOT Envoyé', flotsEnvoyes, Colors.red),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Balance',
                        style: TextStyle(fontSize: 11, color: Colors.grey[700], fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${flotsRecus}↓ / ${flotsEnvoyesCount}↑',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.hourglass_empty, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '$retraitsEnAttente en attente',
                        style: const TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.check_circle, size: 14, color: Colors.green),
                      const SizedBox(width: 4),
                      Text(
                        '$retraitsRembourses remboursés',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildShopStat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            '\$${value.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRetraitCard(RetraitVirtuelModel retrait) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    final isRembourse = retrait.statut == RetraitVirtuelStatus.rembourse;
    final isEnAttente = retrait.statut == RetraitVirtuelStatus.enAttente;
    
    // Le shop DÉBITEUR peut valider (celui qui DOIT l'argent)
    final canValidate = isEnAttente && currentShopId == retrait.shopDebiteurId;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isRembourse ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isRembourse ? Icons.check_circle : Icons.hourglass_empty,
                  size: 16,
                  color: isRembourse ? Colors.green : Colors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      retrait.shopDebiteurDesignation ?? 'Shop ${retrait.shopDebiteurId}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'SIM: ${retrait.simNumero}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${retrait.montant.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isRembourse ? Colors.green : Colors.orange,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isRembourse ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      isRembourse ? 'Remboursé' : 'En Attente',
                      style: TextStyle(
                        fontSize: 9,
                        color: isRembourse ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                DateFormat('dd/MM/yyyy HH:mm').format(retrait.dateRetrait),
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (isRembourse && retrait.dateRemboursement != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.check, size: 12, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  'Remb: ${DateFormat('dd/MM/yyyy').format(retrait.dateRemboursement!)}',
                  style: TextStyle(fontSize: 11, color: Colors.green[700]),
                ),
              ],
            ],
          ),
          if (retrait.notes != null && retrait.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              retrait.notes!,
              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
            ),
          ],
          
          // BOUTON DE VALIDATION : Visible UNIQUEMENT pour le shop DÉBITEUR
          if (canValidate) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _marquerRetraitRembourse(retrait),
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text(
                  'Valider le Remboursement (J\'ai payé)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
  
  /// Carte pour afficher un FLOT physique
  Widget _buildFlotCard(flot_model.FlotModel flot, int? currentShopId) {
    // Récupérer le ShopService pour résoudre les désignations
    final shopService = Provider.of<ShopService>(context, listen: false);
    
    // Fonction helper pour résoudre la désignation d'un shop
    String getShopDesignation(int shopId, String? designation) {
      if (designation != null && designation.isNotEmpty) {
        return designation;
      }
      
      // Chercher dans ShopService
      try {
        final shop = shopService.shops.firstWhere((s) => s.id == shopId);
        return shop.designation;
      } catch (e) {
        return 'Shop #$shopId';
      }
    }
    
    // Déterminer si on est l'expéditeur ou le destinataire
    final bool isSource = flot.shopSourceId == currentShopId;
    final bool isDestination = flot.shopDestinationId == currentShopId;
    final bool isServi = flot.statut == flot_model.StatutFlot.servi;
    final bool isEnRoute = flot.statut == flot_model.StatutFlot.enRoute;
    
    // Déterminer la couleur selon le statut
    final Color statusColor = isServi ? Colors.green : 
                             isEnRoute ? Colors.orange : Colors.grey;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSource ? Colors.red.withOpacity(0.3) : Colors.green.withOpacity(0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  isSource ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: isSource ? Colors.red : Colors.green,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isSource 
                        ? 'FLOT ENVOYÉ à ${getShopDesignation(flot.shopDestinationId, flot.shopDestinationDesignation)}'
                        : 'FLOT REÇU de ${getShopDesignation(flot.shopSourceId, flot.shopSourceDesignation)}',
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.bold,
                        color: isSource ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      'Ref: ${flot.reference}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${flot.montant.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      flot.statutLabel,
                      style: TextStyle(
                        fontSize: 9,
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.calendar_today, size: 12, color: Colors.grey[500]),
              const SizedBox(width: 4),
              Text(
                'Envoyé: ${DateFormat('dd/MM/yyyy HH:mm').format(flot.dateEnvoi)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (isServi && flot.dateReception != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.check, size: 12, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  'Reçu: ${DateFormat('dd/MM/yyyy HH:mm').format(flot.dateReception!)}',
                  style: TextStyle(fontSize: 11, color: Colors.green[700]),
                ),
              ],
            ],
          ),
          if (flot.notes != null && flot.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              flot.notes!,
              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }

  /// Onglet Clôture Journalière
  Widget _buildClotureTab() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final isAdmin = authService.currentUser?.role == 'ADMIN';
    
    if (shopId == null && !isAdmin) {
      return const Center(
        child: Text('Shop ID non disponible', style: TextStyle(color: Colors.red)),
      );
    }
    
    return ClotureVirtuelleModerneWidget(
      shopId: shopId,
      isAdminView: isAdmin,
    );
  }

  /// Onglet rapport avec sous-onglets (par SIM et Frais)
  Widget _buildRapportTab() {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Container(
            color: Colors.grey[200],
            child: const TabBar(
              labelColor: Color(0xFF48bb78),
              unselectedLabelColor: Colors.grey,
              indicatorColor: Color(0xFF48bb78),
              isScrollable: true,
              tabs: [
                Tab(text: 'Vue d\'ensemble', icon: Icon(Icons.dashboard, size: 20)),
                Tab(text: 'Par SIM', icon: Icon(Icons.sim_card, size: 20)),
                Tab(text: 'Frais', icon: Icon(Icons.attach_money, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRapportVueEnsembleTab(),
                _buildRapportParSimTab(),
                _buildRapportFraisTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Récupérer la dernière clôture pour un shop
  Future<ClotureVirtuelleModel?> _getLastCloture(int? shopId) async {
    if (shopId == null) return null;
    
    try {
      final clotures = await LocalDB.instance.getAllCloturesVirtuelles(shopId: shopId);
      if (clotures.isEmpty) return null;
      
      // Trier par date décroissante et prendre la première
      clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));
      return clotures.first;
    } catch (e) {
      debugPrint('Erreur récupération dernière clôture: $e');
      return null;
    }
  }

  /// Récupérer le solde antérieur CASH de la dernière clôture caisse
  /// Utilise la MÊME logique que rapport_cloture_service.dart
  Future<double> _getSoldeAnterieurCash(int? shopId) async {
    if (shopId == null) return 0.0;
    
    try {
      // Obtenir la date d'aujourd'hui
      final aujourdhui = DateTime.now();
      // Jour précédent
      final jourPrecedent = aujourdhui.subtract(const Duration(days: 1));
      
      // Récupérer la clôture caisse du jour précédent
      final cloturePrecedente = await LocalDB.instance.getClotureCaisseByDate(shopId, jourPrecedent);
      
      if (cloturePrecedente != null) {
        // MÊME LOGIQUE QUE rapport_cloture_service.dart:
        // Utiliser le montant SAISI TOTAL comme solde antérieur
        debugPrint('📋 Solde antérieur CASH trouvé (clôture du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   TOTAL SAISI: ${cloturePrecedente.soldeSaisiTotal} USD');
        return cloturePrecedente.soldeSaisiTotal;
      }
      
      // Si aucune clôture précédente, retourner 0
      debugPrint('ℹ️ Aucun solde antérieur CASH (pas de clôture caisse du jour précédent)');
      return 0.0;
    } catch (e) {
      debugPrint('❌ Erreur récupération solde antérieur CASH: $e');
      return 0.0;
    }
  }

  /// Récupérer le solde antérieur VIRTUEL de la dernière clôture virtuelle
  /// Formule: Virtuel Disponible = Solde Antérieur (Virtuel) + Captures du Jour (Frais inclus) - Retraits du Jour
  Future<double> _getSoldeAnterieurVirtuel(int? shopId) async {
    if (shopId == null) return 0.0;
    
    try {
      final clotures = await LocalDB.instance.getAllCloturesVirtuelles(shopId: shopId);
      if (clotures.isEmpty) {
        debugPrint('ℹ️ Aucun solde antérieur VIRTUEL (pas de clôture virtuelle précédente)');
        return 0.0;
      }
      
      // Trier par date décroissante et prendre la première
      clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));
      final derniereCloture = clotures.first;
      
      // Utiliser le solde total des SIMs de la dernière clôture
      debugPrint('📋 Solde antérieur VIRTUEL trouvé (clôture du ${derniereCloture.dateCloture.toIso8601String().split('T')[0]}):');
      debugPrint('   SOLDE TOTAL SIMs: ${derniereCloture.soldeTotalSims} USD');
      return derniereCloture.soldeTotalSims;
    } catch (e) {
      debugPrint('❌ Erreur récupération solde antérieur VIRTUEL: $e');
      return 0.0;
    }
  }

  /// Vue d'ensemble avec statistiques globales et graphiques
  Widget _buildRapportVueEnsembleTab() {
    return Consumer2<VirtualTransactionService, SimService>(
      builder: (BuildContext context, vtService, simService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        final isAdmin = currentUser?.isAdmin ?? false;
        final currentShopId = currentUser?.shopId;
        
        if (!isAdmin && currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        // Filtrer par shop selon le rôle
        final shopIdFilter = isAdmin ? _selectedShopFilter : currentShopId;
        
        // Filtrer les SIMs
        var sims = simService.sims.where((s) => s.statut == SimStatus.active).toList();
        if (shopIdFilter != null) {
          sims = sims.where((s) => s.shopId == shopIdFilter).toList();
        }

        // Filtrer les transactions
        final transactions = shopIdFilter != null
            ? vtService.transactions.where((t) => t.shopId == shopIdFilter).toList()
            : vtService.transactions;

        // Appliquer les filtres de dates
        var filteredTransactions = transactions;
        if (_dateDebutFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.dateEnregistrement.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.dateEnregistrement.isBefore(_dateFinFilter!))
              .toList();
        }
        // Filtrer par SIM (si sélectionnée)
        if (_selectedSimFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.simNumero == _selectedSimFilter)
              .toList();
        }

        // Calculer les statistiques globales
        final captures = filteredTransactions;
        final validees = filteredTransactions.where((t) => t.statut == VirtualTransactionStatus.validee).toList();
        final enAttente = filteredTransactions.where((t) => t.statut == VirtualTransactionStatus.enAttente).toList();
        final annulees = filteredTransactions.where((t) => t.statut == VirtualTransactionStatus.annulee).toList();

        final montantTotalCaptures = captures.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final montantVirtuelServies = validees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final fraisPercus = validees.fold<double>(0, (sum, t) => sum + t.frais);
        // NOUVEAU: Total des frais de TOUTES les captures (pas seulement servies)
        final fraisToutesCaptures = captures.fold<double>(0, (sum, t) => sum + t.frais);
        final cashServi = validees.fold<double>(0, (sum, t) => sum + t.montantCash);
        final montantEnAttente = enAttente.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final montantAnnulees = annulees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);

        // Soldes SIMs
        final soldeTotalSims = sims.fold<double>(0, (sum, s) => sum + s.soldeActuel);

        // Statistiques par opérateur
        final Map<String, Map<String, dynamic>> statsParOperateur = {};
        for (var sim in sims) {
          final operateur = sim.operateur;
          if (!statsParOperateur.containsKey(operateur)) {
            statsParOperateur[operateur] = {
              'nombre_sims': 0,
              'solde_total': 0.0,
              'transactions': 0,
              'frais': 0.0,
            };
          }
          statsParOperateur[operateur]!['nombre_sims'] += 1;
          statsParOperateur[operateur]!['solde_total'] += sim.soldeActuel;

          final simTransactions = filteredTransactions.where((t) => t.simNumero == sim.numero).toList();
          final simValidees = simTransactions.where((t) => t.statut == VirtualTransactionStatus.validee).toList();
          statsParOperateur[operateur]!['transactions'] += simTransactions.length;
          statsParOperateur[operateur]!['frais'] += simValidees.fold<double>(0, (sum, t) => sum + t.frais);
        }

        // NOUVEAU: Charger les retraits virtuels via FutureBuilder
        return FutureBuilder<List<RetraitVirtuelModel>>(
          future: LocalDB.instance.getAllRetraitsVirtuels(shopSourceId: shopIdFilter),
          builder: (BuildContext context, retraitsSnapshot) {
            // Statistiques des retraits
            var retraits = retraitsSnapshot.data ?? [];
            
            // Filtrer par dates
            if (_dateDebutFilter != null) {
              retraits = retraits.where((r) => r.dateRetrait.isAfter(_dateDebutFilter!)).toList();
            }
            if (_dateFinFilter != null) {
              retraits = retraits.where((r) => r.dateRetrait.isBefore(_dateFinFilter!)).toList();
            }
            // Filtrer par SIM
            if (_selectedSimFilter != null) {
              retraits = retraits.where((r) => r.simNumero == _selectedSimFilter).toList();
            }
            
            final retraitsEnAttente = retraits.where((r) => r.statut == RetraitVirtuelStatus.enAttente).toList();
            final retraitsRembourses = retraits.where((r) => r.statut == RetraitVirtuelStatus.rembourse).toList();
            
            final montantTotalRetraits = retraits.fold<double>(0, (sum, r) => sum + r.montant);
            final montantRetraitsEnAttente = retraitsEnAttente.fold<double>(0, (sum, r) => sum + r.montant);
            final montantRetraitsRembourses = retraitsRembourses.fold<double>(0, (sum, r) => sum + r.montant);
            
            // NOUVEAU: Calculer le Cash Disponible selon la formule de clôture
            // Cash Disponible = Solde Antérieur (Dernière clôture CAISSE) + FLOTs reçus - Cash Servi (après capture)
            // MÊME LOGIQUE QUE cloture_agent_widget.dart et rapport_cloture_service.dart
            return FutureBuilder<List<flot_model.FlotModel>>(
              future: LocalDB.instance.getAllFlots(),
              builder: (BuildContext context, flotsSnapshot) {
                // Calculer les FLOTs reçus ET envoyés
                var allFlots = flotsSnapshot.data ?? [];
                
                // Filtrer les FLOTs REÇUS (où on est destination et statut = servi)
                var flotsRecus = allFlots.where((f) => 
                  f.shopDestinationId == shopIdFilter &&
                  f.statut == flot_model.StatutFlot.servi
                ).toList();
                
                // Filtrer les FLOTs ENVOYÉS (où on est source et statut = servi)
                var flotsEnvoyes = allFlots.where((f) => 
                  f.shopSourceId == shopIdFilter &&
                  f.statut == flot_model.StatutFlot.servi
                ).toList();
                
                // Appliquer les filtres de date sur FLOTs REÇUS
                if (_dateDebutFilter != null) {
                  flotsRecus = flotsRecus.where((f) {
                    final dateToCheck = f.dateReception ?? f.dateEnvoi;
                    return dateToCheck.isAfter(_dateDebutFilter!) || 
                           dateToCheck.isAtSameMomentAs(_dateDebutFilter!);
                  }).toList();
                }
                if (_dateFinFilter != null) {
                  flotsRecus = flotsRecus.where((f) {
                    final dateToCheck = f.dateReception ?? f.dateEnvoi;
                    return dateToCheck.isBefore(_dateFinFilter!.add(const Duration(days: 1)));
                  }).toList();
                }
                
                // Appliquer les filtres de date sur FLOTs ENVOYÉS
                if (_dateDebutFilter != null) {
                  flotsEnvoyes = flotsEnvoyes.where((f) {
                    final dateToCheck = f.dateEnvoi;
                    return dateToCheck.isAfter(_dateDebutFilter!) || 
                           dateToCheck.isAtSameMomentAs(_dateDebutFilter!);
                  }).toList();
                }
                if (_dateFinFilter != null) {
                  flotsEnvoyes = flotsEnvoyes.where((f) {
                    final dateToCheck = f.dateEnvoi;
                    return dateToCheck.isBefore(_dateFinFilter!.add(const Duration(days: 1)));
                  }).toList();
                }
                
                final flotsRecusPhysiques = flotsRecus.fold<double>(0.0, (sum, f) => sum + f.montant);
                final flotsEnvoyesPhysiques = flotsEnvoyes.fold<double>(0.0, (sum, f) => sum + f.montant);
                
                return FutureBuilder<double>(
                  future: _getSoldeAnterieurCash(shopIdFilter),
                  builder: (BuildContext context, soldeSnapshot) {
                    final soldeAnterieur = soldeSnapshot.data ?? 0.0;
                    
                    final capitalInitialCash = soldeAnterieur; // Solde antérieur de la dernière clôture
                    final flotsRecus = flotsRecusPhysiques; // FLOTs PHYSIQUES reçus
                    final flotsEnvoyes = flotsEnvoyesPhysiques; // FLOTs PHYSIQUES envoyés
                    final cashServiValue = cashServi; // Cash physique servi (toutes les SIMs)
                    // FORMULE: Cash Dispo = Solde Antérieur + FLOT Reçu - FLOT Envoyé - Cash Servi
                    final cashDisponible = capitalInitialCash + flotsRecus - flotsEnvoyes - cashServiValue;
                
                return Consumer<ShopService>(
                  builder: (BuildContext context, shopService, child) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Filtres de dates
                          _buildDateFilters(),
                          const SizedBox(height: 16),

                          // En-tête
                          Row(
                            children: [
                      const Icon(Icons.dashboard, color: Color(0xFF48bb78), size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vue d\'Ensemble',
                              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            if (_dateDebutFilter != null || _dateFinFilter != null)
                              Text(
                                'Période filtrée',
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                              ),
                            if (isAdmin && shopIdFilter == null)

                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'Vue TOUS LES SHOPS',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy').format(DateTime.now()),
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                            ],
                          ),
const SizedBox(height: 16),

                          // Statistiques financières
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Column(
                                children: [
                                  // HEADER - CASH DISPONIBLE
                                  Container(
                                    padding: const EdgeInsets.all(20),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.blue.withOpacity(0.1),
                                          Colors.blue.withOpacity(0.05),
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [Colors.blue, Color(0xFF1976D2)],
                                            ),
                                          ),
                                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Cash Disponible (Physique)',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // BODY - DETAILS CASH
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                  _buildFinanceRow('Solde Antérieur', capitalInitialCash, const Color(0xFF48bb78)),
                                  const SizedBox(height: 8),
                                  _buildFinanceRow('+ FLOTs reçus', flotsRecus, Colors.green),
                                  const SizedBox(height: 8),
                                  _buildFinanceRow('- FLOTs envoyés', flotsEnvoyes, Colors.orange),
                                  const SizedBox(height: 8),
                                  _buildFinanceRow('- Cash servis (Toutes SIMs)', cashServiValue, Colors.red),
                                  const SizedBox(height: 4),
                                  // Détails Cash Servi par SIM
                                  FutureBuilder<Map<String, double>>(
                                    future: _getCashServiParSim(shopIdFilter, validees),
                                    builder: (context, snapshot) {
                                      final cashParSim = snapshot.data ?? {};
                                      if (cashParSim.isEmpty) return const SizedBox.shrink();
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 16, top: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: cashParSim.entries.map((e) => 
                                            Text(
                                              '• ${e.key}: \$${e.value.toStringAsFixed(2)}',
                                              style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                                            )
                                          ).toList(),
                                        ),
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  const Divider(height: 16),
                                  _buildFinanceRow(
                                    'Cash Disponible',
                                    cashDisponible,
                                    cashDisponible >= 0 ? Colors.blue : Colors.orange,
                                  ),
                                  const SizedBox(height: 16),
                                  const SizedBox(height: 8),

                                  // VIRTUEL DISPONIBLE - FORMULE
                                  // Virtuel Disponible = Solde Antérieur (Solde d'hier) + Captures du Jour (SANS Frais) - Retraits du Jour (Toutes SIMs)
                                  FutureBuilder<double>(
                                    future: _getSoldeAnterieurVirtuel(shopIdFilter),
                                    builder: (context, virtuelSnapshot) {
                                      final soldeAnterieurVirtuel = virtuelSnapshot.data ?? 0.0;
                                      final capturesDuJour = montantTotalCaptures; // Captures SANS Frais
                                      final retraitsDuJour = montantTotalRetraits; // Retraits (Toutes SIMs)
                                      final virtuelDisponible = soldeAnterieurVirtuel + capturesDuJour - retraitsDuJour;
                                      
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // 1. SOLDE ANTÉRIEUR (Solde d'hier)
                                          _buildFinanceRow('Solde Antérieur (Virtuel)', soldeAnterieurVirtuel, Colors.grey),
                                          const SizedBox(height: 8),
                                          
                                          // 2. CAPTURES DU JOUR (Toutes SIMs) - Frais inclus sur le solde virtuel
                                          _buildFinanceRow('+ Captures du jour', capturesDuJour, Colors.green),
                                          const SizedBox(height: 8),
                                          
                                          // 3. RETRAITS DU JOUR (Toutes SIMs)
                                          _buildFinanceRow('- Retraits du jour', retraitsDuJour, Colors.red),
                                          const Divider(height: 16),
                                          
                                          // 4. RÉSULTAT = VIRTUEL DISPONIBLE
                                          _buildFinanceRow('= Virtuel Disponible', virtuelDisponible, Colors.purple, isBold: true, fontSize: 16),
                                          const SizedBox(height: 16),
                                          
                                          // 5. LISTE DES NON SERVIS PAR SIM
                                          if (enAttente.isNotEmpty) ...[
                                            const Divider(height: 16),
                                            const SizedBox(height: 8),
                                            Text(
                                              'Captures non servies par SIM:',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orange[800],
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            ...(() {
                                              // Grouper les non servis par SIM
                                              final Map<String, List<VirtualTransactionModel>> nonServisParSim = {};
                                              for (var transaction in enAttente) {
                                                final simKey = transaction.simNumero;
                                                if (!nonServisParSim.containsKey(simKey)) {
                                                  nonServisParSim[simKey] = [];
                                                }
                                                nonServisParSim[simKey]!.add(transaction);
                                              }
                                              
                                              // Créer les widgets pour chaque SIM
                                              return nonServisParSim.entries.map((entry) {
                                                final simNumero = entry.key;
                                                final transactions = entry.value;
                                                final totalMontant = transactions.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
                                                
                                                return Padding(
                                                  padding: const EdgeInsets.only(bottom: 8),
                                                  child: Container(
                                                    padding: const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.orange.shade50,
                                                      borderRadius: BorderRadius.circular(8),
                                                      border: Border.all(color: Colors.orange.shade200),
                                                    ),
                                                    child: Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          '📱 SIM: $simNumero',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.orange[900],
                                                          ),
                                                        ),
                                                        Text(
                                                          '${transactions.length} = \$${totalMontant.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight: FontWeight.bold,
                                                            color: Colors.orange[700],
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                );
                                              }).toList();
                                            })(),
                                          ],
                                        ],
                                      );
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                  _buildFinanceRow('Frais perçus (Virtuel)', fraisPercus, Colors.green),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Frais dans le solde virtuel',
                                    style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                  ),
                                  const SizedBox(height: 4),
                                  // Détails Captures par SIM (aujourd'hui)
                                  FutureBuilder<Map<String, Map<String, dynamic>>>(
                                    future: _getCapturesParSim(shopIdFilter, captures),
                                    builder: (context, snapshot) {
                                      final capturesParSim = snapshot.data ?? {};
                                      if (capturesParSim.isEmpty) return const SizedBox.shrink();
                                      
                                      return Padding(
                                        padding: const EdgeInsets.only(left: 16, top: 4),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Captures d\'aujourd\'hui:',
                                              style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                            ),
                                            ...capturesParSim.entries.map((e) => 
                                              Padding(
                                                padding: const EdgeInsets.only(bottom: 2, left: 8),
                                                child: Text(
                                                  '• ${e.key}: ${e.value['count']} capture(s) = \$${e.value['montant'].toStringAsFixed(2)}',
                                                  style: TextStyle(fontSize: 11, color: Colors.purple[700]),
                                                ),
                                              )
                                            ).toList(),
                                          ],
                                        ),
                                      );
                                    },
                                  ),
                                  
                                  const SizedBox(height: 16),
                                  const Divider(height: 8),
                                  const SizedBox(height: 8),
                                  
                                  // VIRTUEL DISPONIBLE - DUPLICATE (REMOVED)
                                  // Déjà affiché au-dessus, cette section est supprimée pour éviter la duplication
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // CARD CAPITAL NET
                          // Calculer le Virtuel Disponible pour le Capital Net (SANS Frais)
                          FutureBuilder<double>(
                            future: _getSoldeAnterieurVirtuel(shopIdFilter),
                            builder: (context, virtuelSoldeSnapshot) {
                              final soldeAnterieurVirtuel = virtuelSoldeSnapshot.data ?? 0.0;
                              final capturesDuJour = montantTotalCaptures;  // SANS frais
                              final retraitsDuJour = montantTotalRetraits;
                              final virtuelDisponible = soldeAnterieurVirtuel + capturesDuJour - retraitsDuJour;
                              final nonServi = montantEnAttente; // Captures non servies
                              
                              return FutureBuilder<Map<String, double>>(
                                future: _getCapitalNetData(shopIdFilter ?? currentShopId, cashDisponible, virtuelDisponible, enAttente),
                                builder: (context, capitalSnapshot) {
                                  final capitalData = capitalSnapshot.data ?? {};
                                  final shopsNousDoivent = capitalData['shopsNousDoivent'] ?? 0.0;
                                  final shopsNousDevons = capitalData['shopsNousDevons'] ?? 0.0;
                                  
                                  // CAPITAL NET = Cash Disponible + Virtuel Disponible + Shops nous doivent - Shops nous devons - Non Servi
                                  final capitalNet = cashDisponible + virtuelDisponible + shopsNousDoivent - shopsNousDevons - nonServi;
                              final isPositif = capitalNet >= 0;
                              
                              return Container(
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.08),
                                      blurRadius: 20,
                                      offset: const Offset(0, 8),
                                    ),
                                    BoxShadow(
                                      color: (isPositif ? Colors.green : Colors.orange).withOpacity(0.1),
                                      blurRadius: 30,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Column(
                                    children: [
                                      // HEADER
                                      Container(
                                        padding: const EdgeInsets.all(20),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              (isPositif ? Colors.green : Colors.orange).withOpacity(0.1),
                                              (isPositif ? Colors.green : Colors.orange).withOpacity(0.05),
                                            ],
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: isPositif 
                                                    ? [const Color(0xFF48bb78), Colors.green]
                                                    : [Colors.orange, Colors.deepOrange],
                                                ),
                                              ),
                                              child: Icon(
                                                isPositif ? Icons.trending_up : Icons.warning,
                                                color: Colors.white,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  const Text(
                                                    'CAPITAL NET',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.w600,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    '\$${capitalNet.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 32,
                                                      fontWeight: FontWeight.bold,
                                                      color: isPositif ? const Color(0xFF48bb78) : Colors.orange,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // BODY
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            _buildFinanceRow('Shops qui nous doivent', shopsNousDoivent, Colors.green),
                                            const SizedBox(height: 8),
                                            _buildFinanceRow('Shops que nous devons', shopsNousDevons, Colors.red),
                                            const SizedBox(height: 8),
                                            _buildFinanceRow('Non Servi (Virtuel)', nonServi, Colors.orange),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(12),
                                              decoration: BoxDecoration(
                                                color: Colors.green.shade50,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: Colors.green.shade200),
                                              ),
                                              child: Text(
                                                'CAPITAL NET = Cash Disponible + Virtuel Disponible + Shops nous doivent - Shops nous devons - Non Servi',
                                                style: TextStyle(fontSize: 10, color: Colors.green.shade800, fontStyle: FontStyle.italic),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            // BOUTON PRÉVISUALISATION PDF
                                            ElevatedButton.icon(
                                              onPressed: () => _previewRapportPdf(
                                                context,
                                                cashDisponible,
                                                virtuelDisponible,
                                                nonServi,
                                                shopsNousDoivent,
                                                shopsNousDevons,
                                                capitalNet,
                                                captures,
                                                validees,
                                                enAttente,
                                                retraits,
                                                montantTotalCaptures,
                                                fraisToutesCaptures,
                                                montantTotalRetraits,
                                                cashServi,
                                                flotsRecus,
                                                flotsEnvoyes,
                                              ),
                                              icon: const Icon(Icons.picture_as_pdf),
                                              label: const Text('Prévisualiser le Rapport PDF'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: const Color(0xFF48bb78),
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius: BorderRadius.circular(12),
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
                            },
                          );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Statistiques par opérateur
                          Card(
                            elevation: 3,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.business, color: Colors.indigo),
                                      SizedBox(width: 8),
                                      Text(
                                        'Par Opérateur',
                                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  ...statsParOperateur.entries.map((entry) {
                                    final operateur = entry.key;
                                    final stats = entry.value;
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade50,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.indigo.shade200),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  operateur,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.indigo,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                '${stats['nombre_sims']} SIM(s)',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey[700],
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'Solde total',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    '\$${stats['solde_total'].toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Color(0xFF48bb78),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Transactions',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    '${stats['transactions']}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Text(
                                                    'Frais',
                                                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    '\$${stats['frais'].toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.purple,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    );
                                  }),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
              },
            );
          },
        );
      },
    );
  }

  /// Rapport par SIM (soldes et transactions)
  Widget _buildRapportParSimTab() {
    return Consumer2<VirtualTransactionService, SimService>(
      builder: (BuildContext context, vtService, simService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentUser = authService.currentUser;
        final isAdmin = currentUser?.isAdmin ?? false;
        final currentShopId = currentUser?.shopId;
        
        if (!isAdmin && currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        // Filtrer par shop selon le rôle
        final shopIdFilter = isAdmin ? _selectedShopFilter : currentShopId;
        
        // Filtrer les SIMs
        var sims = simService.sims.where((s) => s.statut == SimStatus.active).toList();
        if (shopIdFilter != null) {
          sims = sims.where((s) => s.shopId == shopIdFilter).toList();
        }
        
        // Filtrer les transactions
        var transactions = shopIdFilter != null
            ? vtService.transactions.where((t) => t.shopId == shopIdFilter).toList()
            : vtService.transactions;

        // Appliquer les filtres de dates
        if (_dateDebutFilter != null) {
          transactions = transactions
              .where((t) => t.dateEnregistrement.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          transactions = transactions
              .where((t) => t.dateEnregistrement.isBefore(_dateFinFilter!))
              .toList();
        }
        // Filtrer par SIM (si sélectionnée)
        if (_selectedSimFilter != null) {
          transactions = transactions
              .where((t) => t.simNumero == _selectedSimFilter)
              .toList();
          sims = sims.where((s) => s.numero == _selectedSimFilter).toList();
        }

        // NOUVEAU: Charger les retraits virtuels
        return FutureBuilder<List<RetraitVirtuelModel>>(
          future: LocalDB.instance.getAllRetraitsVirtuels(shopSourceId: shopIdFilter),
          builder: (BuildContext context, retraitsSnapshot) {
            var retraits = retraitsSnapshot.data ?? [];
            
            // Appliquer les filtres de dates sur les retraits
            if (_dateDebutFilter != null) {
              retraits = retraits.where((r) => r.dateRetrait.isAfter(_dateDebutFilter!)).toList();
            }
            if (_dateFinFilter != null) {
              retraits = retraits.where((r) => r.dateRetrait.isBefore(_dateFinFilter!)).toList();
            }
            // Filtrer par SIM
            if (_selectedSimFilter != null) {
              retraits = retraits.where((r) => r.simNumero == _selectedSimFilter).toList();
            }

        if (sims.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sim_card_alert, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  isAdmin && _selectedShopFilter != null
                      ? 'Aucune SIM disponible pour ce shop'
                      : 'Aucune SIM disponible',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        // Calculer les statistiques par SIM
        final simStats = <String, Map<String, dynamic>>{};
        
        for (var sim in sims) {
          final simTransactions = transactions.where((t) => t.simNumero == sim.numero).toList();
          final validees = simTransactions.where((t) => t.statut == VirtualTransactionStatus.validee).toList();
          final enAttente = simTransactions.where((t) => t.statut == VirtualTransactionStatus.enAttente).toList();
          
          // NOUVEAU: Calculer les retraits pour cette SIM
          final simRetraits = retraits.where((r) => r.simNumero == sim.numero).toList();
          final nbRetraits = simRetraits.length;
          final montantTotalRetraits = simRetraits.fold<double>(0, (sum, r) => sum + r.montant);
          
          final totalVirtuel = validees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final totalFrais = validees.fold<double>(0, (sum, t) => sum + t.frais);
          final totalCash = validees.fold<double>(0, (sum, t) => sum + t.montantCash);
          final montantEnAttente = enAttente.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          
          simStats[sim.numero] = {
            'sim': sim,
            'nb_total': simTransactions.length,
            'nb_validees': validees.length,
            'nb_en_attente': enAttente.length,
            'nb_retraits': nbRetraits,
            'montant_retraits': montantTotalRetraits,
            'total_virtuel': totalVirtuel,
            'total_frais': totalFrais,
            'total_cash': totalCash,
            'montant_en_attente': montantEnAttente,
            'solde_actuel': sim.soldeActuel,
          };
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtres de dates
              _buildDateFilters(),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Icon(Icons.sim_card, color: Color(0xFF48bb78), size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rapport par SIM',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        if (_dateDebutFilter != null || _dateFinFilter != null)
                          Text(
                            'Période filtrée (soldes actuels non affectés)',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontStyle: FontStyle.italic),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Liste des SIMs avec leurs stats
              ...simStats.entries.map((entry) {
                final simNumero = entry.key;
                final stats = entry.value;
                final sim = stats['sim'] as SimModel;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 16),
                  elevation: 3,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF48bb78).withOpacity(0.1),
                      child: const Icon(Icons.sim_card, color: Color(0xFF48bb78)),
                    ),
                    title: Text(
                      simNumero,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          sim.operateur,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF48bb78).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Solde: \$${stats['solde_actuel'].toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF48bb78),
                            ),
                          ),
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _buildSimStatRow('Transactions Total', '${stats['nb_total']}', Icons.receipt_long, Colors.blue),
                            _buildSimStatRow('Servies', '${stats['nb_validees']}', Icons.check_circle, Colors.green),
                            _buildSimStatRow('En Attente', '${stats['nb_en_attente']}', Icons.hourglass_empty, Colors.orange),
                            _buildSimStatRow('Retraits', '${stats['nb_retraits']}', Icons.remove_circle, Colors.purple),
                            const Divider(height: 24),
                            _buildSimStatRow('Virtuel Encaissé', '\$${stats['total_virtuel'].toStringAsFixed(2)}', Icons.mobile_friendly, const Color(0xFF48bb78)),
                            _buildSimStatRow('Frais Générés', '\$${stats['total_frais'].toStringAsFixed(2)}', Icons.attach_money, Colors.purple),
                            _buildSimStatRow('Cash Servi', '\$${stats['total_cash'].toStringAsFixed(2)}', Icons.money, Colors.red),
                            _buildSimStatRow('Montant Retraits', '\$${stats['montant_retraits'].toStringAsFixed(2)}', Icons.payments, Colors.purple),
                            if (stats['montant_en_attente'] > 0)
                              _buildSimStatRow('En Attente (Montant)', '\$${stats['montant_en_attente'].toStringAsFixed(2)}', Icons.pending, Colors.orange),
                            const Divider(height: 24),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF48bb78).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF48bb78), width: 2),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.info_outline, color: Color(0xFF48bb78), size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Solde Actuel (Toutes périodes)',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[700],
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _buildSimStatRow('Solde SIM Actuel', '\$${stats['solde_actuel'].toStringAsFixed(2)}', Icons.account_balance_wallet, const Color(0xFF48bb78), isBold: true),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
          },
        );
      },
    );
  }

  /// Rapport des Frais (Commissions)
  Widget _buildRapportFraisTab() {
    return Consumer<VirtualTransactionService>(
      builder: (BuildContext context, service, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        var transactions = service.transactions
            .where((t) => t.shopId == currentShopId && t.statut == VirtualTransactionStatus.validee)
            .toList();

        // Appliquer les filtres de dates
        if (_dateDebutFilter != null) {
          transactions = transactions
              .where((t) => t.dateValidation != null && t.dateValidation!.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          transactions = transactions
              .where((t) => t.dateValidation != null && t.dateValidation!.isBefore(_dateFinFilter!))
              .toList();
        }

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Aucune transaction validée'),
                const SizedBox(height: 8),
                if (_dateDebutFilter != null || _dateFinFilter != null)
                  TextButton.icon(
                    icon: const Icon(Icons.clear),
                    label: const Text('Effacer les filtres'),
                    onPressed: () {
                      setState(() {
                        _dateDebutFilter = null;
                        _dateFinFilter = null;
                      });
                    },
                  ),
              ],
            ),
          );
        }

        // Statistiques globales
        final totalFrais = transactions.fold<double>(0, (sum, t) => sum + t.frais);
        final totalVirtuel = transactions.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final moyenneFrais = totalFrais / transactions.length;
        final tauxMoyenFrais = (totalFrais / totalVirtuel) * 100;

        // Regrouper par SIM
        final fraisParSim = <String, Map<String, dynamic>>{};
        for (var transaction in transactions) {
          if (!fraisParSim.containsKey(transaction.simNumero)) {
            fraisParSim[transaction.simNumero] = {
              'nb_transactions': 0,
              'total_frais': 0.0,
              'total_virtuel': 0.0,
            };
          }
          fraisParSim[transaction.simNumero]!['nb_transactions'] = 
              (fraisParSim[transaction.simNumero]!['nb_transactions'] as int) + 1;
          fraisParSim[transaction.simNumero]!['total_frais'] = 
              (fraisParSim[transaction.simNumero]!['total_frais'] as double) + transaction.frais;
          fraisParSim[transaction.simNumero]!['total_virtuel'] = 
              (fraisParSim[transaction.simNumero]!['total_virtuel'] as double) + transaction.montantVirtuel;
        }

        // Regrouper par agent
        final fraisParAgent = <String, Map<String, dynamic>>{};
        for (var transaction in transactions) {
          final agentKey = transaction.agentUsername ?? 'Agent ${transaction.agentId}';
          if (!fraisParAgent.containsKey(agentKey)) {
            fraisParAgent[agentKey] = {
              'nb_transactions': 0,
              'total_frais': 0.0,
            };
          }
          fraisParAgent[agentKey]!['nb_transactions'] = 
              (fraisParAgent[agentKey]!['nb_transactions'] as int) + 1;
          fraisParAgent[agentKey]!['total_frais'] = 
              (fraisParAgent[agentKey]!['total_frais'] as double) + transaction.frais;
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtres de dates
              _buildDateFilters(),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Icon(Icons.attach_money, color: Colors.purple, size: 28),
                  const SizedBox(width: 12),
                  const Text(
                    'Rapport des Frais',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat('dd/MM/yyyy').format(DateTime.now()),
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Résumé global
              Card(
                elevation: 3,
                color: Colors.purple.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Résumé Global',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildSimStatRow('Total Transactions', '${transactions.length}', Icons.receipt, Colors.blue),
                      _buildSimStatRow('Total Frais', '\$${totalFrais.toStringAsFixed(2)}', Icons.attach_money, Colors.purple, isBold: true),
                      _buildSimStatRow('Moyenne Frais/Trans', '\$${moyenneFrais.toStringAsFixed(2)}', Icons.trending_up, Colors.orange),
                      _buildSimStatRow('Taux Moyen Frais', '${tauxMoyenFrais.toStringAsFixed(2)}%', Icons.percent, Colors.green),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Frais par SIM
              const Text(
                'Frais par SIM',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...fraisParSim.entries.map((entry) {
                final simNumero = entry.key;
                final stats = entry.value;
                final tauxFrais = ((stats['total_frais'] as double) / (stats['total_virtuel'] as double)) * 100;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFF48bb78),
                      child: Icon(Icons.sim_card, color: Colors.white, size: 20),
                    ),
                    title: Text(simNumero, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${stats['nb_transactions']} transactions - Taux: ${tauxFrais.toStringAsFixed(2)}%'),
                    trailing: Text(
                      '\$${(stats['total_frais'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 24),
              
              // Frais par Agent
              const Text(
                'Frais par Agent',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              ...fraisParAgent.entries.map((entry) {
                final agentName = entry.key;
                final stats = entry.value;
                
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Icon(Icons.person, color: Colors.white, size: 20),
                    ),
                    title: Text(agentName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${stats['nb_transactions']} transactions'),
                    trailing: Text(
                      '\$${(stats['total_frais'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple,
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// Ligne de statistique pour SIM
  Widget _buildSimStatRow(String label, String value, IconData icon, Color color, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 18 : 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Onglet rapport quotidien (ANCIEN - conservé pour référence, peut être supprimé)
  Widget _buildOldRapportTab() {
    return Consumer<VirtualTransactionService>(
      builder: (BuildContext context, service, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        return FutureBuilder<Map<String, dynamic>>(
          future: service.getDailyStats(shopId: currentShopId, date: DateTime.now()),
          builder: (BuildContext context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(child: Text('Aucune donnée disponible'));
            }

            final stats = snapshot.data!;
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rapport du ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),
                  _buildStatCard('Total Transactions', '${stats['total_transactions'] ?? 0}', Icons.receipt, Colors.blue),
                  _buildStatCard('En Attente', '${stats['transactions_en_attente'] ?? 0}', Icons.hourglass_empty, Colors.orange),
                  _buildStatCard('Servies', '${stats['transactions_validees'] ?? 0}', Icons.check_circle, Colors.green),
                  const Divider(height: 32),
                  _buildStatCard(
                    'Virtuel Encaissé',
                    '\$${(stats['total_virtuel_encaisse'] ?? 0).toStringAsFixed(2)}',
                    Icons.mobile_friendly,
                    const Color(0xFF48bb78),
                  ),
                  _buildStatCard(
                    'Frais Générés',
                    '\$${(stats['total_frais'] ?? 0).toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.purple,
                  ),
                  _buildStatCard(
                    'Cash Servi',
                    '\$${(stats['total_cash_servi'] ?? 0).toStringAsFixed(2)}',
                    Icons.money,
                    Colors.red,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Carte de statistique
  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(label, style: TextStyle(color: Colors.grey[700])),
        trailing: Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }

  /// Widget pour afficher une stat dans une grid card
  Widget _buildGridStatCard(String title, String count, String amount, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 24, color: color),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(fontSize: 10, color: Colors.grey[700], fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),
            Text(
              count,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              amount,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  /// Widget pour afficher une ligne de stat financière
  /// Obtenir le cash servi groupé par SIM
  Future<Map<String, double>> _getCashServiParSim(int? shopId, List<VirtualTransactionModel> validees) async {
    final Map<String, double> cashParSim = {};
    
    for (final transaction in validees) {
      final simKey = transaction.simNumero;
      cashParSim[simKey] = (cashParSim[simKey] ?? 0.0) + transaction.montantCash;
    }
    
    return cashParSim;
  }
  
  /// Obtenir les captures groupées par SIM
  Future<Map<String, Map<String, dynamic>>> _getCapturesParSim(int? shopId, List<VirtualTransactionModel> captures) async {
    final Map<String, Map<String, dynamic>> capturesParSim = {};
    
    for (final transaction in captures) {
      final simKey = transaction.simNumero;
      if (!capturesParSim.containsKey(simKey)) {
        capturesParSim[simKey] = {'count': 0, 'montant': 0.0};
      }
      capturesParSim[simKey]!['count'] += 1;
      capturesParSim[simKey]!['montant'] += transaction.montantVirtuel;
    }
    
    return capturesParSim;
  }
  
  /// Obtenir les données pour le CAPITAL NET
  Future<Map<String, double>> _getCapitalNetData(int? shopId, double cashDisponible, double virtuelDisponible, List<VirtualTransactionModel> capturesEnAttente) async {
    if (shopId == null) {
      return {
        'shopsNousDoivent': 0.0,
        'shopsNousDevons': 0.0,
        'capturesEnAttente': 0.0,
      };
    }
    
    try {
      // Récupérer tous les retraits et FLOTs pour calculer les soldes
      final retraits = await LocalDB.instance.getAllRetraitsVirtuels();
      final allFlots = await LocalDB.instance.getAllFlots();
      
      // Filtrer pour notre shop
      final retraitsFiltres = retraits.where((r) => 
        r.shopSourceId == shopId || r.shopDebiteurId == shopId
      ).toList();
      
      final flots = allFlots.where((f) => 
        f.shopSourceId == shopId || f.shopDestinationId == shopId
      ).toList();
      
      double shopsNousDoivent = 0.0;
      double shopsNousDevons = 0.0;
      
      // Calculer par shop
      final Map<int, double> soldesParShop = {};
      
      // Retraits
      for (final retrait in retraitsFiltres) {
        if (retrait.shopSourceId == shopId) {
          // On est créancier
          final autreShopId = retrait.shopDebiteurId;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + retrait.montant;
        } else {
          // On est débiteur
          final autreShopId = retrait.shopSourceId;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - retrait.montant;
        }
      }
      
      // FLOTs
      for (final flot in flots) {
        if (flot.statut == flot_model.StatutFlot.servi) {
          if (flot.shopSourceId == shopId) {
            // On a envoyé
            final autreShopId = flot.shopDestinationId;
            soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montant;
          } else if (flot.shopDestinationId == shopId) {
            // On a reçu
            final autreShopId = flot.shopSourceId;
            soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montant;
          }
        }
      }
      
      // Séparer positifs et négatifs
      for (final solde in soldesParShop.values) {
        if (solde > 0) {
          shopsNousDoivent += solde;
        } else if (solde < 0) {
          shopsNousDevons += solde.abs();
        }
      }
      
      // Captures en attente
      final montantCapturesEnAttente = capturesEnAttente.fold<double>(
        0.0,
        (sum, t) => sum + t.montantVirtuel,
      );
      
      return {
        'shopsNousDoivent': shopsNousDoivent,
        'shopsNousDevons': shopsNousDevons,
        'capturesEnAttente': montantCapturesEnAttente,
      };
    } catch (e) {
      debugPrint('Erreur calcul CAPITAL NET: $e');
      return {
        'shopsNousDoivent': 0.0,
        'shopsNousDevons': 0.0,
        'capturesEnAttente': 0.0,
      };
    }
  }

  Widget _buildFinanceRow(String label, double amount, Color color, {bool isBold = false, double fontSize = 14}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }


  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.grey[100],
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Consumer<SimService>(
                  builder: (BuildContext context, simService, child) {
                    final authService = Provider.of<AuthService>(context, listen: false);
                    final currentShopId = authService.currentUser?.shopId;
                    
                    final sims = simService.sims
                        .where((s) => s.shopId == currentShopId && s.statut == SimStatus.active)
                        .toList();

                    return DropdownButtonFormField<String>(
                      value: _selectedSimFilter,
                      decoration: const InputDecoration(
                        labelText: 'Filtrer par SIM',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('Toutes les SIMs')),
                        ...sims.map((sim) => DropdownMenuItem(
                          value: sim.numero,
                          child: Text('${sim.numero} (${sim.operateur})'),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedSimFilter = value;
                        });
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_dateDebutFilter != null
                      ? DateFormat('dd/MM/yyyy').format(_dateDebutFilter!)
                      : 'Date début'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateDebutFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dateDebutFilter = date);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(_dateFinFilter != null
                      ? DateFormat('dd/MM/yyyy').format(_dateFinFilter!)
                      : 'Date fin'),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _dateFinFilter ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _dateFinFilter = date);
                    }
                  },
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  setState(() {
                    _selectedSimFilter = null;
                    _dateDebutFilter = null;
                    _dateFinFilter = null;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Card de transaction
  Widget _buildTransactionCard(VirtualTransactionModel transaction, {required bool isEnAttente}) {
    final color = isEnAttente ? Colors.orange : Colors.green;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 2,
      child: InkWell(
        onTap: () => _showTransactionDetails(transaction),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: color.withOpacity(0.1),
                    child: Icon(
                      isEnAttente ? Icons.hourglass_empty : Icons.check_circle,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REF: ${transaction.reference}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Text(
                          'SIM: ${transaction.simNumero}',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '\$${transaction.montantCash.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      Text(
                        'Cash à servir',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Virtuel: \$${transaction.montantVirtuel.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Text(
                    'Frais: \$${transaction.frais.toStringAsFixed(2)}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Enregistré: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateEnregistrement)}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              if (transaction.clientNom != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Client: ${transaction.clientNom} - ${transaction.clientTelephone}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                ),
              ],
              if (isEnAttente) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _serveClient(transaction),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Servir Client'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Afficher les détails d'un retrait virtuel
  void _showRetraitDetails(RetraitVirtuelModel retrait) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Détails Retrait Virtuel'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('SIM', '${retrait.simNumero} (${retrait.simOperateur ?? "N/A"})'),
              _buildDetailRow('Montant', '\$${retrait.montant.toStringAsFixed(2)}'),
              _buildDetailRow('Solde Avant', '\$${retrait.soldeAvant.toStringAsFixed(2)}'),
              _buildDetailRow('Solde Après', '\$${retrait.soldeApres.toStringAsFixed(2)}'),
              _buildDetailRow('Shop Débiteur', retrait.shopDebiteurDesignation ?? 'N/A'),
              _buildDetailRow('Agent', retrait.agentUsername ?? 'N/A'),
              _buildDetailRow('Statut', retrait.statutLabel),
              _buildDetailRow('Date Retrait', DateFormat('dd/MM/yyyy HH:mm').format(retrait.dateRetrait)),
              if (retrait.dateRemboursement != null)
                _buildDetailRow('Date Remboursement', DateFormat('dd/MM/yyyy HH:mm').format(retrait.dateRemboursement!)),
              if (retrait.notes != null && retrait.notes!.isNotEmpty)
                _buildDetailRow('Notes', retrait.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Afficher les détails d'une transaction
  void _showTransactionDetails(VirtualTransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Transaction ${transaction.reference}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow('Référence', transaction.reference),
              _buildDetailRow('SIM', transaction.simNumero),
              _buildDetailRow('Montant Virtuel', '\$${transaction.montantVirtuel.toStringAsFixed(2)}'),
              _buildDetailRow('Frais', '\$${transaction.frais.toStringAsFixed(2)}'),
              _buildDetailRow('Cash à Servir', '\$${transaction.montantCash.toStringAsFixed(2)}'),
              _buildDetailRow('Statut', transaction.statutLabel),
              _buildDetailRow('Date Enregistrement', DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateEnregistrement)),
              if (transaction.dateValidation != null)
                _buildDetailRow('Date Validation', DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateValidation!)),
              if (transaction.clientNom != null)
                _buildDetailRow('Client', '${transaction.clientNom} - ${transaction.clientTelephone}'),
              if (transaction.notes != null && transaction.notes!.isNotEmpty)
                _buildDetailRow('Notes', transaction.notes!),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          if (transaction.statut == VirtualTransactionStatus.enAttente)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _serveClient(transaction);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('Servir'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Créer une nouvelle transaction
  Future<void> _createTransaction() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateVirtualTransactionDialog(),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  /// Créer un retrait virtuel
  Future<void> _createRetraitVirtuel() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateRetraitVirtuelDialog(),
    );
    
    if (result == true) {
      setState(() {
        _retraitsTabKey = UniqueKey(); // Forcer le rechargement de l'onglet retraits
      });
      await _loadData();
    }
  }
  
  /// Marquer un retrait comme remboursé (VALIDATION PAR LE SHOP DÉBITEUR)
  Future<void> _marquerRetraitRembourse(RetraitVirtuelModel retrait) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    // Confirmer l'action
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Valider le remboursement'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirmer que vous avez REMBOURSÉ ce retrait ?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Montant: \$${retrait.montant.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('Shop créancier: ${retrait.shopSourceDesignation}'),
                  Text('Vous devez: ${retrait.shopDebiteurDesignation}'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text(
                '⚠️ En validant, vous confirmez avoir DONNÉ le cash à l\'autre shop. Cette action mettra à jour les soldes des deux shops.',
                style: TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, true),
            icon: const Icon(Icons.check),
            label: const Text('Confirmer'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
    
    if (confirm != true) return;
    
    try {
      // Mettre à jour le statut
      final retraitMisAJour = retrait.copyWith(
        statut: RetraitVirtuelStatus.rembourse,
        dateRemboursement: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser?.username ?? 'System',
        isSynced: false, // Marquer pour sync
      );
      
      await LocalDB.instance.saveRetraitVirtuel(retraitMisAJour);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Remboursement validé!\n'
              'Montant: \$${retrait.montant.toStringAsFixed(2)}\n'
              'Vous avez confirmé avoir payé ${retrait.shopSourceDesignation}.\n'
              'Les soldes ont été mis à jour pour les deux shops.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        
        setState(() {}); // Rafraîchir l'affichage
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Rechercher une transaction par référence
  Future<void> _searchByReference() async {
    final reference = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('Rechercher par Référence'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Référence',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Rechercher'),
            ),
          ],
        );
      },
    );

    if (reference != null && reference.isNotEmpty) {
      final transaction = await VirtualTransactionService.instance.findByReference(reference);
      
      if (transaction != null && mounted) {
        if (transaction.statut == VirtualTransactionStatus.enAttente) {
          _serveClient(transaction);
        } else {
          _showTransactionDetails(transaction);
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ Référence non trouvée')),
        );
      }
    }
  }

  /// Servir un client
  Future<void> _serveClient(VirtualTransactionModel transaction) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ServeClientDialog(transaction: transaction),
    );
    
    if (result == true) {
      await _loadData();
    }
  }

  /// Générer et prévisualiser le rapport PDF
  Future<void> _previewRapportPdf(
    BuildContext context,
    double cashDisponible,
    double virtuelDisponible,
    double nonServi,
    double shopsNousDoivent,
    double shopsNousDevons,
    double capitalNet,
    List<VirtualTransactionModel> captures,
    List<VirtualTransactionModel> validees,
    List<VirtualTransactionModel> enAttente,
    List<dynamic> retraits,
    double montantTotalCaptures,
    double fraisToutesCaptures,
    double montantTotalRetraits,
    double cashServi,
    double flotsRecus,
    double flotsEnvoyes,
  ) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      final shopName = 'Shop #${currentUser?.shopId ?? 0}';
      final agentName = currentUser?.username ?? 'Agent';
      final dateNow = DateTime.now();
      
      // Créer le document PDF
      final pdf = pw.Document();
      
      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // EN-TÊTE
                pw.Container(
                  padding: const pw.EdgeInsets.all(20),
                  decoration: pw.BoxDecoration(
                    color: const PdfColor.fromInt(0xFF48bb78),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'RAPPORT DES TRANSACTIONS VIRTUELLES',
                        style: pw.TextStyle(
                          fontSize: 20,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '$shopName - $agentName',
                        style: pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(dateNow),
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                
                // CASH DISPONIBLE
                pw.Text(
                  'Cash Disponible (Physique)',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                _buildPdfRow('FLOTs reçus', flotsRecus),
                _buildPdfRow('FLOTs envoyés', flotsEnvoyes),
                _buildPdfRow('Cash servis', cashServi),
                pw.Divider(),
                _buildPdfRow('TOTAL', cashDisponible, isBold: true),
                pw.SizedBox(height: 20),
                
                // VIRTUEL DISPONIBLE
                pw.Text(
                  'Virtuel Disponible',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                _buildPdfRow('Captures du jour', montantTotalCaptures),
                _buildPdfRow('Retraits du jour', montantTotalRetraits),
                pw.Divider(),
                _buildPdfRow('TOTAL', virtuelDisponible, isBold: true),
                pw.SizedBox(height: 20),
                
                // CAPITAL NET
                pw.Text(
                  'CAPITAL NET',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                _buildPdfRow('Cash Disponible', cashDisponible),
                _buildPdfRow('Virtuel Disponible', virtuelDisponible),
                _buildPdfRow('Shops qui nous doivent', shopsNousDoivent),
                _buildPdfRow('Shops que nous devons', shopsNousDevons),
                _buildPdfRow('Non Servi (Virtuel)', nonServi),
                pw.Divider(),
                _buildPdfRow('CAPITAL NET', capitalNet, isBold: true, fontSize: 18),
                pw.SizedBox(height: 20),
                
                // STATISTIQUES
                pw.Text(
                  'Statistiques',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                _buildPdfRow('Total Captures', captures.length.toDouble(), isCount: true),
                _buildPdfRow('Captures Servies', validees.length.toDouble(), isCount: true),
                _buildPdfRow('Captures En Attente', enAttente.length.toDouble(), isCount: true),
                _buildPdfRow('Total Retraits', retraits.length.toDouble(), isCount: true),
              ],
            );
          },
        ),
      );
      
      // Afficher le PDF
      if (context.mounted) {
        await showDialog(
          context: context,
          builder: (context) => PdfViewerDialog(
            pdfDocument: pdf,
            title: 'Rapport Transactions Virtuelles',
            fileName: 'rapport_virtuel_${DateFormat('yyyyMMdd_HHmmss').format(dateNow)}',
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur génération PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Construire une ligne pour le PDF
  pw.Widget _buildPdfRow(String label, double value, {bool isBold = false, double fontSize = 12, bool isCount = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal,
            ),
          ),
          pw.Text(
            isCount ? value.toInt().toString() : '\$${value.toStringAsFixed(2)}',
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
