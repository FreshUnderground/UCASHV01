import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/virtual_transaction_model.dart';

/// Card moderne et animée pour afficher une transaction virtuelle
class ModernTransactionCard extends StatelessWidget {
  final VirtualTransactionModel transaction;
  final bool isEnAttente;
  final VoidCallback onTap;
  final VoidCallback? onServe;

  const ModernTransactionCard({
    super.key,
    required this.transaction,
    this.isEnAttente = false,
    required this.onTap,
    this.onServe,
  });

  @override
  Widget build(BuildContext context) {
    Color statutColor;
    IconData statutIcon;
    
    switch (transaction.statut) {
      case VirtualTransactionStatus.enAttente:
        statutColor = Colors.orange;
        statutIcon = Icons.hourglass_empty;
        break;
      case VirtualTransactionStatus.validee:
        statutColor = Colors.green;
        statutIcon = Icons.check_circle;
        break;
      case VirtualTransactionStatus.annulee:
        statutColor = Colors.red;
        statutIcon = Icons.cancel;
        break;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                colors: [
                  Colors.white,
                  statutColor.withOpacity(0.02),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: statutColor.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête avec statut et date
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [statutColor, statutColor.withOpacity(0.7)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: statutColor.withOpacity(0.15),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statutIcon, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(
                              transaction.statutLabel,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.access_time, size: 10, color: Colors.grey[600]),
                            const SizedBox(width: 2),
                            Text(
                              DateFormat('dd/MM HH:mm').format(transaction.dateEnregistrement),
                              style: TextStyle(fontSize: 9, color: Colors.grey[700], fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Référence et SIM
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoChip(
                          Icons.tag,
                          'Réf',
                          transaction.reference,
                          Colors.blue,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildInfoChip(
                          Icons.sim_card,
                          'SIM',
                          transaction.simNumero,
                          const Color(0xFF48bb78),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  
                  // Montants
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.grey.shade50,
                          Colors.grey.shade100,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildAmountDisplay(
                            'Virtuel',
                            transaction.montantVirtuel,
                            Icons.phone_android,
                            Colors.purple,
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.grey.shade300,
                        ),
                        Expanded(
                          child: _buildAmountDisplay(
                            'Cash',
                            transaction.montantCash,
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                        if (transaction.frais > 0) ...[
                          Container(
                            width: 1,
                            height: 40,
                            color: Colors.grey.shade300,
                          ),
                          Expanded(
                            child: _buildAmountDisplay(
                              'Frais',
                              transaction.frais,
                              Icons.account_balance_wallet,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // Client
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.blue.shade100,
                          child: Icon(Icons.person, size: 14, color: Colors.blue.shade700),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                transaction.clientNom ?? 'N/A',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (transaction.clientTelephone != null && transaction.clientTelephone!.isNotEmpty)
                                Text(
                                  transaction.clientTelephone!,
                                  style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Bouton servir pour transactions en attente
                  if (isEnAttente && onServe != null) ...[
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: onServe,
                        icon: const Icon(Icons.check_circle, size: 16),
                        label: const Text('Servir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 1,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Widget pour afficher un chip d'information
  Widget _buildInfoChip(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 8, color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                Text(
                  value,
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Widget pour afficher un montant
  Widget _buildAmountDisplay(String label, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 8, color: Colors.grey[600], fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 1),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
