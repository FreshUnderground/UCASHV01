import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flot_model.dart' as flot_model;
import '../models/operation_model.dart';
import '../services/flot_service.dart';
import '../services/shop_service.dart';
import '../services/auth_service.dart';
import '../services/local_db.dart'; // This should be correct
import 'flot_dialog.dart';

/// Widget pour gérer les FLOTS (approvisionnement de liquidité entre shops)
class FlotManagementWidget extends StatefulWidget {
  const FlotManagementWidget({super.key});

  @override
  State<FlotManagementWidget> createState() => _FlotManagementWidgetState();
}

class _FlotManagementWidgetState extends State<FlotManagementWidget> {
  flot_model.StatutFlot? _filtreStatut;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _chargerFlots();
    });
  }

  Future<void> _chargerFlots() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    final isAdmin = authService.currentUser?.role == 'ADMIN';
    await FlotService.instance.loadFlots(shopId: shopId, isAdmin: isAdmin);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('💸 Gestion des FLOTS'),
        backgroundColor: const Color(0xFF9C27B0),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _chargerFlots,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildHeaderInfo(),
          _buildFiltres(),
          Expanded(child: _buildListe()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _afficherDialogueNouveauFlot(),
        backgroundColor: const Color(0xFF9C27B0),
        foregroundColor: Colors.white,
        elevation: 8,
        icon: const Icon(Icons.add, size: 20),
        label: Text(
          isMobile ? 'Nouveau Flot' : 'Nouvel Approvisionnement',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo() {
    return Consumer3<FlotService, AuthService, ShopService>(
      builder: (context, flotService, authService, shopService, child) {
        final size = MediaQuery.of(context).size;
        final isMobile = size.width <= 768;
        
        final currentShopId = authService.currentUser?.shopId;
        if (currentShopId == null) return const SizedBox.shrink();
        
        final currentShop = shopService.getShopById(currentShopId);
        if (currentShop == null) return const SizedBox.shrink();
        
        // Calculer les dettes et créances
        double totalDette = currentShop.dettes;
        double totalCreance = currentShop.creances;
        
        return Card(
          margin: const EdgeInsets.all(16),
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📊 Votre Position Financière',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 16),
                if (isMobile)
                  Column(
                    children: [
                      _buildFinancialCard(
                        title: 'Vous devez',
                        amount: totalDette,
                        color: Colors.red,
                        icon: Icons.arrow_upward,
                      ),
                      const SizedBox(height: 12),
                      _buildFinancialCard(
                        title: 'On vous doit',
                        amount: totalCreance,
                        color: Colors.green,
                        icon: Icons.arrow_downward,
                      ),
                      const SizedBox(height: 12),
                      _buildFinancialCard(
                        title: 'Solde net',
                        amount: totalCreance - totalDette,
                        color: (totalCreance - totalDette) >= 0 ? Colors.blue : Colors.orange,
                        icon: Icons.account_balance,
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'Vous devez',
                          amount: totalDette,
                          color: Colors.red,
                          icon: Icons.arrow_upward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'On vous doit',
                          amount: totalCreance,
                          color: Colors.green,
                          icon: Icons.arrow_downward,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildFinancialCard(
                          title: 'Solde net',
                          amount: totalCreance - totalDette,
                          color: (totalCreance - totalDette) >= 0 ? Colors.blue : Colors.orange,
                          icon: Icons.account_balance,
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue, size: 18),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'ℹ️ Les approvisionnements (FLOT) réduisent vos dettes envers d\'autres shops',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildFinancialCard({
    required String title,
    required double amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${amount.toStringAsFixed(2)} USD',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFiltres() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 500;
        
        return Card(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Filtres', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 12),
                if (isCompact)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildFilterChip(
                        label: 'Tous',
                        selected: _filtreStatut == null,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = null);
                        },
                      ),
                      _buildFilterChip(
                        label: 'En Route',
                        selected: _filtreStatut == flot_model.StatutFlot.enRoute,
                        selectedColor: Colors.orange.shade200,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = flot_model.StatutFlot.enRoute);
                        },
                      ),
                      _buildFilterChip(
                        label: 'Servi',
                        selected: _filtreStatut == flot_model.StatutFlot.servi,
                        selectedColor: Colors.green.shade200,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = flot_model.StatutFlot.servi);
                        },
                      ),
                      _buildFilterChip(
                        label: 'Annulé',
                        selected: _filtreStatut == flot_model.StatutFlot.annule,
                        selectedColor: Colors.red.shade200,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = flot_model.StatutFlot.annule);
                        },
                      ),
                    ],
                  )
                else
                  Row(
                    children: [
                      _buildFilterChip(
                        label: 'Tous',
                        selected: _filtreStatut == null,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = null);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'En Route',
                        selected: _filtreStatut == flot_model.StatutFlot.enRoute,
                        selectedColor: Colors.orange.shade200,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = flot_model.StatutFlot.enRoute);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Servi',
                        selected: _filtreStatut == flot_model.StatutFlot.servi,
                        selectedColor: Colors.green.shade200,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = flot_model.StatutFlot.servi);
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        label: 'Annulé',
                        selected: _filtreStatut == flot_model.StatutFlot.annule,
                        selectedColor: Colors.red.shade200,
                        onSelected: (selected) {
                          setState(() => _filtreStatut = flot_model.StatutFlot.annule);
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  /// Widget helper pour les filtres
  Widget _buildFilterChip({
    required String label,
    required bool selected,
    required ValueChanged<bool> onSelected,
    Color? selectedColor,
  }) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 13)),
      selected: selected,
      selectedColor: selectedColor,
      onSelected: onSelected,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      labelStyle: TextStyle(
        fontWeight: selected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildListe() {
    return Consumer<FlotService>(
      builder: (context, flotService, child) {
        if (flotService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        var flots = flotService.flots;
        
        // Appliquer le filtre
        if (_filtreStatut != null) {
          flots = flots.where((f) => f.statut == _filtreStatut).toList();
        }

        if (flots.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey),
                SizedBox(height: 16),
                Text('Aucun flot', style: TextStyle(color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: flots.length,
          itemBuilder: (context, index) => _buildFlotCard(flots[index]),
        );
      },
    );
  }

  Widget _buildFlotCard(flot_model.FlotModel flot) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentShopId = authService.currentUser?.shopId;
    final isDestination = flot.shopDestinationId == currentShopId;
    final peutMarquerServi = isDestination && flot.statut == flot_model.StatutFlot.enRoute;
    final peutModifier = flot.shopSourceId == currentShopId && flot.statut == flot_model.StatutFlot.enRoute;
    final peutSupprimer = flot.shopSourceId == currentShopId && flot.statut == flot_model.StatutFlot.enRoute;

    Color statutColor;
    IconData statutIcon;
    String statutDescription;
    
    switch (flot.statut) {
      case flot_model.StatutFlot.enRoute:
        statutColor = Colors.orange;
        statutIcon = Icons.local_shipping;
        statutDescription = 'En attente de réception';
        break;
      case flot_model.StatutFlot.servi:
        statutColor = Colors.green;
        statutIcon = Icons.check_circle;
        statutDescription = 'Reçu par le destinataire';
        break;
      case flot_model.StatutFlot.annule:
        statutColor = Colors.red;
        statutIcon = Icons.cancel;
        statutDescription = 'Annulé';
        break;
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              statutColor.withOpacity(0.05),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header avec montant et statut
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: statutColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statutColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statutIcon, size: 20, color: statutColor),
                        const SizedBox(width: 8),
                        Text(
                          flot.statutLabel,
                          style: TextStyle(
                            color: statutColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${flot.montant.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF9C27B0),
                        ),
                      ),
                      Text(
                        flot.devise,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Description du statut
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: statutColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statutColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(statutIcon, color: statutColor, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        statutDescription,
                        style: TextStyle(
                          color: statutColor,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Information sur l'impact sur les dettes
              if (flot.statut == flot_model.StatutFlot.enRoute) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info, color: Colors.blue, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Ce flot réduira la dette de ${flot.shopSourceDesignation} envers ${flot.shopDestinationDesignation}',
                          style: const TextStyle(
                            color: Colors.blue,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Shops
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildShopInfo(
                      title: 'Expéditeur',
                      shopName: flot.shopSourceDesignation,
                      isCurrentShop: flot.shopSourceId == currentShopId,
                      icon: Icons.upload,
                      iconColor: Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    const Icon(Icons.arrow_downward, color: Colors.grey),
                    const SizedBox(height: 12),
                    _buildShopInfo(
                      title: 'Destinataire',
                      shopName: flot.shopDestinationDesignation,
                      isCurrentShop: flot.shopDestinationId == currentShopId,
                      icon: Icons.download,
                      iconColor: Colors.green,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Dates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDateInfo(
                    icon: Icons.send,
                    label: 'Envoyé',
                    date: flot.dateEnvoi,
                    color: Colors.orange,
                  ),
                  if (flot.dateReception != null)
                    _buildDateInfo(
                      icon: Icons.check_circle,
                      label: 'Reçu',
                      date: flot.dateReception!,
                      color: Colors.green,
                    ),
                ],
              ),
              
              if (flot.reference != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.tag, size: 14, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Réf: ${flot.reference}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              if (flot.notes != null && flot.notes!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '📝 Notes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        flot.notes!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 20),
              
              // Actions
              Row(
                children: [
                  if (peutModifier) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _afficherDialogueModifierFlot(flot),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.edit, size: 18),
                        label: const Text('Modifier', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (peutSupprimer) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _supprimerFlot(flot),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                        label: const Text('Supprimer', style: TextStyle(fontSize: 14, color: Colors.red)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (peutMarquerServi) ...[
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _marquerServi(flot),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(Icons.check_circle, size: 18),
                        label: const Text('Marquer SERVI', style: TextStyle(fontSize: 14)),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  /// Widget helper pour afficher les informations d'un shop
  Widget _buildShopInfo({
    required String title,
    required String shopName,
    required bool isCurrentShop,
    required IconData icon,
    required Color iconColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      shopName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  if (isCurrentShop)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF9C27B0).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF9C27B0).withOpacity(0.3)),
                      ),
                      child: const Text(
                        'Vous',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9C27B0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Widget helper pour afficher les dates
  Widget _buildDateInfo({
    required IconData icon,
    required String label,
    required DateTime date,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              _formatDate(date),
              style: const TextStyle(
                fontSize: 11,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _marquerServi(flot_model.FlotModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final agentId = authService.currentUser?.id;
    final agentUsername = authService.currentUser?.username;

    if (agentId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la réception'),
        content: Text(
          'Confirmez-vous avoir reçu ${flot.montant.toStringAsFixed(2)} ${flot.devise} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final success = await FlotService.instance.marquerFlotServi(
        flotId: flot.id!,
        agentRecepteurId: agentId,
        agentRecepteurUsername: agentUsername,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Flot marqué comme servi'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _afficherDialogueNouveauFlot() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Utilisateur non authentifié')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FlotDialog(currentShopId: shopId),
    );

    if (result == true && mounted) {
      await _chargerFlots();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Flot créé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Add this new method for editing a flot
  Future<void> _afficherDialogueModifierFlot(flot_model.FlotModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Utilisateur non authentifié')),
      );
      return;
    }

    // Vérifier que l'utilisateur peut modifier ce flot
    if (flot.shopSourceId != shopId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Vous ne pouvez modifier que vos propres flots')),
      );
      return;
    }

    if (flot.statut != flot_model.StatutFlot.enRoute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Seuls les flots en cours peuvent être modifiés')),
      );
      return;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => FlotDialog(flot: flot, currentShopId: shopId),
    );

    if (result == true && mounted) {
      await _chargerFlots();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Flot mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Add this new method for deleting a flot
  Future<void> _supprimerFlot(flot_model.FlotModel flot) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    
    if (shopId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Utilisateur non authentifié')),
      );
      return;
    }

    // Vérifier que l'utilisateur peut supprimer ce flot
    if (flot.shopSourceId != shopId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Vous ne pouvez supprimer que vos propres flots')),
      );
      return;
    }

    if (flot.statut != flot_model.StatutFlot.enRoute) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Seuls les flots en cours peuvent être supprimés')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text(
          'Êtes-vous sûr de vouloir supprimer le flot de ${flot.montant.toStringAsFixed(2)} ${flot.devise} vers ${flot.shopDestinationDesignation} ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await LocalDB.instance.deleteFlot(flot.id!); // This should work now
        await _chargerFlots();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Flot supprimé avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erreur lors de la suppression: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}