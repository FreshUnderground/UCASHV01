# 🔧 Fix: DropdownButton Assertion Error After Saving Capture

## 📌 Problem

**Error occurred AFTER saving a virtual transaction (capture):**
```
_AssertionError ('package:flutter/src/material/dropdown.dart': Failed assertion: line 1619 pos 15: 
'There should be exactly one item with [DropdownButton]'s value: Instance of 'SimModel'. 
Either zero or 2 or more [DropdownMenuItem]s were detected with the same value)
```

**Timeline:**
1. User saves a "capture" (virtual transaction)
2. `SimService.loadSims()` is called to refresh the list
3. Dropdown tries to rebuild with the refreshed SIM list
4. **CRASH**: Assertion error because dropdown found duplicate SIMs

## ✅ Root Causes

### 1. Missing `==` and `hashCode` in SimModel ✅ FIXED
- **Problem**: `SimModel` couldn't properly compare instances
- **Solution**: Added `==` and `hashCode` overrides to `SimModel`
- **Status**: ✅ Already fixed in previous commit

### 2. Duplicate SIMs in List ⚠️ NEW ISSUE
- **Problem**: `loadSims()` method loaded ALL SIMs from SharedPreferences without removing duplicates
- **Cause**: If duplicate SIM IDs exist in storage (e.g., from sync issues), they all get loaded
- **Result**: Dropdown receives list with multiple SIMs having the same ID
- **Impact**: Even with `==` override, dropdown fails because it finds 2+ items with same value

## 🔧 Solutions Applied

### Solution 1: Override == and hashCode ✅
**File**: [`lib/models/sim_model.dart`](lib/models/sim_model.dart)

```dart
@override
bool operator ==(Object other) {
  if (identical(this, other)) return true;
  return other is SimModel && other.id == id;
}

@override
int get hashCode => id.hashCode;
```

### Solution 2: Deduplicate SIMs on Load ✅
**File**: [`lib/services/sim_service.dart`](lib/services/sim_service.dart)

**Before:**
```dart
Future<void> loadSims({int? shopId}) async {
  _setLoading(true);
  try {
    _sims = await LocalDB.instance.getAllSims(shopId: shopId);
    // No duplicate removal! ❌
    
    debugPrint('Total SIMs chargées: ${_sims.length}');
    // ...
  }
}
```

**After:**
```dart
Future<void> loadSims({int? shopId}) async {
  _setLoading(true);
  try {
    final allSims = await LocalDB.instance.getAllSims(shopId: shopId);
    
    // CRITICAL: Remove duplicates by ID to prevent dropdown assertion errors
    final simsMap = <int, SimModel>{};
    for (var sim in allSims) {
      if (sim.id != null) {
        simsMap[sim.id!] = sim; // Keep the last occurrence if duplicates
      }
    }
    _sims = simsMap.values.toList();
    
    debugPrint('Total SIMs brutes: ${allSims.length}');
    debugPrint('Total SIMs uniques: ${_sims.length}');
    if (allSims.length != _sims.length) {
      debugPrint('⚠️ ${allSims.length - _sims.length} doublons supprimés!');
    }
    // ...
  }
}
```

**How it works:**
1. Load all SIMs from LocalDB (may contain duplicates)
2. Create a Map with `sim.id` as key
3. Duplicates automatically overwrite (Map keeps only one entry per key)
4. Convert Map values back to List
5. Result: **Guaranteed unique SIMs by ID**

## 📋 Why Duplicates Can Occur

**Common scenarios:**
1. **Sync Issues**: Server sends same SIM multiple times
2. **Network Retries**: Failed requests retry and create duplicates
3. **Migration**: Old data format converted incorrectly
4. **Manual Edits**: Testing/debugging creates duplicate entries
5. **Race Conditions**: Multiple saves happening simultaneously

## 🎯 Impact

**Before Fix:**
- ❌ App crashes when dropdown tries to display SIMs after save
- ❌ User unable to create new captures/operations
- ❌ Confusing error message for end users
- ❌ Requires app restart to recover

**After Fix:**
- ✅ Duplicates automatically removed on load
- ✅ Dropdown works correctly even with duplicate data in storage
- ✅ Debug logs show when duplicates are detected
- ✅ App remains stable and usable

## ✅ Verification

```bash
flutter analyze lib/services/sim_service.dart
flutter analyze lib/models/sim_model.dart
```

**Result:** ✅ No issues found!

## 📝 Test Scenarios

### Scenario 1: Normal Operation
1. Load SIMs without duplicates
2. **Expected**: All SIMs displayed correctly
3. **Result**: ✅ Works

### Scenario 2: Duplicate SIMs in Storage
1. Create duplicate SIM entries (same ID) in SharedPreferences
2. Load SIMs via `SimService.loadSims()`
3. **Expected**: Only unique SIMs, duplicates removed
4. **Result**: ✅ Works, logs show "X doublons supprimés!"

### Scenario 3: After Saving Capture
1. Save a virtual transaction
2. Trigger `SimService.loadSims()` refresh
3. Dropdown rebuilds with refreshed list
4. **Expected**: No assertion error
5. **Result**: ✅ Works

## 💡 Prevention

**Best practices to avoid duplicate SIMs:**

1. **Sync Service**: Check for existing ID before insert
   ```dart
   final existingSim = await LocalDB.instance.getSimById(simId);
   if (existingSim != null) {
     debugPrint('⚠️ Doublon ignoré: SIM ID $simId existe déjà');
     return;
   }
   ```

2. **Create SIM**: Validate numero uniqueness
   ```dart
   if (await _numeroExists(numero)) {
     _errorMessage = 'Ce numéro de SIM existe déjà';
     return null;
   }
   ```

3. **Load SIMs**: Always deduplicate (as implemented)

## 🔍 Debugging

**To check for duplicate SIMs:**

```dart
final prefs = await LocalDB.instance.database;
final simKeys = prefs.getKeys().where((k) => k.startsWith('sim_')).toList();
debugPrint('Total SIM keys: ${simKeys.length}');

final simIds = <int>[];
for (var key in simKeys) {
  final simData = prefs.getString(key);
  if (simData != null) {
    final sim = SimModel.fromJson(jsonDecode(simData));
    if (simIds.contains(sim.id)) {
      debugPrint('⚠️ DUPLICATE FOUND: SIM ID ${sim.id}');
    }
    simIds.add(sim.id!);
  }
}
```

## 📝 Files Modified

1. **[`lib/models/sim_model.dart`](lib/models/sim_model.dart)** 
   - Added `==` and `hashCode` overrides

2. **[`lib/services/sim_service.dart`](lib/services/sim_service.dart)**
   - Added deduplication logic in `loadSims()` method

## 🚀 Status

**COMPLETELY FIXED** ✅ 

The dropdown assertion error after saving captures is now fully resolved with a two-layered fix:
1. Proper equality comparison in `SimModel`
2. Automatic duplicate removal in `SimService`

The app now gracefully handles duplicate SIMs and provides debug information when they're detected.
