import 'package:flutter/material.dart';
import '../services/currency_service.dart';

/// Widget pour afficher les montants cash toujours en USD
class CashAmountDisplay extends StatelessWidget {
  final double montantVirtuel;
  final String devise;
  final double? frais;
  final TextStyle? style;
  final bool showLabel;

  const CashAmountDisplay({
    super.key,
    required this.montantVirtuel,
    required this.devise,
    this.frais,
    this.style,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    double cashUsd;
    
    if (devise == 'CDF') {
      // Conversion CDF → USD
      final montantApresCommission = montantVirtuel - (frais ?? 0);
      cashUsd = CurrencyService.instance.convertCdfToUsd(montantApresCommission);
    } else {
      // Déjà en USD
      cashUsd = montantVirtuel - (frais ?? 0);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          const Icon(
            Icons.attach_money,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 4),
          Text(
            'Cash: ',
            style: style?.copyWith(fontWeight: FontWeight.w500) ?? 
                   const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
        Text(
          '\$${cashUsd.toStringAsFixed(2)} USD',
          style: style?.copyWith(
            color: Colors.green[700],
            fontWeight: FontWeight.bold,
          ) ?? TextStyle(
            color: Colors.green[700],
            fontWeight: FontWeight.bold,
          ),
        ),
        if (devise == 'CDF') ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: Colors.blue[200]!),
            ),
            child: Text(
              'Converti',
              style: TextStyle(
                fontSize: 10,
                color: Colors.blue[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Widget pour afficher le détail de conversion
class ConversionDetailWidget extends StatelessWidget {
  final double montantVirtuel;
  final String devise;
  final double frais;

  const ConversionDetailWidget({
    super.key,
    required this.montantVirtuel,
    required this.devise,
    required this.frais,
  });

  @override
  Widget build(BuildContext context) {
    if (devise == 'USD') {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Calcul du cash (USD):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Montant virtuel: \$${montantVirtuel.toStringAsFixed(2)} USD'),
            Text('Commission: \$${frais.toStringAsFixed(2)} USD'),
            const Divider(),
            Text(
              'Cash à remettre: \$${(montantVirtuel - frais).toStringAsFixed(2)} USD',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    } else {
      final montantApresCommission = montantVirtuel - frais;
      final cashUsd = CurrencyService.instance.convertCdfToUsd(montantApresCommission);
      final taux = CurrencyService.instance.tauxCdfToUsd;

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
            const Text(
              'Calcul du cash (CDF → USD):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Montant virtuel: ${montantVirtuel.toStringAsFixed(0)} CDF'),
            Text('Commission: ${frais.toStringAsFixed(0)} CDF'),
            Text('Après commission: ${montantApresCommission.toStringAsFixed(0)} CDF'),
            const SizedBox(height: 4),
            Text(
              'Taux de change: 1 USD = ${taux.toStringAsFixed(0)} CDF',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const Divider(),
            Text(
              'Cash à remettre: \$${cashUsd.toStringAsFixed(2)} USD',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
          ],
        ),
      );
    }
  }
}
