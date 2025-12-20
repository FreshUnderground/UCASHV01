# Deletion System Troubleshooting Guide

## Overview

This guide helps troubleshoot issues with the deletion request system, specifically the 400 Bad Request errors when validating deletion requests.

## Current Status

Based on your logs, you're experiencing:
1. **400 Bad Request** errors when validating deletion requests
2. **No pending admin requests** showing in the system
3. Requests being queued for retry

## Root Cause Analysis

The 400 error indicates that our improved error handling is working correctly - the server is now properly rejecting invalid requests rather than crashing with a 500 error. Possible causes include:

1. **Missing deletion requests** in the database
2. **Invalid request data** being sent by the client
3. **Database schema issues** preventing proper validation
4. **Network or connectivity issues**

## Diagnostic Steps

### Step 1: Check Database Connection and Structure

Run the inspection script to verify the database:
```bash
cd c:\laragon1\www\UCASHV01\server
php inspect_deletion_table.php
```

This will show:
- Table structure
- Column definitions
- Index information
- Sample data

### Step 2: Verify Deletion Requests Exist

Run the debug script to check for requests:
```bash
cd c:\laragon1\www\UCASHV01\server
php debug_deletion_request.php
```

This will show:
- Total number of requests
- Sample requests
- Specific request (251212115644101) if it exists

### Step 3: Manually Test the Endpoint

Use the test script to simulate a request:
```bash
cd c:\laragon1\www\UCASHV01\server
php test_admin_validate_request.php
```

Or use curl directly:
```bash
curl -X POST \
  https://mahanaimeservice.investee-group.com/server/api/sync/deletion_requests/admin_validate.php \
  -H 'Content-Type: application/json' \
  -d '{
    "code_ops": "251212115644101",
    "validated_by_admin_id": 1,
    "validated_by_admin_name": "Test Admin"
  }'
```

## Solutions

### Solution 1: Create a New Deletion Request

1. Log in to the admin panel
2. Navigate to operations
3. Select an operation to delete
4. Create a deletion request
5. Verify it appears in the admin validation list

### Solution 2: Check Server Logs

Look for detailed error messages in the server logs:
- Check Apache/Nginx error logs
- Check PHP error logs
- Look for entries with "[DELETION_REQUESTS]" prefix

Expected log messages:
- `[DELETION_REQUESTS] Missing required fields: ...`
- `[DELETION_REQUESTS] Request not found: ...`
- `[DELETION_REQUESTS] Request ... already admin validated`

### Solution 3: Verify Database Schema

Ensure the database schema is up to date:
1. Check that `deletion_requests` table exists
2. Verify column structure matches expectations
3. Ensure enum values for `statut` column are correct:
   - `en_attente`
   - `admin_validee`
   - `agent_validee`
   - `refusee`
   - `annulee`

### Solution 4: Check Network Connectivity

Verify the server can be reached:
```bash
ping mahanaim.investee-group.com
```

## Common Issues and Fixes

### Issue 1: No Deletion Requests in Database
**Symptoms**: "Total demandes admin en attente: 0"
**Fix**: Create deletion requests through the admin interface

### Issue 2: Invalid Request Data
**Symptoms**: 400 Bad Request with "Missing required fields"
**Fix**: Ensure all required fields are sent:
- `code_ops`
- `validated_by_admin_id`
- `validated_by_admin_name`

### Issue 3: Request Already Processed
**Symptoms**: 400 Bad Request with "already validated"
**Fix**: Create a new deletion request

### Issue 4: Database Connection Issues
**Symptoms**: Various database-related errors
**Fix**: 
1. Verify database credentials in `server/config/database.php`
2. Check database server connectivity
3. Ensure the database user has proper permissions

## Testing Checklist

Before considering the issue resolved, verify:

- [ ] Deletion requests can be created through admin interface
- [ ] Created requests appear in admin validation list
- [ ] Admin validation succeeds without errors
- [ ] Validated requests appear in agent validation list
- [ ] Agent validation (approve/reject) works correctly
- [ ] Operations are properly moved to corbeille when approved

## Contact Support

If issues persist after following this guide:

1. Provide server error logs
2. Include output from diagnostic scripts
3. Specify exact steps taken
4. Mention any recent changes to the system

## Additional Resources

- Database schema: `database/create_deletion_tables.sql`
- Migration script: `database/migrate_deletion_requests_admin_validation.sql`
- API endpoints: `server/api/sync/deletion_requests/`