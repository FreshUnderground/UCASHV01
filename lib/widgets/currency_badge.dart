import 'package:flutter/material.dart';

/// Badge pour afficher la devise d'une transaction
class CurrencyBadge extends StatelessWidget {
  final String devise;
  final double? size;
  final bool showIcon;

  const CurrencyBadge({
    super.key,
    required this.devise,
    this.size,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final isUsd = devise == 'USD';
    final color = isUsd ? Colors.green : Colors.blue;
    final icon = isUsd ? Icons.attach_money : Icons.monetization_on;
    final label = isUsd ? 'USD' : 'CDF';
    final fontSize = size ?? 10;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.6,
        vertical: fontSize * 0.2,
      ),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(fontSize * 0.4),
        border: Border.all(color: color[200]!, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              icon,
              size: fontSize * 0.9,
              color: color[700],
            ),
            SizedBox(width: fontSize * 0.3),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: fontSize,
              color: color[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge pour afficher la conversion CDF → USD
class ConversionBadge extends StatelessWidget {
  final double montantCdf;
  final double montantUsd;
  final double? size;

  const ConversionBadge({
    super.key,
    required this.montantCdf,
    required this.montantUsd,
    this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = size ?? 9;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: fontSize * 0.7,
        vertical: fontSize * 0.3,
      ),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(fontSize * 0.5),
        border: Border.all(color: Colors.orange[200]!, width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.swap_horiz,
            size: fontSize * 1.1,
            color: Colors.orange[700],
          ),
          SizedBox(width: fontSize * 0.4),
          Text(
            '${montantCdf.toStringAsFixed(0)} FC → \$${montantUsd.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: fontSize,
              color: Colors.orange[700],
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
