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
import '../services/client_service.dart'; // Add this import
import '../services/local_db.dart';
import '../services/depot_retrait_sync_service.dart';
import '../services/cloture_virtuelle_par_sim_service.dart';
import '../services/currency_service.dart';
import '../services/credit_virtuel_service.dart';
import '../models/credit_virtuel_model.dart';
import '../models/cloture_virtuelle_par_sim_model.dart';
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
import 'cloture_virtuelle_par_sim_widget.dart';
import 'modern_transaction_card.dart';
import 'pdf_viewer_dialog.dart';
import 'flot_management_widget.dart';
import 'virtual_exchange_widget.dart';
import '../utils/currency_utils.dart';


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
  DateTime? _selectedDate; // Date unique pour Vue d'Ensemble
  Key _retraitsTabKey = UniqueKey(); // Pour forcer le rechargement
  bool _showFilters = false; // Masquer les filtres par défaut
  bool _showVueEnsembleFilter = false; // Masquer le filtre Vue d'ensemble par défaut
  
  // 🔍 NOUVEAU: Filtres de recherche
  VirtualTransactionStatus? _statusFilter = VirtualTransactionStatus.enAttente; // Par défaut: En Attente
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = ''; // Pour recherche par référence ou téléphone
  String? _deviseFilter; // NOUVEAU: Filtre par devise (USD/CDF)
  
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
  
  // 🔍 NOUVEAU: Filtres pour Liste des Transactions
  bool _showListeTransactionsFilters = false;
  DateTime? _listeTransactionsDateDebut;
  DateTime? _listeTransactionsDateFin;
  double? _listeTransactionsMontantMin;
  
  // 🔍 NOUVEAU: Filtres pour Crédits Virtuels
  CreditVirtuelStatus? _creditStatusFilter; // Filtre par statut
  DateTime? _creditDateDebutFilter; // Filtre par date début
  DateTime? _creditDateFinFilter; // Filtre par date fin
  String? _creditSimFilter; // Filtre par SIM
  final TextEditingController _creditSearchController = TextEditingController();
  String _creditSearchQuery = ''; // Recherche par bénéficiaire/référence
  double? _listeTransactionsMontantMax;
  VirtualTransactionStatus? _listeTransactionsStatusFilter;
  final TextEditingController _listeTransactionsSearchController = TextEditingController();
  String _listeTransactionsSearchQuery = '';
  String? _listeTransactionsDeviseFilter;
  String? _listeTransactionsSimFilter;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this); // 6 tabs: Captures, Flots, Dépôt, Crédit, Échanges, Rapport
    // Initialiser la date à aujourd'hui pour le filtre Vue d'ensemble
    _selectedDate = DateTime.now();
    // Charger les données APRÈS le build initial pour éviter setState() during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadData();
      }
    });
    // Vérification automatique des clôtures manquantes après 2 secondes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _verifierJoursNonClotures();
        }
      });
    });
  }

  @override
  void dispose() {
    // Disposer tous les controllers avec protection
    try {
      _tabController.dispose();
    } catch (e) {
      debugPrint('⚠️ _tabController déjà disposé: $e');
    }
    
    try {
      _searchController.dispose();
    } catch (e) {
      debugPrint('⚠️ _searchController déjà disposé: $e');
    }
    
    try {
      _flotSearchController.dispose();
    } catch (e) {
      debugPrint('⚠️ _flotSearchController déjà disposé: $e');
    }
    
    try {
      _depotSearchController.dispose();
    } catch (e) {
      debugPrint('⚠️ _depotSearchController déjà disposé: $e');
    }
    
    try {
      _listeTransactionsSearchController.dispose();
    } catch (e) {
      debugPrint('⚠️ _listeTransactionsSearchController déjà disposé: $e');
    }
    
    try {
      _creditSearchController.dispose();
    } catch (e) {
      debugPrint('⚠️ _creditSearchController déjà disposé: $e');
    }
    
    super.dispose();
  }

  Future<void> _loadData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    final isAdmin = currentUser?.role == 'ADMIN';
    
    if (isAdmin) {
      // Admin: charger TOUTES les transactions (sans filtre shop)
      await VirtualTransactionService.instance.loadTransactions(
        cleanDuplicates: true, // Activer le nettoyage au premier chargement
      );
      // Charger toutes les SIMs
      await SimService.instance.loadSims();
      // Charger tous les shops pour le filtre
      await ShopService.instance.loadShops();
    } else if (currentUser?.shopId != null) {
      // Agent: charger uniquement les transactions de son shop
      await VirtualTransactionService.instance.loadTransactions(
        shopId: currentUser!.shopId,
        cleanDuplicates: true, // Activer le nettoyage au premier chargement
      );
      await SimService.instance.loadSims(shopId: currentUser.shopId);
    }
  }

  /// Vérifier et proposer de clôturer les jours précédents non clôturés
  Future<void> _verifierJoursNonClotures() async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser?.shopId == null) return;
    
    try {
      // Récupérer les SIMs du shop
      final sims = await LocalDB.instance.getAllSims(shopId: currentUser!.shopId!);
      if (sims.isEmpty) {
        debugPrint('⚠️ Aucune SIM trouvée pour le shop ${currentUser.shopId}');
        return;
      }
      
      // Déterminer la date de début de recherche
      DateTime dateDebutRecherche;
      
      // 1. Chercher la dernière clôture par SIM
      final aujourdhui = DateTime.now();
      final dateAujourdhui = DateTime(aujourdhui.year, aujourdhui.month, aujourdhui.day);
      
      // Chercher la dernière clôture (toutes SIMs confondues)
      DateTime? dateDerniereClotureGlobale;
      for (int i = 1; i <= 30; i++) {
        final date = dateAujourdhui.subtract(Duration(days: i));
        final clotures = await LocalDB.instance.getCloturesVirtuellesParDate(
          shopId: currentUser.shopId!,
          date: date,
        );
        
        if (clotures.isNotEmpty) {
          dateDerniereClotureGlobale = date;
          debugPrint('✅ Dernière clôture trouvée: ${date.day}/${date.month}/${date.year}');
          break;
        }
      }
      
      if (dateDerniereClotureGlobale != null) {
        // Si une clôture existe, chercher à partir du lendemain
        dateDebutRecherche = dateDerniereClotureGlobale.add(const Duration(days: 1));
        debugPrint('📅 Recherche à partir du lendemain de la dernière clôture: ${dateDebutRecherche.day}/${dateDebutRecherche.month}/${dateDebutRecherche.year}');
      } else {
        // Aucune clôture trouvée, chercher la date de la première capture
        debugPrint('⚠️ Aucune clôture trouvée, recherche de la première capture...');
        
        final transactions = await LocalDB.instance.getAllVirtualTransactions(
          shopId: currentUser.shopId!,
          dateDebut: dateAujourdhui.subtract(const Duration(days: 365)), // Max 1 an en arrière
          dateFin: dateAujourdhui.subtract(const Duration(days: 1)), // Jusqu'à hier
        );
        
        if (transactions.isEmpty) {
          debugPrint('ℹ️ Aucune capture trouvée, pas besoin de clôture');
          return;
        }
        
        // Trouver la date de la première capture (la plus ancienne)
        transactions.sort((a, b) => a.dateEnregistrement.compareTo(b.dateEnregistrement));
        final premiereCapture = transactions.first;
        dateDebutRecherche = DateTime(
          premiereCapture.dateEnregistrement.year,
          premiereCapture.dateEnregistrement.month,
          premiereCapture.dateEnregistrement.day,
        );
        
        debugPrint('📅 Première capture trouvée le: ${dateDebutRecherche.day}/${dateDebutRecherche.month}/${dateDebutRecherche.year}');
      }
      
      // Chercher les jours non clôturés à partir de la date de début
      final joursNonClotures = <DateTime>[];
      final dateHier = dateAujourdhui.subtract(const Duration(days: 1));
      
      // Limiter à 30 jours maximum pour éviter trop de requêtes
      DateTime dateCourante = dateDebutRecherche;
      int compteur = 0;
      
      while (dateCourante.isBefore(dateAujourdhui) && compteur < 30) {
        // Vérifier si une clôture existe pour cette date
        final clotures = await LocalDB.instance.getCloturesVirtuellesParDate(
          shopId: currentUser.shopId!,
          date: dateCourante,
        );
        
        if (clotures.isEmpty) {
          joursNonClotures.add(dateCourante);
          debugPrint('❌ Jour non clôturé: ${dateCourante.day}/${dateCourante.month}/${dateCourante.year}');
        } else {
          debugPrint('✅ Jour clôturé: ${dateCourante.day}/${dateCourante.month}/${dateCourante.day}');
        }
        
        dateCourante = dateCourante.add(const Duration(days: 1));
        compteur++;
      }
      
      // Si on trouve des jours non clôturés, proposer de les clôturer
      if (joursNonClotures.isNotEmpty && mounted) {
        // Trier par date croissante (plus ancien en premier)
        joursNonClotures.sort((a, b) => a.compareTo(b));
        
        debugPrint('📊 ${joursNonClotures.length} jour(s) non clôturé(s) trouvé(s)');
        
        // Afficher le dialogue de clôture pour les jours manquants
        await _proposerClotureMassive(joursNonClotures, sims);
      } else {
        debugPrint('✅ Toutes les journées sont clôturées');
      }
    } catch (e) {
      debugPrint('❌ Erreur vérification jours non clôturés: $e');
    }
  }

  /// Proposer de clôturer tous les jours manquants avec le même montant
  Future<void> _proposerClotureMassive(List<DateTime> joursNonClotures, List<SimModel> sims) async {
    if (!mounted) return;
    
    final dateFormatter = DateFormat('dd/MM/yyyy', 'fr_FR');
    final joursTexte = joursNonClotures.map((d) => dateFormatter.format(d)).join(', ');
    final nbJours = joursNonClotures.length;
    
    // Dialogue d'information
    final action = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade700, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Clôtures Manquantes',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nbJours == 1
                  ? 'La journée suivante n\'a pas été clôturée:'
                  : 'Les $nbJours journées suivantes n\'ont pas été clôturées:',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Text(
                joursTexte,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.orange.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              nbJours == 1
                  ? 'Voulez-vous clôturer cette journée maintenant?'
                  : nbJours <= 3
                      ? 'Voulez-vous clôturer ces journées avec les mêmes montants?'
                      : 'Voulez-vous clôturer toutes ces journées en une fois?',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('ignorer'),
            child: const Text('Plus tard', style: TextStyle(color: Colors.grey)),
          ),
          if (nbJours == 1)
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('cloturer_un'),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Clôturer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48bb78),
                foregroundColor: Colors.white,
              ),
            )
          else if (nbJours <= 3)
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('cloturer_tous'),
              icon: const Icon(Icons.playlist_add_check),
              label: Text('Clôturer les $nbJours jours'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48bb78),
                foregroundColor: Colors.white,
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop('cloturer_tous'),
              icon: const Icon(Icons.fast_forward),
              label: Text('Clôturer tout ($nbJours jours)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48bb78),
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
    
    if (action == 'cloturer_un') {
      // Ouvrir le dialogue de clôture pour le jour le plus ancien
      await _ouvrirDialogueClotureForce(joursNonClotures.first, sims);
    } else if (action == 'cloturer_tous') {
      // Clôturer tous les jours avec les mêmes montants
      await _cloturerTousLesJours(joursNonClotures, sims);
    }
    // Si 'ignorer', ne rien faire
  }

  /// Ouvrir le dialogue de clôture pour une date spécifique
  Future<void> _ouvrirDialogueClotureForce(DateTime date, List<SimModel> sims) async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) return;
    
    // Ouvrir le dialogue de clôture par SIM avec la date spécifiée
    final result = await _genererClotureForce(date, currentUser, sims);
    
    if (result == true && mounted) {
      // Vérifier s'il reste d'autres jours à clôturer
      _verifierJoursNonClotures();
    }
  }

  /// Clôturer tous les jours manquants avec le même montant
  Future<void> _cloturerTousLesJours(List<DateTime> joursNonClotures, List<SimModel> sims) async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser == null) return;
    
    // Ouvrir le dialogue pour le premier jour et utiliser les mêmes montants pour les autres
    final result = await _genererClotureForce(joursNonClotures.first, currentUser, sims);
    
    if (result == true && mounted && joursNonClotures.length > 1) {
      // TODO: Implémenter la clôture des jours suivants avec les mêmes montants
      // Pour l'instant, on redemande pour chaque jour
      final joursRestants = joursNonClotures.sublist(1);
      await _proposerClotureMassive(joursRestants, sims);
    }
  }

  /// Générer une clôture forcée pour une date
  Future<bool?> _genererClotureForce(DateTime date, dynamic currentUser, List<SimModel> sims) async {
    if (!mounted) return null;
    
    try {
      // Générer les clôtures
      final cloturesGenerees = await ClotureVirtuelleParSimService.instance.genererClotureParSim(
        shopId: currentUser.shopId!,
        agentId: currentUser.id!,
        cloturePar: currentUser.username,
        date: date,
      );
      
      // Créer les contrôleurs pour chaque SIM
      final controllers = <String, Map<String, TextEditingController>>{};
      for (var cloture in cloturesGenerees) {
        controllers[cloture.simNumero] = {
          'solde': TextEditingController(text: cloture.soldeActuel.toStringAsFixed(2)),
          'notes': TextEditingController(),
        };
      }
      
      // Variable pour stocker les clôtures mises à jour
      List<ClotureVirtuelleParSimModel>? cloturesMisesAJour;
      
      // Afficher le dialogue avec les champs éditables
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('Clôture du ${date.day}/${date.month}/${date.year}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Vérifiez les soldes avant de sauvegarder:',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 16),
                ...cloturesGenerees.map((cloture) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cloture.simNumero,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: controllers[cloture.simNumero]!['solde'],
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Solde Virtuel',
                          prefixText: r'$ ',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () {
                // Récupérer les valeurs saisies AVANT de disposer
                cloturesMisesAJour = [];
                for (var cloture in cloturesGenerees) {
                  final soldeText = controllers[cloture.simNumero]!['solde']!.text;
                  final solde = double.tryParse(soldeText) ?? cloture.soldeActuel;
                  
                  cloturesMisesAJour!.add(cloture.copyWith(
                    soldeActuel: solde,
                  ));
                }
                
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF48bb78),
              ),
              child: const Text('Confirmer'),
            ),
          ],
        ),
      );
      
      // Disposer les contrôleurs APRÈS la fermeture du dialogue
      for (var simControllers in controllers.values) {
        for (var controller in simControllers.values) {
          controller.dispose();
        }
      }
      
      if (result == true && cloturesMisesAJour != null && mounted) {
        // Sauvegarder les clôtures MISES À JOUR
        await ClotureVirtuelleParSimService.instance.sauvegarderClotures(cloturesMisesAJour!);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${cloturesMisesAJour!.length} clôture(s) sauvegardée(s)'),
              backgroundColor: Colors.green,
            ),
          );
        }
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('❌ Erreur génération clôture forcée: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final isAdmin = authService.currentUser?.role == 'ADMIN';
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
        actions: [
          // 🏪 FILTRE SHOP GLOBAL (Admin uniquement)
          if (isAdmin)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Consumer<ShopService>(
                builder: (BuildContext context, shopService, child) {
                  return PopupMenuButton<int>(
                    tooltip: 'Filtrer par Shop',
                    icon: Icon(
                      _selectedShopFilter == null ? Icons.store : Icons.store_mall_directory,
                      color: _selectedShopFilter == null ? Colors.white : Colors.yellow,
                      size: 28,
                    ),
                    onSelected: (int? value) {
                      setState(() {
                        _selectedShopFilter = value;
                        _selectedSimFilter = null;
                      });
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<int>(
                        value: null,
                        child: Row(
                          children: [
                            Icon(
                              _selectedShopFilter == null ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: _selectedShopFilter == null ? const Color(0xFF48bb78) : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Tous les shops',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      ...shopService.shops.map((shop) => PopupMenuItem<int>(
                        value: shop.id,
                        child: Row(
                          children: [
                            Icon(
                              _selectedShopFilter == shop.id ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: _selectedShopFilter == shop.id ? const Color(0xFF48bb78) : Colors.grey,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                shop.designation,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      )),
                    ],
                  );
                },
              ),
            ),
          // TODO: Bouton pour vérifier les clôtures manquantes (désactivé temporairement)
          // Cause: setState() during build même avec bouton manuel
          // IconButton(
          //   icon: const Icon(Icons.history, color: Colors.white),
          //   tooltip: 'Vérifier les clôtures manquantes',
          //   onPressed: () {
          //     _verifierJoursNonClotures();
          //   },
          // ),
        ],
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
                  icon: Icon(Icons.credit_card, size: isMobile ? 18 : 22),
                  text: 'Crédit',
                ),
                Tab(
                  icon: Icon(Icons.swap_horiz, size: isMobile ? 18 : 22),
                  text: 'Échanges',
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
      body: Column(
        children: [
          // 🏪 BARRE DE FILTRE SHOP (Admin uniquement) - COMPACTE ET MASQUABLE
          Consumer<AuthService>(
            builder: (context, authService, child) {
              final isAdmin = authService.currentUser?.role == 'ADMIN';
              if (!isAdmin) return const SizedBox.shrink();
              
              return Column(
                children: [
                  // Bouton pour afficher/masquer le filtre shop
                  Container(
                    color: const Color(0xFF48bb78),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.store, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        const Text(
                          'Filtre Shop',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const Spacer(),
                        // Indicateur si un filtre est actif
                        if (_selectedShopFilter != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.yellow,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'Actif',
                              style: TextStyle(
                                color: Colors.black,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: Icon(
                            _showFilters ? Icons.expand_less : Icons.expand_more,
                            color: Colors.white,
                            size: 20,
                          ),
                          onPressed: () {
                            setState(() {
                              _showFilters = !_showFilters;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  // Dropdown du filtre (masquable)
                  if (_showFilters)
                    Container(
                      color: Colors.grey[100],
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Consumer<ShopService>(
                        builder: (BuildContext context, shopService, child) {
                          return Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF48bb78)),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<int>(
                                      value: _selectedShopFilter,
                                      isExpanded: true,
                                      hint: const Text(
                                        'Tous les shops',
                                        style: TextStyle(fontSize: 13),
                                      ),
                                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF48bb78), size: 20),
                                      style: const TextStyle(fontSize: 13, color: Colors.black),
                                      items: [
                                        const DropdownMenuItem<int>(
                                          value: null,
                                          child: Text(
                                            'Tous les shops',
                                            style: TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                        ...shopService.shops.map((shop) => DropdownMenuItem<int>(
                                          value: shop.id,
                                          child: Text(shop.designation),
                                        )),
                                      ],
                                      onChanged: (int? value) {
                                        setState(() {
                                          _selectedShopFilter = value;
                                          _selectedSimFilter = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              // Bouton pour effacer le filtre
                              if (_selectedShopFilter != null)
                                const SizedBox(width: 8),
                              if (_selectedShopFilter != null)
                                IconButton(
                                  icon: const Icon(Icons.close, color: Colors.red, size: 18),
                                  tooltip: 'Effacer le filtre',
                                  onPressed: () {
                                    setState(() {
                                      _selectedShopFilter = null;
                                      _selectedSimFilter = null;
                                    });
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 32,
                                    minHeight: 32,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTransactionsTab(),
                _buildFlotTab(),
                _buildDepotTab(),
                _buildCreditVirtuelTab(),
                _buildEchangesTab(),
                _buildRapportTab(),
              ],
            ),
          ),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
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
                label: const SizedBox.shrink(), // Remove text, keep only icon
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
            child: SingleChildScrollView(
              child: Column(
                children: [
                // FILTRE PAR SHOP (Admin uniquement) - EN PREMIER
                Consumer<AuthService>(
                  builder: (context, authService, child) {
                    final isAdmin = authService.currentUser?.role == 'ADMIN';
                    if (!isAdmin) return const SizedBox.shrink();
                    
                    return Column(
                      children: [
                        Consumer<ShopService>(
                          builder: (BuildContext context, shopService, child) {
                            return DropdownButtonFormField<int>(
                              value: _selectedShopFilter,
                              decoration: const InputDecoration(
                                labelText: 'Filtrer par Shop',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                prefixIcon: Icon(Icons.store, color: Color(0xFF48bb78)),
                                filled: true,
                                fillColor: Colors.white,
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
                                  // Réinitialiser le filtre SIM quand on change de shop
                                  _selectedSimFilter = null;
                                });
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
                ),
                // Barre de recherche
                TextField(
                  controller: _searchController,
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Rechercher...',
                    hintStyle: const TextStyle(fontSize: 12),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF48bb78), size: 18),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
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
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                        label: const Text('Tout', style: TextStyle(fontSize: 10)),
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
                        label: const Text('En Attente', style: TextStyle(fontSize: 10)),
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
                        label: const Text('Servies', style: TextStyle(fontSize: 10)),
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
          ),
        // Liste des transactions (scrollable)
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
        final isAdmin = authService.currentUser?.role == 'ADMIN';
        
        if (currentShopId == null && !isAdmin) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        // Filtrer par shop
        var transactions = service.transactions;
        
        // Si admin avec filtre shop sélectionné, filtrer par ce shop
        if (isAdmin && _selectedShopFilter != null) {
          transactions = transactions.where((t) => t.shopId == _selectedShopFilter).toList();
        } 
        // Si admin sans filtre, afficher tous les shops
        else if (isAdmin) {
          transactions = transactions.toList();
        }
        // Si agent, filtrer par son shop
        else {
          transactions = transactions.where((t) => t.shopId == currentShopId).toList();
        }

        // Filtrer par statut si sélectionné
        if (_statusFilter != null) {
          transactions = transactions.where((t) => t.statut == _statusFilter).toList();
        }

        // Filtrer par devise si sélectionnée
        if (_deviseFilter != null) {
          transactions = transactions.where((t) => t.devise == _deviseFilter).toList();
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
        final isAdmin = authService.currentUser?.role == 'ADMIN';
        
        if (currentShopId == null && !isAdmin) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        // Filtrer par statut: enAttente
        var transactions = service.transactions
            .where((t) => t.statut == VirtualTransactionStatus.enAttente)
            .toList();

        // Filtrer par shop
        // Si admin avec filtre shop sélectionné, filtrer par ce shop
        if (isAdmin && _selectedShopFilter != null) {
          transactions = transactions.where((t) => t.shopId == _selectedShopFilter).toList();
        } 
        // Si admin sans filtre, afficher tous les shops
        else if (isAdmin) {
          // Garder tous les shops
        }
        // Si agent, filtrer par son shop
        else {
          transactions = transactions.where((t) => t.shopId == currentShopId).toList();
        }

        // Appliquer les filtres
        var filteredTransactions = transactions;
        if (_selectedSimFilter != null) {
          filteredTransactions = filteredTransactions.where((t) => t.simNumero == _selectedSimFilter).toList();
        }
        if (_dateDebutFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.dateEnregistrement.isAtSameMomentAs(_dateDebutFilter!) || t.dateEnregistrement.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          filteredTransactions = filteredTransactions
              .where((t) => t.dateEnregistrement.isAtSameMomentAs(_dateFinFilter!) || t.dateEnregistrement.isBefore(_dateFinFilter!))
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
                    label: const SizedBox.shrink(), // Remove text, keep only icon
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
        final isAdmin = authService.currentUser?.role == 'ADMIN';
        
        if (currentShopId == null && !isAdmin) {
          return const Center(child: Text('Shop ID non disponible'));
        }

        // Filtrer par statut: validee
        var transactions = service.transactions
            .where((t) => t.statut == VirtualTransactionStatus.validee)
            .toList();

        // Filtrer par shop
        // Si admin avec filtre shop sélectionné, filtrer par ce shop
        if (isAdmin && _selectedShopFilter != null) {
          transactions = transactions.where((t) => t.shopId == _selectedShopFilter).toList();
        } 
        // Si admin sans filtre, afficher tous les shops
        else if (isAdmin) {
          // Garder tous les shops
        }
        // Si agent, filtrer par son shop
        else {
          transactions = transactions.where((t) => t.shopId == currentShopId).toList();
        }

        // Appliquer les filtres
        if (_selectedSimFilter != null) {
          transactions = transactions.where((t) => t.simNumero == _selectedSimFilter).toList();
        }
        if (_dateDebutFilter != null) {
          transactions = transactions
              .where((t) => t.dateValidation != null && (t.dateValidation!.isAtSameMomentAs(_dateDebutFilter!) || t.dateValidation!.isAfter(_dateDebutFilter!)))
              .toList();
        }
        if (_dateFinFilter != null) {
          transactions = transactions
              .where((t) => t.dateValidation != null && (t.dateValidation!.isAtSameMomentAs(_dateFinFilter!) || t.dateValidation!.isBefore(_dateFinFilter!)))
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
                    label: const SizedBox.shrink(), // Remove text, keep only icon
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
        
        // Ajouter les retraits (avec filtrage par date si nécessaire)
        for (var retrait in retraits) {
          // Appliquer le filtre de date si défini
          if (_flotDateFilter != null) {
            final filterDate = DateTime(_flotDateFilter!.year, _flotDateFilter!.month, _flotDateFilter!.day);
            final retraitDate = DateTime(retrait.dateRetrait.year, retrait.dateRetrait.month, retrait.dateRetrait.day);
            if (!retraitDate.isAtSameMomentAs(filterDate)) {
              continue; // Ignorer ce retrait s'il ne correspond pas à la date filtrée
            }
          }
          
          mouvements.add({
            'type': 'retrait',
            'data': retrait,
            'date': retrait.dateRetrait,
          });
        }
        
        // Ajouter les FLOTs (avec filtrage par date si nécessaire)
        for (var flot in flots) {
          // Appliquer le filtre de date si défini
          if (_flotDateFilter != null) {
            final filterDate = DateTime(_flotDateFilter!.year, _flotDateFilter!.month, _flotDateFilter!.day);
            final flotDate = DateTime(flot.dateOp.year, flot.dateOp.month, flot.dateOp.day);
            if (!flotDate.isAtSameMomentAs(filterDate)) {
              continue; // Ignorer ce flot s'il ne correspond pas à la date filtrée
            }
          }
          
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
              .where((t) => t.dateEnregistrement.isAtSameMomentAs(_dateDebutFilter!) || t.dateEnregistrement.isAfter(_dateDebutFilter!))
              .toList();
        }
        if (_dateFinFilter != null) {
          transactions = transactions
              .where((t) => t.dateEnregistrement.isAtSameMomentAs(_dateFinFilter!) || t.dateEnregistrement.isBefore(_dateFinFilter!))
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
                    label: const SizedBox.shrink(), // Remove text, keep only icon
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
                        : 'début',
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
                      setState(() => _dateDebutFilter = DateTime(date.year, date.month, date.day, 0, 0, 0));
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
                        : 'fin',
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
    
    // Écouter les changements du service de sync pour rafraîchir automatiquement
    return Consumer<DepotRetraitSyncService>(
      builder: (context, depotSyncService, child) {
        // Utiliser une clé unique basée sur un timestamp pour forcer le rechargement
        return FutureBuilder<List<DepotClientModel>>(
          key: ValueKey('depot_tab_${DateTime.now().millisecondsSinceEpoch}'),
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
                    label: const SizedBox.shrink(), // Remove text, keep only icon
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
                        // Forcer le rechargement en reconstruisant le widget avec une nouvelle clé
                        setState(() {}); 
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
                label: const SizedBox.shrink(), // Remove text, keep only icon
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
      double montantSigne; // Positif = ils Nous qui Doivent, Négatif = on leur doit
      
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
        // Inclure à la fois les FLOTs validés et en attente
        if (flot.shopDestinationId == shopId && 
            (flot.statut == OperationStatus.validee || 
             flot.statut == OperationStatus.terminee || 
             flot.statut == OperationStatus.enAttente)) {
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
          
          // On a REÇU du cash → réduit ce qu'ils Nous qui Doivent
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
          
          // On leur a ENVOYÉ du cash → augmente ce qu'ils Nous qui Doivent
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
                      
                      // Section: Ils Nous qui Doivent (solde > 0)
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
                                'Ils Nous qui Doivent',
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

  /// Onglet Crédit Virtuel - Gestion des crédits accordés aux shops/partenaires
  Widget _buildCreditVirtuelTab() {
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
              tabs: [
                Tab(text: 'Accorder Crédit', icon: Icon(Icons.add_card, size: 20)),
                Tab(text: 'Gestion Crédits', icon: Icon(Icons.credit_card, size: 20)),
                Tab(text: 'Statistiques', icon: Icon(Icons.analytics, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildAccorderCreditTab(),
                _buildGestionCreditsTab(),
                _buildStatistiquesCreditTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Sous-onglet pour accorder un nouveau crédit
  Widget _buildAccorderCreditTab() {
    return Consumer<CreditVirtuelService>(
      builder: (context, creditService, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place the button and filter toggle on the same line
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _showAccorderCreditDialog(),
                            icon: const Icon(Icons.add_card),
                            label: const Text('Crédit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF48bb78),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Filter toggle button
                          OutlinedButton.icon(
                            onPressed: () {
                              setState(() {
                                _showFilters = !_showFilters;
                              });
                            },
                            icon: Icon(
                              _showFilters ? Icons.visibility_off : Icons.visibility,
                              size: 20,
                            ),
                            label: const Text('Afficher/Masquer'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF48bb78),
                              side: const BorderSide(color: Color(0xFF48bb78), width: 1.5),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ],
                      ),
                      // Conditionally show the solde virtuel disponible when filters are shown
                      if (_showFilters) ...[
                        const SizedBox(height: 16),
                        _buildCreditFilters(),
                        const SizedBox(height: 16),
                        _buildSoldeVirtuelDisponible(),
                      ]
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Sous-onglet pour gérer les crédits existants
  Widget _buildGestionCreditsTab() {
    return Consumer<CreditVirtuelService>(
      builder: (context, creditService, child) {
        return Column(
          children: [
            // Barre de filtres et actions
            Container(
              color: Colors.grey[200],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _loadCreditsData(),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Actualiser'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF48bb78),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${creditService.credits.length} crédit(s)',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            // Liste des crédits
            Expanded(
              child: creditService.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : creditService.credits.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.credit_card_off, size: 64, color: Colors.grey),
                              SizedBox(height: 16),
                              Text(
                                'Aucun crédit accordé',
                                style: TextStyle(fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(8),
                          itemCount: creditService.credits.length,
                          itemBuilder: (context, index) {
                            final credit = creditService.credits[index];
                            return _buildCreditCard(credit);
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  /// Sous-onglet pour les statistiques des crédits
  Widget _buildStatistiquesCreditTab() {
    return Consumer<CreditVirtuelService>(
      builder: (context, creditService, child) {
        return FutureBuilder<Map<String, dynamic>>(
          future: creditService.getStatistiques(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final stats = snapshot.data ?? {};
            
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatCard('Total Accordé', stats['total_accorde']?.toString() ?? '0', Icons.trending_up, Colors.blue),
                  _buildStatCard('Total Payé', stats['total_paye']?.toString() ?? '0', Icons.payment, Colors.green),
                  _buildStatCard('En Attente', stats['total_en_attente']?.toString() ?? '0', Icons.schedule, Colors.orange),
                  _buildStatCard('En Retard', stats['total_en_retard']?.toString() ?? '0', Icons.warning, Colors.red),
                  _buildStatCard('Taux Recouvrement', '${(stats['taux_recouvrement'] ?? 0.0).toStringAsFixed(1)}%', Icons.percent, Colors.purple),
                ],
              ),
            );
          },
        );
      },
    );
  }

  /// Onglet Échanges Virtuels - Transfert de crédit entre SIMs
  Widget _buildEchangesTab() {
    return const VirtualExchangeWidget();
  }

  /// Onglet rapport avec sous-onglets (par SIM et Frais)
  Widget _buildRapportTab() {
    return DefaultTabController(
      length: 5,
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
                Tab(text: 'Liste Transactions', icon: Icon(Icons.list_alt, size: 20)),
                Tab(text: 'Clôture par SIM', icon: Icon(Icons.phonelink_lock, size: 20)),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildRapportVueEnsembleTab(),
                _buildRapportParSimTab(),
                _buildRapportFraisTab(),
                _buildListeTransactionsTab(),
                _buildClotureParSimTab(),
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
  Future<double> _getSoldeAnterieurCash(int? shopId, {DateTime? dateReference}) async {
    if (shopId == null) return 0.0;
    
    try {
      // Utiliser la date de référence (date sélectionnée) ou aujourd'hui par défaut
      final dateRef = dateReference ?? DateTime.now();
      // Jour précédent
      final jourPrecedent = dateRef.subtract(const Duration(days: 1));
      
      // D'abord essayer de récupérer les clôtures PAR SIM du jour précédent
      final cloturesParSim = await LocalDB.instance.getCloturesVirtuellesParDate(
        shopId: shopId,
        date: jourPrecedent,
      );
      
      if (cloturesParSim.isNotEmpty) {
        // Calculer le total du cash disponible de toutes les SIMs
        final cashTotalParSim = cloturesParSim.fold<double>(0.0, (sum, cloture) {
          final cashDisponible = cloture['cash_disponible'] as num?;
          return sum + (cashDisponible?.toDouble() ?? 0.0);
        });
        
        debugPrint('📋 Solde antérieur CASH trouvé (${cloturesParSim.length} clôture(s) par SIM du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   CASH TOTAL: ${cashTotalParSim.toStringAsFixed(2)} USD');
        return cashTotalParSim;
      }
      
      // Si pas de clôtures par SIM, essayer la clôture caisse classique
      // Récupérer la clôture caisse du jour précédent
      final cloturePrecedente = await LocalDB.instance.getClotureCaisseByDate(shopId, jourPrecedent);
      
      if (cloturePrecedente != null) {
        // MÊME LOGIQUE QUE rapport_cloture_service.dart:
        // Utiliser le montant SAISI TOTAL comme solde antérieur
        debugPrint('📋 Solde antérieur CASH trouvé (clôture caisse du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   TOTAL SAISI: ${cloturePrecedente.soldeSaisiTotal} USD');
        return cloturePrecedente.soldeSaisiTotal;
      }
      
      // Si aucune clôture précédente, retourner 0
      debugPrint('ℹ️ Aucun solde antérieur CASH (pas de clôture du jour précédent)');
      return 0.0;
    } catch (e) {
      debugPrint('❌ Erreur récupération solde antérieur CASH: $e');
      return 0.0;
    }
  }

  /// Récupérer le solde antérieur VIRTUEL de la dernière clôture virtuelle
  /// Formule: Virtuel Disponible = Solde Antérieur (Virtuel) + Captures du Jour (Frais inclus) - Retraits du Jour
  Future<double> _getSoldeAnterieurVirtuel(int? shopId, {DateTime? dateReference}) async {
    if (shopId == null) return 0.0;
    
    try {
      // Utiliser la date de référence (date sélectionnée) ou aujourd'hui par défaut
      final dateRef = dateReference ?? DateTime.now();
      final jourPrecedent = dateRef.subtract(const Duration(days: 1));
      
      final cloturesParSim = await LocalDB.instance.getCloturesVirtuellesParDate(
        shopId: shopId,
        date: jourPrecedent,
      );
      
      if (cloturesParSim.isNotEmpty) {
        // Calculer le total des soldes actuels de toutes les SIMs
        final soldeTotalParSim = cloturesParSim.fold<double>(0.0, (sum, cloture) {
          final soldeActuel = cloture['solde_actuel'] as num?;
          return sum + (soldeActuel?.toDouble() ?? 0.0);
        });
        
        debugPrint('📋 Solde antérieur VIRTUEL trouvé (${cloturesParSim.length} clôture(s) par SIM du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   SOLDE TOTAL SIMs: ${soldeTotalParSim.toStringAsFixed(2)} USD');
        return soldeTotalParSim;
      }
      
      // Si pas de clôtures par SIM, essayer la clôture globale
      final clotures = await LocalDB.instance.getAllCloturesVirtuelles(shopId: shopId);
      if (clotures.isEmpty) {
        debugPrint('ℹ️ Aucun solde antérieur VIRTUEL (pas de clôture virtuelle précédente)');
        return 0.0;
      }
      
      // Trier par date décroissante et prendre la première
      clotures.sort((a, b) => b.dateCloture.compareTo(a.dateCloture));
      final derniereCloture = clotures.first;
      
      // Utiliser le solde total des SIMs de la dernière clôture
      debugPrint('📋 Solde antérieur VIRTUEL trouvé (clôture globale du ${derniereCloture.dateCloture.toIso8601String().split('T')[0]}):');
      debugPrint('   SOLDE TOTAL SIMs: ${derniereCloture.soldeTotalSims} USD');
      return derniereCloture.soldeTotalSims;
    } catch (e) {
      debugPrint('❌ Erreur récupération solde antérieur VIRTUEL: $e');
      return 0.0;
    }
  }

  /// Récupérer le solde FRAIS antérieur de la clôture du jour précédent
  /// Utilise la MÊME logique que rapport_cloture_service.dart
  Future<double> _getSoldeFraisAnterieur(int? shopId, {DateTime? dateReference}) async {
    if (shopId == null) return 0.0;
    
    try {
      // Utiliser la date de référence (date sélectionnée) ou aujourd'hui par défaut
      final dateRef = dateReference ?? DateTime.now();
      // Jour précédent
      final jourPrecedent = dateRef.subtract(const Duration(days: 1));
      
      // D'abord essayer de récupérer les clôtures PAR SIM du jour précédent
      final cloturesParSim = await LocalDB.instance.getCloturesVirtuellesParDate(
        shopId: shopId,
        date: jourPrecedent,
      );
      
      if (cloturesParSim.isNotEmpty) {
        // Calculer le total des frais de toutes les SIMs
        final fraisTotalParSim = cloturesParSim.fold<double>(0.0, (sum, cloture) {
          final fraisTotal = cloture['frais_total'] as num?;
          return sum + (fraisTotal?.toDouble() ?? 0.0);
        });
        
        debugPrint('📋 Solde FRAIS antérieur trouvé (${cloturesParSim.length} clôture(s) par SIM du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   FRAIS TOTAL: ${fraisTotalParSim.toStringAsFixed(2)} USD');
        return fraisTotalParSim;
      }
      
      // Si pas de clôtures par SIM, essayer la clôture caisse classique
      // Récupérer la clôture caisse du jour précédent
      final cloturePrecedente = await LocalDB.instance.getClotureCaisseByDate(shopId, jourPrecedent);
      
      if (cloturePrecedente != null) {
        // Retourner le solde FRAIS enregistré dans la clôture
        debugPrint('📋 Solde FRAIS antérieur trouvé (clôture caisse du ${jourPrecedent.toIso8601String().split('T')[0]}):');
        debugPrint('   SOLDE FRAIS: ${cloturePrecedente.soldeFraisAnterieur} USD');
        return cloturePrecedente.soldeFraisAnterieur;
      }
      
      // Si aucune clôture précédente, retourner 0
      debugPrint('ℹ️ Aucun solde FRAIS antérieur (pas de clôture du jour précédent)');
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
                  
                  if (transDate.isAfter(startOfDay) &&
                      transDate.isBefore(endOfDay)) {
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
    return Consumer3<VirtualTransactionService, SimService, CreditVirtuelService>(
      builder: (BuildContext context, vtService, simService, creditService, child) {
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

        // NOUVEAU: Séparer les filtres selon la logique des dates
        // CAPTURES DU JOUR: Basées sur dateEnregistrement
        var capturesDuJour = transactions;
        // SERVICES DU JOUR: Basées sur dateValidation
        var servicesDuJour = transactions.where((t) => 
          t.statut == VirtualTransactionStatus.validee && t.dateValidation != null
        ).toList();
        
        if (_selectedDate != null) {
          final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
          final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
          
          // Filtrer CAPTURES par dateEnregistrement
          capturesDuJour = capturesDuJour
              .where((t) => 
                (t.dateEnregistrement.isAtSameMomentAs(startOfDay) || t.dateEnregistrement.isAfter(startOfDay)) &&
                (t.dateEnregistrement.isAtSameMomentAs(endOfDay) || t.dateEnregistrement.isBefore(endOfDay)))
              .toList();
              
          // Filtrer SERVICES par dateValidation (CASH SERVI)
          servicesDuJour = servicesDuJour
              .where((t) => 
                t.dateValidation != null &&
                t.dateValidation!.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
                t.dateValidation!.isBefore(endOfDay.add(const Duration(milliseconds: 1))))
              .toList();
        }
        
        // Filtrer par SIM (si sélectionnée)
        if (_selectedSimFilter != null) {
          capturesDuJour = capturesDuJour
              .where((t) => t.simNumero == _selectedSimFilter)
              .toList();
          servicesDuJour = servicesDuJour
              .where((t) => t.simNumero == _selectedSimFilter)
              .toList();
        }

        // Calculer les statistiques basées sur la logique correcte des dates
        final captures = capturesDuJour; // CAPTURES = dateEnregistrement
        final validees = servicesDuJour; // SERVICES = dateValidation
        final enAttente = capturesDuJour.where((t) => t.statut == VirtualTransactionStatus.enAttente).toList();
        final annulees = capturesDuJour.where((t) => t.statut == VirtualTransactionStatus.annulee).toList();

        // NOUVEAU: Séparer les captures par devise
        final capturesCdf = captures.where((t) => t.devise == 'CDF').toList();
        final capturesUsd = captures.where((t) => t.devise == 'USD').toList();
        final montantCapturesCdf = capturesCdf.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final montantCapturesUsd = capturesUsd.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        
        // NOUVEAU: Séparer les servies par devise
        final serviesCdf = validees.where((t) => t.devise == 'CDF').toList();
        final serviesUsd = validees.where((t) => t.devise == 'USD').toList();
        final montantServiesCdf = serviesCdf.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final montantServiesUsd = serviesUsd.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        
        // NOUVEAU: Séparer les en attente par devise
        final enAttenteCdf = enAttente.where((t) => t.devise == 'CDF').toList();
        final enAttenteUsd = enAttente.where((t) => t.devise == 'USD').toList();
        final montantEnAttenteCdf = enAttenteCdf.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final montantEnAttenteUsd = enAttenteUsd.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        
        // Totaux pour compatibilité (conversion CDF en USD pour totaux globaux)
        final montantTotalCaptures = montantCapturesUsd + CurrencyService.instance.convertCdfToUsd(montantCapturesCdf);
        final montantVirtuelServies = montantServiesUsd + CurrencyService.instance.convertCdfToUsd(montantServiesCdf);
        final montantEnAttente = montantEnAttenteUsd + CurrencyService.instance.convertCdfToUsd(montantEnAttenteCdf);
        
        final fraisPercus = captures.fold<double>(0, (sum, t) => sum + t.frais);
        // NOUVEAU: Total des frais de TOUTES les captures (pas seulement servies)
        final fraisToutesCaptures = captures.fold<double>(0, (sum, t) => sum + t.frais);
        
        // DEBUG: Afficher les détails des CAPTURES incluses dans le calcul
        debugPrint('📋 [DEBUG] Captures Calculation');
        debugPrint('   Nombre total captures incluses: ${captures.length}');
        for (var t in captures.take(5)) { // Afficher seulement les 5 premières
          debugPrint('   - ID: ${t.id}, Ref: ${t.reference}, Montant: ${t.montantVirtuel} ${t.devise}, Frais: ${t.frais}');
          debugPrint('     DateEnregistrement RAW: ${t.dateEnregistrement.toIso8601String()}');
          debugPrint('     DateEnregistrement LOCAL: ${t.dateEnregistrement.toLocal().toIso8601String()}');
          debugPrint('     DateEnregistrement UTC: ${t.dateEnregistrement.toUtc().toIso8601String()}');
        }
        if (captures.length > 5) {
          debugPrint('   ... et ${captures.length - 5} autres captures');
        }
        final cashServi = validees.fold<double>(0, (sum, t) => sum + t.montantCash);
        
        // DEBUG ENHANCED: Vérification détaillée du calcul Cash Servi
        debugPrint('🔍 [DEBUG ENHANCED] Cash Servi Calculation - VERIFICATION BD');
        debugPrint('   Date sélectionnée: ${_selectedDate?.toIso8601String().split('T')[0] ?? 'Toutes'}');
        debugPrint('   Shop ID Filter: $shopIdFilter');
        debugPrint('   SIM Filter: $_selectedSimFilter');
        
        // Vérifier les transactions AVANT filtrage par date
        final allValidatedTransactions = transactions.where((t) => 
          t.statut == VirtualTransactionStatus.validee && t.dateValidation != null
        ).toList();
        debugPrint('   Total transactions validées (AVANT filtrage date): ${allValidatedTransactions.length}');
        
        // Vérifier les transactions APRÈS filtrage par date
        debugPrint('   Total transactions validées (APRÈS filtrage date): ${servicesDuJour.length}');
        debugPrint('   Total validées utilisées pour calcul: ${validees.length}');
        
        if (_selectedDate != null) {
          final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
          final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
          debugPrint('   Plage de filtrage: $startOfDay à $endOfDay');
          
          // Vérifier chaque transaction validée pour voir si elle passe le filtre
          debugPrint('   === ANALYSE DÉTAILLÉE DU FILTRAGE ===');
          double totalCashIncluded = 0.0;
          double totalCashExcluded = 0.0;
          int countIncluded = 0;
          int countExcluded = 0;
          
          for (var t in allValidatedTransactions) {
            final dateVal = t.dateValidation!;
            final passesFilter = (dateVal.isAtSameMomentAs(startOfDay) || dateVal.isAfter(startOfDay)) &&
                               (dateVal.isAtSameMomentAs(endOfDay) || dateVal.isBefore(endOfDay));
            
            if (passesFilter) {
              totalCashIncluded += t.montantCash;
              countIncluded++;
              debugPrint('   ✅ INCLUS - ID: ${t.id}, Ref: ${t.reference}');
              debugPrint('      DateValidation: ${dateVal.toIso8601String()}');
              debugPrint('      MontantVirtuel: ${t.montantVirtuel} ${t.devise}');
              debugPrint('      MontantCash: \$${t.montantCash}');
              debugPrint('      Frais: \$${t.frais}');
              debugPrint('      Statut: ${t.statut}');
            } else {
              totalCashExcluded += t.montantCash;
              countExcluded++;
              debugPrint('   ❌ EXCLU - ID: ${t.id}, DateValidation: ${dateVal.toIso8601String()}, Cash: \$${t.montantCash}');
            }
          }
          
          debugPrint('   === RÉSUMÉ DU FILTRAGE ===');
          debugPrint('   Transactions INCLUSES: $countIncluded, Cash total: \$${totalCashIncluded.toStringAsFixed(2)}');
          debugPrint('   Transactions EXCLUES: $countExcluded, Cash total: \$${totalCashExcluded.toStringAsFixed(2)}');
          debugPrint('   TOTAL BD: ${countIncluded + countExcluded}, Cash total BD: \$${(totalCashIncluded + totalCashExcluded).toStringAsFixed(2)}');
        }
        
        // Calculer le total manuellement pour vérification
        debugPrint('   === CALCUL MANUEL DÉTAILLÉ ===');
        double manualCashServi = 0.0;
        for (var t in validees) {
          // Calculer le montant cash attendu selon la formule: montantVirtuel - frais
          final expectedCash = t.montantVirtuel - t.frais;
          manualCashServi += t.montantCash;
          
          debugPrint('   Transaction ID: ${t.id}');
          debugPrint('     MontantVirtuel: ${t.montantVirtuel} ${t.devise}');
          debugPrint('     Frais: \$${t.frais}');
          debugPrint('     MontantCash (BD): \$${t.montantCash}');
          debugPrint('     MontantCash (Attendu): \$${expectedCash.toStringAsFixed(2)}');
          debugPrint('     CONCORDANCE: ${t.montantCash == expectedCash ? 'OUI' : 'NON - DIFFÉRENCE!'}');
          debugPrint('     Total cumulé: \$${manualCashServi.toStringAsFixed(2)}');
          debugPrint('   ---');
        }
        
        debugPrint('   RÉSULTAT FINAL Cash Servi: \$${cashServi.toStringAsFixed(2)}');
        debugPrint('   VÉRIFICATION MANUELLE: \$${manualCashServi.toStringAsFixed(2)}');
        debugPrint('   CONCORDANCE: ${cashServi == manualCashServi ? 'OUI' : 'NON - ERREUR!'}');
        final montantAnnulees = annulees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);

        // Soldes SIMs
        final soldeTotalSims = sims.fold<double>(0, (sum, s) => sum + s.soldeActuel);

        // NOUVEAU: Statistiques des crédits virtuels
        final creditsVirtuels = shopIdFilter != null
            ? creditService.credits.where((c) => c.shopId == shopIdFilter).toList()
            : creditService.credits;
        
        // Filtrer les crédits par date (date de sortie)
        var creditsDuJour = creditsVirtuels;
        var paiementsDuJour = creditsVirtuels.where((c) => c.datePaiement != null).toList();
        
        if (_selectedDate != null) {
          final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
          final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
          
          // Crédits accordés du jour (basé sur date_sortie)
          creditsDuJour = creditsDuJour.where((c) => 
            (c.dateSortie.isAtSameMomentAs(startOfDay) || c.dateSortie.isAfter(startOfDay)) &&
            (c.dateSortie.isAtSameMomentAs(endOfDay) || c.dateSortie.isBefore(endOfDay))).toList();
            
          // Paiements reçus du jour (basé sur date_paiement)
          paiementsDuJour = paiementsDuJour.where((c) => 
            c.datePaiement != null &&
            (c.datePaiement!.isAtSameMomentAs(startOfDay) || c.datePaiement!.isAfter(startOfDay)) &&
            (c.datePaiement!.isAtSameMomentAs(endOfDay) || c.datePaiement!.isBefore(endOfDay))).toList();
        }
        
        // Filtrer par SIM si sélectionnée
        if (_selectedSimFilter != null) {
          creditsDuJour = creditsDuJour.where((c) => c.simNumero == _selectedSimFilter).toList();
          paiementsDuJour = paiementsDuJour.where((c) => c.simNumero == _selectedSimFilter).toList();
        }
        
        // Calculs des crédits virtuels
        final montantCreditsAccordes = creditsDuJour.fold<double>(0, (sum, c) => sum + c.montantCredit);
        final montantPaiementsRecus = paiementsDuJour.fold<double>(0, (sum, c) => sum + (c.montantPaye ?? 0.0));
        final nombreCreditsAccordes = creditsDuJour.length;
        final nombrePaiementsRecus = paiementsDuJour.length;
        
        // Impact sur le solde virtuel (crédits accordés diminuent le virtuel)
        final impactVirtuelNegatif = montantCreditsAccordes;
        
        // Impact sur le cash (paiements reçus augmentent le cash)
        final impactCashPositif = montantPaiementsRecus;
        
        // Statistiques globales des crédits (tous statuts)
        final totalCreditsEnCours = creditsVirtuels.where((c) => 
          c.statut != CreditVirtuelStatus.paye && c.statut != CreditVirtuelStatus.annule).length;
        final montantTotalEnAttente = creditsVirtuels.where((c) => 
          c.statut != CreditVirtuelStatus.paye && c.statut != CreditVirtuelStatus.annule)
          .fold<double>(0, (sum, c) => sum + c.montantRestant);
        final creditsEnRetard = creditsVirtuels.where((c) => c.estEnRetard).length;

        // Statistiques par opérateur avec soldes USD/CDF séparés
        final statsParOperateur = <String, Map<String, dynamic>>{};
        for (var sim in sims) {
          final operateur = sim.operateur;
          if (!statsParOperateur.containsKey(operateur)) {
            statsParOperateur[operateur] = {
              'nombre_sims': 0,
              'solde_total': 0.0,
              'solde_usd': 0.0,
              'solde_cdf': 0.0,
              'transactions': 0,
              'frais': 0.0,
            };
          }
          statsParOperateur[operateur]!['nombre_sims'] += 1;
          statsParOperateur[operateur]!['solde_total'] += sim.soldeActuel;

          // Calculer les soldes USD/CDF pour cette SIM
          final simCaptures = capturesDuJour.where((t) => t.simNumero == sim.numero).toList();
          final simServices = servicesDuJour.where((t) => t.simNumero == sim.numero).toList();
          
          // Soldes par devise basés sur les transactions validées
          final capturesUSD = simServices.where((t) => t.devise == 'USD').fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final capturesCDF = simServices.where((t) => t.devise == 'CDF').fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          
          statsParOperateur[operateur]!['solde_usd'] += capturesUSD;
          statsParOperateur[operateur]!['solde_cdf'] += capturesCDF;
          statsParOperateur[operateur]!['transactions'] += simCaptures.length;
          statsParOperateur[operateur]!['frais'] += simServices.fold<double>(0, (sum, t) => sum + t.frais);
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
                (r.dateRetrait.isAtSameMomentAs(startOfDay) || r.dateRetrait.isAfter(startOfDay)) &&
                (r.dateRetrait.isAtSameMomentAs(endOfDay) || r.dateRetrait.isBefore(endOfDay))).toList();
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
                  final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
                  final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
                  flotsRecus = flotsRecus.where((f) {
                    // Utiliser created_at pour la date de réception du FLOT
                    if (f.createdAt == null) return false; // Exclure si pas de created_at
                    final dateToCheck = f.createdAt!;
                    return (dateToCheck.isAtSameMomentAs(startOfDay) || dateToCheck.isAfter(startOfDay)) &&
                           (dateToCheck.isAtSameMomentAs(endOfDay) || dateToCheck.isBefore(endOfDay));
                  }).toList();
                }
                
                // Appliquer les filtres de date sur FLOTs ENVOYÉS (DATE ENVOI)
                if (_selectedDate != null) {
                  final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
                  final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
                  flotsEnvoyes = flotsEnvoyes.where((f) {
                    // Utiliser created_at pour la date d'envoi du FLOT
                    if (f.createdAt == null) return false; // Exclure si pas de created_at
                    final dateToCheck = f.createdAt!;
                    return (dateToCheck.isAtSameMomentAs(startOfDay) || dateToCheck.isAfter(startOfDay)) &&
                           (dateToCheck.isAtSameMomentAs(endOfDay) || dateToCheck.isBefore(endOfDay));
                  }).toList();
                }
                
                final flotsRecusPhysiques = flotsRecus.fold<double>(0.0, (sum, f) => sum + f.montantNet);
                final flotsEnvoyesPhysiques = flotsEnvoyes.fold<double>(0.0, (sum, f) => sum + f.montantNet);
                final flotsRecusListe = flotsRecus; // Garder la liste pour les détails
                final flotsEnvoyesListe = flotsEnvoyes; // Garder la liste pour les détails
                
                return FutureBuilder<double>(
                  future: _getSoldeAnterieurCash(shopIdFilter, dateReference: _selectedDate),
                  builder: (BuildContext context, soldeSnapshot) {
                    final soldeAnterieur = soldeSnapshot.data ?? 0.0;
                    
                    // NOUVEAU: Charger les dépôts clients
                    return FutureBuilder<List<DepotClientModel>>(
                      future: LocalDB.instance.getAllDepotsClients(shopId: shopIdFilter),
                      builder: (BuildContext context, depotsSnapshot) {
                        var depots = depotsSnapshot.data ?? [];
                        
                        // Filtrer par date unique (DATE DEPOT)
                        if (_selectedDate != null) {
                          final startOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 0, 0, 0);
                          final endOfDay = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, 23, 59, 59);
                          depots = depots.where((d) => 
                            d.dateDepot.isAfter(startOfDay.subtract(const Duration(milliseconds: 1))) &&
                            d.dateDepot.isBefore(endOfDay.add(const Duration(milliseconds: 1)))).toList();
                        }
                        // Filtrer par SIM
                        if (_selectedSimFilter != null) {
                          depots = depots.where((d) => d.simNumero == _selectedSimFilter).toList();
                        }
                        
                        final depotsClients = depots.fold<double>(0, (sum, d) => sum + d.montant);
                        final depotsListe = depots; // Garder la liste pour les détails
                        
                        final capitalInitialCash = soldeAnterieur; // Solde antérieur de la dernière clôture
                        final flotsRecus = flotsRecusPhysiques; // FLOTs PHYSIQUES reçus
                        final flotsEnvoyes = flotsEnvoyesPhysiques; // FLOTs PHYSIQUES envoyés
                        final cashServiValue = cashServi; // Cash physique servi (toutes les SIMs)
                        // NOUVELLE FORMULE: Cash Dispo = Solde Antérieur + FLOT Reçu - FLOT Envoyé + Dépôts Clients - Cash Servi + Paiements Crédits Reçus
                        final cashDisponible = capitalInitialCash + flotsRecus - flotsEnvoyes + depotsClients - cashServiValue + impactCashPositif;
                
                        return Consumer<ShopService>(
                  builder: (BuildContext context, shopService, child) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Bouton pour afficher/masquer le filtre
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _showVueEnsembleFilter = !_showVueEnsembleFilter;
                                });
                              },
                              icon: Icon(
                                _showVueEnsembleFilter ? Icons.filter_alt_off : Icons.filter_alt,
                                size: 20,
                              ),
                              label: const SizedBox.shrink(), // Remove text, keep only icon
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF48bb78),
                                side: const BorderSide(color: Color(0xFF48bb78), width: 1.5),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          
                          // Filtre de date unique (masqué par défaut)
                          if (_showVueEnsembleFilter)
                            _buildSingleDateFilter(),
                          if (_showVueEnsembleFilter)
                            const SizedBox(height: 16),

                          // En-tête
                          Row(
                            children: [
                      const Icon(Icons.dashboard, color: Color(0xFF48bb78), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Vue d\'Ensemble',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                                                  '• ${ShopService.instance.getShopDesignation(flot.shopSourceId, existingDesignation: flot.shopSourceDesignation)}: \$${flot.montantNet.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 11, 
                                                    color: flot.statut == OperationStatus.validee ? Colors.green[700] : Colors.orange[700],
                                                  ),
                                                )
                                              ).toList(),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        _buildFinanceRow('+ Dépôts Clients', depotsClients, Colors.green),
                                        // Détails Dépôts Clients (groupés par SIM)
                                        if (depotsListe.isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: () {
                                                // Grouper les dépôts par SIM
                                                final Map<String, List<DepotClientModel>> depotsParSim = {};
                                                for (var depot in depotsListe) {
                                                  if (!depotsParSim.containsKey(depot.simNumero)) {
                                                    depotsParSim[depot.simNumero] = [];
                                                  }
                                                  depotsParSim[depot.simNumero]!.add(depot);
                                                }
                                                
                                                // Afficher chaque SIM avec son total
                                                return depotsParSim.entries.map((entry) {
                                                  final simNumero = entry.key;
                                                  final depotsSim = entry.value;
                                                  final totalSim = depotsSim.fold<double>(0, (sum, d) => sum + d.montant);
                                                  
                                                  return Text(
                                                    '• $simNumero: ${depotsSim.length} dépôt(s) = \$${totalSim.toStringAsFixed(2)}',
                                                    style: const TextStyle(
                                                      fontSize: 11, 
                                                      color: Colors.green,
                                                    ),
                                                  );
                                                }).toList();
                                              }(),
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
                            future: _getSoldeAnterieurVirtuel(shopIdFilter, dateReference: _selectedDate),
                            builder: (context, virtuelSnapshot) {
                              final soldeAnterieurVirtuel = virtuelSnapshot.data ?? 0.0;
                              final capturesDuJour = montantTotalCaptures; // Captures SANS Frais
                              final retraitsDuJour = montantTotalRetraits; // Retraits (Toutes SIMs)
                              // NOUVELLE FORMULE: Virtuel Dispo = Solde Antérieur + Captures - Retraits - Dépôts Clients - Crédits Accordés
                              final virtuelDisponible = soldeAnterieurVirtuel + capturesDuJour - retraitsDuJour - depotsClients - impactVirtuelNegatif;
                              
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
                                            // NOUVEAU: Afficher les captures par devise
                                            if (montantCapturesCdf > 0) ...[
                                              _buildFinanceRowWithCurrency('+ Captures CDF', montantCapturesCdf, 'CDF', Colors.green),
                                              const SizedBox(height: 4),
                                            ],
                                            if (montantCapturesUsd > 0) ...[
                                              _buildFinanceRowWithCurrency('+ Captures USD', montantCapturesUsd, 'USD', Colors.green),
                                              const SizedBox(height: 4),
                                            ],
                                            if (montantCapturesCdf == 0 && montantCapturesUsd == 0)
                                              _buildFinanceRow('+ Captures du jour', 0.0, Colors.green),
                                            // NOUVEAU: Afficher les en attente par devise
                                            if (montantEnAttenteCdf > 0) ...[
                                              _buildFinanceRowWithCurrency('- En Attente CDF', montantEnAttenteCdf, 'CDF', Colors.orange),
                                              const SizedBox(height: 4),
                                            ],
                                            if (montantEnAttenteUsd > 0) ...[
                                              _buildFinanceRowWithCurrency('- En Attente USD', montantEnAttenteUsd, 'USD', Colors.orange),
                                              const SizedBox(height: 4),
                                            ],
                                            if (montantEnAttenteCdf == 0 && montantEnAttenteUsd == 0)
                                              _buildFinanceRow('- En Attente', 0.0, Colors.orange),
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
                                                      ...capturesParSim.entries.map((e) {
                                                        final simNumero = e.key;
                                                        final data = e.value;
                                                        final countCdf = data['count_cdf'] as int;
                                                        final countUsd = data['count_usd'] as int;
                                                        final montantCdf = data['montant_cdf'] as double;
                                                        final montantUsd = data['montant_usd'] as double;
                                                        
                                                        return Padding(
                                                          padding: const EdgeInsets.only(bottom: 2, left: 8),
                                                          child: Column(
                                                            crossAxisAlignment: CrossAxisAlignment.start,
                                                            children: [
                                                              if (countCdf > 0)
                                                                Text(
                                                                  '• $simNumero: CDF = ${montantCdf.toStringAsFixed(0)} FC',
                                                                  style: TextStyle(fontSize: 11, color: Colors.blue[700]),
                                                                ),
                                                              if (countUsd > 0)
                                                                Text(
                                                                  '• $simNumero: USD = \$${montantUsd.toStringAsFixed(2)}',
                                                                  style: TextStyle(fontSize: 11, color: Colors.green[700]),
                                                                ),
                                                            ],
                                                          ),
                                                        );
                                                      }).toList(),
                                                    ],
                                                  ),
                                                );
                                              },
                                            ),
                                            const SizedBox(height: 8),
                                            _buildFinanceRow('- Crédits Accordés', impactVirtuelNegatif, Colors.red),
                                            if (nombreCreditsAccordes > 0)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 16, top: 4),
                                                child: Text(
                                                  '• $nombreCreditsAccordes crédit(s) accordé(s) (sortie virtuelle)',
                                                  style: TextStyle(fontSize: 11, color: Colors.red[700]),
                                                ),
                                              ),
                                            const SizedBox(height: 8),
                                            _buildFinanceRow('- Flot Envoyé Virtuel', retraitsDuJour, Colors.red),
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
                                            _buildFinanceRow('- Dépôts Clients', depotsClients, Colors.red),
                                            // Détails Dépôts Clients (groupés par SIM)
                                            if (depotsListe.isNotEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(left: 16, top: 4),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: () {
                                                    // Grouper les dépôts par SIM
                                                    final Map<String, List<DepotClientModel>> depotsParSim = {};
                                                    for (var depot in depotsListe) {
                                                      if (!depotsParSim.containsKey(depot.simNumero)) {
                                                        depotsParSim[depot.simNumero] = [];
                                                      }
                                                      depotsParSim[depot.simNumero]!.add(depot);
                                                    }
                                                    
                                                    // Afficher chaque SIM avec son total
                                                    return depotsParSim.entries.map((entry) {
                                                      final simNumero = entry.key;
                                                      final depotsSim = entry.value;
                                                      final totalSim = depotsSim.fold<double>(0, (sum, d) => sum + d.montant);
                                                      
                                                      return Text(
                                                        '• $simNumero: ${depotsSim.length} dépôt(s) = \$${totalSim.toStringAsFixed(2)}',
                                                        style: TextStyle(
                                                          fontSize: 11, 
                                                          color: Colors.red[700],
                                                        ),
                                                      );
                                                    }).toList();
                                                  }(),
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
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.orange[800],
                                                ),
                                              ),
                                              const SizedBox(height: 8),
                                              ...(() {
                                                // Grouper les non servis par SIM et par devise
                                                final Map<String, Map<String, List<VirtualTransactionModel>>> nonServisParSim = {};
                                                for (var transaction in enAttente) {
                                                  final simKey = transaction.simNumero;
                                                  final devise = transaction.devise;
                                                  if (!nonServisParSim.containsKey(simKey)) {
                                                    nonServisParSim[simKey] = {'CDF': [], 'USD': []};
                                                  }
                                                  nonServisParSim[simKey]![devise]!.add(transaction);
                                                }
                                                
                                                // Créer les widgets pour chaque SIM avec séparation par devise
                                                return nonServisParSim.entries.map((entry) {
                                                  final simNumero = entry.key;
                                                  final transactionsParDevise = entry.value;
                                                  final transactionsCdf = transactionsParDevise['CDF']!;
                                                  final transactionsUsd = transactionsParDevise['USD']!;
                                                  
                                                  final montantCdf = transactionsCdf.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
                                                  final montantUsd = transactionsUsd.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
                                                  
                                                  return Padding(
                                                    padding: const EdgeInsets.only(bottom: 8),
                                                    child: Container(
                                                      padding: const EdgeInsets.all(8),
                                                      decoration: BoxDecoration(
                                                        color: Colors.orange.shade50,
                                                        borderRadius: BorderRadius.circular(8),
                                                        border: Border.all(color: Colors.orange.shade200),
                                                      ),
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            '📱 SIM: $simNumero',
                                                            style: TextStyle(
                                                              fontSize: 15,
                                                              fontWeight: FontWeight.bold,
                                                              color: Colors.orange[900],
                                                            ),
                                                          ),
                                                          const SizedBox(height: 4),
                                                          if (transactionsCdf.isNotEmpty)
                                                            Text(
                                                              'CDF = ${montantCdf.toStringAsFixed(0)} FC',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.blue[700],
                                                              ),
                                                            ),
                                                          if (transactionsUsd.isNotEmpty)
                                                            Text(
                                                              'USD = \$${montantUsd.toStringAsFixed(2)}',
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight: FontWeight.w600,
                                                                color: Colors.green[700],
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
                          
                          // NOUVELLE SECTION: CRÉDITS VIRTUELS
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
                                  // HEADER - CRÉDITS VIRTUELS
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Colors.orange.withOpacity(0.1),
                                          Colors.orange.withOpacity(0.05),
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
                                              colors: [Colors.orange, Color(0xFFFF8F00)],
                                            ),
                                          ),
                                          child: const Icon(Icons.credit_card, color: Colors.white, size: 24),
                                        ),
                                        const SizedBox(width: 12),
                                        const Expanded(
                                          child: Text(
                                            'CRÉDITS VIRTUELS',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // BODY - DÉTAILS CRÉDITS
                                  Padding(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      children: [
                                        // Impact sur le virtuel (crédits accordés)
                                        _buildFinanceRow('Crédits Accordés (Sortie)', montantCreditsAccordes, Colors.red),
                                        if (nombreCreditsAccordes > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4),
                                            child: Text(
                                              '• $nombreCreditsAccordes crédit(s) accordé(s)',
                                              style: TextStyle(fontSize: 11, color: Colors.red[700]),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        
                                        // Impact sur le cash (paiements reçus)
                                        _buildFinanceRow('Paiements Reçus (Entrée)', montantPaiementsRecus, Colors.green),
                                        if (nombrePaiementsRecus > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 16, top: 4),
                                            child: Text(
                                              '• $nombrePaiementsRecus paiement(s) reçu(s)',
                                              style: TextStyle(fontSize: 11, color: Colors.green[700]),
                                            ),
                                          ),
                                        const SizedBox(height: 8),
                                        
                                        const Divider(),
                                        
                                        // Impact net sur les soldes
                                        _buildFinanceRow('Impact Virtuel (Négatif)', -impactVirtuelNegatif, Colors.red, isBold: true),
                                        const SizedBox(height: 4),
                                        _buildFinanceRow('Impact Cash (Positif)', impactCashPositif, Colors.green, isBold: true),
                                        
                                        const SizedBox(height: 16),
                                        
                                        // Statistiques globales
                                        if (totalCreditsEnCours > 0 || montantTotalEnAttente > 0 || creditsEnRetard > 0) ...[
                                          const Divider(height: 16),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Situation Globale des Crédits:',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orange[800],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          
                                          if (totalCreditsEnCours > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Crédits en cours:',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    '$totalCreditsEnCours crédit(s)',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          
                                          if (montantTotalEnAttente > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Montant en attente:',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    CurrencyService.instance.formatMontant(montantTotalEnAttente, 'USD'),
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.orange),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          
                                          if (creditsEnRetard > 0)
                                            Padding(
                                              padding: const EdgeInsets.only(bottom: 4),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    'Crédits en retard:',
                                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                                  ),
                                                  Text(
                                                    '$creditsEnRetard crédit(s)',
                                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.red),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // SECTION SOLDE PAR PARTENAIRE
                          FutureBuilder<Map<String, double>>(
                            future: _calculerSoldeParPartenaire(shopIdFilter, _selectedDate),
                            builder: (context, soldePartenaireSnapshot) {
                              final soldeParPartenaire = soldePartenaireSnapshot.data ?? {};
                              
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
                                      // HEADER - SOLDE PAR PARTENAIRE
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.indigo.withOpacity(0.1),
                                              Colors.indigo.withOpacity(0.05),
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
                                                  colors: [Colors.indigo, Color(0xFF3F51B5)],
                                                ),
                                              ),
                                              child: const Icon(Icons.people, color: Colors.white, size: 24),
                                            ),
                                            const SizedBox(width: 12),
                                            const Expanded(
                                              child: Text(
                                                'SOLDE PAR PARTENAIRE',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // BODY - DETAILS PARTENAIRES
                                      Padding(
                                        padding: const EdgeInsets.all(20),
                                        child: Column(
                                          children: [
                                            if (soldeParPartenaire.isEmpty)
                                              Text(
                                                'Aucune opération partenaire trouvée',
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey[600],
                                                  fontStyle: FontStyle.italic,
                                                ),
                                              )
                                            else ...[
                                              // Grouper par créances et dettes
                                              () {
                                                final creances = soldeParPartenaire.entries.where((e) => e.value > 0).toList();
                                                final dettes = soldeParPartenaire.entries.where((e) => e.value < 0).toList();
                                                final equilibres = soldeParPartenaire.entries.where((e) => e.value == 0).toList();
                                                
                                                return Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    // CRÉANCES (Nous devons)
                                                    if (creances.isNotEmpty) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.red.shade50,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.red.shade200),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Icon(Icons.arrow_upward, color: Colors.red.shade700, size: 16),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  'CRÉANCES',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.red.shade700,
                                                                  ),
                                                                ),
                                                                const Spacer(),
                                                                Text(
                                                                  '+${creances.fold<double>(0, (sum, e) => sum + e.value).toStringAsFixed(2)} USD',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.red.shade700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            ...creances.map((entry) => Padding(
                                                              padding: const EdgeInsets.only(left: 24, bottom: 4),
                                                              child: Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      entry.key,
                                                                      style: const TextStyle(fontSize: 11),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '+${entry.value.toStringAsFixed(2)} USD',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Colors.red.shade600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            )),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 12),
                                                    ],
                                                    
                                                    // DETTES (Ils nous doivent)
                                                    if (dettes.isNotEmpty) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.green.shade50,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.green.shade200),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Icon(Icons.arrow_downward, color: Colors.green.shade700, size: 16),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  'DETTES',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.green.shade700,
                                                                  ),
                                                                ),
                                                                const Spacer(),
                                                                Text(
                                                                  '${dettes.fold<double>(0, (sum, e) => sum + e.value).toStringAsFixed(2)} USD',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.green.shade700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            ...dettes.map((entry) => Padding(
                                                              padding: const EdgeInsets.only(left: 24, bottom: 4),
                                                              child: Row(
                                                                children: [
                                                                  Expanded(
                                                                    child: Text(
                                                                      entry.key,
                                                                      style: const TextStyle(fontSize: 11),
                                                                    ),
                                                                  ),
                                                                  Text(
                                                                    '${entry.value.toStringAsFixed(2)} USD',
                                                                    style: TextStyle(
                                                                      fontSize: 11,
                                                                      fontWeight: FontWeight.w600,
                                                                      color: Colors.green.shade600,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            )),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(height: 12),
                                                    ],
                                                    
                                                    // ÉQUILIBRÉS (si il y en a)
                                                    if (equilibres.isNotEmpty) ...[
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                                        decoration: BoxDecoration(
                                                          color: Colors.grey.shade100,
                                                          borderRadius: BorderRadius.circular(8),
                                                          border: Border.all(color: Colors.grey.shade300),
                                                        ),
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Icon(Icons.balance, color: Colors.grey.shade700, size: 16),
                                                                const SizedBox(width: 8),
                                                                Text(
                                                                  'ÉQUILIBRÉS (${equilibres.length})',
                                                                  style: TextStyle(
                                                                    fontSize: 12,
                                                                    fontWeight: FontWeight.bold,
                                                                    color: Colors.grey.shade700,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            const SizedBox(height: 8),
                                                            ...equilibres.map((entry) => Padding(
                                                              padding: const EdgeInsets.only(left: 24, bottom: 4),
                                                              child: Text(
                                                                entry.key,
                                                                style: TextStyle(
                                                                  fontSize: 11,
                                                                  color: Colors.grey.shade600,
                                                                ),
                                                              ),
                                                            )),
                                                          ],
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                );
                                              }(),
                                              const Divider(),
                                              () {
                                                final totalSolde = soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                                                final color = totalSolde > 0 
                                                  ? Colors.red[700] 
                                                  : totalSolde < 0 
                                                    ? Colors.green[700] 
                                                    : Colors.grey[700];
                                                return _buildFinanceRow(
                                                  'SOLDE NET ', 
                                                  totalSolde, 
                                                  color!, 
                                                  isBold: true
                                                );
                                              }(),
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
                                    future: _getSoldeFraisAnterieur(shopIdFilter, dateReference: _selectedDate),
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
                                                    _buildFinanceRow('+ Frais du jour (captures)', fraisPercus, Colors.green),
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
                            future: _getSoldeFraisAnterieur(shopIdFilter, dateReference: _selectedDate),
                            builder: (context, fraisAntSnapshot) {
                              final fraisAnterieur = fraisAntSnapshot.data ?? 0.0;
                              
                              return FutureBuilder<double>(
                                future: _getSortieFrais(shopIdFilter, _selectedDate),
                                builder: (context, sortieFraisSnapshot) {
                                  final sortieFrais = sortieFraisSnapshot.data ?? 0.0;
                                  final soldeFraisTotal = fraisAnterieur + fraisPercus - sortieFrais;
                                  
                                  return FutureBuilder<double>(
                                    future: _getSoldeAnterieurVirtuel(shopIdFilter, dateReference: _selectedDate),
                                    builder: (context, virtuelSoldeSnapshot) {
                                      final soldeAnterieurVirtuel = virtuelSoldeSnapshot.data ?? 0.0;
                                      final capturesDuJour = montantTotalCaptures;  // SANS frais
                                      final retraitsDuJour = montantTotalRetraits;
                                      // FORMULE: Virtuel Dispo = Solde Antérieur + Captures - Retraits - Dépôts Clients
                                      final virtuelDisponible = soldeAnterieurVirtuel + capturesDuJour - retraitsDuJour - depotsClients;
                                      final nonServi = montantEnAttente; // Captures non servies
                                      
                                      return FutureBuilder<Map<String, double>>(
                                        future: _getCapitalNetData(shopIdFilter ?? currentShopId, cashDisponible, virtuelDisponible, enAttente),
                                        builder: (context, capitalSnapshot) {
                                          final capitalData = capitalSnapshot.data ?? {};
                                          final shopsNousDoivent = capitalData['shopsNousDoivent'] ?? 0.0;
                                          final shopsNousDevons = capitalData['shopsNousDevons'] ?? 0.0;
                                          
                                          return FutureBuilder<Map<String, double>>(
                                            future: _calculerSoldeParPartenaire(shopIdFilter, _selectedDate),
                                            builder: (context, partenaireSnapshot) {
                                              final soldeParPartenaire = partenaireSnapshot.data ?? {};
                                              final totalSoldePartenaire = soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                                              
                                              // CAPITAL NET = Cash Disponible + Virtuel Disponible + Shop qui Nous qui Doivent - Shop que Nous que Devons - Non Servi - Solde FRAIS - Solde Net Partenaires
                                              // LOGIQUE PARTENAIRES: Si dettes > créances (totalSoldePartenaire < 0) = on SOUSTRAIT (impact négatif)
                                              // Si créances > dettes (totalSoldePartenaire > 0) = on SOUSTRAIT aussi (nous devons = impact négatif)
                                              final capitalNet = cashDisponible + virtuelDisponible + shopsNousDoivent - shopsNousDevons - nonServi - soldeFraisTotal - totalSoldePartenaire;
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
                                                _buildFinanceRow('- Shops que Nous que Devons', shopsNousDevons, Colors.red),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('- Non Servi (Virtuel)', nonServi, Colors.red),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('- Solde FRAIS', soldeFraisTotal, Colors.red),
                                                const SizedBox(height: 8),
                                                _buildFinanceRow('- Solde Net Partenaires', totalSoldePartenaire, totalSoldePartenaire >= 0 ? Colors.red : Colors.green),
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
                                                soldeFraisTotal, // Ajouter le solde frais total
                                                totalSoldePartenaire, // Ajouter le solde net partenaires
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

                          // NOUVELLE SECTION: Shops qui Nous qui Doivent
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
                                  // Shops qui Nous qui Doivent (Créances)
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
                                  
                                  // Shops que Nous que Devons (Dettes)
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
              }, // Fermeture builder FutureBuilder dépôts clients
            ); // Fermeture FutureBuilder dépôts clients  
              }, // Fermeture builder FutureBuilder soldeAnterieur
            ); // Fermeture FutureBuilder soldeAnterieur
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

        // Appliquer les filtres de dates (par défaut: aujourd'hui)
        final dateDebut = _dateDebutFilter ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final dateFin = _dateFinFilter ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
        
        transactions = transactions
            .where((t) => t.dateEnregistrement.isAfter(dateDebut.subtract(const Duration(milliseconds: 1))) && t.dateEnregistrement.isBefore(dateFin.add(const Duration(milliseconds: 1))))
            .toList();
        
        // Filtrer par SIM (si sélectionnée)
        if (_selectedSimFilter != null) {
          transactions = transactions
              .where((t) => t.simNumero == _selectedSimFilter)
              .toList();
          sims = sims.where((s) => s.numero == _selectedSimFilter).toList();
        }

        // NOUVEAU: Charger les retraits virtuels ET dépôts clients
        return FutureBuilder<List<RetraitVirtuelModel>>(
          future: LocalDB.instance.getAllRetraitsVirtuels(shopSourceId: shopIdFilter),
          builder: (BuildContext context, retraitsSnapshot) {
            var retraits = retraitsSnapshot.data ?? [];
            
            // Appliquer les filtres de dates sur les retraits (par défaut: aujourd'hui)
            retraits = retraits.where((r) => r.dateRetrait.isAfter(dateDebut.subtract(const Duration(milliseconds: 1))) && r.dateRetrait.isBefore(dateFin.add(const Duration(milliseconds: 1)))).toList();
            
            // Filtrer par SIM
            if (_selectedSimFilter != null) {
              retraits = retraits.where((r) => r.simNumero == _selectedSimFilter).toList();
            }
            
            // Charger les dépôts clients
            return FutureBuilder<List<DepotClientModel>>(
              future: LocalDB.instance.getAllDepotsClients(shopId: shopIdFilter),
              builder: (BuildContext context, depotsSnapshot) {
                var depots = depotsSnapshot.data ?? [];
                
                // Appliquer les filtres de dates sur les dépôts (par défaut: aujourd'hui)
                depots = depots.where((d) => d.dateDepot.isAfter(dateDebut.subtract(const Duration(milliseconds: 1))) && d.dateDepot.isBefore(dateFin.add(const Duration(milliseconds: 1)))).toList();
                
                // Filtrer par SIM
                if (_selectedSimFilter != null) {
                  depots = depots.where((d) => d.simNumero == _selectedSimFilter).toList();
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
          
          // NOUVEAU: Séparer par devise pour les validées
          final valideesCdf = validees.where((t) => t.devise == 'CDF').toList();
          final valideesUsd = validees.where((t) => t.devise == 'USD').toList();
          final totalVirtuelCdf = valideesCdf.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final totalVirtuelUsd = valideesUsd.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final totalVirtuel = totalVirtuelUsd + CurrencyService.instance.convertCdfToUsd(totalVirtuelCdf);
          
          // NOUVEAU: Séparer par devise pour les en attente
          final enAttenteCdf = enAttente.where((t) => t.devise == 'CDF').toList();
          final enAttenteUsd = enAttente.where((t) => t.devise == 'USD').toList();
          final montantEnAttenteCdf = enAttenteCdf.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final montantEnAttenteUsd = enAttenteUsd.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final montantEnAttente = montantEnAttenteUsd + CurrencyService.instance.convertCdfToUsd(montantEnAttenteCdf);
          
          final totalFrais = validees.fold<double>(0, (sum, t) => sum + t.frais);
          final totalCash = validees.fold<double>(0, (sum, t) => sum + t.montantCash);
          
          // Calculer le solde pour la période filtrée (avec filtres appliqués)
          final simDepots = depots.where((d) => d.simNumero == sim.numero).toList();
          final nbDepotsFiltre = simDepots.length;
          final montantDepotsFiltre = simDepots.fold<double>(0, (sum, d) => sum + d.montant);
          final montantCaptures = simTransactions.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final soldePeriode = montantCaptures - montantTotalRetraits - montantDepotsFiltre;
          
          // NOUVEAU: Calculer le solde GLOBAL (SANS FILTRE - toutes les transactions)
          // Récupérer TOUTES les transactions de cette SIM (sans filtre de date, mais avec filtre shop)
          var toutesTransactionsSim = vtService.transactions.where((t) => t.simNumero == sim.numero).toList();
          if (shopIdFilter != null) {
            toutesTransactionsSim = toutesTransactionsSim.where((t) => t.shopId == shopIdFilter).toList();
          }
          
          // Récupérer TOUS les retraits (sans filtre de date, mais avec filtre shop)
          final allRetraits = retraitsSnapshot.data ?? [];
          var tousRetraitsSim = allRetraits.where((r) => r.simNumero == sim.numero).toList();
          if (shopIdFilter != null) {
            tousRetraitsSim = tousRetraitsSim.where((r) => r.shopSourceId == shopIdFilter).toList();
          }
          
          // Récupérer TOUS les dépôts clients (sans filtre de date, mais avec filtre shop)
          final allDepots = depotsSnapshot.data ?? [];
          var tousDepotsSim = allDepots.where((d) => d.simNumero == sim.numero).toList();
          if (shopIdFilter != null) {
            tousDepotsSim = tousDepotsSim.where((d) => d.shopId == shopIdFilter).toList();
          }
          
          // Formule GLOBALE: Somme Captures - Somme Retraits - Somme Dépôts (TOUTES PÉRIODES)
          final toutesCaptures = toutesTransactionsSim.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
          final tousRetraits = tousRetraitsSim.fold<double>(0, (sum, r) => sum + r.montant);
          final tousDepots = tousDepotsSim.fold<double>(0, (sum, d) => sum + d.montant);
          
          // FORMULE SIMPLIFIÉE: Captures - Retraits - Dépôts (sans solde antérieur pour éviter async)
          // Note: Le solde antérieur sera géré dans une future amélioration avec FutureBuilder
          final soldeGlobalCalcule = toutesCaptures - tousRetraits - tousDepots;
          
          // Debugging: Afficher les valeurs de calcul dans la console
          debugPrint('SIM ${sim.numero} - Calcul Solde:');
          debugPrint('  Captures: \$${toutesCaptures.toStringAsFixed(2)} (${toutesTransactionsSim.length} transactions)');
          debugPrint('  Retraits: \$${tousRetraits.toStringAsFixed(2)} (${tousRetraitsSim.length} retraits)');
          debugPrint('  Dépôts: \$${tousDepots.toStringAsFixed(2)} (${tousDepotsSim.length} dépôts)');
          debugPrint('  Solde calculé: \$${soldeGlobalCalcule.toStringAsFixed(2)}');
          debugPrint('  Solde BDD: \$${sim.soldeActuel.toStringAsFixed(2)}');
          debugPrint('  FORMULE: ${toutesCaptures.toStringAsFixed(2)} - ${tousRetraits.toStringAsFixed(2)} - ${tousDepots.toStringAsFixed(2)} = ${soldeGlobalCalcule.toStringAsFixed(2)}');
          debugPrint('---');

          simStats[sim.numero] = {
            'sim': sim,
            'nb_total': simTransactions.length,
            'nb_validees': validees.length,
            'nb_en_attente': enAttente.length,
            'nb_retraits': nbRetraits,
            'nb_depots_filtre': nbDepotsFiltre,
            'montant_retraits': montantTotalRetraits,
            'montant_depots_filtre': montantDepotsFiltre,
            'montant_captures': montantCaptures,
            'total_virtuel': totalVirtuel,
            'total_frais': totalFrais,
            'total_cash': totalCash,
            'montant_en_attente': montantEnAttente,
            // NOUVEAU: Données par devise
            'total_virtuel_cdf': totalVirtuelCdf,
            'total_virtuel_usd': totalVirtuelUsd,
            'nb_validees_cdf': valideesCdf.length,
            'nb_validees_usd': valideesUsd.length,
            'montant_en_attente_cdf': montantEnAttenteCdf,
            'montant_en_attente_usd': montantEnAttenteUsd,
            'nb_en_attente_cdf': enAttenteCdf.length,
            'nb_en_attente_usd': enAttenteUsd.length,
            'solde_actuel': sim.soldeActuel, // Solde de la BDD (peut être incorrect)
            'solde_global': soldeGlobalCalcule, // Solde calculé (TOUTES périodes) - TODO: Ajouter soldes antérieurs
            'solde_periode': soldePeriode, // Solde calculé pour la période filtrée
            'total_captures_global': toutesCaptures, // Pour le récapitulatif
            'total_retraits_global': tousRetraits, // Pour le récapitulatif
            'total_depots_global': tousDepots, // Pour le récapitulatif
          };
        }
        
        // Calculer les totaux globaux pour toutes les SIMs
        final grandTotalCaptures = simStats.values.fold<double>(0, (sum, stats) => sum + (stats['total_captures_global'] as double));
        final grandTotalRetraits = simStats.values.fold<double>(0, (sum, stats) => sum + (stats['total_retraits_global'] as double));
        final grandTotalDepots = simStats.values.fold<double>(0, (sum, stats) => sum + (stats['total_depots_global'] as double));
        final grandSolde = grandTotalCaptures - grandTotalRetraits - grandTotalDepots;

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
              
              // Récapitulatif global
              Card(
                elevation: 4,
                color: const Color(0xFF48bb78).withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.summarize, color: Color(0xFF48bb78), size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Récapitulatif Global',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalCard(
                              'Total Captures',
                              grandTotalCaptures,
                              Icons.add_circle,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTotalCard(
                              'Total Retraits',
                              grandTotalRetraits,
                              Icons.remove_circle,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTotalCard(
                              'Total Dépôts',
                              grandTotalDepots,
                              Icons.account_balance,
                              Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildTotalCard(
                              'Solde Global',
                              grandSolde,
                              Icons.account_balance_wallet,
                              const Color(0xFF48bb78),
                              isBold: true,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
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
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sim.operateur,
                          style: const TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            // USD Balance
                            if (stats['total_virtuel_usd'] > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF48bb78).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_wallet, size: 12, color: Color(0xFF48bb78)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'USD ${stats['total_virtuel_usd'].toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF48bb78),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (stats['total_virtuel_usd'] > 0 && stats['total_virtuel_cdf'] > 0)
                              const SizedBox(width: 8),
                            // CDF Balance
                            if (stats['total_virtuel_cdf'] > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.account_balance_wallet, size: 12, color: Colors.blue),
                                    const SizedBox(width: 4),
                                    Text(
                                      'CDF ${stats['total_virtuel_cdf'].toStringAsFixed(0)}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            // Show zero if no balances
                            if (stats['total_virtuel_usd'] == 0 && stats['total_virtuel_cdf'] == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.account_balance_wallet, size: 12, color: Colors.grey),
                                    SizedBox(width: 4),
                                    Text(
                                      'Aucun solde',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // SECTION 1: PÉRIODE FILTRÉE
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue, width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.date_range, color: Colors.blue, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _dateDebutFilter != null || _dateFinFilter != null
                                              ? 'Période: ${_dateDebutFilter != null ? DateFormat('dd/MM/yyyy').format(_dateDebutFilter!) : "..."} - ${_dateFinFilter != null ? DateFormat('dd/MM/yyyy').format(_dateFinFilter!) : "..."}'
                                              : 'Période: ${DateFormat('dd/MM/yyyy').format(DateTime.now())} (Aujourd\'hui)',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSimStatRow('Transactions Total', '${stats['nb_total']}', Icons.receipt_long, Colors.blue),
                                  _buildSimStatRow('Servies', '${stats['nb_validees']}', Icons.check_circle, Colors.green),
                                  _buildSimStatRowWithEnAttenteBreakdown('En Attente', stats, Icons.hourglass_empty, Colors.orange),
                                  const Divider(height: 16),
                                  _buildSimStatRowWithCurrencyBreakdown('Captures', stats, 'periode', Icons.add_circle, const Color(0xFF48bb78)),
                                  _buildSimStatRow('Total Retraits', 'USD ${stats['montant_retraits'].toStringAsFixed(2)}', Icons.remove_circle, Colors.red),
                                  _buildSimStatRow('Total Dépôts', 'USD ${stats['montant_depots_filtre'].toStringAsFixed(2)}', Icons.account_balance, Colors.purple),
                                  const Divider(height: 16),
                                  _buildSimStatRow('Solde Période', 'USD ${stats['solde_periode'].toStringAsFixed(2)}', Icons.trending_up, Colors.blue, isBold: true),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            // SECTION 2: GLOBAL (TOUTES PÉRIODES)
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF48bb78).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFF48bb78), width: 2),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(Icons.all_inclusive, color: Color(0xFF48bb78), size: 20),
                                      SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Global SIM (Toutes Périodes)',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF48bb78),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  _buildSimStatRowWithCurrencyBreakdown('Total Captures', stats, 'global', Icons.add_circle, Colors.green),
                                  _buildSimStatRow('Total Retraits', 'USD ${stats['total_retraits_global'].toStringAsFixed(2)}', Icons.remove_circle, Colors.orange),
                                  _buildSimStatRow('Total Dépôts', 'USD ${stats['total_depots_global'].toStringAsFixed(2)}', Icons.account_balance, Colors.purple),
                                  const Divider(height: 16),
                                  _buildSimStatRow('Solde Global', 'USD ${stats['solde_global'].toStringAsFixed(2)}', Icons.account_balance_wallet, const Color(0xFF48bb78), isBold: true),
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

        // FRAIS GLOBAUX (toutes périodes)
        final toutesTransactionsValidees = service.transactions
            .where((t) => t.shopId == currentShopId && t.statut == VirtualTransactionStatus.validee)
            .toList();
        final totalFraisGlobal = toutesTransactionsValidees.fold<double>(0, (sum, t) => sum + t.frais);
        final totalVirtuelGlobal = toutesTransactionsValidees.fold<double>(0, (sum, t) => sum + t.montantVirtuel);

        // FRAIS PÉRIODE (avec filtre de dates, par défaut: aujourd'hui)
        final dateDebut = _dateDebutFilter ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
        final dateFin = _dateFinFilter ?? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 23, 59, 59);
        
        var transactions = service.transactions
            .where((t) => t.shopId == currentShopId && t.statut == VirtualTransactionStatus.validee)
            .toList();

        // Appliquer les filtres de dates (toujours) - FRAIS basés sur dateEnregistrement
        transactions = transactions
            .where((t) => t.dateEnregistrement.isAfter(dateDebut.subtract(const Duration(milliseconds: 1))) && t.dateEnregistrement.isBefore(dateFin.add(const Duration(milliseconds: 1))))
            .toList();

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

        // Statistiques de la période
        final totalFraisPeriode = transactions.fold<double>(0, (sum, t) => sum + t.frais);
        final totalVirtuelPeriode = transactions.fold<double>(0, (sum, t) => sum + t.montantVirtuel);
        final moyenneFrais = transactions.isNotEmpty ? totalFraisPeriode / transactions.length : 0.0;
        final tauxMoyenFrais = totalVirtuelPeriode > 0 ? (totalFraisPeriode / totalVirtuelPeriode) * 100 : 0.0;

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
              
              // Récapitulatif: Frais Globaux vs Période
              Row(
                children: [
                  // FRAIS GLOBAUX
                  Expanded(
                    child: Card(
                      elevation: 3,
                      color: const Color(0xFF48bb78).withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.all_inclusive, color: Color(0xFF48bb78), size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Frais Globaux',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '\$${totalFraisGlobal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF48bb78),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${toutesTransactionsValidees.length} transactions',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // FRAIS PÉRIODE
                  Expanded(
                    child: Card(
                      elevation: 3,
                      color: Colors.purple.withOpacity(0.05),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.date_range, color: Colors.purple, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _dateDebutFilter != null || _dateFinFilter != null
                                        ? 'Frais Période'
                                        : 'Frais Aujourd\'hui',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '\$${totalFraisPeriode.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.purple,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${transactions.length} transactions',
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Résumé statistiques période
              Card(
                elevation: 3,
                color: Colors.purple.withOpacity(0.05),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Détails Période',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      _buildSimStatRow('Total Transactions', '${transactions.length}', Icons.receipt, Colors.blue),
                      _buildSimStatRow('Total Frais', '\$${totalFraisPeriode.toStringAsFixed(2)}', Icons.attach_money, Colors.purple, isBold: true),
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

  /// Onglet Clôture par SIM
  Widget _buildClotureParSimTab() {
    return const ClotureVirtuelleParSimWidget();
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

  /// Ligne de statistique avec détail des devises pour les transactions en attente
  Widget _buildSimStatRowWithEnAttenteBreakdown(String label, Map<String, dynamic> stats, IconData icon, Color color) {
    final totalCdf = stats['montant_en_attente_cdf'] ?? 0.0;
    final totalUsd = stats['montant_en_attente_usd'] ?? 0.0;
    final countCdf = stats['nb_en_attente_cdf'] ?? 0;
    final countUsd = stats['nb_en_attente_usd'] ?? 0;
    final totalCount = countCdf + countUsd;
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label ($totalCount)',
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (totalUsd > 0)
                Text(
                  'USD ${totalUsd.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              if (totalCdf > 0)
                Text(
                  'CDF ${totalCdf.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              if (totalCdf == 0 && totalUsd == 0)
                Text(
                  '0',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Ligne de statistique avec détail des devises pour les captures
  Widget _buildSimStatRowWithCurrencyBreakdown(String label, Map<String, dynamic> stats, String type, IconData icon, Color color) {
    double totalCdf, totalUsd;
    int countCdf, countUsd;
    
    if (type == 'periode') {
      // Pour la période filtrée, utiliser les montants des transactions filtrées
      totalCdf = stats['total_virtuel_cdf'] ?? 0.0;
      totalUsd = stats['total_virtuel_usd'] ?? 0.0;
      countCdf = stats['nb_validees_cdf'] ?? 0;
      countUsd = stats['nb_validees_usd'] ?? 0;
    } else {
      // Pour global, on utilise le montant total (déjà converti)
      totalCdf = 0.0; // On n'a pas le détail global par devise
      totalUsd = stats['total_captures_global'] ?? 0.0;
      countCdf = 0;
      countUsd = stats['nb_validees'] ?? 0;
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (totalUsd > 0)
                Text(
                  'USD ${totalUsd.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              if (totalCdf > 0)
                Text(
                  'CDF ${totalCdf.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              if (totalCdf == 0 && totalUsd == 0)
                Text(
                  '0.00',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// Carte pour afficher un total dans le récapitulatif
  Widget _buildTotalCard(String label, double value, IconData icon, Color color, {bool isBold = false}) {
    // Determine currency display based on label
    String currencyDisplay;
    if (label.contains('Captures')) {
      currencyDisplay = 'Mixed ${value.toStringAsFixed(2)}';
    } else {
      currencyDisplay = 'USD ${value.toStringAsFixed(2)}';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            currencyDisplay,
            style: TextStyle(
              fontSize: isBold ? 20 : 18,
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
  
  /// Obtenir les captures groupées par SIM avec gestion des devises
  Future<Map<String, Map<String, dynamic>>> _getCapturesParSim(int? shopId, List<VirtualTransactionModel> captures) async {
    final Map<String, Map<String, dynamic>> capturesParSim = {};
    
    for (final transaction in captures) {
      final simKey = transaction.simNumero;
      if (!capturesParSim.containsKey(simKey)) {
        capturesParSim[simKey] = {
          'count': 0, 
          'montant_cdf': 0.0,
          'montant_usd': 0.0,
          'count_cdf': 0,
          'count_usd': 0,
        };
      }
      capturesParSim[simKey]!['count'] += 1;
      
      // Séparer par devise
      if (transaction.devise == 'CDF') {
        capturesParSim[simKey]!['montant_cdf'] += transaction.montantVirtuel;
        capturesParSim[simKey]!['count_cdf'] += 1;
      } else {
        capturesParSim[simKey]!['montant_usd'] += transaction.montantVirtuel;
        capturesParSim[simKey]!['count_usd'] += 1;
      }
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

  /// Obtenir les détails des shops (qui Nous qui Doivent et que Nous que Devons)
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
          '\$${amount.toStringAsFixed(2)} USD',
          style: TextStyle(
            fontSize: fontSize + 2,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  /// Widget pour afficher un montant avec sa devise originale (CDF ou USD)
  Widget _buildFinanceRowWithCurrency(String label, double amount, String currency, Color color, {bool isBold = false, double fontSize = 14}) {
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
          currency == 'CDF' 
            ? '${amount.toStringAsFixed(0)} FC'
            : '\$${amount.toStringAsFixed(2)} USD',
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
      child: SingleChildScrollView(
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
              const SizedBox(width: 12),
              // NOUVEAU: Filtre par devise
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _deviseFilter,
                  decoration: const InputDecoration(
                    labelText: 'Devise',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    prefixIcon: Icon(Icons.currency_exchange, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Toutes')),
                    DropdownMenuItem(
                      value: 'USD',
                      child: Row(
                        children: [
                          Icon(Icons.attach_money, size: 16, color: Colors.green),
                          SizedBox(width: 8),
                          Text('USD (\$)'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'CDF',
                      child: Row(
                        children: [
                          Icon(Icons.monetization_on, size: 16, color: Colors.blue),
                          SizedBox(width: 8),
                          Text('CDF (FC)'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _deviseFilter = value;
                    });
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
                      : 'début'),
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
                      : 'fin'),
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
                    _deviseFilter = null;
                  });
                },
              ),
            ],
          ),
        ],
        ),
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
                          fontSize: 14,
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
                    'Virtuel: ${CurrencyUtils.formatAmount(transaction.montantVirtuel, transaction.devise)}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                  Text(
                    'Frais: ${CurrencyUtils.formatAmount(transaction.frais, transaction.devise)}',
                    style: TextStyle(color: Colors.grey[700]),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Enregistré: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateEnregistrement)}',
                style: TextStyle(fontSize: 10, color: Colors.grey[600]),
              ),
              if (transaction.clientNom != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Client: ${transaction.clientNom} - ${transaction.clientTelephone}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
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
                            fontSize: 12,
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

  /// Formater le montant cash avec conversion si nécessaire
  String _formatCashAmount(VirtualTransactionModel transaction) {
    if (transaction.devise == 'CDF') {
      // Pour les transactions CDF, calculer le USD avec le taux actuel
      final montantApresCommission = transaction.montantVirtuel - transaction.frais;
      final cashUsd = CurrencyService.instance.convertCdfToUsd(montantApresCommission);
      return '\$${cashUsd.toStringAsFixed(2)} USD (converti de ${montantApresCommission.toStringAsFixed(0)} CDF)';
    } else {
      // Pour les transactions USD, afficher directement
      return '\$${transaction.montantCash.toStringAsFixed(2)} USD';
    }
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
              _buildDetailRow('Montant Virtuel', CurrencyUtils.formatAmount(transaction.montantVirtuel, transaction.devise)),
              _buildDetailRow('Frais', CurrencyUtils.formatAmount(transaction.frais, transaction.devise)),
              _buildDetailRow('Cash à Servir', _formatCashAmount(transaction)),
              if (transaction.devise == 'CDF')
                _buildDetailRow('Devise Originale', 'CDF (Franc Congolais)'),
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

  /// Calculer le solde par partenaire pour les transactions virtuelles
  /// Adapté de la logique du rapport de clôture
  Future<Map<String, double>> _calculerSoldeParPartenaire(int? shopId, DateTime? dateRapport) async {
    if (shopId == null) return {};
    
    final dateReference = dateRapport ?? DateTime.now();
    
    try {
      // Charger toutes les opérations depuis LocalDB
      final operations = await LocalDB.instance.getAllOperations();
      
      // Charger tous les shops pour avoir leurs noms
      final shops = await LocalDB.instance.getAllShops();
      final shopsMap = {for (var shop in shops) shop.id: shop.designation};
      
      // DEPOT = TOUS les dépôts où nous sommes destinataires (shopDestination)
      // + INCLURE les opérations administratives (initialisations) où nous sommes source
      // CHANGEMENT: Inclut TOUTES les opérations jusqu'à la date du rapport (solde cumulatif)
      final depotsRecus = operations.where((op) =>
          op.type == OperationType.depot &&
          ((op.shopDestinationId == shopId) || 
           (op.shopSourceId == shopId && op.isAdministrative)) && // INCLURE les initialisations
          op.dateOp.isBefore(dateReference.add(const Duration(days: 1))) // Jusqu'à la fin du jour du rapport
      ).toList();
      
      // RETRAIT = TOUS les retraits où nous sommes destinataires (shopDestination)
      // + INCLURE les retraits administratifs (dettes initialisées) où nous sommes source
      // CHANGEMENT: Inclut TOUTES les opérations jusqu'à la date du rapport (solde cumulatif)
      final retraitsServis = operations.where((op) =>
          op.type == OperationType.retrait &&
          ((op.shopDestinationId == shopId) || 
           (op.shopSourceId == shopId && op.isAdministrative)) && // INCLURE les dettes initialisées
          op.dateOp.isBefore(dateReference.add(const Duration(days: 1))) // Jusqu'à la fin du jour du rapport
      ).toList();
      
      // Calculer le solde net par partenaire
      final Map<String, double> soldeParPartenaire = {};
      
      // Ajouter les dépôts (positif - nous devons au partenaire)
      for (var op in depotsRecus) {
        String partenaireKey;
        
        if (op.isAdministrative) {
          // Pour les initialisations administratives, utiliser le nom du client directement
          final clientName = op.clientNom ?? op.destinataire ?? 'Client inconnu';
          partenaireKey = '$clientName';
        } else {
          // Pour les opérations normales, utiliser uniquement le nom du client pour grouper correctement
          final clientName = op.clientNom ?? op.destinataire ?? 'Client inconnu';
          partenaireKey = '$clientName';
        }
        
        soldeParPartenaire[partenaireKey] = (soldeParPartenaire[partenaireKey] ?? 0.0) + op.montantNet;
      }
      
      // Soustraire les retraits (négatif - le partenaire nous doit)
      for (var op in retraitsServis) {
        String partenaireKey;
        
        if (op.isAdministrative) {
          // Pour les dettes initialisées administratives, utiliser le nom du client directement
          final clientName = op.clientNom ?? op.destinataire ?? 'Client inconnu';
          partenaireKey = '$clientName';
        } else {
          // Pour les opérations normales, utiliser uniquement le nom du client pour grouper correctement
          final clientName = op.clientNom ?? op.destinataire ?? 'Client inconnu';
          partenaireKey = '$clientName';
        }
        
        soldeParPartenaire[partenaireKey] = (soldeParPartenaire[partenaireKey] ?? 0.0) - op.montantNet;
      }
      
      debugPrint('🔟 SOLDE PAR PARTENAIRE - Virtuel');
      debugPrint('   Dépôts reçus: ${depotsRecus.length}');
      debugPrint('   Retraits servis: ${retraitsServis.length}');
      debugPrint('   Solde calculé par partenaire: ${soldeParPartenaire.length} entrées');
      
      return soldeParPartenaire;
    } catch (e) {
      debugPrint('❌ Erreur calcul solde par partenaire: $e');
      return {};
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
    double soldeFraisTotal, // NOUVEAU: Ajouter le solde frais total
    double totalSoldePartenaire, // NOUVEAU: Ajouter le solde net partenaires
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
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        '$shopName - $agentName',
                        style: const pw.TextStyle(
                          fontSize: 11,
                          color: PdfColors.white,
                        ),
                      ),
                      pw.Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(dateNow),
                        style: const pw.TextStyle(
                          fontSize: 10,
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
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                _buildPdfRow('Captures du jour', montantTotalCaptures),
                _buildPdfRow('Retraits du jour', montantTotalRetraits),
                pw.Divider(),
                _buildPdfRow('TOTAL', virtuelDisponible, isBold: true),
                pw.SizedBox(height: 20),
                
                // CAPITAL NET
                // Formule: Cash Disponible + Virtuel Disponible + Shop qui Nous qui Doivent - Shop que Nous que Devons - Non Servi - Solde FRAIS + Solde Net Partenaires
                pw.Text(
                  'CAPITAL NET',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                pw.Divider(),
                _buildPdfRow('Cash Disponible', cashDisponible),
                _buildPdfRow('+ Virtuel Disponible', virtuelDisponible),
                _buildPdfRow('+ Shop qui Nous Doivent (DIFF. DETTES)', shopsNousDoivent),
                _buildPdfRow('- Shop que Nous Devons', shopsNousDevons),
                _buildPdfRow('- Non Servi (Virtuel)', nonServi),
                _buildPdfRow('- Solde FRAIS', soldeFraisTotal),
                _buildPdfRow('+ Solde Net Partenaires', totalSoldePartenaire),
                pw.Divider(),
                _buildPdfRow('= CAPITAL NET', capitalNet, isBold: true, fontSize: 16),
                pw.SizedBox(height: 20),
                
                // STATISTIQUES
                pw.Text(
                  'Statistiques',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
  pw.Widget _buildPdfRow(String label, double value, {bool isBold = false, double fontSize = 10, bool isCount = false}) {
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

  /// Onglet Liste des Transactions avec filtres avancés
  Widget _buildListeTransactionsTab() {
    // Set default filter to today's transactions if not already set
    if (_listeTransactionsDateDebut == null && _listeTransactionsDateFin == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          final today = DateTime.now();
          _listeTransactionsDateDebut = DateTime(today.year, today.month, today.day);
          _listeTransactionsDateFin = DateTime(today.year, today.month, today.day, 23, 59, 59);
        });
      });
    }
    
    return Column(
      children: [
        // Barre de filtres
        Container(
          color: Colors.grey[100],
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              // Bouton pour afficher/masquer les filtres
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _showListeTransactionsFilters = !_showListeTransactionsFilters;
                        });
                      },
                      icon: Icon(_showListeTransactionsFilters ? Icons.filter_list_off : Icons.filter_list),
                      label: const SizedBox.shrink(), // Remove text, keep only icon
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF48bb78),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _resetListeTransactionsFilters,
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Reset'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _exportListeTransactionsToPdf,
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Export PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              
              // Filtres détaillés (masqués par défaut)
              if (_showListeTransactionsFilters) ...[
                const SizedBox(height: 12),
                _buildListeTransactionsFilters(),
              ],
            ],
          ),
        ),
        
        // Liste des transactions (with proper mobile scrolling)
        Expanded(
          child: _buildListeTransactionsFilteredList(),
        ),
      ],
    );
  }

  /// Construire les filtres pour la liste des transactions
  Widget _buildListeTransactionsFilters() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filtres de Recherche',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF48bb78),
              ),
            ),
            const SizedBox(height: 16),
            
            // Ligne 1: Recherche par texte et Statut
            Row(
              children: [
                // Recherche par référence/téléphone
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _listeTransactionsSearchController,
                    decoration: const InputDecoration(
                      labelText: 'Recherche (Référence, Téléphone)',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() {
                        _listeTransactionsSearchQuery = value.toLowerCase();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                
                // Filtre par statut
                Expanded(
                  child: DropdownButtonFormField<VirtualTransactionStatus?>(
                    value: _listeTransactionsStatusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Statut',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<VirtualTransactionStatus?>(
                        value: null,
                        child: Text('Tous les statuts'),
                      ),
                      ...VirtualTransactionStatus.values.map((status) {
                        String statusText;
                        switch (status) {
                          case VirtualTransactionStatus.enAttente:
                            statusText = 'En Attente';
                            break;
                          case VirtualTransactionStatus.validee:
                            statusText = 'Servi';
                            break;
                          case VirtualTransactionStatus.annulee:
                            statusText = 'Annulé';
                            break;
                        }
                        return DropdownMenuItem<VirtualTransactionStatus?>(
                          value: status,
                          child: Text(statusText),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _listeTransactionsStatusFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Ligne 2: Filtres de date
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectListeTransactionsDateDebut(),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date Début',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _listeTransactionsDateDebut != null
                            ? DateFormat('dd/MM/yyyy').format(_listeTransactionsDateDebut!)
                            : 'Sélectionner',
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectListeTransactionsDateFin(),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date Fin',
                        prefixIcon: Icon(Icons.calendar_today),
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        _listeTransactionsDateFin != null
                            ? DateFormat('dd/MM/yyyy').format(_listeTransactionsDateFin!)
                            : 'Sélectionner',
                      ),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Ligne 3: Filtres de montant et devise
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Montant Min',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _listeTransactionsMontantMin = double.tryParse(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Montant Max',
                      prefixIcon: Icon(Icons.attach_money),
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      setState(() {
                        _listeTransactionsMontantMax = double.tryParse(value);
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: _listeTransactionsDeviseFilter,
                    decoration: const InputDecoration(
                      labelText: 'Devise',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Toutes devises'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'USD',
                        child: Text('USD'),
                      ),
                      DropdownMenuItem<String?>(
                        value: 'CDF',
                        child: Text('CDF'),
                      ),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _listeTransactionsDeviseFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Ligne 4: Filtre par SIM
            Row(
              children: [
                Expanded(
                  child: Consumer<SimService>(
                    builder: (context, simService, child) {
                      return FutureBuilder<void>(
                        future: simService.loadSims(),
                        builder: (context, snapshot) {
                          final sims = simService.sims;
                          return DropdownButtonFormField<String?>(
                            value: sims.any((sim) => sim.numero == _listeTransactionsSimFilter) 
                                ? _listeTransactionsSimFilter 
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'SIM',
                              prefixIcon: Icon(Icons.sim_card),
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Toutes les SIMs'),
                              ),
                              ...sims.map((sim) {
                                return DropdownMenuItem<String?>(
                                  value: sim.numero,
                                  child: Text('${sim.operateur} (${sim.numero})'),
                                );
                              }),
                            ],
                            onChanged: (value) {
                              setState(() {
                                _listeTransactionsSimFilter = value;
                              });
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(flex: 2, child: SizedBox()), // Espace vide pour alignement
              ],
            ),
          ],
          ),
        ),
      ),
    );
  }

  /// Construire la liste filtrée des transactions pour Liste des Transactions
  Widget _buildListeTransactionsFilteredList() {
    return Consumer<VirtualTransactionService>(
      builder: (context, service, child) {
        return FutureBuilder<List<VirtualTransactionModel>>(
          future: Future.value(service.transactions),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            if (snapshot.hasError) {
              return Center(
                child: Text('Erreur: ${snapshot.error}'),
              );
            }
            
            final allTransactions = snapshot.data ?? [];
            final filteredTransactions = _applyListeTransactionsFilters(allTransactions);
            
            if (filteredTransactions.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Aucune transaction trouvée',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              );
            }
            
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    shrinkWrap: false,
                    itemCount: filteredTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = filteredTransactions[index];
                      return _buildListeTransactionListItem(transaction);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Appliquer les filtres à la liste des transactions
  List<VirtualTransactionModel> _applyListeTransactionsFilters(List<VirtualTransactionModel> transactions) {
    return transactions.where((transaction) {
      // Filtre par recherche textuelle
      if (_listeTransactionsSearchQuery.isNotEmpty) {
        final searchLower = _listeTransactionsSearchQuery.toLowerCase();
        final matchesReference = transaction.reference.toLowerCase().contains(searchLower);
        final matchesPhone = (transaction.clientTelephone ?? '').toLowerCase().contains(searchLower);
        if (!matchesReference && !matchesPhone) return false;
      }
      
      // Filtre par statut
      if (_listeTransactionsStatusFilter != null && 
          transaction.statut != _listeTransactionsStatusFilter) {
        return false;
      }
      
      // Filtre par date de début
      if (_listeTransactionsDateDebut != null) {
        final dateDebut = DateTime(_listeTransactionsDateDebut!.year, 
                                  _listeTransactionsDateDebut!.month, 
                                  _listeTransactionsDateDebut!.day);
        final transactionDate = DateTime(transaction.dateEnregistrement.year,
                                       transaction.dateEnregistrement.month,
                                       transaction.dateEnregistrement.day);
        if (transactionDate.isBefore(dateDebut)) return false;
      }
      
      // Filtre par date de fin
      if (_listeTransactionsDateFin != null) {
        final dateFin = DateTime(_listeTransactionsDateFin!.year, 
                                _listeTransactionsDateFin!.month, 
                                _listeTransactionsDateFin!.day, 23, 59, 59);
        final transactionDate = DateTime(transaction.dateEnregistrement.year,
                                       transaction.dateEnregistrement.month,
                                       transaction.dateEnregistrement.day);
        if (transactionDate.isAfter(dateFin)) return false;
      }
      
      // Filtre par montant minimum
      if (_listeTransactionsMontantMin != null && 
          transaction.montantVirtuel < _listeTransactionsMontantMin!) {
        return false;
      }
      
      // Filtre par montant maximum
      if (_listeTransactionsMontantMax != null && 
          transaction.montantVirtuel > _listeTransactionsMontantMax!) {
        return false;
      }
      
      // Filtre par devise
      if (_listeTransactionsDeviseFilter != null && 
          transaction.devise != _listeTransactionsDeviseFilter) {
        return false;
      }
      
      // Filtre par SIM
      if (_listeTransactionsSimFilter != null && 
          transaction.simNumero != _listeTransactionsSimFilter) {
        return false;
      }
      
      return true;
    }).toList();
  }

  /// Construire un élément de la liste des transactions pour Liste des Transactions
  Widget _buildListeTransactionListItem(VirtualTransactionModel transaction) {
    final currencyService = CurrencyService.instance;
    
    // Déterminer la couleur selon le statut
    Color statusColor;
    IconData statusIcon;
    String statusText;
    
    switch (transaction.statut) {
      case VirtualTransactionStatus.enAttente:
        statusColor = Colors.orange;
        statusIcon = Icons.hourglass_empty;
        statusText = 'En Attente';
        break;
      case VirtualTransactionStatus.validee:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        statusText = 'Servi';
        break;
      case VirtualTransactionStatus.annulee:
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        statusText = 'Annulé';
        break;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.2),
          child: Icon(statusIcon, color: statusColor),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Réf: ${transaction.reference}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
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
                Icon(Icons.phone, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(transaction.clientTelephone ?? 'N/A'),
                const Spacer(),
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateEnregistrement)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  transaction.devise == 'USD' 
                      ? currencyService.formatMontant(transaction.montantVirtuel, 'USD')
                      : currencyService.formatMontant(transaction.montantVirtuel, 'CDF'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                if (transaction.statut == VirtualTransactionStatus.validee && transaction.dateValidation != null) ...[
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Servi: ${DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateValidation!)}',
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'details':
                _showListeTransactionDetails(transaction);
                break;
              case 'serve':
                if (transaction.statut == VirtualTransactionStatus.enAttente) {
                  _serveTransaction(transaction);
                }
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<String>(
              value: 'details',
              child: Row(
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: 8),
                  Text('Détails'),
                ],
              ),
            ),
            if (transaction.statut == VirtualTransactionStatus.enAttente)
              const PopupMenuItem<String>(
                value: 'serve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline),
                    SizedBox(width: 8),
                    Text('Servir'),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Sélectionner la date de début pour les filtres
  Future<void> _selectListeTransactionsDateDebut() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _listeTransactionsDateDebut ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _listeTransactionsDateDebut = picked;
      });
    }
  }

  /// Sélectionner la date de fin pour les filtres
  Future<void> _selectListeTransactionsDateFin() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _listeTransactionsDateFin ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _listeTransactionsDateFin = picked;
      });
    }
  }

  /// Réinitialiser tous les filtres
  void _resetListeTransactionsFilters() {
    setState(() {
      _listeTransactionsDateDebut = null;
      _listeTransactionsDateFin = null;
      _listeTransactionsMontantMin = null;
      _listeTransactionsMontantMax = null;
      _listeTransactionsStatusFilter = null;
      _listeTransactionsSearchController.clear();
      _listeTransactionsSearchQuery = '';
      _listeTransactionsDeviseFilter = null;
      _listeTransactionsSimFilter = null;
    });
  }

  /// Afficher les détails d'une transaction pour Liste des Transactions
  void _showListeTransactionDetails(VirtualTransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Détails Transaction'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildListeTransactionDetailRow('Référence', transaction.reference),
              _buildListeTransactionDetailRow('Téléphone', transaction.clientTelephone ?? 'N/A'),
              _buildListeTransactionDetailRow('Montant', '${transaction.montantVirtuel.toStringAsFixed(2)} ${transaction.devise}'),
              _buildListeTransactionDetailRow('Statut', transaction.statut.toString().split('.').last),
              _buildListeTransactionDetailRow('Date Enregistrement', DateFormat('dd/MM/yyyy HH:mm:ss').format(transaction.dateEnregistrement)),
              if (transaction.dateValidation != null)
                _buildListeTransactionDetailRow('Date Validation', DateFormat('dd/MM/yyyy HH:mm:ss').format(transaction.dateValidation!)),
              _buildListeTransactionDetailRow('Shop ID', transaction.shopId.toString()),
              _buildListeTransactionDetailRow('SIM', transaction.simNumero),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  /// Construire une ligne de détail pour Liste des Transactions
  Widget _buildListeTransactionDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  /// Servir une transaction
  void _serveTransaction(VirtualTransactionModel transaction) {
    showDialog(
      context: context,
      builder: (context) => ServeClientDialog(
        transaction: transaction,
      ),
    );
  }

  /// Exporter la liste des transactions filtrées en PDF
  Future<void> _exportListeTransactionsToPdf() async {
    try {
      // Récupérer les transactions filtrées
      final service = Provider.of<VirtualTransactionService>(context, listen: false);
      await service.loadTransactions(); // Load transactions first
      final allTransactions = service.transactions;
      final filteredTransactions = _applyListeTransactionsFilters(allTransactions);
      
      if (filteredTransactions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune transaction à exporter'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Générer le PDF
      final pdf = pw.Document();
      
      // Récupérer les informations de l'utilisateur et du shop
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shop = await shopService.getShopById(currentUser?.shopId ?? 0);
      
      // Créer les pages du PDF
      await _generateListeTransactionsPdfPages(pdf, filteredTransactions, shop, currentUser);
      
      // Afficher le PDF dans un dialog de prévisualisation
      // final pdfBytes = await pdf.save(); // Not needed for PdfViewerDialog
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => PdfViewerDialog(
            pdfDocument: pdf,
            fileName: 'liste_transactions_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
            title: 'Liste des Transactions - ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Générer les pages du PDF pour la liste des transactions
  Future<void> _generateListeTransactionsPdfPages(
    pw.Document pdf,
    List<VirtualTransactionModel> transactions,
    dynamic shop,
    dynamic currentUser,
  ) async {
    const int transactionsPerPage = 20;
    final totalPages = (transactions.length / transactionsPerPage).ceil();
    
    for (int pageIndex = 0; pageIndex < totalPages; pageIndex++) {
      final startIndex = pageIndex * transactionsPerPage;
      final endIndex = (startIndex + transactionsPerPage).clamp(0, transactions.length);
      final pageTransactions = transactions.sublist(startIndex, endIndex);
      
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(20),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // En-tête
                _buildListeTransactionsPdfHeader(shop, currentUser, pageIndex + 1, totalPages),
                pw.SizedBox(height: 20),
                
                // Informations sur les filtres appliqués
                _buildListeTransactionsPdfFilters(),
                pw.SizedBox(height: 20),
                
                // Tableau des transactions
                _buildListeTransactionsPdfTable(pageTransactions),
                
                pw.Spacer(),
                
                // Pied de page
                _buildListeTransactionsPdfFooter(transactions.length),
              ],
            );
          },
        ),
      );
    }
  }

  /// Construire l'en-tête du PDF
  pw.Widget _buildListeTransactionsPdfHeader(dynamic shop, dynamic currentUser, int currentPage, int totalPages) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  shop?.nom ?? 'Shop',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  'Liste des Transactions Virtuelles',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text(
                  'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Agent: ${currentUser?.nom ?? 'N/A'}',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.Text(
                  'Page $currentPage/$totalPages',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
        pw.Divider(thickness: 2),
      ],
    );
  }

  /// Construire les informations sur les filtres appliqués
  pw.Widget _buildListeTransactionsPdfFilters() {
    final List<String> activeFilters = [];
    
    if (_listeTransactionsDateDebut != null) {
      activeFilters.add('Date début: ${DateFormat('dd/MM/yyyy').format(_listeTransactionsDateDebut!)}');
    }
    if (_listeTransactionsDateFin != null) {
      activeFilters.add('Date fin: ${DateFormat('dd/MM/yyyy').format(_listeTransactionsDateFin!)}');
    }
    if (_listeTransactionsStatusFilter != null) {
      String statusText = '';
      switch (_listeTransactionsStatusFilter!) {
        case VirtualTransactionStatus.enAttente:
          statusText = 'En Attente';
          break;
        case VirtualTransactionStatus.validee:
          statusText = 'Servi';
          break;
        case VirtualTransactionStatus.annulee:
          statusText = 'Annulé';
          break;
      }
      activeFilters.add('Statut: $statusText');
    }
    if (_listeTransactionsMontantMin != null) {
      activeFilters.add('Montant min: ${_listeTransactionsMontantMin!.toStringAsFixed(2)}');
    }
    if (_listeTransactionsMontantMax != null) {
      activeFilters.add('Montant max: ${_listeTransactionsMontantMax!.toStringAsFixed(2)}');
    }
    if (_listeTransactionsDeviseFilter != null) {
      activeFilters.add('Devise: $_listeTransactionsDeviseFilter');
    }
    if (_listeTransactionsSimFilter != null) {
      activeFilters.add('SIM: $_listeTransactionsSimFilter');
    }
    if (_listeTransactionsSearchQuery.isNotEmpty) {
      activeFilters.add('Recherche: $_listeTransactionsSearchQuery');
    }
    
    if (activeFilters.isEmpty) {
      return pw.Text(
        'Filtres: Aucun filtre appliqué',
        style: pw.TextStyle(fontSize: 10, fontStyle: pw.FontStyle.italic),
      );
    }
    
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Filtres appliqués:',
          style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
        ),
        pw.Text(
          activeFilters.join(' • '),
          style: const pw.TextStyle(fontSize: 9),
        ),
      ],
    );
  }

  /// Construire le tableau des transactions
  pw.Widget _buildListeTransactionsPdfTable(List<VirtualTransactionModel> transactions) {
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      columnWidths: {
        0: const pw.FlexColumnWidth(2), // Référence
        1: const pw.FlexColumnWidth(2), // Téléphone
        2: const pw.FlexColumnWidth(1.5), // Montant
        3: const pw.FlexColumnWidth(1), // Devise
        4: const pw.FlexColumnWidth(1.5), // Statut
        5: const pw.FlexColumnWidth(2), // Date
        6: const pw.FlexColumnWidth(1), // SIM
      },
      children: [
        // En-tête du tableau
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _buildPdfTableCell('Référence', isHeader: true),
            _buildPdfTableCell('Téléphone', isHeader: true),
            _buildPdfTableCell('Montant', isHeader: true),
            _buildPdfTableCell('Devise', isHeader: true),
            _buildPdfTableCell('Statut', isHeader: true),
            _buildPdfTableCell('Date', isHeader: true),
            _buildPdfTableCell('SIM', isHeader: true),
          ],
        ),
        // Lignes de données
        ...transactions.map((transaction) {
          String statusText = '';
          switch (transaction.statut) {
            case VirtualTransactionStatus.enAttente:
              statusText = 'En Attente';
              break;
            case VirtualTransactionStatus.validee:
              statusText = 'Servi';
              break;
            case VirtualTransactionStatus.annulee:
              statusText = 'Annulé';
              break;
          }
          
          return pw.TableRow(
            children: [
              _buildPdfTableCell(transaction.reference),
              _buildPdfTableCell(transaction.clientTelephone ?? 'N/A'),
              _buildPdfTableCell(transaction.montantVirtuel.toStringAsFixed(2)),
              _buildPdfTableCell(transaction.devise),
              _buildPdfTableCell(statusText),
              _buildPdfTableCell(DateFormat('dd/MM/yyyy HH:mm').format(transaction.dateEnregistrement)),
              _buildPdfTableCell(transaction.simNumero),
            ],
          );
        }),
      ],
    );
  }

  /// Construire une cellule du tableau PDF
  pw.Widget _buildPdfTableCell(String text, {bool isHeader = false}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 9 : 8,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: pw.TextAlign.center,
      ),
    );
  }

  /// Construire le pied de page du PDF
  pw.Widget _buildListeTransactionsPdfFooter(int totalTransactions) {
    return pw.Column(
      children: [
        pw.Divider(),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Total: $totalTransactions transaction(s)',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              'Généré le ${DateFormat('dd/MM/yyyy à HH:mm').format(DateTime.now())}',
              style: const pw.TextStyle(fontSize: 8),
            ),
          ],
        ),
      ],
    );
  }

  // === MÉTHODES HELPER POUR CRÉDIT VIRTUEL ===

  /// Charger les données des crédits
  Future<void> _loadCreditsData() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    
    if (currentUser != null) {
      final creditService = Provider.of<CreditVirtuelService>(context, listen: false);
      await creditService.loadCredits(
        shopId: currentUser.role == 'ADMIN' ? _selectedShopFilter : currentUser.shopId,
        simNumero: _creditSimFilter,
        dateDebut: _creditDateDebutFilter,
        dateFin: _creditDateFinFilter,
        statut: _creditStatusFilter,
        beneficiaire: _creditSearchQuery.isNotEmpty ? _creditSearchQuery : null,
      );
    }
  }

  /// Afficher le dialog pour accorder un crédit
  void _showAccorderCreditDialog() {
    showDialog(
      context: context,
      builder: (context) => _AccorderCreditDialog(
        onCreditAccorde: () {
          _loadCreditsData();
        },
      ),
    );
  }

  /// Construire les filtres pour les crédits virtuels
  Widget _buildCreditFilters() {
    return Consumer<SimService>(
      builder: (context, simService, child) {
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.filter_list, color: const Color(0xFF48bb78), size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Filtres de Recherche',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF48bb78),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Barre de recherche
                TextField(
                  controller: _creditSearchController,
                  decoration: InputDecoration(
                    hintText: 'Rechercher par bénéficiaire ou référence...',
                    prefixIcon: const Icon(Icons.search, color: Color(0xFF48bb78)),
                    suffixIcon: _creditSearchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _creditSearchController.clear();
                                _creditSearchQuery = '';
                              });
                              _loadCreditsData();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _creditSearchQuery = value);
                    _loadCreditsData();
                  },
                ),
                const SizedBox(height: 16),
                
                // Row with filters
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    // Filtre par statut
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<CreditVirtuelStatus?>(
                        value: _creditStatusFilter,
                        decoration: InputDecoration(
                          labelText: 'Statut',
                          prefixIcon: const Icon(Icons.info_outline, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Tous')),
                          ...CreditVirtuelStatus.values.map((status) => DropdownMenuItem(
                            value: status,
                            child: Text(_getStatusLabel(status)),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _creditStatusFilter = value);
                          _loadCreditsData();
                        },
                      ),
                    ),
                    
                    // Filtre par SIM
                    SizedBox(
                      width: 200,
                      child: DropdownButtonFormField<String?>(
                        value: simService.sims.any((sim) => sim.numero == _creditSimFilter) 
                            ? _creditSimFilter 
                            : null,
                        decoration: InputDecoration(
                          labelText: 'SIM',
                          prefixIcon: const Icon(Icons.sim_card, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: null, child: Text('Toutes')),
                          ...simService.sims.map((sim) => DropdownMenuItem(
                            value: sim.numero,
                            child: Text('${sim.operateur} (${sim.numero})'),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _creditSimFilter = value);
                          _loadCreditsData();
                        },
                      ),
                    ),
                    
                    // Filtre date début
                    SizedBox(
                      width: 180,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _creditDateDebutFilter != null
                              ? DateFormat('dd/MM/yyyy').format(_creditDateDebutFilter!)
                              : 'Date début',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _creditDateDebutFilter != null 
                              ? const Color(0xFF48bb78).withOpacity(0.1) 
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _creditDateDebutFilter ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _creditDateDebutFilter = DateTime(date.year, date.month, date.day, 0, 0, 0));
                            _loadCreditsData();
                          }
                        },
                      ),
                    ),
                    
                    // Filtre date fin
                    SizedBox(
                      width: 180,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                          _creditDateFinFilter != null
                              ? DateFormat('dd/MM/yyyy').format(_creditDateFinFilter!)
                              : 'Date fin',
                          style: const TextStyle(fontSize: 13),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: _creditDateFinFilter != null 
                              ? const Color(0xFF48bb78).withOpacity(0.1) 
                              : null,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _creditDateFinFilter ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() => _creditDateFinFilter = DateTime(date.year, date.month, date.day, 23, 59, 59));
                            _loadCreditsData();
                          }
                        },
                      ),
                    ),
                    
                    // Bouton réinitialiser
                    OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _creditStatusFilter = null;
                          _creditDateDebutFilter = null;
                          _creditDateFinFilter = null;
                          _creditSimFilter = null;
                          _creditSearchController.clear();
                          _creditSearchQuery = '';
                        });
                        _loadCreditsData();
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Réinitialiser'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Helper pour obtenir le label du statut
  String _getStatusLabel(CreditVirtuelStatus status) {
    switch (status) {
      case CreditVirtuelStatus.accorde:
        return 'Accordé';
      case CreditVirtuelStatus.partiellementPaye:
        return 'Partiellement Payé';
      case CreditVirtuelStatus.paye:
        return 'Payé';
      case CreditVirtuelStatus.annule:
        return 'Annulé';
      case CreditVirtuelStatus.enRetard:
        return 'En Retard';
    }
  }

  /// Construire le widget d'affichage du solde virtuel disponible
  Widget _buildSoldeVirtuelDisponible() {
    return Consumer<SimService>(
      builder: (context, simService, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solde Virtuel Disponible par SIM',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF48bb78),
                  ),
                ),
                const SizedBox(height: 12),
                ...simService.sims.map((sim) => FutureBuilder<Map<String, double>>(
                  future: _calculateSoldeVirtuelDisponibleParDevise(sim.numero),
                  builder: (context, snapshot) {
                    final soldes = snapshot.data ?? {'USD': 0.0, 'CDF': 0.0};
                    final soldeUSD = soldes['USD'] ?? 0.0;
                    final soldeCDF = soldes['CDF'] ?? 0.0;
                    final currencyService = CurrencyService.instance;
                    
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text('${sim.operateur} (${sim.numero})'),
                          ),
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (soldeUSD > 0)
                                  Text(
                                    currencyService.formatMontant(soldeUSD, 'USD'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: soldeUSD > 0 ? Colors.green : Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                if (soldeCDF > 0)
                                  Text(
                                    currencyService.formatMontant(soldeCDF, 'CDF'),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: soldeCDF > 0 ? Colors.blue : Colors.red,
                                      fontSize: 13,
                                    ),
                                  ),
                                if (soldeUSD == 0 && soldeCDF == 0)
                                  Text(
                                    '0.00',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                      fontSize: 13,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Calculer le solde virtuel disponible par devise pour une SIM
  Future<Map<String, double>> _calculateSoldeVirtuelDisponibleParDevise(String simNumero) async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = authService.currentUser?.shopId;
      
      if (shopId == null) return {'USD': 0.0, 'CDF': 0.0};
      
      // Récupérer toutes les transactions pour cette SIM
      final allTransactions = await LocalDB.instance.getAllVirtualTransactions(shopId: shopId);
      final simTransactions = allTransactions.where((t) => t.simNumero == simNumero).toList();
      
      // Calculer les soldes par devise
      double soldeUSD = 0.0;
      double soldeCDF = 0.0;
      
      for (var transaction in simTransactions) {
        if (transaction.statut == VirtualTransactionStatus.validee) {
          if (transaction.devise == 'USD') {
            soldeUSD += transaction.montantVirtuel;
          } else if (transaction.devise == 'CDF') {
            soldeCDF += transaction.montantVirtuel;
          }
        }
      }
      
      // Soustraire les retraits (toujours en USD)
      final retraits = await LocalDB.instance.getAllRetraitsVirtuels(shopSourceId: shopId);
      final simRetraits = retraits.where((r) => r.simNumero == simNumero).toList();
      final totalRetraits = simRetraits.fold<double>(0.0, (sum, r) => sum + r.montant);
      soldeUSD -= totalRetraits; // Les retraits sont toujours en USD
      
      // Soustraire les dépôts clients (toujours en USD)
      final depots = await LocalDB.instance.getAllDepotsClients(shopId: shopId);
      final simDepots = depots.where((d) => d.simNumero == simNumero).toList();
      final totalDepots = simDepots.fold<double>(0.0, (sum, d) => sum + d.montant);
      soldeUSD -= totalDepots; // Les dépôts sont toujours en USD
      
      return {
        'USD': soldeUSD,
        'CDF': soldeCDF,
      };
    } catch (e) {
      debugPrint('❌ Erreur calcul solde par devise pour SIM $simNumero: $e');
      return {'USD': 0.0, 'CDF': 0.0};
    }
  }

  /// Construire une carte de crédit
  Widget _buildCreditCard(CreditVirtuelModel credit) {
    final currencyService = CurrencyService.instance;
    
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  credit.reference,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                _buildCreditStatusBadge(credit.statut),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    credit.beneficiaireNom,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.account_balance_wallet, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Crédit: ${currencyService.formatMontant(credit.montantCredit, credit.devise)}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 16),
                Text(
                  'Restant: ${currencyService.formatMontant(credit.montantRestant, credit.devise)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: credit.montantRestant > 0 ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Accordé: ${DateFormat('dd/MM/yyyy').format(credit.dateSortie)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                if (credit.dateEcheance != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Échéance: ${DateFormat('dd/MM/yyyy').format(credit.dateEcheance!)}',
                    style: TextStyle(
                      color: credit.estEnRetard ? Colors.red : Colors.grey[600],
                    ),
                  ),
                ],
              ],
            ),
            if (credit.statut != CreditVirtuelStatus.paye && credit.statut != CreditVirtuelStatus.annule) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _showEnregistrerPaiementDialog(credit),
                    icon: const Icon(Icons.payment, size: 16),
                    label: const Text('Paiement'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF48bb78),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () => _showAnnulerCreditDialog(credit),
                    icon: const Icon(Icons.cancel, size: 16),
                    label: const Text('Annuler'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construire le badge de statut du crédit
  Widget _buildCreditStatusBadge(CreditVirtuelStatus statut) {
    Color color;
    String label;
    
    switch (statut) {
      case CreditVirtuelStatus.accorde:
        color = Colors.blue;
        label = 'Accordé';
        break;
      case CreditVirtuelStatus.partiellementPaye:
        color = Colors.orange;
        label = 'Partiel';
        break;
      case CreditVirtuelStatus.paye:
        color = Colors.green;
        label = 'Payé';
        break;
      case CreditVirtuelStatus.annule:
        color = Colors.red;
        label = 'Annulé';
        break;
      case CreditVirtuelStatus.enRetard:
        color = Colors.red;
        label = 'En Retard';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// Construire une carte de statistique
  // Widget _buildStatCard(String title, String value, IconData icon, Color color) {
  //   return Card(
  //     margin: const EdgeInsets.symmetric(vertical: 4),
  //     child: Padding(
  //       padding: const EdgeInsets.all(16),
  //       child: Row(
  //         children: [
  //           Container(
  //             padding: const EdgeInsets.all(12),
  //             decoration: BoxDecoration(
  //               color: color.withOpacity(0.1),
  //               borderRadius: BorderRadius.circular(8),
  //             ),
  //             child: Icon(icon, color: color, size: 24),
  //           ),
  //           const SizedBox(width: 16),
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: TextStyle(
  //                     color: Colors.grey[600],
  //                     fontSize: 14,
  //                   ),
  //                 ),
  //                 Text(
  //                   value,
  //                   style: const TextStyle(
  //                     fontSize: 18,
  //                     fontWeight: FontWeight.bold,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

  /// Afficher le dialog d'enregistrement de paiement
  void _showEnregistrerPaiementDialog(CreditVirtuelModel credit) {
    showDialog(
      context: context,
      builder: (context) => _EnregistrerPaiementDialog(
        credit: credit,
        onPaiementEnregistre: () {
          _loadCreditsData();
        },
      ),
    );
  }

  /// Afficher le dialog d'annulation de crédit
  void _showAnnulerCreditDialog(CreditVirtuelModel credit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Annuler le Crédit'),
        content: Text('Êtes-vous sûr de vouloir annuler le crédit ${credit.reference} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Non'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              final authService = Provider.of<AuthService>(context, listen: false);
              final currentUser = authService.currentUser;
              
              if (currentUser != null) {
                final creditService = Provider.of<CreditVirtuelService>(context, listen: false);
                final success = await creditService.annulerCredit(
                  creditId: credit.id!,
                  agentId: currentUser.id!,
                  agentUsername: currentUser.username,
                  motifAnnulation: 'Annulation manuelle',
                );
                
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Crédit annulé avec succès'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  _loadCreditsData();
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Oui, Annuler'),
          ),
        ],
      ),
    );
  }
}

// === DIALOGS POUR CRÉDIT VIRTUEL ===

/// Dialog pour accorder un nouveau crédit
class _AccorderCreditDialog extends StatefulWidget {
  final VoidCallback onCreditAccorde;

  const _AccorderCreditDialog({required this.onCreditAccorde});

  @override
  State<_AccorderCreditDialog> createState() => _AccorderCreditDialogState();
}

class _AccorderCreditDialogState extends State<_AccorderCreditDialog> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();
  
  String _devise = 'USD';
  String? _selectedSim;
  final _partenaireController = TextEditingController(); // For partner name input
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Accorder un Crédit Virtuel'),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _referenceController,
                  decoration: const InputDecoration(
                    labelText: 'Référence *',
                    hintText: 'Ex: CRED001',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Référence requise';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _montantController,
                        decoration: const InputDecoration(
                          labelText: 'Montant *',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Montant requis';
                          }
                          final montant = double.tryParse(value);
                          if (montant == null || montant <= 0) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _devise,
                        decoration: const InputDecoration(
                          labelText: 'Devise',
                        ),
                        items: const [
                          DropdownMenuItem(value: 'USD', child: Text('USD')),
                          DropdownMenuItem(value: 'CDF', child: Text('CDF')),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _devise = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Consumer<SimService>(
                  builder: (context, simService, child) {
                    return DropdownButtonFormField<String>(
                      value: _selectedSim,
                      decoration: const InputDecoration(
                        labelText: 'SIM *',
                      ),
                      items: simService.sims.map((sim) {
                        return DropdownMenuItem(
                          value: sim.numero,
                          child: Text('${sim.operateur} (${sim.numero})'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedSim = value;
                        });
                      },
                      validator: (value) {
                        if (value == null) {
                          return 'SIM requise';
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),


                  TextFormField(
                    controller: _partenaireController,
                    decoration: const InputDecoration(
                      labelText: 'Nom du Partenaire *',
                      hintText: 'Entrez le nom du partenaire',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Nom du partenaire requis';
                      }
                      return null;
                    },
                  ),


                
                const SizedBox(height: 16),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _accorderCredit,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF48bb78),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Accorder'),
        ),
      ],
    );
  }

  Future<void> _accorderCredit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final creditService = Provider.of<CreditVirtuelService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      
      final shop = shopService.shops.firstWhere(
        (s) => s.id == currentUser.shopId,
        orElse: () => throw Exception('Shop non trouvé'),
      );

      // Get partner information from text field
      String beneficiaireNom = _partenaireController.text.trim();
      String? beneficiaireTelephone;
      String? beneficiaireAdresse;
      
      final credit = await creditService.accorderCredit(
        reference: _referenceController.text.trim(),
        montantCredit: double.parse(_montantController.text),
        devise: _devise,
        beneficiaireNom: beneficiaireNom,
        beneficiaireTelephone: beneficiaireTelephone,
        beneficiaireAdresse: beneficiaireAdresse,
        typeBeneficiaire: 'partenaire',
        simNumero: _selectedSim!,
        shopId: currentUser.shopId!,
        shopDesignation: shop.designation,
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (credit != null && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Crédit accordé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onCreditAccorde();
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

/// Dialog pour enregistrer un paiement
class _EnregistrerPaiementDialog extends StatefulWidget {
  final CreditVirtuelModel credit;
  final VoidCallback onPaiementEnregistre;

  const _EnregistrerPaiementDialog({
    required this.credit,
    required this.onPaiementEnregistre,
  });

  @override
  State<_EnregistrerPaiementDialog> createState() => _EnregistrerPaiementDialogState();
}

class _EnregistrerPaiementDialogState extends State<_EnregistrerPaiementDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _referenceController = TextEditingController();
  
  String _modePaiement = 'cash';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final currencyService = CurrencyService.instance;
    
    return AlertDialog(
      title: Text('Paiement - ${widget.credit.reference}'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bénéficiaire: ${widget.credit.beneficiaireNom}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Text(
                'Montant restant: ${currencyService.formatMontant(widget.credit.montantRestant, widget.credit.devise)}',
                style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.orange),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _montantController,
                decoration: InputDecoration(
                  labelText: 'Montant du paiement *',
                  suffixText: widget.credit.devise,
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Montant requis';
                  }
                  final montant = double.tryParse(value);
                  if (montant == null || montant <= 0) {
                    return 'Montant invalide';
                  }
                  if (montant > widget.credit.montantRestant) {
                    return 'Montant supérieur au restant dû';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _modePaiement,
                decoration: const InputDecoration(
                  labelText: 'Mode de paiement',
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
                  DropdownMenuItem(value: 'virement', child: Text('Virement')),
                ],
                onChanged: (value) {
                  setState(() {
                    _modePaiement = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referenceController,
                decoration: const InputDecoration(
                  labelText: 'Référence du paiement',
                  hintText: 'Ex: REF123456',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _enregistrerPaiement,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF48bb78),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Enregistrer'),
        ),
      ],
    );
  }

  Future<void> _enregistrerPaiement() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final creditService = Provider.of<CreditVirtuelService>(context, listen: false);
      
      final success = await creditService.enregistrerPaiement(
        creditId: widget.credit.id!,
        montantPaiement: double.parse(_montantController.text),
        modePaiement: _modePaiement,
        referencePaiement: _referenceController.text.trim().isEmpty ? null : _referenceController.text.trim(),
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
      );

      if (success && mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Paiement enregistré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onPaiementEnregistre();
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
