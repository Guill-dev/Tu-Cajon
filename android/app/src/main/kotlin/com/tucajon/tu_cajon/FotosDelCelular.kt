package com.tucajon.tu_cajon

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapRegionDecoder
import android.graphics.Matrix
import android.graphics.Rect
import android.media.ExifInterface
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.util.concurrent.Executors
import kotlin.math.ceil
import kotlin.math.floor
import kotlin.math.roundToInt

/**
 * Lo pesado de las fotos (abrir, recortar, achicar y pasar a JPEG) con el
 * decodificador y el codificador del celular: varias veces más rápido que
 * hacerlo en Dart. Canal con lib/features/escanear/fotos_del_celular.dart:
 *
 * - "medir" {jpeg} → {ancho, alto}: medidas de la foto ya derecha (según su EXIF).
 * - "preparar" {jpeg, amplia: [izq, arriba, der, abajo], parte: [...], ladoMaximo, calidad}
 *     → {base, original}: `original` es la parte [amplia] de la foto (en
 *     píxeles de la foto derecha), enderezada y achicada a [ladoMaximo];
 *     `base` es la parte [parte] dentro de ella.
 * - "codificar" {rgba, ancho, alto, calidad} → JPEG.
 *
 * Todo en memoria, sin archivos. Los JPEG que salen no llevan los datos
 * ocultos de la cámara (EXIF: ubicación, modelo…).
 */
class FotosDelCelular {

    // Uno a la vez y en orden: las fotos salen en el orden en que se tomaron.
    private val hilo = Executors.newSingleThreadExecutor()
    private val principal = Handler(Looper.getMainLooper())

    fun registrar(mensajero: BinaryMessenger) {
        MethodChannel(mensajero, "tu_cajon/fotos").setMethodCallHandler { llamada, respuesta ->
            val trabajo: () -> Any = when (llamada.method) {
                "medir" -> ({ medir(llamada.argument<ByteArray>("jpeg")!!) })
                "preparar" -> ({
                    preparar(
                        llamada.argument<ByteArray>("jpeg")!!,
                        llamada.argument<List<Double>>("amplia")!!,
                        llamada.argument<List<Double>>("parte")!!,
                        llamada.argument<Int>("ladoMaximo") ?: 2400,
                        llamada.argument<Int>("calidad") ?: 92,
                    )
                })
                "codificar" -> ({
                    codificar(
                        llamada.argument<ByteArray>("rgba")!!,
                        llamada.argument<Int>("ancho")!!,
                        llamada.argument<Int>("alto")!!,
                        llamada.argument<Int>("calidad") ?: 92,
                    )
                })
                else -> {
                    respuesta.notImplemented()
                    return@setMethodCallHandler
                }
            }
            hilo.execute {
                try {
                    val resultado = trabajo()
                    principal.post { respuesta.success(resultado) }
                } catch (e: Throwable) {
                    // También si no alcanza la memoria: Dart lo hace a su manera.
                    principal.post { respuesta.error("foto", e.message ?: e.toString(), null) }
                }
            }
        }
    }

    private fun medir(jpeg: ByteArray): Map<String, Int> {
        val (ancho, alto) = medidasGuardadas(jpeg)
        val giro = giroSegunExif(jpeg)
        return if (giro == 90 || giro == 270) {
            mapOf("ancho" to alto, "alto" to ancho)
        } else {
            mapOf("ancho" to ancho, "alto" to alto)
        }
    }

