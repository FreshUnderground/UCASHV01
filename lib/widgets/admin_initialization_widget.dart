import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/client_model.dart';
import '../models/shop_model.dart';
import '../models/sim_model.dart';
import '../models/virtual_transaction_model.dart';
import '../models/operation_model.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../services/shop_service.dart';
import '../services/sim_service.dart';
import '../services/local_db.dart';
import '../services/triangular_debt_settlement_service.dart';
import '../utils/responsive_utils.dart';

/// Widget d'initialisation pour l'admin
/// Permet d'initialiser:
/// 1. Soldes virtuels (SIMs)
/// 2. Comptes clients
/// 3. Crédits intershops (dettes/créances entre shops)
class AdminInitializationWidget extends StatefulWidget {
  const AdminInitializationWidget({super.key});

  @override
  State<AdminInitializationWidget> createState() => _AdminInitializationWidgetState();
}

class _AdminInitializationWidgetState extends State<AdminInitializationWidget> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this); // Changed from 3 to 4
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;
    
    return Container(
      color: Colors.grey[100],
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.settings_suggest,
                        color: Color(0xFFDC2626),
                        size: 28,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Initialisation Système',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFDC2626),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Initialiser les soldes virtuels, comptes clients et crédits intershops',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '⚠️ Les opérations d\'initialisation sont marquées comme ADMINISTRATIVES et n\'impactent PAS le cash disponible',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 13,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFFDC2626),
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFFDC2626),
                  isScrollable: isMobile,
                  tabs: const [
                    Tab(text: '📱 Soldes Virtuels'),
                    Tab(text: '👥 Comptes Clients'),
                    Tab(text: '🏪 Crédits Intershops'),
                    Tab(text: '🔺 Regul.'), // Règlement Triangulaire
                  ],
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                _VirtualBalanceInitTab(),
                _ClientAccountInitTab(),
                _IntershopCreditInitTab(),
                _TriangularDebtSettlementTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Onglet 1: Initialisation des soldes virtuels (SIMs)
class _VirtualBalanceInitTab extends StatefulWidget {
  const _VirtualBalanceInitTab();

  @override
  State<_VirtualBalanceInitTab> createState() => _VirtualBalanceInitTabState();
}

