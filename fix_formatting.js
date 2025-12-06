const fs = require('fs');

// Read the file
let content = fs.readFileSync('c:\\laragon1\\www\\UCASHV01\\lib\\services\\rapport_cloture_service.dart', 'utf8');

// Define the problematic line and the replacement
const problematicLine = "    debugPrint('   FRAIS: Solde total = ${soldeFraisTotal.toStringAsFixed(2)} USD');    debugPrint('   DÉPENSE: Dépôts du jour = ${depotsDepense.toStringAsFixed(2)} USD');";
const replacementLines = "    debugPrint('   FRAIS: Solde total = ${soldeFraisTotal.toStringAsFixed(2)} USD');\n    debugPrint('   DÉPENSE: Dépôts du jour = ${depotsDepense.toStringAsFixed(2)} USD');";

// Replace the problematic line
content = content.replace(problematicLine, replacementLines);

// Write the file back
fs.writeFileSync('c:\\laragon1\\www\\UCASHV01\\lib\\services\\rapport_cloture_service.dart', content, 'utf8');

console.log('File fixed successfully!');