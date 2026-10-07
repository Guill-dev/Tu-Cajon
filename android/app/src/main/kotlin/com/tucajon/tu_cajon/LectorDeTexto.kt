package com.tucajon.tu_cajon

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Lee el texto de una página con el reconocimiento de texto de ML Kit.
 * El modelo viene dentro de la app: funciona sin internet y la imagen no
 * sale del celular. Canal con lib/core/lectura/lector_de_texto.dart:
 *
 * - "leer" {imagen} → {texto, ancho, alto, lineas: [{texto, x, y, ancho, alto}]}
 *
 * La imagen llega ya descifrada y se lee solo en memoria (sin archivos).
 */
class LectorDeTexto {

    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())
    private val reconocedor by lazy { TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS) }

    fun registrar(mensajero: BinaryMessenger) {
        MethodChannel(mensajero, "tu_cajon/leer").setMethodCallHandler { llamada, respuesta ->
            when (llamada.method) {
                "leer" -> {
                    val imagen = llamada.argument<ByteArray>("imagen")
                    if (imagen == null) {
                        respuesta.error("sin_imagen", "Falta la imagen", null)
                        return@setMethodCallHandler
                    }
                    // Fuera del hilo de la pantalla: leer una página tarda un poco.
                    hilo.execute {
                        try {
                            val resultado = leer(imagen)
                            principal.post { respuesta.success(resultado) }
                        } catch (e: Exception) {
                            principal.post { respuesta.error("no_se_leyo", e.message, null) }
                        }
                    }
                }
                else -> respuesta.notImplemented()
            }
        }
    }

    private class Lectura(val texto: Text, val ancho: Int, val alto: Int)

    private fun leer(bytes: ByteArray): Map<String, Any> {
        val imagen = abrir(bytes) ?: throw IllegalArgumentException("No es una imagen")
        try {
            var mejor = reconocer(imagen, 0)
            // Casi sin texto: la foto puede estar de lado o al revés.
            if (mejor.texto.text.length < MINIMO_DE_LETRAS) {
                for (giro in intArrayOf(90, 270, 180)) {
                    val otra = reconocer(imagen, giro)
                    if (otra.texto.text.length > mejor.texto.text.length) mejor = otra
                }
            }
            return aMapa(mejor)
        } finally {
            imagen.recycle()
        }
    }

    private fun reconocer(imagen: Bitmap, giro: Int): Lectura {
        val texto = Tasks.await(reconocedor.process(InputImage.fromBitmap(imagen, giro)))
        // Las posiciones vienen en la imagen ya girada.
        val deLado = giro == 90 || giro == 270
        return Lectura(
            texto,
            if (deLado) imagen.height else imagen.width,
            if (deLado) imagen.width else imagen.height,
        )
    }

    private fun aMapa(lectura: Lectura): Map<String, Any> {
        val lineas = mutableListOf<Map<String, Any>>()
        for (bloque in lectura.texto.textBlocks) {
            for (linea in bloque.lines) {
                val caja = linea.boundingBox ?: continue
                lineas.add(
                    mapOf(
                        "texto" to linea.text,
                        "x" to caja.left,
                        "y" to caja.top,
                        "ancho" to caja.width(),
                        "alto" to caja.height(),
                    )
                )
            }
        }
        return mapOf(
            "texto" to lectura.texto.text,
            "ancho" to lectura.ancho,
            "alto" to lectura.alto,
            "lineas" to lineas,
        )
    }

    /**
     * Abre el JPEG derecho (según su EXIF) y sin pasarse de tamaño: una foto
     * de 12 MP se lee igual de bien a la mitad, y más rápido.
     */
    private fun abrir(bytes: ByteArray): Bitmap? {
        val medidas = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, medidas)
        if (medidas.outWidth <= 0 || medidas.outHeight <= 0) return null
        var muestra = 1
        while (maxOf(medidas.outWidth, medidas.outHeight) / (muestra * 2) >= LADO_MINIMO) muestra *= 2
        val opciones = BitmapFactory.Options().apply { inSampleSize = muestra }
        val imagen = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opciones) ?: return null
        val giro = giroSegunExif(bytes)
        if (giro == 0) return imagen
        val derecha = Bitmap.createBitmap(
            imagen, 0, 0, imagen.width, imagen.height, Matrix().apply { postRotate(giro.toFloat()) }, true,
        )
        if (derecha !== imagen) imagen.recycle()
        return derecha
    }

    // giroSegunExif: en FotosDelCelular.kt.

    private companion object {
        /** El lado largo queda entre 1600 y 3200 píxeles. */
        const val LADO_MINIMO = 1600

        /** Con menos letras que esto, se prueba la foto girada. */
        const val MINIMO_DE_LETRAS = 12
    }
}
