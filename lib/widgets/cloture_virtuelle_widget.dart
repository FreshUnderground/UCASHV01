import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/cloture_virtuelle_model.dart';
import '../services/cloture_virtuelle_service.dart';
import '../services/cloture_virtuelle_pdf_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/local_db.dart';

/// Widget pour la clôture journalière des transactions virtuelles
/// Inspiré du design moderne de cloture_agent_widget.dart
class ClotureVirtuelleWidget extends StatefulWidget {
  final int? shopId;
  final bool isAdminView; // Si true, masque le bouton de clôture
  
  const ClotureVirtuelleWidget({
    super.key,
    this.shopId,
    this.isAdminView = false,
  });

  @override
  State<ClotureVirtuelleWidget> createState() => _ClotureVirtuelleWidgetState();
}

class _ClotureVirtuelleWidgetState extends State<ClotureVirtuelleWidget> {
  DateTime _selectedDate = DateTime.now();
  List<ClotureVirtuelleModel> _clotures = [];
  Map<String, dynamic>? _rapport;
  bool _isLoading = false;
  bool _journeeCloturee = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClotures();
      _genererRapport();
    });
  }

  Future<void> _loadClotures() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      final clotures = await LocalDB.instance.getAllCloturesVirtuelles(shopId: shopId);
      
      if (!mounted) return;
      
      setState(() {
        _clotures = clotures;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Erreur: $e')),
      );
    }
  }

  Future<void> _genererRapport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      // Vérifier si déjà clôturé
      final estCloturee = await ClotureVirtuelleService.instance.journeeEstCloturee(
        shopId, 
        _selectedDate
      );

      final rapport = await ClotureVirtuelleService.instance.genererRapportCloture(
        shopId: shopId,
        date: _selectedDate,
      );

      setState(() {
        _rapport = rapport;
        _journeeCloturee = estCloturee;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _cloturerJournee() async {
    if (_journeeCloturee) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cette journée a déjà été clôturée'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la clôture'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Voulez-vous clôturer la journée du ${DateFormat('dd/MM/yyyy').format(_selectedDate)}?'),
            const SizedBox(height: 16),
            const Text(
              'Cette action est irréversible.',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Clôturer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      final shop = shopService.shops.firstWhere((s) => s.id == shopId);

      await ClotureVirtuelleService.instance.cloturerJournee(
        shopId: shopId,
        shopDesignation: shop.designation,
        dateCloture: _selectedDate,
        cloturePar: authService.currentUser?.username ?? 'Unknown',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Journée clôturée avec succès'),
            backgroundColor: Colors.green,
          ),
        );
        _genererRapport();
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _previsualiserPDF() async {
    if (_rapport == null) return;

    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      final shop = shopService.shops.firstWhere(
        (s) => s.id == shopId,
        orElse: () => throw Exception('Shop non trouvé'),
      );

      // Générer le PDF
      final pdf = await genererClotureVirtuellePDF(
        _rapport!,
        shop.designation,
        _selectedDate,
      );

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
                    color: const Color(0xFF48bb78),
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
                  // Contenu PDF
                  Expanded(
                    child: PdfPreview(
                      build: (format) => pdfBytes,
                      allowSharing: false,
                      allowPrinting: false,
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
          SnackBar(
            content: Text('❌ Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _telechargerPDF() async {
    if (_rapport == null) return;

    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      final shop = shopService.shops.firstWhere(
        (s) => s.id == shopId,
        orElse: () => throw Exception('Shop non trouvé'),
      );

      // Générer le PDF
      final pdf = await genererClotureVirtuellePDF(
        _rapport!,
        shop.designation,
        _selectedDate,
      );

      final pdfBytes = await pdf.save();
      final fileName = 'cloture_virtuelle_${shop.designation}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf';

      // Partager le PDF
      await Printing.sharePdf(bytes: pdfBytes, filename: fileName);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ PDF généré avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📱 Clôture Virtuelle'),
        backgroundColor: const Color(0xFF48bb78),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Voir Rapport de Clôture',
            onPressed: () => _genererRapport(),
          ),
          if (_rapport != null) ...[
            IconButton(
              icon: const Icon(Icons.visibility),
              tooltip: 'Prévisualiser PDF',
              onPressed: _previsualiserPDF,
            ),
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Télécharger PDF',
              onPressed: _telechargerPDF,
            ),
          ],
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: () {
              _loadClotures();
              _genererRapport();
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Sélecteur de date et bouton clôturer
            _buildHeader(isMobile),
            
            // Liste des clôtures
            _isLoading
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : _clotures.isEmpty
                    ? _buildEmptyState()
                    : _buildCloturesList(isMobile),
          ],
        ),
      ),
    );
  }

  // Add modern header method inspired by cloture_agent_widget.dart
  Widget _buildHeader(bool isMobile) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
    
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF48bb78),
            const Color(0xFF48bb78).withOpacity(0.8),
          ],
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
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Sélecteur de date
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.mobile_friendly, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date de clôture virtuelle',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime.now(),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: Color(0xFF48bb78),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                      _loadClotures();
                      _genererRapport();
                    }
                  },
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: Text(isMobile ? 'Changer' : 'Modifier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF48bb78),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 10 : 18,
                      vertical: isMobile ? 8 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Bouton clôturer la journée virtuelle (MASQUÉ pour l'admin)
            if (!widget.isAdminView)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cloturerJournee,
                  icon: const Icon(Icons.mobile_screen_share, size: 22),
                  label: Text(
                    isMobile ? 'Clôturer Virtuel' : 'Clôturer la Journée Virtuelle',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF48bb78),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 22,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mobile_off_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune clôture virtuelle enregistrée',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cliquez sur "Clôturer la Journée Virtuelle" pour commencer',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCloturesList(bool isMobile) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: _clotures.map((cloture) => _buildClotureCard(cloture, isMobile)).toList(),
      ),
    );
  }

  Widget _buildClotureCard(ClotureVirtuelleModel cloture, bool isMobile) {
    final hasProfit = cloture.fraisTotalJournee > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFF48bb78).withOpacity(0.1),
            blurRadius: 30,
            offset: const Offset(0, 10),
            spreadRadius: -5,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          children: [
            // En-tête de la carte
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF48bb78).withOpacity(0.1),
                    const Color(0xFF48bb78).withOpacity(0.05)
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Icône circulaire
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF48bb78),
                              const Color(0xFF48bb78).withOpacity(0.7)
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF48bb78).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mobile_friendly,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd/MM/yyyy').format(cloture.dateCloture),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.person, size: 14, color: Colors.grey[700]),
                                      const SizedBox(width: 4),
                                      Text(
                                        cloture.cloturePar,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey[800],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats en grille
                  Row(
                    children: [
                      Expanded(
                        child: _buildModernStat('Captures', cloture.nombreCaptures.toDouble(), Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModernStat('Servies', cloture.nombreServies.toDouble(), Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModernStat('Frais', cloture.fraisTotalJournee, Colors.green),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label == 'Frais' 
              ? '\$${value.toStringAsFixed(2)}'
              : '${value.toStringAsFixed(0)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
