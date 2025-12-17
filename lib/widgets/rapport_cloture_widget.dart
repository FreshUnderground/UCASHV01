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

/// Widget pour afficher et générer le Rapport de Clôture Journalière
class RapportClotureWidget extends StatefulWidget {
  final int? shopId;
  
  const RapportClotureWidget({super.key, this.shopId});

  @override
  State<RapportClotureWidget> createState() => _RapportClotureWidgetState();
}

class _RapportClotureWidgetState extends State<RapportClotureWidget> {
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
      
      // Forcer le rechargement des données en passant null pour les opérations
      // Cela forcera le service à recharger les opérations depuis la base de données
      final rapport = await RapportClotureService.instance.genererRapport(
        shopId: shopId,
        date: _selectedDate,
        generePar: authService.currentUser?.username ?? 'Admin',
        operations: null, // Force le rechargement depuis LocalDB
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

      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(_rapport!, shop);

      // Prévisualiser le PDF
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

      // Confirmation avant impression
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.print, color: Color(0xFFDC2626)),
              SizedBox(width: 12),
              Text('Confirmer l\'impression'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Rapport de clôture du ${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}'),
              const SizedBox(height: 8),
              Text('Shop: ${shop.designation}'),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: const Text(
                  '💡 Conseil: Utilisez "Prévisualiser" pour voir le contenu avant d\'imprimer',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Annuler'),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.print),
              label: const Text('Imprimer'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
      
      if (confirmed != true) return;

      // Générer le PDF avec le nouveau service
      final pdf = await genererRapportCloturePDF(_rapport!, shop);

      // Imprimer directement
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'rapportcloture_${shop.designation}_${DateFormat('yyyy-MM-dd').format(_selectedDate)}.pdf',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Impression lancée avec succès'),
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('📊 Rapport de Clôture Journalière'),
        backgroundColor: const Color(0xFFDC2626),
        actions: [
          // Bouton de rafraîchissement pour forcer le rechargement des données
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser le rapport',
            onPressed: _genererRapport,
          ),
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
            const SizedBox(height: 8),
            Text(
              '${rapport.capitalNet.toStringAsFixed(2)} USD',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: rapport.capitalNet >= 0 ? Colors.blue[700] : Colors.red[700],
              ),
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _buildCapitalBreakdown('Cash Disponible', rapport.cashDisponibleTotal, Colors.green),
            _buildCapitalBreakdown('+ Shops Nous qui Doivent', rapport.totalShopsNousDoivent, Colors.orange),
            _buildCapitalBreakdown('- Shops Nous que Devons', -rapport.totalShopsNousDevons, Colors.purple),
            (() {
              final totalSoldePartenaire = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
              return _buildCapitalBreakdown('+ Solde Net Partenaires', totalSoldePartenaire, totalSoldePartenaire >= 0 ? Colors.blue : Colors.red);
            }()),
            const SizedBox(height: 8),
            const Divider(thickness: 2),
            const SizedBox(height: 8),
            (() {
              final totalSoldePartenaire = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
              // EXCLUSION: Depots Partenaires et Partenaires Servis ne sont plus inclus dans le calcul du capital NET
              final capitalNetSansPartenaires = rapport.cashDisponibleTotal + 
                                               rapport.totalShopsNousDoivent - 
                                               rapport.totalShopsNousDevons - 
                                               (rapport.soldeFraisAnterieur + rapport.commissionsFraisDuJour - rapport.retraitsFraisDuJour) - 
                                               rapport.transfertsEnAttente +
                                               totalSoldePartenaire;
              return _buildCapitalBreakdown('= CAPITAL NET', capitalNetSansPartenaires, capitalNetSansPartenaires >= 0 ? Colors.blue : Colors.red, bold: true);
            }()),
          ],
        ),
      ),
    );
  }

  Widget _buildCashBreakdown(String label, double montant) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCapitalBreakdown(String label, double montant, Color color, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label, 
            style: TextStyle(
              fontSize: bold ? 16 : 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '${montant.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods - moved to top to fix compilation errors
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

  Widget _buildLine(String label, double montant, {bool bold = false, Color? color, String prefix = ''}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: bold ? 16 : 14,
            ),
          ),
          Text(
            '$prefix${montant.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.w500,
              fontSize: bold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeftColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        _buildSection(
          '1️⃣ Solde Antérieur',
          [
            _buildLine('Cash', rapport.soldeAnterieurCash),
            _buildLine('Airtel Money', rapport.soldeAnterieurAirtelMoney),
            _buildLine('M-Pesa', rapport.soldeAnterieurMPesa),
            _buildLine('Orange Money', rapport.soldeAnterieurOrangeMoney),
            const Divider(),
            _buildLine('TOTAL', rapport.soldeAnterieurTotal, bold: true),
          ],
          Colors.grey,
        ),
        const SizedBox(height: 16),
        _buildSection(
          '2️⃣ Flots',
          [
            _buildLine('Reçus', rapport.flotRecu, color: Colors.green),
            _buildLine('Envoyés', rapport.flotEnvoye, color: Colors.red, prefix: '-'),
          ],
          Colors.purple,
        ),
        const SizedBox(height: 16),
        _buildSection(
          '3️⃣ Transferts',
          [
            _buildLine('Reçus', rapport.transfertsRecus, color: Colors.green),
            _buildLine('Servis', rapport.transfertsServis, color: Colors.red, prefix: '-'),
          ],
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildRightColumn(RapportClotureModel rapport) {
    return Column(
      children: [
        // Masqué: Opérations Clients
        // Partenaires Servis (anciennement Clients Nous qui Doivent)
        _buildSection(
          '5️⃣ Partenaires Servis',
          [
            Text(
              '${rapport.clientsNousDoivent.length} partenaire(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...rapport.clientsNousDoivent.take(5).map((client) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(client.nom, style: const TextStyle(fontSize: 12))),
                  Text(
                    '${client.solde.toStringAsFixed(2)} USD',
                    style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
            if (rapport.clientsNousDoivent.length > 5)
              Text('... et ${rapport.clientsNousDoivent.length - 5} autre(s)'),
            const Divider(),
            _buildLine('TOTAL', rapport.totalClientsNousDoivent, color: Colors.red),
          ],
          Colors.red,
        ),
        const SizedBox(height: 16),
        // Dépôts Partenaires (anciennement Clients Nous que Devons)
        _buildSection(
          '6️⃣ Dépôts Partenaires',
          [
            Text(
              '${rapport.clientsNousDevons.length} partenaire(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...rapport.clientsNousDevons.take(5).map((client) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(client.nom, style: const TextStyle(fontSize: 12))),
                  Text(
                    '${client.solde.toStringAsFixed(2)} USD',
                    style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )),
            if (rapport.clientsNousDevons.length > 5)
              Text('... et ${rapport.clientsNousDevons.length - 5} autre(s)'),
            const Divider(),
            _buildLine('TOTAL', rapport.totalClientsNousDevons, color: Colors.green),
          ],
          Colors.green,
        ),
        const SizedBox(height: 16),
        _buildSection(
          '7️⃣ Shops Nous qui Doivent',
          [
            Text(
              '${rapport.shopsNousDoivent.length} shop(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (rapport.shopsNousDoivent.isEmpty)
              const Text('Aucun shop débiteur', style: TextStyle(fontStyle: FontStyle.italic))
            else
              ...rapport.shopsNousDoivent.take(5).map((shop) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${shop.designation} (${shop.localisation})', style: const TextStyle(fontSize: 12))),
                    Text(
                      '${shop.montant.toStringAsFixed(2)} USD',
                      style: const TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
            if (rapport.shopsNousDoivent.length > 5)
              Text('... et ${rapport.shopsNousDoivent.length - 5} autre(s)'),
            const Divider(),
            _buildLine('TOTAL Dettes Inter-Shops', rapport.totalShopsNousDoivent, color: Colors.orange),
          ],
          Colors.orange,
        ),
        const SizedBox(height: 16),
        _buildSection(
          '8️⃣ Shops Nous que Devons',
          [
            Text(
              '${rapport.shopsNousDevons.length} shop(s)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (rapport.shopsNousDevons.isEmpty)
              const Text('Aucun shop créditeur', style: TextStyle(fontStyle: FontStyle.italic))
            else
              ...rapport.shopsNousDevons.take(5).map((shop) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text('${shop.designation} (${shop.localisation})', style: const TextStyle(fontSize: 12))),
                    Text(
                      '${shop.montant.toStringAsFixed(2)} USD',
                      style: const TextStyle(color: Colors.purple, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
            if (rapport.shopsNousDevons.length > 5)
              Text('... et ${rapport.shopsNousDevons.length - 5} autre(s)'),
            const Divider(),
            _buildLine('TOTAL Créances Inter-Shops', rapport.totalShopsNousDevons, color: Colors.purple),
          ],
          Colors.purple,
        ),
        const SizedBox(height: 16),
        
        // NOUVEAU: Section AUTRES SHOP (opérations où nous sommes destinataires)
        if (rapport.autresShopServis > 0 || rapport.autresShopDepots > 0)
          _buildSection(
            '9️⃣ AUTRES SHOP',
            [
              // SERVIS - Retraits où nous sommes destinataires
              if (rapport.autresShopServis > 0) ...[
                _buildLine('SERVIS ', rapport.autresShopServis, color: Colors.orange),
                
                // Détails SERVIS groupés par shop
                if (rapport.autresShopServisGroupes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Détail SERVIS par Client:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  ...rapport.autresShopServisGroupes.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '  • ${entry.key}',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
                const SizedBox(height: 8),
              ],
              
              // DEPOT - Dépôts où nous sommes destinataires
              if (rapport.autresShopDepots > 0) ...[
                _buildLine('DEPOT', rapport.autresShopDepots, color: Colors.green),
                
                // Détails DEPOT groupés par shop
                if (rapport.autresShopDepotsGroupes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Détail DEPOT par Client:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  ...rapport.autresShopDepotsGroupes.entries.map((entry) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '  • ${entry.key}',
                            style: const TextStyle(fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${entry.value.toStringAsFixed(2)} USD',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ],
              
              const Divider(),
              _buildLine('TOTAL', rapport.autresShopServis + rapport.autresShopDepots, color: Colors.blue, bold: true),
            ],
            Colors.blue,
          ),
        const SizedBox(height: 16),
        
        // NOUVEAU: Section SOLDE PAR PARTENAIRE (depot - retrait où nous sommes destination)
        // Cette section apparaît TOUJOURS, indépendamment des autres sections
        _buildSection(
          '🔟 SOLDE PAR PARTENAIRE',
          [
            // DEBUG: Afficher le nombre d'entrées pour diagnostic
            Text(
              'DEBUG: ${rapport.soldeParPartenaire.length} entrées trouvées',
              style: const TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
            ),
            // DEBUG: Afficher les détails de chaque entrée
            ...rapport.soldeParPartenaire.entries.map((entry) => Text(
              'DEBUG: ${entry.key} = ${entry.value.toStringAsFixed(2)} USD',
              style: const TextStyle(fontSize: 9, color: Colors.orange),
            )),
            const SizedBox(height: 4),
           
            // Afficher chaque partenaire avec son solde
            if (rapport.soldeParPartenaire.isEmpty)
              const Text(
                'Aucune opération partenaire trouvée pour ce jour',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey),
              )
            else
              ...rapport.soldeParPartenaire.entries.map((entry) {
                final solde = entry.value;
                final color = solde > 0 ? Colors.red : solde < 0 ? Colors.green : Colors.grey;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              entry.key, // Nom du partenaire (via shop)
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${solde < 0 ? "-" : ""}${solde.abs().toStringAsFixed(2)} USD',
                            style: TextStyle(
                              color: color,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
            
            if (rapport.soldeParPartenaire.isNotEmpty) ...[
              const Divider(),
              (() {
                final totalSolde = rapport.soldeParPartenaire.values.fold(0.0, (sum, solde) => sum + solde);
                final color = totalSolde > 0 ? Colors.red : totalSolde < 0 ? Colors.green : Colors.grey;
                return _buildLine('SOLDE NET', totalSolde, color: color, bold: true);
              }()),
            ],
          ],
          Colors.indigo,
        ),
      ],
    );
  }

}
