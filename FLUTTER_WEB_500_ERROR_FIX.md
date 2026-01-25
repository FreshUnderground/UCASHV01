# 🔧 UCASH Flutter Web - Fixing 500 Error on flutter.js

## ❌ Error Description

You encountered these errors when deploying UCASH to `https://safdal.investee-group.com`:

```
GET https://safdal.investee-group.com/flutter.js net::ERR_ABORTED 500 (Internal Server Error)
Uncaught ReferenceError: _flutter is not defined at (index):171:7
Error while trying to use the following icon from the Manifest: 
https://safdal.investee-group.com/icons/Icon-144.png 
(Download error or resource isn't a valid image)
```

## 🎯 Root Causes

### 1. **Missing or Corrupted flutter.js** (500 Error)
- The `flutter.js` file is not being generated or uploaded correctly
- Server misconfiguration blocking JavaScript files
- Incorrect MIME type for `.js` files

### 2. **_flutter is not defined**
- This is a **consequence** of error #1
- When `flutter.js` fails to load, the `_flutter` object doesn't exist
- Your `index.html` line 171 tries to use `_flutter.loader.loadEntrypoint()` but fails

### 3. **Missing/Invalid Icon**
- Icon file not uploaded or corrupted
- Incorrect path in manifest.json

---

## ✅ Complete Solution

### Step 1: Clean Rebuild with Correct Settings

The issue might be caused by using the deprecated `--web-renderer html` flag. 

**Updated build command:**
```bash
flutter build web --release --web-renderer canvaskit --base-href /
```

### Step 2: Deploy Using Updated Script

Run the updated deployment script:

```bash
deploy_lws.bat
```

This will:
1. Clean previous builds
2. Build with correct renderer (canvaskit)
3. Generate all required files including `flutter.js`
4. Include the new `.htaccess` configuration

### Step 3: Verify Build Output

After building, check that these files exist in `build\web\`:

```
build/web/
├── index.html              ✅ Main HTML
├── flutter.js              ✅ Flutter loader (CRITICAL)
├── flutter_bootstrap.js    ✅ Bootstrap script
├── main.dart.js           ✅ Compiled app
├── flutter_service_worker.js
├── manifest.json
├── .htaccess              ✅ Apache config (NEW)
├── assets/
├── canvaskit/             ✅ Renderer engine
└── icons/
    ├── Icon-16.png
    ├── Icon-32.png
    ├── Icon-72.png
    ├── Icon-128.png
    ├── Icon-144.png        ✅ Missing icon
    ├── Icon-192.png
    ├── Icon-512.png
    └── Icon-maskable-*.png
```

**If `flutter.js` is missing**, your Flutter SDK might be outdated. Run:
```bash
flutter upgrade
flutter clean
flutter pub get
flutter build web --release --web-renderer canvaskit
```

### Step 4: Upload to Server

Using FTP/SFTP, upload **ALL** files from `build\web\` to your server:

**Server path:** `/www/` or `/public_html/`

**Important:** Make sure to upload:
- ✅ `.htaccess` (often hidden by default in FTP clients)
- ✅ All files in `icons/` folder
- ✅ All files in `canvaskit/` folder
- ✅ `flutter.js` and `flutter_bootstrap.js`

### Step 5: Set Correct File Permissions

Via SSH or FTP client:
```bash
# Directories: 755
find . -type d -exec chmod 755 {} \;

