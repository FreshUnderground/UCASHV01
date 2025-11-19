import 'dart:io';

void main() {
  final file = File(r'c:\laragon1\www\UCASHV01\lib\widgets\agent_operations_widget.dart');
  final content = file.readAsStringSync();
  
  // Check if the file is truncated
  if (content.endsWith("Text('")) {
    // Add the missing content
    final fixedContent = content + 
        'Observation: \${operation.observation}\'),\n' +
        '          ],\n' +
        '        ),\n' +
        '        actions: [\n' +
        '          TextButton(\n' +
        '            onPressed: () => Navigator.of(context).pop(),\n' +
        '            child: const Text(\'Fermer\'),\n' +
        '          ),\n' +
        '        ],\n' +
        '      ),\n' +
        '    );\n' +
        '  }\n' +
        '}\n';
    
    // Write the fixed content back to the file
    file.writeAsStringSync(fixedContent);
    print('File fixed successfully!');
  } else {
    print('File doesn\'t appear to be truncated at the expected location.');
  }
}