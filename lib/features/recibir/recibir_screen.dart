import 'package:flutter/material.dart';

import '../../core/archivos/buzon.dart';
import '../../core/archivos/selector_archivos.dart';
import '../../core/icons/app_icons.dart';
import '../../core/router/app_routes.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../shared/illustrations/cajon_mini.dart';
import '../../shared/widgets/buttons.dart';
import '../../shared/widgets/common.dart';
import '../agregar/preparar_pdf.dart';
import '../paginas/paginas_screen.dart';

/// Lo que llega por "Compartir → Tu Cajón" desde WhatsApp, Gmail, Drive o la
/// galería:
///
/// - un PDF → se revisa y va directo a Guardar, donde se elige el nombre, de
///   quién es y qué tipo de documento es;
/// - una o varias fotos → Tus páginas, con las mismas herramientas de la
///   cámara (recortar, mejorar, quitar, ordenar), y de ahí a Guardar.
///
/// Mientras se lee, el cajón del dibujo se abre; si algo no sirve, lo dice.
class RecibirScreen extends StatefulWidget {
  const RecibirScreen({super.key, required this.envio});

  /// Lo que llegó (todavía se está leyendo).
  final Future<Envio> envio;

  @override
  State<RecibirScreen> createState() => _RecibirScreenState();
}

class _RecibirScreenState extends State<RecibirScreen> {
  /// Por qué no se pudo recibir; `null` mientras se lee.
  String? _problema;

  @override
  void initState() {
    super.initState();
    _recibir();
  }

  Future<void> _recibir() async {
    final Envio envio;
    try {
      envio = await widget.envio;
    } catch (e) {
      debugPrint('No se pudo leer lo compartido: $e');
      return _fallar('No pudimos leer lo que compartiste. Vuelve a intentarlo.');
    }
    final pdf = envio.archivos.where((a) => a.esPdf).firstOrNull;
    final fotos = envio.archivos.where((a) => a.esFoto).toList();
    if (pdf != null) return _recibirPdf(pdf);
    if (fotos.isNotEmpty) {
      return _recibirFotos(fotos, total: envio.archivos.length, sobrantes: envio.sobrantes);
    }
    _fallar(
      envio.archivos.isEmpty
          ? 'No llegó ningún archivo. Vuelve a compartirlo.'
          : 'Tu Cajón recibe documentos en PDF y fotos, y este archivo no es ninguno de los dos.',
    );
  }

  Future<void> _recibirPdf(ArchivoRecibido pdf) async {
    final bytes = pdf.bytes;
    if (bytes == null) {
      return _fallar(
        pdf.problema == ProblemaRecibido.muyGrande
            ? 'Ese PDF pesa más de 50 MB. Tu Cajón recibe PDF más livianos.'
            : 'No pudimos leer el PDF. Vuelve a compartirlo.',
      );
    }
    final nombre = pdf.nombre.trim().isEmpty ? 'Documento.pdf' : pdf.nombre;
    try {
      final listo = await prepararPdf(PdfElegido(nombre: nombre, bytes: bytes), recibido: true);
      _seguir(AppRoutes.guardar, listo);
    } on PdfRechazado catch (e) {
      _fallar(e.mensaje);
    }
  }

  void _recibirFotos(List<ArchivoRecibido> fotos, {required int total, required int sobrantes}) {
    final buenas = [for (final f in fotos) ?f.bytes];
    if (buenas.isEmpty) {
      return _fallar(
        fotos.every((f) => f.problema == ProblemaRecibido.muyGrande)
            ? 'Esas fotos pesan demasiado (más de 30 MB cada una).'
            : 'No pudimos leer las fotos. Vuelve a compartirlas.',
      );
    }
    final perdidas = fotos.length - buenas.length;
    final avisos = [
      if (perdidas == 1)
        'Una foto no se pudo recibir.'
      else if (perdidas > 1)
        '$perdidas fotos no se pudieron recibir.',
      if (sobrantes > 0) 'Llegaron solo las primeras $total; comparte las demás aparte.',
    ];
    _seguir(
      AppRoutes.paginas,
      EntradaPaginas(nuevas: buenas, aviso: avisos.isEmpty ? null : avisos.join(' ')),
    );
  }

  /// Cambia esta pantalla por la siguiente. Si la persona salió mientras se
  /// leía, el cambio pasa debajo de la pantalla de la llave, que sigue encima.
  void _seguir(String ruta, Object argumentos) {
    if (!mounted) return;
    final nav = Navigator.of(context);
    final esta = ModalRoute.of(context)!;
    final siguiente = AppRoutes.onGenerateRoute(RouteSettings(name: ruta, arguments: argumentos));
    if (esta.isCurrent) {
      nav.pushReplacement(siguiente);
    } else {
      nav.replace(oldRoute: esta, newRoute: siguiente);
    }
  }

  void _fallar(String mensaje) {
    if (mounted) setState(() => _problema = mensaje);
  }

  @override
  Widget build(BuildContext context) {
    final problema = _problema;
    return Scaffold(
      backgroundColor: AppColors.fondo,
      body: SafeArea(
        child: FillScroll(
          padding: const EdgeInsets.fromLTRB(32, 64, 32, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: CajonMini(width: 104, abierto: problema == null)),
              const SizedBox(height: 32),
              Semantics(
                liveRegion: true,
                child: Text(
                  problema == null ? 'Recibiendo tu documento…' : 'No se pudo recibir',
                  textAlign: TextAlign.center,
                  style: AppText.display(28, height: 1.2),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                problema ?? 'Un momento: lo estamos preparando para guardarlo en tu cajón.',
                textAlign: TextAlign.center,
                style: AppText.secondary(17, height: 1.45),
              ),
              const SizedBox(height: 32),
              if (problema == null)
                const Center(
                  child: SizedBox.square(
                    dimension: 32,
                    child: CircularProgressIndicator(strokeWidth: 3, color: AppColors.primario),
                  ),
                ),
              const Spacer(),
              const SizedBox(height: 24),
              if (problema != null) ...[
                PrimaryButton(
                  label: 'Volver',
                  icon: AppIcons.atras,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const SizedBox(height: 16),
              ],
              const PrivacyNote('Lo que recibes se guarda cifrado, solo en este celular'),
            ],
          ),
        ),
      ),
    );
  }
}
