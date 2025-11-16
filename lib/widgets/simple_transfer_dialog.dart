import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../models/operation_model.dart';
import '../models/agent_model.dart';
import '../services/operation_service.dart';
import '../services/transaction_service.dart';
import '../services/auth_service.dart';
import '../services/shop_service.dart';
import '../services/rates_service.dart';
import '../utils/responsive_dialog_utils.dart';
import 'print_receipt_dialog.dart';

class SimpleTransferDialog extends StatefulWidget {
  const SimpleTransferDialog({super.key});

  @override
  State<SimpleTransferDialog> createState() => _SimpleTransferDialogState();
}

class _SimpleTransferDialogState extends State<SimpleTransferDialog> {
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

  @override
  void initState() {
    super.initState();
    _montantController.addListener(_calculateCommission);
  }

  @override
  void dispose() {
    _montantController.removeListener(_calculateCommission);
    _montantController.dispose();
    _destinataireController.dispose();
    super.dispose();
  }
  
  void _calculateCommission() async {
    final montantNet = double.tryParse(_montantController.text) ?? 0.0;  // Montant que le destinataire REÇOIT
    
    // Récupérer la VRAIE commission depuis RatesService
    final ratesService = RatesService.instance;
    await ratesService.loadRatesAndCommissions();
    
    final commissionData = ratesService.getCommissionByType('SORTANT');
    if (commissionData != null) {
      _tauxCommission = commissionData.taux; // Stocker le taux réel
      _commission = montantNet * (commissionData.taux / 100);
      debugPrint('✅ Commission récupérée: ${commissionData.taux}% sur $montantNet = $_commission');
    } else {
      // PAS DE FALLBACK - Afficher erreur
      debugPrint('❌ ERREUR: Commission SORTANT non trouvée dans la base de données!');
      _tauxCommission = 0.0;
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
        title: 'Nouveau Transfert',
        icon: Icons.send,
        color: const Color(0xFFDC2626),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Instructions
            Container(
              padding: EdgeInsets.all(isMobile ? 12 : 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info, color: Colors.blue, size: ResponsiveDialogUtils.getIconSize(context)),
                  SizedBox(width: isMobile ? 8 : 12),
                  Expanded(
                    child: Text(
                      isMobile
                          ? 'Ajoutez une capture, montant et destinataire.'
                          : 'Pour effectuer un transfert, vous avez besoin de :\n• Une capture d\'écran de la preuve de paiement\n• Le montant exact\n• Le nom du destinataire',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: isMobile ? 13 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: fieldSpacing),
            
            // 1. Capture d'écran
            Text(
              '1. Capture d\'écran de la preuve *',
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
                height: isMobile ? 150 : 200,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedImage != null ? Colors.green : Colors.grey,
                    width: 2,
                    style: BorderStyle.solid,
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
                                        size: isMobile ? 40 : 48,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: isMobile ? 6 : 8),
                                      Text(
                                        'Image sélectionnée',
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
                            size: isMobile ? 40 : 48,
                            color: Colors.grey,
                          ),
                          SizedBox(height: isMobile ? 8 : 12),
                          Text(
                            'Cliquez pour ajouter une capture',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: isMobile ? 13 : 14,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
            SizedBox(height: fieldSpacing),
            
            // 2. Destinataire
            Text(
              '2. Nom du destinataire *',
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
                labelText: 'Nom complet',
                border: const OutlineInputBorder(),
                prefixIcon: Icon(Icons.person, size: ResponsiveDialogUtils.getIconSize(context)),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 12 : 16,
                ),
              ),
              style: TextStyle(fontSize: isMobile ? 16 : 18),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Le nom du destinataire est requis';
                }
                return null;
              },
            ),
            SizedBox(height: fieldSpacing),
            
            // 3. Montant
            Text(
              '3. Montant du transfert *',
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
            
            // Résumé commission
            if (_montantController.text.isNotEmpty)
              Container(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Montant:', style: TextStyle(fontSize: isMobile ? 13 : 14)),
                        Text(
                          '${_montantController.text} USD',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14),
                        ),
                      ],
                    ),
                    SizedBox(height: isMobile ? 6 : 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Commission (${_tauxCommission > 0 ? '${_tauxCommission.toStringAsFixed(1)}%' : '0%'}):', 
                          style: TextStyle(fontSize: isMobile ? 13 : 14)
                        ),
                        Text(
                          '${_commission.toStringAsFixed(2)} USD',
                          style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: isMobile ? 13 : 14),
                        ),
                      ],
                    ),
                    Divider(height: isMobile ? 16 : 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Montant net:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: isMobile ? 14 : 16),
                        ),
                        Text(
                          '${_montantNet.toStringAsFixed(2)} USD',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                            fontSize: isMobile ? 14 : 16,
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
          if (!isMobile)
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              minimumSize: Size(isMobile ? double.infinity : 120, isMobile ? 48 : 40),
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
                : Text(isMobile ? 'Envoyer' : 'Envoyer Transfert'),
          ),
        ],
      ),
    );
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
              content: Text('Veuillez ajouter une capture d\'écran de la preuve de paiement'),
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
      final currentUser = authService.currentUser;
      
      if (currentUser?.id == null || currentUser?.shopId == null) {
        throw Exception('Utilisateur non connecté');
      }

      final operationService = OperationService();
      final montant = double.parse(_montantController.text);
      
      // Créer l'opération de transfert simple
      final operation = OperationModel(
        agentId: currentUser!.id!,
        agentUsername: currentUser.username,
        shopSourceId: currentUser.shopId!,
        type: OperationType.transfertNational, // Par défaut national
        montantNet: _montantNet,  // Ce que le destinataire REÇOIT
        montantBrut: _montantNet + _commission,  // Ce que le client PAIE
        commission: _commission,
        devise: 'USD',
        modePaiement: ModePaiement.cash,
        destinataire: _destinataireController.text,
        notes: 'Transfert simple - Photo: ${_selectedImage!.path}',
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
                  content: Text('Transfert de ${montant.toStringAsFixed(2)} USD effectué - Reçu imprimé'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            onSkipPrint: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Transfert de ${montant.toStringAsFixed(2)} USD effectué (sans impression)'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
          ),
        );
      }
    } catch (e) {
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}
