import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/rapport_cloture_model.dart';
import '../models/operation_model.dart';
import '../services/rapport_cloture_service.dart';
import '../services/auth_service.dart';
import '../services/rapportcloture_pdf_service.dart';
import '../services/shop_service.dart';
import '../services/operation_service.dart';
import '../services/transfer_sync_service.dart';

/// Widget pour afficher et générer le Rapport de Clôture Journalière
/// Nom du fichier: rapportcloture.dart
class RapportCloture extends StatefulWidget {
  final int? shopId;
  final bool isAdminView; // Si true, masque le bouton de clôture (admin ne peut pas clôturer)
  final DateTime? dateInitiale; // Date initiale à afficher (pour forcer une clôture)
  
  const RapportCloture({
    super.key,
    this.shopId,
    this.isAdminView = false,
    this.dateInitiale,
  });

  @override
  State<RapportCloture> createState() => _RapportClotureState();
}

class _RapportClotureState extends State<RapportCloture> {
  late DateTime _selectedDate;
  RapportClotureModel? _rapport;
  bool _isLoading = false;
  bool _journeeCloturee = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Utiliser la date initiale si fournie, sinon utiliser aujourd'hui
    _selectedDate = widget.dateInitiale ?? DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _genererRapport();
    });
  }

  Future<void> _genererRapport() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = Provider.of<OperationService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      // 1️⃣ D'ABORD: Synchroniser depuis l'API pour obtenir toutes les opérations fraîches
      if (!mounted) return;
      
      final transferSync = Provider.of<TransferSyncService>(context, listen: false);
      debugPrint('🔄 [RAPPORT CLÔTURE] Synchronisation des opérations depuis l\'API...');
      await transferSync.forceRefreshFromAPI();
      debugPrint('✅ [RAPPORT CLÔTURE] Synchronisation terminée');
      
      // 2️⃣ Vérifier si la journée est déjà clôturée
      final estCloturee = await RapportClotureService.instance.journeeEstCloturee(shopId, _selectedDate);
      if (!mounted) return;
      
      // 3️⃣ Charger les opérations de "Mes Ops" pour ce shop (IMPORTANT: pour agent ET admin)
      await operationService.loadOperations(shopId: shopId);
      if (!mounted) return;
      
      // 4️⃣ Générer le rapport avec les opérations chargées
      final rapport = await RapportClotureService.instance.genererRapport(
        shopId: shopId,
        date: _selectedDate,
        generePar: authService.currentUser?.username ?? 'Admin',
        operations: operationService.operations, // Utiliser les données de "Mes Ops" (pour agent ET admin)
      );
      if (!mounted) return;

      setState(() {
        _rapport = rapport;
        _journeeCloturee = estCloturee;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _partagerPDF() async {
    if (_rapport == null) return;

    try {
      // Obtenir le shop actuel
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      final shop = shopService.getShopById(shopId);
      
      if (shop == null) {
        throw Exception('Shop non trouvé');
      }

      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(_rapport!, shop);

      // Sauvegarder ou partager le PDF
      final pdfBytes = await pdf.save();
      final fileName = 'rapportcloture_${shop.designation}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf';
      
      // Utiliser Printing.sharePdf qui fonctionne sur toutes les plateformes
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF partagé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur partage PDF: $e')),
        );
      }
    }
  }

  Future<void> _telechargerPDF() async {
    if (_rapport == null) return;

    try {
      // Obtenir le shop actuel
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      final shop = shopService.getShopById(shopId);
      
      if (shop == null) {
        throw Exception('Shop non trouvé');
      }

      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(_rapport!, shop);

      // Sauvegarder ou partager le PDF
      final pdfBytes = await pdf.save();
      final fileName = 'rapportcloture_${shop.designation}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf';

      // Utiliser Printing pour sauvegarder ou partager
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF généré avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur PDF: $e')),
        );
      }
    }
  }

  Future<void> _previsualiserPDF() async {
    if (_rapport == null) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      final shop = shopService.getShopById(shopId);
      
      if (shop == null) {
        throw Exception('Shop non trouvé');
      }

      // Générer le PDF
      final pdf = await genererRapportCloturePDF(_rapport!, shop);

      final pdfBytes = await pdf.save();

      // Afficher le PDF dans une boîte de dialogue de prévisualisation
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  // En-tête
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFFDC2626),
                    child: Row(
                      children: [
                        const Text(
                          'Prévisualisation PDF',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Viewer PDF
                  Expanded(
                    child: PdfPreview(
                      build: (format) => pdfBytes,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      actions: [
                        PdfPreviewAction(
                          icon: const Icon(Icons.share),
                          onPressed: (context, build, pageFormat) async {
                            Navigator.pop(context);
                            await _partagerPDF();
                          },
                        ),
                        PdfPreviewAction(
                          icon: const Icon(Icons.print),
                          onPressed: (context, build, pageFormat) async {
                            Navigator.pop(context);
                            await _imprimerPDF();
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  Future<void> _imprimerPDF() async {
    if (_rapport == null) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      final shop = shopService.getShopById(shopId);
      
      if (shop == null) {
        throw Exception('Shop non trouvé');
      }

      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(_rapport!, shop);

      // Imprimer directement
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'rapportcloture_${shop.designation}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  /// Clôturer la journée - enregistre le solde actuel comme solde de clôture
  Future<void> _cloturerJournee() async {
    if (!mounted) return;
    
    // Contrôleurs pour la saisie des montants
    final cashController = TextEditingController(text: _rapport?.cashDisponibleCash.toStringAsFixed(2) ?? '0.00');
    final airtelController = TextEditingController(text: _rapport?.cashDisponibleAirtelMoney.toStringAsFixed(2) ?? '0.00');
    final mpesaController = TextEditingController(text: _rapport?.cashDisponibleMPesa.toStringAsFixed(2) ?? '0.00');
    final orangeController = TextEditingController(text: _rapport?.cashDisponibleOrangeMoney.toStringAsFixed(2) ?? '0.00');
    
    // Afficher le dialogue de saisie
    final confirm = await showDialog<Map<String, double>?>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('🔒 Clôturer la journée'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Clôture pour le ${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}'),
              const SizedBox(height: 16),
              const Text(
                'Saisissez les montants comptés physiquement:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              
              // USD (Cash)
              TextField(
                controller: cashController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'USD (Espèces)',
                  prefixIcon: const Icon(Icons.attach_money),
                  border: const OutlineInputBorder(),
                  hintText: 'Montant en USD',
                  helperText: _rapport != null ? 'Calculé: ${_rapport!.cashDisponibleCash.toStringAsFixed(2)}' : null,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              final cash = double.tryParse(cashController.text) ?? 0.0;
              final airtel = double.tryParse(airtelController.text) ?? 0.0;
              final mpesa = double.tryParse(mpesaController.text) ?? 0.0;
              final orange = double.tryParse(orangeController.text) ?? 0.0;
              
              Navigator.pop(context, {
                'cash': cash,
                'airtel': airtel,
                'mpesa': mpesa,
                'orange': orange,
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
            ),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (confirm == null || !mounted) return;

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      await RapportClotureService.instance.cloturerJournee(
        shopId: shopId,
        dateCloture: _selectedDate,
        cloturePar: authService.currentUser?.username ?? 'Admin',
        soldeSaisiCash: confirm['cash']!,
        soldeSaisiAirtelMoney: confirm['airtel']!,
        soldeSaisiMPesa: confirm['mpesa']!,
        soldeSaisiOrangeMoney: confirm['orange']!,
      );
      if (!mounted) return;

      setState(() {
        _journeeCloturee = true;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Journée clôturée avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Erreur: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      cashController.dispose();
      airtelController.dispose();
      mpesaController.dispose();
      orangeController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Rapport de Clôture Journalière'),
        backgroundColor: const Color(0xFFDC2626),
        actions: [
          if (_rapport != null) ...[
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Prévisualiser PDF',
              onPressed: _previsualiserPDF,
            ),
            IconButton(
              icon: const Icon(Icons.print),
              tooltip: 'Imprimer',
              onPressed: _imprimerPDF,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Télécharger PDF',
              onPressed: _telechargerPDF,
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sélection de date
            _buildDateSelector(isMobile),
            const SizedBox(height: 24),

            // Contenu du rapport
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              _buildError(_errorMessage!)
            else if (_rapport != null)
              _buildRapport(_rapport!, isMobile)
            else
              const Center(child: Text('Aucun rapport disponible')),
          ],
        ),
      ),
    );
  }

  Widget _buildDateSelector(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.calendar_today, color: Color(0xFFDC2626)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                      _genererRapport();
                    }
                  },
                  icon: const Icon(Icons.edit_calendar),
                  label: const Text('Changer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                  ),
                ),
              ],
            ),
            
            // Bouton de clôture
            if (_rapport != null) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              if (_journeeCloturee)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Journée déjà clôturée',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              else
                // Bouton "Clôturer la journée" (MASQUÉ pour l'admin)
                if (!widget.isAdminView)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _cloturerJournee,
                      icon: const Icon(Icons.lock),
                      label: const Text('Clôturer la journée'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }

  Widget _buildRapport(RapportClotureModel rapport, bool isMobile) {
    return Column(
      children: [
        // En-tête
        _buildSection(
          'Shop: ${rapport.shopDesignation}',
          [
            Text(
              'Rapport du ${rapport.dateRapport.day}/${rapport.dateRapport.month}/${rapport.dateRapport.year}',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
          Colors.blue,
        ),
        const SizedBox(height: 16),

        // Cash Disponible (TOTAL)
        _buildCashDisponibleCard(rapport),
        const SizedBox(height: 16),

        // Détails par section
        if (!isMobile)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildLeftColumn(rapport)),
              const SizedBox(width: 16),
              Expanded(child: _buildRightColumn(rapport)),
            ],
          )
        else
          Column(
            children: [
              _buildLeftColumn(rapport),
              const SizedBox(height: 16),
              _buildRightColumn(rapport),
            ],
          ),
        
        const SizedBox(height: 24),
        
        // Capital Net Final
        _buildCapitalNetCard(rapport),
      ],
    );
  }

  Widget _buildCashDisponibleCard(RapportClotureModel rapport) {
    return Card(
      elevation: 4,
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '💰 CASH DISPONIBLE TOTAL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '${rapport.cashDisponibleTotal.toStringAsFixed(2)} USD',
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            _buildCashBreakdown('Cash', rapport.cashDisponibleCash),
          ],
        ),
      ),
    );
  }

  Widget _buildCashBreakdown(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        // Solde Antérieur
        _buildSection(
          '1️⃣ Solde Antérieur',
          [
            _buildCashRow('Cash', rapport.soldeAnterieurCash),
            const Divider(),
            _buildTotalRow(
              'TOTAL',
              rapport.soldeAnterieurCash +
                  rapport.soldeAnterieurAirtelMoney +
                  rapport.soldeAnterieurMPesa +
                  rapport.soldeAnterieurOrangeMoney,
            ),
          ],
          Colors.grey,
        ),
        const SizedBox(height: 16),

        // FLOT - COMBINED SECTION
        _buildSection(
          '2️⃣ Flots',
          [
            _buildMovementRow('FLOTs Reçus', rapport.flotRecu, true),
            _buildMovementRow('FLOTs Envoyés', rapport.flotEnvoye, false),
            const SizedBox(height: 8),
            _buildTotalRow(
              '= TOTAL FLOTs',
              rapport.flotRecu + rapport.flotsEnAttente - rapport.flotEnvoye,
              bold: true,
              color: Colors.purple,
            ),
            
            // Détails des FLOTs reçus GROUPÉS PAR SHOP EXPÉDITEUR
            if (rapport.flotsRecusGroupes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('FLOTs Reçus Détails:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.flotsRecusGroupes.entries.map((entry) => _buildFlotDetailRow(
                entry.key, // Nom du shop expéditeur
                '',
                entry.value, // Somme des montants
                Colors.green,
              )).toList(),
            ],
            
            // Détails des FLOTs envoyés GROUPÉS PAR SHOP DESTINATION
            if (rapport.flotsEnvoyesGroupes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('FLOTs Envoyés Détails:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.flotsEnvoyesGroupes.entries.map((entry) => _buildFlotDetailRow(
                entry.key, // Nom du shop destination
                '',
                entry.value, // Somme des montants
                Colors.red,
              )).toList(),
            ],
          ],
          Colors.purple,
        ),
        const SizedBox(height: 16),

        // Transferts
        _buildSection(
          '4️⃣ Transferts',
          [
            _buildMovementRow('Transferts', rapport.transfertsRecus, true),
            _buildMovementRow('Servis', rapport.transfertsServis, false),
            _buildMovementRow('Non Servis', rapport.transfertsEnAttente, false),
            
            // Détails des TRANSFERTS REÇUS GROUPÉS PAR SHOP DESTINATION
            if (rapport.transfertsRecusGroupes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Transferts Reçus :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.transfertsRecusGroupes.entries.map((entry) => _buildFlotDetailRow(
                entry.key, // Nom du shop destination
                'Total du jour',
                entry.value, // Somme des montants
                Colors.green,
              )).toList(),
            ],
            
            // Détails des TRANSFERTS SERVIS GROUPÉS PAR SHOP SOURCE
            if (rapport.transfertsServisGroupes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Transferts Servis Détails :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.transfertsServisGroupes.entries.map((entry) => _buildFlotDetailRow(
                entry.key, // Nom du shop source
                'Total du jour',
                entry.value, // Somme des montants
                Colors.red,
              )).toList(),
            ],
            
           
            // DÉTAILS DES TRANSFERTS EN ATTENTE GROUPÉS PAR SHOP SOURCE
            if (rapport.transfertsEnAttenteGroupes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Non Servis:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.transfertsEnAttenteGroupes.entries.map((entry) => _buildFlotDetailRow(
                entry.key, // Nom du shop source
                'Total du jour',
                entry.value, // Somme des montants
                Colors.orange,
              )).toList(),
            ],
          ],
          Colors.blue,
        ),        const SizedBox(height: 16),

        // NOUVEAU: Comptes Spéciaux (FRAIS uniquement)
        _buildSection(
          '5️⃣ Compte FRAIS',
          [
            _buildCashRow('Frais Antérieur', rapport.soldeFraisAnterieur),
            _buildCashRow('+ Frais encaissés', rapport.commissionsFraisDuJour),
            const SizedBox(height: 8),
            _buildCashRow('- Sortie Frais du jour', -rapport.retraitsFraisDuJour),  // Négatif car c'est une sortie
            
            // Détail des frais par shop
            if (rapport.fraisGroupesParShop.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('  Détail par Shop :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.fraisGroupesParShop.entries.map((entry) => _buildFlotDetailRow(
                entry.key, // Nom du shop source
                'Frais',
                entry.value, // Montant des frais
                Colors.green,
              )).toList(),
            ],
            const Divider(),
            _buildTotalRow('= Solde Frais du jour', rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour, color: Colors.green, bold: true),
          ],
          Colors.green,
        ),

      ],
    );
  }

  Widget _buildRightColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        // Partenaires Servis (anciennement Clients Nous qui Doivent)
        _buildSection(
          '6️⃣ Partenaires Servis',
          [
            Text('${rapport.clientsNousDoivent.length} partenaire(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            // Show detailed client list like UI
            ...rapport.clientsNousDoivent.map((client) => _buildClientRow(
              client.nom,
              client.solde,
              Colors.red,
            )).toList(),
            const Divider(),
            _buildTotalRow('TOTAL', rapport.totalClientsNousDoivent, color: Colors.red),
          ],
          Colors.red,
        ),
        const SizedBox(height: 16),

        // Dépôts Partenaires (anciennement Clients Nous que Devons)
        _buildSection(
          '7️⃣ Dépôts Partenaires',
          [
           // Show detailed client list like UI
            ...rapport.clientsNousDevons.map((client) => _buildClientRow(
              client.nom,
              client.solde,
              Colors.green,
            )).toList(),
            const Divider(),
            _buildTotalRow('TOTAL', rapport.totalClientsNousDevons, color: Colors.green),
          ],
          Colors.green,
        ),
        const SizedBox(height: 16),

        // Shops Qui Nous qui Doivent
        _buildSection(
          '8️⃣ Shops Qui Nous Doivent (DIFF. DETTES)',
          [
            Text('${rapport.shopsNousDoivent.length} shop(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            // Show detailed shop list like UI
            ...rapport.shopsNousDoivent.map((shop) => _buildShopRow(
              '${shop.designation} (${shop.localisation})',
              shop.montant,
              Colors.orange,
            )).toList(),
            const Divider(),
            _buildTotalRow('TOTAL', rapport.totalShopsNousDoivent, color: Colors.orange),
          ],
          Colors.orange,
        ),
        const SizedBox(height: 16),

        // Shops Nous que Devons
        _buildSection(
          '9️⃣ Shop Que Nous que Devons',
          [
            Text('${rapport.shopsNousDevons.length} shop(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            // Show detailed shop list like UI
            ...rapport.shopsNousDevons.map((shop) => _buildShopRow(
              '${shop.designation} (${shop.localisation})',
              shop.montant,
              Colors.purple,
            )).toList(),
            const Divider(),
            _buildTotalRow('TOTAL', rapport.totalShopsNousDevons, color: Colors.purple),
          ],
          Colors.purple,
        ),
        const SizedBox(height: 16),

        // NOUVEAU: Section SOLDE PAR PARTENAIRE
        _buildSection(
          '🔟 SOLDE PAR PARTENAIRE',
          [
            if (rapport.soldeParPartenaire.isEmpty)
              const Text(
                'Aucune opération partenaire trouvée',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              )
            else ...[
              // CRÉANCES (Soldes positifs - Clients qui nous doivent)
              (() {
                final creances = rapport.soldeParPartenaire.entries
                    .where((entry) => entry.value > 0)
                    .toList();
                
                if (creances.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_wallet, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'CRÉANCES (${creances.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${creances.fold(0.0, (sum, entry) => sum + entry.value).toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...creances.map((entry) => _buildClientRowWithSign(
                      entry.key,
                      entry.value,
                      Colors.red,
                    )).toList(),
                  ],
                );
              }()),
              
              const SizedBox(height: 16),
              
              // DETTES (Soldes négatifs - Clients à qui nous devons)
              (() {
                final dettes = rapport.soldeParPartenaire.entries
                    .where((entry) => entry.value < 0)
                    .toList();
                
                if (dettes.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.money_off, color: Colors.green, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'DETTES (${dettes.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${dettes.fold(0.0, (sum, entry) => sum + entry.value.abs()).toStringAsFixed(2)} USD',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...dettes.map((entry) => _buildClientRowWithSign(
                      entry.key,
                      entry.value,
                      Colors.green,
                    )).toList(),
                  ],
                );
              }()),
              
              // Soldes neutres (exactement 0)
              (() {
                final neutres = rapport.soldeParPartenaire.entries
                    .where((entry) => entry.value == 0)
                    .toList();
                
                if (neutres.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.balance, color: Colors.grey, size: 16),
                          const SizedBox(width: 8),
                          Text(
                            'SOLDES NEUTRES (${neutres.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...neutres.map((entry) => _buildClientRowWithSign(
                      entry.key,
                      entry.value,
                      Colors.grey,
                    )).toList(),
                  ],
                );
              }()),
              
              // Total net de la section
              if (rapport.soldeParPartenaire.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(thickness: 2),
                (() {
                  final totalSolde = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                  final color = totalSolde > 0 ? Colors.red : totalSolde < 0 ? Colors.green : Colors.grey;
                  final totalCreances = rapport.soldeParPartenaire.values.where((v) => v > 0).fold(0.0, (sum, v) => sum + v);
                  final totalDettes = rapport.soldeParPartenaire.values.where((v) => v < 0).fold(0.0, (sum, v) => sum + v.abs());
                  
                  return Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Créances:', style: TextStyle(fontSize: 12, color: Colors.red)),
                          Text('${totalCreances.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Dettes:', style: TextStyle(fontSize: 12, color: Colors.green)),
                          Text('${totalDettes.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w500)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildTotalRow('SOLDE NET PARTENAIRES', totalSolde, color: color, bold: true),
                    ],
                  );
                }()),
              ],
            ],
          ],
          Colors.blue,
        ),
        const SizedBox(height: 16),

        // NOUVEAU: Règlements Triangulaires de Dettes
        if (rapport.triangularSettlements.isNotEmpty)
          _buildSection(
            '🔺 REGULARISATION',
            [
              DataTable(
                columnSpacing: 8,
                horizontalMargin: 8,
                columns: const [
                  DataColumn(label: Text('Réf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Montant', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Rôle', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                  DataColumn(label: Text('Impact', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                ],
                rows: rapport.triangularSettlements.map((settlement) {
                  // Déterminer l'icône et la couleur selon le rôle
                  IconData roleIcon;
                  Color roleColor;
                  String roleText;
                  
                  switch (settlement.roleDuShopCourant) {
                    case 'debtor':
                      roleIcon = Icons.arrow_downward;
                      roleColor = Colors.green;
                      roleText = 'Débiteur';
                      break;
                    case 'intermediary':
                      roleIcon = Icons.swap_horiz;
                      roleColor = Colors.orange;
                      roleText = 'Intermédiaire';
                      break;
                    case 'creditor':
                      roleIcon = Icons.account_balance;
                      roleColor = Colors.blue;
                      roleText = 'Créancier';
                      break;
                    default:
                      roleIcon = Icons.help;
                      roleColor = Colors.grey;
                      roleText = 'Inconnu';
                  }
                  
                  // Déterminer l'icône et la couleur selon l'impact
                  IconData impactIcon;
                  Color impactColor;
                  String impactText;
                  
                  switch (settlement.impactSurDette) {
                    case 'diminue':
                      impactIcon = Icons.arrow_downward;
                      impactColor = Colors.green;
                      impactText = 'Dette diminue';
                      break;
                    case 'augmente':
                      impactIcon = Icons.arrow_upward;
                      impactColor = Colors.red;
                      impactText = 'Dette augmente';
                      break;
                    case 'aucun':
                      impactIcon = Icons.remove;
                      impactColor = Colors.grey;
                      impactText = 'Pas d\'impact';
                      break;
                    default:
                      impactIcon = Icons.help;
                      impactColor = Colors.grey;
                      impactText = 'Inconnu';
                  }
                  
                  return DataRow(
                    cells: [
                      DataCell(
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(settlement.reference, style: const TextStyle(fontSize: 11)),
                            Text(
                              '${settlement.shopDebtorDesignation} → ${settlement.shopCreditorDesignation}',
                              style: const TextStyle(fontSize: 9, color: Colors.grey),
                            ),
                            if (settlement.notes != null && settlement.notes!.isNotEmpty)
                              Text(
                                '${settlement.notes}',
                                style: const TextStyle(fontSize: 9, fontStyle: FontStyle.italic, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),
                      DataCell(
                        Text('${NumberFormat('#,##0.00').format(settlement.montant)} ${settlement.devise}'),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Icon(roleIcon, size: 16, color: roleColor),
                            const SizedBox(width: 4),
                            Text(roleText, style: TextStyle(color: roleColor, fontSize: 11)),
                          ],
                        ),
                      ),
                      DataCell(
                        Row(
                          children: [
                            Icon(impactIcon, size: 16, color: impactColor),
                            const SizedBox(width: 4),
                            Text(impactText, style: TextStyle(color: impactColor, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ],
            Colors.blue,
          ),
        
        const SizedBox(height: 16),

        if (rapport.autresShopServis > 0 || rapport.autresShopDepots > 0)
          _buildSection(
            '1️⃣1️⃣ AUTRES SHOP',
            [
              // SERVIS - Retraits où nous sommes destinataires
              if (rapport.autresShopServis > 0) ...[
                const Divider(),
                _buildCashRow('SERVIS ', rapport.autresShopServis),
                
                // Détails SERVIS groupés par client
                if (rapport.autresShopServisGroupes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('  Détail SERVIS par Client :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const Divider(),
                  ...rapport.autresShopServisGroupes.entries.map((entry) => _buildFlotDetailRow(
                    entry.key, // Nom du client (via shop)
                    'Retrait servi',
                    entry.value, // Montant servi
                    Colors.orange,
                  )).toList(),
                ],
                const SizedBox(height: 8),
              ],
              
              // DEPOT - Dépôts où nous sommes destinataires
              if (rapport.autresShopDepots > 0) ...[
                const Divider(),
                _buildCashRow('DEPOT', rapport.autresShopDepots),
                
                // Détails DEPOT groupés par client
                if (rapport.autresShopDepotsGroupes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('  Détail DEPOT par Client :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const Divider(),
                  ...rapport.autresShopDepotsGroupes.entries.map((entry) => _buildFlotDetailRow(
                    entry.key, // Nom du client (via shop)
                    'Dépôt reçu',
                    entry.value, // Montant reçu
                    Colors.green,
                  )).toList(),
                ],
              ],
              
              const Divider(),
              _buildTotalRow('TOTAL', rapport.autresShopServis + rapport.autresShopDepots, color: Colors.blue, bold: true),
            ],
            Colors.blue,
          ),
      ],
    );
  }

  Widget _buildCapitalNetCard(RapportClotureModel rapport) {
    return Card(
      elevation: 4,
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              '📈 CAPITAL NET FINAL',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Formule: Cash Disponible (incluant -Retraits FRAIS) + Créances - Dettes',
              style: TextStyle(fontSize: 10, fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              '${rapport.capitalNet.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: rapport.capitalNet >= 0 ? Colors.blue : Colors.red,
              ),
            ),
                        const Divider(color: Colors.blue),
            const SizedBox(height: 8),
            _buildCashRow('Cash Disponible', rapport.cashDisponibleTotal),
            _buildCashRow('+ DIFF. DETTES', rapport.totalShopsNousDoivent),
            _buildCashRow('- Shops Que Nous que Devons', rapport.totalShopsNousDevons),
            _buildCashRow('- Solde Frais du jour', rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour),
            _buildCashRow('- Non Servis', rapport.transfertsEnAttente),
            (() {
              final totalSoldePartenaire = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
              return _buildCashRow('+ Solde Net Partenaires', totalSoldePartenaire);
            }()),
            const Divider(thickness: 2, color: Colors.blue),
            _buildTotalRow('= CAPITAL NET', 
              (() {
                final totalSoldePartenaire = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                // EXCLUSION: Depots Partenaires et Partenaires Servis ne sont plus inclus dans le calcul du capital NET
                return rapport.cashDisponibleTotal + 
                       rapport.totalShopsNousDoivent - 
                       rapport.totalShopsNousDevons - 
                       (rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour) - 
                       rapport.transfertsEnAttente +
                       totalSoldePartenaire;
              }()), 
              bold: true, 
              color: (() {
                final totalSoldePartenaire = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                // EXCLUSION: Depots Partenaires et Partenaires Servis ne sont plus inclus dans le calcul du capital NET
                final capitalNet = rapport.cashDisponibleTotal + 
                                   rapport.totalShopsNousDoivent - 
                                   rapport.totalShopsNousDevons - 
                                   (rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour) - 
                                   rapport.transfertsEnAttente +
                                   totalSoldePartenaire;
                return capitalNet >= 0 ? Colors.blue : Colors.red;
              }())),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCashRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildMovementRow(String label, double amount, bool isPositive) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '${isPositive ? '+' : '-'}${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 14,
              color: isPositive ? Colors.green : Colors.red,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(String label, double amount, {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
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

  Widget _buildClientRow(String name, double balance, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${balance.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopRow(String name, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlotDetailRow(String shopName, String details, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransfertDetailRow(String shopName, String details, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shopName,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  details,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransfertRouteRow(TransfertRouteResume route) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${route.shopSourceDesignation} → ${route.shopDestinationDesignation}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Transferts: ${route.transfertsCount}', style: const TextStyle(fontSize: 10, color: Colors.blue)),
              Text('${route.transfertsTotal.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 10, color: Colors.blue)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Servis: ${route.servisCount}', style: const TextStyle(fontSize: 10, color: Colors.green)),
              Text('${route.servisTotal.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 10, color: Colors.green)),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('En attente: ${route.enAttenteCount}', style: const TextStyle(fontSize: 10, color: Colors.orange)),
              Text('${route.enAttenteTotal.toStringAsFixed(2)} USD', style: const TextStyle(fontSize: 10, color: Colors.orange)),
            ],
          ),
          const Divider(height: 8, thickness: 1),
        ],
      ),
    );
  }

  Widget _buildOperationDetailRow(String observation, String details, double amount, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation,
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  details,
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClientRowWithSign(String name, double balance, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${balance < 0 ? "-" : ""}${balance.abs().toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}