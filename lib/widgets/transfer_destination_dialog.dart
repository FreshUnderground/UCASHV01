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
import '../utils/auto_print_helper.dart';
import '../utils/responsive_dialog_utils.dart';

class TransferDestinationDialog extends StatefulWidget {
  const TransferDestinationDialog({super.key});

  @override
  State<TransferDestinationDialog> createState() => _TransferDestinationDialogState();
}

class _TransferDestinationDialogState extends State<TransferDestinationDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _destinataireController = TextEditingController();
  final _expediteurController = TextEditingController(); // Add expediteur controller
  
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
    _expediteurController.dispose(); // Dispose expediteur controller
    super.dispose();
  }
  
  void _loadShops() {
    Provider.of<ShopService>(context, listen: false).loadShops();
  }
  
  void _calculateCommission() async {
    final montantNet = double.tryParse(_montantController.text) ?? 0.0;  // Montant que le destinataire REÇOIT
    
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
          _commission = montantNet * (commissionData.taux / 100);  // Commission sur montantNet
          debugPrint('✅ Commission SORTANT récupérée: ${commissionData.taux}% sur $montantNet = $_commission');
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
          _commission = montantNet * (commissionData.taux / 100);  // Commission sur montantNet
          debugPrint('✅ Commission ENTRANT récupérée: ${commissionData.taux}% sur $montantNet = $_commission');
        } else {
          _tauxCommission = 0.0;
          _commission = 0.0;
          debugPrint('❌ ERREUR: Commission ENTRANT non trouvée dans la base de données!');
        }
        break;
      default:
        _commission = 0.0;
    }
    
    // LE CLIENT PAIE: Montant Net + Commission
    _montantNet = montantNet;  // Ce que le destinataire reçoit
    // montantBrut sera = montantNet + commission (calculé lors de la création)
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth <= 480;
    final fieldSpacing = ResponsiveDialogUtils.getFieldSpacing(context);
    final labelFontSize = ResponsiveDialogUtils.getLabelFontSize(context);
    
    return ResponsiveDialogUtils.buildResponsiveDialog(
      context: context,
      header: ResponsiveDialogUtils.buildResponsiveHeader(
        context: context,
        title: 'Transfert vers Destination',
        icon: Icons.send,
        color: const Color(0xFFDC2626),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Type de transfert
            Text(
              '1. Type de transfert *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
                      
            DropdownButtonFormField<OperationType>(
              value: _transferType,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Type de transfert',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.swap_horiz, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: OperationType.transfertNational,
                  child: Text(
                    'Transfert Sortant (National + International)',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                DropdownMenuItem(
                  value: OperationType.transfertInternationalEntrant,
                  child: Text(
                    'Transfert International Entrant',
                    style: TextStyle(fontSize: isMobile ? 14 : 16),
                    overflow: TextOverflow.ellipsis,
                  ),
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
            SizedBox(height: fieldSpacing),
                      
            // Shop de destination (pour tous les transferts sortants)
            if (_transferType == OperationType.transfertNational) ...[
              Text(
                '2. Shop de destination *',
                style: TextStyle(
                  fontSize: labelFontSize,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFDC2626),
                ),
              ),
              SizedBox(height: isMobile ? 8 : 12),
                        
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
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Shop de destination',
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.store, size: ResponsiveDialogUtils.getIconSize(context)),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 12 : 16,
                        vertical: isMobile ? 12 : 16,
                      ),
                    ),
                    items: availableShops.map((shop) {
                      return DropdownMenuItem(
                        value: shop,
                        child: Text(
                          '${shop.designation} - ${shop.localisation}',
                          style: TextStyle(fontSize: isMobile ? 14 : 16),
                          overflow: TextOverflow.ellipsis,
                        ),
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
              SizedBox(height: fieldSpacing),
            ],
                      
            // Informations du destinataire
            Text(
              '${OperationType.transfertNational == OperationType.transfertNational ? '3' : '2'}. Personne qui sera servie *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            TextFormField(
              controller: _destinataireController,
              decoration: InputDecoration(
                labelText: 'Nom de la personne qui sera servie',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, size: ResponsiveDialogUtils.getIconSize(context)),
                hintText: 'Ex: Jean Mukendi',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              style: TextStyle(fontSize: isMobile ? 16 : 18),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le nom de la personne est requis';
                }
                return null;
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // Nom de l'expéditeur
            Text(
              '${_transferType == OperationType.transfertNational ? '4' : '3'}. Nom de l\'expéditeur',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            TextFormField(
              controller: _expediteurController,
              decoration: InputDecoration(
                labelText: 'Nom de l\'expéditeur (optionnel)',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline, size: ResponsiveDialogUtils.getIconSize(context)),
                hintText: 'Ex: Marie Dupont',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              style: TextStyle(fontSize: isMobile ? 16 : 18),
            ),
            SizedBox(height: fieldSpacing),
            
            // Montant
            Text(
              '${_transferType == OperationType.transfertNational ? '5' : '4'}. Montant du transfert *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            TextFormField(
              controller: _montantController,
              decoration: InputDecoration(
                labelText: 'Montant en USD',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money, size: ResponsiveDialogUtils.getIconSize(context)),
                suffixText: 'USD',
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              keyboardType: TextInputType.number,
              style: TextStyle(fontSize: isMobile ? 16 : 18),
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
            SizedBox(height: fieldSpacing),
            
            // Mode de paiement
            Text(
              '${_transferType == OperationType.transfertNational ? '6' : '5'}. Mode de paiement *',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            DropdownButtonFormField<ModePaiement>(
              value: _modePaiement,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Mode de paiement',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.payment, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              items: [
                DropdownMenuItem(
                  value: ModePaiement.cash,
                  child: Row(
                    children: [
                      Icon(Icons.money, color: Colors.green, size: isMobile ? 18 : 20),
                      SizedBox(width: 8),
                      Text('Cash', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ModePaiement.airtelMoney,
                  child: Row(
                    children: [
                      Icon(Icons.phone_android, color: Colors.orange, size: isMobile ? 18 : 20),
                      SizedBox(width: 8),
                      Text('Airtel Money', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ModePaiement.mPesa,
                  child: Row(
                    children: [
                      Icon(Icons.account_balance_wallet, color: Colors.blue, size: isMobile ? 18 : 20),
                      SizedBox(width: 8),
                      Text('M-Pesa', style: TextStyle(fontSize: isMobile ? 14 : 16)),
                    ],
                  ),
                ),
                DropdownMenuItem(
                  value: ModePaiement.orangeMoney,
                  child: Row(
                    children: [
                      Icon(Icons.payment, color: Colors.orange, size: isMobile ? 18 : 20),
                      SizedBox(width: 8),
                      Text('Orange Money', style: TextStyle(fontSize: isMobile ? 14 : 16)),
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
            SizedBox(height: fieldSpacing),
            
            // Capture d'écran (optionnelle)
            Text(
              '${_transferType == OperationType.transfertNational ? '7' : '6'}. Preuve de paiement (optionnelle)',
              style: TextStyle(
                fontSize: labelFontSize,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            SizedBox(height: isMobile ? 8 : 12),
            
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                width: double.infinity,
                height: isMobile ? 120 : 150,
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
                                        size: isMobile ? 36 : 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'Preuve sélectionnée',
                                        style: TextStyle(
                                          color: Colors.green,
                                          fontWeight: FontWeight.bold,
                                          fontSize: isMobile ? 13 : 14,
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
                            size: isMobile ? 36 : 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Cliquez pour ajouter une preuve',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: isMobile ? 14 : 16,
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
            
            SizedBox(height: fieldSpacing),
            
            // Résumé
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFDC2626).withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Résumé du transfert',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isMobile ? 14 : 16,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  SizedBox(height: isMobile ? 8 : 12),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Type:', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                      Text(
                        _getTransferTypeLabel(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  
                  if (_selectedShop != null) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Destination:', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                        Text(
                          _selectedShop!.designation,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 14,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                  ],
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Personne à servir:', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                      Flexible(
                        child: Text(
                          _destinataireController.text.isEmpty ? 'Non renseigné' : _destinataireController.text,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 12 : 14,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Montant à servir:', style: TextStyle(fontSize: isMobile ? 12 : 14)),
                      Text(
                        '${_montantController.text.isEmpty ? '0' : _montantController.text} USD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Commission (${_tauxCommission > 0 ? '${_tauxCommission.toStringAsFixed(1)}%' : 'Gratuit'}):', 
                        style: TextStyle(fontSize: isMobile ? 12 : 14),
                      ),
                      Text(
                        '${_commission.toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 12 : 14,
                          color: _commission > 0 ? Colors.orange : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 6 : 8),
                  
                  const Divider(),
                  SizedBox(height: isMobile ? 6 : 8),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total à payer:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                        ),
                      ),
                      Text(
                        '${(_montantNet + _commission).toStringAsFixed(2)} USD',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: isMobile ? 14 : 16,
                          color: const Color(0xFFDC2626),
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
      actions: ResponsiveDialogUtils.buildResponsiveActions(
        context: context,
        actions: [
          TextButton(
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
            child: const Text('Annuler'),
          ),
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
    
    // Image is now optional, so we don't check for it
    
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
      
      // Create notes with image info and expediteur if provided
      String notes = 'Transfert avec destination - ${_getTransferTypeLabel()}';
      if (_selectedImage != null) {
        notes += ' - Photo: ${_selectedImage!.path}';
      }
      if (_expediteurController.text.isNotEmpty) {
        notes += ' - Expéditeur: ${_expediteurController.text}';
      }
      
      // Récupérer le shop source pour avoir sa désignation
      final shopService = Provider.of<ShopService>(context, listen: false);
      final shopSource = shopService.getShopById(currentUser!.shopId!);
      
      // Créer l'opération
      final operation = OperationModel(
        codeOps: '', // Sera généré automatiquement par createOperation
        agentId: currentUser.id!,
        agentUsername: currentUser.username,
        shopSourceId: currentUser.shopId!,
        shopSourceDesignation: shopSource?.designation,  // Ajouter la désignation du shop source
        shopDestinationId: _selectedShop?.id,
        shopDestinationDesignation: _selectedShop?.designation,
        type: _transferType,
        montantNet: _montantNet,  // Ce que le destinataire REÇOIT
        montantBrut: _montantNet + _commission,  // Ce que le client PAIE
        commission: _commission,
        devise: 'USD',
        modePaiement: _modePaiement,
        destinataire: _destinataireController.text,
        notes: notes,
        observation: _expediteurController.text.isNotEmpty ? _expediteurController.text : null, // Store expediteur in observation field
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
        
        // Imprimer automatiquement le reçu sur POS
        await AutoPrintHelper.autoPrintWithDialog(
          context: context,
          operation: savedOperation,
          shop: shop,
          agent: agent,
          clientName: _destinataireController.text,
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
