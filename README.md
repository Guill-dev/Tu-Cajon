# Tu Cajón (app Flutter)

Tus papeles importantes, guardados y siempre a la mano.

Este proyecto convierte a código Flutter las **12 pantallas del prototipo "Tu Cajón (v2)"**, con sus animaciones e interacciones.
**No tiene servidor ni nube.** Todo se guarda en una base de datos **SQLite cifrada dentro del
celular**, usando Drift. Detalles en [Los datos](#los-datos-drift--sqlite-cifrado).

---

## Cómo correrlo

```bash
flutter pub get
flutter run                 # en un celular o emulador Android conectado
flutter run -d chrome       # para verlo rápido en el navegador
flutter test                # pruebas de la base de datos y de las 12 pantallas
dart run build_runner build # regenera base_datos.g.dart si cambias las tablas
```

La primera compilación descarga SQLite3MultipleCiphers (la versión de SQLite con cifrado),
verificado con su huella sha256. Es automático, lo hace el paquete `sqlite3`.

**Atajo para desarrollar:** en la pantalla de carga, **mantén presionado** para abrir el
*catálogo de pantallas* y saltar directo a cualquiera. Solo funciona en modo debug.

---

## Cómo está organizado

```
lib/
├── main.dart                  Arranque: abre la base de datos y lanza la app en vertical.
├── app.dart                   MaterialApp: tema, idioma español (es-CO), rutas y repositorio.
│
├── core/                      Lo que usa toda la app. No depende de ninguna pantalla.
│   ├── theme/
│   │   ├── app_colors.dart    Todos los colores del diseño, con nombre (fondo, primario, ámbar…).
│   │   ├── app_text.dart      Tipografía: Plus Jakarta Sans (títulos gruesos y texto).
│   │   ├── app_decor.dart     Tarjetas: radio, sombras suaves y sombras de color.
│   │   └── app_theme.dart     ThemeData de Material.
│   ├── icons/app_icons.dart   Los íconos del diseño como trazos SVG (idénticos al prototipo).
│   ├── router/app_routes.dart Nombres de las rutas y qué pantalla abre cada una.
│   ├── seguridad/             Llave del celular (huella/PIN) y cerrojo al salir de la app.
│   ├── copia/                 Para la copia de seguridad: dónde vive su llave (Block Store)
│                              y si hay Wi-Fi.
│   ├── avisos/                Notificaciones: avisos de vencimiento y recordatorios.
│   ├── compartir/             Arma el PDF y lo entrega a WhatsApp o al menú de compartir.
│   ├── archivos/              Abre la galería y el explorador de archivos del sistema, y
│                              recibe lo que llega por "Compartir → Tu Cajón" (buzón).
│   ├── pdf/                   Lee los PDF subidos con el lector nativo (sin dejar copias).
│   ├── formato.dart           Fechas en español, tamaños ("480 KB") y búsqueda sin tildes.
│   └── motion.dart            Curva "suave" del diseño y detector de "reducir animaciones".
│
├── data/                      Los datos (ver "Los datos" más abajo).
│   ├── models/                Documento, Categoria (carpetas), Perfil.
│   ├── db/                    Base de datos: tablas, índice de búsqueda y apertura cifrada.
│   ├── repositorio/           CajonRepositorio: lo único que usan las pantallas.
│   ├── copia/                 Copia de seguridad: cifrado, índice, nube y programador.
│   └── datos_ejemplo.dart     Marta y Mamá (solo en desarrollo y en la vista web).
│
├── shared/                    Piezas reutilizables entre pantallas.
│   ├── widgets/               Botones, TcIcon, TcTap (base táctil), toast, hoja inferior,
│   │                          campo de texto, borde punteado, anillo que late, etc.
│   └── illustrations/         Dibujos: el cajón del ícono (`cajon_dibujo.dart`, en código
│                              para moverlo por partes), su animación de entrada, su versión
│                              pequeña que se abre, lápiz mascota y cédula esquemática.
│
└── features/                  Una carpeta por pantalla (o grupo de pantallas).
    ├── carga/                 1 · Carga (caen los papeles al cajón del ícono)
    ├── bienvenida/            2 · Bienvenida (el lápiz pregunta tu nombre)
    ├── proteccion/            3 · La llave del cajón
    ├── desbloqueo/            4 · Abrir el cajón (cuando vuelves)
    ├── cajon/                 Contenedor con la barra inferior (Mi cajón · + · Avisos)
    ├── inicio/                5 · Mi cajón (perfiles, buscador, lista)
    ├── detalle/               6 · Documento: editar, reemplazar, eliminar y enviar por WhatsApp
    ├── avisos/                7 · Avisos y sugerencias con IA
    ├── agregar/               8 · Agregar documento
    ├── escanear/              9 · Escanear con la cámara (formatos, recorte, filtros, revisar foto)
    ├── paginas/               Tus páginas: fotos de la galería antes de guardarlas
    ├── recibir/               Lo que llega desde WhatsApp, Gmail, Drive o la galería
    ├── guardar/               10 · Guardar (la IA llena los datos)
    ├── preguntar/             11 · Pregúntale a tu cajón (chat IA)
    ├── ajustes/               Ajustes: la copia de seguridad en Google Drive
    ├── recuperar/             Recuperar mi cajón (al estrenar celular)
    ├── perfil/                12 · Nuevo perfil (Mamá, mascotas…)
    └── catalogo/              Solo desarrollo: lista de todas las pantallas

test/copia_test.dart           Copia de seguridad: cifrado, solo sube lo nuevo, recuperar con
                               la llave o con el código de emergencia, Wi-Fi y errores.
test/base_datos_test.dart      Base SQLite real (en memoria): búsqueda, guardar, renombrar,
                               eliminar, perfiles, vencimientos, sugerencias y la IA local.
test/pantallas_test.dart       Abre las 12 pantallas en tamaño celular (390×844) y prueba
                               el flujo: nombre → llave → Mi cajón → buscar → Avisos, etc.
```

### El estilo visual (v3)

Inspirado en una referencia de app de libros: fondo azul muy claro, tarjetas blancas
grandes y redondeadas **sin bordes y con sombra suave**, títulos en dos tonos
("Hola, / **Marta**"), acento azul-violeta, botones cuadrados redondeados en amarillo,
tarjeta seleccionada rellena de color y barra inferior flotante en forma de píldora.
La letra es **Plus Jakarta Sans**.

Todo sale de tres archivos. Si cambias algo ahí, cambia en toda la app:

| Archivo | Qué define |
|---|---|
| `core/theme/app_colors.dart` | Colores (`fondo`, `primario`, `amarillo`, `tituloSuave`…) |
| `core/theme/app_text.dart` | Letra: `display` (títulos gruesos), `displayLight` (primera línea gris), `body` |
| `core/theme/app_decor.dart` | Forma de las tarjetas: `AppDecor.tarjeta()`, radio 24, sombras |

Piezas del estilo: `TwoToneTitle` y `BackHeader` en `shared/widgets/common.dart`, y
`SquircleButton`, `ArrowButton` y `PillChip` en `shared/widgets/buttons.dart`.

### La regla de las capas

`features` usa `shared`, `data` y `core`. `shared` usa `core`. `core` no usa a nadie.
Si una pieza sirve en dos pantallas, se mueve a `shared/`. Si solo sirve en una, va en
`features/<pantalla>/widgets/`.

---

## Cómo se navega

| Desde | Acción | Va a |
|---|---|---|
| Carga | tocar la pantalla | Bienvenida (o *Abrir el cajón* si ya activaste la llave) |
| Bienvenida | Continuar | La llave del cajón |
| Bienvenida | ¿Ya tenías Tu Cajón en otro celular? | Recuperar mi cajón → La llave del cajón |
| La llave | Activar → ¡Listo! → Abrir mi cajón | Mi cajón (borra el historial) |
| Abrir el cajón | huella o PIN | Mi cajón |
| Mi cajón | tocar un documento | Documento |
| Mi cajón | burbuja de chat | Pregúntale a tu cajón |
| Mi cajón | "+ Nuevo" | Nuevo perfil |
| Mi cajón | botón de ajustes | Ajustes (copia de seguridad) |
| Mi cajón | tarjeta de sugerencia | pestaña Avisos |
| Barra inferior | + Agregar | Agregar → Escanear → Guardar → Documento |
| Agregar | Subir un PDF | explorador de archivos → Guardar → Documento |
| Agregar | Fotos de la galería | galería → Tus páginas → Guardar → Documento |
| Otra app (WhatsApp, Gmail, Drive, galería) | Compartir → Tu Cajón | la llave → un PDF va a Guardar; fotos, a Tus páginas → Guardar |

"Mi cajón" y "Avisos" son dos pestañas del mismo contenedor (`features/cajon/cajon_shell.dart`).
Por eso, al cambiar de pestaña, cada una conserva sus filtros y lo que ya descartaste.

---

## Animaciones del diseño y dónde están

| Animación | Archivo |
|---|---|
| Carga: el cajón del ícono aparece, caen los papeles a la bandeja, la cerradura gira y brilla; luego los papeles se mecen | `shared/illustrations/cajon_animado.dart` |
| Llave: al abrir, la cerradura gira, el cajón azul sale y los papeles saltan | `shared/illustrations/cajon_mini.dart` |
| El lápiz flota y saluda con el brazo | `shared/illustrations/lapiz_mascota.dart` |
| Anillos que laten alrededor de la huella | `shared/widgets/pulse_ring.dart` |
| Hojas inferiores que suben (la llave) | `shared/widgets/sheet.dart` |
| Avisos flotantes (toast) | `shared/widgets/toast.dart` |
| Destello de la foto y miniaturas que aparecen | `features/escanear/escanear_screen.dart` |
| Mensajes del chat que suben | `features/preguntar/preguntar_screen.dart` |
| Interruptor "¿se vence?" y tarjetas de Avisos que se cierran | `guardar/` y `avisos/` |

Si el celular tiene activado **"reducir animaciones"**, las animaciones en bucle se
detienen y el cajón aparece ya abierto.

---

## Los datos (Drift + SQLite cifrado)

```
Pantalla ──context.repo──▶ CajonRepositorio (interfaz)
                              ├─ DriftCajonRepositorio   → SQLite cifrado (celular)
                              └─ MemoriaCajonRepositorio → en memoria (web y pruebas)
```

- **Las pantallas no hablan con la base de datos:** usan `context.repo` (`data/repositorio/`).
  Los métodos `vigilar…` devuelven `Stream`s. Si guardas o renombras un documento,
  "Mi cajón", "Avisos" y el contador de la barra se actualizan solos.
- **Tablas** (`data/db/tablas.dart`): `perfiles`, `documentos` (borrar un perfil borra sus
  documentos), `ajustes` (nombre, llave activada) y `sugerencias_descartadas`.
- **Búsqueda:** índice FTS5 `documentos_fts` que mantienen unos triggers. Busca por nombre,
  carpeta y texto leído del documento, sin importar las tildes ("conduccion" encuentra
  "conducción"). Lo usan el buscador de "Mi cajón" y "Pregúntale a tu cajón". Al tocar el
  buscador, "Mi cajón" esconde el saludo y los perfiles para dejar la lista debajo, y la barra
  de abajo se oculta mientras el teclado está abierto; "Cancelar" o atrás vuelven a lo normal.
- **Cifrado** (`data/db/conexion_nativa.dart`): el archivo `tu_cajon.sqlite` está en la carpeta
  privada de la app y se cifra con SQLite3MultipleCiphers (`hooks:` en `pubspec.yaml`).
  - La clave es aleatoria y se crea la primera vez. Se guarda en el almacén seguro del sistema
    (Keychain / Keystore) con `flutter_secure_storage`, nunca en el código.
  - Si por error se enlazara SQLite sin cifrado, la app falla al abrir en vez de guardar en claro.
- **La copia automática de Android está desactivada** (`allowBackup="false"`). Sin la clave,
  una base restaurada no se podría abrir. La copia de la app es otra, cifrada con su propia
  llave: ver [La copia de seguridad](#la-copia-de-seguridad).
- **Datos de ejemplo:** en modo desarrollo, una base nueva arranca con Marta y Mamá. En una
  versión de producción el cajón empieza vacío. El catálogo de pantallas tiene un botón para
  borrar todo y volver a cargarlos.
- **Web:** no hay SQLite nativo, así que `flutter run -d chrome` usa `MemoriaCajonRepositorio`.
- **Cambiar una tabla:** súbele el número a `schemaVersion` en `data/db/base_datos.dart`, agrega el
  paso en `onUpgrade` y corre `dart run build_runner build`.
- **Qué calcula el código:** "Vence en 18 días", "Tiene 2 meses" y las sugerencias de Avisos
  salen de las fechas guardadas (`data/models/documento.dart` y
  `features/avisos/sugerencias.dart`), no de textos fijos.

---

## La copia de seguridad

Se activa en **Ajustes → Conectar con Google**. No es un registro: es un permiso sobre la
propia cuenta de Google de la persona, solo para una carpeta oculta de la app en su Drive.

```
Ajustes / Recuperar ──context.copia──▶ CopiaDeSeguridad (data/copia/)
                                         ├─ Nube: NubeDePrueba hoy · Google Drive después
                                         ├─ LlavesDeCopia: almacén seguro + Block Store
                                         └─ Red: ¿hay Wi-Fi?
```

- **Todo va cifrado antes de salir** (AES-256-GCM, `data/copia/cifrado_copia.dart`) con una
  llave propia de la copia (32 bytes al azar). Google guarda archivos que no puede abrir.
- **Qué sube:** `tucajon-indice.bin` (perfiles, documentos, fechas, en JSON cifrado), un
  `tucajon-doc-<id>-<versión>.bin` por documento con sus fotos o su PDF, y
  `tucajon-emergencia.bin` si hay código de emergencia.
- **Solo sube lo nuevo:** si un documento no cambió, su archivo ya está en la nube. Primero se
  suben los archivos, después el índice y al final se borra lo que ya no se usa, así la copia
  de la nube siempre está completa.
- **Se hace sola** (`ProgramadorDeCopias`): 20 segundos después del último cambio, y al abrir
  la app si la última tiene más de un día. "Solo con Wi-Fi" (activado de entrada) hace que la
  automática espere el Wi-Fi; "Hacer copia ahora" no espera.
- **Sin contraseñas:** la llave de la copia se guarda en **Block Store** de Google
  (`CopiaDeSeguridad.kt`), protegida con el PIN, patrón o contraseña de bloqueo del celular,
  de extremo a extremo. Al estrenar celular y restaurar la cuenta de Google, la llave llega
  sola (Android 12 o más nuevo; Pixel desde Android 9).
- **Código de emergencia** (opcional, Ajustes): 16 letras y números que protegen otra copia
  de la llave. Sirve si el celular nuevo no restauró la cuenta de Google o el viejo no tenía
  bloqueo de pantalla. Se muestra una sola vez.
- **Recuperar** (bienvenida → "¿Ya tenías Tu Cajón…?"): busca la copia, la abre con la llave
  o con el código, y cambia todo el cajón por el de la copia (`restaurar` en el repositorio:
  todo o nada). Después sigue a la llave del cajón de ese celular.
- **Modo de prueba (hoy):** mientras no esté el proyecto de Google Cloud, la "nube" es una
  carpeta dentro del mismo celular (`nube_de_prueba/`, en la carpeta privada de la app). Todo
  lo demás es igual a como será con Drive. Para conectar Drive falta: el proyecto en Google
  Cloud con la API de Drive, la pantalla de permiso, la firma propia de la app y el permiso de
  internet.

---

## Qué sigue simulado (para conectar después)

| Hoy | Después |
|---|---|
| La IA de "Guardar" siempre propone "Cédula de ciudadanía" | Reconocimiento de texto en el celular (OCR) que llene `textoExtraido` |
| El chat usa búsqueda + reglas (`preguntar/respuestas_demo.dart`) | Modelo de IA local sobre tus documentos |
| La copia de seguridad se guarda en una carpeta del mismo celular (modo de prueba) | Google Drive: carpeta oculta de la app, con un proyecto de Google Cloud |
| "Compartir → Tu Cajón" solo en Android | En iPhone hace falta una extensión aparte (Share Extension) |

Ya funcionan de verdad: la llave del cajón (huella, rostro, PIN o patrón del celular, con `local_auth`), que se vuelve a pedir cada vez que se sale de la app (`core/seguridad/cerrojo.dart`), los avisos de vencimiento (notificaciones del celular 30 días antes, 7 días antes y el mismo día a las 9 a. m., y "Recordarme el lunes"; se programan en el celular sin internet, sobreviven a un reinicio y al tocarlos abren el documento después de la llave: `core/avisos/` y `features/avisos/avisos_programados.dart`, con `flutter_local_notifications`), editar un documento guardado (sus datos en Guardar, o sus páginas con las herramientas de siempre en `features/paginas/`, guardando en el mismo lugar sin volver a preguntar), reemplazar las páginas de un documento, la cámara (con
formatos de marco, páginas ilimitadas, revisar/recortar/eliminar cada foto y filtros de escáner, en
`features/escanear/`), subir un PDF (se guarda tal cual, cifrado; sus páginas se dibujan con el lector nativo de Android sin dejar copias, `core/pdf/`) o fotos de la galería con las mismas herramientas de la cámara (`features/paginas/`), recibir un PDF o fotos desde otras apps con "Compartir → Tu Cajón" (`ArchivosRecibidos.kt` los lee directo a la memoria, sin copias; se ven solo después de la llave; `core/archivos/recepcion.dart` y `features/recibir/`), enviar por WhatsApp o compartir como PDF (`core/compartir/`, el PDF temporal se borra solo), guardar documentos, eliminar, crear perfiles, buscar,
descartar sugerencias, y recordar el nombre y la llave entre sesiones.

---

## La "IA" dentro de la app

Hoy **Tu Cajón no usa ningún modelo de inteligencia artificial** y no envía datos a servicios de
IA: todo funciona dentro del celular. Algunas partes llevan la etiqueta "IA" en la interfaz
porque así quedaron en el diseño, pero por dentro son reglas o están simuladas:

| En la app | Cómo funciona de verdad |
|---|---|
| "Sugerencia de la IA" (Mi cajón y Avisos) | Reglas fijas sobre fechas y tipos de documento (`features/avisos/sugerencias.dart`) |
| "Pregúntale a tu cajón" | Búsqueda en la base de datos + respuestas por reglas (`features/preguntar/respuestas_demo.dart`) |
| "La IA llenó los datos" al guardar | Simulado: siempre propone los mismos datos |
| Filtros de escáner (Documento, B/N) | Procesamiento de imagen clásico: iluminación pareja, contraste y nitidez, con el paquete `image` (`features/escanear/filtros.dart`) |
| Recorte al marco de la cámara | Geometría y el paquete `image` (`features/escanear/recorte.dart`) |

Si más adelante se agrega IA de verdad (por ejemplo, leer el texto de los documentos o
responder preguntas), hay que anotarlo aquí: qué modelo, si corre en el celular o en internet,
y qué datos usa.

---

## Notas

- **Ícono:** el diseño original está en `assets/icono/icono.png`. Si se cambia, se corre
  `dart run tool/generar_iconos.dart` y se rehacen todos los tamaños: Android (adaptable
  para cualquier forma, redondo y temático de un color), iPhone, web y
  `assets/icono/play_store_512.png` para la Play Store.
- **Letras:** Plus Jakarta Sans va dentro de la app (`assets/fonts/`, pesos 400 a 800,
  licencia libre en `assets/fonts/OFL.txt`). No se descarga nada de internet.
- **Letra grande:** los botones y las filas crecen si la persona usa letra grande en su
  celular, en vez de cortar el texto.
- **Formato del código:** `dart format lib test` (ancho de línea 110, configurado en
  `analysis_options.yaml`).
