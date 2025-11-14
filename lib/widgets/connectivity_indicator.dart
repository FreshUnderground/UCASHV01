import 'package:flutter/material.dart';
import '../services/connectivity_service.dart';

class ConnectivityIndicator extends StatelessWidget {
  const ConnectivityIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ConnectivityService.instance,
      builder: (context, child) {
        final connectivityService = ConnectivityService.instance;
        final isOnline = connectivityService.isOnline;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline ? Colors.green[100] : Colors.orange[100],
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline ? Colors.green[300]! : Colors.orange[300]!,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isOnline ? Icons.wifi : Icons.wifi_off,
                size: 16,
                color: isOnline ? Colors.green[700] : Colors.orange[700],
              ),
              const SizedBox(width: 6),
              Text(
                connectivityService.statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isOnline ? Colors.green[700] : Colors.orange[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
