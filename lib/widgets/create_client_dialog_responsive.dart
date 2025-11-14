import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/client_service.dart';
import 'responsive_form_dialog.dart';
import 'responsive_card.dart';

/// Dialog responsive pour créer un nouveau client
class CreateClientDialogResponsive extends StatefulWidget {
  final int shopId;
  final int agentId;

  const CreateClientDialogResponsive({
    super.key,
    required this.shopId,
    required this.agentId,
  });

  @override
  State<CreateClientDialogResponsive> createState() => _CreateClientDialogResponsiveState();
}


class _CreateClientDialogResponsiveState extends State<CreateClientDialogResponsive> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _adresseController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _createAccount = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveFormDialog(
      title: 'Nouveau Client',
      titleIcon: Icons.person_add,
      maxWidth: context.isDesktop ? 600 : null,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Informations personnelles
            Text(
              'Informations Personnelles',
              style: TextStyle(
                fontSize: context.isMobile ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: const Color(0xFFDC2626),
              ),
            ),
            const SizedBox(height: 16),
            
            // Nom complet
            ResponsiveFormField(
              label: 'Nom Complet',
              controller: _nomController,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Le nom est requis';
                }
                if (value.trim().length < 2) {
                  return 'Le nom doit contenir au moins 2 caractères';
                }
                return null;
              },
            ),
            
            // Téléphone et adresse
            ResponsiveGrid(
              forceColumns: context.isMobile ? 1 : 2,
              children: [
                ResponsiveFormField(
                  label: 'Téléphone',
                  controller: _telephoneController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Le téléphone est requis';
                    }
                    if (value.trim().length < 8) {
                      return 'Numéro de téléphone invalide';
                    }
                    return null;
                  },
                ),
                ResponsiveFormField(
                  label: 'Adresse (optionnel)',
                  controller: _adresseController,
                  maxLines: context.isMobile ? 2 : 1,
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Option de création de compte
            ResponsiveCard(
              backgroundColor: Colors.blue[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Checkbox(
                      value: _createAccount,
                      onChanged: (value) {
                        setState(() {
                          _createAccount = value ?? false;
                        });
                      },
                      activeColor: const Color(0xFFDC2626),
                    ),
                    Expanded(
                      child: Text(
                        'Créer un compte de connexion pour ce client',
                        style: TextStyle(
                          fontSize: context.isMobile ? 14 : 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_createAccount) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Informations de Connexion',
                    style: TextStyle(
                      fontSize: context.isMobile ? 14 : 16,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFDC2626),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ResponsiveGrid(
                    forceColumns: context.isMobile ? 1 : 2,
                    children: [
                      ResponsiveFormField(
                        label: 'Nom d\'utilisateur',
                        controller: _usernameController,
                        validator: _createAccount ? (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Le nom d\'utilisateur est requis';
                          }
                          if (value.trim().length < 3) {
                            return 'Au moins 3 caractères requis';
                          }
                          return null;
                        } : null,
                      ),
                      ResponsiveFormField(
                        label: 'Mot de passe',
                        controller: _passwordController,
                        obscureText: true,
                        validator: _createAccount ? (value) {
                          if (value == null || value.isEmpty) {
                            return 'Le mot de passe est requis';
                          }
                          if (value.length < 6) {
                            return 'Au moins 6 caractères requis';
                          }
                          return null;
                        } : null,
                      ),
                    ],
                  ),
                ],
              ],
            ),
            ),
            
            const SizedBox(height: 16),
            
            // Informations sur le solde initial
            ResponsiveCard(
              backgroundColor: Colors.green[50],
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.green[700],
                    size: context.isMobile ? 20 : 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Le client sera créé avec un solde initial de 0.00 USD. '
                      'Utilisez les opérations de dépôt pour ajouter des fonds.',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: context.isMobile ? 12 : 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Affichage du numéro de compte généré
            ResponsiveCard(
              backgroundColor: Colors.blue[50],
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.account_balance,
                        color: Colors.blue[700],
                        size: context.isMobile ? 20 : 24,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Numéro de Compte',
                        style: TextStyle(
                          fontSize: context.isMobile ? 14 : 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Un numéro de compte unique sera généré automatiquement à la création du client.',
                    style: TextStyle(
                      color: Colors.blue[600],
                      fontSize: context.isMobile ? 12 : 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        ResponsiveActionButtons(
          onCancel: () => Navigator.of(context).pop(),
          onSave: _isLoading ? null : _handleSubmit,
          isLoading: _isLoading,
          saveText: 'Créer Client',
        ),
      ],
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final clientService = Provider.of<ClientService>(context, listen: false);
      
      final success = await clientService.createClient(
        nom: _nomController.text.trim(),
        telephone: _telephoneController.text.trim(),
        adresse: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
        shopId: widget.shopId,
        agentId: widget.agentId,
        username: _createAccount ? _usernameController.text.trim() : null,
        password: _createAccount ? _passwordController.text : null,
      );

      if (success && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _createAccount 
                ? 'Client créé avec succès avec compte de connexion !'
                : 'Client créé avec succès !',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${clientService.errorMessage ?? "Erreur inconnue"}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
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
}
