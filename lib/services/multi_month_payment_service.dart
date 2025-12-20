import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/multi_month_payment_model.dart';
import '../models/operation_model.dart';
import 'local_db.dart';
import 'operation_service.dart';
import 'auth_service.dart';
import 'shop_service.dart';

/// Service de gestion des paiements multi-mois
/// Permet de créer des paiements couvrant plusieurs mois d'un service
class MultiMonthPaymentService extends ChangeNotifier {
  static final MultiMonthPaymentService _instance = MultiMonthPaymentService._internal();
  static MultiMonthPaymentService get instance => _instance;
  
  MultiMonthPaymentService._internal();

  List<MultiMonthPaymentModel> _payments = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<MultiMonthPaymentModel> get payments => _payments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  /// Charger tous les paiements multi-mois
  Future<void> loadPayments({
    int? shopId,
    DateTime? dateDebut,
    DateTime? dateFin,
    MultiMonthPaymentStatus? statut,
    String? serviceType,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔍 [MultiMonthPaymentService] Chargement paiements multi-mois...');
      
      _payments = await LocalDB.instance.getAllMultiMonthPayments(
        shopId: shopId,
        dateDebut: dateDebut,
        dateFin: dateFin,
        statut: statut,
        serviceType: serviceType,
      );
      
      debugPrint('✅ [MultiMonthPaymentService] ${_payments.length} paiements chargés');
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
    } catch (e, stackTrace) {
      _errorMessage = 'Erreur chargement paiements: $e';
      debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
      debugPrint('📚 Stack trace: $stackTrace');
      _setLoading(false);
      notifyListeners();
      rethrow;
    }
  }

