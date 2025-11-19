import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/operation_service.dart';
import '../models/operation_model.dart';

class ClientAccountSummary extends StatelessWidget {
  const ClientAccountSummary({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, OperationService>(
      builder: (context, authService, operationService, child) {
        final client = authService.currentClient;
        if (client == null) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune information partenaire disponible'),
            ),
          );
        }

        // Calculer les statistiques
        final clientOperations = operationService.operations
            .where((op) => op.clientId == client.id)
            .toList();
        
        final totalDeposits = clientOperations
            .where((op) => op.type == OperationType.depot)
            .fold<double>(0, (sum, op) => sum + op.montantNet);
        
        final totalWithdrawals = clientOperations
            .where((op) => op.type == OperationType.retrait)
            .fold<double>(0, (sum, op) => sum + op.montantNet);
        
        final totalTransfersSent = clientOperations
            .where((op) => op.type == OperationType.transfertNational ||
                          op.type == OperationType.transfertInternationalSortant)
            .fold<double>(0, (sum, op) => sum + op.montantNet);
        
        final totalTransfersReceived = clientOperations
            .where((op) => op.type == OperationType.transfertInternationalEntrant)
            .fold<double>(0, (sum, op) => sum + op.montantNet);

        return Column(
          children: [
            // Solde principal
            Card(
              elevation: 4,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [Color(0xFFDC2626), Color(0xFFB91C1C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.account_balance_wallet,
                      color: Colors.white,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Solde Actuel',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${client.solde.toStringAsFixed(2)} USD',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: client.solde >= 0 ? Colors.green : Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        client.solde >= 0 ? 'Compte Créditeur' : 'Compte Débiteur',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Statistiques détaillées
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Dépôts',
                    '${totalDeposits.toStringAsFixed(2)} USD',
                    Icons.add_circle,
                    Colors.green,
                    clientOperations.where((op) => op.type == OperationType.depot).length,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Retraits',
                    '${totalWithdrawals.toStringAsFixed(2)} USD',
                    Icons.remove_circle,
                    Colors.orange,
                    clientOperations.where((op) => op.type == OperationType.retrait).length,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Envoyés',
                    '${totalTransfersSent.toStringAsFixed(2)} USD',
                    Icons.send,
                    Colors.blue,
                    clientOperations.where((op) => 
                        op.type == OperationType.transfertNational ||
                        op.type == OperationType.transfertInternationalSortant).length,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildStatCard(
                    'Reçus',
                    '${totalTransfersReceived.toStringAsFixed(2)} USD',
                    Icons.call_received,
                    Colors.purple,
                    clientOperations.where((op) => 
                        op.type == OperationType.transfertInternationalEntrant).length,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Informations du compte
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Informations du Compte',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildInfoRow('Nom complet', client.nom),
                    _buildInfoRow('Téléphone', client.telephone),
                    if (client.adresse != null && client.adresse!.isNotEmpty)
                      _buildInfoRow('Adresse', client.adresse!),
                    _buildInfoRow('Statut', client.isActive ? 'Actif' : 'Inactif'),
                    _buildInfoRow('Membre depuis', _formatDate(client.createdAt ?? DateTime.now())),
                    _buildInfoRow('Dernière mise à jour', _formatDate(client.lastModifiedAt ?? DateTime.now())),
                    _buildInfoRow('Total transactions', '${clientOperations.length}'),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Information sur les opérations
            Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue[600]),
                        const SizedBox(width: 8),
                        const Text(
                          'Pour effectuer des opérations',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    _buildOperationInfo(
                      icon: Icons.add_circle,
                      title: 'Dépôts',
                      description: 'Rendez-vous dans un shop UCASH avec votre pièce d\'identité',
                      color: Colors.green,
                    ),
                    
                    _buildOperationInfo(
                      icon: Icons.remove_circle,
                      title: 'Retraits',
                      description: 'Présentez-vous dans un shop UCASH avec votre pièce d\'identité',
                      color: Colors.orange,
                    ),
                    
                    _buildOperationInfo(
                      icon: Icons.send,
                      title: 'Transferts',
                      description: 'Demandez à un agent UCASH d\'effectuer votre transfert',
                      color: Colors.blue,
                    ),
                    
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.location_on, color: Colors.blue[700], size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Trouvez le shop UCASH le plus proche de chez vous pour toutes vos opérations.',
                              style: TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildOperationInfo({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count transaction${count > 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
