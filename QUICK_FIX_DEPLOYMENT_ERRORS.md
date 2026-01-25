# 🚨 Quick Fix: UCASH Deployment Errors

## The Errors You're Seeing

```
❌ GET https://safdal.investee-group.com/flutter.js 
   net::ERR_ABORTED 500 (Internal Server Error)

❌ Uncaught ReferenceError: _flutter is not defined

❌ Error while trying to use the following icon from the Manifest:
   https://safdal.investee-group.com/icons/Icon-144.png
```

---

## ⚡ 5-Minute Fix

### Step 1: Run the Fix Script (2 minutes)

```bash
deploy_fix_500_error.bat
```

This will:
- Clean old builds
- Build with correct settings
- Verify all files are present
- Create deployment package

### Step 2: Upload to Server (2 minutes)

**Connect to FTP:**
- Server: Your LWS FTP
- Path: `/www/` or `/public_html/`

**Upload ALL files from:**
```
build\web\  →  Server root directory
```

**⚠️ CRITICAL:** Make sure to upload:
- ✅ `.htaccess` (show hidden files in FTP client!)
- ✅ `flutter.js`
- ✅ All folders: `assets/`, `canvaskit/`, `icons/`

### Step 3: Verify (1 minute)

Open in browser:
```
https://safdal.investee-group.com/flutter.js
```

**✅ Expected:** JavaScript code displays  
**❌ If 500 error:** See troubleshooting below

---

## 🔧 What Was Wrong?

| Error | Cause | Fix |
|-------|-------|-----|
| `flutter.js 500` | Wrong build command or missing file | Use `--web-renderer canvaskit` |
| `_flutter is not defined` | Consequence of above | Fixed when flutter.js loads |
| Missing icons | Not uploaded or wrong path | Upload entire `icons/` folder |
| `.htaccess` issues | Missing or incorrect config | New `.htaccess` created in `web/` |

---

## 🆘 Still Not Working?

### Check #1: Is flutter.js Generated?

```bash
dir build\web\flutter.js
```

**If missing:**
```bash
flutter upgrade
flutter clean
flutter build web --release --web-renderer canvaskit
```

### Check #2: Is .htaccess Uploaded?

In FTP client:
- Enable "Show hidden files"
- Look for `.htaccess` in root
- If missing, upload from `build\web\.htaccess`

### Check #3: File Permissions

Set via SSH or FTP:
- Directories: `755`
- Files: `644`

### Check #4: Server Configuration

Contact LWS support and ask:
- "Is `mod_rewrite` enabled?"
- "Is `mod_mime` enabled?"
- "Can you check Apache error logs for flutter.js?"

---

## 📋 Upload Checklist

Before declaring victory, verify:

- [ ] Uploaded `.htaccess`
- [ ] Uploaded `flutter.js`
- [ ] Uploaded `flutter_bootstrap.js`
- [ ] Uploaded `main.dart.js`
- [ ] Uploaded `manifest.json`
- [ ] Uploaded `assets/` folder
- [ ] Uploaded `canvaskit/` folder
- [ ] Uploaded `icons/` folder (all PNG files)
- [ ] File permissions set (755/644)
- [ ] Browser shows no 500 errors
- [ ] App loads and runs

---

## 🎯 Test URLs

After upload, these should all work:

```
✓ https://safdal.investee-group.com/
✓ https://safdal.investee-group.com/flutter.js
✓ https://safdal.investee-group.com/flutter_bootstrap.js
✓ https://safdal.investee-group.com/manifest.json
✓ https://safdal.investee-group.com/icons/Icon-144.png
✓ https://safdal.investee-group.com/icons/Icon-192.png
```

**Test in browser console (F12):**
```javascript
// Should work after fixing:
console.log(typeof _flutter); // Should output "object"
```

---

## 📚 Full Documentation

For detailed explanation, see:
- **[FLUTTER_WEB_500_ERROR_FIX.md](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/FLUTTER_WEB_500_ERROR_FIX.md)** - Complete troubleshooting guide
- **[DEPLOIEMENT_LWS.md](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/DEPLOIEMENT_LWS.md)** - Full deployment guide

---

## 🎉 Success Indicators

When everything works:

```
✅ No console errors
✅ UCASH logo appears
✅ Loading spinner shows
✅ App loads completely
✅ Login page displays
✅ Navigation works
```

**Browser console should show:**
```
Service Worker désenregistré
(No errors about flutter.js or _flutter)
```

---

**Last Updated:** January 18, 2026  
**Status:** Ready to deploy  
**Next:** Run `deploy_fix_500_error.bat`
