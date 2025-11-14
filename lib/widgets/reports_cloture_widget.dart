import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/rapportcloture.dart';  // Change this import
import '../services/agent_auth_service.dart';

/// Widget pour afficher le rapport de clôture depuis le menu des rapports
class ReportsClotureWidget extends StatelessWidget {
  const ReportsClotureWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AgentAuthService>(context);
    final shopId = authService.currentAgent?.shopId;
    
    return RapportCloture(shopId: shopId);  // Use the new widget
  }
}