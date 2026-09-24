import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_cajon/data/models/categoria.dart';
import 'package:tu_cajon/data/models/documento.dart';
import 'package:tu_cajon/data/models/perfil.dart';
import 'package:tu_cajon/features/avisos/avisos_programados.dart';

void main() {
  final ahora = DateTime(2026, 10, 1, 10, 30);
  const yo = Perfil(id: Perfil.idPropio, nombre: 'Tú', inicial: 'M', color: Colors.blue, esPropio: true);
  const mama = Perfil(id: 'mama', nombre: 'Mamá', inicial: 'C', color: Colors.red);
  final perfiles = {yo.id: yo, mama.id: mama};

  Documento doc(String nombre, DateTime? vence, {String perfil = Perfil.idPropio}) => Documento(
    id: nombre,
    perfilId: perfil,
    nombre: nombre,
    categoria: Categoria.vehiculo,
    guardadoEn: DateTime(2026, 1, 1),
    paginas: 1,
    tamanoBytes: 1,
    venceEn: vence,
  );

  test('avisa 30 días antes, 7 días antes y el mismo día, a las 9 de la mañana', () {
    final avisos = calcularAvisos([doc('SOAT', DateTime(2026, 12, 1))], perfiles, ahora);
    expect(avisos.map((a) => a.cuando), [
      DateTime(2026, 11, 1, 9),
      DateTime(2026, 11, 24, 9),
      DateTime(2026, 12, 1, 9),
    ]);
    expect(avisos.map((a) => a.titulo), [
      '«SOAT» vence en 30 días',
      '«SOAT» vence en 7 días',
      '«SOAT» vence hoy',
    ]);
    expect(avisos.first.cuerpo, 'Vence el 1 de diciembre de 2026. Toca para verlo.');
    expect(avisos.every((a) => a.documentoId == 'SOAT'), isTrue);
  });

  test('no programa lo que ya pasó, lo vencido ni lo que no tiene fecha', () {
    final avisos = calcularAvisos(
      [
        doc('Pronto', DateTime(2026, 10, 10)), // faltan 9 días: ya no el de 30
        doc('Hoy', DateTime(2026, 10, 1)), // ya pasaron las 9
        doc('Vencido', DateTime(2026, 9, 1)),
        doc('Sin fecha', null),
      ],
      perfiles,
      ahora,
    );
    expect(avisos.map((a) => (a.documentoId, a.cuando)), [
      ('Pronto', DateTime(2026, 10, 3, 9)),
      ('Pronto', DateTime(2026, 10, 10, 9)),
    ]);
  });

  test('dice de quién es si no es tuyo, y ordena del más próximo al más lejano', () {
    final avisos = calcularAvisos(
      [doc('Pasaporte', DateTime(2027, 6, 1)), doc('Licencia', DateTime(2026, 11, 20), perfil: 'mama')],
      perfiles,
      ahora,
    );
    expect(avisos.first.titulo, '«Licencia» de Mamá vence en 30 días');
    expect(avisos.first.cuando, DateTime(2026, 10, 21, 9));
    final fechas = avisos.map((a) => a.cuando).toList();
    expect(fechas, [...fechas]..sort());
  });

  test('"Recordarme el lunes" llega ese lunes a las 9', () {
    final aviso = avisoDeRenovar(
      doc('Licencia', DateTime(2026, 10, 19)),
      perfiles,
      DateTime(2026, 10, 5, 15),
    );
    expect(aviso.cuando, DateTime(2026, 10, 5, 9));
    expect(aviso.cuando.weekday, DateTime.monday);
    expect(aviso.titulo, 'Recuerda renovar «Licencia»');
    expect(aviso.cuerpo, 'Vence el 19 de octubre de 2026. Toca para verlo.');
  });
}
