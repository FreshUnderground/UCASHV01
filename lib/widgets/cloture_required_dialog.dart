import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../services/rapport_cloture_service.dart';
import '../services/auth_service.dart';
import '../models/cloture_caisse_model.dart';
import '../models/rapport_cloture_model.dart';
import 'rapportcloture.dart';

/// Dialog pour afficher les jours non clôturés et proposer de les clôturer
/// Ce dialog s'affiche quand l'agent essaie d'accéder aux menus Operations, Validations, Flot
class ClotureRequiredDialog extends StatefulWidget {
  final int shopId;
  final List<DateTime> joursNonClotures;
  final VoidCallback? onCloturesCompleted;

  const ClotureRequiredDialog({
    super.key,
    required this.shopId,
    required this.joursNonClotures,
    this.onCloturesCompleted,
  });

  /// Afficher le dialog et retourner true si les clôtures ont été effectuées
  static Future<bool> show(
    BuildContext context, {
    required int shopId,
    required List<DateTime> joursNonClotures,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClotureRequiredDialog(
        shopId: shopId,
        joursNonClotures: joursNonClotures,
      ),
    );
    return result ?? false;
  }

  @override
  State<ClotureRequiredDialog> createState() => _ClotureRequiredDialogState();
}

class _ClotureRequiredDialogState extends State<ClotureRequiredDialog> {
  bool _isLoading = false;
  ClotureCaisseModel? _derniereCloture;
  RapportClotureModel? _rapportPremierJour; // Rapport du premier jour à clôturer
  String? _errorMessage;

