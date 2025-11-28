import 'package:flutter/foundation.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import 'local_db.dart';
import 'operation_service.dart';

/// Service pour gérer les FLOTS (approvisionnement de liquidité entre shops)
/// UTILISE MAINTENANT OperationModel avec type=flotShopToShop
class FlotService extends ChangeNotifier {
  static final FlotService _instance = FlotService._internal();
  static FlotService get instance => _instance;
  
  FlotService._internal();

  List<OperationModel> _flots = [];
  bool _isLoading = false;
  String? _errorMessage;
  int? _currentShopId;
  bool _currentIsAdmin = false;

  List<OperationModel> get flots => _flots;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger tous les flots (filtre operations avec type=flotShopToShop)
  Future<void> loadFlots({int? shopId, bool isAdmin = false}) async {
    _setLoading(true);
    _currentShopId = shopId;
    _currentIsAdmin = isAdmin;
    
    try {
      debugPrint('📦 loadFlots() called - shopId: $shopId, isAdmin: $isAdmin');
      
      // Récupérer TOUTES les operations de type flotShopToShop
      final allOperations = await LocalDB.instance.getAllOperations();
      final allFlots = allOperations.where((op) => 
        op.type == OperationType.flotShopToShop
      ).toList();
      
      if (isAdmin) {
        // Admin voit tous les flots
        _flots = allFlots;
        debugPrint('📊 ADMIN - Tous les flots chargés: ${_flots.length}');
      } else if (shopId != null) {
        // Shop voit seulement les flots où il est source ou destination
        _flots = allFlots.where((f) => 
          f.shopSourceId == shopId || f.shopDestinationId == shopId
        ).toList();
        
        debugPrint('🏪 SHOP $shopId - Total flots: ${allFlots.length}, Filtrés: ${_flots.length}');
        debugPrint('   └─ Critère: shopSourceId == $shopId OU shopDestinationId == $shopId');
        
        // Debug: Afficher le détail
        final enCours = _flots.where((f) => f.statut == OperationStatus.enAttente).length;
        final servis = _flots.where((f) => f.statut == OperationStatus.validee || f.statut == OperationStatus.terminee).length;
        final annules = _flots.where((f) => f.statut == OperationStatus.annulee).length;
        debugPrint('   → En attente: $enCours | Servis: $servis | Annulés: $annules');
      } else {
        // Par défaut, charger tous les flots
        _flots = allFlots;
        debugPrint('📊 Par défaut - Tous les flots chargés: ${_flots.length}');
      }
      
      _errorMessage = null;
      debugPrint('💸 Flots chargés: ${_flots.length}');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des flots: $e';
      debugPrint('❌ $_errorMessage');
    }
    _setLoading(false);
  }

