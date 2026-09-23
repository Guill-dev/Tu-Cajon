package com.tucajon.tu_cajon

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// FragmentActivity: la necesita el diálogo de huella, rostro o PIN (local_auth).
class MainActivity : FlutterFragmentActivity() {

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // Lector de los PDF que se suben (ver LectorPdf.kt).
        LectorPdf(applicationContext).registrar(flutterEngine.dartExecutor.binaryMessenger)
        // Canal con lib/core/compartir/compartidor.dart.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tu_cajon/compartir")
            .setMethodCallHandler { llamada, respuesta ->
                when (llamada.method) {
                    "whatsapp" -> {
                        val ruta = llamada.argument<String>("ruta")
                        if (ruta == null) {
                            respuesta.error("sin_ruta", "Falta la ruta del PDF", null)
                        } else {
                            respuesta.success(enviarPorWhatsApp(File(ruta)))
                        }
                    }
                    else -> respuesta.notImplemented()
                }
            }
    }

    /**
     * Abre WhatsApp (o WhatsApp Business) directo en "Enviar a…" con el PDF.
     * Devuelve false si ninguno de los dos está instalado.
     *
     * WhatsApp solo recibe permiso de lectura para este archivo, y solo
     * mientras lo envía (FLAG_GRANT_READ_URI_PERMISSION).
     */
    private fun enviarPorWhatsApp(pdf: File): Boolean {
        val uri = FileProvider.getUriForFile(this, "$packageName.compartir", pdf)
        for (app in listOf("com.whatsapp", "com.whatsapp.w4b")) {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "application/pdf"
                putExtra(Intent.EXTRA_STREAM, uri)
                clipData = ClipData.newRawUri(pdf.name, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                setPackage(app)
            }
            try {
                startActivity(intent)
                return true
            } catch (_: ActivityNotFoundException) {
                // No está instalada: se prueba la siguiente.
            }
        }
        return false
    }
}