  // Contrôleurs pour les montants
  final _cashController = TextEditingController();
  final _airtelController = TextEditingController();
  final _mpesaController = TextEditingController();
  final _orangeController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDerniereCloture();
  }

  @override
  void dispose() {
    _cashController.dispose();
    _airtelController.dispose();
    _mpesaController.dispose();
    _orangeController.dispose();
    super.dispose();
  }

  Future<void> _loadDerniereCloture() async {
    setState(() => _isLoading = true);

    try {
      final derniereCloture = await RapportClotureService.instance.getDerniereCloture(widget.shopId);
      
      // Générer le rapport pour le premier jour à clôturer pour obtenir le Cash Disponible
      RapportClotureModel? rapport;
      if (widget.joursNonClotures.isNotEmpty) {
        final premierJour = widget.joursNonClotures.first;
        rapport = await RapportClotureService.instance.genererRapport(
          shopId: widget.shopId,
          date: premierJour,
        );
        debugPrint('💰 Cash Disponible du ${premierJour.toIso8601String().split('T')[0]}:');
        debugPrint('   Cash: ${rapport.cashDisponibleCash.toStringAsFixed(2)} USD');
        debugPrint('   Airtel: ${rapport.cashDisponibleAirtelMoney.toStringAsFixed(2)} USD');
        debugPrint('   MPesa: ${rapport.cashDisponibleMPesa.toStringAsFixed(2)} USD');
        debugPrint('   Orange: ${rapport.cashDisponibleOrangeMoney.toStringAsFixed(2)} USD');
        debugPrint('   TOTAL: ${rapport.cashDisponibleTotal.toStringAsFixed(2)} USD');
      }
      
      if (mounted) {
        setState(() {
          _derniereCloture = derniereCloture;
          _rapportPremierJour = rapport;
          _isLoading = false;
          
          // Pré-remplir les montants avec le CASH DISPONIBLE du jour à clôturer
          if (rapport != null) {
            _cashController.text = rapport.cashDisponibleCash.toStringAsFixed(2);
            _airtelController.text = rapport.cashDisponibleAirtelMoney.toStringAsFixed(2);
            _mpesaController.text = rapport.cashDisponibleMPesa.toStringAsFixed(2);
            _orangeController.text = rapport.cashDisponibleOrangeMoney.toStringAsFixed(2);
          } else if (derniereCloture != null) {
            // Fallback: utiliser la dernière clôture si le rapport n'est pas disponible
            _cashController.text = derniereCloture.soldeSaisiCash.toStringAsFixed(2);
            _airtelController.text = derniereCloture.soldeSaisiAirtelMoney.toStringAsFixed(2);
            _mpesaController.text = derniereCloture.soldeSaisiMPesa.toStringAsFixed(2);
            _orangeController.text = derniereCloture.soldeSaisiOrangeMoney.toStringAsFixed(2);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cloturerJoursManquants() async {
    if (!mounted) return;

    final cash = double.tryParse(_cashController.text) ?? 0.0;
    final airtel = double.tryParse(_airtelController.text) ?? 0.0;
    final mpesa = double.tryParse(_mpesaController.text) ?? 0.0;
    final orange = double.tryParse(_orangeController.text) ?? 0.0;

    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final username = authService.currentUser?.username ?? 'Agent';

      final success = await RapportClotureService.instance.cloturerPlusieursJours(
        shopId: widget.shopId,
        dates: widget.joursNonClotures,
        soldeSaisiCash: cash,
        soldeSaisiAirtelMoney: airtel,
        soldeSaisiMPesa: mpesa,
        soldeSaisiOrangeMoney: orange,
        cloturePar: username,
      );

      if (mounted) {
        if (success) {
          widget.onCloturesCompleted?.call();
          Navigator.of(context).pop(true);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ${widget.joursNonClotures.length} jour(s) clôturé(s) avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _errorMessage = 'Échec de la clôture';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _ouvrirRapportCloture() {
    // Ouvrir le rapport de clôture pour le premier jour non clôturé
    if (widget.joursNonClotures.isNotEmpty) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RapportCloture(
            shopId: widget.shopId,
            dateInitiale: widget.joursNonClotures.first,
          ),
        ),
      ).then((_) {
        // Fermer le dialog après retour du rapport
        if (mounted) {
          Navigator.of(context).pop(true);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 600;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: isMobile ? size.width * 0.95 : 500,
        constraints: BoxConstraints(maxHeight: size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // En-tête
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '🔒 Clôture Requise',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.joursNonClotures.length} jour(s) à clôturer',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Contenu
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Message d'explication
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Pour accéder aux menus, vous devez d\'abord clôturer les journées précédentes.',
                              style: TextStyle(color: Colors.orange.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Liste des jours non clôturés
                    const Text(
                      '📅 Jours à clôturer:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: widget.joursNonClotures.map((date) {
                          final jourSemaine = _getJourSemaine(date.weekday);
                          return ListTile(
                            dense: true,
                            leading: const Icon(Icons.calendar_today, color: Color(0xFFDC2626)),
                            title: Text(
                              dateFormat.format(date),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(jourSemaine),
                          );
                        }).toList(),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Cash Disponible du jour à clôturer (calculé)
                    if (_rapportPremierJour != null) ...[  
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.account_balance_wallet, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Cash Disponible',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            _buildCashDispoRow('Cash (USD)', _rapportPremierJour!.cashDisponibleCash, Colors.green),
                            const Divider(height: 16),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Compte FRAIS du jour
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.attach_money, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Compte FRAIS',
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            _buildCashDispoRow('Frais Antérieur', _rapportPremierJour!.soldeFraisAnterieur, Colors.grey),
                            _buildCashDispoRow('+ Frais encaissés', _rapportPremierJour!.commissionsFraisDuJour, Colors.green),
                            _buildCashDispoRow('- Sortie Frais', _rapportPremierJour!.retraitsFraisDuJour, Colors.red),
                            const Divider(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '= Solde Frais du jour',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade900,
                                  ),
                                ),
                                Text(
                                  '${(_rapportPremierJour!.soldeFraisAnterieur + _rapportPremierJour!.commissionsFraisDuJour - _rapportPremierJour!.retraitsFraisDuJour).toStringAsFixed(2)} USD',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Dernière clôture (Solde Antérieur)
                    if (_derniereCloture != null) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'Clôture du : ${dateFormat.format(_derniereCloture!.dateCloture)}',
                                  style: TextStyle(
                                    color: Colors.green.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Solde total: ${_derniereCloture!.soldeSaisiTotal.toStringAsFixed(2)} USD',
                              style: TextStyle(color: Colors.green.shade800),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Formulaire de saisie des montants
                    const Text(
                      'Montants pour la clôture groupée:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    // Champs de saisie
                    _buildMontantField('Cash (USD)', _cashController, Icons.attach_money, Colors.green),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.red),
                            const SizedBox(width: 8),
                            Expanded(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red))),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Boutons d'action
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Bouton principal - Clôturer tous les jours
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _cloturerJoursManquants,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.lock),
                      label: Text(
                        _isLoading
                            ? 'Clôture en cours...'
                            : 'Clôturer ${widget.joursNonClotures.length} jour(s)',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Bouton secondaire - Voir le rapport détaillé
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _isLoading ? null : _ouvrirRapportCloture,
                      icon: const Icon(Icons.assessment),
                      label: const Text('Voir le Rapport de Clôture'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Bouton annuler (bloqué - ne peut pas continuer sans clôturer)
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text(
                      'Annuler (Accès bloqué)',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCashDispoRow(String label, double value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(Icons.circle, color: color, size: 10),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Colors.grey.shade700)),
            ],
          ),
          Text(
            '${value.toStringAsFixed(2)} USD',
            style: TextStyle(fontWeight: FontWeight.w600, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildMontantField(String label, TextEditingController controller, IconData icon, Color color) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  String _getJourSemaine(int weekday) {
    switch (weekday) {
      case 1: return 'Lundi';
      case 2: return 'Mardi';
      case 3: return 'Mercredi';
      case 4: return 'Jeudi';
      case 5: return 'Vendredi';
      case 6: return 'Samedi';
      case 7: return 'Dimanche';
      default: return '';
    }
  }
}
