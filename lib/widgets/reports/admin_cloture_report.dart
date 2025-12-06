import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../models/rapport_cloture_model.dart';
import '../../models/shop_model.dart';
import '../../services/rapport_cloture_service.dart';
import '../../services/shop_service.dart';
import '../../services/auth_service.dart';
import '../../services/rapportcloture_pdf_service.dart';

/// Widget pour afficher le Rapport de Clôture Journalière pour les administrateurs
class AdminClotureReport extends StatefulWidget {
  final int? shopId;
  final DateTime? date;
  
  const AdminClotureReport({
    super.key,
    this.shopId,
    this.date,
  });

  @override
  State<AdminClotureReport> createState() => _AdminClotureReportState();
}

class _AdminClotureReportState extends State<AdminClotureReport> {
  DateTime _selectedDate = DateTime.now();
  int? _selectedShopId;
  RapportClotureModel? _rapport;
  bool _isLoading = false;
  String? _errorMessage;
  List<ShopModel> _shops = [];
  bool _isFiltersExpanded = false; // Add this line to control filter visibility

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.date ?? DateTime.now();
    _selectedShopId = widget.shopId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShopsAndGenerateReport();
    });
  }

  Future<void> _loadShopsAndGenerateReport() async {
    await _loadShops();
    if (_selectedShopId == null && _shops.isNotEmpty) {
      setState(() {
        _selectedShopId = _shops.first.id;
      });
    }
    _genererRapport();
  }

  Future<void> _loadShops() async {
    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      await shopService.loadShops();
      setState(() {
        _shops = shopService.shops;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des shops: $e';
      });
    }
  }

  Future<void> _genererRapport() async {
    if (_selectedShopId == null) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      
      final rapport = await RapportClotureService.instance.genererRapport(
        shopId: _selectedShopId!,
        date: _selectedDate,
        generePar: authService.currentUser?.username ?? 'Admin',
      );

      setState(() {
        _rapport = rapport;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _partagerPDF(RapportClotureModel rapport) async {
    try {
      final shop = _shops.firstWhere((s) => s.id == rapport.shopId);
      
      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(rapport, shop);

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
          SnackBar(content: Text('❌ Erreur partage: $e')),
        );
      }
    }
  }

  Future<void> _telechargerPDF(RapportClotureModel rapport) async {
    try {
      final shop = _shops.firstWhere((s) => s.id == rapport.shopId);
      
      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(rapport, shop);

      final pdfBytes = await pdf.save();
      final fileName = 'rapportcloture_${shop.designation}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf';

      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ PDF généré avec succès')),
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

  Future<void> _previsualiserPDF(RapportClotureModel rapport) async {
    try {
      final shop = _shops.firstWhere((s) => s.id == rapport.shopId);
      
      // Générer le PDF
      final pdf = await genererRapportCloturePDF(rapport, shop);

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
                            await _partagerPDF(rapport);
                          },
                        ),
                        PdfPreviewAction(
                          icon: const Icon(Icons.print),
                          onPressed: (context, build, pageFormat) async {
                            Navigator.pop(context);
                            await _imprimerPDF(rapport);
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

  Future<void> _imprimerPDF(RapportClotureModel rapport) async {
    try {
      final shop = _shops.firstWhere((s) => s.id == rapport.shopId);
      
      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(rapport, shop);

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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sélection de date et shop
          _buildFilters(isMobile),
          const SizedBox(height: 24),

          // Contenu du rapport
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            _buildError(_errorMessage!)
          else if (_rapport != null)
            _buildRapport(_rapport!, isMobile)
          else if (_selectedShopId == null)
            _buildNoShopSelected()
          else
            const Center(child: Text('Aucun rapport disponible')),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with toggle button
            Row(
              children: [
                const Icon(Icons.filter_list, color: Color(0xFFDC2626)),
                const SizedBox(width: 12),
                const Text(
                  'Filtres du Rapport',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    _isFiltersExpanded ? Icons.expand_less : Icons.expand_more,
                  ),
                  onPressed: () => setState(() => _isFiltersExpanded = !_isFiltersExpanded),
                  tooltip: _isFiltersExpanded ? 'Masquer les filtres' : 'Afficher les filtres',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Collapsible filters content
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: _isFiltersExpanded
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, color: Color(0xFFDC2626)),
                            const SizedBox(width: 12),
                            const Text(
                              'Date:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
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
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            const Icon(Icons.store, color: Color(0xFFDC2626)),
                            const SizedBox(width: 12),
                            const Text(
                              'Shop:',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<int>(
                                value: _selectedShopId,
                                items: _shops.where((shop) => shop.id != null).map((shop) {
                                  return DropdownMenuItem(
                                    value: shop.id!,
                                    child: Text(shop.designation),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setState(() {
                                    _selectedShopId = value;
                                  });
                                  _genererRapport();
                                },
                                isExpanded: true,
                                hint: const Text('Sélectionner un shop'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),
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

  Widget _buildNoShopSelected() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.store_outlined, size: 64, color: Colors.grey[400]),
              const SizedBox(height: 16),
              const Text(
                'Aucun shop sélectionné',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Veuillez sélectionner un shop pour générer le rapport',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRapport(RapportClotureModel rapport, bool isMobile) {
    return Column(
      children: [
        // En-tête
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.receipt_long, color: Colors.blue[700], size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Rapport de Clôture Journalière',
                        style: TextStyle(
                          fontSize: isMobile ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Shop: ${rapport.shopDesignation}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Date: ${_formatDate(rapport.dateRapport)}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                Text(
                  'Généré par: ${rapport.generePar}',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                // Actions PDF
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _previsualiserPDF(rapport),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('Prévisualiser PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _imprimerPDF(rapport),
                      icon: const Icon(Icons.print, size: 18),
                      label: const Text('Imprimer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _telechargerPDF(rapport),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Télécharger'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        
        // Keep the existing report content
        // Solde antérieur
        _buildSection(
          'Solde Antérieur',
          [
            _buildCashRow('Cash', rapport.soldeAnterieurCash),
            _buildCashRow('Airtel Money', rapport.soldeAnterieurAirtelMoney),
            _buildCashRow('M-Pesa', rapport.soldeAnterieurMPesa),
            _buildCashRow('Orange Money', rapport.soldeAnterieurOrangeMoney),
            const Divider(),
            _buildTotalRow(
              'Total Solde Antérieur',
              rapport.soldeAnterieurCash +
                  rapport.soldeAnterieurAirtelMoney +
                  rapport.soldeAnterieurMPesa +
                  rapport.soldeAnterieurOrangeMoney,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Mouvements de la journée
        _buildSection(
          'Mouvements de la Journée',
          [
            _buildMovementRow('Flots Reçus', rapport.flotRecu, true),
            _buildMovementRow('Flots Envoyés', rapport.flotEnvoye, false),
            _buildMovementRow('Transferts Reçus', rapport.transfertsRecus, true),
            _buildMovementRow('Transferts Servis', rapport.transfertsServis, false),
            _buildMovementRow('Dépôts Clients', rapport.depotsClients, true),
            _buildMovementRow('Retraits Clients', rapport.retraitsClients, false),
          ],
        ),
        const SizedBox(height: 24),

        // Cash disponible
        _buildSection(
          'Cash Disponible',
          [
            _buildCashRow('Cash', rapport.cashDisponibleCash),
            _buildCashRow('Airtel Money', rapport.cashDisponibleAirtelMoney),
            _buildCashRow('M-Pesa', rapport.cashDisponibleMPesa),
            _buildCashRow('Orange Money', rapport.cashDisponibleOrangeMoney),
            const Divider(),
            _buildTotalRow(
              'Total Cash Disponible',
              rapport.cashDisponibleCash +
                  rapport.cashDisponibleAirtelMoney +
                  rapport.cashDisponibleMPesa +
                  rapport.cashDisponibleOrangeMoney,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Capital Net
        _buildSection(
          'Capital Net',
          [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Formule: Cash Disponible + Clients qui Nous qui Doivent + Shops qui Nous qui Doivent - Clients que Nous que Devons - Shops que Nous que Devons',
                    style: TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.grey,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildCashRow('Cash Disponible', rapport.cashDisponibleTotal),
            _buildCashRow('Clients qui Nous qui Doivent', rapport.totalClientsNousDoivent),
            _buildCashRow('Shops qui Nous qui Doivent', rapport.totalShopsNousDoivent),
            _buildCashRow('Clients que Nous que Devons', rapport.totalClientsNousDevons),
            _buildCashRow('Shops que Nous que Devons', rapport.totalShopsNousDevons),
            const Divider(),
            _buildTotalRow(
              'Capital Net',
              rapport.capitalNet,
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Compte FRAIS section
        _buildSection(
          'Compte FRAIS',
          [
            _buildCashRow('Frais Antérieur', rapport.soldeFraisAnterieur),
            _buildCashRow('+ Frais encaissés', rapport.commissionsFraisDuJour),
             const SizedBox(height: 8),
            _buildCashRow('- Sortie Frais du jour', -rapport.retraitsFraisDuJour),
            
            // Détail des frais par shop
            if (rapport.fraisGroupesParShop.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('  Détail par Shop :', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.fraisGroupesParShop.entries.map((entry) => Row(
                children: [
                  const SizedBox(width: 16),
                  Icon(Icons.store, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                  Text(
                    '${entry.value.toStringAsFixed(2)} USD',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.green[700]),
                  ),
                ],
              )).toList(),
            ],
           const Divider(),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '= Solde Frais du jour',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${(rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour).toStringAsFixed(2)} USD',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Clients
        _buildSection(
          'Partenaires',
          [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clients qui Nous qui Doivent (Solde Négatif)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red[700],
                    ),
                  ),
                ),
                Text(
                  '${rapport.clientsNousDoivent.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rapport.clientsNousDoivent.isEmpty)
              const Text('Aucun partenaire débiteur')
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: rapport.clientsNousDoivent.length,
                  itemBuilder: (context, index) {
                    final client = rapport.clientsNousDoivent[index];
                    return ListTile(
                      title: Text(client.nom),
                      subtitle: Text(client.telephone),
                      trailing: Text(
                        '${client.solde.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: Colors.red[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Clients que Nous que Devons (Solde Positif)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ),
                Text(
                  '${rapport.clientsNousDevons.length}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (rapport.clientsNousDevons.isEmpty)
              const Text('Aucun partenaire créditeur')
            else
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: rapport.clientsNousDevons.length,
                  itemBuilder: (context, index) {
                    final client = rapport.clientsNousDevons[index];
                    return ListTile(
                      title: Text(client.nom),
                      subtitle: Text(client.telephone),
                      trailing: Text(
                        '${client.solde.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          color: Colors.green[700],
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildCashRow(String label, double amount) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '${amount.toStringAsFixed(2)} USD',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMovementRow(String label, double amount, bool isPositive) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          '${amount.toStringAsFixed(2)} USD',
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: isPositive ? Colors.green[700] : Colors.red[700],
          ),
        ),
      ],
    );
  }

  Widget _buildTotalRow(String label, double amount) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Text(
          '${amount.toStringAsFixed(2)} USD',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}