  /// Créer un nouveau paiement multi-mois avec support des bonus et heures supplémentaires
  Future<MultiMonthPaymentModel?> createMultiMonthPayment({
    required String serviceType,
    required String serviceDescription,
    required double montantMensuel,
    required int nombreMois,
    required DateTime dateDebut,
    String devise = 'USD',
    double bonus = 0.0,
    double heuresSupplementaires = 0.0,
    double tauxHoraireSupp = 0.0,
    int? clientId,
    String? clientNom,
    String? clientTelephone,
    String? numeroCompte,
    required int shopId,
    String? destinataire,
    String? telephoneDestinataire,
    String? notes,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🆕 [MultiMonthPaymentService] Création paiement multi-mois...');
      debugPrint('   Service: $serviceType');
      debugPrint('   Montant mensuel: $montantMensuel');
      debugPrint('   Nombre de mois: $nombreMois');
      
      // Générer une référence unique
      final reference = _generateReference(serviceType);
      
      // Vérifier si la référence existe déjà
      if (await _referenceExists(reference)) {
        _errorMessage = 'Cette référence existe déjà';
        debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return null;
      }

      // Calculer le montant total
      final montantTotal = montantMensuel * nombreMois;
      
      // Calculer la date de fin (dernier mois couvert)
      final dateFin = DateTime(dateDebut.year, dateDebut.month + nombreMois - 1, dateDebut.day);
      
      // Générer la liste des mois couverts
      final moisCouverts = _generateMonthlyPeriods(dateDebut, nombreMois, montantMensuel, devise);
      
      // Récupérer les informations de l'agent connecté
      final currentUser = AuthService().currentUser;
      final agentId = currentUser?.id ?? 0;
      final agentUsername = currentUser?.username;
      
      // Récupérer les informations du shop
      String? shopDesignation;
      final shops = ShopService.instance.shops;
      final shop = shops.where((s) => s.id == shopId).firstOrNull;
      shopDesignation = shop?.designation;
      
      final newPayment = MultiMonthPaymentModel(
        reference: reference,
        serviceType: serviceType,
        serviceDescription: serviceDescription,
        montantMensuel: montantMensuel,
        nombreMois: nombreMois,
        montantTotal: montantTotal,
        devise: devise,
        bonus: bonus,
        heuresSupplementaires: heuresSupplementaires,
        tauxHoraireSupp: tauxHoraireSupp,
        dateDebut: dateDebut,
        dateFin: dateFin,
        clientId: clientId,
        clientNom: clientNom,
        clientTelephone: clientTelephone,
        numeroCompte: numeroCompte,
        shopId: shopId,
        shopDesignation: shopDesignation,
        agentId: agentId,
        agentUsername: agentUsername,
        destinataire: destinataire,
        telephoneDestinataire: telephoneDestinataire,
        notes: notes,
        statut: MultiMonthPaymentStatus.enAttente,
        dateCreation: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: agentUsername ?? 'agent_$agentId',
        moisCouverts: moisCouverts,
      );
      
      debugPrint('📦 [MultiMonthPaymentService] Sauvegarde paiement...');
      final savedPayment = await LocalDB.instance.saveMultiMonthPayment(newPayment);
      debugPrint('✅ [MultiMonthPaymentService] Paiement sauvegardé avec ID #${savedPayment.id}');
      
      // Recharger les paiements
      await loadPayments(shopId: shopId);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return savedPayment;
    } catch (e) {
      _errorMessage = 'Erreur création paiement: $e';
      debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Valider un paiement multi-mois (créer l'opération correspondante)
  Future<bool> validateMultiMonthPayment({
    required MultiMonthPaymentModel payment,
    required ModePaiement modePaiement,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('✅ [MultiMonthPaymentService] Validation paiement multi-mois...');
      debugPrint('   ID: ${payment.id}');
      debugPrint('   Référence: ${payment.reference}');
      debugPrint('   Montant total: ${payment.montantTotal}');
      
      if (payment.statut != MultiMonthPaymentStatus.enAttente) {
        _errorMessage = 'Ce paiement a déjà été traité';
        debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }
      
      // PROTECTION: Ne pas permettre de revalider un paiement déjà validé
      if (payment.dateValidation != null) {
        _errorMessage = 'Ce paiement a déjà été validé le ${payment.dateValidation}';
        debugPrint('⚠️ [MultiMonthPaymentService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }
      
      // Créer une opération de paiement correspondante
      final operationCreated = await _createCorrespondingOperation(payment, modePaiement);
      if (!operationCreated) {
        _errorMessage = 'Erreur lors de la création de l\'opération de paiement';
        _setLoading(false);
        notifyListeners();
        return false;
      }

      // Mettre à jour le statut du paiement multi-mois
      final updatedPayment = payment.copyWith(
        statut: MultiMonthPaymentStatus.validee,
        dateValidation: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false, // Marquer comme non synchronisé pour upload vers cloud
      );

      await LocalDB.instance.updateMultiMonthPayment(updatedPayment);
      debugPrint('✅ [MultiMonthPaymentService] Paiement multi-mois validé');
      
      // Recharger les paiements
      await loadPayments(shopId: payment.shopId);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Erreur validation paiement: $e';
      debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Annuler un paiement multi-mois
  Future<bool> cancelMultiMonthPayment({
    required MultiMonthPaymentModel payment,
    String? reason,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('❌ [MultiMonthPaymentService] Annulation paiement multi-mois...');
      debugPrint('   ID: ${payment.id}');
      debugPrint('   Raison: $reason');
      
      if (payment.statut == MultiMonthPaymentStatus.validee) {
        _errorMessage = 'Impossible d\'annuler un paiement déjà validé';
        debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
        _setLoading(false);
        notifyListeners();
        return false;
      }

      final updatedPayment = payment.copyWith(
        statut: MultiMonthPaymentStatus.annulee,
        notes: reason != null ? '${payment.notes ?? ''}\nAnnulé: $reason' : payment.notes,
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: modifiedBy,
        isSynced: false,
      );

      await LocalDB.instance.updateMultiMonthPayment(updatedPayment);
      debugPrint('✅ [MultiMonthPaymentService] Paiement multi-mois annulé');
      
      // Recharger les paiements
      await loadPayments(shopId: payment.shopId);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return true;
    } catch (e) {
      _errorMessage = 'Erreur annulation paiement: $e';
      debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return false;
    }
  }

  /// Générer une référence unique pour le paiement
  String _generateReference(String serviceType) {
    final now = DateTime.now();
    final year = now.year.toString().substring(2);
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');
    final servicePrefix = serviceType.toUpperCase().substring(0, 3);
    
    return 'MP$servicePrefix$year$month$day$hour$minute';
  }

  /// Vérifier si une référence existe déjà
  Future<bool> _referenceExists(String reference) async {
    final existingPayments = await LocalDB.instance.getAllMultiMonthPayments();
    return existingPayments.any((payment) => payment.reference == reference);
  }

  /// Générer la liste des périodes mensuelles couvertes
  List<MonthlyPeriod> _generateMonthlyPeriods(DateTime dateDebut, int nombreMois, double montantMensuel, String devise) {
    final List<MonthlyPeriod> periods = [];
    
    for (int i = 0; i < nombreMois; i++) {
      final currentDate = DateTime(dateDebut.year, dateDebut.month + i, 1);
      periods.add(MonthlyPeriod(
        annee: currentDate.year,
        mois: currentDate.month,
        montant: montantMensuel,
        devise: devise,
      ));
    }
    
    return periods;
  }

  /// Créer une opération de paiement correspondante au paiement multi-mois
  Future<bool> _createCorrespondingOperation(MultiMonthPaymentModel payment, ModePaiement modePaiement) async {
    try {
      // Générer un code d'opération unique
      final codeOps = _generateOperationCode();
      
      // Créer l'opération manuellement selon le modèle OperationModel
      final operation = OperationModel(
        type: OperationType.depot, // Utiliser dépôt comme type de base
        montantBrut: payment.montantTotal,
        commission: 0.0, // Pas de commission pour les paiements de services
        montantNet: payment.montantTotal,
        devise: payment.devise,
        clientId: payment.clientId,
        clientNom: payment.clientNom,
        shopSourceId: payment.shopId,
        shopSourceDesignation: payment.shopDesignation,
        agentId: payment.agentId,
        agentUsername: payment.agentUsername,
        codeOps: codeOps,
        destinataire: payment.destinataire ?? 'Paiement ${payment.serviceType}',
        telephoneDestinataire: payment.telephoneDestinataire,
        reference: payment.reference,
        modePaiement: modePaiement,
        statut: OperationStatus.terminee,
        notes: 'Paiement multi-mois: ${payment.serviceDescription} (${payment.nombreMois} mois)',
        dateOp: DateTime.now(),
        createdAt: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: payment.agentUsername ?? 'agent_${payment.agentId}',
      );
      
      // Utiliser le montant final avec ajustements pour l'opération
      final operationWithFinalAmount = operation.copyWith(
        montantBrut: payment.montantFinalCalcule,
        montantNet: payment.montantFinalCalcule,
        notes: '${operation.notes}\n${payment.hasAdjustments ? "Ajustements: ${payment.adjustmentsDetails}" : ""}',
      );
      
      // Créer l'opération via OperationService avec AuthService
      final createdOperation = await OperationService().createOperation(
        operationWithFinalAmount,
        authService: AuthService(),
      );
      
      return createdOperation != null;
    } catch (e) {
      debugPrint('❌ Erreur création opération correspondante: $e');
      return false;
    }
  }

  /// Générer un code d'opération unique
  String _generateOperationCode() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString();
    return 'MP${timestamp.substring(timestamp.length - 8)}';
  }

  /// Obtenir les statistiques des paiements multi-mois
  Map<String, dynamic> getPaymentStats() {
    final totalPayments = _payments.length;
    final validatedPayments = _payments.where((p) => p.statut == MultiMonthPaymentStatus.validee).length;
    final pendingPayments = _payments.where((p) => p.statut == MultiMonthPaymentStatus.enAttente).length;
    final cancelledPayments = _payments.where((p) => p.statut == MultiMonthPaymentStatus.annulee).length;
    
    final totalAmount = _payments
        .where((p) => p.statut == MultiMonthPaymentStatus.validee)
        .fold(0.0, (sum, p) => sum + p.montantTotal);
    
    final pendingAmount = _payments
        .where((p) => p.statut == MultiMonthPaymentStatus.enAttente)
        .fold(0.0, (sum, p) => sum + p.montantTotal);

    return {
      'totalPayments': totalPayments,
      'validatedPayments': validatedPayments,
      'pendingPayments': pendingPayments,
      'cancelledPayments': cancelledPayments,
      'totalAmount': totalAmount,
      'pendingAmount': pendingAmount,
    };
  }

  /// Recalculer un paiement avec de nouveaux bonus/heures supplémentaires
  Future<MultiMonthPaymentModel?> recalculatePaymentAmounts({
    required MultiMonthPaymentModel payment,
    double? newBonus,
    double? newHeuresSupplementaires,
    double? newTauxHoraireSupp,
    String? modifiedBy,
  }) async {
    _setLoading(true);
    try {
      debugPrint('🔄 [MultiMonthPaymentService] Recalcul paiement...');
      debugPrint('   ID: ${payment.id}');
      debugPrint('   Référence: ${payment.reference}');
      debugPrint('   Ancien bonus: ${payment.bonus}');
      debugPrint('   Nouveau bonus: ${newBonus ?? payment.bonus}');
      debugPrint('   Anciennes heures supp: ${payment.heuresSupplementaires}');
      debugPrint('   Nouvelles heures supp: ${newHeuresSupplementaires ?? payment.heuresSupplementaires}');
      debugPrint('   Ancien taux horaire: ${payment.tauxHoraireSupp}');
      debugPrint('   Nouveau taux horaire: ${newTauxHoraireSupp ?? payment.tauxHoraireSupp}');
      
      // Utiliser la méthode statique de recalcul du modèle
      final recalculatedPayment = MultiMonthPaymentModel.recalculateAmounts(
        payment: payment,
        newBonus: newBonus,
        newHeuresSupplementaires: newHeuresSupplementaires,
        newTauxHoraireSupp: newTauxHoraireSupp,
      ).copyWith(
        lastModifiedBy: modifiedBy,
        isSynced: false, // Marquer comme non synchronisé
      );
      
      debugPrint('   Montant de base: ${recalculatedPayment.montantTotal}');
      debugPrint('   Bonus final: ${recalculatedPayment.bonus}');
      debugPrint('   Heures supp finales: ${recalculatedPayment.heuresSupplementaires}');
      debugPrint('   Montant heures supp: ${recalculatedPayment.montantHeuresSupplementairesCalcule}');
      debugPrint('   Montant final total: ${recalculatedPayment.montantFinalCalcule}');
      
      // Sauvegarder le paiement recalculé
      await LocalDB.instance.updateMultiMonthPayment(recalculatedPayment);
      debugPrint('✅ [MultiMonthPaymentService] Paiement recalculé et sauvegardé');
      
      // Recharger les paiements
      await loadPayments(shopId: payment.shopId);
      
      _errorMessage = null;
      _setLoading(false);
      notifyListeners();
      
      return recalculatedPayment;
    } catch (e) {
      _errorMessage = 'Erreur recalcul paiement: $e';
      debugPrint('❌ [MultiMonthPaymentService] $_errorMessage');
      _setLoading(false);
      notifyListeners();
      return null;
    }
  }

  /// Obtenir les paiements par type de service
  Map<String, List<MultiMonthPaymentModel>> getPaymentsByServiceType() {
    final Map<String, List<MultiMonthPaymentModel>> paymentsByType = {};
    
    for (final payment in _payments) {
      if (!paymentsByType.containsKey(payment.serviceType)) {
        paymentsByType[payment.serviceType] = [];
      }
      paymentsByType[payment.serviceType]!.add(payment);
    }
    
    return paymentsByType;
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
