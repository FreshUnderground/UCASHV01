import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/operation_model.dart';
import '../models/journal_caisse_model.dart';
import '../models/shop_model.dart';
import 'local_db.dart';
import 'rates_service.dart';
import 'sync_service.dart';
import 'depot_retrait_sync_service.dart';
import 'agent_service.dart';
import 'auth_service.dart';
import 'compte_special_service.dart';
import 'sim_service.dart';
import 'rapport_cloture_service.dart';
import '../config/app_config.dart';


class OperationService extends ChangeNotifier {
  static final OperationService _instance = OperationService._internal();
  factory OperationService() => _instance;
  OperationService._internal() {
    // Start periodic check for deleted operations
    startPeriodicDeletedOperationsCheck();
  }

  List<OperationModel> _operations = [];
  final List<JournalCaisseModel> _journalEntries = [];
  bool _isLoading = false;
  String? _errorMessage;
  // Sauvegarder les filtres actifs pour les réutiliser lors du reload
  int? _activeShopFilter;
  int? _activeAgentFilter;
  
  /// Periodically check for deleted operations
  void startPeriodicDeletedOperationsCheck() {
    // Check every 5 minutes for deleted operations
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      await _checkForDeletedOperationsOnServer();
    });
    debugPrint('✅ Started periodic deleted operations check (every 5 minutes)');
  }

  /// Manual refresh to check for deleted operations
  Future<void> checkForDeletedOperations() async {
    await _checkForDeletedOperationsOnServer();
    // Reload operations to reflect changes
    await loadOperations();
  }
  
  // Timer pour vérifier les opérations en attente toutes les 30 secondes
  Timer? _pendingOpsTimer;
  bool _isPendingOpsCheckEnabled = false;
  int _pendingOpsCount = 0;
  
  // Timer pour synchroniser les opérations non synchronisées
  Timer? _unsyncedOpsTimer;
  int _unsyncedOpsCount = 0;
  
  // Queue des suppressions en attente de synchronisation
  final List<String> _pendingDeletions = [];

  List<OperationModel> get operations => _operations;
  List<JournalCaisseModel> get journalEntries => _journalEntries;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get pendingOpsCount => _pendingOpsCount;
  bool get isPendingOpsCheckEnabled => _isPendingOpsCheckEnabled;
  int get unsyncedOpsCount => _unsyncedOpsCount;
  int get pendingDeletionsCount => _pendingDeletions.length;

  void _setLoading(bool loading) {
    _isLoading = loading;
    // Déférer notifyListeners pour éviter l'appel pendant build
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  /// Réinitialiser les filtres (utile pour l'admin)
  void clearFilters() {
    _activeShopFilter = null;
    _activeAgentFilter = null;
    debugPrint('🗑️ Filtres réinitialisés');
  }

  /// Check if an operation has been deleted (exists in corbeille)
  Future<bool> _isOperationDeleted(String codeOps) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'corbeille_$codeOps';
      return prefs.containsKey(key);
    } catch (e) {
      debugPrint('Error checking if operation is deleted: $e');
      return false;
    }
  }

  /// Filter out deleted operations
  Future<List<OperationModel>> _filterOutDeletedOperations(List<OperationModel> operations) async {
    final filteredOperations = <OperationModel>[];
    
    for (final operation in operations) {
      if (operation.codeOps != null) {
        final isDeleted = await _isOperationDeleted(operation.codeOps!);
        if (!isDeleted) {
          filteredOperations.add(operation);
        } else {
          debugPrint('🗑️ Operation ${operation.codeOps} filtered out (deleted)');
        }
      } else {
        // If codeOps is null, keep the operation (shouldn't happen in practice)
        filteredOperations.add(operation);
      }
    }
    
    return filteredOperations;
  }

  /// Check for deleted operations on the server and remove them from local storage
  Future<void> _checkForDeletedOperationsOnServer() async {
    try {
      // Get all operations with codeOps
      final allOperations = await LocalDB.instance.getAllOperations();
      final codeOpsList = allOperations
          .where((op) => op.codeOps != null && op.codeOps!.isNotEmpty)
          .map((op) => op.codeOps!)
          .toList();

      if (codeOpsList.isEmpty) {
        return;
      }

      debugPrint('🔍 Checking for deleted operations on server... (${codeOpsList.length} operations)');

      // Call the API to check for deleted operations
      final baseUrl = await AppConfig.getApiBaseUrl();
      final cleanUrl = baseUrl.trim();
      final url = Uri.parse('$cleanUrl/sync/operations/check_deleted.php');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'code_ops_list': codeOpsList,
        }),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Timeout checking for deleted operations');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final deletedOperations = List<String>.from(data['deleted_operations']);

          if (deletedOperations.isNotEmpty) {
            debugPrint('🗑️ Found ${deletedOperations.length} deleted operations on server');
            
            // Remove deleted operations from all local storage
            await _removeDeletedOperationsLocally(deletedOperations);
          } else {
            debugPrint('✅ No deleted operations found on server');
          }
        } else {
          debugPrint('⚠️ Error checking for deleted operations: ${data['error']}');
        }
      } else {
        debugPrint('⚠️ HTTP Error ${response.statusCode} checking for deleted operations');
      }
    } catch (e) {
      debugPrint('⚠️ Error checking for deleted operations: $e');
    }
  }

  /// Remove deleted operations from all local storage sources
  Future<void> _removeDeletedOperationsLocally(List<String> deletedCodeOpsList) async {
    try {
      if (deletedCodeOpsList.isEmpty) {
        return;
      }

      debugPrint('🗑️ Removing ${deletedCodeOpsList.length} deleted operations from local storage');

      final prefs = await SharedPreferences.getInstance();

      // 1. Remove from operations list in memory
      final initialCount = _operations.length;
      _operations.removeWhere((op) => 
          op.codeOps != null && deletedCodeOpsList.contains(op.codeOps));
      final removedFromMemory = initialCount - _operations.length;

      // 2. Remove from LocalDB
      int removedFromLocalDB = 0;
      try {
        await LocalDB.instance.deleteOperationsByCodeOpsList(deletedCodeOpsList);
        removedFromLocalDB = deletedCodeOpsList.length;
      } catch (e) {
        debugPrint('⚠️ Error removing operations from LocalDB: $e');
      }

      // 3. Remove from pending validations
      int removedFromValidations = 0;
      final validationsJson = prefs.getString('pending_validations');
      if (validationsJson != null) {
        try {
          final List<dynamic> validationsList = jsonDecode(validationsJson);
          final initialValidationsCount = validationsList.length;
          validationsList.removeWhere((validation) => 
              deletedCodeOpsList.contains(validation['code_ops']));
          removedFromValidations = initialValidationsCount - validationsList.length;

          if (removedFromValidations > 0) {
            await prefs.setString('pending_validations', jsonEncode(validationsList));
            debugPrint('💾 $removedFromValidations validations removed');
          }
        } catch (e) {
          debugPrint('⚠️ Error removing validations: $e');
        }
      }

      // 4. Remove from local transfers
      int removedFromLocalTransfers = 0;
      final localTransfersJson = prefs.getString('local_transfers');
      if (localTransfersJson != null) {
        try {
          final List<dynamic> localList = jsonDecode(localTransfersJson);
          final localTransfers = localList
              .map((json) => OperationModel.fromJson(json))
              .toList();

          final initialLocalCount = localTransfers.length;
          localTransfers.removeWhere((op) => 
              op.codeOps != null && deletedCodeOpsList.contains(op.codeOps));
          removedFromLocalTransfers = initialLocalCount - localTransfers.length;

          if (removedFromLocalTransfers > 0) {
            await prefs.setString(
              'local_transfers',
              jsonEncode(localTransfers.map((op) => op.toJson()).toList()),
            );
            debugPrint('💾 $removedFromLocalTransfers operations removed from local_transfers');
          }
        } catch (e) {
          debugPrint('⚠️ Error removing from local_transfers: $e');
        }
      }

      final totalRemoved = removedFromMemory + removedFromLocalDB + 
                          removedFromValidations + removedFromLocalTransfers;
      debugPrint('✅ Local cleanup completed: $totalRemoved operations removed ' +
                 '($removedFromMemory memory, $removedFromLocalDB LocalDB, ' +
                 '$removedFromValidations validations, $removedFromLocalTransfers local_transfers)');

      // Notify listeners if operations were removed
      if (totalRemoved > 0) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error during local cleanup: $e');
    }
  }

  // Charger les opérations
  Future<void> loadOperations({int? shopId, int? agentId, bool excludeVirement = true}) async {
    _setLoading(true);
    try {
      // Sauvegarder les filtres actifs pour réutilisation
      if (shopId != null) _activeShopFilter = shopId;
      if (agentId != null) _activeAgentFilter = agentId;
      
      // Si aucun filtre passé, réutiliser les filtres actifs sauvegardés
      final effectiveShopFilter = shopId ?? _activeShopFilter;
      final effectiveAgentFilter = agentId ?? _activeAgentFilter;
      
      _operations = await LocalDB.instance.getAllOperations();
      
      debugPrint('📊 loadOperations: ${_operations.length} opérations totales chargées depuis LocalDB');
      
      // Filter out deleted operations
      _operations = await _filterOutDeletedOperations(_operations);
      debugPrint('📊 Après filtrage des opérations supprimées: ${_operations.length} opérations');

      // Exclure les virements (FLOT) par défaut car ils sont visibles dans la section dédiée aux FLOTS
      if (excludeVirement) {
        final beforeExclusion = _operations.length;
        _operations = _operations.where((op) => op.type != OperationType.virement).toList();
        debugPrint('🚫 Exclusion FLOT (virements): $beforeExclusion → ${_operations.length}');
      }
      
      // Pas d'initialisation de données par défaut
      // Les opérations seront créées uniquement par les utilisateurs
      
      if (effectiveShopFilter != null) {
        final beforeFilter = _operations.length;
        _operations = _operations.where((op) => 
          op.shopSourceId == effectiveShopFilter || op.shopDestinationId == effectiveShopFilter).toList();
        debugPrint('📊 Filtre shopId=$effectiveShopFilter: $beforeFilter → ${_operations.length} opérations');
        debugPrint('   ✅ Inclut: capital initial du shop + toutes ops du shop + transferts entrants');
      }
      
      if (effectiveAgentFilter != null) {
        final beforeFilter = _operations.length;
        _operations = _operations.where((op) => op.agentId == effectiveAgentFilter).toList();
        debugPrint('📊 Filtre agentId=$effectiveAgentFilter: $beforeFilter → ${_operations.length} opérations');
      }
      
      _operations.sort((a, b) => b.dateOp.compareTo(a.dateOp));
      _errorMessage = null;
      debugPrint('📊 ✅ Opérations finales: ${_operations.length}');
      if (_operations.isNotEmpty) {
        int initialCapitalCount = 0;
        for (var op in _operations) {
          // Compter les opérations de capital initial
          if (op.destinataire == 'CAPITAL INITIAL') {
            initialCapitalCount++;
            debugPrint('💰 OP #${op.id}: CAPITAL INITIAL - ${op.type.name}, montant=${op.montantNet}, shop_source=${op.shopSourceId}');
          } else {
            debugPrint('   - Op #${op.id}: ${op.type.name}, shop_source=${op.shopSourceId}, shop_dest=${op.shopDestinationId}, agent=${op.agentId}');
          }
        }
        if (initialCapitalCount > 0) {
          debugPrint('💰 Total opérations de capital initial: $initialCapitalCount');
        }
      }
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement: $e';
      debugPrint(_errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  // Pas d'initialisation de données de test
  // Les opérations sont créées uniquement par les utilisateurs

  Future<OperationModel?> createOperation(OperationModel operation, {AuthService? authService}) async {
    try {
      // ✅ VÉRIFIER SI L'UTILISATEUR EST ADMIN - Les admins sont exemptés de la clôture
      final isAdmin = authService?.currentUser?.role == 'ADMIN';
      
      if (!isAdmin) {
        // ✅ VÉRIFIER SI LES JOURS PRÉCÉDENTS SONT CLÔTURÉS (uniquement pour les agents)
        // Un agent ne peut pas effectuer une opération si les jours précédents ne sont pas clôturés
        if (operation.shopSourceId != null) {
          final joursNonClotures = await RapportClotureService.instance.verifierAccesMenusAgent(
            operation.shopSourceId!,
          );
          
          if (joursNonClotures != null && joursNonClotures.isNotEmpty) {
            final premiereDate = joursNonClotures.first;
            final dateStr = '${premiereDate.day.toString().padLeft(2, '0')}/${premiereDate.month.toString().padLeft(2, '0')}/${premiereDate.year}';
            _errorMessage = 'Vous devez d\'abord clôturer les journées précédentes (depuis le $dateStr). ${joursNonClotures.length} jour(s) à clôturer.';
            debugPrint('❌ $_errorMessage');
            throw Exception(_errorMessage);
          }
        }
        
        // ✅ VÉRIFIER SI LA JOURNÉE D'AUJOURD'HUI EST CLÔTURÉE (uniquement pour les agents)
        // Un agent ne peut plus effectuer une opération si sa journée est clôturée
        if (operation.shopSourceId != null) {
          final today = DateTime.now();
          final isClosedToday = await LocalDB.instance.clotureExistsPourDate(
            operation.shopSourceId!,
            today,
          );
          
          if (isClosedToday) {
            final dateStr = '${today.day.toString().padLeft(2, '0')}/${today.month.toString().padLeft(2, '0')}/${today.year}';
            _errorMessage = 'La journée du $dateStr est déjà clôturée. Aucune opération ne peut être effectuée.';
            debugPrint('❌ $_errorMessage');
            throw Exception(_errorMessage);
          }
        }
      } else {
        debugPrint('✅ Utilisateur ADMIN - Exemption de clôture accordée pour l\'opération');
      }
      
      // RÉSOUDRE et ENRICHIR l'opération avec l'USERNAME de l'agent AVANT sauvegarde
      OperationModel enrichedOperation = operation;
      
      // Obtenir l'username de l'agent connecté depuis AuthService
      if (authService != null && authService.currentUser != null) {
        final agentUsername = authService.currentUser!.username;
        enrichedOperation = operation.copyWith(
          lastModifiedBy: 'agent_$agentUsername', // Stocker username pour sync
        );
        debugPrint('✅ Agent enrichi depuis session: username "$agentUsername"');
      } else {
        // Fallback: chercher l'agent par ID (si disponible localement)
        // Since agentId is non-nullable, this check is always true
        if (true) {
          // Vérifier si les agents sont chargés en mémoire
          if (AgentService.instance.agents.isEmpty) {
            debugPrint('⚠️ Liste des agents vide, rechargement depuis LocalDB...');
            await AgentService.instance.loadAgents();
            debugPrint('✅ ${AgentService.instance.agents.length} agents chargés');
          }
          
          final agent = AgentService.instance.getAgentById(operation.agentId!);
          if (agent != null) {
            enrichedOperation = operation.copyWith(
              lastModifiedBy: 'agent_${agent.username}',
            );
            debugPrint('✅ Agent enrichi par ID: username "${agent.username}"');
          } else {
            debugPrint('⚠️ Agent non trouvé pour ID ${operation.agentId}');
            
            // Vérifier si des agents existent APRÈS rechargement
            final agents = AgentService.instance.agents;
            if (agents.isEmpty) {
              debugPrint('❌ CRITIQUE: Aucun agent disponible même après rechargement!');
              debugPrint('💡 Solution: Synchronisez pour télécharger les agents depuis MySQL');
              throw Exception('Aucun agent disponible. Veuillez synchroniser d\'abord.');
            } else {
              debugPrint('📊 Agents disponibles: ${agents.map((a) => "ID=${a.id} username=${a.username}").join(", ")}');
            }
          }
        } else {
          debugPrint('⚠️ Opération créée sans agentId ni AuthService');
        }
      }
      
      // Générer le code d'opération unique avec milliseconde pour garantir l'unicité
      // Format: YYMMDDHHMMSSXXX (14 chiffres) - aucun caractère spécial
      final now = DateTime.now();
      final year = (now.year % 100).toString().padLeft(2, '0');
      final month = now.month.toString().padLeft(2, '0');
      final day = now.day.toString().padLeft(2, '0');
      final hour = now.hour.toString().padLeft(2, '0');
      final minute = now.minute.toString().padLeft(2, '0');
      final second = now.second.toString().padLeft(2, '0');
      final milliseconds = (now.millisecondsSinceEpoch % 1000).toString().padLeft(3, '0');
      final codeOps = '$year$month$day$hour$minute$second$milliseconds';
      
      debugPrint('✅ Code opération généré: $codeOps');
      
      // Ajouter le codeOps à l'opération
      final operationWithCode = enrichedOperation.copyWith(
        codeOps: codeOps,
      );
      
      // Calculer la commission automatiquement SI PAS DÉJÀ CALCULÉE
      OperationModel operationWithCommission;
      if (operationWithCode.commission > 0 || operationWithCode.montantBrut > 0) {
        // Commission déjà calculée dans le formulaire, ne pas recalculer
        operationWithCommission = operationWithCode;
        debugPrint('✅ Commission déjà calculée: ${operationWithCode.commission} USD');
      } else {
        // Pas de commission, calculer automatiquement (dépôts, retraits, etc.)
        operationWithCommission = await _calculateCommission(operationWithCode);
      }
      
      // Mettre à jour les soldes selon le type d'opération
      await _updateBalances(operationWithCommission);
      
      // Sauvegarder l'opération en local en priorité (mode offline-first)
      final savedOperation = await LocalDB.instance.saveOperation(operationWithCommission);
      
      // Créer l'entrée dans le journal de caisse
      await _createJournalEntry(savedOperation);
      
      // Enregistrer automatiquement les frais dans le compte FRAIS
      if (savedOperation.commission > 0) {
        // Selon la logique métier : les frais appartiennent au SHOP DESTINATION qui servira le transfert
        final fraisShopId = (savedOperation.shopDestinationId != null && 
                           (savedOperation.type == OperationType.transfertNational ||
                            savedOperation.type == OperationType.transfertInternationalSortant))
                          ? savedOperation.shopDestinationId!
                          : savedOperation.shopSourceId!;
        
        // Récupérer les informations pour la description détaillée
        final shopSource = await LocalDB.instance.getShopById(savedOperation.shopSourceId!);
        final shopDest = savedOperation.shopDestinationId != null 
            ? await LocalDB.instance.getShopById(savedOperation.shopDestinationId!)
            : null;
        
        // Nom du client déposant (qui envoie)
        final deposant = savedOperation.clientNom ?? 'Client inconnu';
        
        // Nom du destinataire (qui reçoit)
        final destinataire = savedOperation.destinataire ?? 'Destinataire inconnu';
        
        // Description détaillée : Déposant → Destinataire - Montant - Shops
        final description = shopDest != null
            ? 'Commission: $deposant → $destinataire - \$${savedOperation.montantNet.toStringAsFixed(2)} (${shopSource?.designation ?? "Shop ${savedOperation.shopSourceId}"} → ${shopDest.designation})'
            : 'Commission: $deposant → $destinataire - \$${savedOperation.montantNet.toStringAsFixed(2)} (${shopSource?.designation ?? "Shop ${savedOperation.shopSourceId}"})'; 
        
        await CompteSpecialService.instance.addFrais(
          montant: savedOperation.commission,
          description: description,
          shopId: fraisShopId, // ← CORRECTED: Frais vont au shop destination pour transferts
          operationId: savedOperation.id,
          agentId: savedOperation.agentId,
          agentUsername: savedOperation.agentUsername,
        );
        debugPrint('💰 FRAIS enregistrés: \$${savedOperation.commission.toStringAsFixed(2)} au Shop ID: $fraisShopId');
        debugPrint('   Description: $description');
      }
      
      // Toujours sauvegarder en local d'abord, la synchronisation se fera en arrière-plan
      debugPrint('💾 Opération sauvegardée localement avec succès (ID: ${savedOperation.id})');
      
      // Démarrer la synchronisation en arrière-plan (ne bloque pas l'interface)
      _syncOperationInBackground(savedOperation);
      
      // Recharger les opérations
      await loadOperations();
      
      debugPrint('✅ Opération créée et sauvegardée localement: ${savedOperation.id}');
      return savedOperation;
    } catch (e) {
      _errorMessage = 'Erreur lors de la création: $e';
      debugPrint(_errorMessage);
      return null;
    }
  }

  // Valider une opération
  Future<bool> validateOperation(int operationId, ModePaiement modePaiement) async {
    try {
      final operation = _operations.firstWhere((op) => op.id == operationId);
      
      // PROTECTION: Ne pas permettre de revalider une opération déjà validée
      if (operation.dateValidation != null) {
        _errorMessage = 'Cette opération a déjà été validée le ${operation.dateValidation}';
        debugPrint('⚠️ $_errorMessage');
        notifyListeners();
        return false;
      }
      
      final updatedOperation = operation.copyWith(
        statut: OperationStatus.validee,
        modePaiement: modePaiement,
        dateValidation: DateTime.now(), // Définie UNE SEULE FOIS
        lastModifiedAt: DateTime.now(),
      );
      
      await LocalDB.instance.updateOperation(updatedOperation);

      // Synchroniser la mise à jour vers le serveur en arrière-plan
      _syncOperationInBackground(updatedOperation);

      // Recharger les données
      await loadOperations();
      
      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la validation: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Calculer la commission selon le type d'opération
  Future<OperationModel> _calculateCommission(OperationModel operation) async {
    double commission = 0.0;
    
    switch (operation.type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Récupérer la commission depuis RatesService pour les transferts sortants
        final ratesService = RatesService.instance;
        await ratesService.loadRatesAndCommissions();
        
        final commissionData = ratesService.commissions.firstWhere(
          (c) => c.type == 'SORTANT',
          orElse: () {
            debugPrint('❌ ERREUR: Commission SORTANT non trouvée dans la base de données!');
            throw Exception('Commission SORTANT non configurée. Veuillez configurer les commissions dans le système.');
          },
        );
        
        // Commission calculée sur le montantNet (ce que le destinataire reçoit)
        // BUSINESS LOGIC: Commission is calculated on the net amount because that's what the recipient actually receives
        // The shop destination keeps this commission as revenue for serving the transfer
        // IMPORTANT: Arrondir à 2 décimales
        commission = double.parse((operation.montantNet * (commissionData.taux / 100)).toStringAsFixed(2));
        debugPrint('💰 Commission calculée: ${commission.toStringAsFixed(2)} ${operation.devise} (${commissionData.taux}% de ${operation.montantNet})');
        debugPrint('📌 NOTE: Cette commission appartient au SHOP DESTINATION qui servira le transfert');
        break;
        
      case OperationType.transfertInternationalEntrant:
        // Transferts entrants gratuits
        commission = 0.0;
        break;
        
      case OperationType.depot:
      case OperationType.retrait:
        // Dépôts et retraits dans comptes clients : pas de commission
        commission = 0.0;
        break;
        
      case OperationType.retraitMobileMoney:
        // Retraits Mobile Money : frais selon l'opérateur
        // Le montantNet est le montant VIRTUEL reçu sur la SIM
        // Les frais sont déduits pour donner le montant CASH au client
        commission = _calculateRetraitMobileMoneyFees(operation.modePaiement, operation.montantNet);
        debugPrint('💰 Frais Retrait Mobile Money: ${commission.toStringAsFixed(2)} ${operation.devise} (${_getRetraitFeeRate(operation.modePaiement)}% de ${operation.montantNet})');
        break;
        
      case OperationType.virement:
        // Virements internes gratuits
        commission = 0.0;
        break;
        
      case OperationType.flotShopToShop:
        // FLOTs shop-to-shop : TOUJOURS commission = 0
        commission = 0.0;
        break;
    }
    
    // montantNet = ce que le destinataire reçoit
    // montantBrut = montantNet + commission (ce que le client paie au shop source)
    // LOGIQUE: Le shop source reçoit le montant BRUT et doit le montant BRUT au shop destination
    //          Le shop destination garde la COMMISSION et sert le montant NET au bénéficiaire
    return operation.copyWith(
      commission: commission,
      montantBrut: operation.montantNet + commission,  // Client paie Net + Commission
    );
  }

  // Mettre à jour les soldes selon le type d'opération
  Future<void> _updateBalances(OperationModel operation) async {
    switch (operation.type) {
      case OperationType.depot:
        await _handleDepotBalances(operation);
        break;
      case OperationType.retrait:
        await _handleRetraitBalances(operation);
        break;
      case OperationType.retraitMobileMoney:
        await _handleRetraitMobileMoneyBalances(operation);
        break;
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
      case OperationType.transfertInternationalEntrant:
        await _handleTransfertBalances(operation);
        break;
      case OperationType.virement:
        // Les virements internes ne changent pas les soldes globaux
        break;
      case OperationType.flotShopToShop:
        // Les FLOTs sont gérés par FlotService (capital déjà mis à jour)
        break;
    }
  }

  // Gérer les soldes pour un dépôt
  Future<void> _handleDepotBalances(OperationModel operation) async {
    try {
      // 1. Augmenter le solde du client
      if (operation.clientId != null) {
        final client = await LocalDB.instance.getClientById(operation.clientId!);
        if (client != null) {
          final nouveauSolde = client.solde + operation.montantNet;
          final updatedClient = client.copyWith(
            solde: nouveauSolde,
            lastModifiedAt: DateTime.now(),
            lastModifiedBy: 'operation_${operation.id}',
          );
          await LocalDB.instance.saveClient(updatedClient);
          debugPrint('💰 Solde client ${client.nom}: ${client.solde} → ${nouveauSolde} USD');
          
          // 🔥 NOUVEAU: Dépôt avec shop de destination différent du shop source
          if (operation.shopDestinationId != null && 
              operation.shopDestinationId != operation.shopSourceId) {
            await _handleIntershopCredit(
              sourceShopId: operation.shopSourceId!,
              destinationShopId: operation.shopDestinationId!,
              amount: operation.montantNet,
              operationType: 'depot',
              clientName: client.nom,
              operationId: operation.id,
            );
          }
        }
      }

      // 2. Augmenter le capital du shop selon le mode de paiement
      if (operation.shopSourceId != null) {
        final shop = await LocalDB.instance.getShopById(operation.shopSourceId!);
        if (shop != null) {
          final updatedShop = _updateShopCapital(shop, operation.modePaiement, operation.montantNet, true, devise: operation.devise);
          await LocalDB.instance.saveShop(updatedShop);
          debugPrint('🏪 Capital shop ${shop.designation} mis a jour (+${operation.montantNet} ${operation.devise})');
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes dépôt: $e');
      throw e;
    }
  }

  // Gérer les soldes pour un FLOT shop-to-shop
  Future<void> _handleFlotBalances(OperationModel operation) async {
    try {
      // LOGIQUE MÉTIER FLOT :
      // 1. À la création : Shop source ENVOIE l'argent (diminution de capital)
      // 2. À la validation : Shop destination REÇOIT l'argent (augmentation de capital)
      
      if (operation.statut == OperationStatus.enAttente) {
        // CRÉATION DU FLOT : Shop source envoie l'argent
        if (operation.shopSourceId != null) {
          final shopSource = await LocalDB.instance.getShopById(operation.shopSourceId!);
          if (shopSource != null) {
            // Le shop source PERD le montant net (envoie l'argent)
            final updatedShopSource = _updateShopCapital(shopSource, operation.modePaiement, operation.montantNet, false, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopSource);
            debugPrint('🏪 Shop source ${shopSource.designation}: -${operation.montantNet} ${operation.devise} (FLOT envoyé)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : SORTIE pour le shop source
            final journalEntryEnvoi = JournalCaisseModel(
              shopId: operation.shopSourceId!,
              agentId: operation.agentId,
              libelle: 'FLOT ENVOYÉ - Vers ${operation.shopDestinationDesignation ?? "Shop"}',
              montant: operation.montantNet, // Montant envoyé
              type: TypeMouvement.sortie, // SORTIE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date d'envoi
              operationId: operation.id,
              notes: 'FLOT shop-to-shop envoyé depuis ${shopSource.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryEnvoi);
            debugPrint('📝 Journal caisse: SORTIE de ${operation.montantNet} ${operation.devise} pour shop source (FLOT)');
          }
        }
      } else if (operation.statut == OperationStatus.validee) {
        // VALIDATION DU FLOT : Shop destination reçoit l'argent
        
        if (operation.shopDestinationId != null) {
          final shopDestination = await LocalDB.instance.getShopById(operation.shopDestinationId!);
          if (shopDestination != null) {
            // Le shop destination GAGNE le montant net (reçoit l'argent)
            final updatedShopDestination = _updateShopCapital(shopDestination, operation.modePaiement, operation.montantNet, true, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopDestination);
            debugPrint('🏪 Shop destination ${shopDestination.designation}: +${operation.montantNet} ${operation.devise} (FLOT reçu)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : ENTRÉE pour le shop destination
            final journalEntryRecu = JournalCaisseModel(
              shopId: operation.shopDestinationId!,
              agentId: operation.agentId,
              libelle: 'FLOT REÇU - De ${operation.shopSourceDesignation ?? "Shop"}',
              montant: operation.montantNet, // Montant reçu
              type: TypeMouvement.entree, // ENTRÉE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date de réception/validation
              operationId: operation.id,
              notes: 'FLOT shop-to-shop reçu par ${shopDestination.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryRecu);
            debugPrint('📝 Journal caisse: ENTRÉE de ${operation.montantNet} ${operation.devise} pour shop destination (FLOT)');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes FLOT: $e');
      rethrow;
    }
  }

  // Gérer les soldes pour un retrait
  Future<void> _handleRetraitBalances(OperationModel operation) async {
    try {      // 1. Diminuer le solde du client (DÉCOUVERT AUTORISÉ - solde peut devenir négatif)
      if (operation.clientId != null) {
        final client = await LocalDB.instance.getClientById(operation.clientId!);
        if (client != null) {
          // IMPORTANT: Pas de vérification de solde insuffisant
          // Le client peut avoir un solde négatif (Nous que Devons de l'argent au client)
          // ou retirer plus que son solde (le client nous doit de l'argent)
          
          final nouveauSolde = client.solde - operation.montantNet;
          final updatedClient = client.copyWith(
            solde: nouveauSolde,
            lastModifiedAt: DateTime.now(),
            lastModifiedBy: 'operation_${operation.id}',
          );
          await LocalDB.instance.saveClient(updatedClient);
          
          if (nouveauSolde < 0) {
            debugPrint('💰 Solde client ${client.nom}: ${client.solde} → ${nouveauSolde} USD (DÉCOUVERT - client nous doit ${nouveauSolde.abs()} USD)');
          } else {
            debugPrint('💰 Solde client ${client.nom}: ${client.solde} → ${nouveauSolde} USD');
          }
          
          // 🔥 LOGIQUE INTERSHOP: Gestion des crédits/dettes pour retrait avec destination
          // 1. Retrait cross-shop classique (client d'un autre shop)
          final clientShopId = client.shopId;
          if (clientShopId != null && clientShopId != operation.shopSourceId) {
            await _handleCrossShopDebt(
              clientOriginalShopId: clientShopId,
              withdrawalShopId: operation.shopSourceId!,
              amount: operation.montantNet,
              clientName: client.nom,
              operationId: operation.id,
            );
          }
          
          // 2. NOUVEAU: Retrait avec shop de destination différent du shop source
          if (operation.shopDestinationId != null && 
              operation.shopDestinationId != operation.shopSourceId) {
            await _handleIntershopCredit(
              sourceShopId: operation.shopSourceId!,
              destinationShopId: operation.shopDestinationId!,
              amount: operation.montantNet,
              operationType: 'retrait',
              clientName: client.nom,
              operationId: operation.id,
            );
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes retrait: $e');
      throw e;
    }
  }





  /// Gérer les soldes pour un retrait Mobile Money (Cash-Out)
  /// LOGIQUE: 
  /// - À la création (enAttente): PAS de mouvement (juste enregistrement)
  /// - À la validation: Augmente virtuel SIM + Diminue cash agent
  /// FRAIS: montantBrut = virtuel reçu, montantNet = cash donné, commission = frais
  Future<void> _handleRetraitMobileMoneyBalances(OperationModel operation) async {
    try {
      // Si EN_ATTENTE : Pas de mouvement de capital (juste enregistrement)
      if (operation.statut == OperationStatus.enAttente) {
        debugPrint('📱 Retrait Mobile Money enregistré (en attente): Référence ${operation.reference}');
        debugPrint('   Aucun mouvement de capital pour l\'instant');
        return;
      }
      
      // Si VALIDE : Mise à jour SIM + Capital
      if (operation.statut == OperationStatus.validee || operation.statut == OperationStatus.terminee) {
        debugPrint('📱 === VALIDATION RETRAIT MOBILE MONEY ===');
        debugPrint('   Montant VIRTUEL (SIM): ${operation.montantBrut} ${operation.devise}');
        debugPrint('   Frais: ${operation.commission} ${operation.devise}');
        debugPrint('   Montant CASH (Client): ${operation.montantNet} ${operation.devise}');
        debugPrint('   Référence: ${operation.reference}');
        debugPrint('   SIM: ${operation.simNumero}');
        
        // 1. Augmenter le solde virtuel de la SIM (montantBrut = virtuel)
        if (operation.simNumero != null) {
          final simService = SimService.instance;
          await simService.loadSims(shopId: operation.shopSourceId);
          
          final sim = simService.sims.firstWhere(
            (s) => s.numero == operation.simNumero,
            orElse: () => throw Exception('SIM ${operation.simNumero} introuvable'),
          );
          
          final updatedSim = sim.copyWith(
            soldeActuel: sim.soldeActuel + operation.montantBrut, // VIRTUEL = montantBrut
            lastModifiedAt: DateTime.now(),
            lastModifiedBy: 'operation_${operation.id}',
          );
          
          await LocalDB.instance.updateSim(updatedSim);
          debugPrint('💳 Solde SIM ${sim.numero}: ${sim.soldeActuel.toStringAsFixed(2)} → ${updatedSim.soldeActuel.toStringAsFixed(2)} USD (+${operation.montantBrut})');
        }
        
        // 2. Diminuer le capital CASH du shop (montantNet = cash donné au client)
        if (operation.shopSourceId != null) {
          final shop = await LocalDB.instance.getShopById(operation.shopSourceId!);
          if (shop != null) {
            // Diminuer le CASH du montant NET (ce que le client reçoit)
            final updatedShop = _updateShopCapital(shop, ModePaiement.cash, operation.montantNet, false, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShop);
            debugPrint('🏪 Capital CASH shop ${shop.designation}: -${operation.montantNet} ${operation.devise}');
            
            // Créer entrée journal de caisse (SORTIE du cash)
            final journalEntry = JournalCaisseModel(
              shopId: operation.shopSourceId!,
              agentId: operation.agentId,
              libelle: 'Retrait Mobile Money - ${operation.destinataire ?? "Client"} (Réf: ${operation.reference})',
              montant: operation.montantNet, // Cash sorti
              type: TypeMouvement.sortie,
              mode: ModePaiement.cash,
              dateAction: DateTime.now(),
              operationId: operation.id,
              notes: 'Cash-Out ${_getModePaiementName(operation.modePaiement)} vers SIM ${operation.simNumero} - Frais: ${operation.commission} ${operation.devise}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntry);
            debugPrint('📋 Journal caisse: SORTIE CASH de ${operation.montantNet} ${operation.devise}');
          }
        }
        
        debugPrint('✅ Retrait Mobile Money validé avec succès!');
        debugPrint('   💰 RÉCAPITULATIF:');
        debugPrint('      Virtuel SIM: +${operation.montantBrut} ${operation.devise}');
        debugPrint('      Frais Agent: +${operation.commission} ${operation.devise}');
        debugPrint('      Cash Sorti: -${operation.montantNet} ${operation.devise}');
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes retrait mobile money: $e');
      throw e;
    }
  }

  // Gérer les soldes pour un transfert selon la logique métier UCASH
  Future<void> _handleTransfertBalances(OperationModel operation) async {
    try {
      // LOGIQUE MÉTIER UCASH CORRECTE :
      // 1. À la création : Shop source GAGNE l'argent (client paie)
      // 2. À la validation : Shop destination PERD l'argent (sert le bénéficiaire)
      
      if (operation.statut == OperationStatus.enAttente) {
        // CRÉATION DU TRANSFERT : Shop source reçoit l'argent du client
        if (operation.shopSourceId != null) {
          final shopSource = await LocalDB.instance.getShopById(operation.shopSourceId!);
          if (shopSource != null) {
            // Le shop source GAGNE le montant brut (montant + commission)
            final updatedShopSource = _updateShopCapital(shopSource, operation.modePaiement, operation.montantBrut, true, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopSource);
            debugPrint('🏪 Shop source ${shopSource.designation}: +${operation.montantBrut} ${operation.devise} (client paie)');
          }
        }
      } else if (operation.statut == OperationStatus.validee) {
        // VALIDATION DU TRANSFERT : Shop destination sert l'argent
        
        // Transferts nationaux
        if (operation.shopDestinationId != null && operation.type == OperationType.transfertNational) {
          final shopDestination = await LocalDB.instance.getShopById(operation.shopDestinationId!);
          if (shopDestination != null) {
            // Le shop destination PERD le montant net (sert au bénéficiaire)
            final updatedShopDestination = _updateShopCapital(shopDestination, operation.modePaiement, operation.montantNet, false, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopDestination);
            debugPrint('🏪 Shop destination ${shopDestination.designation}: -${operation.montantNet} ${operation.devise} (sert beneficiaire)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : SORTIE pour le shop destination
            final journalEntryServie = JournalCaisseModel(
              shopId: operation.shopDestinationId!,
              agentId: operation.agentId,
              libelle: 'Transfert SERVIE - ${operation.destinataire} (Montant servi)',
              montant: operation.montantNet, // Montant servi au bénéficiaire
              type: TypeMouvement.sortie, // SORTIE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date de validation/service
              operationId: operation.id,
              notes: 'Transfert validé depuis ${shopDestination.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryServie);
            debugPrint('📝 Journal caisse: SORTIE de ${operation.montantNet} ${operation.devise} pour shop destination');
          }
        }
        
        // Transferts internationaux ENTRANTS : même logique
        if (operation.shopDestinationId != null && operation.type == OperationType.transfertInternationalEntrant) {
          final shopDestination = await LocalDB.instance.getShopById(operation.shopDestinationId!);
          if (shopDestination != null) {
            // Le shop destination PERD le montant net (sert au bénéficiaire)
            final updatedShopDestination = _updateShopCapital(shopDestination, operation.modePaiement, operation.montantNet, false, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopDestination);
            debugPrint('🏪 Shop destination ${shopDestination.designation}: -${operation.montantNet} ${operation.devise} (sert beneficiaire international)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : SORTIE pour le shop destination
            final journalEntryServie = JournalCaisseModel(
              shopId: operation.shopDestinationId!,
              agentId: operation.agentId,
              libelle: 'Transfert International SERVIE - ${operation.destinataire} (Montant servi)',
              montant: operation.montantNet, // Montant servi au bénéficiaire
              type: TypeMouvement.sortie, // SORTIE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date de validation/service
              operationId: operation.id,
              notes: 'Transfert international validé depuis ${shopDestination.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryServie);
            debugPrint('📝 Journal caisse: SORTIE de ${operation.montantNet} ${operation.devise} pour shop destination (international)');
          }
        }
        
        // Transferts internationaux SORTANTS : Logique spéciale
        if (operation.shopSourceId != null && operation.type == OperationType.transfertInternationalSortant) {
          final shopSource = await LocalDB.instance.getShopById(operation.shopSourceId!);
          if (shopSource != null) {
            // Le shop source GAGNE le montant brut (montant + commission)
            final updatedShopSource = _updateShopCapital(shopSource, operation.modePaiement, operation.montantBrut, true, devise: operation.devise);
            await LocalDB.instance.saveShop(updatedShopSource);
            debugPrint('🏪 Shop source ${shopSource.designation}: +${operation.montantBrut} ${operation.devise} (transfert international sortant)');
            
            // CRÉER ENTRÉE JOURNAL DE CAISSE : ENTRÉE pour le shop source
            final journalEntryEnvoi = JournalCaisseModel(
              shopId: operation.shopSourceId!,
              agentId: operation.agentId,
              libelle: 'Transfert International ENVOYÉ - ${operation.destinataire} (Montant envoyé)',
              montant: operation.montantBrut, // Montant envoyé (brut avec commission)
              type: TypeMouvement.entree, // ENTRÉE de caisse
              mode: operation.modePaiement,
              dateAction: DateTime.now(), // Date d'envoi
              operationId: operation.id,
              notes: 'Transfert international envoyé depuis ${shopSource.designation}',
              lastModifiedAt: DateTime.now(),
              lastModifiedBy: 'agent_${operation.agentId}',
            );
            
            await LocalDB.instance.saveJournalEntry(journalEntryEnvoi);
            debugPrint('📝 Journal caisse: ENTRÉE de ${operation.montantBrut} ${operation.devise} pour shop source (international)');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Erreur mise à jour soldes transfert: $e');
      rethrow; // Utiliser rethrow au lieu de throw e
    }
  }

  // Mettre à jour le capital d'un shop selon le mode de paiement ET la devise
  ShopModel _updateShopCapital(ShopModel shop, ModePaiement modePaiement, double montant, bool isCredit, {String? devise}) {
    final factor = isCredit ? 1.0 : -1.0;
    final deltaAmount = montant * factor;
    
    // Determiner la devise de l'operation (par defaut USD)
    final deviseOp = devise ?? shop.devisePrincipale;
    
    // Si la devise de l'operation est la devise principale
    if (deviseOp == shop.devisePrincipale) {
      switch (modePaiement) {
        case ModePaiement.cash:
          return shop.copyWith(
            capitalCash: shop.capitalCash + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
        case ModePaiement.airtelMoney:
          return shop.copyWith(
            capitalAirtelMoney: shop.capitalAirtelMoney + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
        case ModePaiement.mPesa:
          return shop.copyWith(
            capitalMPesa: shop.capitalMPesa + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
        case ModePaiement.orangeMoney:
          return shop.copyWith(
            capitalOrangeMoney: shop.capitalOrangeMoney + deltaAmount,
            capitalActuel: shop.capitalActuel + deltaAmount,
          );
      }
    } 
    // Si la devise de l'operation est la devise secondaire
    else if (deviseOp == shop.deviseSecondaire) {
      switch (modePaiement) {
        case ModePaiement.cash:
          return shop.copyWith(
            capitalCashDevise2: (shop.capitalCashDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
        case ModePaiement.airtelMoney:
          return shop.copyWith(
            capitalAirtelMoneyDevise2: (shop.capitalAirtelMoneyDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
        case ModePaiement.mPesa:
          return shop.copyWith(
            capitalMPesaDevise2: (shop.capitalMPesaDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
        case ModePaiement.orangeMoney:
          return shop.copyWith(
            capitalOrangeMoneyDevise2: (shop.capitalOrangeMoneyDevise2 ?? 0) + deltaAmount,
            capitalActuelDevise2: (shop.capitalActuelDevise2 ?? 0) + deltaAmount,
          );
      }
    }
    
    // Si la devise n'est pas supportee, retourner le shop inchange
    debugPrint('⚠️ Devise $deviseOp non supportee par le shop ${shop.designation}');
    return shop;
  }

  /// Helper pour obtenir le nom du mode de paiement
  String _getModePaiementName(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }

  /// Obtenir le taux de frais pour retrait Mobile Money selon l'opérateur
  double _getRetraitFeeRate(ModePaiement operateur) {
    switch (operateur) {
      case ModePaiement.airtelMoney:
        return 4.0; // 4% pour Airtel Money
      case ModePaiement.mPesa:
        return 3.5; // 3.5% pour M-Pesa
      case ModePaiement.orangeMoney:
        return 4.0; // 4% pour Orange Money
      case ModePaiement.cash:
        return 0.0; // Pas de frais pour cash
    }
  }

  /// Calculer les frais de retrait Mobile Money
  /// montantVirtuel = montant reçu sur la SIM
  /// Retourne les frais à déduire
  double _calculateRetraitMobileMoneyFees(ModePaiement operateur, double montantVirtuel) {
    final tauxPourcentage = _getRetraitFeeRate(operateur);
    final frais = (montantVirtuel * tauxPourcentage / 100);
    return double.parse(frais.toStringAsFixed(2)); // Arrondi à 2 décimales
  }

  // Créer une ou plusieurs entrées dans le journal de caisse
  Future<void> _createJournalEntry(OperationModel operation) async {
    String libelle = '';
    TypeMouvement type = TypeMouvement.entree;
    double montant = operation.montantNet;
    
    switch (operation.type) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Pour les transferts sortants: ENTRÉE du montant TOTAL (brut = à servir + commission)
        libelle = 'Transfert ${operation.typeLabel} - ${operation.destinataire} (Total reçu)';
        montant = operation.montantBrut; // TOTAL = montant à servir + commission
        type = TypeMouvement.entree; // ENTRÉE en caisse
        break;
        
      case OperationType.transfertInternationalEntrant:
        libelle = 'Réception ${operation.typeLabel} - ${operation.destinataire}';
        montant = operation.montantNet;
        type = TypeMouvement.entree;
        break;
        
      case OperationType.depot:
        libelle = 'Dépôt - ${operation.destinataire ?? "Partenaire"}';
        montant = operation.montantNet;
        type = TypeMouvement.entree; // ENTRÉE en caisse
        break;
        
      case OperationType.retrait:
        libelle = 'Retrait - ${operation.destinataire ?? "Partenaire"}';
        montant = operation.montantNet;
        type = TypeMouvement.sortie; // SORTIE de caisse
        break;
        
      case OperationType.virement:
        libelle = 'Virement - ${operation.destinataire}';
        montant = operation.montantNet;
        type = TypeMouvement.entree; // Neutre pour le shop
        break;
        
      default:
        libelle = 'Opération - ${operation.typeLabel}';
        montant = operation.montantNet;
        type = TypeMouvement.entree;
    }
    
    // Créer l'entrée journal
    final journalEntry = JournalCaisseModel(
      shopId: operation.shopSourceId ?? 0,
      agentId: operation.agentId,
      libelle: libelle,
      montant: montant,
      type: type,
      mode: operation.modePaiement,
      dateAction: operation.dateOp,
      operationId: operation.id,
      notes: operation.commission > 0 
          ? 'Dont commission: ${operation.commission.toStringAsFixed(2)} ${operation.devise}'
          : null,
      lastModifiedAt: DateTime.now(),
      lastModifiedBy: 'agent_${operation.agentId}',
    );
    
    await LocalDB.instance.saveJournalEntry(journalEntry);
    debugPrint('📝 Journal caisse: ${type.name.toUpperCase()} de $montant ${operation.devise} - $libelle');
  }

  // Obtenir les statistiques du jour AVEC DONNEES LOCALES REELLES
  Map<String, dynamic> getDailyStats(int agentId) {
    final today = DateTime.now();
    final todayOperations = _operations.where((op) => 
      op.agentId == agentId &&
      op.dateOp.year == today.year &&
      op.dateOp.month == today.month &&
      op.dateOp.day == today.day
    ).toList();
    
    final transferts = todayOperations.where((op) => 
      op.type == OperationType.transfertNational ||
      op.type == OperationType.transfertInternationalSortant ||
      op.type == OperationType.transfertInternationalEntrant
    ).length;
    
    final depots = todayOperations.where((op) => op.type == OperationType.depot).length;
    final retraits = todayOperations.where((op) => op.type == OperationType.retrait).length;
    final virements = todayOperations.where((op) => op.type == OperationType.virement).length;
    
    // CALCUL REEL: Commissions par devise
    final commissionsUSD = todayOperations
        .where((op) => op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    final commissionsCDF = todayOperations
        .where((op) => op.devise == 'CDF')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    final commissionsUGX = todayOperations
        .where((op) => op.devise == 'UGX')
        .fold<double>(0.0, (sum, op) => sum + op.commission);
    
    // CALCUL REEL: Montants totaux par devise
    final montantTotalUSD = todayOperations
        .where((op) => op.devise == 'USD')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    final montantTotalCDF = todayOperations
        .where((op) => op.devise == 'CDF')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    final montantTotalUGX = todayOperations
        .where((op) => op.devise == 'UGX')
        .fold<double>(0.0, (sum, op) => sum + op.montantBrut);
    
    return {
      'transferts': transferts,
      'depots': depots,
      'retraits': retraits,
      'virements': virements,
      'totalOperations': todayOperations.length,
      // Commissions par devise
      'commissionsUSD': commissionsUSD,
      'commissionsCDF': commissionsCDF,
      'commissionsUGX': commissionsUGX,
      'commissionsEncaissees': commissionsUSD, // Pour compatibilite (USD par defaut)
      // Montants par devise
      'montantTotalUSD': montantTotalUSD,
      'montantTotalCDF': montantTotalCDF,
      'montantTotalUGX': montantTotalUGX,
      // Operations par statut
      'enAttente': todayOperations.where((op) => op.statut == OperationStatus.enAttente).length,
      'validees': todayOperations.where((op) => op.statut == OperationStatus.validee).length,
      'annulees': todayOperations.where((op) => op.statut == OperationStatus.annulee).length,
    };
  }

  // Filtrer les opérations
  List<OperationModel> filterOperations({
    OperationStatus? statut,
    OperationType? type,
    DateTime? dateDebut,
    DateTime? dateFin,
    bool excludeVirement = true, // Par défaut, exclure les virements (FLOT)
  }) {
    var filtered = List<OperationModel>.from(_operations);
    
    // Exclure les virements (FLOT) par défaut car ils sont visibles dans la section dédiée
    if (excludeVirement) {
      filtered = filtered.where((op) => op.type != OperationType.virement).toList();
    }
    
    if (statut != null) {
      filtered = filtered.where((op) => op.statut == statut).toList();
    }
    
    if (type != null) {
      filtered = filtered.where((op) => op.type == type).toList();
    }
    
    if (dateDebut != null) {
      filtered = filtered.where((op) => op.dateOp.isAfter(dateDebut)).toList();
    }
    
    if (dateFin != null) {
      filtered = filtered.where((op) => op.dateOp.isBefore(dateFin)).toList();
    }
    
    return filtered;
  }

  // Mettre à jour une opération
  Future<bool> updateOperation(OperationModel operation) async {
    try {
      // Récupérer l'ancienne opération pour comparer les statuts (si elle existe)
      final oldOperation = _operations.where((op) => op.id == operation.id).firstOrNull;
      
      await LocalDB.instance.updateOperation(operation);
      
      // Si c'est un transfert qui passe de "enAttente" à "validee", gérer les soldes ET le journal
      // IMPORTANT: Seulement si l'opération existait déjà localement en EN_ATTENTE
      if (oldOperation != null &&
          oldOperation.statut == OperationStatus.enAttente && 
          operation.statut == OperationStatus.validee &&
          (operation.type == OperationType.transfertNational ||
           operation.type == OperationType.transfertInternationalSortant ||
           operation.type == OperationType.transfertInternationalEntrant)) {
        
        debugPrint('🔄 Validation du transfert ${operation.id} - Mise à jour des soldes et journal...');
        await _handleTransfertBalances(operation);
      } 
      // Si c'est un FLOT qui passe de "enAttente" à "validee", gérer les soldes ET le journal
      else if (oldOperation != null &&
          oldOperation.statut == OperationStatus.enAttente && 
          operation.statut == OperationStatus.validee &&
          operation.type == OperationType.flotShopToShop) {
        
        debugPrint('🔄 Validation du FLOT ${operation.id} - Mise à jour des soldes et journal...');
        await _handleFlotBalances(operation);
      } 
      else if (oldOperation == null && operation.statut == OperationStatus.validee) {        // Cas: Opération reçue du serveur déjà VALIDEE (Shop source découvre que Shop destination a servi)
        debugPrint('📥 Transfert ${operation.id} reçu du serveur avec statut VALIDEE (déjà servi)');
        debugPrint('   ✅ Pas de mise à jour des soldes (déjà effectuée par Shop destination)');
      }
      
      // Recharger les opérations
      await loadOperations();
      
      debugPrint('✅ Opération ${operation.id} mise à jour avec succès');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  /// Supprimer une opération (Admin uniquement)
  /// Utilise codeOps pour identifier l'opération sur le serveur (car id est auto-increment)
  Future<bool> deleteOperation(int operationId) async {
    try {
      debugPrint('🗑️ Suppression de l\'opération $operationId...');
      
      // Récupérer l'opération pour obtenir son codeOps
      final operation = getOperationById(operationId);
      if (operation == null) {
        _errorMessage = 'Opération non trouvée';
        debugPrint(_errorMessage);
        return false;
      }
      
      // 1. Supprimer sur le serveur d'abord en utilisant codeOps
      try {
        final url = '${AppConfig.apiBaseUrl}/sync/operations/delete.php';
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'codeOps': operation.codeOps}),
        );
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            debugPrint('✅ Opération supprimée du serveur (codeOps: ${operation.codeOps})');
          } else {
            debugPrint('⚠️ Erreur serveur: ${result['error']}');
            // Continue quand même avec la suppression locale
          }
        } else {
          debugPrint('⚠️ Erreur HTTP ${response.statusCode}: ${response.body}');
          // Continue quand même avec la suppression locale
        }
      } catch (e) {
        debugPrint('⚠️ Erreur de connexion au serveur: $e');
        debugPrint('   Suppression locale uniquement (sera re-téléchargée lors de la sync)');
        // Continue avec la suppression locale même si le serveur est inaccessible
      }
      
      // 2. Supprimer de la base de données locale
      await LocalDB.instance.deleteOperation(operationId);
      
      // 3. Supprimer de la mémoire
      _operations.removeWhere((op) => op.id == operationId);
      
      notifyListeners();
      debugPrint('✅ Opération $operationId supprimée avec succès');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }

  // Charger les opérations d'un client spécifique
  Future<void> loadClientOperations(int clientId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final allOperations = await LocalDB.instance.getAllOperations();
      _operations = allOperations.where((op) => op.clientId == clientId).toList();
      
      // Trier par date décroissante
      _operations.sort((a, b) => b.dateOp.compareTo(a.dateOp));
      
      debugPrint('✅ ${_operations.length} opérations chargées pour le client $clientId');
    } catch (e) {
      _errorMessage = 'Erreur lors du chargement des opérations: $e';
      debugPrint(_errorMessage);
    }

    _isLoading = false;
    notifyListeners();
  }

  // Obtenir une opération par ID
  OperationModel? getOperationById(int id) {
    try {
      return _operations.firstWhere((op) => op.id == id);
    } catch (e) {
      return null;
    }
  }
  
  OperationModel? getOperationByCodeOps(String codeOps) {
    try {
      return _operations.firstWhere((op) => op.codeOps == codeOps);
    } catch (e) {
      return null;
    }
  }
  
  /// Get operation from database by CodeOps (used when operation may not be in memory)
  Future<OperationModel?> getOperationByCodeOpsFromDB(String codeOps) async {
    try {
      return await LocalDB.instance.getOperationByCodeOps(codeOps);
    } catch (e) {
      debugPrint('Error getting operation by CodeOps: $e');
      return null;
    }
  }
  
  /// Delete operation by CodeOps (unique identifier - more reliable than ID)
  Future<bool> deleteOperationByCodeOps(String codeOps) async {
    try {
      debugPrint('🗑️ Suppression de l\'opération par CodeOps: $codeOps...');
      
      // 1. Get the operation from database
      final operation = await LocalDB.instance.getOperationByCodeOps(codeOps);
      if (operation == null) {
        _errorMessage = 'Opération non trouvée (CodeOps: $codeOps)';
        debugPrint(_errorMessage);
        return false;
      }
      
      // 2. Delete from local database FIRST (immediate)
      if (operation.id != null) {
        await LocalDB.instance.deleteOperation(operation.id!);
        debugPrint('✅ Opération $codeOps supprimée en LOCAL');
      }
      
      // 3. Remove from memory to update UI immediately
      _operations.removeWhere((op) => op.codeOps == codeOps);
      notifyListeners();
      
      // 4. Delete on server in BACKGROUND (non-blocking)
      _syncOperationDeleteInBackground(codeOps);
      
      debugPrint('✅ Opération $codeOps supprimée avec succès (sync en arrière-plan)');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la suppression: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Remove operation from memory only (used by DeletionService)
  /// Does NOT delete from database or server - only removes from in-memory list
  void removeOperationFromMemory(String codeOps) {
    final countBefore = _operations.length;
    _operations.removeWhere((op) => op.codeOps == codeOps);
    final countAfter = _operations.length;
    
    if (countBefore > countAfter) {
      debugPrint('📋 Opération $codeOps retirée de la mémoire OperationService ($countBefore -> $countAfter)');
      notifyListeners();
    } else {
      debugPrint('⚠️ Opération $codeOps non trouvée en mémoire (déjà supprimée?)');
    }
  }
  
  /// Sync operation deletion to server in background
  void _syncOperationDeleteInBackground(String codeOps) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/operations/delete.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation suppression serveur: $codeOps...');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'codeOps': codeOps}),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Opération $codeOps supprimée sur le serveur');
          // Remove from pending deletions queue if it was there
          _pendingDeletions.remove(codeOps);
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Ajout à la queue de retry');
          _addToPendingDeletions(codeOps);
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Ajout à la queue de retry');
        _addToPendingDeletions(codeOps);
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT suppression: $e - Ajout à la queue de retry');
      _addToPendingDeletions(codeOps);
    } on http.ClientException catch (e) {
      debugPrint('⚠️ [BACKGROUND] Pas d\'internet (ClientException): $e - Ajout à la queue de retry');
      _addToPendingDeletions(codeOps);
    } catch (e) {
      debugPrint('⚠️ [BACKGROUND] Erreur suppression: $e - Ajout à la queue de retry');
      _addToPendingDeletions(codeOps);
    }
  }
  
  /// Add CodeOps to pending deletions queue
  void _addToPendingDeletions(String codeOps) {
    if (!_pendingDeletions.contains(codeOps)) {
      _pendingDeletions.add(codeOps);
      debugPrint('📋 Suppression ajoutée à la queue de retry: $codeOps (Total: ${_pendingDeletions.length})');
    }
  }
  
  /// Retry all pending deletions
  Future<void> _retryPendingDeletions() async {
    if (_pendingDeletions.isEmpty) {
      return;
    }
    
    debugPrint('🔄 [RETRY] Tentative de synchronisation de ${_pendingDeletions.length} suppressions en attente...');
    
    // Create a copy to iterate over (to avoid concurrent modification)
    final deletionsToRetry = List<String>.from(_pendingDeletions);
    
    for (final codeOps in deletionsToRetry) {
      try {
        final url = '${AppConfig.apiBaseUrl}/sync/operations/delete.php';
        debugPrint('🔄 [RETRY] Suppression: $codeOps...');
        
        final response = await http.post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'codeOps': codeOps}),
        ).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final result = jsonDecode(response.body);
          if (result['success'] == true) {
            debugPrint('✅ [RETRY] Suppression $codeOps réussie sur le serveur');
            _pendingDeletions.remove(codeOps);
          } else {
            debugPrint('⚠️ [RETRY] Erreur serveur: ${result["message"]} - Restera en queue');
          }
        } else {
          debugPrint('⚠️ [RETRY] HTTP ${response.statusCode} - Restera en queue');
        }
      } catch (e) {
        debugPrint('⚠️ [RETRY] Erreur pour $codeOps: $e - Restera en queue');
        // Stop retrying if we have connection issues
        break;
      }
    }
    
    if (_pendingDeletions.isEmpty) {
      debugPrint('✅ [RETRY] Toutes les suppressions en attente ont été synchronisées!');
    } else {
      debugPrint('📋 [RETRY] ${_pendingDeletions.length} suppressions restent en attente');
    }
  }
  
  /// Update operation by CodeOps (unique identifier - more reliable than ID)
  Future<bool> updateOperationByCodeOps(OperationModel operation) async {
    try {
      debugPrint('🔄 Mise à jour de l\'opération par CodeOps: ${operation.codeOps}...');
      
      // 1. Update in local database FIRST (immediate)
      await LocalDB.instance.updateOperationByCodeOps(operation);
      debugPrint('✅ Opération ${operation.codeOps} mise à jour en LOCAL');
      
      // 2. Update in memory to reflect changes immediately in UI
      final index = _operations.indexWhere((op) => op.codeOps == operation.codeOps);
      if (index != -1) {
        _operations[index] = operation.copyWith(isSynced: false); // Mark as not synced
        notifyListeners();
      }
      
      // 3. Sync to server in BACKGROUND (non-blocking)
      _syncOperationUpdateInBackground(operation);
      
      debugPrint('✅ Opération ${operation.codeOps} mise à jour avec succès (sync en arrière-plan)');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la mise à jour: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Sync operation update to server in background
  void _syncOperationUpdateInBackground(OperationModel operation) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/operations/update.php';
      debugPrint('🌐 [BACKGROUND] Synchronisation serveur: ${operation.codeOps}...');
      debugPrint('🌐 [BACKGROUND] URL: $url');
      
      final jsonBody = jsonEncode(operation.toJson());
      debugPrint('📦 [BACKGROUND] Taille du body: ${jsonBody.length} caractères');
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      ).timeout(const Duration(seconds: 10));
      
      debugPrint('📡 [BACKGROUND] Réponse HTTP ${response.statusCode}');
      debugPrint('📡 [BACKGROUND] Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [BACKGROUND] Opération ${operation.codeOps} synchronisée sur le serveur');
          
          // Mark as synced in local DB
          final syncedOp = operation.copyWith(isSynced: true, syncedAt: DateTime.now());
          await LocalDB.instance.updateOperationByCodeOps(syncedOp);
          
          // Update in memory
          final index = _operations.indexWhere((op) => op.codeOps == operation.codeOps);
          if (index != -1) {
            _operations[index] = syncedOp;
            notifyListeners();
          }
        } else {
          debugPrint('⚠️ [BACKGROUND] Erreur serveur: ${result["message"]} - Restera en attente de sync');
        }
      } else {
        debugPrint('⚠️ [BACKGROUND] Erreur HTTP ${response.statusCode} - Restera en attente de sync');
      }
    } on TimeoutException catch (e) {
      debugPrint('⚠️ [BACKGROUND] TIMEOUT (10s): $e');
    } on http.ClientException catch (e) {
      debugPrint('⚠️ [BACKGROUND] ClientException: $e');
    } on FormatException catch (e) {
      debugPrint('⚠️ [BACKGROUND] FormatException (JSON invalide): $e');
    } catch (e, stackTrace) {
      debugPrint('⚠️ [BACKGROUND] ERREUR COMPLETE: Type=${e.runtimeType}, Message=$e');
      debugPrint('⚠️ [BACKGROUND] STACK TRACE: $stackTrace');
    }
  }
  
  /// Valider un transfert depuis le serveur (Shop Destination UNIQUEMENT)
  /// Permet de marquer un transfert comme SERVIE et mettre à jour les soldes
  /// SÉCURITÉ: Vérifie que le shop connecté est bien le DESTINATAIRE
  Future<bool> validerTransfertServeur(int operationId, ModePaiement modePaiement, {int? currentShopId}) async {
    try {
      final operation = _operations.where((op) => op.id == operationId).firstOrNull;
      
      if (operation == null) {
        _errorMessage = 'Opération non trouvée';
        debugPrint(_errorMessage);
        return false;
      }
      
      // Vérifier que c'est un transfert
      if (operation.type != OperationType.transfertNational &&
          operation.type != OperationType.transfertInternationalSortant &&
          operation.type != OperationType.transfertInternationalEntrant) {
        _errorMessage = 'Cette opération n\'est pas un transfert';
        debugPrint(_errorMessage);
        return false;
      }
      
      // ❗ SÉCURITÉ CRITIQUE: Vérifier que le shop connecté est le DESTINATAIRE
      if (currentShopId != null && operation.shopDestinationId != currentShopId) {
        _errorMessage = '❌ ERREUR DE SÉCURITÉ: Ce transfert n\'est pas destiné à votre shop!';
        debugPrint('❌ TENTATIVE DE VALIDATION INTERDITE:');
        debugPrint('   Shop connecté: $currentShopId');
        debugPrint('   Shop destination du transfert: ${operation.shopDestinationId}');
        debugPrint('   Shop source du transfert: ${operation.shopSourceId}');
        debugPrint('   ⚠️ Seul le shop DESTINATION peut valider un transfert!');
        return false;
      }
      
      // Vérifier le statut
      if (operation.statut != OperationStatus.enAttente) {
        _errorMessage = 'Le transfert n\'est pas en attente (Statut actuel: ${operation.statut.name})';
        debugPrint(_errorMessage);
        return false;
      }
      
      // PROTECTION: Ne pas permettre de revalider une opération déjà validée
      if (operation.dateValidation != null) {
        _errorMessage = 'Ce transfert a déjà été validé le ${operation.dateValidation}';
        debugPrint('⚠️ $_errorMessage');
        return false;
      }
      
      // Mettre à jour le statut et le mode de paiement
      final updatedOperation = operation.copyWith(
        statut: OperationStatus.validee,
        modePaiement: modePaiement,
        dateValidation: DateTime.now(), // Définie UNE SEULE FOIS
        lastModifiedAt: DateTime.now(),
        isSynced: false,  // IMPORTANT: Marquer comme non synchronisé pour forcer l'upload
      );
      
      await LocalDB.instance.updateOperation(updatedOperation);
      
      // Gérer les soldes et créer l'entrée journal (SORTIE)
      await _handleTransfertBalances(updatedOperation);
      
      // Recharger les opérations
      await loadOperations();
      
      // SYNCHRONISATION EN ARRIÈRE-PLAN: Upload le changement de statut vers le serveur
      debugPrint('🔄 Synchronisation en arrière-plan du transfert validé...');
      try {
        // Utiliser la synchronisation en arrière-plan
        _syncOperationInBackground(updatedOperation);
        debugPrint('✅ Transfert ${operationId} synchronisation lancée en arrière-plan');
      } catch (e) {
        debugPrint('⚠️ Erreur de synchronisation (transfert validé localement): $e');
        // L'opération est validée localement, la sync se fera plus tard
      }
      
      debugPrint('✅ Transfert ${operationId} validé et servi avec succès');
      return true;
    } catch (e) {
      _errorMessage = 'Erreur lors de la validation: $e';
      debugPrint(_errorMessage);
      notifyListeners();
      return false;
    }
  }
  
  /// Récupérer les transferts SERVIS concernant ce shop (Shop Source)
  /// Retourne les transferts que ce shop a envoyés et qui ont été servis par le shop destination
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la SOURCE
  List<OperationModel> getTransfertsServis({int? shopId}) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // Vérifier que c'est SERVIE (validée)
      final isServie = op.statut == OperationStatus.validee;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la SOURCE (a envoyé le transfert)
      final isSource = shopId == null || op.shopSourceId == shopId;
      
      return isTransfert && isServie && isSource;
    }).toList();
  }
  
  /// Récupérer les transferts EN ATTENTE à servir (Shop Destination)
  /// Retourne UNIQUEMENT les transferts que ce shop doit servir
  /// EXCLUT les FLOTs (flotShopToShop) qui ont leur propre section de gestion
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la DESTINATION
  List<OperationModel> getTransfertsAServir(int shopDestinationId) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert (PAS un FLOT)
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // Vérifier que c'est EN ATTENTE
      final isEnAttente = op.statut == OperationStatus.enAttente;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la DESTINATION (doit servir)
      final isDestination = op.shopDestinationId == shopDestinationId;
      
      return isTransfert && isEnAttente && isDestination;
    }).toList();
  }
  
  /// Récupérer les transferts ENVOYÉS par ce shop (Shop Source)
  /// Retourne TOUS les transferts créés par ce shop (EN_ATTENTE + SERVIS)
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la SOURCE
  List<OperationModel> getTransfertsEnvoyes(int shopSourceId) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la SOURCE
      final isSource = op.shopSourceId == shopSourceId;
      
      return isTransfert && isSource;
    }).toList();
  }
  
  /// Récupérer les transferts REÇUS par ce shop (Shop Destination)
  /// Retourne TOUS les transferts destinés à ce shop (EN_ATTENTE + SERVIS)
  /// SÉCURITÉ: Filtre UNIQUEMENT les transferts où ce shop est la DESTINATION
  List<OperationModel> getTransfertsRecus(int shopDestinationId) {
    return _operations.where((op) {
      // Vérifier que c'est un transfert
      final isTransfert = op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant ||
                          op.type == OperationType.transfertInternationalEntrant;
      
      // ❗ SÉCURITÉ: Vérifier que ce shop est la DESTINATION
      final isDestination = op.shopDestinationId == shopDestinationId;
      
      return isTransfert && isDestination;
    }).toList();
  }
  
  /// Vérifier si un agent/shop peut valider un transfert
  /// EXCLUT les FLOTs (flotShopToShop) qui ont leur propre gestion
  /// Retourne true UNIQUEMENT si le shop est le DESTINATAIRE
  bool peutValiderTransfert(int operationId, int currentShopId) {
    final operation = _operations.where((op) => op.id == operationId).firstOrNull;
    
    if (operation == null) return false;
    
    // Vérifier que c'est un transfert (PAS un FLOT)
    final isTransfert = operation.type == OperationType.transfertNational ||
                        operation.type == OperationType.transfertInternationalSortant ||
                        operation.type == OperationType.transfertInternationalEntrant;
    
    if (!isTransfert) return false;
    
    // Vérifier que le statut est EN_ATTENTE
    if (operation.statut != OperationStatus.enAttente) return false;
    
    // ❗ SÉCURITÉ CRITIQUE: Vérifier que le shop est le DESTINATAIRE
    return operation.shopDestinationId == currentShopId;
  }
  
  /// Gérer les crédits/dettes intershop pour les opérations depot/retrait avec shop destination
  /// 
  /// **Logique métier pour depot/retrait avec destination:**
  /// - Agent du Shop A fait un dépôt pour un client vers Shop B
  /// - 🔄 DETTE: Shop A doit le montant à Shop B (car Shop B recevra l'impact)
  /// - 🔄 CRÉANCE: Shop B a une créance sur Shop A
  /// 
  /// Pour retrait:
  /// - Agent du Shop A fait un retrait pour un client depuis Shop B
  /// - 🔄 DETTE: Shop B doit le montant à Shop A (car Shop A donne l'argent)
  /// - 🔄 CRÉANCE: Shop A a une créance sur Shop B
  Future<void> _handleIntershopCredit({
    required int sourceShopId,
    required int destinationShopId,
    required double amount,
    required String operationType,
    required String clientName,
    int? operationId,
  }) async {
    try {
      // Charger les deux shops concernés
      final sourceShop = await LocalDB.instance.getShopById(sourceShopId);
      final destinationShop = await LocalDB.instance.getShopById(destinationShopId);
      
      if (sourceShop == null || destinationShop == null) {
        debugPrint('⚠️ Shops non trouvés pour calcul crédit intershop');
        return;
      }
      
      debugPrint('🔥 === CRÉDIT INTERSHOP DÉTECTÉ ===');
      debugPrint('🏪 Shop source: ${sourceShop.designation} (ID: ${sourceShop.id})');
      debugPrint('🏪 Shop destination: ${destinationShop.designation} (ID: ${destinationShop.id})');
      debugPrint('💵 Montant: $amount USD');
      debugPrint('📋 Type: $operationType');
      debugPrint('👤 Client: $clientName');
      
      if (operationType == 'depot') {
        // DÉPÔT: Shop source doit à shop destination
        // Car le shop destination recevra l'impact du dépôt
        
        // 1. Augmenter les dettes du shop source
        final updatedSourceShop = sourceShop.copyWith(
          dettes: sourceShop.dettes + amount,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'system_intershop_depot',
        );
        await LocalDB.instance.saveShop(updatedSourceShop);
        debugPrint('❌ ${sourceShop.designation}: Dettes ${sourceShop.dettes} → ${updatedSourceShop.dettes} USD');
        
        // 2. Augmenter les créances du shop destination
        final updatedDestinationShop = destinationShop.copyWith(
          creances: destinationShop.creances + amount,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'system_intershop_depot',
        );
        await LocalDB.instance.saveShop(updatedDestinationShop);
        debugPrint('✅ ${destinationShop.designation}: Créances ${destinationShop.creances} → ${updatedDestinationShop.creances} USD');
        
      } else if (operationType == 'retrait') {
        // RETRAIT: Shop destination doit à shop source
        // Car le shop source donne l'argent pour un client du shop destination
        
        // 1. Augmenter les créances du shop source
        final updatedSourceShop = sourceShop.copyWith(
          creances: sourceShop.creances + amount,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'system_intershop_retrait',
        );
        await LocalDB.instance.saveShop(updatedSourceShop);
        debugPrint('✅ ${sourceShop.designation}: Créances ${sourceShop.creances} → ${updatedSourceShop.creances} USD');
        
        // 2. Augmenter les dettes du shop destination
        final updatedDestinationShop = destinationShop.copyWith(
          dettes: destinationShop.dettes + amount,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'system_intershop_retrait',
        );
        await LocalDB.instance.saveShop(updatedDestinationShop);
        debugPrint('❌ ${destinationShop.designation}: Dettes ${destinationShop.dettes} → ${updatedDestinationShop.dettes} USD');
      }
      
      debugPrint('📊 RÉSUMÉ INTERSHOP:');
      debugPrint('   • Opération: $operationType de $amount USD');
      debugPrint('   • Client: $clientName');
      debugPrint('   • Impact crédit intershop appliqué avec succès');
      debugPrint('🔥 === FIN CRÉDIT INTERSHOP ===');
      
    } catch (e) {
      debugPrint('❌ Erreur gestion crédit intershop: $e');
      // Ne pas bloquer l'opération si le crédit ne peut pas être créé
    }
  }
  
  /// Gérer la dette automatique entre shops lors d'un retrait cross-shop
  /// 
  /// **Logique métier UCASH:**
  /// - Client créé par Shop MOKU avec solde de 10000 USD
  /// - Client fait un retrait de 5000 USD au Shop NGANGAZU
  /// - 🔄 DETTE AUTOMATIQUE: NGANGAZU doit 5000 USD à MOKU
  /// - 🔄 CRÉANCE AUTOMATIQUE: MOKU a une créance de 5000 USD sur NGANGAZU
  /// 
  /// Cette logique permet de suivre les mouvements d'argent entre shops
  /// quand les clients font des opérations cross-shop
  Future<void> _handleCrossShopDebt({
    required int clientOriginalShopId,
    required int withdrawalShopId,
    required double amount,
    required String clientName,
    int? operationId,
  }) async {
    try {
      // Charger les deux shops concernés
      final originalShop = await LocalDB.instance.getShopById(clientOriginalShopId);
      final withdrawalShop = await LocalDB.instance.getShopById(withdrawalShopId);
      
      if (originalShop == null || withdrawalShop == null) {
        debugPrint('⚠️ Shops non trouvés pour calcul dette cross-shop');
        return;
      }
      
      debugPrint('🔥 === DETTE CROSS-SHOP DÉTECTÉE ===');
      debugPrint('🏪 Shop client: ${originalShop.designation} (ID: ${originalShop.id})');
      debugPrint('🏪 Shop retrait: ${withdrawalShop.designation} (ID: ${withdrawalShop.id})');
      debugPrint('💵 Montant: $amount USD');
      debugPrint('👤 Client: $clientName');
      
      // LOGIQUE: Shop qui effectue le retrait DOIT au shop d'origine du client
      // Car le shop de retrait a donné de l'argent pour un client d'un autre shop
      
      // 1. Mettre à jour les dettes du shop qui effectue le retrait
      final updatedWithdrawalShop = withdrawalShop.copyWith(
        dettes: withdrawalShop.dettes + amount,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'system_cross_shop_debt',
      );
      await LocalDB.instance.saveShop(updatedWithdrawalShop);
      debugPrint('❌ ${withdrawalShop.designation}: Dettes ${withdrawalShop.dettes} → ${updatedWithdrawalShop.dettes} USD');
      
      // 2. Mettre à jour les créances du shop d'origine du client
      final updatedOriginalShop = originalShop.copyWith(
        creances: originalShop.creances + amount,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'system_cross_shop_debt',
      );
      await LocalDB.instance.saveShop(updatedOriginalShop);
      debugPrint('✅ ${originalShop.designation}: Créances ${originalShop.creances} → ${updatedOriginalShop.creances} USD');
      
      debugPrint('📊 RÉSUMÉ:');
      debugPrint('   • ${withdrawalShop.designation} doit maintenant ${updatedWithdrawalShop.dettes} USD au total');
      debugPrint('   • ${originalShop.designation} a maintenant ${updatedOriginalShop.creances} USD de créances au total');
      debugPrint('🔥 === FIN DETTE CROSS-SHOP ===');
      
    } catch (e) {
      debugPrint('❌ Erreur gestion dette cross-shop: $e');
      // Ne pas bloquer l'opération de retrait si la dette ne peut pas être créée
    }
  }
  
  /// Démarrer la vérification automatique des opérations en attente toutes les 30 secondes
  void startPendingOpsCheck({int? shopId}) {
    if (_isPendingOpsCheckEnabled) {
      debugPrint('⚠️ Vérification automatique déjà activée');
      return;
    }
    
    _isPendingOpsCheckEnabled = true;
    _activeShopFilter = shopId; // Sauvegarder le filtre shop pour les vérifications
    
    debugPrint('⏰ Démarrage de la vérification automatique des opérations en attente (toutes les 30s)');
    
    // Vérification immédiate (avec protection)
    _checkPendingOperations().catchError((error) {
      debugPrint('❌ Erreur lors de la vérification initiale: $error');
    });
    
    // Démarrer le timer pour vérifications régulières
    _pendingOpsTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isPendingOpsCheckEnabled) {
        // Exécuter avec protection contre les erreurs non capturées
        _checkPendingOperations().catchError((error) {
          debugPrint('❌ Erreur dans Timer.periodic: $error');
        });
      } else {
        timer.cancel();
      }
    });
  }
  
  /// Arrêter la vérification automatique des opérations en attente
  void stopPendingOpsCheck() {
    if (!_isPendingOpsCheckEnabled) {
      debugPrint('⚠️ Vérification automatique déjà arrêtée');
      return;
    }
    
    _isPendingOpsCheckEnabled = false;
    _pendingOpsTimer?.cancel();
    _pendingOpsTimer = null;
    
    debugPrint('⏹️ Arrêt de la vérification automatique des opérations en attente');
  }
  
  /// Vérifier les opérations en attente et synchroniser si nécessaire
  Future<void> _checkPendingOperations() async {
    try {
      debugPrint('🔍 Vérification des opérations en attente...');
      
      // Récupérer les transferts en attente depuis MySQL via API
      if (_activeShopFilter != null) {
        await _fetchPendingTransfersFromServer(_activeShopFilter!);
      }
      
      // Récupérer toutes les opérations localement
      final allOps = await LocalDB.instance.getAllOperations();
      debugPrint('📊 Vérification transferts: ${allOps.length} opérations en mémoire');
      
      // Filtrer les opérations en attente
      List<OperationModel> pendingOps = allOps.where((op) {
        // Pour les transferts: doit être EN ATTENTE
        if ((op.type == OperationType.transfertNational ||
             op.type == OperationType.transfertInternationalSortant ||
             op.type == OperationType.transfertInternationalEntrant) &&
            op.statut == OperationStatus.enAttente) {
          return true;
        }
        // Pour les FLOTs: doit être EN ATTENTE
        if (op.type == OperationType.flotShopToShop &&
            op.statut == OperationStatus.enAttente) {
          return true;
        }
        // Pour les depot/retrait: peut être VALIDE ou TERMINE
        if ((op.type == OperationType.depot ||
             op.type == OperationType.retrait) &&
            (op.statut == OperationStatus.validee || op.statut == OperationStatus.terminee)) {
          return true;
        }
        return false;
      }).toList();
      
      // Filtrer par shop si nécessaire (transferts + FLOTs destinés à ce shop, depot/retrait provenant de ce shop)
      if (_activeShopFilter != null) {
        pendingOps = pendingOps.where((op) => 
          // Pour les transferts et FLOTs, le shop doit être la destination
          ((op.type == OperationType.transfertNational ||
            op.type == OperationType.transfertInternationalSortant ||
            op.type == OperationType.transfertInternationalEntrant ||
            op.type == OperationType.flotShopToShop) &&
           op.shopDestinationId == _activeShopFilter) ||
          // Pour les depot/retrait, le shop doit être la source
          ((op.type == OperationType.depot ||
            op.type == OperationType.retrait) &&
           op.shopSourceId == _activeShopFilter)
        ).toList();
        debugPrint('🔍 ${pendingOps.length} opérations en attente pour shop $_activeShopFilter');
      }
      
      final previousCount = _pendingOpsCount;
      _pendingOpsCount = pendingOps.length;
      
      if (_pendingOpsCount > 0) {
        debugPrint('📥 $_pendingOpsCount opération(s) en attente trouvée(s)');
        
        // Afficher les détails des opérations en attente
        for (final op in pendingOps) {
          debugPrint('   - ID ${op.id}: ${op.type.name}, de Shop ${op.shopSourceId} vers Shop ${op.shopDestinationId}, montant: ${op.montantNet} ${op.devise}');
        }
      } else {
        if (previousCount > 0) {
          debugPrint('✅ Aucune opération en attente');
        }
      }
      
      // Notifier les listeners du changement de compteur (avec protection)
      if (previousCount != _pendingOpsCount) {
        try {
          notifyListeners();
          debugPrint('✅ Listeners notifiés du changement de compteur');
        } catch (e) {
          debugPrint('⚠️ Erreur lors de notifyListeners: $e');
        }
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur lors de la vérification des opérations en attente: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      // Ne pas propager l'erreur pour éviter le crash de l'app
    }
  }
  
  /// Vérifier manuellement les opérations en attente (pour bouton refresh)
  Future<void> checkPendingOperationsNow() async {
    await _checkPendingOperations();
  }
  
  /// Récupérer les transferts en attente depuis le serveur MySQL
  Future<void> _fetchPendingTransfersFromServer(int shopId) async {
    try {
      debugPrint('🌐 Récupération des transferts en attente depuis le serveur pour Shop $shopId...');
      
      final baseUrl = await AppConfig.getSyncBaseUrl();
      
      final url = '$baseUrl/operations/pending_transfers.php?shop_id=$shopId';
      debugPrint('🔗 URL: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['success'] == true) {
          final transfers = data['transfers'] as List;
          debugPrint('📥 ${transfers.length} transfert(s) récupéré(s) depuis le serveur');
          
          // Sauvegarder les transferts localement
          for (final transferJson in transfers) {
            try {
              // Vérifier si l'opération existe déjà localement
              final existingOps = await LocalDB.instance.getAllOperations();
              final existingOp = existingOps.where((op) => op.id == transferJson['id']).firstOrNull;
              
              if (existingOp == null) {
                // Nouvelle opération, la sauvegarder
                final operation = OperationModel.fromJson(transferJson);
                await LocalDB.instance.saveOperation(operation);
                debugPrint('   ✅ Transfert ID ${operation.id} sauvegardé localement');
              } else if (existingOp.statut != OperationStatus.enAttente) {
                // Opération existe mais statut différent, mettre à jour
                final operation = OperationModel.fromJson(transferJson);
                await LocalDB.instance.updateOperation(operation);
                debugPrint('   🔄 Transfert ID ${operation.id} mis à jour localement');
              }
            } catch (e) {
              debugPrint('   ⚠️ Erreur sauvegarde transfert: $e');
            }
          }
          
          // Recharger les opérations après ajout/mise à jour (avec protection)
          try {
            await loadOperations(shopId: shopId);
            debugPrint('✅ Opérations rechargées après sync transferts');
          } catch (e) {
            debugPrint('⚠️ Erreur rechargement opérations: $e');
          }
          
        } else {
          debugPrint('⚠️ Réponse serveur: ${data['message']}');
        }
      } else {
        debugPrint('⚠️ Erreur HTTP: ${response.statusCode}');
      }
      
    } catch (e, stackTrace) {
      debugPrint('❌ Erreur récupération transferts depuis serveur: $e');
      debugPrint('📚 Stack trace: $stackTrace');
      // Ne pas bloquer le processus en cas d'erreur
    }
  }
  
  /// Synchronise une opération en arrière-plan sans bloquer l'interface
  /// Utilise DepotRetraitSyncService pour les dépôts/retraits, SyncService pour les transferts
  Future<void> _syncOperationInBackground(OperationModel operation) async {
    Future.microtask(() async {
      try {
        // Vérifier le type d'opération
        final isDepotRetrait = operation.type == OperationType.depot ||
                              operation.type == OperationType.retrait ||
                              operation.type == OperationType.retraitMobileMoney;
        
        if (isDepotRetrait) {
          // Utiliser le service spécialisé pour dépôts/retraits
          debugPrint('💰 [DEPOT/RETRAIT] Ajout à la queue de sync spécialisée: ${operation.type.name} - ${operation.codeOps}');
          
          final depotRetraitSync = DepotRetraitSyncService();
          await depotRetraitSync.queueOperation(operation);
          
          debugPrint('✅ [DEPOT/RETRAIT] Opération en file - synchronisation auto dans 2s');
        } else {
          // Utiliser la queue générique pour les transferts
          debugPrint('📦 [TRANSFERT] Ajout à la queue générale: ${operation.type.name} - ${operation.codeOps}');
          
          final operationMap = operation.toJson();
          final syncService = SyncService();
          await syncService.queueOperation(operationMap);
          
          debugPrint('✅ [QUEUE] Opération en file - RobustSyncService la synchronisera');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ [SYNC] Erreur ajout opération: $e');
        debugPrint('   Stack trace: $stackTrace');
      }
    });
  }
  
  /// Marquer une opération comme synchronisée
  Future<void> _markOperationAsSynced(int operationId) async {
    try {
      final operation = await LocalDB.instance.getOperationById(operationId);
      if (operation != null) {
        final updatedOp = operation.copyWith(
          lastModifiedAt: DateTime.now(),
          // On pourrait ajouter un champ 'synced' si nécessaire
        );
        await LocalDB.instance.updateOperation(updatedOp);
      }
    } catch (e) {
      debugPrint('⚠️ Erreur marquage opération synchronisée: $e');
    }
  }
  
  /// Ajouter une opération à la file d'attente de synchronisation persistante
  Future<void> _addToPendingSyncQueue(OperationModel operation) async {
    try {
      final syncService = SyncService();
      await syncService.queueOperation(operation.toJson());
      debugPrint('📋 Opération ${operation.codeOps} ajoutée à la file de synchronisation persistante');
    } catch (e) {
      debugPrint('❌ Erreur ajout à la file de synchronisation: $e');
    }
  }
  
  /// Démarrer la synchronisation automatique des opérations non synchronisées
  /// Vérifie toutes les 2 minutes et tente de synchroniser
  void startUnsyncedOperationsSync() {
    debugPrint('🔄 Démarrage de la synchronisation automatique des opérations non synchronisées...');
    
    // Annuler le timer existant s'il y en a un
    _unsyncedOpsTimer?.cancel();
    
    // Créer un nouveau timer qui vérifie toutes les 2 minutes (120 secondes)
    _unsyncedOpsTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _syncUnsyncedOperations();
    });
    
    // Première synchronisation immédiate
    _syncUnsyncedOperations();
  }
  
  /// Arrêter la synchronisation automatique
  void stopUnsyncedOperationsSync() {
    debugPrint('🛝️ Arrêt de la synchronisation automatique des opérations');
    _unsyncedOpsTimer?.cancel();
    _unsyncedOpsTimer = null;
  }
  
  /// Synchroniser toutes les opérations non synchronisées
  Future<void> _syncUnsyncedOperations() async {
    try {
      // Récupérer toutes les opérations de la base de données
      final allOps = await LocalDB.instance.getAllOperations();
      
      // Filtrer les opérations non synchronisées
      final unsyncedOps = allOps.where((op) => op.isSynced == false).toList();
      
      _unsyncedOpsCount = unsyncedOps.length;
      
      if (unsyncedOps.isEmpty && _pendingDeletions.isEmpty) {
        debugPrint('✅ [AUTO-SYNC] Aucune opération à synchroniser');
        return;
      }
      
      if (unsyncedOps.isNotEmpty) {
        debugPrint('🔄 [AUTO-SYNC] ${unsyncedOps.length} opérations non synchronisées détectées');
      }
      
      if (_pendingDeletions.isNotEmpty) {
        debugPrint('🔄 [AUTO-SYNC] ${_pendingDeletions.length} suppressions en attente détectées');
      }
      
      int successCount = 0;
      int failCount = 0;
      
      // Tenter de synchroniser chaque opération
      for (var operation in unsyncedOps) {
        try {
          debugPrint('🔄 [AUTO-SYNC] Tentative sync: ${operation.codeOps}');
          
          // Utiliser la méthode de synchronisation en arrière-plan
          await _syncOperationUpdateToServer(operation);
          
          successCount++;
        } catch (e) {
          debugPrint('⚠️ [AUTO-SYNC] Échec sync ${operation.codeOps}: $e');
          failCount++;
        }
      }
      
      // Also retry pending deletions
      await _retryPendingDeletions();
      
      debugPrint('✅ [AUTO-SYNC] Synchronisation terminée: $successCount réussies, $failCount échecs');
      
      // Mettre à jour le compteur
      _unsyncedOpsCount = failCount;
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ [AUTO-SYNC] Erreur lors de la synchronisation: $e');
    }
  }
  
  /// Synchroniser une opération vers le serveur (version await au lieu de void)
  Future<void> _syncOperationUpdateToServer(OperationModel operation) async {
    try {
      final url = '${AppConfig.apiBaseUrl}/sync/operations/update.php';
      
      final jsonBody = jsonEncode(operation.toJson());
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonBody,
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          debugPrint('✅ [AUTO-SYNC] Opération ${operation.codeOps} synchronisée');
          
          // Marquer comme synchronisée dans la base de données locale
          final syncedOp = operation.copyWith(isSynced: true, syncedAt: DateTime.now());
          await LocalDB.instance.updateOperationByCodeOps(syncedOp);
          
          // Mettre à jour en mémoire si l'opération est chargée
          final index = _operations.indexWhere((op) => op.codeOps == operation.codeOps);
          if (index != -1) {
            _operations[index] = syncedOp;
          }
        } else {
          throw Exception(result['message'] ?? 'Erreur serveur inconnue');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      // Re-throw pour que l'appelant puisse compter les échecs
      throw Exception('Sync failed: $e');
    }
  }

  @override
  void dispose() {
    _pendingOpsTimer?.cancel();
    _unsyncedOpsTimer?.cancel();
    super.dispose();
  }

}
