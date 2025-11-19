import 'package:flutter/material.dart';
import '../widgets/material_dashboard.dart';

class MaterialDashboardPage extends StatelessWidget {
  const MaterialDashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: MaterialDashboard(),
    );
  }
}