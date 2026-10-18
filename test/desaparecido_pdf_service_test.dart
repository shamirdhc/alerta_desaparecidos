import 'package:flutter_test/flutter_test.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/services/desaparecido_pdf_service.dart';
import 'package:alerta_desaparecidos/services/comisaria_matcher_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DesaparecidoPdfService Tests', () {
    final desaparecidoActivo = Desaparecido(
      id: 'nota_test_001',
      nombres: 'JUAN CARLOS',
      apellidos: 'QUISPE MAMANI',
      sexo: 'MASCULINO',
      fechaNacimiento: DateTime(2010, 5, 12),
      fechaDesaparicion: DateTime(2026, 10, 15, 14, 30),
      departamento: 'LIMA',
      provincia: 'LIMA',
      distrito: 'SAN JUAN DE LURIGANCHO',
      unidadACargo: 'COMISARIA SANTA ELIZABETH',
      detallesAdicionales: 'Estatura: 1.55m, Contextura: Delgada, Tez: Trigueña, Cabello: Negro corto, Ojos: Castaños, Nariz: Recta. Vestía pantalón jean azul, polera ploma con capucha y zapatillas blancas.',
      estado: 'desaparecido',
      portalUrl: 'https://desaparecidosenperu.policia.gob.pe/desaparecidos/nota_alerta_preview?id=nota_test_001',
    );

    final desaparecidoEncontrado = Desaparecido(
      id: 'nota_test_002',
      nombres: 'MARIA ELENA',
      apellidos: 'FLORES ROJAS',
      sexo: 'FEMENINO',
      fechaNacimiento: DateTime(1995, 8, 20),
      fechaDesaparicion: DateTime(2026, 10, 10),
      departamento: 'AREQUIPA',
      provincia: 'AREQUIPA',
      distrito: 'CERRO COLORADO',
      unidadACargo: 'COMISARIA CERRO COLORADO',
      detallesAdicionales: 'Estatura: 1.62m, Contextura: Mediana. Vestía casaca roja.',
      estado: 'encontrado',
      portalUrl: 'https://desaparecidosenperu.policia.gob.pe/desaparecidos/nota_alerta_preview?id=nota_test_002',
    );

    test('construirAficheBytes generates valid A4 PDF for active missing case', () async {
      final bytes = await DesaparecidoPdfService.construirAficheBytes(
        desaparecidoActivo,
        comisariaInfo: const ComisariaMatchResult(
          nombreOficial: 'COMISARIA PNP SANTA ELIZABETH',
          telefono: '(01) 388-1234',
          telefonoLimpio: '013881234',
          tieneTelefonoDirecto: true,
          direccion: 'Av. Canto Grande s/n, SJL',
          distrito: 'SAN JUAN DE LURIGANCHO',
          provincia: 'LIMA',
          departamento: 'LIMA',
          unidadPolicial: 'DIVPOL ESTE 1',
          tipoCoincidencia: 'DIRECTA',
        ),
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      // Valid PDF files start with %PDF
      expect(bytes[0], 0x25); // '%'
      expect(bytes[1], 0x50); // 'P'
      expect(bytes[2], 0x44); // 'D'
      expect(bytes[3], 0x46); // 'F'
    });

    test('construirAficheBytes generates valid A4 PDF with watermark for found person', () async {
      final bytes = await DesaparecidoPdfService.construirAficheBytes(
        desaparecidoEncontrado,
      );

      expect(bytes, isNotNull);
      expect(bytes.isNotEmpty, isTrue);
      expect(bytes[0], 0x25); // '%'
      expect(bytes[1], 0x50); // 'P'
      expect(bytes[2], 0x44); // 'D'
      expect(bytes[3], 0x46); // 'F'
    });

    test('Desaparecido entity exposes urlNotaAlertaOficial correctly', () {
      expect(desaparecidoActivo.urlNotaAlertaOficial, desaparecidoActivo.portalUrl);
      
      final sinPortal = Desaparecido(
        id: '123',
        nombres: 'Test',
        apellidos: 'Test',
        fotoUrl: 'https://storage.googleapis.com/test/photo.jpg',
      );
      expect(
        sinPortal.urlNotaAlertaOficial,
        'https://desaparecidosenperu.policia.gob.pe/Desaparecidos/nota_alerta_mujer?id=123',
      );
    });
  });
}
