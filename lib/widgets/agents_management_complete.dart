import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/agent_service.dart';
import '../services/reset_sync_service.dart';
import '../services/shop_service.dart';
import '../utils/responsive_utils.dart';
import '../theme/ucash_containers.dart';
import 'agents_stats_widget.dart';
import 'agents_table_widget.dart';

class AgentsManagementComplete extends StatefulWidget {
  const AgentsManagementComplete({super.key});

  @override
  State<AgentsManagementComplete> createState() => _AgentsManagementCompleteState();
}

class _AgentsManagementCompleteState extends State<AgentsManagementComplete>  {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  @override
  Future<void> onSyncCompleted() async {
    _loadData();
  }

  void _loadData() {
    Provider.of<AgentService>(context, listen: false).loadAgents();
    Provider.of<ShopService>(context, listen: false).loadShops();
  }


  Future<void> _resetSync() async {
    await ResetSyncService.forceFreshSync();
  }


  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques des agents
          const AgentsStatsWidget(),
          context.verticalSpace(mobile: 16, tablet: 20, desktop: 24),
          
          // Tableau des agents
          const AgentsTableWidget(),
        ],
      ),
    );
  }

}
