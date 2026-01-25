# Synchronization Testing Guide

## Overview
This guide explains how to test the synchronization functionality in the UCASH application to ensure it works correctly.

## Prerequisites
1. Ensure Laragon (or another local server environment) is running
2. Ensure the UCASH database is properly configured
3. Ensure the API endpoints are accessible at `https://safdal.investee-group.com/server/api/sync`

## Testing Methods

### 1. Automated Tests
Run the unit tests to verify the synchronization functionality:

```bash
flutter test test/sync_test.dart
```

### 2. Manual Testing Script
Run the simple test script to verify basic synchronization functionality:

```bash
dart bin/test_sync.dart
```

### 3. In-App Testing
1. Launch the UCASH application
2. Navigate to the synchronization section in the admin dashboard
3. Trigger a manual synchronization
4. Observe the synchronization status and logs

## Test Scenarios

### Scenario 1: Basic Connectivity
- Verify that the application can connect to the synchronization server
- Check that the connectivity status is properly displayed

### Scenario 2: Data Upload
- Create new entities (shops, agents, clients, operations, taux, commissions)
- Trigger synchronization
- Verify that the data is uploaded to the server

### Scenario 3: Data Download
- Modify data on the server
- Trigger synchronization
- Verify that the changes are downloaded and applied to the local database

### Scenario 4: Conflict Resolution
- Modify the same entity both locally and on the server
- Trigger synchronization
- Verify that conflicts are detected and resolved properly

### Scenario 5: Offline Mode
- Disconnect from the network
- Create new entities
- Reconnect to the network
- Verify that the entities are synchronized when connectivity is restored

## Troubleshooting

### Common Issues
1. **Server Unreachable**: Ensure Laragon is running and the API endpoints are accessible
2. **Database Connection**: Verify database credentials in `server/config/database.php`
3. **Network Issues**: Check firewall settings and network connectivity

### Debugging Tips
1. Enable verbose logging in the application
2. Check the server logs for error messages
3. Use the test scripts to isolate issues
4. Monitor network traffic with tools like Wireshark or browser developer tools

## Expected Results
- Synchronization should complete without errors
- All entities should be properly synchronized between the client and server
- Conflicts should be resolved according to the defined strategy
- Offline data should be synchronized when connectivity is restored

## Monitoring
- Monitor synchronization performance
- Track error rates and failure patterns
- Gather user feedback on the synchronization experience
- Regularly review synchronization logs for issues