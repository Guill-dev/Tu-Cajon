# Reglas para el optimizador (R8) de la versión final.

# ML Kit (leer documentos, ver LectorDeTexto.kt): al arrancar crea sus componentes por
# reflexión, con el constructor vacío. Sin esta regla R8 lo quita, ML Kit no se inicia
# y la lectura falla en silencio ("NoSuchMethodException ... Registrar.<init>").
-keep class * implements com.google.firebase.components.ComponentRegistrar { <init>(); }

# Inicio de sesión de Google (copia en Google Drive): Credential Manager busca su
# proveedor de Play Services por reflexión; sin esto, R8 lo quita en la versión final.
-if class androidx.credentials.CredentialManager
-keep class androidx.credentials.playservices.** {
  *;
}
