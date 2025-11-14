#!/usr/bin/env dart
// Simple test script to verify synchronization functionality

import 'dart:io';
import 'package:ucashv01/services/sync_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  print('🧪 Testing Synchronization Functionality');
  print('=====================================');
  
  try {
    // Enable debug printing
    Function? originalDebugPrint = debugPrint;
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) {
        print('DEBUG: $message');
      }
    };
    
    // Initialize the sync service
    print('🔄 Initializing Sync Service...');
    final syncService = SyncService();
    await syncService.initialize();
    print('✅ Sync Service initialized');
    
    // Test connectivity
    print('\n🔍 Testing connectivity...');
    final isConnected = await syncService.testConnection();
    print('🌐 Connectivity test result: ${isConnected ? "✅ Connected" : "❌ Disconnected"}');
    
    // Test getting last sync timestamp
    print('\n🕒 Testing last sync timestamp retrieval...');
    final timestamp = await syncService.getLastSyncTimestamp('shops');
    print('⏱️ Last sync timestamp for shops: ${timestamp ?? "Never synced"}');
    
    print('\n🏁 Synchronization functionality test completed');
    
    // Exit with success code
    exit(0);
  } catch (e, stackTrace) {
    print('❌ Error during synchronization test: $e');
    print('Stack trace: $stackTrace');
    
    // Exit with error code
    exit(1);
  }
}