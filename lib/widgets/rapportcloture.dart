import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/rapport_cloture_model.dart';
import '../services/rapport_cloture_service.dart';
import '../services/auth_service.dart';
import '../services/rapportcloture_pdf_service.dart';
import '../services/shop_service.dart';
import '../services/operation_service.dart';

/// Widget pour afficher et générer le Rapport de Clôture Journalière
/// Nom du fichier: rapportcloture.dart
class RapportCloture extends StatefulWidget {
  final int? shopId;
  
  const RapportCloture({super.key, this.shopId});

  @override
  State<RapportCloture> createState() => _RapportClotureState();
}

class _RapportClotureState extends State<RapportCloture> {
  DateTime _selectedDate = DateTime.now();
  RapportClotureModel? _rapport;
  bool _isLoading = false;
  bool _journeeCloturee = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
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
      
      // Vérifier si la journée est déjà clôturée
      final estCloturee = await RapportClotureService.instance.journeeEstCloturee(shopId, _selectedDate);
      if (!mounted) return;
      
      // Charger les opérations de "Mes Ops" pour ce shop
      await operationService.loadOperations(shopId: shopId);
      if (!mounted) return;
      
      final rapport = await RapportClotureService.instance.genererRapport(
        shopId: shopId,
        date: _selectedDate,
        generePar: authService.currentUser?.username ?? 'Admin',
        operations: operationService.operations, // Utiliser les données de "Mes Ops"
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
                          icon: const Icon(Icons.download),
                          onPressed: (context, build, pageFormat) async {
                            Navigator.pop(context);
                            await _telechargerPDF();
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
              const SizedBox(height: 12),
              
              // Airtel Money
              TextField(
                controller: airtelController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Airtel Money',
                  prefixIcon: const Icon(Icons.phone_android),
                  border: const OutlineInputBorder(),
                  hintText: 'Montant Airtel',
                  helperText: _rapport != null ? 'Calculé: ${_rapport!.cashDisponibleAirtelMoney.toStringAsFixed(2)}' : null,
                ),
              ),
              const SizedBox(height: 12),
              
              // M-Pesa (Vodacash)
              TextField(
                controller: mpesaController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'M-Pesa (Vodacash)',
                  prefixIcon: const Icon(Icons.phone_android),
                  border: const OutlineInputBorder(),
                  hintText: 'Montant M-Pesa',
                  helperText: _rapport != null ? 'Calculé: ${_rapport!.cashDisponibleMPesa.toStringAsFixed(2)}' : null,
                ),
              ),
              const SizedBox(height: 12),
              
              // Orange Money
              TextField(
                controller: orangeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Orange Money',
                  prefixIcon: const Icon(Icons.phone_android),
                  border: const OutlineInputBorder(),
                  hintText: 'Montant Orange',
                  helperText: _rapport != null ? 'Calculé: ${_rapport!.cashDisponibleOrangeMoney.toStringAsFixed(2)}' : null,
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
            _buildCashBreakdown('Airtel Money', rapport.cashDisponibleAirtelMoney),
            _buildCashBreakdown('M-Pesa', rapport.cashDisponibleMPesa),
            _buildCashBreakdown('Orange Money', rapport.cashDisponibleOrangeMoney),
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
            _buildCashRow('Airtel Money', rapport.soldeAnterieurAirtelMoney),
            _buildCashRow('M-Pesa', rapport.soldeAnterieurMPesa),
            _buildCashRow('Orange Money', rapport.soldeAnterieurOrangeMoney),
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

        // FLOT
        _buildSection(
          '2️⃣ Flots',
          [
            _buildMovementRow('Reçus', rapport.flotRecu, true),
            _buildMovementRow('Envoyés', rapport.flotEnvoye, false),
            
            // Détails des FLOTs reçus
            if (rapport.flotsRecusDetails.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('FLOTs Reçus Détails:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.flotsRecusDetails.map((flot) => _buildFlotDetailRow(
                flot.shopSourceDesignation,
                '${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)} - ${flot.modePaiement}',
                flot.montant,
                Colors.green,
              )).toList(),
            ],
            
            // Détails des FLOTС envoyés
            if (rapport.flotsEnvoyes.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('FLOTs Envoyés Détails:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.flotsEnvoyes.map((flot) => _buildFlotDetailRow(
                flot.shopDestinationDesignation,
                '${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)} - ${flot.modePaiement} (${flot.statut})',
                flot.montant,
                Colors.red,
              )).toList(),
            ],
          ],
          Colors.purple,
        ),
        const SizedBox(height: 16),

        // Transferts
        _buildSection(
          '3️⃣ Transferts',
          [
            _buildMovementRow('Transferts Reçus', rapport.transfertsRecus, true),
            _buildMovementRow('Transferts Servis', rapport.transfertsServis, false),
          ],
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildRightColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        // Partenaires Servis (anciennement Clients Nous Doivent)
        _buildSection(
          '5️⃣ Partenaires Servis',
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

        // Dépôts Partenaires (anciennement Clients Nous Devons)
        _buildSection(
          '6️⃣ Dépôts Partenaires',
          [
            Text('${rapport.clientsNousDevons.length} partenaire(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
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

        // Shops Nous Doivent
        _buildSection(
          '7️⃣ Shops Nous Doivent',
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

        // Shops Nous Devons
        _buildSection(
          '8️⃣ Shops Nous Devons',
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
              'Formule: Cash Disponible + Ceux qui nous doivent - Ceux que nous devons',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
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
            _buildCashRow('+ Partenaires Servis', rapport.totalClientsNousDoivent),
            _buildCashRow('+ Shops Nous Doivent', rapport.totalShopsNousDoivent),
            _buildCashRow('- Dépôts Partenaires', rapport.totalClientsNousDevons),
            _buildCashRow('- Shops Nous Devons', rapport.totalShopsNousDevons),
            const Divider(thickness: 2, color: Colors.blue),
            _buildTotalRow('= CAPITAL NET', rapport.capitalNet, bold: true, color: rapport.capitalNet >= 0 ? Colors.blue : Colors.red),
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
}