# Script to fix the truncated agent_operations_widget.dart file

file_path = r"c:\laragon1\www\UCASHV01\lib\widgets\agent_operations_widget.dart"

# Read the file content
with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Check if the file is truncated
if content.endswith("Text('"):
    # Add the missing content
    content += "Observation: ${operation.observation}'),\n"
    content += "          ],\n"
    content += "        ),\n"
    content += "        actions: [\n"
    content += "          TextButton(\n"
    content += "            onPressed: () => Navigator.of(context).pop(),\n"
    content += "            child: const Text('Fermer'),\n"
    content += "          ),\n"
    content += "        ],\n"
    content += "      ),\n"
    content += "    );\n"
    content += "  }\n"
    content += "}\n"
    
    # Write the fixed content back to the file
    with open(file_path, "w", encoding="utf-8") as f:
        f.write(content)
    
    print("File fixed successfully!")
else:
    print("File doesn't appear to be truncated at the expected location.")