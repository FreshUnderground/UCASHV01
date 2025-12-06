# Script to fix the formatting issue in rapport_cloture_service.dart
file_path = r'c:\laragon1\www\UCASHV01\lib\services\rapport_cloture_service.dart'

# Read the file
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the problematic line
old_line = "    debugPrint('   FRAIS: Solde total = ${soldeFraisTotal.toStringAsFixed(2)} USD');    debugPrint('   DÉPENSE: Dépôts du jour = ${depotsDepense.toStringAsFixed(2)} USD');"
new_lines = "    debugPrint('   FRAIS: Solde total = ${soldeFraisTotal.toStringAsFixed(2)} USD');\n    debugPrint('   DÉPENSE: Dépôts du jour = ${depotsDepense.toStringAsFixed(2)} USD');"

# Perform the replacement
content = content.replace(old_line, new_lines)

# Write the file back
with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("File fixed successfully!")