# Files: 644
find . -type f -exec chmod 644 {} \;
```

### Step 6: Verify Server Configuration

**Check Apache modules** (contact LWS support if needed):
- `mod_rewrite` - For routing
- `mod_headers` - For CORS
- `mod_deflate` - For compression
- `mod_expires` - For caching
- `mod_mime` - For MIME types

---

## 🔍 Troubleshooting Steps

### If flutter.js Still Returns 500

#### Option A: Check Server Error Logs

Contact LWS support to check Apache error logs:
```
/var/log/apache2/error.log
```

Look for PHP errors or permission issues.

#### Option B: Test File Access Directly

Open in browser:
```
https://safdal.investee-group.com/flutter.js
```

**Expected:** JavaScript file downloads or displays
**If 500 error:** Server-side issue (PHP, permissions, .htaccess)

#### Option C: Test Without .htaccess

1. Temporarily rename `.htaccess` to `.htaccess.backup`
2. Test if `flutter.js` loads
3. If it works, there's an issue with `.htaccess` rules

#### Option D: Check MIME Types

Add this to your `.htaccess` if missing:
```apache
<IfModule mod_mime.c>
    AddType application/javascript .js
    AddType application/javascript .mjs
</IfModule>
```

### If Icons Are Missing

1. **Check build output:**
   ```bash
   dir build\web\icons
   ```

2. **Verify manifest.json:**
   ```json
   "icons": [
     {
       "src": "icons/Icon-192.png",
       "sizes": "192x192",
       "type": "image/png"
     },
     {
       "src": "icons/Icon-512.png",
       "sizes": "512x512",
       "type": "image/png"
     }
   ]
   ```

3. **Re-upload icons folder** via FTP

---

## 🚀 Alternative: Use CDN-Based flutter.js

If the server continues to have issues serving `flutter.js`, you can use Flutter's CDN version.

**Modify `web/index.html`** (line 181):

**Before:**
```html
<script src="flutter.js" defer></script>
```

**After:**
```html
<script src="https://unpkg.com/flutter-web-plugins@latest/flutter.js" defer></script>
```

⚠️ **Warning:** This is a temporary workaround. The proper fix is to ensure your server serves `flutter.js` correctly.

---

## 📊 Verification Checklist

After deployment, verify:

- [ ] ✅ `https://safdal.investee-group.com` loads without errors
- [ ] ✅ `https://safdal.investee-group.com/flutter.js` returns JavaScript
- [ ] ✅ No console errors about `_flutter is not defined`
- [ ] ✅ Icons load in browser
- [ ] ✅ PWA manifest loads correctly
- [ ] ✅ Application runs and is interactive
- [ ] ✅ No 500 errors in browser console
- [ ] ✅ HTTPS redirect works
- [ ] ✅ Compression enabled (check Network tab)

---

## 🆘 If All Else Fails

### Contact LWS Support

Provide them with:
1. **Error logs** from Apache
2. **File permissions** for uploaded files
3. **Server configuration** details
4. **This error:** "flutter.js returns 500 Internal Server Error"

### Quick Test Script

Create a test file `test.js` in the same directory:
```javascript
console.log('JavaScript works!');
```

Upload and test: `https://safdal.investee-group.com/test.js`

- **If works:** Issue specific to flutter.js filename/content
- **If fails:** Server blocks all JavaScript files

---

## 🎉 Expected Result

After applying all fixes, you should see:

```
✅ GET https://safdal.investee-group.com/flutter.js 200 OK
✅ No console errors
✅ UCASH application loads and runs
✅ PWA installable
✅ Icons display correctly
```

---

## 📝 Summary of Changes Made

1. ✅ Created `web/.htaccess` with proper Apache configuration
2. ✅ Updated `deploy_lws.bat` to use `--web-renderer canvaskit`
3. ✅ Added proper MIME types for JavaScript files
4. ✅ Configured CORS headers
5. ✅ Set up compression and caching
6. ✅ Added error page redirects

---

## 🔗 Related Files

- [web/.htaccess](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/web/.htaccess) - Apache configuration
- [deploy_lws.bat](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/deploy_lws.bat) - Updated deployment script
- [web/index.html](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/web/index.html) - Main HTML file
- [DEPLOIEMENT_LWS.md](file:///c:/Users/DIEU-MERCI/Documents/projet/UCASHV01/DEPLOIEMENT_LWS.md) - Deployment guide

---

**Created:** January 18, 2026  
**Status:** Ready for deployment  
**Next Step:** Run `deploy_lws.bat` and upload to server
