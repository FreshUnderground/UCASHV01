import 'package:flutter/material.dart';
import '../models/devise_model.dart';
import '../models/shop_model.dart';
import '../services/taux_change_service.dart';

/// Widget affichant la conversion d'un montant entre deux devises
class ConversionDeviseWidget extends StatelessWidget {
  final double montant;
  final String deviseSource;
  final String deviseCible;
  final bool showDetails;
  
  const ConversionDeviseWidget({
    super.key,
    required this.montant,
    required this.deviseSource,
    required this.deviseCible,
    this.showDetails = true,
  });

  @override
  Widget build(BuildContext context) {
    final tauxService = TauxChangeService();
    final conversion = tauxService.calculerInteretConversion(
      montantSource: montant,
      deviseSource: deviseSource,
      deviseCible: deviseCible,
    );

    if (deviseSource == deviseCible) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.currency_exchange, size: 20, color: Colors.blue[700]),
              const SizedBox(width: 8),
              Text(
                'Conversion de devise',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Montant source
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Montant en $deviseSource:'),
              Text(
                tauxService.formaterMontant(montant, deviseSource),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          
          // Taux de change
          if (showDetails) ...[
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Taux de change:', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                Text(
                  '1 $deviseSource = ${conversion['taux'].toStringAsFixed(2)} $deviseCible',
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ],
          
          const Divider(),
          
          // Montant converti
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Equivalent en $deviseCible:', style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(
                tauxService.formaterMontant(conversion['montantConverti'], deviseCible),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.blue[900],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget calculateur de conversion interactif
class ConversionCalculator extends StatefulWidget {
  final ShopModel shop;
  final Function(double montant, String devise)? onConversionComplete;
  
  const ConversionCalculator({
    super.key,
    required this.shop,
    this.onConversionComplete,
  });

  @override
  State<ConversionCalculator> createState() => _ConversionCalculatorState();
}

class _ConversionCalculatorState extends State<ConversionCalculator> {
  final _montantController = TextEditingController();
  String? _deviseSource;
  String? _deviseCible;
  double? _montantConverti;

  @override
  void initState() {
    super.initState();
    final devises = widget.shop.devisesSupportees;
    if (devises.isNotEmpty) {
      _deviseSource = devises.first;
      _deviseCible = devises.length > 1 ? devises[1] : devises.first;
    }
  }

  @override
  void dispose() {
    _montantController.dispose();
    super.dispose();
  }

  void _calculer() {
    final montant = double.tryParse(_montantController.text);
    if (montant == null || _deviseSource == null || _deviseCible == null) {
      return;
    }

    final tauxService = TauxChangeService();
    final resultat = tauxService.convertir(
      montant: montant,
      deviseSource: _deviseSource!,
      deviseCible: _deviseCible!,
    );

    setState(() {
      _montantConverti = resultat;
    });

    widget.onConversionComplete?.call(resultat, _deviseCible!);
  }

  void _inverser() {
    setState(() {
      final temp = _deviseSource;
      _deviseSource = _deviseCible;
      _deviseCible = temp;
      _calculer();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devises = widget.shop.devisesSupportees;
    
    if (devises.length < 2) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'Ce shop utilise uniquement ${devises.first}. La conversion n\'est pas disponible.',
          style: TextStyle(color: Colors.grey[600]),
        ),
      );
    }

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calculate, color: Colors.blue[700]),
                const SizedBox(width: 8),
                const Text(
                  'Calculateur de conversion',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Montant a convertir
            TextField(
              controller: _montantController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Montant a convertir',
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.money),
                suffixText: _deviseSource,
              ),
              onChanged: (_) => _calculer(),
            ),
            
            const SizedBox(height: 16),
            
            // Selection des devises
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _deviseSource,
                    decoration: const InputDecoration(
                      labelText: 'De',
                      border: OutlineInputBorder(),
                    ),
                    items: devises.map((devise) {
                      return DropdownMenuItem(
                        value: devise,
                        child: Text(devise),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _deviseSource = value;
                        _calculer();
                      });
                    },
                  ),
                ),
                
                const SizedBox(width: 8),
                
                IconButton(
                  icon: const Icon(Icons.swap_horiz),
                  onPressed: _inverser,
                  tooltip: 'Inverser les devises',
                  color: Colors.blue[700],
                ),
                
                const SizedBox(width: 8),
                
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _deviseCible,
                    decoration: const InputDecoration(
                      labelText: 'Vers',
                      border: OutlineInputBorder(),
                    ),
                    items: devises.map((devise) {
                      return DropdownMenuItem(
                        value: devise,
                        child: Text(devise),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _deviseCible = value;
                        _calculer();
                      });
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Resultat
            if (_montantConverti != null && _deviseSource != _deviseCible)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Resultat:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          TauxChangeService().formaterMontant(_montantConverti!, _deviseCible!),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.green[900],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ConversionDeviseWidget(
                      montant: double.tryParse(_montantController.text) ?? 0,
                      deviseSource: _deviseSource!,
                      deviseCible: _deviseCible!,
                      showDetails: true,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Widget compact pour afficher le taux de change
class TauxChangeIndicator extends StatelessWidget {
  final String deviseSource;
  final String deviseCible;
  
  const TauxChangeIndicator({
    super.key,
    required this.deviseSource,
    required this.deviseCible,
  });

  @override
  Widget build(BuildContext context) {
    if (deviseSource == deviseCible) {
      return const SizedBox.shrink();
    }

    final tauxService = TauxChangeService();
    final taux = tauxService.getTaux(deviseSource, deviseCible);

    if (taux == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, size: 14, color: Colors.orange[900]),
          const SizedBox(width: 4),
          Text(
            '1 $deviseSource = ${taux.taux.toStringAsFixed(2)} $deviseCible',
            style: TextStyle(
              fontSize: 11,
              color: Colors.orange[900],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
