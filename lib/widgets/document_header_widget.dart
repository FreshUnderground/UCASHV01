import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/document_header_service.dart';
import '../models/document_header_model.dart';

/// Widget pour gérer les en-têtes personnalisés des documents (re\u00e7us, PDF, rapports)
class DocumentHeaderManagementWidget extends StatefulWidget {
  const DocumentHeaderManagementWidget({super.key});

  @override
  State<DocumentHeaderManagementWidget> createState() => _DocumentHeaderManagementWidgetState();
}

class _DocumentHeaderManagementWidgetState extends State<DocumentHeaderManagementWidget> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _companyNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _footerMessageController = TextEditingController();
  final _rccmController = TextEditingController();
  final _idnatController = TextEditingController();
  final _taxNumberController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Charger après le premier build pour éviter setState pendant build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadHeader();
    });
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _footerMessageController.dispose();
    _rccmController.dispose();
    _idnatController.dispose();
    _taxNumberController.dispose();
    super.dispose();
  }

  Future<void> _loadHeader() async {
    setState(() => _isLoading = true);
    
    final headerService = Provider.of<DocumentHeaderService>(context, listen: false);
    await headerService.loadHeader();
    
    final header = headerService.getHeaderOrDefault();
    
    _companyNameController.text = header.companyName;
    _addressController.text = header.address ?? '';
    _phoneController.text = header.phone ?? '';
    _footerMessageController.text = header.companySlogan ?? 'Merci pour votre confiance';
    _rccmController.text = header.registrationNumber ?? '';
    _idnatController.text = header.email ?? ''; // Utiliser email pour stocker IDNAT temporairement
    _taxNumberController.text = header.taxNumber ?? '';
    
    setState(() => _isLoading = false);
  }

  Future<void> _saveHeader() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final headerService = Provider.of<DocumentHeaderService>(context, listen: false);
      
      final header = DocumentHeaderModel(
        id: 0,
        companyName: _companyNameController.text.trim(),
        companySlogan: _footerMessageController.text.trim().isEmpty 
            ? null 
            : _footerMessageController.text.trim(),
        address: _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
        phone: _phoneController.text.trim().isEmpty 
            ? null 
            : _phoneController.text.trim(),
        email: _idnatController.text.trim().isEmpty 
            ? null 
            : _idnatController.text.trim(), // IDNAT stocké dans email
        website: null,
        taxNumber: _taxNumberController.text.trim().isEmpty 
            ? null 
            : _taxNumberController.text.trim(),
        registrationNumber: _rccmController.text.trim().isEmpty 
            ? null 
            : _rccmController.text.trim(),
        isActive: true,
        createdAt: DateTime.now(),
      );
      
      final success = await headerService.saveHeader(header);
      
      if (success && mounted) {
        _showSnackBar('✅ En-tête sauvegardé avec succès', Colors.green);
        // Recharger pour afficher les données synchronisées
        await _loadHeader();
      } else if (mounted) {
        _showSnackBar('❌ Erreur lors de la sauvegarde', Colors.red);
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('❌ Erreur: $e', Colors.red);
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;
    
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.receipt_long,
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
                          'En-t\u00eate des Documents',
                          style: TextStyle(
                            fontSize: isMobile ? 18 : 22,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Nom, Adresse, Téléphone, RCCM, IDNAT, N° Impôt',
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
              
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),
              
              // Form fields
              if (isMobile)
                Column(
                  children: _buildFormFields(),
                )
              else
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _buildFormFields(),
                ),
              
              const SizedBox(height: 24),
              
              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loadHeader,
                      icon: const Icon(Icons.refresh),
                      label: const Text('R\u00e9initialiser'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: const BorderSide(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveHeader,
                      icon: _isSaving 
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Sauvegarde...' : 'Sauvegarder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
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

  List<Widget> _buildFormFields() {
    final isMobile = MediaQuery.of(context).size.width <= 768;
    final fieldWidth = isMobile ? double.infinity : (MediaQuery.of(context).size.width - 100) / 2;
    
    return [
      // Company Name (Required)
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _companyNameController,
          decoration: const InputDecoration(
            labelText: 'Nom de l\'entreprise *',
            hintText: 'Ex: UCASH',
            prefixIcon: Icon(Icons.business),
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Le nom de l\'entreprise est requis';
            }
            return null;
          },
        ),
      ),
      
      // Address
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _addressController,
          decoration: const InputDecoration(
            labelText: 'Adresse',
            hintText: 'Adresse complète',
            prefixIcon: Icon(Icons.location_on),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ),
      
      // Phone
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _phoneController,
          decoration: const InputDecoration(
            labelText: 'Téléphone',
            hintText: 'Ex: +243 XXX XXX XXX',
            prefixIcon: Icon(Icons.phone),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      
      // Footer Message
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _footerMessageController,
          decoration: const InputDecoration(
            labelText: 'Message de pied de page',
            hintText: 'Ex: Merci pour votre confiance',
            prefixIcon: Icon(Icons.message),
            border: OutlineInputBorder(),
          ),
          maxLines: 2,
        ),
      ),
      
      // RCCM
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _rccmController,
          decoration: const InputDecoration(
            labelText: 'RCCM',
            hintText: 'Numéro RCCM',
            prefixIcon: Icon(Icons.description),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      
      // IDNAT
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _idnatController,
          decoration: const InputDecoration(
            labelText: 'IDNAT',
            hintText: 'Numéro d\'Identification Nationale',
            prefixIcon: Icon(Icons.fingerprint),
            border: OutlineInputBorder(),
          ),
        ),
      ),
      
      // N° Impôt
      SizedBox(
        width: fieldWidth,
        child: TextFormField(
          controller: _taxNumberController,
          decoration: const InputDecoration(
            labelText: 'N° Impôt',
            hintText: 'Numéro d\'Impôt',
            prefixIcon: Icon(Icons.receipt_long),
            border: OutlineInputBorder(),
          ),
        ),
      ),
    ];
  }
}
