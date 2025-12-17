import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../models/compte_special_model.dart';
import '../services/compte_special_service.dart';

/// Widget pour afficher le relevé d'un compte spécial
class ReleveCompteSpecialWidget extends StatelessWidget {
  final TypeCompteSpecial typeCompte;
  final int? shopId;
  final DateTime startDate;
  final DateTime endDate;
  
  const ReleveCompteSpecialWidget({
    Key? key,
    required this.typeCompte,
    this.shopId,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final service = CompteSpecialService.instance;
    final transactions = typeCompte == TypeCompteSpecial.FRAIS
        ? service.getFrais(shopId: shopId, startDate: startDate, endDate: endDate)
        : service.getDepenses(shopId: shopId, startDate: startDate, endDate: endDate);
    
    final solde = typeCompte == TypeCompteSpecial.FRAIS
        ? service.getSoldeFrais(shopId: shopId, startDate: startDate, endDate: endDate)
        : service.getSoldeDepense(shopId: shopId, startDate: startDate, endDate: endDate);
    
    final locale = Localizations.localeOf(context).toString();
    final numberFormat = NumberFormat('#,##0.00', locale);
    final dateFormat = DateFormat('dd/MM/yyyy', locale);
    
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête
            Row(
              children: [
                Icon(
                  typeCompte == TypeCompteSpecial.FRAIS
                      ? Icons.attach_money
                      : Icons.account_balance_wallet,
                  size: 40,
                  color: typeCompte == TypeCompteSpecial.FRAIS
                      ? Colors.green
                      : Colors.blue,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${l10n.statement.toUpperCase()} ${_getAccountLabel(typeCompte, l10n).toUpperCase()}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${l10n.period}: ${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 32),
            
            // Résumé
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _buildSummaryRow(
                    l10n.transactionsCount,
                    transactions.length.toString(),
                  ),
                  if (typeCompte == TypeCompteSpecial.FRAIS) ...[
                    _buildSummaryRow(
                      l10n.clientCommissions,
                      '\$${numberFormat.format(transactions.where((t) => t.typeTransaction == TypeTransactionCompte.COMMISSION_AUTO).fold(0.0, (sum, t) => sum + t.montant))}',
                    ),
                    _buildSummaryRow(
                      l10n.bossWithdrawals,
                      '\$${numberFormat.format(transactions.where((t) => t.typeTransaction == TypeTransactionCompte.RETRAIT).fold(0.0, (sum, t) => sum + t.montant.abs()))}',
                    ),
                  ] else ...[
                    _buildSummaryRow(
                      l10n.bossDeposits,
                      '\$${numberFormat.format(transactions.where((t) => t.typeTransaction == TypeTransactionCompte.DEPOT).fold(0.0, (sum, t) => sum + t.montant))}',
                    ),
                    _buildSummaryRow(
                      l10n.expensesOutflows,
                      '\$${numberFormat.format(transactions.where((t) => t.typeTransaction == TypeTransactionCompte.SORTIE).fold(0.0, (sum, t) => sum + t.montant.abs()))}',
                    ),
                  ],
                  const Divider(),
                  _buildSummaryRow(
                    l10n.balance.toUpperCase(),
                    '\$${numberFormat.format(solde)}',
                    isTotal: true,
                    color: solde >= 0 ? Colors.green : Colors.red,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Liste des transactions
            Text(
              l10n.transactionsDetails,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (transactions.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    l10n.noTransactionsForPeriod,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: transactions.length,
                itemBuilder: (context, index) {
                  final transaction = transactions[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: transaction.montant >= 0
                            ? Colors.green.withOpacity(0.2)
                            : Colors.red.withOpacity(0.2),
                        child: Text(
                          transaction.typeTransaction.icon,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      title: Text(transaction.description),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateFormat('dd/MM/yyyy HH:mm', locale).format(transaction.dateTransaction),
                            style: const TextStyle(fontSize: 10),
                          ),
                          Text(
                            transaction.typeTransaction.label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${transaction.montant >= 0 ? '+' : ''}\$${numberFormat.format(transaction.montant)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: transaction.montant >= 0
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 10 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              fontSize: isTotal ? 10 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  String _getAccountLabel(TypeCompteSpecial type, AppLocalizations l10n) {
    switch (type) {
      case TypeCompteSpecial.FRAIS:
        return l10n.feesAccount;
      case TypeCompteSpecial.DEPENSE:
        return l10n.expenseAccount;
    }
  }
}
