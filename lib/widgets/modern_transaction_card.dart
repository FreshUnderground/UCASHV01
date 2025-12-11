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
    final size = MediaQuery.of(context).size;
    final isCompact = size.width < 400;
    
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
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: statutColor.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(isCompact ? 10 : 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête compact avec statut et montant principal
                  Row(
                    children: [
                      // Badge statut compact
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statutColor,
                          borderRadius: BorderRadius.circular(6),
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
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      // Montant cash principal (mis en évidence)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '\$${transaction.montantCash.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: isCompact ? 16 : 18,
                              fontWeight: FontWeight.bold,
                              color: statutColor,
                            ),
                          ),
                          Text(
                            'Cash',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  
                  // Ligne Référence + SIM + Date (compact)
                  Row(
                    children: [
                      // Référence
                      Icon(Icons.tag, size: 12, color: Colors.blue[700]),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          transaction.reference,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      // SIM
                      Icon(Icons.sim_card, size: 12, color: Colors.green[700]),
                      const SizedBox(width: 4),
                      Text(
                        transaction.simNumero,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Montants secondaires en ligne
                  Row(
                    children: [
                      _buildCompactAmount('Virtuel', transaction.montantVirtuel, Colors.purple),
                      const SizedBox(width: 12),
                      if (transaction.frais > 0)
                        _buildCompactAmount('Frais', transaction.frais, Colors.orange),
                      const Spacer(),
                      // Date compactée
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 10, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Text(
                            DateFormat('dd/MM HH:mm').format(transaction.dateEnregistrement),
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Shop designation (seulement si disponible)
                  if (transaction.shopDesignation != null && transaction.shopDesignation!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.store, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            transaction.shopDesignation!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Client (seulement si disponible)
                  if (transaction.clientNom != null && transaction.clientNom!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.person_outline, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${transaction.clientNom}${transaction.clientTelephone != null ? " • ${transaction.clientTelephone}" : ""}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Bouton servir moderne et joli pour transactions en attente
                  if (isEnAttente && onServe != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 25,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF48bb78), Color(0xFF38a169)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF48bb78).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: onServe,
                          borderRadius: BorderRadius.circular(10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.check_circle,
                                size: 20,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Servir Client',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.arrow_forward_rounded,
                                size: 18,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ],
                          ),
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

  /// Widget compact pour afficher un montant secondaire
  Widget _buildCompactAmount(String label, double amount, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
