package com.example.ucashv01

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Context
import android.os.Bundle
import android.util.Log
import java.io.IOException

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ucash.ucashv01/printer"
    private val TAG = "UCASH_Printer"
    private var printerDevice: Any? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPrinter" -> {
                    val available = checkPrinterAvailable()
                    result.success(available)
                }
                "printReceipt" -> {
                    // Recevoir le texte complet au lieu de la liste
                    val data = call.argument<String>("data")
                    if (data != null) {
                        Log.d(TAG, "Received print data: ${data.length} characters")
                        val success = printReceiptText(data)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Data cannot be null", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun checkPrinterAvailable(): Boolean {
        return try {
            Log.d(TAG, "Vérification imprimante Q2I...")
            
            // Afficher les informations du périphérique
            val model = android.os.Build.MODEL
            val manufacturer = android.os.Build.MANUFACTURER
            val device = android.os.Build.DEVICE
            Log.d(TAG, "Device info: $manufacturer $model ($device)")
            
            // Méthode 1: Vérifier si le fichier de périphérique existe (Q2I)
            val printerDeviceFile = java.io.File("/dev/ttyS4")
            if (printerDeviceFile.exists()) {
                Log.d(TAG, "✅ Q2I printer device found: /dev/ttyS4")
                Log.d(TAG, "  - Can read: ${printerDeviceFile.canRead()}")
                Log.d(TAG, "  - Can write: ${printerDeviceFile.canWrite()}")
                return true
            }
            
            // Vérifier via les propriétés système
            if (model.contains("Q2I", ignoreCase = true) || 
                model.contains("Q2", ignoreCase = true)) {
                Log.d(TAG, "✅ Q2I terminal detected by model name")
                return true
            }
            
            // Méthode 3: Vérifier les autres fichiers de périphérique courants
            val commonPrinterPaths = listOf(
                "/dev/ttyS0",
                "/dev/ttyS1",
                "/dev/ttyS2",
                "/dev/ttyS3",
                "/dev/ttyS4",
                "/dev/ttyMT0",
                "/dev/ttyMT1",
                "/dev/ttyMT2"
            )
            
            for (path in commonPrinterPaths) {
                val file = java.io.File(path)
                if (file.exists()) {
                    Log.d(TAG, "✅ Printer device found: $path")
                    Log.d(TAG, "  - Can read: ${file.canRead()}")
                    Log.d(TAG, "  - Can write: ${file.canWrite()}")
                    return true
                }
            }
            
            Log.d(TAG, "❌ No Q2I printer device found")
            Log.d(TAG, "TIP: Device may require root permissions or SELinux policy")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Error checking printer: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun printReceiptText(text: String): Boolean {
        return try {
            Log.d(TAG, "Printing text to Q2I... (${text.length} chars)")
            Log.d(TAG, "First 100 chars: ${text.take(100)}")
            
            // Essayer d'ouvrir le périphérique d'imprimante Q2I
            val printerPaths = listOf(
                "/dev/ttyS4",  // Q2I principal
                "/dev/ttyMT1",
                "/dev/ttyMT2",
                "/dev/ttyS0"
            )
            
            for (path in printerPaths) {
                val deviceFile = java.io.File(path)
                if (deviceFile.exists()) {
                    Log.d(TAG, "🔍 Trying device: $path")
                    Log.d(TAG, "  - Exists: true")
                    Log.d(TAG, "  - Can read: ${deviceFile.canRead()}")
                    Log.d(TAG, "  - Can write: ${deviceFile.canWrite()}")
                    
                    if (printToDevice(path, text)) {
                        Log.d(TAG, "✅ Print successful on $path")
                        return true
                    } else {
                        Log.w(TAG, "⚠️ Print failed on $path, trying next...")
                    }
                }
            }
            
            Log.e(TAG, "❌ Failed to print to any device")
            false
        } catch (e: Exception) {
            Log.e(TAG, "Print error: ${e.message}")
            e.printStackTrace()
            false
        }
    }
    
    private fun printToDevice(devicePath: String, text: String): Boolean {
        var outputStream: java.io.FileOutputStream? = null
        return try {
            Log.d(TAG, "🔗 Opening device: $devicePath")
            
            // Ouvrir le flux vers le périphérique
            outputStream = java.io.FileOutputStream(devicePath)
            
            // Commandes ESC/POS pour imprimante thermique
            val ESC = 0x1B
            val GS = 0x1D
            val LF = 0x0A
            val CR = 0x0D
            
            Log.d(TAG, "📋 Initializing printer...")
            
            // Initialiser l'imprimante ESC @
            outputStream.write(ESC)
            outputStream.write('@'.code)
            Thread.sleep(100)
            
            Log.d(TAG, "📝 Writing text (${text.length} chars)...")
            
            // Convertir le texte en lignes et imprimer
            val lines = text.split("\n")
            Log.d(TAG, "Number of lines: ${lines.size}")
            
            for ((index, line) in lines.withIndex()) {
                // Écrire la ligne
                val lineBytes = line.toByteArray(Charsets.UTF_8)
                outputStream.write(lineBytes)
                
                // Saut de ligne
                outputStream.write(LF)
                outputStream.write(CR)
                
                // Log progress every 10 lines
                if (index % 10 == 0) {
                    Log.d(TAG, "  Written line $index/${lines.size}")
                }
            }
            
            Log.d(TAG, "📄 Feeding paper...")
            
            // Avancer le papier (5 lignes)
            for (i in 0 until 5) {
                outputStream.write(LF)
                outputStream.write(CR)
            }
            
            Log.d(TAG, "✂️ Cutting paper...")
            
            // Couper le papier - GS V m
            outputStream.write(GS)
            outputStream.write('V'.code)
            outputStream.write(0)
            
            // Flush pour forcer l'envoi
            outputStream.flush()
            
            Log.d(TAG, "⏳ Waiting for print to complete...")
            Thread.sleep(500)
            
            outputStream.close()
            
            Log.d(TAG, "✅ Print to $devicePath completed successfully")
            true
        } catch (e: java.io.IOException) {
            Log.e(TAG, "❌ IO Error printing to $devicePath: ${e.message}")
            Log.e(TAG, "  Error type: ${e.javaClass.simpleName}")
            e.printStackTrace()
            false
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ Security Error (permissions): ${e.message}")
            e.printStackTrace()
            false
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error printing to $devicePath: ${e.message}")
            e.printStackTrace()
            false
        } finally {
            try {
                outputStream?.close()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing stream: ${e.message}")
            }
        }
    }
}
