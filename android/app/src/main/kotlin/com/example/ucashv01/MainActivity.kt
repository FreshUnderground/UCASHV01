package com.example.ucashv01

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.print.PrintManager
import android.print.PrintDocumentAdapter
import android.print.PrintAttributes
import android.print.PrintDocumentInfo
import android.content.Context
import android.os.Bundle
import android.util.Log

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.ucash.ucashv01/printer"
    private val TAG = "UCASH_Printer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPrinter" -> {
                    val available = checkPrinterAvailable()
                    result.success(available)
                }
                "printReceipt" -> {
                    val lines = call.argument<List<String>>("lines")
                    if (lines != null) {
                        val success = printReceipt(lines)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "Lines cannot be null", null)
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
            val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
            val hasService = printManager != null
            Log.d(TAG, "Print service available: $hasService")
            hasService
        } catch (e: Exception) {
            Log.e(TAG, "Error checking printer: ${e.message}")
            false
        }
    }

    private fun printReceipt(lines: List<String>): Boolean {
        return try {
            Log.d(TAG, "Printing ${lines.size} lines...")
            
            val printManager = getSystemService(Context.PRINT_SERVICE) as? PrintManager
            if (printManager == null) {
                Log.e(TAG, "PrintManager not available")
                return false
            }

            // Pour Q2i et terminaux POS, utiliser l'imprimante par défaut
            val jobName = "UCASH_Receipt_${System.currentTimeMillis()}"
            
            // Créer un PrintDocumentAdapter simple pour texte
            val adapter = createTextPrintAdapter(lines)
            
            // Déclencher l'impression
            printManager.print(jobName, adapter, null)
            
            Log.d(TAG, "Print job sent successfully")
            true
        } catch (e: Exception) {
            Log.e(TAG, "Print error: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    private fun createTextPrintAdapter(lines: List<String>): PrintDocumentAdapter {
        return object : PrintDocumentAdapter() {
            override fun onLayout(
                oldAttributes: PrintAttributes?,
                newAttributes: PrintAttributes?,
                cancellationSignal: android.os.CancellationSignal?,
                callback: LayoutResultCallback?,
                extras: Bundle?
            ) {
                if (cancellationSignal?.isCanceled == true) {
                    callback?.onLayoutCancelled()
                    return
                }

                val info = PrintDocumentInfo.Builder("receipt.txt")
                    .setContentType(PrintDocumentInfo.CONTENT_TYPE_DOCUMENT)
                    .setPageCount(1)
                    .build()

                callback?.onLayoutFinished(info, true)
            }

            override fun onWrite(
                pages: Array<out android.print.PageRange>?,
                destination: android.os.ParcelFileDescriptor?,
                cancellationSignal: android.os.CancellationSignal?,
                callback: WriteResultCallback?
            ) {
                try {
                    if (cancellationSignal?.isCanceled == true) {
                        callback?.onWriteCancelled()
                        return
                    }

                    val output = java.io.FileOutputStream(destination?.fileDescriptor)
                    val text = lines.joinToString("\n")
                    output.write(text.toByteArray(Charsets.UTF_8))
                    output.close()

                    callback?.onWriteFinished(arrayOf(android.print.PageRange.ALL_PAGES))
                } catch (e: Exception) {
                    Log.e(TAG, "Write error: ${e.message}")
                    callback?.onWriteFailed(e.message)
                }
            }
        }
    }
}
