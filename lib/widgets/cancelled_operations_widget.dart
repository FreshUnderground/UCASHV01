import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/operation_service.dart';
import '../services/auth_service.dart';
import '../models/operation_model.dart';
import 'package:intl/intl.dart';

/// Widget pour afficher les op\u00e9rations annul\u00e9es d'un agent
class CancelledOperationsWidget extends StatefulWidget {
  const CancelledOperationsWidget({super.key});

  @override
  State<CancelledOperationsWidget> createState() => _CancelledOperationsWidgetState();
}

class _CancelledOperationsWidgetState extends State<CancelledOperationsWidget> {
  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;
    if (currentUser?.shopId != null) {
      Provider.of<OperationService>(context, listen: false)
          .loadOperations(shopId: currentUser!.shopId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isMobile = size.width <= 768;

    return Padding(
      padding: EdgeInsets.all(isMobile ? 16 : 24),
      child: Column(
        children: [
          _buildHeader(isMobile),
          SizedBox(height: isMobile ? 16 : 24),
          Expanded(
            child: _buildCancelledOperationsList(isMobile),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Card(
      elevation: 3,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 16 : 20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.cancel,
                color: Colors.red,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u274c Op\u00e9rations Annul\u00e9es',
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Vos op\u00e9rations annul\u00e9es par l\'administration',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualiser',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCancelledOperationsList(bool isMobile) {
    return Consumer2<OperationService, AuthService>(
      builder: (context, operationService, authService, child) {
        final currentUser = authService.currentUser;
        
        if (currentUser == null) {
          return const Center(child: Text('Non connect\u00e9'));
        }

        if (operationService.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        // Filtrer uniquement les op\u00e9rations annul\u00e9es de cet agent
        final cancelledOps = operationService.operations
            .where((op) => 
                op.agentId == currentUser.id && 
                op.statut == OperationStatus.annulee)
            .toList();

        // Trier par date d'annulation (plus r\u00e9centes en premier)
        cancelledOps.sort((a, b) {
          if (a.dateAnnulation == null) return 1;
          if (b.dateAnnulation == null) return -1;
          return b.dateAnnulation!.compareTo(a.dateAnnulation!);
        });

        if (cancelledOps.isEmpty) {
          return Card(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 72,
                      color: Colors.green[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Aucune op\u00e9ration annul\u00e9e',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Toutes vos op\u00e9rations sont valides',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Card(
          child: ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: cancelledOps.length,
            itemBuilder: (context, index) {
              return _buildCancelledOperationCard(cancelledOps[index], isMobile);
            },
          ),
        );
      },
    );
  }

  Widget _buildCancelledOperationCard(OperationModel op, bool isMobile) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.withOpacity(0.3), width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header avec badge annul\u00e9
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cancel, color: Colors.white, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        op.statutLabel.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  'ID: ${op.id}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 12),

            // Informations de l'op\u00e9ration
            _buildInfoRow(
              Icons.payment,
              'Type',
              op.typeLabel,
              Colors.blue,
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.attach_money,
              'Montant',
              '${op.montantNet.toStringAsFixed(2)} ${op.devise}',
              const Color(0xFFDC2626),
            ),
            if (op.destinataire != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.person,
                'Destinataire',
                op.destinataire!,
                Colors.grey[700]!,
              ),
            ],
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.calendar_today,
              'Date op\u00e9ration',
              DateFormat('dd/MM/yyyy \u00e0 HH:mm').format(op.dateOp),
              Colors.grey[700]!,
            ),
            if (op.dateAnnulation != null) ...[
              const SizedBox(height: 8),
              _buildInfoRow(
                Icons.event_busy,
                'Date annulation',
                DateFormat('dd/MM/yyyy \u00e0 HH:mm').format(op.dateAnnulation!),
                Colors.red,
              ),
            ],
            
            // Motif d'annulation (en \u00e9vidence)
            if (op.motifAnnulation != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red[200]!, width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.red,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Motif d\'annulation:',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      op.motifAnnulation!,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
