import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/sim_model.dart';
import '../services/virtual_exchange_service.dart';
import '../services/sim_service.dart';
import '../services/auth_service.dart';

class CreateVirtualExchangeDialog extends StatefulWidget {
  const CreateVirtualExchangeDialog({Key? key}) : super(key: key);

  @override
  State<CreateVirtualExchangeDialog> createState() => _CreateVirtualExchangeDialogState();
}

class _CreateVirtualExchangeDialogState extends State<CreateVirtualExchangeDialog> {
  final _formKey = GlobalKey<FormState>();
  final _montantController = TextEditingController();
  final _notesController = TextEditingController();
  
  SimModel? _simSource;
  SimModel? _simDestination;
  String _devise = 'USD';
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _createExchange() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_simSource == null || _simDestination == null) {
      setState(() => _errorMessage = 'Sélectionner les SIMs source et destination');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final montant = double.parse(_montantController.text);
      final authService = Provider.of<AuthService>(context, listen: false);
      
      final exchange = await VirtualExchangeService.instance.createExchange(
        simSource: _simSource!.numero,
        simDestination: _simDestination!.numero,
        montant: montant,
        devise: _devise,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        agentId: authService.currentUser?.id,
        agentUsername: authService.currentUser?.username,
      );

      if (exchange != null && mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('✅ Échange créé: ${exchange.reference}'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _errorMessage = VirtualExchangeService.instance.errorMessage ?? 'Erreur création');
      }
    } catch (e) {
      setState(() => _errorMessage = 'Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SimService>(
      builder: (context, simService, child) {
        final authService = Provider.of<AuthService>(context, listen: false);
        final currentShopId = authService.currentUser?.shopId;
        
        final availableSims = simService.sims
            .where((sim) => sim.shopId == currentShopId && sim.statut == SimStatus.active)
            .toList();

        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.swap_horiz, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Échange Virtuel SIM → SIM'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(_errorMessage!, style: TextStyle(color: Colors.red.shade700)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  DropdownButtonFormField<SimModel>(
                    value: _simSource,
                    decoration: const InputDecoration(
                      labelText: 'SIM Source',
                      border: OutlineInputBorder(),
                    ),
                    items: availableSims.map((sim) => DropdownMenuItem(
                      value: sim,
                      child: Text('${sim.numero} (${sim.operateur})'),
                    )).toList(),
                    onChanged: (sim) => setState(() => _simSource = sim),
                    validator: (value) => value == null ? 'Sélectionner SIM source' : null,
                  ),
                  const SizedBox(height: 16),

                  DropdownButtonFormField<SimModel>(
                    value: _simDestination,
                    decoration: const InputDecoration(
                      labelText: 'SIM Destination',
                      border: OutlineInputBorder(),
                    ),
                    items: availableSims.map((sim) => DropdownMenuItem(
                      value: sim,
                      child: Text('${sim.numero} (${sim.operateur})'),
                    )).toList(),
                    onChanged: (sim) => setState(() => _simDestination = sim),
                    validator: (value) => value == null ? 'Sélectionner SIM destination' : null,
                  ),
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextFormField(
                          controller: _montantController,
                          decoration: const InputDecoration(
                            labelText: 'Montant',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Montant requis';
                            final montant = double.tryParse(value);
                            if (montant == null || montant <= 0) return 'Montant invalide';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _devise,
                          decoration: const InputDecoration(
                            labelText: 'Devise',
                            border: OutlineInputBorder(),
                          ),
                          items: ['USD', 'CDF'].map((devise) => DropdownMenuItem(
                            value: devise,
                            child: Text(devise),
                          )).toList(),
                          onChanged: (devise) => setState(() => _devise = devise!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optionnel)',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: _isLoading ? null : _createExchange,
              child: _isLoading 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Créer Échange'),
            ),
          ],
        );
      },
    );
  }
}
