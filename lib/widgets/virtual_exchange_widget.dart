import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/virtual_exchange_model.dart';
import '../services/virtual_exchange_service.dart';
import '../services/auth_service.dart';
import 'create_virtual_exchange_dialog.dart';

class VirtualExchangeWidget extends StatefulWidget {
  const VirtualExchangeWidget({Key? key}) : super(key: key);

  @override
  State<VirtualExchangeWidget> createState() => _VirtualExchangeWidgetState();
}

class _VirtualExchangeWidgetState extends State<VirtualExchangeWidget> {
  @override
  void initState() {
    super.initState();
    _loadExchanges();
  }

  Future<void> _loadExchanges() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final shopId = authService.currentUser?.shopId;
    if (shopId != null) {
      await VirtualExchangeService.instance.loadExchanges(shopId: shopId);
    }
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CreateVirtualExchangeDialog(),
    );
    if (result == true) await _loadExchanges();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VirtualExchangeService>(
      builder: (context, service, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(child: Text('Échanges', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                  ElevatedButton.icon(
                    onPressed: _showCreateDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('Nouvel Échange'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: service.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : service.exchanges.isEmpty
                      ? const Center(child: Text('Aucun échange virtuel'))
                      : ListView.builder(
                          itemCount: service.exchanges.length,
                          itemBuilder: (context, index) => _buildCard(service.exchanges[index]),
                        ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCard(VirtualExchangeModel exchange) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Icon(Icons.swap_horiz, color: _getStatusColor(exchange.statut)),
        title: Text('${exchange.simSource} → ${exchange.simDestination}'),
        subtitle: Text('${exchange.montant} ${exchange.devise} • ${exchange.statutLabel}'),
        trailing: exchange.statut == VirtualExchangeStatus.enAttente
            ? PopupMenuButton(
                onSelected: (value) {
                  if (value == 'validate') {
                    _validateExchange(exchange);
                  } else if (value == 'cancel') {
                    _cancelExchange(exchange);
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'validate',
                    child: Text('Valider'),
                  ),
                  const PopupMenuItem(
                    value: 'cancel',
                    child: Text('Annuler'),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Color _getStatusColor(VirtualExchangeStatus status) {
    switch (status) {
      case VirtualExchangeStatus.enAttente: return Colors.orange;
      case VirtualExchangeStatus.valide: return Colors.green;
      case VirtualExchangeStatus.annule: return Colors.red;
    }
  }

  Future<void> _validateExchange(VirtualExchangeModel exchange) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await VirtualExchangeService.instance.validateExchange(
      exchange, 
      agentUsername: authService.currentUser?.username,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Échange validé'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _cancelExchange(VirtualExchangeModel exchange) async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final success = await VirtualExchangeService.instance.cancelExchange(
      exchange, 
      agentUsername: authService.currentUser?.username,
    );
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Échange annulé'), backgroundColor: Colors.orange),
      );
    }
  }
}