    private fun preparar(
        jpeg: ByteArray,
        amplia: List<Double>,
        parte: List<Double>,
        ladoMaximo: Int,
        calidad: Int,
    ): Map<String, ByteArray> {
        val (ancho, alto) = medidasGuardadas(jpeg)
        val giro = giroSegunExif(jpeg)
        // Solo se abre la parte que sirve, y ya achicada (por mitades) mientras
        // quede más grande que ladoMaximo: es lo más rápido.
        val region = enLaFotoGuardada(amplia, giro, ancho, alto)
        val lado = maxOf(region.width(), region.height())
        var muestra = 1
        while (lado / (muestra * 2) >= ladoMaximo) muestra *= 2
        val decodificador = abrirPorPartes(jpeg)
        val trozo = try {
            decodificador.decodeRegion(
                region,
                BitmapFactory.Options().apply {
                    inSampleSize = muestra
                    inPreferredConfig = Bitmap.Config.ARGB_8888
                },
            )
        } finally {
            decodificador.recycle()
        } ?: throw IllegalArgumentException("No se pudo abrir la foto")

        // Derecha y del tamaño final, en un solo paso (con suavizado).
        val escala = minOf(1f, ladoMaximo.toFloat() / maxOf(trozo.width, trozo.height))
        val lista = if (giro == 0 && escala == 1f) {
            trozo
        } else {
            val matriz = Matrix().apply {
                postRotate(giro.toFloat())
                postScale(escala, escala)
            }
            Bitmap.createBitmap(trozo, 0, 0, trozo.width, trozo.height, matriz, true)
                .also { if (it !== trozo) trozo.recycle() }
        }
        try {
            val original = aJpeg(lista, calidad)
            // Dónde queda la parte dentro de la amplia (en fracciones).
            val aw = amplia[2] - amplia[0]
            val ah = amplia[3] - amplia[1]
            val izq = (parte[0] - amplia[0]) / aw
            val arriba = (parte[1] - amplia[1]) / ah
            val der = (parte[2] - amplia[0]) / aw
            val abajo = (parte[3] - amplia[1]) / ah
            if (izq < 0.002 && arriba < 0.002 && der > 0.998 && abajo > 0.998) {
                return mapOf("base" to original, "original" to original)
            }
            val x = (izq * lista.width).roundToInt().coerceIn(0, lista.width - 1)
            val y = (arriba * lista.height).roundToInt().coerceIn(0, lista.height - 1)
            val w = ((der - izq) * lista.width).roundToInt().coerceIn(1, lista.width - x)
            val h = ((abajo - arriba) * lista.height).roundToInt().coerceIn(1, lista.height - y)
            val recorte = Bitmap.createBitmap(lista, x, y, w, h)
            try {
                return mapOf("base" to aJpeg(recorte, calidad), "original" to original)
            } finally {
                if (recorte !== lista) recorte.recycle()
            }
        } finally {
            lista.recycle()
        }
    }

    private fun codificar(rgba: ByteArray, ancho: Int, alto: Int, calidad: Int): ByteArray {
        val imagen = Bitmap.createBitmap(ancho, alto, Bitmap.Config.ARGB_8888)
        try {
            // En memoria, ARGB_8888 guarda cada píxel como R, G, B, A: igual que Dart.
            imagen.copyPixelsFromBuffer(ByteBuffer.wrap(rgba))
            return aJpeg(imagen, calidad)
        } finally {
            imagen.recycle()
        }
    }

    private fun aJpeg(imagen: Bitmap, calidad: Int): ByteArray {
        val salida = ByteArrayOutputStream(imagen.width * imagen.height / 3)
        imagen.compress(Bitmap.CompressFormat.JPEG, calidad, salida)
        return salida.toByteArray()
    }

    /** Ancho y alto tal como está guardada (sin girar), sin abrirla. */
    private fun medidasGuardadas(jpeg: ByteArray): Pair<Int, Int> {
        val medidas = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size, medidas)
        if (medidas.outWidth <= 0 || medidas.outHeight <= 0) throw IllegalArgumentException("No es una foto")
        return Pair(medidas.outWidth, medidas.outHeight)
    }

    /**
     * El rectángulo [r] (izquierda, arriba, derecha, abajo) de la foto ya
     * derecha, en la foto tal como está guardada ([ancho]×[alto]) antes de
     * girarla [giro] grados.
     */
    private fun enLaFotoGuardada(r: List<Double>, giro: Int, ancho: Int, alto: Int): Rect {
        val (izq, arriba, der, abajo) = r
        val (gi, ga, gd, gb) = when (giro) {
            90 -> listOf(arriba, alto - der, abajo, alto - izq)
            180 -> listOf(ancho - der, alto - abajo, ancho - izq, alto - arriba)
            270 -> listOf(ancho - abajo, izq, ancho - arriba, der)
            else -> listOf(izq, arriba, der, abajo)
        }
        val i = floor(gi).toInt().coerceIn(0, ancho - 1)
        val a = floor(ga).toInt().coerceIn(0, alto - 1)
        return Rect(i, a, ceil(gd).toInt().coerceIn(i + 1, ancho), ceil(gb).toInt().coerceIn(a + 1, alto))
    }

    @Suppress("DEPRECATION")
    private fun abrirPorPartes(jpeg: ByteArray): BitmapRegionDecoder =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            BitmapRegionDecoder.newInstance(jpeg, 0, jpeg.size)
        } else {
            BitmapRegionDecoder.newInstance(jpeg, 0, jpeg.size, false)
        } ?: throw IllegalArgumentException("No se pudo abrir la foto")
}

/** Cuántos grados hay que girar la foto para verla derecha, según su EXIF. */
internal fun giroSegunExif(bytes: ByteArray): Int {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.N) return 0
    return try {
        when (ExifInterface(ByteArrayInputStream(bytes))
            .getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90
            ExifInterface.ORIENTATION_ROTATE_180 -> 180
            ExifInterface.ORIENTATION_ROTATE_270 -> 270
            else -> 0
        }
    } catch (_: Exception) {
        0
    }
}
