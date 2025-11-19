import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/flot_model.dart' as flot_model;
import '../../models/shop_model.dart';
import '../../services/flot_service.dart';
import '../../services/shop_service.dart';
import '../../services/reports_pdf_service.dart';

/// Widget pour afficher les rapports FLOT pour les administrateurs
class AdminFlotReport extends StatefulWidget {
  final int? shopId;
  final DateTime? startDate;
  final DateTime? endDate;
  
  const AdminFlotReport({
    super.key,
    this.shopId,
    this.startDate,
    this.endDate,
  });

  @override
  State<AdminFlotReport> createState() => _AdminFlotReportState();
}

class _AdminFlotReportState extends State<AdminFlotReport> {
  DateTime? _startDate;
  DateTime? _endDate;
  int? _selectedShopId;
  flot_model.StatutFlot? _filtreStatut;
  List<flot_model.FlotModel> _flots = [];
  List<ShopModel> _shops = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _isFiltersExpanded = false; // Add this line to control filter visibility

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _selectedShopId = widget.shopId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    await _loadShops();
    await _loadFlots();
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

  Future<void> _loadFlots() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final flotService = Provider.of<FlotService>(context, listen: false);
      await flotService.loadFlots();
      
      setState(() {
        _flots = flotService.flots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erreur lors du chargement des flots: $e';
        _isLoading = false;
      });
    }
  }

  List<flot_model.FlotModel> _getFilteredFlots() {
    var filteredFlots = _flots;

    // Filtrer par date
    if (_startDate != null) {
      filteredFlots = filteredFlots.where((f) => f.dateEnvoi.isAfter(_startDate!)).toList();
    }
    
    if (_endDate != null) {
      filteredFlots = filteredFlots.where((f) => f.dateEnvoi.isBefore(_endDate!.add(const Duration(days: 1)))).toList();
    }
    
    // Filtrer par shop
    if (_selectedShopId != null) {
      filteredFlots = filteredFlots.where((f) => 
        f.shopSourceId == _selectedShopId || f.shopDestinationId == _selectedShopId
      ).toList();
    }
    
    // Filtrer par statut
    if (_filtreStatut != null) {
      filteredFlots = filteredFlots.where((f) => f.statut == _filtreStatut).toList();
    }

    // Trier par date d'envoi (plus récents en premier)
    filteredFlots.sort((a, b) => b.dateEnvoi.compareTo(a.dateEnvoi));
    
    return filteredFlots;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    final filteredFlots = _getFilteredFlots();

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filtres
          _buildFilters(isMobile),
          const SizedBox(height: 24),

          // Statistiques
          _buildStatistics(filteredFlots),
          const SizedBox(height: 24),

          // Liste des flots
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_errorMessage != null)
            _buildError(_errorMessage!)
          else
            _buildFlotsList(filteredFlots, isMobile),
          
          const SizedBox(height: 24),
          // Boutons PDF
          if (!_isLoading && _errorMessage == null)
            _buildPdfActions(),
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
                const Icon(Icons.filter_list, color: Color(0xFF9C27B0)),
                const SizedBox(width: 12),
                const Text(
                  'Filtres',
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
                        // Filtres de date
                        Row(
                          children: [
                            const Icon(Icons.date_range, color: Color(0xFF9C27B0)),
                            const SizedBox(width: 12),
                            const Text('Période:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _startDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (date != null) {
                                          setState(() => _startDate = date);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _startDate != null 
                                            ? '${_startDate!.day.toString().padLeft(2, '0')}/${_startDate!.month.toString().padLeft(2, '0')}/${_startDate!.year}'
                                            : 'Date début',
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text('à'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: GestureDetector(
                                      onTap: () async {
                                        final date = await showDatePicker(
                                          context: context,
                                          initialDate: _endDate ?? DateTime.now(),
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime.now(),
                                        );
                                        if (date != null) {
                                          setState(() => _endDate = date);
                                        }
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border.all(color: Colors.grey),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          _endDate != null 
                                            ? '${_endDate!.day.toString().padLeft(2, '0')}/${_endDate!.month.toString().padLeft(2, '0')}/${_endDate!.year}'
                                            : 'Date fin',
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Filtre par shop
                        Row(
                          children: [
                            const Icon(Icons.store, color: Color(0xFF9C27B0)),
                            const SizedBox(width: 12),
                            const Text('Shop:', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButton<int>(
                                value: _selectedShopId,
                                items: [
                                  const DropdownMenuItem(
                                    value: null,
                                    child: Text('Tous les shops'),
                                  ),
                                  ..._shops.where((shop) => shop.id != null).map((shop) {
                                    return DropdownMenuItem(
                                      value: shop.id!,
                                      child: Text(shop.designation ?? 'Shop sans nom'),
                                    );
                                  }).toList(),
                                ],
                                onChanged: (value) {
                                  setState(() => _selectedShopId = value);
                                },
                                isExpanded: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        
                        // Filtre par statut
                        const Text('Statut:', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilterChip(
                              label: const Text('Tous'),
                              selected: _filtreStatut == null,
                              onSelected: (selected) {
                                setState(() => _filtreStatut = null);
                              },
                            ),
                            FilterChip(
                              label: const Text('En Route'),
                              selected: _filtreStatut == flot_model.StatutFlot.enRoute,
                              selectedColor: Colors.orange.shade200,
                              onSelected: (selected) {
                                setState(() => _filtreStatut = flot_model.StatutFlot.enRoute);
                              },
                            ),
                            FilterChip(
                              label: const Text('Servi'),
                              selected: _filtreStatut == flot_model.StatutFlot.servi,
                              selectedColor: Colors.green.shade200,
                              onSelected: (selected) {
                                setState(() => _filtreStatut = flot_model.StatutFlot.servi);
                              },
                            ),
                            FilterChip(
                              label: const Text('Annulé'),
                              selected: _filtreStatut == flot_model.StatutFlot.annule,
                              selectedColor: Colors.red.shade200,
                              onSelected: (selected) {
                                setState(() => _filtreStatut = flot_model.StatutFlot.annule);
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                setState(() {
                                  _startDate = null;
                                  _endDate = null;
                                  _selectedShopId = null;
                                  _filtreStatut = null;
                                });
                              },
                              child: const Text('Réinitialiser'),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: _loadFlots,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF9C27B0),
                              ),
                              child: const Text('Appliquer'),
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

  Widget _buildStatistics(List<flot_model.FlotModel> flots) {
    // Calculer les statistiques
    final flotsEnRoute = flots.where((f) => f.statut == flot_model.StatutFlot.enRoute).length;
    final flotsServis = flots.where((f) => f.statut == flot_model.StatutFlot.servi).length;
    final flotsAnnules = flots.where((f) => f.statut == flot_model.StatutFlot.annule).length;
    
    final totalMontant = flots.fold(0.0, (sum, f) => sum + f.montant);
    final montantEnRoute = flots.where((f) => f.statut == flot_model.StatutFlot.enRoute)
        .fold(0.0, (sum, f) => sum + f.montant);
    final montantServi = flots.where((f) => f.statut == flot_model.StatutFlot.servi)
        .fold(0.0, (sum, f) => sum + f.montant);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Statistiques',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Total Flots',
                    '$flotsEnRoute',
                    Icons.local_shipping,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Flots Servis',
                    '$flotsServis',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Flots Annulés',
                    '$flotsAnnules',
                    Icons.cancel,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Montant Total',
                    '${totalMontant.toStringAsFixed(2)} USD',
                    Icons.attach_money,
                    const Color(0xFF9C27B0),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Montant En Route',
                    '${montantEnRoute.toStringAsFixed(2)} USD',
                    Icons.local_shipping,
                    Colors.orange,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Montant Servi',
                    '${montantServi.toStringAsFixed(2)} USD',
                    Icons.check_circle,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
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
            title,
            style: TextStyle(
              fontSize: 12,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
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

  Widget _buildFlotsList(List<flot_model.FlotModel> flots, bool isMobile) {
    if (flots.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Aucun flot trouvé',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Aucun mouvement FLOT ne correspond aux filtres sélectionnés',
                  style: TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Mouvements FLOT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${flots.length} flots',
                  style: TextStyle(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Divider(),
          SizedBox(
            height: 400,
            child: ListView.builder(
              itemCount: flots.length,
              itemBuilder: (context, index) {
                return _buildFlotItem(flots[index], isMobile);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlotItem(flot_model.FlotModel flot, bool isMobile) {
    Color statutColor;
    IconData statutIcon;
    String statutLabel;
    
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statutColor = Colors.orange;
        statutIcon = Icons.local_shipping;
        statutLabel = 'En Route';
        break;
      case flot_model.StatutFlot.servi:
        statutColor = Colors.green;
        statutIcon = Icons.check_circle;
        statutLabel = 'Servi';
        break;
      case flot_model.StatutFlot.annule:
        statutColor = Colors.red;
        statutIcon = Icons.cancel;
        statutLabel = 'Annulé';
        break;
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statutColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statutIcon, size: 16, color: statutColor),
                      const SizedBox(width: 4),
                      Text(
                        statutLabel,
                        style: TextStyle(
                          color: statutColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${flot.montant.toStringAsFixed(2)} ${flot.devise}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF9C27B0),
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
                      const Text('De:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        flot.shopSourceDesignation,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('Vers:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      Text(
                        flot.shopDestinationDesignation,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Envoyé: ${_formatDate(flot.dateEnvoi)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                if (flot.dateReception != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.check, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    'Reçu: ${_formatDate(flot.dateReception!)}',
                    style: const TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ],
            ),
            if (flot.reference != null) ...[
              const SizedBox(height: 4),
              Text(
                'Réf: ${flot.reference}',
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
            if (flot.notes != null && flot.notes!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Text(
                  flot.notes!,
                  style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  // Boutons actions PDF
  Widget _buildPdfActions() {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isMobile
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _previsualiserPDF,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Prévisualiser PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _imprimerPDF,
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _telechargerPDF,
                    icon: const Icon(Icons.download),
                    label: const Text('Télécharger'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: _previsualiserPDF,
                    icon: const Icon(Icons.visibility),
                    label: const Text('Prévisualiser PDF'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF9C27B0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _imprimerPDF,
                    icon: const Icon(Icons.print),
                    label: const Text('Imprimer'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: _telechargerPDF,
                    icon: const Icon(Icons.download),
                    label: const Text('Télécharger'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _previsualiserPDF() async {
    try {
      final filteredFlots = _getFilteredFlots();
      
      final pdf = await generateFlotReportPdf(
        flots: filteredFlots,
        startDate: _startDate,
        endDate: _endDate,
      );

      final pdfBytes = await pdf.save();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    color: const Color(0xFF9C27B0),
                    child: Row(
                      children: [
                        const Text(
                          'Prévisualisation Rapport FLOT',
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
                            await Printing.sharePdf(
                              bytes: pdfBytes,
                              filename: 'rapport_flot_${DateTime.now().toString().split(' ')[0]}.pdf',
                            );
                          },
                        ),
                        PdfPreviewAction(
                          icon: const Icon(Icons.print),
                          onPressed: (context, build, pageFormat) async {
                            await Printing.layoutPdf(
                              onLayout: (format) => pdfBytes,
                            );
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
    try {
      final filteredFlots = _getFilteredFlots();
      
      final pdf = await generateFlotReportPdf(
        flots: filteredFlots,
        startDate: _startDate,
        endDate: _endDate,
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e')),
        );
      }
    }
  }

  Future<void> _telechargerPDF() async {
    try {
      final filteredFlots = _getFilteredFlots();
      
      final pdf = await generateFlotReportPdf(
        flots: filteredFlots,
        startDate: _startDate,
        endDate: _endDate,
      );

      await Printing.sharePdf(
        bytes: await pdf.save(),
        filename: 'rapport_flot_${DateTime.now().toString().split(' ')[0]}.pdf',
      );

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
}