import 'package:flutter/material.dart';
import '../models/client_model.dart';
import 'create_transaction_dialog_responsive.dart';

/// Wrapper pour maintenir la compatibilité avec l'ancien CreateTransactionDialog
class CreateTransactionDialog extends StatelessWidget {
  final ClientModel? preselectedClient;

  const CreateTransactionDialog({
    super.key,
    this.preselectedClient,
  });

  @override
  Widget build(BuildContext context) {
    return CreateTransactionDialogResponsive(
      preselectedClient: preselectedClient,
    );
  }
}
