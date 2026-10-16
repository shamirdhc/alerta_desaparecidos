import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:alerta_desaparecidos/services/mi_familia_service.dart';
import 'package:alerta_desaparecidos/services/mi_familia_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('MiFamiliaPdfService generates Afiche and Carnet without errors', () async {
    final familiar = FamiliarProfile(
      id: '123',
      nombreCompleto: 'Pedrito Pérez Quispe',
      parentesco: 'Hijo/a',
      edad: 10,
      dni: '73849201',
      telefonoContacto: '948269740',
      tipoSangre: 'O+',
      condicionEspecial: 'Autismo / TEA',
      estatura: '1.30 m',
      contextura: 'Delgada',
      colorPiel: 'Trigueña',
      colorCabello: 'Negro',
      senasParticulares: 'Lunar en la mejilla',
      datosMedicos: 'Alérgico a la penicilina',
      ropaDelDia: 'Buzo escolar azul',
    );

    print('Testing construirAficheBytes...');
    final aficheBytes = await MiFamiliaPdfService.construirAficheBytes(familiar, ultimaUbicacion: 'Lima, Perú');
    expect(aficheBytes.isNotEmpty, true);
    print('Afiche generated successfully: ${aficheBytes.length} bytes');

    print('Testing construirCarnetBytes...');
    final carnetBytes = await MiFamiliaPdfService.construirCarnetBytes(familiar);
    expect(carnetBytes.isNotEmpty, true);
    print('Carnet generated successfully: ${carnetBytes.length} bytes');
  });

  test('MiFamiliaPdfService handles familiar with photoBase64 without crash', () async {
    // 1x1 transparent png
    const dummyBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    final familiar = FamiliarProfile(
      id: '124',
      nombreCompleto: 'Abuelita María',
      parentesco: 'Abuelo/a',
      edad: 78,
      fotoBase64: dummyBase64,
      telefonoContacto: '987654321',
    );

    final aficheBytes = await MiFamiliaPdfService.construirAficheBytes(familiar);
    expect(aficheBytes.isNotEmpty, true);

    final carnetBytes = await MiFamiliaPdfService.construirCarnetBytes(familiar);
    expect(carnetBytes.isNotEmpty, true);
  });

  test('MiFamiliaPdfService generates Carnet SOS for Infantil, Juvenil, and Adulto', () async {
    const dummyBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

    // 1. Niño (0-11 años)
    final nino = FamiliarProfile(
      id: 'nino_1',
      nombreCompleto: 'Carlitos Rojas',
      parentesco: 'Hijo',
      edad: 8,
      fotoBase64: dummyBase64,
      telefonoContacto: '948269740',
      tipoSangre: 'O+',
    );
    final themeNino = CarnetThemeConfig.desdeFamiliar(nino);
    expect(themeNino.tipo, CarnetTipoEstilo.infantilNino);
    final carnetNinoBytes = await MiFamiliaPdfService.construirCarnetBytes(nino, orientacion: CarnetOrientacion.vertical);
    expect(carnetNinoBytes.isNotEmpty, true);
    File('test_carnet_boy.pdf').writeAsBytesSync(carnetNinoBytes);

    // 1b. Niña (0-11 años)
    final nina = FamiliarProfile(
      id: 'nina_1',
      nombreCompleto: 'Belky Hurtado C.',
      parentesco: 'Hija',
      edad: 4,
      dni: '10221517',
      fotoBase64: dummyBase64,
      telefonoContacto: '958177177',
      tipoSangre: 'O+',
    );
    final themeNina = CarnetThemeConfig.desdeFamiliar(nina);
    expect(themeNina.tipo, CarnetTipoEstilo.infantilNina);
    final carnetNinaBytes = await MiFamiliaPdfService.construirCarnetBytes(nina, orientacion: CarnetOrientacion.vertical);
    expect(carnetNinaBytes.isNotEmpty, true);
    File('test_carnet_girl.pdf').writeAsBytesSync(carnetNinaBytes);

    // 2. Adolescente / Joven (12-17 años)
    final joven = FamiliarProfile(
      id: 'joven_1',
      nombreCompleto: 'Mateo Quispe (15 años)',
      parentesco: 'Hijo/a',
      edad: 15,
      fotoBase64: dummyBase64,
      telefonoContacto: '948269740',
    );
    final themeJoven = CarnetThemeConfig.desdeFamiliar(joven);
    expect(themeJoven.tipo, CarnetTipoEstilo.juvenil);
    final carnetJovenBytes = await MiFamiliaPdfService.construirCarnetBytes(joven);
    expect(carnetJovenBytes.isNotEmpty, true);

    // 3. Adulto / Senior (18+ años)
    final adulto = FamiliarProfile(
      id: 'adulto_1',
      nombreCompleto: 'Don Alberto Mendoza (68 años)',
      parentesco: 'Abuelo/a',
      edad: 68,
      fotoBase64: dummyBase64,
      telefonoContacto: '948269740',
      tipoSangre: 'O+',
      datosMedicos: 'Hipertensión e insulina',
    );
    final themeAdulto = CarnetThemeConfig.desdeFamiliar(adulto);
    expect(themeAdulto.tipo, CarnetTipoEstilo.adulto);
    final carnetAdultoBytes = await MiFamiliaPdfService.construirCarnetBytes(adulto);
    expect(carnetAdultoBytes.isNotEmpty, true);
  });

  test('MiFamiliaPdfService supports horizontal, vertical and dual orientations for printing', () async {
    const dummyBase64 = 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';
    final familiar = FamiliarProfile(
      id: 'or_1',
      nombreCompleto: 'Lucas Quispe',
      parentesco: 'Hijo/a',
      edad: 9,
      fotoBase64: dummyBase64,
      telefonoContacto: '948269740',
      tipoSangre: 'O+',
    );

    // 1. Horizontal (Billetera)
    final hBytes = await MiFamiliaPdfService.construirCarnetBytes(familiar, orientacion: CarnetOrientacion.horizontal);
    expect(hBytes.isNotEmpty, true);

    // 2. Vertical (Lanyard de Cuello)
    final vBytes = await MiFamiliaPdfService.construirCarnetBytes(familiar, orientacion: CarnetOrientacion.vertical);
    expect(vBytes.isNotEmpty, true);

    // 3. Hoja Dual A4 (Ambas)
    final dualBytes = await MiFamiliaPdfService.construirCarnetBytes(familiar, orientacion: CarnetOrientacion.ambas);
    expect(dualBytes.isNotEmpty, true);
  });
}