class _VirtualBalanceInitTabState extends State<_VirtualBalanceInitTab> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();
  
  SimModel? _selectedSim;
  String _devise = 'USD';
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              icon: Icons.info,
              color: Colors.blue,
              title: 'Initialisation de Solde Virtuel',
              description: 'Cette opération créera une transaction virtuelle d\'initialisation pour ajuster le solde virtuel d\'une SIM sans impact sur le cash disponible.',
            ),
            const SizedBox(height: 24),
            
            // Sélection de la SIM
            Consumer<SimService>(
              builder: (context, simService, child) {
                return DropdownButtonFormField<SimModel>(
                  value: _selectedSim,
                  decoration: InputDecoration(
                    labelText: 'Sélectionner la SIM *',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.sim_card),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: simService.sims.map((sim) {
                    return DropdownMenuItem(
                      value: sim,
                      child: Text('${sim.numero} - ${sim.operateur} (${sim.shopDesignation ?? "N/A"})')  ,
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedSim = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Veuillez sélectionner une SIM';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Montant
            TextFormField(
              controller: _montantController,
              decoration: const InputDecoration(
                labelText: 'Montant initial *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                filled: true,
                fillColor: Colors.white,
                helperText: 'Positif pour ajouter au solde, négatif pour déduire',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le montant est requis';
                }
                final montant = double.tryParse(value);
                if (montant == null || montant == 0) {
                  return 'Veuillez saisir un montant valide (≠ 0)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Devise
            DropdownButtonFormField<String>(
              value: _devise,
              decoration: const InputDecoration(
                labelText: 'Devise',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.currency_exchange),
                filled: true,
                fillColor: Colors.white,
              ),
              items: const [
                DropdownMenuItem(value: 'USD', child: Text('USD')),
                DropdownMenuItem(value: 'CDF', child: Text('CDF')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _devise = value;
                  });
                }
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
                filled: true,
                fillColor: Colors.white,
                hintText: 'Initialisation solde virtuel...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Bouton d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleVirtualBalanceInit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
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
                label: Text(_isLoading ? 'Initialisation...' : 'Initialiser Solde Virtuel'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleVirtualBalanceInit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      final montant = double.parse(_montantController.text.trim());
      final notes = _notesController.text.trim().isEmpty 
          ? 'Initialisation solde virtuel - Opération administrative'
          : _notesController.text.trim();

      // Créer une transaction virtuelle d'initialisation
      final transaction = VirtualTransactionModel(
        reference: 'INIT-VIRT-${DateTime.now().millisecondsSinceEpoch}',
        montantVirtuel: montant.abs(),
        frais: 0.0,
        montantCash: 0.0,
        devise: _devise,
        simNumero: _selectedSim!.numero,
        shopId: _selectedSim!.shopId,
        shopDesignation: _selectedSim!.shopDesignation,
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        statut: VirtualTransactionStatus.validee,
        dateEnregistrement: DateTime.now(),
        dateValidation: DateTime.now(),
        notes: notes,
        isAdministrative: true,  // Marqué comme administrative
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: currentUser.username,
      );

      await LocalDB.instance.saveVirtualTransaction(transaction);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Solde virtuel initialisé avec succès !',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text('📱 SIM: ${_selectedSim!.numero}'),
                Text('💰 Montant: ${montant.toStringAsFixed(2)} $_devise'),
                const Text('⚠️ Opération administrative - sans impact cash'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Réinitialiser le formulaire
        _montantController.clear();
        _notesController.clear();
        setState(() {
          _selectedSim = null;
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
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
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
}

/// Onglet 2: Initialisation des comptes clients
class _ClientAccountInitTab extends StatefulWidget {
  const _ClientAccountInitTab();

  @override
  State<_ClientAccountInitTab> createState() => _ClientAccountInitTabState();
}

class _ClientAccountInitTabState extends State<_ClientAccountInitTab> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _observationController = TextEditingController();
  
  ClientModel? _selectedClient;
  ShopModel? _selectedShop;
  ModePaiement _modePaiement = ModePaiement.cash;
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              icon: Icons.info,
              color: Colors.blue,
              title: 'Initialisation de Compte Client',
              description: 'Cette opération créera un solde initial pour un client SANS impacter votre cash disponible. '
                  'Montant POSITIF = Nous leur devons (crédit), Montant NÉGATIF = Ils nous doivent (dette).',
            ),
            const SizedBox(height: 24),
            
            // Sélection du client
            Consumer<ClientService>(
              builder: (context, clientService, child) {
                return DropdownButtonFormField<ClientModel>(
                  value: _selectedClient,
                  decoration: const InputDecoration(
                    labelText: 'Sélectionner le client *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: clientService.clients.map((client) {
                    return DropdownMenuItem(
                      value: client,
                      child: Text('${client.nom} - ${client.telephone}'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedClient = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Veuillez sélectionner un client';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Sélection du shop
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<ShopModel>(
                  value: _selectedShop,
                  decoration: const InputDecoration(
                    labelText: 'Shop *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: shopService.shops.map((shop) {
                    return DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedShop = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Veuillez sélectionner un shop';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Montant
            TextFormField(
              controller: _montantController,
              decoration: const InputDecoration(
                labelText: 'Montant initial *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'USD',
                filled: true,
                fillColor: Colors.white,
                helperText: 'Positif pour crédit client, négatif pour dette client',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le montant est requis';
                }
                final montant = double.tryParse(value);
                if (montant == null || montant == 0) {
                  return 'Veuillez saisir un montant valide (≠ 0)';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Mode de paiement
            DropdownButtonFormField<ModePaiement>(
              value: _modePaiement,
              decoration: const InputDecoration(
                labelText: 'Mode de paiement',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment),
                filled: true,
                fillColor: Colors.white,
              ),
              items: ModePaiement.values.map((mode) {
                return DropdownMenuItem(
                  value: mode,
                  child: Text(_getModePaiementLabel(mode)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _modePaiement = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),
            
            // Observation
            TextFormField(
              controller: _observationController,
              decoration: const InputDecoration(
                labelText: 'Observation',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Solde d\'ouverture de compte...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            
            // Bouton d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleClientAccountInit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
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
                label: Text(_isLoading ? 'Initialisation...' : 'Initialiser Compte Client'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getModePaiementLabel(ModePaiement mode) {
    switch (mode) {
      case ModePaiement.cash:
        return 'Cash';
      case ModePaiement.airtelMoney:
        return 'Airtel Money';
      case ModePaiement.mPesa:
        return 'MPESA/VODACASH';
      case ModePaiement.orangeMoney:
        return 'Orange Money';
    }
  }

  Future<void> _handleClientAccountInit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final clientService = Provider.of<ClientService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser?.id == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (_selectedClient == null || _selectedShop == null) {
        throw Exception('Veuillez sélectionner un client et un shop');
      }

      final montant = double.parse(_montantController.text.trim());
      final observation = _observationController.text.trim().isEmpty 
          ? 'Initialisation solde client - Opération administrative'
          : _observationController.text.trim();

      final success = await clientService.initialiserSoldeClient(
        clientId: _selectedClient!.id!,
        montantInitial: montant,
        shopId: _selectedShop!.id!,
        agentId: currentUser!.id!,
        observation: observation,
        modePaiement: _modePaiement,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Compte client initialisé avec succès !',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text('👤 Client: ${_selectedClient!.nom}'),
                Text('🏪 Shop: ${_selectedShop!.designation}'),
                Text('💰 Montant: ${montant.toStringAsFixed(2)} USD'),
                const Text('⚠️ Opération administrative - sans impact cash'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Réinitialiser le formulaire
        _montantController.clear();
        _observationController.clear();
        setState(() {
          _selectedClient = null;
          _selectedShop = null;
        });
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${clientService.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
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
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
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
}

/// Onglet 3: Initialisation des crédits intershops
class _IntershopCreditInitTab extends StatefulWidget {
  const _IntershopCreditInitTab();

  @override
  State<_IntershopCreditInitTab> createState() => _IntershopCreditInitTabState();
}

class _IntershopCreditInitTabState extends State<_IntershopCreditInitTab> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _observationController = TextEditingController();
  
  ShopModel? _shopSource;
  ShopModel? _shopDestination;
  String _typeMouvement = 'creance'; // 'creance' ou 'dette'
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _observationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              icon: Icons.info,
              color: Colors.blue,
              title: 'Initialisation de Crédit Intershop',
              description: 'Cette opération ajustera les dettes/créances entre deux shops. '
                  'Utilisez CRÉANCE si le shop source doit recevoir de l\'argent, DETTE s\'il doit payer.',
            ),
            const SizedBox(height: 24),
            
            // Type de mouvement
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
                    'Type de mouvement',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Créance'),
                          subtitle: const Text('Shop source a une créance'),
                          value: 'creance',
                          groupValue: _typeMouvement,
                          onChanged: (value) {
                            setState(() {
                              _typeMouvement = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Dette'),
                          subtitle: const Text('Shop source a une dette'),
                          value: 'dette',
                          groupValue: _typeMouvement,
                          onChanged: (value) {
                            setState(() {
                              _typeMouvement = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            // Shop source
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<ShopModel>(
                  value: _shopSource,
                  decoration: const InputDecoration(
                    labelText: 'Shop Source *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: shopService.shops.map((shop) {
                    return DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _shopSource = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Veuillez sélectionner le shop source';
                    if (value == _shopDestination) return 'Les deux shops doivent être différents';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Shop destination
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<ShopModel>(
                  value: _shopDestination,
                  decoration: const InputDecoration(
                    labelText: 'Shop Destination *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store_mall_directory),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: shopService.shops.map((shop) {
                    return DropdownMenuItem(
                      value: shop,
                      child: Text('${shop.designation} (#${shop.id})'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _shopDestination = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) return 'Veuillez sélectionner le shop destination';
                    if (value == _shopSource) return 'Les deux shops doivent être différents';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            
            // Montant
            TextFormField(
              controller: _montantController,
              decoration: const InputDecoration(
                labelText: 'Montant *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                suffixText: 'USD',
                filled: true,
                fillColor: Colors.white,
                helperText: 'Montant de la créance ou de la dette',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le montant est requis';
                }
                final montant = double.tryParse(value);
                if (montant == null || montant <= 0) {
                  return 'Veuillez saisir un montant positif';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Observation
            TextFormField(
              controller: _observationController,
              decoration: const InputDecoration(
                labelText: 'Observation',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.note),
                filled: true,
                fillColor: Colors.white,
                hintText: 'Initialisation crédit intershop...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Résumé de l'opération
            if (_shopSource != null && _shopDestination != null && _montantController.text.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Résumé de l\'opération',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (_typeMouvement == 'creance')
                      Text(
                        '✅ ${_shopSource!.designation} aura une créance de ${_montantController.text} USD sur ${_shopDestination!.designation}',
                        style: const TextStyle(fontSize: 13),
                      )
                    else
                      Text(
                        '❌ ${_shopSource!.designation} aura une dette de ${_montantController.text} USD envers ${_shopDestination!.designation}',
                        style: const TextStyle(fontSize: 13),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            
            // Bouton d'action
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleIntershopCreditInit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
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
                label: Text(_isLoading ? 'Initialisation...' : 'Initialiser Crédit Intershop'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleIntershopCreditInit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final shopService = Provider.of<ShopService>(context, listen: false);
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('Utilisateur non connecté');
      }

      if (_shopSource == null || _shopDestination == null) {
        throw Exception('Veuillez sélectionner les deux shops');
      }

      final montant = double.parse(_montantController.text.trim());

      // Mettre à jour les shops selon le type de mouvement
      if (_typeMouvement == 'creance') {
        // Shop source a une créance -> augmenter ses créances et les dettes du destination
        final updatedSource = _shopSource!.copyWith(
          creances: _shopSource!.creances + montant,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'admin_init_intershop',
        );
        final updatedDestination = _shopDestination!.copyWith(
          dettes: _shopDestination!.dettes + montant,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'admin_init_intershop',
        );

        await LocalDB.instance.saveShop(updatedSource);
        await LocalDB.instance.saveShop(updatedDestination);
        
        await shopService.loadShops();
      } else {
        // Shop source a une dette -> augmenter ses dettes et les créances du destination
        final updatedSource = _shopSource!.copyWith(
          dettes: _shopSource!.dettes + montant,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'admin_init_intershop',
        );
        final updatedDestination = _shopDestination!.copyWith(
          creances: _shopDestination!.creances + montant,
          lastModifiedAt: DateTime.now(),
          lastModifiedBy: 'admin_init_intershop',
        );

        await LocalDB.instance.saveShop(updatedSource);
        await LocalDB.instance.saveShop(updatedDestination);
        
        await shopService.loadShops();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '✅ Crédit intershop initialisé avec succès !',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text('🏪 ${_shopSource!.designation} → ${_shopDestination!.designation}'),
                Text('💰 Montant: ${montant.toStringAsFixed(2)} USD'),
                Text('📋 Type: ${_typeMouvement == 'creance' ? 'Créance' : 'Dette'}'),
                const Text('⚠️ Opération administrative'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );

        // Réinitialiser le formulaire
        _montantController.clear();
        _observationController.clear();
        setState(() {
          _shopSource = null;
          _shopDestination = null;
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
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.black87,
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
}

/// Onglet 4: Initialisation de règlement triangulaire de dettes
/// Scénario: Shop A doit à Shop C, mais Shop B reçoit le paiement pour le compte de Shop C
class _TriangularDebtSettlementTab extends StatefulWidget {
  const _TriangularDebtSettlementTab();

  @override
  State<_TriangularDebtSettlementTab> createState() => _TriangularDebtSettlementTabState();
}

class _TriangularDebtSettlementTabState extends State<_TriangularDebtSettlementTab> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();
  
  ShopModel? _shopDebtor;      // Shop A (qui doit l'argent)
  ShopModel? _shopIntermediary; // Shop B (qui reçoit le paiement)
  ShopModel? _shopCreditor;     // Shop C (à qui l'argent est dû)
  bool _isLoading = false;

  @override
  void dispose() {
    _montantController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = context.isSmallScreen;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(
              icon: Icons.info,
              color: Colors.blue,
              title: 'Règlement Triangulaire de Dettes',
              description: 'Shop A doit à Shop C, mais Shop B reçoit le paiement pour le compte de Shop C. '
                  'Dette de A envers C diminue, Dette de B envers C augmente.',
            ),
            const SizedBox(height: 24),
            
            // Example box and shop dropdowns... (shortened for brevity)
            // Shop A - Débiteur
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<ShopModel>(
                  value: _shopDebtor,
                  decoration: const InputDecoration(
                    labelText: 'Shop A - Débiteur (qui doit l\'argent) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store, color: Colors.red),
                  ),
                  items: shopService.shops.map((shop) {
                    return DropdownMenuItem(value: shop, child: Text('${shop.designation} (#${shop.id})'));
                  }).toList(),
                  onChanged: (value) => setState(() => _shopDebtor = value),
                  validator: (value) {
                    if (value == null) return 'Sélectionnez le shop débiteur';
                    if (value == _shopIntermediary || value == _shopCreditor) return 'Shops doivent être différents';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // Shop B - Intermédiaire
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<ShopModel>(
                  value: _shopIntermediary,
                  decoration: const InputDecoration(
                    labelText: 'Shop B - Intermédiaire (qui reçoit le paiement) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store, color: Colors.green),
                  ),
                  items: shopService.shops.map((shop) {
                    return DropdownMenuItem(value: shop, child: Text('${shop.designation} (#${shop.id})'));
                  }).toList(),
                  onChanged: (value) => setState(() => _shopIntermediary = value),
                  validator: (value) {
                    if (value == null) return 'Sélectionnez le shop intermédiaire';
                    if (value == _shopDebtor || value == _shopCreditor) return 'Shops doivent être différents';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // Shop C - Créditeur
            Consumer<ShopService>(
              builder: (context, shopService, child) {
                return DropdownButtonFormField<ShopModel>(
                  value: _shopCreditor,
                  decoration: const InputDecoration(
                    labelText: 'Shop C - Créditeur (à qui l\'argent est dû) *',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.store, color: Colors.blue),
                  ),
                  items: shopService.shops.map((shop) {
                    return DropdownMenuItem(value: shop, child: Text('${shop.designation} (#${shop.id})'));
                  }).toList(),
                  onChanged: (value) => setState(() => _shopCreditor = value),
                  validator: (value) {
                    if (value == null) return 'Sélectionnez le shop créditeur';
                    if (value == _shopDebtor || value == _shopIntermediary) return 'Shops doivent être différents';
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _montantController,
              decoration: const InputDecoration(
                labelText: 'Montant *',
                border: OutlineInputBorder(),
                suffixText: 'USD',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Montant requis';
                if (double.tryParse(value) == null || double.parse(value) <= 0) return 'Montant positif requis';
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _handleTriangularSettlement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_circle),
                label: Text(_isLoading ? 'Traitement...' : 'Créer Règlement Triangulaire'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleTriangularSettlement() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;
      if (currentUser == null) throw Exception('Utilisateur non connecté');

      final montant = double.parse(_montantController.text.trim());
      final settlement = await TriangularDebtSettlementService.instance.createTriangularSettlement(
        shopDebtorId: _shopDebtor!.id!,
        shopIntermediaryId: _shopIntermediary!.id!,
        shopCreditorId: _shopCreditor!.id!,
        montant: montant,
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Règlement triangulaire créé: ${settlement.reference}'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
        _formKey.currentState!.reset();
        _montantController.clear();
        _notesController.clear();
        setState(() {
          _shopDebtor = null;
          _shopIntermediary = null;
          _shopCreditor = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildInfoCard({required IconData icon, required Color color, required String title, required String description}) {
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
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                const SizedBox(height: 4),
                Text(description, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
