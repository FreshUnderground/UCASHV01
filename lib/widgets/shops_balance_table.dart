import 'package:flutter/material.dart';

class ShopsBalanceTable extends StatelessWidget {
  const ShopsBalanceTable({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Soldes par Shop',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D47A1),
                  ),
                ),
                Row(
                  children: [
                    _buildActionButton(
                      'Actualiser',
                      Icons.refresh,
                      const Color(0xFF1976D2),
                      () {},
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      'PDF',
                      Icons.picture_as_pdf,
                      const Color(0xFFDC2626),
                      () {},
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      'CSV',
                      Icons.file_download,
                      const Color(0xFF388E3C),
                      () {},
                    ),
                  ],
                ),
              ],
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: MaterialStateProperty.all(Colors.grey[50]),
              columns: const [
                DataColumn(
                  label: Text(
                    'Shop',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Localisation',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataColumn(
                  label: Text(
                    'Capital Cash',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
                // DataColumn(
                //   label: Text(
                //     'Airtel Money',
                //     style: TextStyle(fontWeight: FontWeight.bold),
                //   ),
                // ),
                // DataColumn(
                //   label: Text(
                //     'M-Pesa',
                //     style: TextStyle(fontWeight: FontWeight.bold),
                //   ),
                // ),
                // DataColumn(
                //   label: Text(
                //     'Orange Money',
                //     style: TextStyle(fontWeight: FontWeight.bold),
                //   ),
                // ),
                DataColumn(
                  label: Text(
                    'Total Capital',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
              rows: _buildTableRows(),
            ),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildTableRows() {
    // Données d'exemple - à remplacer par les vraies données
    final shops = [
    ];

    return shops.map((shop) {
      return DataRow(
        cells: [
          DataCell(
            Text(
              shop['shop']!,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          DataCell(Text(shop['localisation']!)),
          DataCell(_buildAmountCell(shop['cash']!, Colors.green)),
          // MASQUÉ: Airtel Money, M-Pesa, Orange Money ne doivent pas être visibles
          // DataCell(_buildAmountCell(shop['airtel']!, const Color(0xFFE65100))),
          // DataCell(_buildAmountCell(shop['mpesa']!, const Color(0xFF388E3C))),
          // DataCell(_buildAmountCell(shop['orange']!, const Color(0xFFFF9800))),
          DataCell(
            Text(
              '${shop['total']!} USD',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF0D47A1),
              ),
            ),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildAmountCell(String amount, Color color) {
    return Text(
      '$amount USD',
      style: TextStyle(
        fontWeight: FontWeight.w500,
        color: color,
      ),
    );
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 2,
      ),
    );
  }
}
