import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/operation_service.dart';
import '../services/rates_service.dart';
import '../models/shop_model.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import 'print_receipt_dialog.dart';

class TransferDestinationDialog extends StatefulWidget {
  const TransferDestinationDialog({super.key});

  @override
  State<TransferDestinationDialog> createState() => _TransferDestinationDialogState();
}

class _TransferDestinationDialogState extends State<TransferDestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _destinataireController = TextEditingController();
  
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isLoading = false;
  final ImagePicker _picker = ImagePicker();
  
  double _commission = 0.0;
  double _montantNet = 0.0;
  double _tauxCommission = 0.0; // Taux réel de la commission en %
  
  ShopModel? _selectedShop;
  OperationType _transferType = OperationType.transfertNational;
  ModePaiement _modePaiement = ModePaiement.cash;

  @override
  void initState() {
    super.initState();
    _montantController.addListener(_calculateCommission);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShops();
    });
  }

  @override
  void dispose() {
    _montantController.removeListener(_calculateCommission);
    _montantController.dispose();
    _destinataireController.dispose();
    super.dispose();
  }
  
  void _loadShops() {
    Provider.of<ShopService>(context, listen: false).loadShops();
  }
  
  void _calculateCommission() async {
    final montant = double.tryParse(_montantController.text) ?? 0.0;
    
    // Récupérer la VRAIE commission depuis RatesService
    final ratesService = RatesService.instance;
    await ratesService.loadRatesAndCommissions();
    
    // Commission selon le type de transfert
    switch (_transferType) {
      case OperationType.transfertNational:
      case OperationType.transfertInternationalSortant:
        // Utiliser la VRAIE commission SORTANT
        final commissionData = ratesService.getCommissionByType('SORTANT');
        if (commissionData != null) {
          _tauxCommission = commissionData.taux; // Stocker le taux réel
          _commission = montant * (commissionData.taux / 100);
          debugPrint('✅ Commission SORTANT récupérée: ${commissionData.taux}% sur $montant = $_commission');
        } else {
          _tauxCommission = 0.0;
          _commission = 0.0;
          debugPrint('❌ ERREUR: Commission SORTANT non trouvée dans la base de données!');
        }
        break;
      case OperationType.transfertInternationalEntrant:
        // Utiliser la VRAIE commission ENTRANT (normalement 0%)
        final commissionData = ratesService.getCommissionByType('ENTRANT');
        if (commissionData != null) {
          _tauxCommission = commissionData.taux; // Stocker le taux réel
          _commission = montant * (commissionData.taux / 100);
          debugPrint('✅ Commission ENTRANT récupérée: ${commissionData.taux}% sur $montant = $_commission');
        } else {
          _tauxCommission = 0.0;
          _commission = 0.0;
          debugPrint('❌ ERREUR: Commission ENTRANT non trouvée dans la base de données!');
        }
        break;
      default:
        _commission = 0.0;
    }
    
    _montantNet = montant - _commission;
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: 600,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFFDC2626),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  topRight: Radius.circular(8),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.send, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Transfert vers Destination',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Type de transfert
                      const Text(
                        '1. Type de transfert *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<OperationType>(
                        value: _transferType,
                        decoration: const InputDecoration(
                          labelText: 'Type de transfert',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.swap_horiz),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: OperationType.transfertNational,
                            child: Text('Transfert Sortant (National + International)'),
                          ),
                          DropdownMenuItem(
                            value: OperationType.transfertInternationalEntrant,
                            child: Text('Transfert International Entrant'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _transferType = value!;
                            _calculateCommission();
                          });
                        },
                        validator: (value) {
                          if (value == null) {
                            return 'Sélectionnez le type de transfert';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Shop de destination (pour tous les transferts sortants)
                      if (_transferType == OperationType.transfertNational) ...[
                        const Text(
                          '2. Shop de destination *',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        Consumer<ShopService>(
                          builder: (context, shopService, child) {
                            final authService = Provider.of<AuthService>(context, listen: false);
                            final currentUser = authService.currentUser;
                            
                            // Exclure le shop actuel de l'agent
                            final availableShops = shopService.shops
                                .where((shop) => shop.id != currentUser?.shopId)
                                .toList();
                            
                            return DropdownButtonFormField<ShopModel>(
                              value: _selectedShop,
                              decoration: const InputDecoration(
                                labelText: 'Shop de destination',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.store),
                              ),
                              items: availableShops.map((shop) {
                                return DropdownMenuItem(
                                  value: shop,
                                  child: Text('${shop.designation} - ${shop.localisation}'),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedShop = value;
                                });
                              },
                              validator: (value) {
                                if (_transferType == OperationType.transfertNational && value == null) {
                                  return 'Sélectionnez le shop de destination';
                                }
                                return null;
                              },
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                      
                      // Informations du destinataire
                      const Text(
                        '${OperationType.transfertNational == OperationType.transfertNational ? '3' : '2'}. Personne qui sera servie *',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _destinataireController,
                        decoration: const InputDecoration(
                          labelText: 'Nom de la personne qui sera servie',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                          hintText: 'Ex: Jean Mukendi',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le nom de la personne est requis';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Montant
                      Text(
                        '${_transferType == OperationType.transfertNational ? '4' : '3'}. Montant du transfert *',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      TextFormField(
                        controller: _montantController,
                        decoration: const InputDecoration(
                          labelText: 'Montant en USD',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.attach_money),
                          suffixText: 'USD',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le montant est requis';
                          }
                          final montant = double.tryParse(value);
                          if (montant == null || montant <= 0) {
                            return 'Montant invalide';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Mode de paiement
                      Text(
                        '${_transferType == OperationType.transfertNational ? '5' : '4'}. Mode de paiement *',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      DropdownButtonFormField<ModePaiement>(
                        value: _modePaiement,
                        decoration: const InputDecoration(
                          labelText: 'Mode de paiement',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: ModePaiement.cash,
                            child: Row(
                              children: [
                                Icon(Icons.money, color: Colors.green),
                                SizedBox(width: 8),
                                Text('Cash'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ModePaiement.airtelMoney,
                            child: Row(
                              children: [
                                Icon(Icons.phone_android, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Airtel Money'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ModePaiement.mPesa,
                            child: Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: Colors.blue),
                                SizedBox(width: 8),
                                Text('M-Pesa'),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: ModePaiement.orangeMoney,
                            child: Row(
                              children: [
                                Icon(Icons.payment, color: Colors.orange),
                                SizedBox(width: 8),
                                Text('Orange Money'),
                              ],
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _modePaiement = value!;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      
                      // Capture d'écran
                      Text(
                        '${_transferType == OperationType.transfertNational ? '6' : '5'}. Preuve de paiement *',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: double.infinity,
                          height: 150,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: _selectedImage != null ? Colors.green : Colors.grey,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: _selectedImage != null 
                                ? Colors.green.withOpacity(0.05)
                                : Colors.grey.withOpacity(0.05),
                          ),
                          child: _selectedImage != null && _imageBytes != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: kIsWeb || _imageBytes!.length <= 3
                                      ? Container(
                                          color: Colors.green.withOpacity(0.1),
                                          child: Center(
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 48,
                                                  color: Colors.green,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Preuve sélectionnée',
                                                  style: TextStyle(
                                                    color: Colors.green,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        )
                                      : Image.memory(
                                          _imageBytes!,
                                          fit: BoxFit.cover,
                                        ),
                                )
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 48,
                                      color: Colors.grey,
                                    ),
                                    SizedBox(height: 12),
                                    Text(
                                      'Cliquez pour ajouter une preuve',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      
                      if (_selectedImage != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Preuve sélectionnée: ${_selectedImage!.name}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                setState(() {
                                  _selectedImage = null;
                                  _imageBytes = null;
                                });
                              },
                              child: const Text('Changer'),
                            ),
                          ],
                        ),
                      ],
                      
                      const SizedBox(height: 24),
                      
                      // Résumé
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Résumé du transfert',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Color(0xFFDC2626),
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Type:'),
                                Text(
                                  _getTransferTypeLabel(),
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            if (_selectedShop != null) ...[
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Destination:'),
                                  Text(
                                    _selectedShop!.designation,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                            ],
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Personne à servir:'),
                                Text(
                                  _destinataireController.text.isEmpty ? 'Non renseigné' : _destinataireController.text,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Montant:'),
                                Text(
                                  '${_montantController.text.isEmpty ? '0' : _montantController.text} USD',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Commission (${_tauxCommission > 0 ? '${_tauxCommission.toStringAsFixed(1)}%' : 'Gratuit'}):', 
                                ),
                                Text(
                                  '${_commission.toStringAsFixed(2)} USD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: _commission > 0 ? Colors.orange : Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Montant net:'),
                                Text(
                                  '${_montantNet.toStringAsFixed(2)} USD',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            
                            const Divider(),
                            const SizedBox(height: 8),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Total à payer:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${_montantController.text.isEmpty ? '0.00' : double.tryParse(_montantController.text)?.toStringAsFixed(2) ?? '0.00'} USD',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFFDC2626),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Actions
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Envoyer Transfert'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getTransferTypeLabel() {
    switch (_transferType) {
      case OperationType.transfertNational:
        return 'Transfert Sortant';
      case OperationType.transfertInternationalEntrant:
        return 'International Entrant';
      default:
        return 'Inconnu';
    }
  }

  Future<void> _pickImage() async {
    try {
      // Pour le web/desktop, utiliser seulement la galerie
      if (kIsWeb) {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        
        if (image != null) {
          final bytes = await image.readAsBytes();
          setState(() {
            _selectedImage = image;
            _imageBytes = bytes;
          });
        }
        return;
      }
      
      // Pour les plateformes mobiles: Proposer CAMÉRA ou GALERIE
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: const Text('Sélectionner la source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFFDC2626)),
                title: const Text('Prendre une photo'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Color(0xFFDC2626)),
                title: const Text('Choisir depuis la galerie'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );
      
      if (source == null) return;
      
      final XFile? image = await _picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
      }
    } catch (e) {
      debugPrint('❌ Erreur lors de la sélection de l\'image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la sélection de l\'image: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedImage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Veuillez ajouter une preuve de paiement'),
              backgroundColor: Colors.red,
            ),
          );
        }
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final operationService = OperationService();
      final currentUser = authService.currentUser;
      
      if (currentUser?.id == null || currentUser?.shopId == null) {
        throw Exception('Utilisateur non connecté');
      }

      final montant = double.parse(_montantController.text);
      
      // Créer l'opération
      final operation = OperationModel(
        agentId: currentUser!.id!,
        agentUsername: currentUser.username,
        shopSourceId: currentUser.shopId!,
        shopDestinationId: _selectedShop?.id,
        shopDestinationDesignation: _selectedShop?.designation,
        type: _transferType,
        montantBrut: montant,
        montantNet: _montantNet,
        commission: _commission,
        devise: 'USD',
        modePaiement: _modePaiement,
        destinataire: _destinataireController.text,
        notes: 'Transfert avec destination - ${_getTransferTypeLabel()} - Photo: ${_selectedImage!.path}',
        statut: OperationStatus.enAttente,
        dateOp: DateTime.now(),
        lastModifiedAt: DateTime.now(),
        lastModifiedBy: 'agent_${currentUser.username}',
      );

      final savedOperation = await operationService.createOperation(operation);
      
      if (savedOperation == null) {
        throw Exception('Erreur lors de la création du transfert');
      }

      if (mounted) {
        // Fermer le dialog de transfert
        Navigator.of(context).pop(true);
        
        // Récupérer les données pour le reçu
        final shopService = Provider.of<ShopService>(context, listen: false);
        final shop = shopService.shops.firstWhere(
          (s) => s.id == currentUser.shopId,
          orElse: () => shopService.shops.first,
        );
        
        // Convertir UserModel en AgentModel pour le reçu
        final agent = AgentModel(
          id: currentUser.id,
          username: currentUser.username,
          password: '',
          shopId: currentUser.shopId!,
          nom: currentUser.nom,
          telephone: currentUser.telephone,
        );
        
        // Afficher le dialog d'impression
        await showDialog(
          context: context,
          barrierDismissible: true,
          builder: (context) => PrintReceiptDialog(
            operation: savedOperation,
            shop: shop,
            agent: agent,
            clientName: _destinataireController.text,
            onPrintSuccess: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Transfert de ${montant.toStringAsFixed(2)} USD vers ${_destinataireController.text} ${_selectedShop != null ? 'au ${_selectedShop!.designation}' : ''} effectué - Reçu imprimé',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onSkipPrint: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Transfert de ${montant.toStringAsFixed(2)} USD vers ${_destinataireController.text} ${_selectedShop != null ? 'au ${_selectedShop!.designation}' : ''} effectué (sans impression)',
                  ),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Erreur: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
