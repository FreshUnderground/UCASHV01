import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/rapport_cloture_model.dart';
import '../services/rapport_cloture_service.dart';
import '../services/auth_service.dart';
import '../services/rapportcloture_pdf_service.dart';
import '../services/shop_service.dart';

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
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _genererRapport();
    });
  }

  Future<void> _genererRapport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
      
      final rapport = await RapportClotureService.instance.genererRapport(
        shopId: shopId,
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
      final pdf = await generateRapportCloturePdf(
        rapport: _rapport!,
        shop: shop,
      );

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
      final pdf = await generateRapportCloturePdf(
        rapport: _rapport!,
        shop: shop,
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
      final pdf = await generateRapportCloturePdf(
        rapport: _rapport!,
        shop: shop,
      );

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
        child: Row(
          children: [
            const Icon(Icons.calendar_today, color: Color(0xFFDC2626)),
            const SizedBox(width: 12),
            const Text(
              'Date du rapport:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
            _buildMovementRow('En cours', rapport.flotEnCours, false),
            _buildMovementRow('Servis', rapport.flotServi, false),
            
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
            
            // Détails des FLOTs envoyés
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
            
            // Détails des FLOTs en cours
            if (rapport.flotsEnCoursDetails.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('FLOTs En Cours Détails:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const Divider(),
              ...rapport.flotsEnCoursDetails.map((flot) => _buildFlotDetailRow(
                flot.shopDestinationDesignation,
                '${DateFormat('dd/MM HH:mm').format(flot.dateEnvoi)} - ${flot.modePaiement}',
                flot.montant,
                Colors.orange,
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
            _buildMovementRow('Reçus', rapport.transfertsRecus, true),
            _buildMovementRow('Servis', rapport.transfertsServis, false),
          ],
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildRightColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        // Opérations Clients
        _buildSection(
          '4️⃣ Opérations Clients',
          [
            _buildMovementRow('Dépôts', rapport.depotsClients, true),
            _buildMovementRow('Retraits', rapport.retraitsClients, false),
          ],
          Colors.orange,
        ),
        const SizedBox(height: 16),

        // Clients Nous Doivent
        _buildSection(
          '5️⃣ Clients Nous Doivent',
          [
            Text('${rapport.clientsNousDoivent.length} client(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            // Show detailed client list like UI
            ...rapport.clientsNousDoivent.map((client) => _buildClientRow(
              client.nom,
              client.solde,
              Colors.red,
            )).toList(),
            const Divider(),
            _buildTotalRow('TOTAL Dettes', rapport.totalClientsNousDoivent, color: Colors.red),
          ],
          Colors.red,
        ),
        const SizedBox(height: 16),

        // Clients Nous Devons
        _buildSection(
          '6️⃣ Clients Nous Devons',
          [
            Text('${rapport.clientsNousDevons.length} client(s)', style: const TextStyle(fontWeight: FontWeight.bold)),
            const Divider(),
            // Show detailed client list like UI
            ...rapport.clientsNousDevons.map((client) => _buildClientRow(
              client.nom,
              client.solde,
              Colors.green,
            )).toList(),
            const Divider(),
            _buildTotalRow('TOTAL Créances', rapport.totalClientsNousDevons, color: Colors.green),
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
            _buildCashRow('+ Clients Nous Doivent', rapport.totalClientsNousDoivent),
            _buildCashRow('+ Shops Nous Doivent', rapport.totalShopsNousDoivent),
            _buildCashRow('- Clients Nous Devons', rapport.totalClientsNousDevons),
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
}