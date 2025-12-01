# Fix: Admin Account Converting to Agent After Sync

## Problem Description
Sometimes when working as admin, the account would switch to an agent account after a sync operation. This caused serious authorization issues where admins lost their administrative privileges.

## Root Cause

### Issue 1: Missing `role` Field in AgentModel
The `agent_model.dart` was missing the `role` field, even though the database schema includes it:
```sql
CREATE TABLE agents (
    ...
    role ENUM('AGENT', 'ADMIN') DEFAULT 'AGENT',
    ...
)
```

### Issue 2: Hardcoded Role in refreshUserData()
In `auth_service.dart`, the `refreshUserData()` method was hardcoding ALL users to 'AGENT' role when refreshing data after sync:

```dart
// ❌ BEFORE (Line 341)
_currentUser = UserModel(
    ...
    role: 'AGENT',  // ⚠️ Hardcoded! This converts ALL users to AGENT
    ...
);
```

This meant that:
1. Admin logs in ✅
2. Background sync triggers
3. `refreshUserData()` is called
4. Admin's role gets overwritten to 'AGENT' ❌
5. Admin now appears as an agent in the UI

## Solution

### Step 1: Add `role` Field to AgentModel
**File:** `lib/models/agent_model.dart`

Added the `role` field to properly track whether an agent is actually an ADMIN or AGENT:

```dart
class AgentModel {
  final String role;  // 'AGENT' ou 'ADMIN' ✅

  AgentModel({
    ...
    this.role = 'AGENT',  // Par défaut AGENT
    ...
  });

  factory AgentModel.fromJson(Map<String, dynamic> json) {
    return AgentModel(
      ...
      role: json['role'] ?? 'AGENT',  // ✅ Read role from database
      ...
    );
  }

  Map<String, dynamic> toJson() {
    return {
      ...
      'role': role,  // ✅ Include role in JSON export
      ...
    };
  }
}
```

### Step 2: Preserve Role in refreshUserData()
**File:** `lib/services/auth_service.dart`

Modified the `refreshUserData()` method to:
1. Preserve the current user's role
2. Check for admin default account first
3. Use the role from the database instead of hardcoding

```dart
// ✅ AFTER
if (_currentUser != null) {
  final currentRole = _currentUser!.role; // Préserver le rôle actuel
  
  // Si c'est un admin, vérifier d'abord l'admin par défaut
  if (currentRole == 'ADMIN') {
    if (username == 'admin') {
      final admin = await LocalDB.instance.getDefaultAdmin();
      if (admin != null) {
        _currentUser = admin;
        // Admin preserved! ✅
        return;
      }
    }
  }
  
  // Pour les autres utilisateurs
  if (updatedAgent != null) {
    _currentUser = UserModel(
      ...
      role: updatedAgent.role, // ✅ Use role from database
      ...
    );
  }
}
```

## Files Modified

1. **lib/models/agent_model.dart**
   - Added `role` field
   - Added role to constructor with default value 'AGENT'
   - Added role parsing in `fromJson()`
   - Added role to `toJson()`
   - Added role to `copyWith()`

2. **lib/services/auth_service.dart**
   - Modified `refreshUserData()` to preserve admin role
   - Added special handling for default admin account
   - Changed from hardcoded `role: 'AGENT'` to `role: updatedAgent.role`
   - Added better logging to show role during refresh

## Testing

### Test Scenario 1: Admin Login and Sync
1. ✅ Login as admin (admin/admin123)
2. ✅ Wait for background sync
3. ✅ Check that you remain admin (not converted to agent)
4. ✅ Check dashboard shows admin features

### Test Scenario 2: Agent Login and Sync
1. ✅ Login as agent
2. ✅ Wait for background sync
3. ✅ Check that you remain agent
4. ✅ Check dashboard shows agent features

### Test Scenario 3: Admin in Agents Table
1. ✅ Create an admin in the agents table with role='ADMIN'
2. ✅ Login with that admin account
3. ✅ Wait for background sync
4. ✅ Verify role is preserved as 'ADMIN'

## Impact

- **Security:** ✅ Admins no longer lose their privileges
- **User Experience:** ✅ No more unexpected role switches
- **Data Integrity:** ✅ Roles are now properly preserved across syncs
- **Backward Compatibility:** ✅ Default value 'AGENT' ensures existing code works

## Prevention

To prevent similar issues in the future:
1. ✅ Always check database schema matches model definitions
2. ✅ Never hardcode user roles - always read from data source
3. ✅ Test role preservation during sync operations
4. ✅ Add logging to track role changes

## Debug Logs

New debug messages help track role handling:
```
✅ Admin par défaut rechargé: admin
✅ Données admin rafraîchies avec succès
✅ Utilisateur rechargé: username (Rôle: ADMIN)
```

Look for these in console to verify correct role handling.
