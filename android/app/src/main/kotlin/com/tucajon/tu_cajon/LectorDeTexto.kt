package com.tucajon.tu_cajon

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.util.Log
import com.google.android.gms.tasks.Tasks
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.Text
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import kotlin.math.atan2
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

/**
 * Lee el texto de una página con el reconocimiento de texto de ML Kit.
 * El modelo viene dentro de la app: funciona sin internet y la imagen no
 * sale del celular. Canal con lib/core/lectura/lector_de_texto.dart:
 *
 * - "leer" {imagen} → {texto, ancho, alto, confianza,
 *     lineas: [{texto, x, y, ancho, alto, angulo, confianza}]}
 *
 * Para leer mejor:
 * - la letra pequeña se agranda (una cédula de lejos, una foto de WhatsApp):
 *   el modelo lee mejor si cada letra mide unos 20 px o más;
 * - si la lectura sale floja (poco texto o poca confianza), se prueba la
 *   página girada y con la luz pareja (sin sombras), y se queda la mejor.
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

    /** Lo que se leyó de una forma de ver la página ([giro], [luzPareja]), y qué tan bien. */
    private class Lectura(
        val texto: Text,
        val ancho: Int,
        val alto: Int,
        val giro: Int,
        val luzPareja: Boolean,
    ) {
        /** Letras leídas (sin espacios). */
        val letras: Int
        /** Letras por su confianza: más texto y más seguro es mejor. */
        val puntaje: Double

        init {
            var n = 0
            var p = 0.0
            for (bloque in texto.textBlocks) {
                for (linea in bloque.lines) {
                    val l = linea.text.count { !it.isWhitespace() }
                    n += l
                    p += l * linea.confidence.toDouble()
                }
            }
            letras = n
            puntaje = p
        }

        /** Confianza media (0 a 1), pesada por las letras de cada renglón. */
        val confianza: Double get() = if (letras == 0) 0.0 else puntaje / letras

        val como: String
            get() = listOfNotNull(
                if (giro == 0) "derecha" else "girada $giro",
                if (luzPareja) "luz pareja" else null,
            ).joinToString(", ")
    }

    private fun leer(bytes: ByteArray): Map<String, Any> {
        val inicio = SystemClock.elapsedRealtime()
        val imagen = abrir(bytes) ?: throw IllegalArgumentException("No es una imagen")
        try {
            var mejor = reconocer(imagen, 0)
            // Casi sin texto o muy dudoso: la foto puede estar de lado o al revés.
            if (mejor.letras < MINIMO_DE_LETRAS || mejor.confianza < CONFIANZA_PARA_GIRAR) {
                for (giro in intArrayOf(90, 270, 180)) {
                    val otra = reconocer(imagen, giro)
                    if (otra.puntaje > mejor.puntaje) mejor = otra
                }
            }
            // Todavía floja: sombras o poca luz. Se prueba con la luz pareja.
            if (mejor.letras > 0 && mejor.confianza < CONFIANZA_BUENA) {
                val pareja = conLuzPareja(imagen)
                try {
                    val otra = reconocer(pareja, mejor.giro, luzPareja = true)
                    if (otra.puntaje > mejor.puntaje) mejor = otra
                } finally {
                    pareja.recycle()
                }
            }
            // Solo números, nunca el texto (son documentos personales).
            Log.d(
                ETIQUETA,
                "Página ${imagen.width}×${imagen.height}: ${mejor.letras} letras, " +
                    "confianza ${(mejor.confianza * 100).roundToInt()} %, ${mejor.como}, " +
                    "${SystemClock.elapsedRealtime() - inicio} ms",
            )
            return aMapa(mejor)
        } finally {
            imagen.recycle()
        }
    }

    private fun reconocer(imagen: Bitmap, giro: Int, luzPareja: Boolean = false): Lectura {
        val texto = Tasks.await(reconocedor.process(InputImage.fromBitmap(imagen, giro)))
        // Las posiciones vienen en la imagen ya girada.
        val deLado = giro == 90 || giro == 270
        return Lectura(
            texto,
            if (deLado) imagen.height else imagen.width,
            if (deLado) imagen.width else imagen.height,
            giro,
            luzPareja,
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
                        "angulo" to anguloDe(linea),
                        "confianza" to linea.confidence.toDouble(),
                    )
                )
            }
        }
        return mapOf(
            "texto" to lectura.texto.text,
            "ancho" to lectura.ancho,
            "alto" to lectura.alto,
            "confianza" to lectura.confianza,
            "lineas" to lineas,
        )
    }

    /**
     * Cuánto está inclinado el renglón (grados, positivo hacia abajo a la
     * derecha), por su borde de arriba: así se pueden ordenar los renglones
     * aunque la foto esté un poco torcida.
     */
    private fun anguloDe(linea: Text.Line): Double {
        val p = linea.cornerPoints
        if (p == null || p.size < 2) return 0.0
        return Math.toDegrees(atan2((p[1].y - p[0].y).toDouble(), (p[1].x - p[0].x).toDouble()))
    }

    /**
     * Abre el JPEG derecho (según su EXIF) y del tamaño en que mejor se lee:
     * una foto muy grande se achica (más rápido, igual de bien) y una pequeña
     * se agranda, para que la letra no quede de pocos píxeles.
     */
    private fun abrir(bytes: ByteArray): Bitmap? {
        val medidas = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(bytes, 0, bytes.size, medidas)
        if (medidas.outWidth <= 0 || medidas.outHeight <= 0) return null
        var muestra = 1
        while (max(medidas.outWidth, medidas.outHeight) / (muestra * 2) >= LADO_IDEAL) muestra *= 2
        val opciones = BitmapFactory.Options().apply { inSampleSize = muestra }
        val imagen = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opciones) ?: return null
        val giro = giroSegunExif(bytes)
        val largo = max(imagen.width, imagen.height)
        val escala = if (largo < LADO_MINIMO) min(AGRANDAR_HASTA, LADO_IDEAL.toFloat() / largo) else 1f
        if (giro == 0 && escala == 1f) return imagen
        val matriz = Matrix().apply {
            postRotate(giro.toFloat())
            postScale(escala, escala)
        }
        val lista = Bitmap.createBitmap(imagen, 0, 0, imagen.width, imagen.height, matriz, true)
        if (lista !== imagen) imagen.recycle()
        return lista
    }

    /**
     * La página en grises con la luz pareja: se divide cada píxel por la luz
     * del papel a su alrededor (así se van las sombras y el papel queda
     * blanco parejo) y se estira el contraste.
     */
    private fun conLuzPareja(imagen: Bitmap): Bitmap {
        val w = imagen.width
        val h = imagen.height
        val pixeles = IntArray(w * h)
        imagen.getPixels(pixeles, 0, w, 0, 0, w, h)
        // La luz del papel: la página muy achicada (las letras desaparecen) y
        // vuelta a agrandar, suave.
        val chica = Bitmap.createScaledBitmap(imagen, max(1, w / 32), max(1, h / 32), true)
        val fondo = Bitmap.createScaledBitmap(chica, w, h, true)
        chica.recycle()
        val luzFondo = IntArray(w * h)
        fondo.getPixels(luzFondo, 0, w, 0, 0, w, h)
        fondo.recycle()
        for (i in pixeles.indices) {
            val l = luz(pixeles[i])
            val f = max(luz(luzFondo[i]), 24)
            // El papel queda en ~255; la tinta, oscura. Un poco más de contraste en los grises.
            val v = (l * 255 / f).coerceIn(0, 255)
            val g = (((v - 40) * 255) / 200).coerceIn(0, 255)
            pixeles[i] = (0xFF shl 24) or (g shl 16) or (g shl 8) or g
        }
        return Bitmap.createBitmap(pixeles, w, h, Bitmap.Config.ARGB_8888)
    }

    private fun luz(c: Int): Int = (((c shr 16) and 0xFF) * 77 + ((c shr 8) and 0xFF) * 150 + (c and 0xFF) * 29) shr 8

    private companion object {
        const val ETIQUETA = "TuCajon/Lectura"

        /** El lado largo con que mejor se lee una página. */
        const val LADO_IDEAL = 2400

        /** Más pequeña que esto, se agranda (hasta [AGRANDAR_HASTA] veces). */
        const val LADO_MINIMO = 2000
        const val AGRANDAR_HASTA = 2.5f

        /** Con menos letras que esto, se prueba la foto girada. */
        const val MINIMO_DE_LETRAS = 12

        /** Confianza media por debajo de la cual se prueba girarla… */
        const val CONFIANZA_PARA_GIRAR = 0.5

        /** …y por debajo de la cual se prueba con la luz pareja. */
        const val CONFIANZA_BUENA = 0.8
    }
}
