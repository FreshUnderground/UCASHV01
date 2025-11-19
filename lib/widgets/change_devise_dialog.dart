import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/rates_service.dart';
import '../services/transaction_service.dart';
import '../services/local_db.dart';
import '../services/sync_service.dart';
import '../models/shop_model.dart';
import '../models/taux_model.dart';

class ChangeDeviseDialog extends StatefulWidget {
  const ChangeDeviseDialog({super.key});

  @override
  State<ChangeDeviseDialog> createState() => _ChangeDeviseDialogState();
}

class _ChangeDeviseDialogState extends State<ChangeDeviseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _tauxController = TextEditingController();
  
  bool _isLoading = false;
  String _sens = 'USD_TO_LOCAL'; // USD_TO_LOCAL ou LOCAL_TO_USD
  String _deviseLocale = 'CDF'; // CDF ou UGX
  double _montant = 0.0;
  double _montantConverti = 0.0;
  double _taux = 0.0;
  bool _tauxManuel = false; // Si true, l'utilisateur saisit le taux manuellement
  TauxModel? _tauxModel;
  ShopModel? _shop;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShopAndRates();
    });
  }

  Future<void> _loadShopAndRates() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopService = Provider.of<ShopService>(context, listen: false);
    // Utiliser RatesService.instance au lieu du Provider
    final ratesService = RatesService.instance;
    
    debugPrint('\n🔄 ===== CHARGEMENT CHANGE DEVISES =====');
    
    // Charger le shop
    final currentShopId = authService.currentUser?.shopId;
    if (currentShopId != null) {
      final shop = await shopService.getShopById(currentShopId);
      setState(() {
        _shop = shop;
        // Utiliser la devise secondaire du shop
        if (shop?.deviseSecondaire != null && shop!.deviseSecondaire!.isNotEmpty) {
          _deviseLocale = shop.deviseSecondaire!;
        } else {
          _deviseLocale = 'CDF'; // Par défaut
        }
      });
      debugPrint('🏪 Shop: ${shop?.designation}');
      debugPrint('💱 Devise locale: $_deviseLocale');
    }
    
    // Charger les taux DIRECTEMENT depuis la base de données
    debugPrint('\n📊 Chargement taux depuis LocalDB...');
    final tauxFromDB = await LocalDB.instance.getAllTaux();
    debugPrint('📊 Taux en base: ${tauxFromDB.length}');
    for (var t in tauxFromDB) {
      debugPrint('   DB: ${t.type} | ${t.deviseSource} → ${t.deviseCible} = ${t.taux}');
    }
    
    // Charger les taux via RatesService
    debugPrint('\n📊 Chargement via RatesService...');
    await ratesService.loadRatesAndCommissions();
    debugPrint('📊 Taux dans RatesService: ${ratesService.taux.length}');
    for (var t in ratesService.taux) {
      debugPrint('   Service: ${t.type} | ${t.deviseSource} → ${t.deviseCible} = ${t.taux}');
    }
    
    debugPrint('========================================\n');
    
    _updateTaux();
  }

  void _updateTaux() {
    // Utiliser RatesService.instance au lieu du Provider
    final ratesService = RatesService.instance;
    
    debugPrint('\n========== RECHERCHE TAUX ==========');
    debugPrint('🔍 Devise recherchée: $_deviseLocale');
    debugPrint('🔍 Sens: $_sens');
    debugPrint('📊 Total taux en mémoire: ${ratesService.taux.length}');
    
    // Afficher tous les taux disponibles
    for (var t in ratesService.taux) {
      debugPrint('   - ${t.type}: ${t.deviseSource} → ${t.deviseCible} = ${t.taux}');
    }
    
    // Pour un change, on utilise le taux MOYEN par défaut
    // Si pas disponible, on cherche ACHAT ou VENTE
    TauxModel? tauxModel = ratesService.getTauxByDeviseAndType(_deviseLocale, 'MOYEN');
    debugPrint('🔍 Recherche MOYEN pour $_deviseLocale: ${tauxModel != null ? "Trouvé (${tauxModel.taux})" : "Non trouvé"}');
    
    // Si pas de taux MOYEN, essayer ACHAT pour USD->Local, VENTE pour Local->USD
    if (tauxModel == null) {
      if (_sens == 'USD_TO_LOCAL') {
        // Pour convertir USD en local, on utilise le taux ACHAT (le shop achète la devise locale)
        tauxModel = ratesService.getTauxByDeviseAndType(_deviseLocale, 'ACHAT');
        debugPrint('🔍 Recherche ACHAT pour $_deviseLocale: ${tauxModel != null ? "Trouvé (${tauxModel.taux})" : "Non trouvé"}');
      } else {
        // Pour convertir local en USD, on utilise le taux VENTE (le shop vend la devise locale)
        tauxModel = ratesService.getTauxByDeviseAndType(_deviseLocale, 'VENTE');
        debugPrint('🔍 Recherche VENTE pour $_deviseLocale: ${tauxModel != null ? "Trouvé (${tauxModel.taux})" : "Non trouvé"}');
      }
    }
    
    setState(() {
      _tauxModel = tauxModel;
      _taux = tauxModel?.taux ?? 0.0;
      
      // Si pas de taux configuré, activer la saisie manuelle
      if (_taux == 0.0) {
        _tauxManuel = true;
        debugPrint('⚠️ Mode manuel activé');
      } else {
        _tauxController.text = _taux.toString();
        debugPrint('✅ Taux automatique: $_taux');
      }
    });
    
    if (tauxModel == null || _taux == 0.0) {
      debugPrint('❌ RÉSULTAT: Aucun taux trouvé pour $_deviseLocale');
    } else {
      debugPrint('✅ RÉSULTAT: Taux ${tauxModel.type} sélectionné: 1 USD = $_taux $_deviseLocale');
    }
    debugPrint('====================================\n');
    
    _calculateConversion();
  }

  void _calculateConversion() {
    if (_sens == 'USD_TO_LOCAL') {
      // USD → Monnaie Locale
      _montantConverti = _montant * _taux;
    } else {
      // Monnaie Locale → USD
      _montantConverti = _taux > 0 ? _montant / _taux : 0.0;
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final capitalUSD = _shop?.capitalActuel ?? 0.0;
    final capitalLocal = _shop?.capitalActuelDevise2 ?? 0.0;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.currency_exchange,
                          color: Color(0xFF2196F3),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Change de Devises',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Capital disponible
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Capital Disponible',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2D3748),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCapitalCard(
                              'USD',
                              capitalUSD,
                              const Color(0xFF4CAF50),
                            ),
                            _buildCapitalCard(
                              _deviseLocale,
                              capitalLocal,
                              const Color(0xFF2196F3),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Taux disponibles
                  Consumer<RatesService>(
                    builder: (context, ratesService, child) {
                      final allTaux = ratesService.taux.where((t) => t.deviseCible == _deviseLocale).toList();
                      
                      if (allTaux.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEBEE),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFDC2626)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber, color: Color(0xFFDC2626), size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Aucun taux configuré',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Allez dans "Taux de Change" pour créer un taux pour $_deviseLocale',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFFDC2626),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  await ratesService.loadRatesAndCommissions();
                                  _updateTaux();
                                },
                                icon: const Icon(Icons.refresh, color: Color(0xFFDC2626)),
                                tooltip: 'Recharger les taux',
                              ),
                            ],
                          ),
                        );
                      }
                      
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.info_outline, size: 16, color: Color(0xFF2196F3)),
                                const SizedBox(width: 8),
                                const Text(
                                  'Taux disponibles:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  onPressed: () async {
                                    await ratesService.loadRatesAndCommissions();
                                    _updateTaux();
                                  },
                                  icon: const Icon(Icons.refresh, size: 18),
                                  tooltip: 'Recharger les taux',
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...allTaux.map((t) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: t.type == 'MOYEN' 
                                          ? Colors.blue.withOpacity(0.1)
                                          : t.type == 'ACHAT'
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.red.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      t.type,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: t.type == 'MOYEN' 
                                            ? Colors.blue
                                            : t.type == 'ACHAT'
                                                ? Colors.green
                                                : Colors.red,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '1 USD = ${t.taux.toStringAsFixed(2)} $_deviseLocale',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            )).toList(),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Taux du jour
                  if (_tauxModel != null && _taux > 0 && !_tauxManuel)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFF9800)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFFFF9800), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Taux configuré (${_tauxModel!.type}): 1 USD = ${_taux.toStringAsFixed(2)} $_deviseLocale',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFFE65100),
                                  ),
                                ),
                                if (_tauxModel!.type != 'MOYEN') ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    _sens == 'USD_TO_LOCAL'
                                        ? 'Taux ${_tauxModel!.type} utilisé pour ce sens de conversion'
                                        : 'Taux ${_tauxModel!.type} utilisé pour ce sens de conversion',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              setState(() {
                                _tauxManuel = true;
                                _tauxController.text = _taux.toString();
                              });
                            },
                            icon: const Icon(Icons.edit, size: 16),
                            label: const Text('Modifier'),
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFFFF9800),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2196F3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Color(0xFF2196F3), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _tauxModel == null || _taux == 0.0
                                  ? 'Aucun taux configuré - Saisissez le taux actuel'
                                  : 'Taux personnalisé pour ce change',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1976D2),
                              ),
                            ),
                          ),
                          if (_tauxModel != null && _taux > 0)
                            TextButton.icon(
                              onPressed: () {
                                setState(() {
                                  _tauxManuel = false;
                                  _taux = _tauxModel!.taux;
                                  _tauxController.text = _taux.toString();
                                  _calculateConversion();
                                });
                              },
                              icon: const Icon(Icons.undo, size: 16),
                              label: const Text('Rétablir'),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF2196F3),
                              ),
                            ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),

                  // Saisie du taux (si manuel)
                  if (_tauxManuel)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Taux de change',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _tauxController,
                          decoration: InputDecoration(
                            labelText: '1 USD = ? $_deviseLocale',
                            prefixIcon: const Icon(Icons.currency_exchange, color: Color(0xFF2196F3)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            filled: true,
                            fillColor: Colors.grey[50],
                            helperText: 'Exemple: 2500 (1 USD = 2500 $_deviseLocale)',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,4}')),
                          ],
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Veuillez saisir le taux';
                            }
                            final taux = double.tryParse(value);
                            if (taux == null || taux <= 0) {
                              return 'Taux invalide';
                            }
                            return null;
                          },
                          onChanged: (value) {
                            setState(() {
                              _taux = double.tryParse(value) ?? 0.0;
                              _calculateConversion();
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  const SizedBox(height: 20),

                  // Sens de conversion
                  const Text(
                    'Sens de conversion',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: 'USD_TO_LOCAL',
                        label: Text('USD → $_deviseLocale'),
                        icon: const Icon(Icons.arrow_forward, size: 18),
                      ),
                      ButtonSegment(
                        value: 'LOCAL_TO_USD',
                        label: Text('$_deviseLocale → USD'),
                        icon: const Icon(Icons.arrow_back, size: 18),
                      ),
                    ],
                    selected: {_sens},
                    onSelectionChanged: (Set<String> newSelection) {
                      setState(() {
                        _sens = newSelection.first;
                        _montantController.clear();
                        _montant = 0.0;
                        _montantConverti = 0.0;
                        // Recharger le taux approprié pour le nouveau sens
                        _updateTaux();
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Montant à convertir
                  TextFormField(
                    controller: _montantController,
                    decoration: InputDecoration(
                      labelText: _sens == 'USD_TO_LOCAL' 
                          ? 'Montant en USD à convertir' 
                          : 'Montant en $_deviseLocale à convertir',
                      prefixIcon: const Icon(Icons.attach_money, color: Color(0xFF2196F3)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Veuillez saisir un montant';
                      }
                      final montant = double.tryParse(value);
                      if (montant == null || montant <= 0) {
                        return 'Montant invalide';
                      }
                      
                      // Vérifier le capital disponible
                      if (_sens == 'USD_TO_LOCAL') {
                        if (montant > capitalUSD) {
                          return 'Capital USD insuffisant (${capitalUSD.toStringAsFixed(2)} USD disponible)';
                        }
                      } else {
                        if (montant > capitalLocal) {
                          return 'Capital $_deviseLocale insuffisant (${capitalLocal.toStringAsFixed(2)} $_deviseLocale disponible)';
                        }
                      }
                      
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _montant = double.tryParse(value) ?? 0.0;
                        _calculateConversion();
                      });
                    },
                  ),
                  const SizedBox(height: 20),

                  // Résultat de la conversion
                  if (_montant > 0 && _montantConverti > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2196F3).withOpacity(0.1),
                            const Color(0xFF4CAF50).withOpacity(0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF2196F3)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vous donnez:',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
                              Text(
                                _sens == 'USD_TO_LOCAL'
                                    ? '${_montant.toStringAsFixed(2)} USD'
                                    : '${_montant.toStringAsFixed(2)} $_deviseLocale',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFDC2626),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Icon(Icons.swap_vert, color: Color(0xFF2196F3), size: 24),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Vous recevez:',
                                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                              ),
                              Text(
                                _sens == 'USD_TO_LOCAL'
                                    ? '${_montantConverti.toStringAsFixed(2)} $_deviseLocale'
                                    : '${_montantConverti.toStringAsFixed(2)} USD',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4CAF50),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // Boutons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : () => Navigator.pop(context),
                        child: const Text('Annuler'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleSubmit,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.check),
                        label: Text(_isLoading ? 'Traitement...' : 'Confirmer le Change'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2196F3),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapitalCard(String devise, double montant, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            devise,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            montant.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_taux <= 0) {
      _showError('Veuillez saisir un taux de change valide');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final shopService = Provider.of<ShopService>(context, listen: false);
      final transactionService = Provider.of<TransactionService>(context, listen: false);
      
      final currentUser = authService.currentUser;
      if (currentUser?.id == null || currentUser?.shopId == null || _shop == null) {
        _showError('Utilisateur ou shop non trouvé');
        setState(() => _isLoading = false);
        return;
      }

      // 1️⃣ ENREGISTREMENT LOCAL PRIORITAIRE
      debugPrint('\n💾 ===== CHANGE DE DEVISES - LOCAL FIRST =====');
      
      // Mettre à jour les capitaux du shop LOCALEMENT
      double newCapitalUSD = _shop!.capitalActuel;
      double newCapitalLocal = _shop!.capitalActuelDevise2 ?? 0.0;

      if (_sens == 'USD_TO_LOCAL') {
        // USD → Monnaie Locale
        newCapitalUSD -= _montant;
        newCapitalLocal += _montantConverti;
      } else {
        // Monnaie Locale → USD
        newCapitalLocal -= _montant;
        newCapitalUSD += _montantConverti;
      }

      final updatedShop = _shop!.copyWith(
        capitalActuel: newCapitalUSD,
        capitalActuelDevise2: newCapitalLocal,
      );
      
      // Enregistrer le shop LOCALEMENT
      await shopService.updateShop(updatedShop);
      debugPrint('✅ Capital du shop mis à jour localement');
      debugPrint('   USD: ${_shop!.capitalActuel} → $newCapitalUSD');
      debugPrint('   $_deviseLocale: ${_shop!.capitalActuelDevise2} → $newCapitalLocal');

      // Si le taux a été saisi manuellement, l'enregistrer comme taux MOYEN LOCALEMENT
      if (_tauxManuel && (_tauxModel == null || _taux != _tauxModel!.taux)) {
        final ratesService = RatesService.instance;
        try {
          final existingMoyen = ratesService.getTauxByDeviseAndType(_deviseLocale, 'MOYEN');
          
          if (existingMoyen != null) {
            final updatedTaux = existingMoyen.copyWith(taux: _taux, dateEffet: DateTime.now());
            await ratesService.updateTaux(updatedTaux);
            debugPrint('✅ Taux MOYEN mis à jour localement: 1 USD = $_taux $_deviseLocale');
          } else {
            await ratesService.createTaux(
              devise: _deviseLocale,
              taux: _taux,
              type: 'MOYEN',
            );
            debugPrint('✅ Nouveau taux MOYEN créé localement: 1 USD = $_taux $_deviseLocale');
          }
        } catch (e) {
          debugPrint('⚠️ Erreur lors de l\'enregistrement du taux: $e');
        }
      }

      // Enregistrer la transaction de change LOCALEMENT
      final success = await transactionService.createTransaction(
        type: 'CHANGE',
        montant: _montant,
        deviseSource: _sens == 'USD_TO_LOCAL' ? 'USD' : _deviseLocale,
        deviseDestination: _sens == 'USD_TO_LOCAL' ? _deviseLocale : 'USD',
        expediteurId: currentUser!.shopId!,
        destinataireId: currentUser.shopId!,
        nomDestinataire: _shop!.designation,
        agentId: currentUser.id!,
        shopId: currentUser.shopId!,
        notes: 'Change interne: ${_sens == 'USD_TO_LOCAL' ? "USD → $_deviseLocale" : "$_deviseLocale → USD"} au taux de $_taux',
      );

      debugPrint(success ? '✅ Transaction de change enregistrée localement' : '❌ Échec enregistrement transaction');
      debugPrint('==============================================\n');

      if (success) {
        // 2️⃣ SYNCHRONISATION EN ARRIÈRE-PLAN (non bloquante)
        _syncInBackground();
        
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Change effectué avec succès!',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Capital USD: ${newCapitalUSD.toStringAsFixed(2)} | '
                          'Capital $_deviseLocale: ${newCapitalLocal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const Text(
                          'Synchronisation en cours...',
                          style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF4CAF50),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        _showError(transactionService.errorMessage ?? 'Erreur lors du change');
      }
    } catch (e) {
      _showError('Erreur: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _syncInBackground() {
    // Synchronisation asynchrone en arrière-plan
    Future.delayed(Duration.zero, () async {
      try {
        debugPrint('🔄 Synchronisation change en arrière-plan...');
        final syncService = SyncService();
        await syncService.syncAll();
        debugPrint('✅ Synchronisation change terminée');
      } catch (e) {
        debugPrint('⚠️ Erreur sync change (non bloquante): $e');
      }
    });
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    _tauxController.dispose();
    super.dispose();
  }
}
