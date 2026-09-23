package com.tucajon.tu_cajon

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import android.system.Os
import android.system.OsConstants
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors
import kotlin.math.roundToInt

/**
 * Lee los PDF que se suben al cajón con el lector de PDF de Android.
 * Canal con lib/core/pdf/lector_pdf.dart:
 *
 * - "contar"  {pdf}                       → cuántas páginas tiene.
 * - "dibujar" {pdf, ancho, desde, hasta}  → cada página como JPEG (en memoria).
 *
 * Privacidad: el PDF llega ya descifrado, así que no se deja ninguna copia
 * en el disco. Desde Android 11 se abre solo en memoria (memfd); antes, se
 * escribe un archivo temporal que se borra en el mismo instante en que se
 * abre. Las páginas vuelven como bytes, sin pasar por archivos.
 */
class LectorPdf(private val contexto: Context) {

    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())

    fun registrar(mensajero: BinaryMessenger) {
        MethodChannel(mensajero, "tu_cajon/pdf").setMethodCallHandler { llamada, respuesta ->
            val pdf = llamada.argument<ByteArray>("pdf")
            if (pdf == null) {
                respuesta.error("sin_pdf", "Falta el PDF", null)
                return@setMethodCallHandler
            }
            when (llamada.method) {
                "contar" -> enSegundoPlano(respuesta) { conPdf(pdf) { it.pageCount } }
                "dibujar" -> {
                    val ancho = (llamada.argument<Int>("ancho") ?: 1200).coerceIn(64, 2400)
                    val desde = llamada.argument<Int>("desde") ?: 0
                    val hasta = llamada.argument<Int>("hasta")
                    enSegundoPlano(respuesta) {
                        conPdf(pdf) { lector ->
                            val fin = minOf(hasta ?: lector.pageCount, lector.pageCount)
                            (desde.coerceAtLeast(0) until fin).map { dibujarPagina(lector, it, ancho) }
                        }
                    }
                }
                else -> respuesta.notImplemented()
            }
        }
    }

    /** Hace el trabajo fuera del hilo de la pantalla y responde en él. */
    private fun enSegundoPlano(respuesta: MethodChannel.Result, trabajo: () -> Any) {
        hilo.execute {
            try {
                val resultado = trabajo()
                principal.post { respuesta.success(resultado) }
            } catch (e: SecurityException) {
                // PDF protegido con contraseña.
                principal.post { respuesta.error("con_clave", e.message, null) }
            } catch (e: Exception) {
                principal.post { respuesta.error("pdf_invalido", e.message, null) }
            }
        }
    }

    private fun <T> conPdf(pdf: ByteArray, uso: (PdfRenderer) -> T): T {
        val descriptor = abrirSinDejarCopia(pdf)
        try {
            val lector = PdfRenderer(descriptor)
            try {
                return uso(lector)
            } finally {
                lector.close()
            }
        } finally {
            descriptor.close()
        }
    }

    private fun abrirSinDejarCopia(pdf: ByteArray): ParcelFileDescriptor {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            // Un "archivo" que solo existe en la memoria de la app.
            val fd = Os.memfd_create("tu_cajon_pdf", 0)
            try {
                var escritos = 0
                while (escritos < pdf.size) {
                    escritos += Os.write(fd, pdf, escritos, pdf.size - escritos)
                }
                Os.lseek(fd, 0, OsConstants.SEEK_SET)
                return ParcelFileDescriptor.dup(fd)
            } finally {
                Os.close(fd)
            }
        }
        // Android 10 o anterior: el archivo se borra apenas se abre (lo abierto
        // sigue legible hasta cerrarlo, pero ya no está en la carpeta).
        val temporal = File.createTempFile("pdf", ".bin", contexto.cacheDir)
        try {
            temporal.writeBytes(pdf)
            return ParcelFileDescriptor.open(temporal, ParcelFileDescriptor.MODE_READ_ONLY)
        } finally {
            temporal.delete()
        }
    }

    private fun dibujarPagina(lector: PdfRenderer, indice: Int, ancho: Int): ByteArray {
        val pagina = lector.openPage(indice)
        try {
            val alto = (ancho.toFloat() * pagina.height / pagina.width).roundToInt().coerceIn(1, ancho * 4)
            val imagen = Bitmap.createBitmap(ancho, alto, Bitmap.Config.ARGB_8888)
            try {
                // Fondo blanco: sin él, las páginas "transparentes" salen negras.
                imagen.eraseColor(Color.WHITE)
                pagina.render(imagen, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                val salida = ByteArrayOutputStream()
                imagen.compress(Bitmap.CompressFormat.JPEG, 88, salida)
                return salida.toByteArray()
            } finally {
                imagen.recycle()
            }
        } finally {
            pagina.close()
        }
    }
}
