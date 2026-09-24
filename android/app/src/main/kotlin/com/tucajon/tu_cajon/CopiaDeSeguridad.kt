package com.tucajon.tu_cajon

import android.content.Context
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import com.google.android.gms.auth.blockstore.Blockstore
import com.google.android.gms.auth.blockstore.DeleteBytesRequest
import com.google.android.gms.auth.blockstore.RetrieveBytesRequest
import com.google.android.gms.auth.blockstore.StoreBytesData
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Lo que la copia de seguridad necesita del celular.
 * Canal con lib/core/copia/llaves_de_copia.dart y lib/core/copia/red.dart:
 *
 * - "llaveProtegida"        → si la llave viaja cifrada de extremo a extremo.
 * - "guardarLlave" {llave}  → la guarda en Block Store; devuelve si viaja protegida.
 * - "leerLlave"             → la llave (de este celular o la que llegó de otro), o null.
 * - "borrarLlave"
 * - "red"                   → true si la conexión no cobra por datos (Wi-Fi).
 *
 * Block Store es de Google Play services: guarda unos pocos bytes y, si el
 * celular tiene bloqueo de pantalla, los respalda cifrados con ese PIN,
 * patrón o contraseña, de extremo a extremo (Google no puede leerlos). Al
 * estrenar celular y restaurar la cuenta de Google, vuelven solos.
 */
class CopiaDeSeguridad(private val contexto: Context) {

    private val blockStore by lazy { Blockstore.getClient(contexto) }

    fun registrar(mensajero: BinaryMessenger) {
        MethodChannel(mensajero, "tu_cajon/copia").setMethodCallHandler { llamada, respuesta ->
            when (llamada.method) {
                "llaveProtegida" -> blockStore.isEndToEndEncryptionAvailable()
                    .addOnSuccessListener { respuesta.success(it) }
                    .addOnFailureListener { respuesta.success(false) }

                "guardarLlave" -> {
                    val llave = llamada.argument<ByteArray>("llave")
                    if (llave == null) {
                        respuesta.error("sin_llave", "Falta la llave", null)
                    } else {
                        guardar(llave, respuesta)
                    }
                }

                "leerLlave" -> blockStore
                    .retrieveBytes(RetrieveBytesRequest.Builder().setKeys(listOf(CLAVE)).build())
                    .addOnSuccessListener { r -> respuesta.success(r.blockstoreDataMap[CLAVE]?.bytes) }
                    .addOnFailureListener { respuesta.success(null) }

                "borrarLlave" -> blockStore
                    .deleteBytes(DeleteBytesRequest.Builder().setKeys(listOf(CLAVE)).build())
                    .addOnCompleteListener { respuesta.success(null) }

                "red" -> respuesta.success(sinLimiteDeDatos())

                else -> respuesta.notImplemented()
            }
        }
    }

    /** Solo se respalda en la nube si va cifrada de extremo a extremo. */
    private fun guardar(llave: ByteArray, respuesta: MethodChannel.Result) {
        blockStore.isEndToEndEncryptionAvailable()
            .continueWithTask { revisar ->
                val protegida = revisar.isSuccessful && revisar.result == true
                val datos = StoreBytesData.Builder()
                    .setKey(CLAVE)
                    .setBytes(llave)
                    .setShouldBackupToCloud(protegida)
                    .build()
                blockStore.storeBytes(datos).continueWith { protegida }
            }
            .addOnSuccessListener { respuesta.success(it) }
            .addOnFailureListener { respuesta.error("block_store", it.message, null) }
    }

    private fun sinLimiteDeDatos(): Boolean {
        val conexiones = contexto.getSystemService(ConnectivityManager::class.java) ?: return false
        val capacidades = conexiones.getNetworkCapabilities(conexiones.activeNetwork) ?: return false
        return capacidades.hasCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
    }

    private companion object {
        const val CLAVE = "tu_cajon.llave_copia"
    }
}
