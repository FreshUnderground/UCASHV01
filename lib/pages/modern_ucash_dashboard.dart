import 'package:flutter/material.dart';
import '../widgets/material_app_bar.dart';
import '../widgets/material_dashboard.dart';

class ModernUcashDashboard extends StatelessWidget {
  const ModernUcashDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      appBar: MaterialAppBar(
        title: 'UCASH Dashboard',
      ),
      body: MaterialDashboard(),
    );
  }
}