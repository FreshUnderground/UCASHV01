// ignore_for_file: unused_element

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../models/cloture_caisse_model.dart';
import '../services/rapport_cloture_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart';
import 'rapportcloture.dart';

/// Widget de gestion des clôtures de caisse pour l'agent
class ClotureAgentWidget extends StatefulWidget {
  final int? shopId;
  final bool isAdminView; // Si true, masque le bouton de clôture (admin ne peut pas clôturer)
  
  const ClotureAgentWidget({
    super.key,
    this.shopId,
    this.isAdminView = false,
  });

  @override
  State<ClotureAgentWidget> createState() => _ClotureAgentWidgetState();
}

class _ClotureAgentWidgetState extends State<ClotureAgentWidget> {
  DateTime _selectedDate = DateTime.now();
  List<ClotureCaisseModel> _clotures = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadClotures();
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
      
      final clotures = await LocalDB.instance.getCloturesCaisseByShop(shopId);
      
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

  Future<void> _cloturerJournee() async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
    
    // Vérifier si la journée est déjà clôturée
    final estCloturee = await RapportClotureService.instance.journeeEstCloturee(shopId, _selectedDate);
    
    if (estCloturee) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cette journée est déjà clôturée'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // Ouvrir le rapport de clôture pour clôturer
    if (!mounted) return;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RapportCloture(
          shopId: shopId,
          isAdminView: widget.isAdminView, // Transmettre le paramètre
        ),
      ),
    );
    
    // Recharger les clôtures après retour
    _loadClotures();
  }

  Future<void> _voirRapportCloture() async {
    if (!mounted) return;
    
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = widget.shopId ?? authService.currentUser?.shopId ?? 1;
    
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RapportCloture(
          shopId: shopId,
          isAdminView: widget.isAdminView, // Transmettre le paramètre
        ),
      ),
    );
  }

  Future<void> _supprimerCloture(ClotureCaisseModel cloture) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Voulez-vous vraiment supprimer la clôture du ${DateFormat('dd/MM/yyyy').format(cloture.dateCloture)} ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await LocalDB.instance.deleteClotureCaisse(cloture.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clôture supprimée avec succès'),
              backgroundColor: Colors.green,
            ),
          );
          _loadClotures();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('🔒 Gestion des Clôtures'),
        backgroundColor: const Color(0xFFDC2626),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment),
            tooltip: 'Voir Rapport de Clôture',
            onPressed: _voirRapportCloture,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualiser',
            onPressed: _loadClotures,
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

  Widget _buildHeader(bool isMobile) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFDC2626),
            const Color(0xFFDC2626).withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFDC2626).withOpacity(0.3),
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
                  child: const Icon(Icons.calendar_today, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Date',
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
                              primary: Color(0xFFDC2626),
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    if (date != null) {
                      setState(() => _selectedDate = date);
                    }
                  },
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: Text(isMobile ? 'Changer' : 'Modifier'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
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
            
            // Bouton clôturer la journée (MASQUÉ pour l'admin)
            if (!widget.isAdminView)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _cloturerJournee,
                  icon: const Icon(Icons.lock_clock, size: 22),
                  label: Text(
                    isMobile ? 'Clôturer' : 'Clôturer la Journée',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFFDC2626),
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
            Icons.inbox_outlined,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune clôture enregistrée',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Cliquez sur "Clôturer la Journée" pour commencer',
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

  Widget _buildClotureCard(ClotureCaisseModel cloture, bool isMobile) {
    final hasEcart = cloture.ecartTotal.abs() > 0.01;
    final ecartColor = cloture.ecartTotal > 0 ? Colors.green : (cloture.ecartTotal < 0 ? Colors.red : Colors.grey);
    
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
            color: hasEcart ? ecartColor.withOpacity(0.1) : Colors.transparent,
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
                  colors: hasEcart
                    ? [ecartColor.withOpacity(0.1), ecartColor.withOpacity(0.05)]
                    : [Colors.grey.withOpacity(0.05), Colors.grey.withOpacity(0.02)],
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
                            colors: hasEcart
                              ? [ecartColor, ecartColor.withOpacity(0.7)]
                              : [Colors.green, Colors.green.withOpacity(0.7)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (hasEcart ? ecartColor : Colors.green).withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          hasEcart ? Icons.trending_up : Icons.check,
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
                                const SizedBox(width: 4),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Bouton supprimer (Admin seulement)
                      Consumer<AuthService>(
                        builder: (context, authService, child) {
                          final isAdmin = authService.currentUser?.role == 'admin';
                          
                          if (!isAdmin) {
                            return const SizedBox.shrink();
                          }
                          
                          return IconButton(
                            onPressed: () => _supprimerCloture(cloture),
                            icon: const Icon(Icons.delete_outline),
                            color: Colors.red,
                            tooltip: 'Supprimer (Admin)',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Stats en grille
                  Row(
                    children: [
                      Expanded(
                        child: _buildModernStat('Saisi', cloture.soldeSaisiTotal, Colors.blue),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModernStat('Calculé', cloture.soldeCalculeTotal, Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildModernStat('Écart', cloture.ecartTotal, ecartColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Section expandable
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: EdgeInsets.zero,
                title: Row(
                  children: [
                    Icon(Icons.analytics_outlined, size: 18, color: Colors.grey[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Voir les détails',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
                children: [
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        const Divider(height: 1),
                        const SizedBox(height: 20),
                        _buildDetailCard(
                          'USD',
                          Icons.attach_money,
                          cloture.soldeSaisiCash,
                          cloture.soldeCalculeCash,
                          cloture.ecartCash,
                          Colors.green,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          'Airtel Money',
                          Icons.phone_android,
                          cloture.soldeSaisiAirtelMoney,
                          cloture.soldeCalculeAirtelMoney,
                          cloture.ecartAirtelMoney,
                          Colors.red,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          'MPESA/VODACASH',
                          Icons.phone_android,
                          cloture.soldeSaisiMPesa,
                          cloture.soldeCalculeMPesa,
                          cloture.ecartMPesa,
                          Colors.blue,
                        ),
                        const SizedBox(height: 12),
                        _buildDetailCard(
                          'Orange Money',
                          Icons.phone_android,
                          cloture.soldeSaisiOrangeMoney,
                          cloture.soldeCalculeOrangeMoney,
                          cloture.ecartOrangeMoney,
                          Colors.orange,
                        ),
                        if (cloture.notes != null && cloture.notes!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: Colors.amber.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.note_alt_outlined, size: 20, color: Colors.amber[800]),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    cloture.notes!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      height: 1.5,
                                      color: Colors.grey[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
      padding: const EdgeInsets.all(5),
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
            '${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailCard(String label, IconData icon, double saisi, double calcule, double ecart, Color color) {
    final hasEcart = ecart.abs() > 0.01;
    final ecartColor = ecart > 0 ? Colors.green : (ecart < 0 ? Colors.red : Colors.grey);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [color, color.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildAmountChip('Saisi', saisi, Colors.blue),
                    const SizedBox(width: 8),
                    _buildAmountChip('Calculé', calcule, Colors.purple),
                    if (hasEcart) ...[
                      const SizedBox(width: 8),
                      _buildAmountChip('Écart', ecart, ecartColor),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountChip(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '${value.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(2)} \$',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, double value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withOpacity(0.15),
            color.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${value.toStringAsFixed(2)} \$',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, IconData icon, double saisi, double calcule, double ecart) {
    final hasEcart = ecart.abs() > 0.01;
    final ecartColor = ecart > 0 ? Colors.green : (ecart < 0 ? Colors.red : Colors.grey);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFFDC2626)),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Saisi', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '${saisi.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Calculé', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(
                  '${calcule.toStringAsFixed(2)} \$',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Écart', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (hasEcart)
                      Icon(
                        ecart > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                        size: 12,
                        color: ecartColor,
                      ),
                    Text(
                      '${ecart.toStringAsFixed(2)} \$',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: ecartColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