  /// Créer un nouveau flot (utilise OperationModel avec type=flotShopToShop)
  Future<bool> createFlot({
    required int shopSourceId,
    required String shopSourceDesignation,
    required int shopDestinationId,
    required String shopDestinationDesignation,
    required double montant,
    required String devise,
    required ModePaiement modePaiement,
    required int agentEnvoyeurId,
    String? agentEnvoyeurUsername,
    String? notes,
  }) async {
    try {
      // Créer une opération de type flotShopToShop
      final newFlot = OperationModel(
        type: OperationType.flotShopToShop,  // ← Type spécifique FLOT
        shopSourceId: shopSourceId,
        shopSourceDesignation: shopSourceDesignation,
        shopDestinationId: shopDestinationId,
        shopDestinationDesignation: shopDestinationDesignation,
        
        // Montants (commission = 0 pour les FLOTs)
        montantBrut: montant,
        montantNet: montant,
        commission: 0.00,  // ← TOUJOURS 0 pour les FLOTs
        devise: devise,
        
        modePaiement: modePaiement,
        statut: OperationStatus.enAttente,  // Au lieu de StatutFlot.enRoute
        
        agentId: agentEnvoyeurId,
        agentUsername: agentEnvoyeurUsername,
        
        dateOp: DateTime.now(),
        notes: notes,
        
        codeOps: _generateReference(shopSourceId, shopDestinationId),
        destinataire: shopDestinationDesignation,  // Nom du shop destination
        
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentEnvoyeurUsername',
      );

      // Sauvegarder via LocalDB (synchronisation automatique via OperationService)
      await LocalDB.instance.saveOperation(newFlot);
      
      // IMPORTANT: Réduire le capital du shop source immédiatement
      final shop = await LocalDB.instance.getShopById(shopSourceId);
      if (shop != null) {
        final updatedShop = shop.copyWith(
          capitalCash: modePaiement == ModePaiement.cash 
              ? shop.capitalCash - montant 
              : shop.capitalCash,
          capitalAirtelMoney: modePaiement == ModePaiement.airtelMoney 
              ? shop.capitalAirtelMoney - montant 
              : shop.capitalAirtelMoney,
          capitalMPesa: modePaiement == ModePaiement.mPesa 
              ? shop.capitalMPesa - montant 
              : shop.capitalMPesa,
          capitalOrangeMoney: modePaiement == ModePaiement.orangeMoney 
              ? shop.capitalOrangeMoney - montant 
              : shop.capitalOrangeMoney,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'agent_$agentEnvoyeurUsername',
        );
        
        await LocalDB.instance.updateShop(updatedShop);
        debugPrint('✅ Capital réduit de $montant ${modePaiement.name} pour le shop $shopSourceDesignation');
      }
      
      // Créer une entrée journal de caisse pour tracer la sortie
      try {
        final journalEntry = JournalCaisseModel(
          shopId: shopSourceId,
          agentId: agentEnvoyeurId,
          libelle: 'FLOT envoyé à $shopDestinationDesignation',
          montant: montant,
          type: TypeMouvement.sortie,
          mode: modePaiement,
          dateAction: DateTime.now(),
          notes: 'Réf: ${newFlot.codeOps}${notes != null ? ' - $notes' : ''}',
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'agent_$agentEnvoyeurUsername',
        );
        
        await LocalDB.instance.saveJournalEntry(journalEntry);
        debugPrint('✅ Journal: FLOT envoyé - SORTIE de $montant ${modePaiement.name}');
      } catch (e) {
        debugPrint('⚠️ Erreur enregistrement journal: $e (non bloquant)');
      }
      
      // Recharger avec les paramètres actuels APRES la sync
      debugPrint('🔄 Rechargement des FLOTs...');
      await loadFlots(shopId: _currentShopId, isAdmin: _currentIsAdmin);
      
      debugPrint('✅ Flot créé: $montant $devise de $shopSourceDesignation vers $shopDestinationDesignation');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création du flot: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }
  
  /// Mettre à jour un flot (via OperationService)
  Future<bool> updateFlot(OperationModel flot) async {
    try {
      // Mettre à jour via LocalDB
      await LocalDB.instance.updateOperation(flot);
      
      // Recharger avec les paramètres actuels
      await loadFlots(shopId: _currentShopId, isAdmin: _currentIsAdmin);
      
      debugPrint('✅ Flot mis à jour: ${flot.codeOps}');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du flot: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// Marquer un flot comme servi (reçu)
  Future<bool> marquerFlotServi({
    required int flotId,
    required int agentRecepteurId,
    String? agentRecepteurUsername,
  }) async {
    try {
      final flot = _flots.firstWhere((f) => f.id == flotId);
      
      // PROTECTION: Ne pas permettre de re-servir un flot déjà servi
      if (flot.statut == OperationStatus.validee || flot.statut == OperationStatus.terminee) {
        _errorMessage = 'Ce FLOT a déjà été reçu';
        debugPrint('⚠️ $_errorMessage');
        return false;
      }
      
      final updatedFlot = flot.copyWith(
        statut: OperationStatus.validee,  // Au lieu de StatutFlot.servi
        dateValidation: DateTime.now(), // Définie UNE SEULE FOIS
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_$agentRecepteurUsername',
      );

      // Mettre à jour via LocalDB (synchronisation automatique)
      await LocalDB.instance.updateOperation(updatedFlot);
      
      // Recharger avec les paramètres actuels APRES la sync
      debugPrint('🔄 Rechargement des FLOTs...');
      await loadFlots(shopId: _currentShopId, isAdmin: _currentIsAdmin);
      
      debugPrint('✅ Flot marqué servi: ${updatedFlot.codeOps}');
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour du flot: $e';
      debugPrint(_errorMessage);
      return false;
    }
  }

  /// Obtenir les flots en cours pour un shop
  List<OperationModel> getFlotsEnCours(int shopId) {
    return _flots.where((f) => 
      f.statut == OperationStatus.enAttente && 
      (f.shopSourceId == shopId || f.shopDestinationId == shopId)
    ).toList();
  }

  /// Obtenir les flots reçus pour un shop
  List<OperationModel> getFlotsRecus(int shopId, {DateTime? date}) {
    return _flots.where((f) => 
      (f.statut == OperationStatus.validee || f.statut == OperationStatus.terminee) && 
      f.shopDestinationId == shopId &&
      (date == null || (f.dateValidation != null && _isSameDay(f.dateValidation!, date)))
    ).toList();
  }

  /// Générer une référence unique pour le flot (format court: FsrcIDdestIDMMDDHHmm sans caractères spéciaux)
  String _generateReference(int shopSourceId, int shopDestinationId) {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    return 'F$shopSourceId$shopDestinationId$month$day$hour$minute';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}