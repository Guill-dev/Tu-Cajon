package com.tucajon.tu_cajon

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import androidx.core.content.IntentCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream
import java.util.concurrent.Executors

/**
 * Recibe lo que otras apps comparten con Tu Cajón ("Compartir → Tu Cajón" en
 * WhatsApp, Gmail, Drive, la galería…): un PDF, o una o varias fotos.
 * Canal con lib/core/archivos/buzon.dart:
 *
 * - "revisar" → si hay algo esperando (la app se abrió desde "Compartir").
 * - "tomar"   → lo que llegó: {archivos: [{nombre, tipo, bytes | problema}], sobrantes}.
 * - Dart recibe "llego" cada vez que llega algo con la app ya abierta.
 *
 * Privacidad: los archivos se leen directo a la memoria, sin copiarlos a
 * ninguna carpeta. Tu Cajón solo puede leer lo que la persona compartió, con
 * el permiso que Android le da para ese envío.
 */
class ArchivosRecibidos(private val contexto: Context) {

    companion object {
        /** Igual que en la app (lib/features/agregar/preparar_pdf.dart). */
        const val MAXIMO_PDF = 50L * 1024 * 1024
        const val MAXIMO_FOTO = 30L * 1024 * 1024

        /** Cuántos archivos se reciben de una vez (todo se lee a la memoria). */
        const val MAXIMO_ARCHIVOS = 30
    }

    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())
    private var canal: MethodChannel? = null

    /** Lo último que llegó y la app todavía no ha tomado. */
    private var pendientes: List<Uri> = emptyList()
    private var tipoDelEnvio: String? = null
    private var sobrantes = 0

    fun registrar(mensajero: BinaryMessenger) {
        canal = MethodChannel(mensajero, "tu_cajon/recibir").apply {
            setMethodCallHandler { llamada, respuesta ->
                when (llamada.method) {
                    "revisar" -> respuesta.success(pendientes.isNotEmpty())
                    "tomar" -> tomar(respuesta)
                    else -> respuesta.notImplemented()
                }
            }
        }
    }

    /** Si [intent] es un envío desde otra app, lo deja esperando y avisa. */
    fun recibir(intent: Intent?) {
        if (intent == null) return
        if (intent.action != Intent.ACTION_SEND && intent.action != Intent.ACTION_SEND_MULTIPLE) return
        // Abierta desde "Recientes": Android repite el envío viejo, que ya se atendió.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return
        val direcciones = direccionesDe(intent)
        if (direcciones.isEmpty()) return
        pendientes = direcciones.take(MAXIMO_ARCHIVOS)
        sobrantes = maxOf(0, direcciones.size - MAXIMO_ARCHIVOS)
        tipoDelEnvio = intent.type
        canal?.invokeMethod("llego", null)
    }

    private fun direccionesDe(intent: Intent): List<Uri> {
        val lista = mutableListOf<Uri>()
        if (intent.action == Intent.ACTION_SEND) {
            IntentCompat.getParcelableExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)?.let(lista::add)
        } else {
            IntentCompat.getParcelableArrayListExtra(intent, Intent.EXTRA_STREAM, Uri::class.java)
                ?.let(lista::addAll)
        }
        // Algunas apps solo lo ponen en ClipData.
        if (lista.isEmpty()) {
            intent.clipData?.let { clip ->
                for (i in 0 until clip.itemCount) clip.getItemAt(i).uri?.let(lista::add)
            }
        }
        return lista.distinct()
    }

    /** Lee lo pendiente fuera del hilo de la pantalla y lo saca del buzón. */
    private fun tomar(respuesta: MethodChannel.Result) {
        val direcciones = pendientes
        val tipo = tipoDelEnvio
        val deMas = sobrantes
        pendientes = emptyList()
        tipoDelEnvio = null
        sobrantes = 0
        hilo.execute {
            val archivos = direcciones.map { leer(it, tipo) }
            principal.post { respuesta.success(mapOf("archivos" to archivos, "sobrantes" to deMas)) }
        }
    }

    private fun leer(uri: Uri, tipoDelEnvio: String?): Map<String, Any?> {
        if (!esSegura(uri)) return mapOf("nombre" to "", "tipo" to "", "problema" to "no_se_pudo")
        val resolver = contexto.contentResolver
        val tipo = (try { resolver.getType(uri) } catch (_: Exception) { null }) ?: tipoDelEnvio ?: ""
        val datos = mapOf("nombre" to nombreDe(uri), "tipo" to tipo)
        val maximo = if (tipo.startsWith("image/")) MAXIMO_FOTO else MAXIMO_PDF
        return try {
            val entrada = resolver.openInputStream(uri) ?: return datos + ("problema" to "no_se_pudo")
            val bytes = entrada.use { leerHasta(it, maximo) }
            if (bytes == null) datos + ("problema" to "muy_grande") else datos + ("bytes" to bytes)
        } catch (e: Exception) {
            datos + ("problema" to "no_se_pudo")
        }
    }

    /**
     * Solo se aceptan archivos que otra app entrega con permiso ("content://"),
     * nunca rutas directas ("file://"): con ellas, una app mal intencionada
     * podría hacer que Tu Cajón lea sus propios archivos privados.
     */
    private fun esSegura(uri: Uri): Boolean =
        uri.scheme == ContentResolver.SCHEME_CONTENT && uri.authority != "${contexto.packageName}.compartir"

    /** "Certificado_EPS.pdf", si la otra app lo dice. */
    private fun nombreDe(uri: Uri): String {
        try {
            contexto.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { fila ->
                    val columna = fila.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (fila.moveToFirst() && columna >= 0) return fila.getString(columna) ?: ""
                }
        } catch (_: Exception) {
            // Sin nombre: la app propone uno.
        }
        return ""
    }

    /** Lee todo, o devuelve null apenas pase de [maximo] bytes. */
    private fun leerHasta(entrada: InputStream, maximo: Long): ByteArray? {
        val salida = ByteArrayOutputStream()
        val trozo = ByteArray(64 * 1024)
        var total = 0L
        while (true) {
            val leidos = entrada.read(trozo)
            if (leidos < 0) break
            total += leidos
            if (total > maximo) return null
            salida.write(trozo, 0, leidos)
        }
        return salida.toByteArray()
    }
}
