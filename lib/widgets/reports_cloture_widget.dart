import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/rapport_cloture_widget.dart';
import '../services/agent_auth_service.dart';

/// Widget pour afficher le rapport de clôture depuis le menu des rapports
class ReportsClotureWidget extends StatelessWidget {
  const ReportsClotureWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AgentAuthService>(context);
    final shopId = authService.currentAgent?.shopId;
    
    return RapportClotureWidget(shopId: shopId);
  }
}