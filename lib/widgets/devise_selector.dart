import 'package:flutter/material.dart';
import '../models/devise_model.dart';
import '../models/shop_model.dart';

/// Widget de selection de devise base sur les devises supportees par le shop
class DeviseSelector extends StatelessWidget {
  final ShopModel shop;
  final String? deviseSelectionnee;
  final ValueChanged<String> onChanged;
  final bool enabled;
  
  const DeviseSelector({
    super.key,
    required this.shop,
    required this.deviseSelectionnee,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final devises = shop.devisesSupportees;
    
    // Si une seule devise, afficher simplement le texte
    if (devises.length == 1) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            Icon(Icons.attach_money, color: Colors.grey[700], size: 20),
            const SizedBox(width: 8),
            Text(
              _getDeviseLabel(devises.first),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }
    
    // Si 2 devises, afficher des boutons radio/chips
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Devise',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          children: devises.map((devise) {
            final isSelected = devise == deviseSelectionnee;
            return ChoiceChip(
              label: Text(_getDeviseLabel(devise)),
              selected: isSelected,
              onSelected: enabled ? (selected) {
                if (selected) {
                  onChanged(devise);
                }
              } : null,
              selectedColor: const Color(0xFF48bb78),
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[800],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              avatar: isSelected ? const Icon(Icons.check_circle, color: Colors.white, size: 18) : null,
            );
          }).toList(),
        ),
      ],
    );
  }
  
  String _getDeviseLabel(String code) {
    final devise = DeviseExtension.fromCode(code);
    if (devise == null) return code;
    return '${devise.symbole} ${devise.code} - ${devise.nom}';
  }
}

/// Widget dropdown simple pour selection de devise
class DeviseDropdown extends StatelessWidget {
  final ShopModel shop;
  final String? deviseSelectionnee;
  final ValueChanged<String?> onChanged;
  final bool enabled;
  final String? label;
  
  const DeviseDropdown({
    super.key,
    required this.shop,
    required this.deviseSelectionnee,
    required this.onChanged,
    this.enabled = true,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final devises = shop.devisesSupportees;
    
    return DropdownButtonFormField<String>(
      value: deviseSelectionnee,
      decoration: InputDecoration(
        labelText: label ?? 'Devise',
        prefixIcon: const Icon(Icons.attach_money),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        filled: true,
        fillColor: enabled ? Colors.white : Colors.grey[100],
      ),
      items: devises.map((devise) {
        final deviseObj = DeviseExtension.fromCode(devise);
        return DropdownMenuItem(
          value: devise,
          child: Text(
            deviseObj != null 
                ? '${deviseObj.symbole} ${deviseObj.code}'
                : devise,
            style: const TextStyle(fontSize: 16),
          ),
        );
      }).toList(),
      onChanged: enabled ? onChanged : null,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Veuillez selectionner une devise';
        }
        return null;
      },
    );
  }
}

/// Widget d'affichage de montant avec devise
class MontantDevise extends StatelessWidget {
  final double montant;
  final String devise;
  final TextStyle? style;
  final bool showSymbole;
  
  const MontantDevise({
    super.key,
    required this.montant,
    required this.devise,
    this.style,
    this.showSymbole = true,
  });

  @override
  Widget build(BuildContext context) {
    final deviseObj = DeviseExtension.fromCode(devise);
    final symbole = deviseObj?.symbole ?? '';
    final code = deviseObj?.code ?? devise;
    
    return Text(
      showSymbole 
          ? '$symbole ${montant.toStringAsFixed(2)} $code'
          : '${montant.toStringAsFixed(2)} $code',
      style: style ?? const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}
