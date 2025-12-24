import 'package:flutter/material.dart';
import 'documentation_widget.dart';

class HelpButtonWidget extends StatelessWidget {
  final String? contextualHelp;
  final Color? color;
  final double? size;
  final bool showLabel;

  const HelpButtonWidget({
    super.key,
    this.contextualHelp,
    this.color,
    this.size,
    this.showLabel = false,
  });

  @override
  Widget build(BuildContext context) {
    final buttonColor = color ?? const Color(0xFFDC2626);
    final iconSize = size ?? 24.0;

    if (showLabel) {
      return ElevatedButton.icon(
        onPressed: () => _openDocumentation(context),
        icon: Icon(Icons.help_outline, size: iconSize),
        label: const Text('Aide'),
        style: ElevatedButton.styleFrom(
          backgroundColor: buttonColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    }

    return IconButton(
      onPressed: () => _openDocumentation(context),
      icon: Icon(
        Icons.help_outline,
        color: buttonColor,
        size: iconSize,
      ),
      tooltip: 'Ouvrir la documentation',
      padding: const EdgeInsets.all(8),
    );
  }

  void _openDocumentation(BuildContext context) {
    if (contextualHelp != null) {
      _showContextualHelp(context);
    } else {
      _showFullDocumentation(context);
    }
  }

  void _showContextualHelp(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 500),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFFDC2626),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(8),
                    topRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.help_outline,
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Aide Contextuelle',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    contextualHelp!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              
              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _showFullDocumentation(context);
                        },
                        icon: const Icon(Icons.book),
                        label: const Text('Documentation Complète'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFullDocumentation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DocumentationWidget(),
      ),
    );
  }
}

// Widget pour aide flottante
class FloatingHelpButton extends StatelessWidget {
  final String? contextualHelp;

  const FloatingHelpButton({
    super.key,
    this.contextualHelp,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: FloatingActionButton(
        onPressed: () => _openDocumentation(context),
        backgroundColor: const Color(0xFFDC2626),
        foregroundColor: Colors.white,
        tooltip: 'Aide et Documentation',
        child: const Icon(Icons.help_outline),
      ),
    );
  }

  void _openDocumentation(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const DocumentationWidget(),
      ),
    );
  }
}

// Widget pour aide dans AppBar
class AppBarHelpAction extends StatelessWidget {
  final String? contextualHelp;

  const AppBarHelpAction({
    super.key,
    this.contextualHelp,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: () => _openDocumentation(context),
      icon: const Icon(Icons.help_outline),
      tooltip: 'Aide et Documentation',
    );
  }

  void _openDocumentation(BuildContext context) {
    if (contextualHelp != null) {
      _showQuickHelp(context);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const DocumentationWidget(),
        ),
      );
    }
  }

  void _showQuickHelp(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        builder: (context, scrollController) => Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              // Header
              Row(
                children: [
                  const Icon(
                    Icons.help_outline,
                    color: Color(0xFFDC2626),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Aide Rapide',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const DocumentationWidget(),
                        ),
                      );
                    },
                    child: const Text('Documentation Complète'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Text(
                    contextualHelp!,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
