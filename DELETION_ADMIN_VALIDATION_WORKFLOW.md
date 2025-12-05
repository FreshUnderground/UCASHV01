# Deletion Admin Validation Workflow

## Overview

This document describes the new two-step deletion validation workflow:

1. **Admin A** creates a deletion request
2. **Admin B** validates the deletion request (inter-admin validation)
3. The validated request is sent to the **Agent** for final approval
4. The agent approves or rejects the request

## Components Modified

### 1. Database Schema Updates

#### New Columns in `deletion_requests` table:
- `validated_by_admin_id` - ID of admin who validated the request
- `validated_by_admin_name` - Name of admin who validated the request
- `validation_admin_date` - Date/time when admin validated the request

#### Updated Status Enum:
- `en_attente` - Initial state, waiting for admin validation
- `admin_validee` - Validated by an admin, waiting for agent approval
- `agent_validee` - Validated by agent, operation deleted
- `refusee` - Rejected by either admin or agent
- `annulee` - Cancelled

### 2. Server-Side Endpoints

#### New Endpoint: `/sync/deletion_requests/admin_validate.php`
- **Method**: POST
- **Body**: `{code_ops, validated_by_admin_id, validated_by_admin_name}`
- **Function**: Validates a deletion request by an admin

#### Updated Endpoints:
- `/sync/deletion_requests/download.php` - Now includes admin validation fields
- `/sync/deletion_requests/validate.php` - Now handles agent validation with new status

### 3. Mobile App Changes

#### New Widgets:
- `AdminDeletionValidationWidget` - Shows pending deletion requests for admin validation
- Updated `AgentDeletionValidationWidget` - Shows only admin-validated requests

#### Updated Services:
- `DeletionService` - New methods for admin validation and updated filtering logic

#### Updated Models:
- `DeletionRequestModel` - New fields for admin validation and updated status enum

## Workflow Implementation

### Step 1: Admin Creates Deletion Request
1. Admin navigates to deletion management screen
2. Selects an operation to delete
3. Provides reason for deletion
4. Request is created with status `en_attente`

### Step 2: Admin Validates Deletion Request
1. Another admin navigates to "Validations Admin" screen
2. Views pending deletion requests (status = `en_attente`)
3. Reviews request details
4. Clicks "Validate" or "Reject"
5. If validated, request status becomes `admin_validee`

### Step 3: Agent Approves Deletion Request
1. Agent navigates to "Suppressions à valider" screen
2. Views admin-validated requests (status = `admin_validee`)
3. Reviews request details (shows admin who validated)
4. Clicks "Approve" or "Reject"
5. If approved:
   - Operation is moved to corbeille
   - Request status becomes `agent_validee`
   - Operation is removed from operations list

## Implementation Steps

### 1. Database Migration
Run the migration script:
```sql
mysql -u username -p database_name < database/migrate_deletion_requests_admin_validation.sql
```

### 2. Server Deployment
Deploy the updated PHP files:
- `server/api/sync/deletion_requests/admin_validate.php`
- Updated database schema

### 3. Mobile App Update
Rebuild and deploy the mobile app with the new widgets and services.

## Testing

### Test Scenario 1: Full Workflow
1. Admin A creates deletion request for operation X
2. Admin B validates the request
3. Agent approves the request
4. Verify operation X is moved to corbeille
5. Verify all status transitions are correct

### Test Scenario 2: Admin Rejection
1. Admin A creates deletion request for operation X
2. Admin B rejects the request
3. Verify request status is `refusee`
4. Verify operation X remains in operations list

### Test Scenario 3: Agent Rejection
1. Admin A creates deletion request for operation X
2. Admin B validates the request
3. Agent rejects the request
4. Verify request status is `refusee`
5. Verify operation X remains in operations list

## Rollback Plan

If issues occur, the following rollback steps can be taken:

1. Revert database schema changes
2. Restore previous PHP files
3. Deploy previous mobile app version

## Monitoring

Monitor the following logs:
- Server error logs for PHP errors
- Application logs for status transition issues
- Database logs for failed queries