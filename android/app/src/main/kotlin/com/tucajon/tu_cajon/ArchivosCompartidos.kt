package com.tucajon.tu_cajon

import androidx.core.content.FileProvider

/**
 * Entrega a WhatsApp el PDF que se arma al compartir, sin abrir la carpeta
 * privada de la app. Es una clase propia (y no FileProvider a secas) para no
 * chocar con el de otros paquetes, como share_plus.
 *
 * Solo expone la carpeta temporal "compartidos" (res/xml/archivos_compartidos.xml).
 */
class ArchivosCompartidos : FileProvider()
