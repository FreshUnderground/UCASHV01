import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/agent_model.dart';
import '../models/shop_model.dart';
import '../services/agent_auth_service.dart';
import '../services/shop_service.dart';
import '../services/triangular_debt_settlement_service.dart';
import '../utils/responsive_utils.dart';

/// Widget pour permettre aux agents de créer des règlements triangulaires
/// RESTRICTION: L'agent peut créer des règlements UNIQUEMENT pour son propre shop
///
/// Scénarios autorisés pour un agent du Shop A:
/// 1. Shop A (son shop) doit à Shop C, Shop B reçoit le paiement
/// 2. Shop A (son shop) reçoit le paiement pour Shop C (mais Shop B doit à Shop C)
///
/// Le shop de l'agent DOIT toujours être impliqué (débiteur OU intermédiaire)
class AgentTriangularDebtSettlementWidget extends StatefulWidget {
  const AgentTriangularDebtSettlementWidget({super.key});

  @override
  State<AgentTriangularDebtSettlementWidget> createState() =>
      _AgentTriangularDebtSettlementWidgetState();
}

class _AgentTriangularDebtSettlementWidgetState
    extends State<AgentTriangularDebtSettlementWidget> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();

  String _settlementType = 'debtor'; // 'debtor' ou 'intermediary'
  ShopModel? _otherShopA; // L'autre shop impliqué dans la dette
  ShopModel? _shopCreditor; // Shop créancier (toujours Shop C)
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _montantController.clear();
    _notesController.clear();
    setState(() {
      _otherShopA = null;
      _shopCreditor = null;
      _settlementType = 'debtor'; // Reset to default
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Formulaire réinitialisé'),
          backgroundColor: Colors.purple,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;
    final agentAuthService =
        Provider.of<AgentAuthService>(context, listen: false);
    final currentAgent = agentAuthService.currentAgent;
    final agentShopId = currentAgent?.shopId;

    // Logs de débogage pour diagnostiquer le problème
    debugPrint('🔧 [Triangular Widget] Build appelé');
    debugPrint('   currentAgent: ${currentAgent?.username ?? "null"}');
    debugPrint('   currentAgent.id: ${currentAgent?.id}');
    debugPrint('   currentAgent.shopId: ${currentAgent?.shopId}');
    debugPrint('   agentShopId: $agentShopId');

    if (agentShopId == null) {
      debugPrint(
          '⚠️ [Triangular Widget] agentShopId est null - affichage message d\'erreur');
      return Scaffold(
        appBar: AppBar(
          title: const Text('Règlement Triangulaire'),
          backgroundColor: Colors.purple,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.store_outlined,
                    size: 80,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Shop Non Assigné',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Text(
                  'Votre compte agent n\'est pas encore assigné à un shop.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[700],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Pour accéder à la fonctionnalité de règlement triangulaire, '
                  'vous devez être assigné à un shop par un administrateur.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Que faire ?',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue[900],
                                fontSize: 15,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildStepItem('1', 'Contactez votre administrateur'),
                      const SizedBox(height: 8),
                      _buildStepItem('2', 'Demandez l\'assignation à un shop'),
                      const SizedBox(height: 8),
                      _buildStepItem(
                          '3', 'Reconnectez-vous après l\'assignation'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Retour'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Déconnecter et revenir à l'écran de login
                        final authService = Provider.of<AgentAuthService>(
                            context,
                            listen: false);
                        authService.logout();
                        Navigator.of(context).pushReplacementNamed('/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text('Se déconnecter'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Consumer<ShopService>(
      builder: (context, shopService, child) {
        // Vérifier si les shops sont en cours de chargement
        if (shopService.isLoading) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Chargement des shops...'),
                ],
              ),
            ),
          );
        }

        // Vérifier si la liste des shops est vide
        if (shopService.shops.isEmpty) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning, size: 64, color: Colors.orange),
                  const SizedBox(height: 16),
                  const Text('Aucun shop disponible'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () async {
                      await shopService.loadShops();
                    },
                    child: const Text('Recharger'),
                  ),
                ],
              ),
            ),
          );
        }

        final agentShop = shopService.shops.firstWhere(
          (s) => s.id == agentShopId,
          orElse: () => ShopModel(
            designation: 'Shop inconnu',
            localisation: '',
            capitalInitial: 0,
          ),
        );

        return Scaffold(
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isMobile ? 16 : 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header avec info du shop de l'agent
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.purple.withOpacity(0.1),
                          Colors.blue.withOpacity(0.1)
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.purple.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.purple.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.store,
                              color: Colors.purple, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Votre Shop',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                agentShop.designation,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Info card
                  _buildInfoCard(
                    icon: Icons.info,
                    color: Colors.blue,
                    title: 'Règlement Triangulaire',
                    description:
                        'Créez un règlement triangulaire impliquant votre shop. '
                        'Votre shop doit être soit le débiteur qui paie, soit l\'intermédiaire qui reçoit le paiement.',
                  ),
                  const SizedBox(height: 24),

                  // Type de règlement
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Rôle de votre shop dans ce règlement',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RadioListTile<String>(
                          title:
                              Text('${agentShop.designation} PAIE (débiteur)'),
                          subtitle: const Text(
                              'Votre shop doit de l\'argent et paie via un autre shop'),
                          value: 'debtor',
                          groupValue: _settlementType,
                          onChanged: (value) {
                            setState(() {
                              _settlementType = value!;
                              _otherShopA = null;
                              _shopCreditor = null;
                            });
                          },
                        ),
                        RadioListTile<String>(
                          title: Text(
                              '${agentShop.designation} REÇOIT (intermédiaire)'),
                          subtitle: const Text(
                              'Votre shop reçoit un paiement pour le compte d\'un créancier'),
                          value: 'intermediary',
                          groupValue: _settlementType,
                          onChanged: (value) {
                            setState(() {
                              _settlementType = value!;
                              _otherShopA = null;
                              _shopCreditor = null;
                            });
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Impact sur les dettes
                  _buildImpactSummary(agentShop, agentShopId),
                  const SizedBox(height: 24),

                  // Formulaire dynamique
                  _buildDynamicForm(agentShop, shopService),
                  const SizedBox(height: 24),

                  // Bouton de soumission
                  _buildSubmitButton(agentShopId, currentAgent),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh),
            label: const Text('Nouveau'),
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
          ),
        );
      },
    );
  }

  Widget _buildImpactSummary(ShopModel agentShop, int agentShopId) {
    final montant = _montantController.text;

    // Vérifier si les shops requis sont sélectionnés
    if (_otherShopA == null || _shopCreditor == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Sélectionnez les shops pour voir l\'impact du règlement',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    // Déterminer les 3 shops selon le type
    final ShopModel shopA, shopB, shopC;
    if (_settlementType == 'debtor') {
      shopA = agentShop;
      shopB = _otherShopA!;
      shopC = _shopCreditor!;
    } else {
      shopA = _otherShopA!;
      shopB = agentShop;
      shopC = _shopCreditor!;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.purple.withOpacity(0.1),
            Colors.blue.withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.timeline, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text(
                'Impacts du règlement',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildImpactRow(
            Icons.arrow_downward,
            Colors.green,
            'Dette de ${shopA.designation} envers ${shopC.designation}: diminue de $montant USD',
            isAgentShop: shopA.id == agentShopId,
          ),
          const SizedBox(height: 8),
          _buildImpactRow(
            Icons.arrow_upward,
            Colors.red,
            'Dette de ${shopB.designation} envers ${shopC.designation}: augmente de $montant USD',
            isAgentShop: shopB.id == agentShopId,
          ),
          const SizedBox(height: 8),
          _buildImpactRow(
            Icons.info_outline,
            Colors.blue,
            'Créances de ${shopC.designation}: inchangées',
            isAgentShop: false,
          ),
        ],
      ),
    );
  }

  Widget _buildImpactRow(IconData icon, Color color, String text,
      {required bool isAgentShop}) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 13, color: color),
              children: [
                TextSpan(text: text),
                if (isAgentShop)
                  const TextSpan(
                    text: ' (VOTRE SHOP)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDynamicForm(ShopModel agentShop, ShopService shopService) {
    return Column(
      children: [
        if (_settlementType == 'debtor') ...[
          // Scénario: Mon shop (A) doit à C, je paie via B
          Text(
            'Scénario: ${agentShop.designation} doit de l\'argent et paie via un intermédiaire',
            style: TextStyle(
              fontSize: context.isSmallScreen ? 14 : 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ShopModel>(
            value: _otherShopA,
            decoration: const InputDecoration(
              labelText: 'Shop Intermédiaire (qui reçoit le paiement) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.storefront, color: Colors.orange),
              helperText: 'Shop qui reçoit votre paiement',
            ),
            items: shopService.shops
                .where((s) => s.id != agentShop.id)
                .map((shop) => DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _otherShopA = value),
            validator: (value) {
              if (value == null) return 'Sélectionnez le shop intermédiaire';
              if (value == _shopCreditor)
                return 'L\'intermédiaire et le créancier doivent être différents';
              return null;
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ShopModel>(
            value: _shopCreditor,
            decoration: const InputDecoration(
              labelText: 'Shop Créancier (à qui vous devez) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance, color: Colors.green),
              helperText: 'Shop à qui votre dette est due',
            ),
            items: shopService.shops
                .where((s) => s.id != agentShop.id && s != _otherShopA)
                .map((shop) => DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _shopCreditor = value),
            validator: (value) {
              if (value == null) return 'Sélectionnez le shop créancier';
              return null;
            },
          ),
        ] else ...[
          // Scénario: Mon shop (B) reçoit pour le compte de C (A doit à C)
          Text(
            'Scénario: ${agentShop.designation} reçoit un paiement pour le compte d\'un créancier',
            style: TextStyle(
              fontSize: context.isSmallScreen ? 14 : 15,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ShopModel>(
            value: _otherShopA,
            decoration: const InputDecoration(
              labelText: 'Shop Débiteur (qui paie) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.store, color: Colors.red),
              helperText: 'Shop qui effectue le paiement chez vous',
            ),
            items: shopService.shops
                .where((s) => s.id != agentShop.id)
                .map((shop) => DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _otherShopA = value),
            validator: (value) {
              if (value == null) return 'Sélectionnez le shop débiteur';
              if (value == _shopCreditor)
                return 'Le débiteur et le créancier doivent être différents';
              return null;
            },
          ),
          const SizedBox(height: 16),

          DropdownButtonFormField<ShopModel>(
            value: _shopCreditor,
            decoration: const InputDecoration(
              labelText: 'Shop Créancier (pour qui vous recevez) *',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.account_balance, color: Colors.green),
              helperText: 'Shop pour le compte duquel vous recevez',
            ),
            items: shopService.shops
                .where((s) => s.id != agentShop.id && s != _otherShopA)
                .map((shop) => DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _shopCreditor = value),
            validator: (value) {
              if (value == null) return 'Sélectionnez le shop créancier';
              return null;
            },
          ),
        ],

        const SizedBox(height: 16),

        // Montant
        TextFormField(
          controller: _montantController,
          decoration: const InputDecoration(
            labelText: 'Montant *',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.attach_money),
            suffixText: 'USD',
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Montant requis';
            if (double.tryParse(value) == null || double.parse(value) <= 0) {
              return 'Montant positif requis';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Notes
        TextFormField(
          controller: _notesController,
          decoration: const InputDecoration(
            labelText: 'Notes / Observation',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.note),
            hintText: 'Détails du règlement...',
          ),
          maxLines: 3,
        ),
      ],
    );
  }

  Widget _buildSubmitButton(int agentShopId, AgentModel? currentAgent) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: _isLoading
            ? null
            : () => _handleCreateSettlement(agentShopId, currentAgent!.id!),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.check_circle),
        label:
            Text(_isLoading ? 'Création...' : 'Créer Règlement Triangulaire'),
      ),
    );
  }

  Future<void> _handleCreateSettlement(int agentShopId, int agentId) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final agentAuthService =
          Provider.of<AgentAuthService>(context, listen: false);
      final currentAgent = agentAuthService.currentAgent;

      if (currentAgent == null) {
        throw Exception('Agent non connecté');
      }

      final montant = double.parse(_montantController.text.trim());

      // Déterminer les IDs selon le type de règlement
      final int shopDebtorId, shopIntermediaryId, shopCreditorId;

      if (_settlementType == 'debtor') {
        // Mon shop (A) doit à C, je paie via B
        shopDebtorId = agentShopId;
        shopIntermediaryId = _otherShopA!.id!;
        shopCreditorId = _shopCreditor!.id!;
      } else {
        // Mon shop (B) reçoit pour C (A doit à C)
        shopDebtorId = _otherShopA!.id!;
        shopIntermediaryId = agentShopId;
        shopCreditorId = _shopCreditor!.id!;
      }

      // Créer le règlement
      final settlement = await TriangularDebtSettlementService.instance
          .createTriangularSettlement(
        shopDebtorId: shopDebtorId,
        shopIntermediaryId: shopIntermediaryId,
        shopCreditorId: shopCreditorId,
        montant: montant,
        agentId: currentAgent.id!,
        agentUsername: currentAgent.username,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '✅ Règlement triangulaire créé: ${settlement.reference}\n'
              'Les dettes ont été mises à jour.',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );

        // Réinitialiser le formulaire
        _formKey.currentState!.reset();
        _montantController.clear();
        _notesController.clear();
        setState(() {
          _otherShopA = null;
          _shopCreditor = null;
        });
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

  Widget _buildInfoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepItem(String number, String text) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.blue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
