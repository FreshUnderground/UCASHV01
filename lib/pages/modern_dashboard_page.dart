import 'package:flutter/material.dart';
import '../widgets/modern_dashboard_widget.dart';

class ModernDashboardPage extends StatelessWidget {
  const ModernDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: ModernDashboardWidget(),
    );
  }
}