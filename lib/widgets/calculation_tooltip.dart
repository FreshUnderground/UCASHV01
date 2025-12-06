import 'package:flutter/material.dart';

/// A reusable tooltip widget for displaying calculation details and formulas
class CalculationTooltip extends StatelessWidget {
  final String title;
  final String description;
  final String formula;
  final List<String> components;
  final Widget child;

  const CalculationTooltip({
    Key? key,
    required this.title,
    required this.description,
    required this.formula,
    required this.components,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _buildTooltipMessage(),
      textStyle: const TextStyle(
        fontSize: 14,
        height: 1.5,
      ),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
      ),
      verticalOffset: 20,
      preferBelow: false,
      child: child,
    );
  }

  String _buildTooltipMessage() {
    final buffer = StringBuffer();
    buffer.writeln(title);
    buffer.writeln('=' * title.length);
    buffer.writeln();
    buffer.writeln(description);
    buffer.writeln();
    buffer.writeln('Formula:');
    buffer.writeln(formula);
    buffer.writeln();
    buffer.writeln('Components:');
    
    for (int i = 0; i < components.length; i++) {
      buffer.writeln('${i + 1}. ${components[i]}');
    }
    
    return buffer.toString();
  }
}

/// A more detailed dialog for showing calculation breakdowns
class CalculationDetailsDialog extends StatelessWidget {
  final String title;
  final String description;
  final String formula;
  final List<CalculationComponent> components;
  final String businessLogic;

  const CalculationDetailsDialog({
    Key? key,
    required this.title,
    required this.description,
    required this.formula,
    required this.components,
    required this.businessLogic,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'Formula:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                formula,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Components:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            ...components.map((component) => _buildComponentItem(component)),
            const SizedBox(height: 16),
            const Text(
              'Business Logic:',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(businessLogic),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildComponentItem(CalculationComponent component) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: component.isPositive ? Colors.green[100] : Colors.red[100],
              shape: BoxShape.circle,
              border: Border.all(
                color: component.isPositive ? Colors.green : Colors.red,
              ),
            ),
            child: Center(
              child: Text(
                component.isPositive ? '+' : '-',
                style: TextStyle(
                  color: component.isPositive ? Colors.green : Colors.red,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  component.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  component.description,
                  style: const TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CalculationComponent {
  final String name;
  final String description;
  final bool isPositive;

  CalculationComponent({
    required this.name,
    required this.description,
    required this.isPositive,
  });
}