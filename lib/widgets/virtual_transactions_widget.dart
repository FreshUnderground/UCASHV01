import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/virtual_transaction_service.dart';
import '../services/auth_service.dart';
import '../services/sim_service.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';
import '../models/virtual_transaction_model.dart';
import '../models/sim_model.dart';
import '../models/retrait_virtuel_model.dart';
import '../models/cloture_virtuelle_model.dart';
import '../models/depot_client_model.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/operation_model.dart';
import 'create_virtual_transaction_dialog.dart';
import 'serve_client_dialog.dart';
import 'create_retrait_virtuel_dialog.dart';
import 'create_depot_client_dialog.dart';
import 'cloture_virtuelle_moderne_widget.dart';
import 'modern_transaction_card.dart';
import 'pdf_viewer_dialog.dart';
import 'flot_management_widget.dart';


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
  DateTime? _selectedDate; // NOUVEAU: Date unique pour Vue d'Ensemble
  Key _retraitsTabKey = UniqueKey(); // Pour forcer le rechargement
  bool _showFilters = false; // Masquer les filtres par défaut
  
  // 🔍 NOUVEAU: Filtres de recherche
  VirtualTransactionStatus? _statusFilter = VirtualTransactionStatus.enAttente; // Par défaut: En Attente
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // Pour recherche par référence ou téléphone
  
  // 🔍 NOUVEAU: Filtres pour Flots
  bool _showFlotFilters = false; // Masquer les filtres par défaut
  String? _flotTabFilter; // 'vue', 'retraits', 'flots'
  final TextEditingController _flotSearchController = TextEditingController();
  String _flotSearchQuery = ''; // Pour recherche par code
  DateTime? _flotDateFilter; // Pour filtrage par date
  
  // 🔍 NOUVEAU: Filtres pour Dépôt
  bool _showDepotFilters = false; // Masquer les filtres par défaut
  final TextEditingController _depotSearchController = TextEditingController();
  String _depotSearchQuery = ''; // Pour recherche par numéro de téléphone
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _flotSearchController.dispose();
    _depotSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser?.shopId != null) {
      // 🧹 Nettoyer les doublons au démarrage (une seule fois)
      await VirtualTransactionService.instance.loadTransactions(
        shopId: currentUser!.shopId,
        cleanDuplicates: true, // Activer le nettoyage au premier chargement
      );
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF48bb78), Color(0xFF38a169)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
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
                  text: 'Captures',
                ),
                Tab(
                  icon: Icon(Icons.send, size: isMobile ? 18 : 22),
                  text: 'Flots',
                ),
                Tab(
                  icon: Icon(Icons.account_balance, size: isMobile ? 18 : 22),
                  text: 'Dépôt',
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
          _buildDepotTab(),
          _buildClotureTab(),
          _buildRapportTab(),
        ],
      ),

    );
  }

  /// Onglet Transactions (avec sous-onglets: Tout, En Attente, Servies)
  Widget _buildTransactionsTab() {
    return Column(
      children: [
        // Bouton pour afficher/masquer les filtres + Bouton Nouvelle Capture
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Row(
            children: [
              // ✨ Bouton Nouvelle Capture (moderne et joli)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createTransaction,
                  icon: const Icon(Icons.add_circle_outline, size: 22),
                  label: const Text(
                    'Nouvelle Capture',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF48bb78),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    elevation: 2,
                    shadowColor: const Color.fromARGB(255, 126, 204, 84).withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Bouton filtres
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
                icon: Icon(
                  _showFilters ? Icons.filter_alt_off : Icons.filter_alt,
                  size: 20,
                ),
                label: Text(
                  _showFilters ? 'Masquer' : 'Filtres',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF48bb78),
                  side: const BorderSide(color: Color(0xFF48bb78), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 🔍 Barre de recherche et filtres (affichables/masquables)
        if (_showFilters)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Barre de recherche
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par référence ou téléphone...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF48bb78)),
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
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase().trim();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Filtres de statut
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Tout'),
                        selected: _statusFilter == null,
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = selected ? null : _statusFilter;
                          });
                        },
                        selectedColor: const Color(0xFF48bb78),
                        labelStyle: TextStyle(
                          color: _statusFilter == null ? Colors.white : Colors.black87,
                          fontWeight: _statusFilter == null ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('En Attente'),
                        selected: _statusFilter == VirtualTransactionStatus.enAttente,
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = selected ? VirtualTransactionStatus.enAttente : null;
                          });
                        },
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(
                          color: _statusFilter == VirtualTransactionStatus.enAttente ? Colors.white : Colors.black87,
                          fontWeight: _statusFilter == VirtualTransactionStatus.enAttente ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Servies'),
                        selected: _statusFilter == VirtualTransactionStatus.validee,
                        onSelected: (selected) {
                          setState(() {
                            _statusFilter = selected ? VirtualTransactionStatus.validee : null;
                          });
                        },
                        selectedColor: Colors.green,
                        labelStyle: TextStyle(
                          color: _statusFilter == VirtualTransactionStatus.validee ? Colors.white : Colors.black87,
                          fontWeight: _statusFilter == VirtualTransactionStatus.validee ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        // Liste des transactions
        Expanded(
          child: _buildFilteredTransactionsList(),
        ),
      ],
    );
  }

  /// Liste filtrée des transactions avec recherche
  Widget _buildFilteredTransactionsList() {
    return Consumer<VirtualTransactionService>(
      builder: (BuildContext context, service, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        if (currentShopId == null) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        // Filtrer par shop
        var transactions = service.transactions
            .where((t) => t.shopId == currentShopId)
            .toList();

        // Filtrer par statut si sélectionné
        if (_statusFilter != null) {
          transactions = transactions.where((t) => t.statut == _statusFilter).toList();
        }

        // Filtrer par recherche (référence ou téléphone)
        if (_searchQuery.isNotEmpty) {
          transactions = transactions.where((t) {
            final reference = t.reference.toLowerCase();
            final telephone = (t.clientTelephone ?? '').toLowerCase();
            return reference.contains(_searchQuery) || telephone.contains(_searchQuery);
          }).toList();
        }
        
        // Supprimer les doublons par référence (garder la plus récente)
        final Map<String, VirtualTransactionModel> uniqueTransactions = {};
        for (var transaction in transactions) {
          final key = transaction.reference;
          if (!uniqueTransactions.containsKey(key) || 
              transaction.dateEnregistrement.isAfter(uniqueTransactions[key]!.dateEnregistrement)) {
            uniqueTransactions[key] = transaction;
          }
        }
        transactions = uniqueTransactions.values.toList();
        
        // Trier par date (plus récents en premier)
        transactions.sort((a, b) => b.dateEnregistrement.compareTo(a.dateEnregistrement));

        if (service.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (transactions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _searchQuery.isNotEmpty ? Icons.search_off : Icons.inbox_outlined,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty 
                      ? 'Aucun résultat pour "$_searchQuery"'
                      : 'Aucune transaction',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'Essayez une autre recherche'
                      : 'Les captures apparaitront ici',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: _loadData,
          child: ListView.builder(
            padding: const EdgeInsets.all(4),
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final transaction = transactions[index];
              final isEnAttente = transaction.statut == VirtualTransactionStatus.enAttente;
              
              return ModernTransactionCard(
                transaction: transaction,
                isEnAttente: isEnAttente,
                onTap: () => _showTransactionDetails(transaction),
                onServe: isEnAttente ? () => _serveClient(transaction) : null,
              );
            },
          ),
        );
      },
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
        
        // Supprimer les doublons par référence (garder la plus récente)
        final Map<String, VirtualTransactionModel> uniqueTransactions = {};
        for (var transaction in filteredTransactions) {
          final key = transaction.reference;
          if (!uniqueTransactions.containsKey(key) || 
              transaction.dateEnregistrement.isAfter(uniqueTransactions[key]!.dateEnregistrement)) {
            uniqueTransactions[key] = transaction;
          }
        }
        filteredTransactions = uniqueTransactions.values.toList();
        // Trier par date (plus récents en premier)
        filteredTransactions.sort((a, b) => b.dateEnregistrement.compareTo(a.dateEnregistrement));

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
            // Bouton pour afficher/masquer les filtres
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
                    label: Text(_showFilters ? 'Masquer filtres' : 'Afficher filtres'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF48bb78),
                    ),
                  ),
                ],
              ),
            ),
            if (_showFilters) _buildFilters(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadData,
                child: ListView.builder(
                  padding: const EdgeInsets.all(4),
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
        
        // Supprimer les doublons par référence (garder la plus récente)
        final Map<String, VirtualTransactionModel> uniqueTransactions = {};
        for (var transaction in transactions) {
          final key = transaction.reference;
          if (!uniqueTransactions.containsKey(key) || 
              transaction.dateEnregistrement.isAfter(uniqueTransactions[key]!.dateEnregistrement)) {
            uniqueTransactions[key] = transaction;
          }
        }
        transactions = uniqueTransactions.values.toList();
        // Trier par date (plus récents en premier)
        transactions.sort((a, b) => b.dateEnregistrement.compareTo(a.dateEnregistrement));

        if (transactions.isEmpty) {
          return const Center(child: Text('Aucune transaction servie'));
        }

        return Column(
          children: [
            // Bouton pour afficher/masquer les filtres
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
                    label: Text(_showFilters ? 'Masquer filtres' : 'Afficher filtres'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF48bb78),
                    ),
                  ),
                ],
              ),
            ),
            if (_showFilters) _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(4),
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
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final isAdmin = authService.currentUser?.role == 'ADMIN';
    
    return FutureBuilder<List<dynamic>>(
      key: _retraitsTabKey,
      future: Future.wait([
        LocalDB.instance.getAllRetraitsVirtuels(
          shopSourceId: shopId,
        ),
        LocalDB.instance.getAllOperations(), // Charger toutes les opérations
      ]),
      builder: (BuildContext context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Erreur: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
          );
        }

        final retraits = (snapshot.data?[0] as List<RetraitVirtuelModel>?) ?? [];
        var allOperations = (snapshot.data?[1] as List<OperationModel>?) ?? [];
        
        // Filtrer pour obtenir uniquement les FLOTs (type = flotShopToShop)
        // et seulement ceux REÇUS par ce shop (Paiement des retraits)
        var flots = allOperations.where((op) => 
          op.type == OperationType.flotShopToShop
        ).toList();
        
        // Filtrer les FLOTs: seulement ceux REÇUS par ce shop (Paiement des retraits)
        // Logique: On fait un retrait → On reçoit un FLOT en paiement
        if (shopId != null) {
          flots = flots.where((f) => f.shopDestinationId == shopId).toList();
        }
        
        // Créer une liste de mouvements combinés avec type et date
        final List<Map<String, dynamic>> mouvements = [];
        
        // Ajouter les retraits
        for (var retrait in retraits) {
          mouvements.add({
            'type': 'retrait',
            'data': retrait,
            'date': retrait.dateRetrait,
          });
        }
        
        // Ajouter les FLOTs
        for (var flot in flots) {
          mouvements.add({
            'type': 'flot',
            'data': flot,
            'date': flot.dateOp, // OperationModel utilise dateOp
          });
        }
        
        // Trier par date (plus récents en premier)
        mouvements.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

        if (mouvements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swap_horiz, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Aucun mouvement',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Les Flots virtuels et FLOTs apparaîtront ici',
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(4),
          itemCount: mouvements.length + 1, // +1 pour le header
          itemBuilder: (context, index) {
            // Premier item = Header statistiques
            if (index == 0) {
              return Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF48bb78), Color(0xFF38a169)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatChip(
                      icon: Icons.remove_circle,
                      label: 'Retraits',
                      count: retraits.length,
                      color: Colors.white,
                    ),
                    Container(width: 1, height: 30, color: Colors.white38),
                    _buildStatChip(
                      icon: Icons.send,
                      label: 'FLOTs',
                      count: flots.length,
                      color: Colors.white,
                    ),
                    Container(width: 1, height: 30, color: Colors.white38),
                    _buildStatChip(
                      icon: Icons.list,
                      label: 'Total',
                      count: mouvements.length,
                      color: Colors.white,
                    ),
                  ],
                ),
              );
            }
            
            // Items suivants = mouvements
            final mouvement = mouvements[index - 1];
            if (mouvement['type'] == 'retrait') {
              return _buildRetraitCard(mouvement['data'] as RetraitVirtuelModel);
            } else {
              return _buildFlotOperationCard(mouvement['data'] as OperationModel, shopId);
            }
          },
        );
      },
    );
  }
  
  Widget _buildStatChip({
    required IconData icon,
    required String label,
    required int count,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: color.withOpacity(0.9),
            fontSize: 11,
          ),
        ),
      ],
    );
  }
  
  /// Card pour afficher un FLOT (OperationModel avec type flotShopToShop)
  Widget _buildFlotOperationCard(OperationModel flot, int? currentShopId) {
    final shopService = Provider.of<ShopService>(context, listen: false);
    
    // Helper pour résoudre le nom du shop
    String getShopDesignation(int shopId, String? designation) {
      if (designation != null && designation.isNotEmpty) return designation;
      try {
        final shop = shopService.shops.firstWhere((s) => s.id == shopId);
        return shop.designation;
      } catch (e) {
        return 'Shop #$shopId';
      }
    }
    
    // Déterminer direction
    final bool isSource = flot.shopSourceId == currentShopId;
    final bool isDestination = flot.shopDestinationId == currentShopId;
    final bool isServi = flot.statut == OperationStatus.validee || flot.statut == OperationStatus.terminee;
    final bool isEnRoute = flot.statut == OperationStatus.enAttente;
    
    final Color statusColor = isServi ? Colors.green : isEnRoute ? Colors.orange : Colors.grey;
    
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
                        ? 'FLOT ENVOYÉ à ${getShopDesignation(flot.shopDestinationId ?? 0, flot.shopDestinationDesignation)}'
                        : 'FLOT REÇU de ${getShopDesignation(flot.shopSourceId ?? 0, flot.shopSourceDesignation)}',
                      style: TextStyle(
                        fontSize: 13, 
                        fontWeight: FontWeight.bold,
                        color: isSource ? Colors.red : Colors.green,
                      ),
                    ),
                    Text(
                      'Code: ${flot.codeOps}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${flot.montantNet.toStringAsFixed(2)}',
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
                      isServi ? 'Servi' : isEnRoute ? 'En route' : 'Annulé',
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
                'Envoyé: ${DateFormat('dd/MM/yyyy HH:mm').format(flot.dateOp)}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
              if (isServi && flot.dateValidation != null) ...[
                const SizedBox(width: 12),
                Icon(Icons.check, size: 12, color: Colors.green[700]),
                const SizedBox(width: 4),
                Text(
                  'Reçu: ${DateFormat('dd/MM/yyyy HH:mm').format(flot.dateValidation!)}',
                  style: TextStyle(fontSize: 11, color: Colors.green[700]),
                ),
              ],
            ],
          ),
          if (flot.destinataire != null && flot.destinataire!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              flot.destinataire!,
              style: TextStyle(fontSize: 11, color: Colors.grey[700], fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
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
        
        // Supprimer les doublons par référence (garder la plus récente)
        final Map<String, VirtualTransactionModel> uniqueTransactions = {};
        for (var transaction in transactions) {
          final key = transaction.reference;
          if (!uniqueTransactions.containsKey(key) || 
              transaction.dateEnregistrement.isAfter(uniqueTransactions[key]!.dateEnregistrement)) {
            uniqueTransactions[key] = transaction;
          }
        }
        transactions = uniqueTransactions.values.toList();
        // Trier par date (plus récents en premier)
        transactions.sort((a, b) => b.dateEnregistrement.compareTo(a.dateEnregistrement));

        return Column(
          children: [
            // Bouton pour afficher/masquer les filtres
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showFilters = !_showFilters;
                      });
                    },
                    icon: Icon(_showFilters ? Icons.filter_alt_off : Icons.filter_alt),
                    label: Text(_showFilters ? 'Masquer filtres' : 'Afficher filtres'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF48bb78),
                    ),
                  ),
                ],
              ),
            ),
            if (_showFilters) _buildFilters(),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(4),
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
      padding: const EdgeInsets.all(7),
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

  /// Filtre de date unique pour Vue d'Ensemble
  Widget _buildSingleDateFilter() {
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
              const Icon(Icons.calendar_today, size: 20, color: Color(0xFF48bb78)),
              const SizedBox(width: 8),
              const Text(
                'Sélectionner une date',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              if (_selectedDate != null)
                TextButton.icon(
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Effacer', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    setState(() {
                      _selectedDate = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event, size: 20),
                  label: Text(
                    _selectedDate != null
                        ? DateFormat('dd/MM/yyyy').format(_selectedDate!)
                        : 'Toutes les dates',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _selectedDate != null ? const Color(0xFF48bb78).withOpacity(0.1) : Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    side: BorderSide(
                      color: _selectedDate != null ? const Color(0xFF48bb78) : Colors.grey.shade400,
                      width: 2,
                    ),
                  ),
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate ?? DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() {
                        _selectedDate = DateTime(date.year, date.month, date.day);
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Onglet Dépôt
  Widget _buildDepotTab() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    return FutureBuilder<List<DepotClientModel>>(
      future: LocalDB.instance.getAllDepotsClients(shopId: shopId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Appliquer les filtres
        final allDepots = snapshot.data ?? [];
        var filteredDepots = allDepots;
        
        // Filtrer par numéro de téléphone
        if (_depotSearchQuery.isNotEmpty) {
          filteredDepots = filteredDepots.where((d) => 
            d.telephoneClient.contains(_depotSearchQuery)
          ).toList();
        }
        
        return Column(
          children: [
            // Bouton pour afficher/masquer les filtres + Bouton Nouveau Dépôt
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
              child: Row(
                children: [
                  // ✨ Bouton Nouveau Dépôt (moderne et joli)
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _creerDepot(),
                      icon: const Icon(Icons.add_circle_outline, size: 22),
                      label: const Text(
                        'Nouveau Dépôt',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF48bb78),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        elevation: 2,
                        shadowColor: const Color.fromARGB(255, 126, 204, 84).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Bouton filtres
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDepotFilters = !_showDepotFilters;
                      });
                    },
                    icon: Icon(
                      _showDepotFilters ? Icons.filter_alt_off : Icons.filter_alt,
                      size: 20,
                    ),
                    label: Text(
                      _showDepotFilters ? 'Masquer' : 'Filtres',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF48bb78),
                      side: const BorderSide(color: Color(0xFF48bb78), width: 1.5),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 🔍 Barre de recherche et filtres (affichables/masquables)
            if (_showDepotFilters)
              Container(
                color: Colors.grey[100],
                padding: const EdgeInsets.all(8),
                child: Column(
                  children: [
                    // Barre de recherche par numéro de téléphone
                    TextField(
                      controller: _depotSearchController,
                      decoration: InputDecoration(
                        hintText: 'Rechercher par numéro de téléphone...',
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF48bb78)),
                        suffixIcon: _depotSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  setState(() {
                                    _depotSearchController.clear();
                                    _depotSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _depotSearchQuery = value.trim();
                        });
                      },
                    ),
                  ],
                ),
              ),
            
            // Liste des dépôts
            Expanded(
              child: filteredDepots.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _depotSearchQuery.isNotEmpty ? Icons.search_off : Icons.account_balance_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _depotSearchQuery.isNotEmpty 
                                ? 'Aucun résultat pour "$_depotSearchQuery"'
                                : 'Aucun dépôt client',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _depotSearchQuery.isNotEmpty
                                ? 'Essayez une autre recherche'
                                : 'Cliquez sur "Nouveau Dépôt" pour enregistrer un dépôt',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        setState(() {}); // Recharger
                      },
                      child: ListView.builder(
                        padding: const EdgeInsets.all(4),
                        itemCount: filteredDepots.length,
                        itemBuilder: (context, index) {
                          final depot = filteredDepots[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: const Color(0xFF48bb78).withOpacity(0.1),
                                child: const Icon(
                                  Icons.account_balance,
                                  color: Color(0xFF48bb78),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Text(
                                    '\$${depot.montant.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.blue[100],
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      depot.simNumero,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.blue[900],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.phone, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        depot.telephoneClient,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                                      const SizedBox(width: 4),
                                      Text(
                                        DateFormat('dd/MM/yyyy HH:mm').format(depot.dateDepot),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.delete, color: Colors.red),
                                    onPressed: () => _confirmerSuppressionDepot(depot),
                                  ),
                                ],
                              ),
                            ),
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
  
  /// Créer un nouveau dépôt client
  Future<void> _creerDepot() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateDepotClientDialog(),
    );
    
    if (result == true) {
      setState(() {}); // Recharger l'onglet
    }
  }
  
  /// Confirmer la suppression d'un dépôt
  Future<void> _confirmerSuppressionDepot(DepotClientModel depot) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer le dépôt'),
        content: Text(
          'Voulez-vous vraiment supprimer ce dépôt de \$${depot.montant.toStringAsFixed(2)} ?\n\nAttention: Cette action ne peut pas être annulée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    
    if (confirm == true && depot.id != null) {
      try {
        await LocalDB.instance.deleteDepotClient(depot.id!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Dépôt supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          setState(() {}); // Recharger
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
    }
  }

  /// Onglet Flot - Transferts et floats reçus avec solde par shop
  Widget _buildFlotTab() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final isAdmin = authService.currentUser?.role == 'ADMIN';
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;
    
    // Déterminer quel contenu afficher selon le filtre
    Widget content;
    if (_flotTabFilter == 'vue' || _flotTabFilter == null) {
      content = _buildFlotVueEnsembleTab(shopId, isAdmin);
    } else if (_flotTabFilter == 'retraits') {
      content = _buildRetraitsTab();
    } else if (_flotTabFilter == 'flots') {
      content = _buildFlotsPhysiquesTab(shopId, isAdmin);
    } else {
      content = _buildFlotVueEnsembleTab(shopId, isAdmin);
    }
    
    return Column(
      children: [
        // Bouton Nouveau Flot Virtuel (uniquement dans Vue) + Bouton Filtres
        Container(
          color: Colors.grey[200],
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: [
              // ✨ Bouton Nouveau Flot Virtuel (seulement si Vue est sélectionné)
              if (_flotTabFilter == null || _flotTabFilter == 'vue') ...[
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _createRetraitVirtuel,
                    icon: const Icon(Icons.add_circle_outline, size: 22),
                    label: Text(
                      isMobile ? 'Flot Virtuel' : 'Nouveau Flot Virtuel',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF48bb78),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      elevation: 3,
                      shadowColor: const Color(0xFF48bb78).withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              // Bouton filtres
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _showFlotFilters = !_showFlotFilters;
                  });
                },
                icon: Icon(
                  _showFlotFilters ? Icons.filter_alt_off : Icons.filter_alt,
                  size: 20,
                ),
                label: Text(
                  _showFlotFilters ? 'Masquer' : 'Filtres',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF48bb78),
                  side: const BorderSide(color: Color(0xFF48bb78), width: 1.5),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // 🔍 Filtres (affichables/masquables)
        if (_showFlotFilters)
          Container(
            color: Colors.grey[100],
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                // Barre de recherche par code
                TextField(
                  controller: _flotSearchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par code/référence...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF48bb78)),
                    suffixIcon: _flotSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _flotSearchController.clear();
                                _flotSearchQuery = '';
                              });
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _flotSearchQuery = value.toLowerCase().trim();
                    });
                  },
                ),
                const SizedBox(height: 8),
                // Filtres par section + Date sur une seule ligne
                Row(
                  children: [
                    // Chip Vue
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Vue', style: TextStyle(fontSize: 12)),
                        selected: _flotTabFilter == null || _flotTabFilter == 'vue',
                        onSelected: (selected) {
                          setState(() {
                            _flotTabFilter = 'vue';
                          });
                        },
                        selectedColor: Colors.blue,
                        labelStyle: TextStyle(
                          color: (_flotTabFilter == null || _flotTabFilter == 'vue') ? Colors.white : Colors.black87,
                          fontWeight: (_flotTabFilter == null || _flotTabFilter == 'vue') ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chip Retraits
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('Retraits', style: TextStyle(fontSize: 12)),
                        selected: _flotTabFilter == 'retraits',
                        onSelected: (selected) {
                          setState(() {
                            _flotTabFilter = selected ? 'retraits' : 'vue';
                          });
                        },
                        selectedColor: Colors.orange,
                        labelStyle: TextStyle(
                          color: _flotTabFilter == 'retraits' ? Colors.white : Colors.black87,
                          fontWeight: _flotTabFilter == 'retraits' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Chip FLOTs
                    Expanded(
                      child: ChoiceChip(
                        label: const Text('FLOTs', style: TextStyle(fontSize: 12)),
                        selected: _flotTabFilter == 'flots',
                        onSelected: (selected) {
                          setState(() {
                            _flotTabFilter = selected ? 'flots' : 'vue';
                          });
                        },
                        selectedColor: Colors.purple,
                        labelStyle: TextStyle(
                          color: _flotTabFilter == 'flots' ? Colors.white : Colors.black87,
                          fontWeight: _flotTabFilter == 'flots' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Sélecteur de date
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _flotDateFilter ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (date != null) {
                            setState(() {
                              _flotDateFilter = date;
                            });
                          }
                        },
                        icon: Icon(
                          _flotDateFilter != null ? Icons.event_available : Icons.event,
                          size: 18,
                        ),
                        label: Text(
                          _flotDateFilter != null
                              ? DateFormat('dd/MM/yy').format(_flotDateFilter!)
                              : 'Date',
                          style: const TextStyle(fontSize: 12),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _flotDateFilter != null ? const Color(0xFF48bb78) : Colors.grey[700],
                          side: BorderSide(
                            color: _flotDateFilter != null ? const Color(0xFF48bb78) : Colors.grey[400]!,
                            width: 1.5,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    if (_flotDateFilter != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          setState(() {
                            _flotDateFilter = null;
                          });
                        },
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        // Contenu filtré
        Expanded(
          child: content,
        ),
      ],
    );
  }
  
  /// Vue d'ensemble avec soldes par shop
  Widget _buildFlotVueEnsembleTab(int? shopId, bool isAdmin) {
    
    return FutureBuilder<List<RetraitVirtuelModel>>(
      // IMPORTANT: Charger TOUS les retraits (pas de filtre ici)
      // On a besoin de voir les retraits où on est source ET débiteur
      future: LocalDB.instance.getAllRetraitsVirtuels(),
      builder: (builderContext, retraitsSnapshot) {
        if (retraitsSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final retraits = retraitsSnapshot.data ?? [];
        
        return FutureBuilder<List<OperationModel>>(
          future: LocalDB.instance.getAllOperations(),
          builder: (builderContext2, operationsSnapshot) {
            final allOperations = operationsSnapshot.data ?? [];
            
            // Filtrer pour obtenir uniquement les FLOTs (type = flotShopToShop)
            var flots = allOperations.where((op) => 
              op.type == OperationType.flotShopToShop
            ).toList();
            
            // Filtrer les FLOTs pertinents pour ce shop
            if (shopId != null) {
              flots = flots.where((f) => 
                f.shopSourceId == shopId || f.shopDestinationId == shopId
              ).toList();
            }
            
            return _buildFlotContent(retraits, flots, shopId, isAdmin);
          },
        );
      },
    );
  }
  
  Widget _buildFlotContent(
    List<RetraitVirtuelModel> retraits,
    List<OperationModel> flots, // Changé de FlotModel à OperationModel
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
        if (flot.shopDestinationId == shopId && (flot.statut == OperationStatus.validee || flot.statut == OperationStatus.terminee)) {
          final autreShopId = flot.shopSourceId ?? 0;
          
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
          soldesParShop[autreShopId]!['totalFlotsPhysiques'] += flot.montantNet;
          soldesParShop[autreShopId]!['flotsRecus'] += 1;
        }
        
        // CAS 2: On a ENVOYÉ un FLOT (on est source) → On leur a donné du cash
        if (flot.shopSourceId == shopId && (flot.statut == OperationStatus.validee || flot.statut == OperationStatus.terminee)) {
          final autreShopId = flot.shopDestinationId ?? 0;
          
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
          soldesParShop[autreShopId]!['flotsEnvoyes'] += flot.montantNet;
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
        f.dateOp.isAfter(_dateDebutFilter!)
      ).toList();
    }
    if (_dateFinFilter != null) {
      flotsFiltres = flotsFiltres.where((f) => 
        f.dateOp.isBefore(_dateFinFilter!)
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
                      // Séparer les soldes en deux catégories
                      const Text(
                        '💰 Soldes par Shop',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Section: Ils nous doivent (solde > 0)
                      ...() {
                        final ilsDoivent = soldesParShopList.where((s) => (s['solde'] as double) > 0).toList();
                        if (ilsDoivent.isEmpty) return <Widget>[];
                        
                        return [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.arrow_downward, color: Colors.orange, size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Ils nous doivent',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.orange),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${ilsDoivent.length} shop(s)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...ilsDoivent.map((shopData) => _buildShopBalanceCard(shopData)),
                          const SizedBox(height: 24),
                        ];
                      }(),
                      
                      // Section: Nous leur devons (solde < 0)
                      ...() {
                        final nousDevons = soldesParShopList.where((s) => (s['solde'] as double) < 0).toList();
                        if (nousDevons.isEmpty) return <Widget>[];
                        
                        return [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.arrow_upward, color: Colors.red, size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Nous leur devons',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.red),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${nousDevons.length} shop(s)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...nousDevons.map((shopData) => _buildShopBalanceCard(shopData)),
                          const SizedBox(height: 24),
                        ];
                      }(),
                      
                      // Section: Équilibrés (solde == 0)
                      ...() {
                        final equilibres = soldesParShopList.where((s) => (s['solde'] as double) == 0).toList();
                        if (equilibres.isEmpty) return <Widget>[];
                        
                        return [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Icon(Icons.check_circle, color: Colors.green, size: 18),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Comptes équilibrés',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.green),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${equilibres.length} shop(s)',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...equilibres.map((shopData) => _buildShopBalanceCard(shopData)),
                        ];
                      }(),
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
                        '📋 Historique des Flots Virtuels',
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
                      ...flotsFiltres.map((flot) => _buildFlotOperationCard(flot, shopId)),
                    ],
                  ),
                ),
              
              const SizedBox(height: 80),
            ],
          ),
        );
  }
  
  /// Onglet FLOTs Physiques uniquement - Affiche le widget de gestion complet
  Widget _buildFlotsPhysiquesTab(int? shopId, bool isAdmin) {
    return const FlotManagementWidget();
  }
  
  Widget _buildShopBalanceCard(Map<String, dynamic> shopData) {
    final solde = shopData['solde'] as double;
    final totalRetraits = shopData['totalRetraits'] as double;
    final totalFlotRecu = shopData['totalFlotRecu'] as double;
    final totalFlotsPhysiques = shopData['totalFlotsPhysiques'] as double;
    final flotsEnvoyes = shopData['flotsEnvoyes'] ?? 0.0;
    final retraitsEnAttente = shopData['retraitsEnAttente'] as int;
    final retraitsRembourses = shopData['retraitsRembourses'] as int;
    final flotsRecus = shopData['flotsRecus'] as int;
    final flotsEnvoyesCount = shopData['flotsEnvoyesCount'] ?? 0;
    final shopName = shopData['shopName'] as String;
    
    final size = MediaQuery.of(context).size;
    final isMobile = size.width < 600;
    final isTablet = size.width >= 600 && size.width < 900;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
          padding: EdgeInsets.all(isMobile ? 10 : 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isMobile ? 8 : 12),
            border: Border.all(
              color: solde > 0 
                ? Colors.orange.withOpacity(0.4)
                : solde < 0 
                  ? Colors.red.withOpacity(0.4) 
                  : Colors.green.withOpacity(0.4),
              width: isMobile ? 1.5 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (solde > 0 ? Colors.orange : solde < 0 ? Colors.red : Colors.green).withOpacity(0.08),
                blurRadius: isMobile ? 6 : 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header avec nom du shop et solde
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isMobile ? 5 : 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: solde > 0 
                          ? [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.1)]
                          : solde < 0
                            ? [Colors.red.withOpacity(0.2), Colors.red.withOpacity(0.1)]
                            : [Colors.green.withOpacity(0.2), Colors.green.withOpacity(0.1)],
                      ),
                      borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                    ),
                    child: Icon(
                      solde > 0 ? Icons.trending_up : solde < 0 ? Icons.trending_down : Icons.check_circle_outline,
                      color: solde > 0 ? Colors.orange[700] : solde < 0 ? Colors.red[700] : Colors.green[700],
                      size: isMobile ? 16 : 20,
                    ),
                  ),
                  SizedBox(width: isMobile ? 8 : 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shopName,
                          style: TextStyle(
                            fontSize: isMobile ? 13 : 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[900],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!isMobile || isTablet)
                          Text(
                            '${retraitsEnAttente + retraitsRembourses} retrait(s) • ${flotsRecus + flotsEnvoyesCount} FLOT(s)',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 6 : 8,
                          vertical: isMobile ? 2 : 3,
                        ),
                        decoration: BoxDecoration(
                          color: (solde > 0 ? Colors.orange : solde < 0 ? Colors.red : Colors.green).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(isMobile ? 8 : 10),
                        ),
                        child: Text(
                          solde > 0 ? 'À recevoir' : solde < 0 ? 'À payer' : 'OK',
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 9,
                            color: solde > 0 ? Colors.orange[800] : solde < 0 ? Colors.red[800] : Colors.green[800],
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      SizedBox(height: isMobile ? 2 : 4),
                      Text(
                        '\$${solde.abs().toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: isMobile ? 17 : 20,
                          fontWeight: FontWeight.w900,
                          color: solde > 0 ? Colors.orange[700] : solde < 0 ? Colors.red[700] : Colors.green[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              SizedBox(height: isMobile ? 8 : 12),
              
              // Stats grid
              Row(
                children: [
                  Expanded(
                    child: _buildShopStat('Retraits', totalRetraits, Colors.orange, isMobile),
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                  Expanded(
                    child: _buildShopStat('Reçu', totalFlotsPhysiques, Colors.green, isMobile),
                  ),
                ],
              ),
              SizedBox(height: isMobile ? 4 : 6),
              Row(
                children: [
                  Expanded(
                    child: _buildShopStat('Envoyé', flotsEnvoyes, Colors.red, isMobile),
                  ),
                  SizedBox(width: isMobile ? 4 : 6),
                  Expanded(
                    child: Container(
                      padding: EdgeInsets.all(isMobile ? 6 : 8),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.swap_vert, size: isMobile ? 10 : 12, color: Colors.grey[700]),
                              SizedBox(width: isMobile ? 2 : 4),
                              Text(
                                'Balance',
                                style: TextStyle(
                                  fontSize: isMobile ? 8 : 9,
                                  color: Colors.grey[700],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isMobile ? 2 : 3),
                          Text(
                            '${flotsRecus}↓ ${flotsEnvoyesCount}↑',
                            style: TextStyle(
                              fontSize: isMobile ? 11 : 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey[900],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              // Status row - masqué sur mobile
              if (!isMobile) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.orange[200]!, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.pending, size: 12, color: Colors.orange[700]),
                            const SizedBox(width: 4),
                            Text(
                              '$retraitsEnAttente',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green[200]!, width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, size: 12, color: Colors.green[700]),
                            const SizedBox(width: 4),
                            Text(
                              '$retraitsRembourses',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildShopStat(String label, double value, Color color, bool isMobile) {
    return Container(
      padding: EdgeInsets.all(isMobile ? 6 : 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isMobile ? 6 : 8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isMobile ? 8 : 9,
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: isMobile ? 2 : 3),
          Text(
            '\$${value.toStringAsFixed(isMobile ? 0 : 2)}',
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w900,
              color: color,
            ),
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

  /// Récupérer le solde FRAIS antérieur de la clôture du jour précédent
  /// Utilise la MÊME logique que rapport_cloture_service.dart
  Future<double> _getSoldeFraisAnterieur(int? shopId) async {
    if (shopId == null) return 0.0;
    
    try {
      // Obtenir la date d'aujourd'hui
      final aujourdhui = DateTime.now();
      // Jour précédent
      final jourPrecedent = aujourdhui.subtract(const Duration(days: 1));
      
      // Récupérer la clôture caisse du jour précédent
      final cloturePrecedente = await LocalDB.instance.getClotureCaisseByDate(shopId, jourPrecedent);
      
      if (cloturePrecedente != null) {
        // Retourner le solde FRAIS enregistré dans la clôture
        debugPrint('📋 Solde FRAIS antérieur trouvé (clôture du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   SOLDE FRAIS: ${cloturePrecedente.soldeFraisAnterieur} USD');
        return cloturePrecedente.soldeFraisAnterieur;
      }
      
      // Si aucune clôture précédente, retourner 0
      debugPrint('ℹ️ Aucun solde FRAIS antérieur (pas de clôture caisse du jour précédent)');
      return 0.0;
    } catch (e) {
      debugPrint('❌ Erreur récupération solde FRAIS antérieur: $e');
      return 0.0;
    }
  }

  /// Récupérer les sorties FRAIS (retraits du compte FRAIS) pour la date sélectionnée
  Future<double> _getSortieFrais(int? shopId, DateTime? selectedDate) async {
    if (shopId == null) return 0.0;
    
    try {
      // Charger toutes les transactions de comptes spéciaux
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      double sortieFrais = 0.0;
      
      for (String key in keys) {
        if (key.startsWith('compte_special_')) {
          final data = prefs.getString(key);
          if (data != null) {
            final json = jsonDecode(data) as Map<String, dynamic>;
            final type = json['type'] as String?;
            final typeTransaction = json['type_transaction'] as String?;
            final transactionShopId = json['shop_id'] as int?;
            
            // Filtrer: type FRAIS, typeTransaction RETRAIT, même shop
            if (type == 'FRAIS' && 
                typeTransaction == 'RETRAIT' && 
                transactionShopId == shopId) {
              
              // Filtrer par date si spécifiée
              if (selectedDate != null) {
                final dateTransaction = json['date_transaction'] as String?;
                if (dateTransaction != null) {
                  final transDate = DateTime.parse(dateTransaction);
                  final startOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);
                  final endOfDay = DateTime(selectedDate.year, selectedDate.month, selectedDate.day, 23, 59, 59);
                  
                  if (transDate.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                      transDate.isBefore(endOfDay.add(const Duration(seconds: 1)))) {
                    final montant = json['montant'] as num?;
                    if (montant != null) {
                      sortieFrais += montant.toDouble().abs(); // Prendre valeur absolue car montant est négatif
                    }
                  }
                }
              } else {
                // Pas de filtre de date, compter tous les retraits
                final montant = json['montant'] as num?;
                if (montant != null) {
                  sortieFrais += montant.toDouble().abs();
                }
              }
            }
          }
        }
      }
      
      debugPrint('💸 Sortie FRAIS calculée: ${sortieFrais.toStringAsFixed(2)} USD');
      return sortieFrais;
    } catch (e) {
      debugPrint('❌ Erreur récupération sortie FRAIS: $e');
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

        // Appliquer les filtres de dates (date unique pour Vue d'Ensemble)
        var filteredTransactions = transactions;
        if (_selectedDate != null) {
          // Filtrer pour la date exacte sélectionnée
          final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
          final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
          filteredTransactions = filteredTransactions
              .where((t) => 
                t.dateEnregistrement.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                t.dateEnregistrement.isBefore(endOfDay.add(const Duration(seconds: 1))))
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
            
            // Filtrer par date unique
            if (_selectedDate != null) {
              final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
              final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
              retraits = retraits.where((r) => 
                r.dateRetrait.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                r.dateRetrait.isBefore(endOfDay.add(const Duration(seconds: 1)))).toList();
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
            return FutureBuilder<List<OperationModel>>(
              future: LocalDB.instance.getAllOperations(),
              builder: (BuildContext context, operationsSnapshot) {
                // Extraire les FLOTs depuis les opérations
                var allOperations = operationsSnapshot.data ?? [];
                
                // Filtrer uniquement les opérations de type FLOT
                var flotOperations = allOperations.where((op) => 
                  op.type == OperationType.flotShopToShop
                ).toList();
                
                // Filtrer les FLOTs REÇUS (où on est destination et statut = validee OU enAttente)
                var flotsRecus = shopIdFilter != null
                  ? flotOperations.where((f) => 
                      f.shopDestinationId == shopIdFilter &&
                      (f.statut == OperationStatus.validee || f.statut == OperationStatus.enAttente)
                    ).toList()
                  : flotOperations.where((f) => f.statut == OperationStatus.validee || f.statut == OperationStatus.enAttente).toList();
                
                // Filtrer les FLOTs ENVOYÉS (où on est source et statut = validee OU enAttente)
                var flotsEnvoyes = shopIdFilter != null
                  ? flotOperations.where((f) => 
                      f.shopSourceId == shopIdFilter &&
                      (f.statut == OperationStatus.validee || f.statut == OperationStatus.enAttente)
                    ).toList()
                  : flotOperations.where((f) => f.statut == OperationStatus.validee || f.statut == OperationStatus.enAttente).toList();
                
                // Appliquer les filtres de date sur FLOTs REÇUS
                if (_selectedDate != null) {
                  final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                  final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
                  flotsRecus = flotsRecus.where((f) {
                    // Utiliser UNIQUEMENT created_at pour le filtrage
                    if (f.createdAt == null) return false; // Exclure si pas de created_at
                    final dateToCheck = f.createdAt!;
                    return dateToCheck.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                           dateToCheck.isBefore(endOfDay.add(const Duration(seconds: 1)));
                  }).toList();
                }
                
                // Appliquer les filtres de date sur FLOTs ENVOYÉS
                if (_selectedDate != null) {
                  final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day);
                  final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
                  flotsEnvoyes = flotsEnvoyes.where((f) {
                    // Utiliser UNIQUEMENT created_at pour le filtrage
                    if (f.createdAt == null) return false; // Exclure si pas de created_at
                    final dateToCheck = f.createdAt!;
                    return dateToCheck.isAfter(startOfDay.subtract(const Duration(seconds: 1))) &&
                           dateToCheck.isBefore(endOfDay.add(const Duration(seconds: 1)));
                  }).toList();
                }
                
                final flotsRecusPhysiques = flotsRecus.fold<double>(0.0, (sum, f) => sum + f.montantNet);
                final flotsEnvoyesPhysiques = flotsEnvoyes.fold<double>(0.0, (sum, f) => sum + f.montantNet);
                final flotsRecusListe = flotsRecus; // Garder la liste pour les détails
                final flotsEnvoyesListe = flotsEnvoyes; // Garder la liste pour les détails
                
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
                          // Filtre de date unique
                          _buildSingleDateFilter(),
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
                            if (_selectedDate != null)
                              Text(
                                'Date: ${DateFormat('dd/MM/yyyy').format(_selectedDate!)}',
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
                      if (_selectedDate != null)
                        Text(
                          DateFormat('dd/MM/yyyy').format(_selectedDate!),
                          style: const TextStyle(color: Color(0xFF48bb78), fontSize: 14, fontWeight: FontWeight.bold),
                        )
                      else
                        Text(
                          DateFormat('dd/MM/yyyy').format(DateTime.now()),
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                            ],
                          ),
const SizedBox(height: 16),

                          // SECTION CASH DISPONIBLE
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
                                    padding: const EdgeInsets.all(4),
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
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [Colors.blue, Color(0xFF1976D2)],
                                            ),
                                          ),
                                          child: const Icon(Icons.account_balance_wallet, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'CASH DISPONIBLE',
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
                                        _buildFinanceRow('Solde Antérieur', capitalInitialCash, Colors.grey),
                                        const SizedBox(height: 8),
                                        _buildFinanceRow('+ FLOTs reçus', flotsRecus, Colors.green),
                                        // Détails FLOTs reçus
                                        if (flotsRecusListe.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: flotsRecusListe.map((flot) => 
                                                Text(
                                                  '• ${flot.shopSourceDesignation ?? "Shop #${flot.shopSourceId}"}: \$${flot.montantNet.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 11, 
                                                    color: flot.statut == OperationStatus.validee ? Colors.green[700] : Colors.orange[700],
                                                  ),
                                                )
                                              ).toList(),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        _buildFinanceRow('- FLOTs envoyés', flotsEnvoyes, Colors.red),
                                        // Détails FLOTs envoyés
                                        if (flotsEnvoyesListe.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: flotsEnvoyesListe.map((flot) => 
                                                Text(
                                                  '• Vers ${flot.shopDestinationDesignation ?? "Shop #${flot.shopDestinationId}"}: \$${flot.montantNet.toStringAsFixed(2)} (${flot.statut == OperationStatus.validee ? "Validé" : "En attente"})',
                                                  style: TextStyle(
                                                    fontSize: 11, 
                                                    color: flot.statut == OperationStatus.validee ? Colors.orange[700] : Colors.orange[900],
                                                  ),
                                                )
                                              ).toList(),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        _buildFinanceRow('- Cash servi', cashServiValue, Colors.red),
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
                                        const Divider(),
                                        _buildFinanceRow('= Cash Disponible', cashDisponible, Colors.blue, isBold: true),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // SECTION VIRTUEL DISPONIBLE
                          FutureBuilder<double>(
                            future: _getSoldeAnterieurVirtuel(shopIdFilter),
                            builder: (context, virtuelSnapshot) {
                              final soldeAnterieurVirtuel = virtuelSnapshot.data ?? 0.0;
                              final capturesDuJour = montantTotalCaptures; // Captures SANS Frais
                              final retraitsDuJour = montantTotalRetraits; // Retraits (Toutes SIMs)
                              final virtuelDisponible = soldeAnterieurVirtuel + capturesDuJour - retraitsDuJour;
                              
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
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(24),
                                  child: Column(
                                    children: [
                                      // HEADER - VIRTUEL DISPONIBLE
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.purple.withOpacity(0.1),
                                              Colors.purple.withOpacity(0.05),
                                            ],
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 30,
                                              height: 30,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [Colors.purple, Color(0xFF7B1FA2)],
                                                ),
                                              ),
                                              child: const Icon(Icons.cloud_upload, color: Colors.white, size: 24),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'VIRTUEL DISPONIBLE',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // BODY - DETAILS VIRTUEL
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            _buildFinanceRow('Solde Antérieur', soldeAnterieurVirtuel, Colors.grey),
                                            const SizedBox(height: 8),
                                            _buildFinanceRow('+ Captures du jour', capturesDuJour, Colors.green),
                                            // Détails Captures par SIM
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
                                            const SizedBox(height: 8),
                                            _buildFinanceRow('- Flot Virtuel', retraitsDuJour, Colors.red),
                                            // Détails Flots Virtuels (Retraits)
                                            if (retraits.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 16, top: 4),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    ...retraits.map((retrait) => 
                                                      Padding(
                                                        padding: const EdgeInsets.only(bottom: 2, left: 8),
                                                        child: Text(
                                                          '• ${retrait.simNumero}: \$${retrait.montant.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: 11, 
                                                            color: retrait.statut == RetraitVirtuelStatus.enAttente 
                                                              ? Colors.orange[700] 
                                                              : retrait.statut == RetraitVirtuelStatus.rembourse 
                                                                ? Colors.red[700] 
                                                                : Colors.purple[700],
                                                          ),
                                                        ),
                                                      )
                                                    ).toList(),
                                                  ],
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            const Divider(),
                                            _buildFinanceRow('= Virtuel Disponible', virtuelDisponible, Colors.purple, isBold: true),
                                            const SizedBox(height: 16),
                                            // LISTE DES NON SERVIS PAR SIM
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
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 16),
                          
                          // SECTION FRAIS (comme rapportcloture.dart)
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
                                  // HEADER - COMPTE FRAIS
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.green.withOpacity(0.1),
                                          Colors.green.withOpacity(0.05),
                                        ],
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 30,
                                          height: 30,
                                          decoration: const BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: LinearGradient(
                                              colors: [Colors.green, Color(0xFF48bb78)],
                                            ),
                                          ),
                                          child: const Icon(Icons.attach_money, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'Compte FRAIS',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // BODY - DETAILS FRAIS
                                  FutureBuilder<double>(
                                    future: _getSoldeFraisAnterieur(shopIdFilter),
                                    builder: (context, fraisAntSnapshot) {
                                      final fraisAnterieur = fraisAntSnapshot.data ?? 0.0;
                                      
                                      return FutureBuilder<double>(
                                        future: _getSortieFrais(shopIdFilter, _selectedDate),
                                        builder: (context, sortieFraisSnapshot) {
                                          final sortieFrais = sortieFraisSnapshot.data ?? 0.0;
                                          final soldeFraisTotal = fraisAnterieur + fraisPercus - sortieFrais;
                                          
                                          return Column(
                                            children: [
                                              // FRAIS Details Display
                                              Padding(
                                                padding: const EdgeInsets.all(20),
                                                child: Column(
                                                  children: [
                                                    _buildFinanceRow('Frais Antérieur', fraisAnterieur, Colors.grey),
                                                    const SizedBox(height: 8),
                                                    _buildFinanceRow('+ Frais du jour', fraisPercus, Colors.green),
                                                    const SizedBox(height: 4),
                                                    _buildFinanceRow('- Sortie Frais', sortieFrais, Colors.red),
                                                    const SizedBox(height: 4),
                                                    const Divider(),
                                                    _buildFinanceRow('= Solde FRAIS total', soldeFraisTotal, Colors.green, isBold: true),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // CARD CAPITAL NET
                          // Calculer les FRAIS puis le Virtuel Disponible et le Capital Net
                          FutureBuilder<double>(
                            future: _getSoldeFraisAnterieur(shopIdFilter),
                            builder: (context, fraisAntSnapshot) {
                              final fraisAnterieur = fraisAntSnapshot.data ?? 0.0;
                              
                              return FutureBuilder<double>(
                                future: _getSortieFrais(shopIdFilter, _selectedDate),
                                builder: (context, sortieFraisSnapshot) {
                                  final sortieFrais = sortieFraisSnapshot.data ?? 0.0;
                                  final soldeFraisTotal = fraisAnterieur + fraisPercus - sortieFrais;
                                  
                                  return FutureBuilder<double>(
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
                                          
                                          // CAPITAL NET = Cash Disponible + Virtuel Disponible + Shops nous doivent - Shops nous devons - Solde FRAIS
                                          final capitalNet = cashDisponible + virtuelDisponible + shopsNousDoivent - shopsNousDevons - soldeFraisTotal;
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
                                                      fontSize: 20,
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
                                                _buildFinanceRow('Cash Disponible', cashDisponible, Colors.blue),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('+ Virtuel Disponible', virtuelDisponible, Colors.blue),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('+ DIFF. DETTES', shopsNousDoivent, Colors.green),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('- Shops que nous devons', shopsNousDevons, Colors.red),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('- Solde FRAIS', soldeFraisTotal, Colors.red),
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
                                  );
                                },
                              );
                            },
                          ),
                          const SizedBox(height: 16),

                          // Statistiques par opérateur
                          const Card(
                            elevation: 3,
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Column(
// ... existing code ...
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // NOUVELLE SECTION: Shops qui nous doivent
                          FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
                            future: _getShopBalancesDetails(shopIdFilter),
                            builder: (context, shopBalancesSnapshot) {
                              if (!shopBalancesSnapshot.hasData) {
                                return const SizedBox.shrink();
                              }
                              
                              final shopBalances = shopBalancesSnapshot.data!;
                              final shopsNousDoivent = shopBalances['shopsNousDoivent'] ?? [];
                              final shopsNousDevons = shopBalances['shopsNousDevons'] ?? [];
                              
                              return Column(
                                children: [
                                  // Shops qui nous doivent (Créances)
                                  if (shopsNousDoivent.isNotEmpty) ...[
                                    Card(
                                      elevation: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.store, color: Colors.orange.shade700),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Shops Qui Nous Doivent',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${shopsNousDoivent.length} shop(s)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Divider(height: 24),
                                            ...shopsNousDoivent.map((shop) => 
                                              Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.orange.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.orange.shade200),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            shop['designation'],
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          Text(
                                                            shop['localisation'],
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      '\$${shop['montant'].toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.orange.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ).toList(),
                                            const Divider(),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'TOTAL',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${shopsNousDoivent.fold<double>(0.0, (sum, shop) => sum + shop['montant']).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.orange.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],
                                  
                                  // Shops que nous devons (Dettes)
                                  if (shopsNousDevons.isNotEmpty) ...[
                                    Card(
                                      elevation: 3,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Icon(Icons.store, color: Colors.purple.shade700),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Shops Que Nous Devons',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${shopsNousDevons.length} shop(s)',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                            const Divider(height: 24),
                                            ...shopsNousDevons.map((shop) => 
                                              Container(
                                                margin: const EdgeInsets.only(bottom: 8),
                                                padding: const EdgeInsets.all(12),
                                                decoration: BoxDecoration(
                                                  color: Colors.purple.shade50,
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(color: Colors.purple.shade200),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            shop['designation'],
                                                            style: const TextStyle(
                                                              fontSize: 14,
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                          Text(
                                                            shop['localisation'],
                                                            style: TextStyle(
                                                              fontSize: 11,
                                                              color: Colors.grey[600],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                    Text(
                                                      '\$${shop['montant'].toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.purple.shade700,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ).toList(),
                                            const Divider(),
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                const Text(
                                                  'TOTAL',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  '\$${shopsNousDevons.fold<double>(0.0, (sum, shop) => sum + shop['montant']).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.purple.shade700,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              );
                            },
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
                        padding: const EdgeInsets.all(7),
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
      // Récupérer tous les retraits et opérations (pour les FLOTs)
      final retraits = await LocalDB.instance.getAllRetraitsVirtuels();
      final allOperations = await LocalDB.instance.getAllOperations();
      
      // Filtrer les opérations de type FLOT (nouvelle méthode)
      final flotOperations = allOperations.where((op) => 
        op.type == OperationType.flotShopToShop
      ).toList();
      
      // Filtrer pour notre shop
      final retraitsFiltres = retraits.where((r) => 
        r.shopSourceId == shopId || r.shopDebiteurId == shopId
      ).toList();
      
      final flots = flotOperations.where((f) => 
        f.shopSourceId == shopId || f.shopDestinationId == shopId
      ).toList();
      
      double shopsNousDoivent = 0.0;
      double shopsNousDevons = 0.0;
      
      // Calculer par shop
      final Map<int, double> soldesParShop = {};
      
      // Retraits virtuels
      for (final retrait in retraitsFiltres) {
        if (retrait.shopSourceId == shopId) {
          // On est créancier (on a fait un retrait virtuel pour un autre shop)
          final autreShopId = retrait.shopDebiteurId;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + retrait.montant;
        } else {
          // On est débiteur (un autre shop a fait un retrait pour nous)
          final autreShopId = retrait.shopSourceId;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - retrait.montant;
        }
      }
      
      // FLOTs (nouvelle méthode avec OperationModel)
      for (final flot in flots) {
        // Vérifier si le FLOT est validé ou en attente
        if (flot.statut == OperationStatus.validee || flot.statut == OperationStatus.enAttente) {
          if (flot.shopSourceId == shopId) {
            // On a envoyé un FLOT → L'autre shop nous doit
            final autreShopId = flot.shopDestinationId;
            if (autreShopId != null && autreShopId != shopId) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
            }
          } else if (flot.shopDestinationId == shopId) {
            // On a reçu un FLOT → On doit à l'autre shop
            final autreShopId = flot.shopSourceId;
            if (autreShopId != null && autreShopId != shopId) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
            }
          }
        }
      }
      
      // Séparer positifs (créances) et négatifs (dettes)
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

  /// Obtenir les détails des shops (qui nous doivent et que nous devons)
  Future<Map<String, List<Map<String, dynamic>>>> _getShopBalancesDetails(int? shopId) async {
    if (shopId == null) {
      return {
        'shopsNousDoivent': [],
        'shopsNousDevons': [],
      };
    }
    
    try {
      // Récupérer tous les retraits et opérations (pour les FLOTs)
      final retraits = await LocalDB.instance.getAllRetraitsVirtuels();
      final allOperations = await LocalDB.instance.getAllOperations();
      final allShops = await LocalDB.instance.getAllShops();
      
      // Créer un map des shops pour accès rapide
      final shopsMap = {for (var shop in allShops) shop.id: shop};
      
      // Filtrer les opérations de type FLOT
      final flotOperations = allOperations.where((op) => 
        op.type == OperationType.flotShopToShop
      ).toList();
      
      // Filtrer pour notre shop
      final retraitsFiltres = retraits.where((r) => 
        r.shopSourceId == shopId || r.shopDebiteurId == shopId
      ).toList();
      
      final flots = flotOperations.where((f) => 
        f.shopSourceId == shopId || f.shopDestinationId == shopId
      ).toList();
      
      // Calculer par shop
      final Map<int, double> soldesParShop = {};
      
      // Retraits virtuels
      for (final retrait in retraitsFiltres) {
        if (retrait.shopSourceId == shopId) {
          final autreShopId = retrait.shopDebiteurId;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + retrait.montant;
        } else {
          final autreShopId = retrait.shopSourceId;
          soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - retrait.montant;
        }
      }
      
      // FLOTs
      for (final flot in flots) {
        if (flot.statut == OperationStatus.validee || flot.statut == OperationStatus.enAttente) {
          if (flot.shopSourceId == shopId) {
            final autreShopId = flot.shopDestinationId;
            if (autreShopId != null && autreShopId != shopId) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) + flot.montantNet;
            }
          } else if (flot.shopDestinationId == shopId) {
            final autreShopId = flot.shopSourceId;
            if (autreShopId != null && autreShopId != shopId) {
              soldesParShop[autreShopId] = (soldesParShop[autreShopId] ?? 0.0) - flot.montantNet;
            }
          }
        }
      }
      
      // Séparer en deux listes
      final List<Map<String, dynamic>> shopsNousDoivent = [];
      final List<Map<String, dynamic>> shopsNousDevons = [];
      
      for (final entry in soldesParShop.entries) {
        final autreShopId = entry.key;
        final solde = entry.value;
        final shop = shopsMap[autreShopId];
        
        if (shop == null) continue;
        
        if (solde > 0) {
          // Créance
          shopsNousDoivent.add({
            'shopId': autreShopId,
            'designation': shop.designation,
            'localisation': shop.localisation,
            'montant': solde,
          });
        } else if (solde < 0) {
          // Dette
          shopsNousDevons.add({
            'shopId': autreShopId,
            'designation': shop.designation,
            'localisation': shop.localisation,
            'montant': solde.abs(),
          });
        }
      }
      
      return {
        'shopsNousDoivent': shopsNousDoivent,
        'shopsNousDevons': shopsNousDevons,
      };
    } catch (e) {
      debugPrint('Erreur calcul détails shops: $e');
      return {
        'shopsNousDoivent': [],
        'shopsNousDevons': [],
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _serveClient(transaction),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green[600],
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Servir Client',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
            const Text(
              'Confirmer que vous avez REMBOURSÉ ce retrait ?',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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
                  padding: const pw.EdgeInsets.all(10),
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
                        style: const pw.TextStyle(
                          fontSize: 14,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(dateNow),
                        style: const pw.TextStyle(
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
