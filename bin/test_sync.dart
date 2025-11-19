#!/usr/bin/env dart
// Simple test script to verify synchronization functionality

import 'dart:io';
import 'package:ucashv01/services/sync_service.dart';
import 'package:flutter/foundation.dart';

void main() async {
  debugPrint('🧪 Testing Synchronization Functionality');
  debugPrint('=====================================');
  
  try {
    // Initialize the sync service
    debugPrint('🔄 Initializing Sync Service...');
    final syncService = SyncService();
    await syncService.initialize();
    debugPrint('✅ Sync Service initialized');
    
    // Test connectivity
    debugPrint('\n🔍 Testing connectivity...');
    final isConnected = await syncService.testConnection();
    debugPrint('🌐 Connectivity test result: ${isConnected ? "✅ Connected" : "❌ Disconnected"}');
    
    // Test getting last sync timestamp
    debugPrint('\n🕒 Testing last sync timestamp retrieval...');
    final timestamp = await syncService.getLastSyncTimestamp('shops');
    debugPrint('⏱️ Last sync timestamp for shops: ${timestamp ?? "Never synced"}');
    
    debugPrint('\n🏁 Synchronization functionality test completed');
    
    // Exit with success code
    exit(0);
  } catch (e, stackTrace) {
    debugPrint('❌ Error during synchronization test: $e');
    debugPrint('Stack trace: $stackTrace');
    
    // Exit with error code
    exit(1);
  }
}