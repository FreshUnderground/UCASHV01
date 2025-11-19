import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/client_service.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_typography.dart';
import '../theme/ucash_containers.dart';

class ClientProfileWidget extends StatefulWidget {
  const ClientProfileWidget({super.key});

  @override
  State<ClientProfileWidget> createState() => _ClientProfileWidgetState();
}

class _ClientProfileWidgetState extends State<ClientProfileWidget> {
  bool _isEditing = false;
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nomController;
  late TextEditingController _telephoneController;
  late TextEditingController _adresseController;

  @override
  void initState() {
    super.initState();
    final client = Provider.of<AuthService>(context, listen: false).currentClient;
    _nomController = TextEditingController(text: client?.nom ?? '');
    _telephoneController = TextEditingController(text: client?.telephone ?? '');
    _adresseController = TextEditingController(text: client?.adresse ?? '');
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _adresseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, child) {
        final client = authService.currentClient;
        if (client == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune information partenaire disponible'),
            ),
          );
        }

        return Padding(
          padding: ResponsiveUtils.getFluidPadding(
            context,
            mobile: const EdgeInsets.all(12),
            tablet: const EdgeInsets.all(16),
            desktop: const EdgeInsets.all(24),
          ),
          child: Column(
            children: [
              // Photo de profil et informations de base
              Card(
                child: Padding(
                  padding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    desktop: const EdgeInsets.all(24),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: ResponsiveUtils.getFluidSpacing(context, mobile: 40, tablet: 45, desktop: 50),
                        backgroundColor: const Color(0xFFDC2626),
                        child: Text(
                          client.nom.isNotEmpty ? client.nom[0].toUpperCase() : 'P',
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 28, tablet: 32, desktop: 36),
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      
                      Text(
                        client.nom,
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 20, tablet: 22, desktop: 24),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 6, tablet: 7, desktop: 8)),
                      
                      Container(
                        padding: ResponsiveUtils.getFluidPadding(
                          context,
                          mobile: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          tablet: const EdgeInsets.symmetric(horizontal: 11, vertical: 3.5),
                          desktop: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        ),
                        decoration: BoxDecoration(
                          color: client.isActive ? Colors.green : Colors.red,
                          borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getFluidBorderRadius(context, mobile: 10, tablet: 11, desktop: 12),
                          ),
                        ),
                        child: Text(
                          client.isActive ? 'Compte Actif' : 'Compte Inactif',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 10, tablet: 11, desktop: 12),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              
              // Informations détaillées
              Card(
                child: Padding(
                  padding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    desktop: const EdgeInsets.all(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Informations Personnelles',
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 19, desktop: 20),
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1F2937),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _isEditing = !_isEditing;
                                if (!_isEditing) {
                                  // Réinitialiser les contrôleurs si on annule
                                  _nomController.text = client.nom;
                                  _telephoneController.text = client.telephone;
                                  _adresseController.text = client.adresse ?? '';
                                }
                              });
                            },
                            icon: Icon(
                              _isEditing ? Icons.close : Icons.edit,
                              color: _isEditing ? Colors.red : const Color(0xFFDC2626),
                            ),
                            tooltip: _isEditing ? 'Annuler' : 'Modifier',
                          ),
                        ],
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      
                      if (_isEditing)
                        _buildEditForm(client)
                      else
                        _buildInfoDisplay(client),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              
              // Statistiques du compte
              Card(
                child: Padding(
                  padding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    desktop: const EdgeInsets.all(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Statistiques du Compte',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 19, desktop: 20),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      
                      _buildStatRow('Solde actuel', '${client.solde.toStringAsFixed(2)} USD', 
                          client.solde >= 0 ? Colors.green : Colors.red),
                      _buildStatRow('Membre depuis', _formatDate(client.createdAt ?? DateTime.now()), Colors.blue),
                      _buildStatRow('Dernière activité', _formatDate(client.lastModifiedAt ?? DateTime.now()), Colors.orange),
                      _buildStatRow('Statut du compte', client.isActive ? 'Actif' : 'Inactif', 
                          client.isActive ? Colors.green : Colors.red),
                    ],
                  ),
                ),
              ),
              
              SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
              
              // Actions
              Card(
                child: Padding(
                  padding: ResponsiveUtils.getFluidPadding(
                    context,
                    mobile: const EdgeInsets.all(16),
                    tablet: const EdgeInsets.all(20),
                    desktop: const EdgeInsets.all(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Actions',
                        style: TextStyle(
                          fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 18, tablet: 19, desktop: 20),
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1F2937),
                        ),
                      ),
                      SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                      
                      if (context.isSmallScreen)
                        Column(
                          children: [
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _showChangePasswordDialog,
                                icon: Icon(Icons.lock, 
                                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                ),
                                label: Text('Changer le mot de passe',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: ResponsiveUtils.getFluidPadding(
                                    context,
                                    mobile: const EdgeInsets.symmetric(vertical: 10),
                                    tablet: const EdgeInsets.symmetric(vertical: 11),
                                    desktop: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showContactSupportDialog,
                                icon: Icon(Icons.support_agent,
                                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                ),
                                label: Text('Contacter le support',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  padding: ResponsiveUtils.getFluidPadding(
                                    context,
                                    mobile: const EdgeInsets.symmetric(vertical: 10),
                                    tablet: const EdgeInsets.symmetric(vertical: 11),
                                    desktop: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _showChangePasswordDialog,
                                icon: Icon(Icons.lock,
                                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                ),
                                label: Text('Changer le mot de passe',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFDC2626),
                                  foregroundColor: Colors.white,
                                  padding: ResponsiveUtils.getFluidPadding(
                                    context,
                                    mobile: const EdgeInsets.symmetric(vertical: 10),
                                    tablet: const EdgeInsets.symmetric(vertical: 11),
                                    desktop: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: _showContactSupportDialog,
                                icon: Icon(Icons.support_agent,
                                  size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
                                ),
                                label: Text('Contacter le support',
                                  style: TextStyle(
                                    fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFFDC2626),
                                  side: const BorderSide(color: Color(0xFFDC2626)),
                                  padding: ResponsiveUtils.getFluidPadding(
                                    context,
                                    mobile: const EdgeInsets.symmetric(vertical: 10),
                                    tablet: const EdgeInsets.symmetric(vertical: 11),
                                    desktop: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                      ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoDisplay(client) {
    return Column(
      children: [
        _buildInfoRow('Nom complet', client.nom),
        _buildInfoRow('Téléphone', client.telephone),
        _buildInfoRow('Adresse', client.adresse ?? 'Non renseignée'),
        _buildInfoRow('Nom d\'utilisateur', client.username ?? 'Non défini'),
        _buildInfoRow('ID Partenaire', client.id.toString()),
      ],
    );
  }

  Widget _buildEditForm(client) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nomController,
            decoration: InputDecoration(
              labelText: 'Nom complet',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                ),
              ),
              prefixIcon: Icon(Icons.person,
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
              contentPadding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le nom est requis';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
          
          TextFormField(
            controller: _telephoneController,
            decoration: InputDecoration(
              labelText: 'Téléphone',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                ),
              ),
              prefixIcon: Icon(Icons.phone,
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
              contentPadding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Le téléphone est requis';
              }
              return null;
            },
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
          
          TextFormField(
            controller: _adresseController,
            decoration: InputDecoration(
              labelText: 'Adresse (optionnel)',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                ),
              ),
              prefixIcon: Icon(Icons.location_on,
                size: ResponsiveUtils.getFluidIconSize(context, mobile: 18, tablet: 20, desktop: 22),
              ),
              contentPadding: ResponsiveUtils.getFluidPadding(
                context,
                mobile: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                tablet: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                desktop: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              ),
            ),
            style: TextStyle(
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
            ),
            maxLines: 2,
          ),
          SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
          
          if (context.isSmallScreen)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: ResponsiveUtils.getFluidPadding(
                        context,
                        mobile: const EdgeInsets.symmetric(vertical: 12),
                        tablet: const EdgeInsets.symmetric(vertical: 14),
                        desktop: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                        ),
                      ),
                    ),
                    child: Text('Enregistrer',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    child: Text('Annuler',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveChanges,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: ResponsiveUtils.getFluidPadding(
                        context,
                        mobile: const EdgeInsets.symmetric(vertical: 12),
                        tablet: const EdgeInsets.symmetric(vertical: 14),
                        desktop: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getFluidBorderRadius(context, mobile: 6, tablet: 7, desktop: 8),
                        ),
                      ),
                    ),
                    child: Text('Enregistrer',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getFluidSpacing(context, mobile: 12, tablet: 14, desktop: 16)),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _isEditing = false;
                      });
                    },
                    child: Text('Annuler',
                      style: TextStyle(
                        fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 14, tablet: 15, desktop: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 11, desktop: 12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: ResponsiveUtils.getFluidSpacing(context, mobile: 100, tablet: 110, desktop: 120),
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
                fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: ResponsiveUtils.getFluidSpacing(context, mobile: 10, tablet: 11, desktop: 12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: ResponsiveUtils.getFluidFontSize(context, mobile: 13, tablet: 14, desktop: 15),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final clientService = Provider.of<ClientService>(context, listen: false);
    final client = authService.currentClient!;

    final updatedClient = client.copyWith(
      nom: _nomController.text.trim(),
      telephone: _telephoneController.text.trim(),
      adresse: _adresseController.text.trim().isEmpty ? null : _adresseController.text.trim(),
      lastModifiedAt: DateTime.now(),
    );

    final success = await clientService.updateClient(updatedClient);

    if (success && mounted) {
      // Mettre à jour le client dans AuthService
      authService.updateCurrentClient(updatedClient);
      
      setState(() {
        _isEditing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profil mis à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erreur lors de la mise à jour'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Changer le mot de passe'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pour changer votre mot de passe :'),
            SizedBox(height: 16),
            Text('1. Rendez-vous dans votre shop UCASH'),
            Text('2. Présentez une pièce d\'identité'),
            Text('3. L\'agent pourra modifier votre mot de passe'),
            SizedBox(height: 16),
            Text(
              'Cette mesure garantit la sécurité de votre compte.',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Compris'),
          ),
        ],
      ),
    );
  }

  void _showContactSupportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contacter le Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Support Partenaire UCASH'),
            SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.phone, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('+243 XXX XXX XXX'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.email, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('support@ucash.cd'),
              ],
            ),
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.schedule, color: Color(0xFFDC2626)),
                SizedBox(width: 8),
                Text('Lun-Ven: 8h-18h'),
              ],
            ),
            SizedBox(height: 16),
            Text(
              'Ou rendez-vous dans n\'importe quel shop UCASH',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }
}
