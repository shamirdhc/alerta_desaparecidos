import 'package:flutter_test/flutter_test.dart';
import 'package:alerta_desaparecidos/services/comisaria_matcher_service.dart';
import 'package:alerta_desaparecidos/services/desaparecido_pdf_service.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ComisariaMatcherService Tests', () {
    test('Normalización de nombres de comisaría', () {
      expect(
        ComisariaMatcherService.normalizar('COMISARÍA PNP HUAYCÁN (SEC. ATE)'),
        contains('HUAYCAN'),
      );
    });

    test('Limpieza de números de teléfono', () {
      expect(
        ComisariaMatcherService.limpiarTelefono(' (01) 371-5085 / 987654321 '),
        equals('013715085'),
      );
    });

    test('Resolución con fallback ante unidad nula', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: null,
        departamento: 'LIMA',
      );
      expect(match?.nombreOficial, isNotEmpty);
      expect(match?.telefono, isNotEmpty);
    });

    test('Caso Santa María de Chicmo debe resolver COMISARÍA DE S.M. DE CHICMO y NO Mara', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'COMISARÍA SANTA MARÍA DE CHICMO',
        departamento: 'APURÍMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'SANTA MARÍA DE CHICMO',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('CHICMO'));
      expect(match?.provincia, equals('ANDAHUAYLAS'));
      expect(match?.telefono.replaceAll(RegExp(r'\D'), ''), equals('943070460'));
      expect(match?.nombreOficial, isNot(contains('MARA')));
    });

    test('Caso Santa María de Chicmo solo con distrito y unidad genérica PNP', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'POLICÍA NACIONAL DEL PERÚ',
        departamento: 'APURÍMAC',
        distrito: 'SANTA MARÍA DE CHICMO',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('CHICMO'));
      expect(match?.telefono.replaceAll(RegExp(r'\D'), ''), equals('943070460'));
    });

    test('Caso usuario: REGPOL - APURIMAC - COMISARIA ANDAHUAYLAS "A" debe resolver COMISARÍA SECTORIAL DE ANDAHUAYLAS y NUNCA DEPINCRI ni FAMILIA', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'REGPOL - APURIMAC - COMISARIA ANDAHUAYLAS "A"',
        departamento: 'APURÍMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'ANDAHUAYLAS',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('ANDAHUAYLAS'));
      expect(match?.nombreOficial, isNot(contains('DEPINCRI')));
      expect(match?.telefono, isNotEmpty);
      expect(match?.tieneTelefonoDirecto, isTrue);
    });

    test('Caso Nasca con ortografía NAZCA debe resolver COMISARÍA PNP NASCA "A"', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'REGPOL - ICA - COMISARIA NAZCA "A"',
        departamento: 'ICA',
        provincia: 'NAZCA',
        distrito: 'NAZCA',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('NASCA'));
      expect(match?.departamento, equals('ICA'));
    });

    test('Caso Capachica (Puno) no debe confundirse con ICA y debe resolver Capachica', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'REGPOL - PUNO - COMISARIA CAPACHICA "E"',
        departamento: 'PUNO',
        provincia: 'PUNO',
        distrito: 'CAPACHICA',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('CAPACHICA'));
      expect(match?.departamento, equals('PUNO'));
    });

    test('Caso Jicamarca (Lima) debe resolver COMISARÍA PNP JICAMARCA', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'REGPOL - LIMA CENTRO - COMISARIA JICAMARCA "A"',
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'SAN JUAN DE LURIGANCHO',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('JICAMARCA'));
      expect(match?.departamento, equals('LIMA'));
    });

    test('Caso Yurimaguas (investigada por REGPOL San Martin pero ubicada en Loreto)', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'REGPOL - SAN MARTIN - COMISARIA YURIMAGUAS "A"',
        departamento: 'LORETO',
        provincia: 'ALTO AMAZONAS',
        distrito: 'YURIMAGUAS',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('YURIMAGUAS'));
    });

    test('Caso interdepartamental: Hecho en Pasco pero denuncia en COMISARÍA LINCE de Lima', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'REGPOL - LIMA CENTRO - COMISARIA LINCE "A"',
        departamento: 'PASCO',
        provincia: 'PASCO',
        distrito: 'SAN FRANCISCO DE ASIS DE YARUSYACAN',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, contains('LINCE'));
      expect(match?.departamento, equals('LIMA'));
    });

    test('Caso no territorial: DEPINCRI INDEPENDENCIA debe resolver la Comisaría Territorial de Independencia', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'DIRINCRI PNP - DEPINCRI INDEPENDENCIA',
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'INDEPENDENCIA',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, isNot(contains('DEPINCRI')));
      expect(match?.nombreOficial, contains('INDEPENDENCIA'));
    });

    test('Caso no territorial: COMISARIA DE FAMILIA debe resolver la Comisaría Territorial de la jurisdicción', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'DIRFAM PNP - COMISARIA DE FAMILIA PAUCARPATA',
        departamento: 'AREQUIPA',
        provincia: 'AREQUIPA',
        distrito: 'PAUCARPATA',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, isNot(contains('FAMILIA')));
      expect(match?.distrito, equals('PAUCARPATA'));
    });

    test('Caso usuario Anagabriela: DIRITPTIM PNP - DIVINTRAP - APURIMAC debe resolver Comisaría Territorial de Abancay y NUNCA DIVOPUS', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'DIRITPTIM PNP - DIVINTRAP - APURIMAC',
        departamento: 'APURIMAC',
        provincia: 'ABANCAY',
        distrito: 'ABANCAY',
        detallesAdicionales: 'Edad: 16 años. Dirección: URB VILLA LOS REYES SN. Denuncia PNP: 36239458. Unidad a cargo: DIRITPTIM PNP - DIVINTRAP - APURIMAC',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, isNot(contains('DIVOPUS')));
      expect(match?.nombreOficial, isNot(contains('DIVINTRAP')));
      expect(match?.nombreOficial, isNot(contains('DIRITPTIM')));
      expect(match?.nombreOficial, contains('ABANCAY'));
    });

    test('Caso DIVOPUS: si unidad viene como DIVOPUS PNP ABANCAY debe resolver Comisaría Territorial de Abancay', () async {
      final match = await ComisariaMatcherService.resolverComisaria(
        unidadACargo: 'DIVOPUS PNP ABANCAY',
        departamento: 'APURIMAC',
        provincia: 'ABANCAY',
        distrito: 'ABANCAY',
      );
      expect(match, isNotNull);
      expect(match?.nombreOficial, isNot(contains('DIVOPUS')));
      expect(match?.nombreOficial, contains('ABANCAY'));
    });

    test('Entidad Desaparecido.fromMap sanitiza DIVOPUS a Comisaría Territorial', () {
      final d = Desaparecido.fromMap({
        'nombre': 'ANAGABRIELA JARA HUILLCAHUA',
        'unidad_a_cargo': 'DIVOPUS PNP ABANCAY',
        'departamento': 'APURIMAC',
        'provincia': 'ABANCAY',
        'distrito': 'ABANCAY',
      }, 'test_id');
      expect(d.unidadACargo, isNot(contains('DIVOPUS')));
      expect(d.unidadACargo, contains('ABANCAY'));
    });
  });

  group('DesaparecidoPdfService Tests', () {
    test('Genera afiche de búsqueda A4 en bytes válidos', () async {
      final desaparecido = Desaparecido(
        id: 'TEST-123',
        nombres: 'JUAN',
        apellidos: 'PEREZ',
        sexo: 'M',
        fechaNacimiento: DateTime(1999, 5, 20),
        fechaDesaparicion: DateTime.now().subtract(const Duration(hours: 10)),
        departamento: 'LIMA',
        provincia: 'LIMA',
        distrito: 'ATE',
        unidadACargo: 'COMISARIA PNP HUAYCAN',
        telefonoContacto: '01 418-4030',
        detallesAdicionales: 'Vestía polera negra y pantalón jean azul.',
      );

      final bytes = await DesaparecidoPdfService.construirAficheBytes(desaparecido);
      expect(bytes, isNotEmpty);
      // Validar cabecera mágica de PDF (%PDF)
      expect(bytes.sublist(0, 4), equals([0x25, 0x50, 0x44, 0x46]));
    });
  });
}
