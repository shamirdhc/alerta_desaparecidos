import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alerta_desaparecidos/domain/entities/desaparecido.dart';
import 'package:alerta_desaparecidos/domain/entities/policia.dart';
import 'package:alerta_desaparecidos/common/styles/app_theme.dart';
import 'package:alerta_desaparecidos/common/styles/app_colors.dart';
import 'package:alerta_desaparecidos/presentation/common_widgets/comment_bubble.dart';

void main() {
  group('Desaparecido Entity Tests', () {
    test('creates Desaparecido with required fields and defaults', () {
      final desaparecido = Desaparecido(
        id: 'test-123',
        nombres: 'Juan',
        apellidos: 'Perez',
        sexo: 'M',
        departamento: 'LIMA',
      );

      expect(desaparecido.id, equals('test-123'));
      expect(desaparecido.nombres, equals('Juan'));
      expect(desaparecido.apellidos, equals('Perez'));
      expect(desaparecido.estado, equals('activo'));
      expect(desaparecido.departamento, equals('LIMA'));
    });

    test('copyWith properly updates fields', () {
      final desaparecido = Desaparecido(
        id: 'test-123',
        nombres: 'Juan',
        apellidos: 'Perez',
        estado: 'activo',
      );

      final updated = desaparecido.copyWith(
        estado: 'encontrado',
        encontradoDetalles: 'Localizado sano y salvo',
      );

      expect(updated.id, equals('test-123'));
      expect(updated.estado, equals('encontrado'));
      expect(updated.encontradoDetalles, equals('Localizado sano y salvo'));
      expect(updated.nombres, equals('Juan'));
    });

    test('supports DEPITPTIM and jurisdictional units fields', () {
      final now = DateTime.now();
      final desaparecido = Desaparecido(
        id: 'caso-andahuaylas-01',
        nombres: 'María',
        apellidos: 'Huamán',
        departamento: 'APURÍMAC',
        provincia: 'ANDAHUAYLAS',
        distrito: 'TALAVERA',
        unidadACargo: 'DEPITPTIM ANDAHUAYLAS',
        depitptimNombre: 'DEPITPTIM ANDAHUAYLAS',
        unidadRegistradora: 'COMISARÍA TALAVERA',
        fechaReasignacionDepitptim: now,
      );

      expect(desaparecido.unidadACargo, equals('DEPITPTIM ANDAHUAYLAS'));
      expect(desaparecido.depitptimNombre, equals('DEPITPTIM ANDAHUAYLAS'));
      expect(desaparecido.unidadRegistradora, equals('COMISARÍA TALAVERA'));
      expect(desaparecido.fechaReasignacionDepitptim, equals(now));

      final updated = desaparecido.copyWith(
        unidadACargo: 'DEPITPTIM ABANCAY',
        depitptimNombre: 'DEPITPTIM ABANCAY',
      );
      expect(updated.unidadACargo, equals('DEPITPTIM ABANCAY'));
      expect(updated.depitptimNombre, equals('DEPITPTIM ABANCAY'));
    });
  });

  group('Policia Entity Tests', () {
    test('creates Policia with required attributes', () {
      final policia = Policia(
        uid: 'pol-1',
        nombre: 'Carlos',
        apellido: 'Ramirez',
        numeroCip: '12345678',
        rango: 'Capitán',
        unidad: 'Comisaría Central',
        telefono: '987654321',
        departamento: 'LIMA',
        admin: true,
        rol: 'policia',
        fechaRegistro: DateTime(2025, 1, 1),
      );

      expect(policia.uid, equals('pol-1'));
      expect(policia.nombreCompleto, equals('Carlos Ramirez'));
      expect(policia.numeroCip, equals('12345678'));
      expect(policia.admin, isTrue);
      expect(policia.departamento, equals('LIMA'));
    });

    test('validates DEPITPTIM hierarchy and unit management permissions', () {
      final depitptimOfficial = Policia(
        uid: 'pol-depitptim-01',
        nombre: 'Marco',
        apellido: 'Quispe',
        numeroCip: '87654321',
        rango: 'Mayor PNP',
        unidad: 'DEPITPTIM Andahuaylas',
        tipoUnidad: 'DEPITPTIM',
        departamento: 'APURÍMAC',
        telefono: '987654321',
        rol: 'policia',
        admin: true,
        fechaRegistro: DateTime(2025, 1, 1),
      );

      expect(depitptimOfficial.isDepitptim, isTrue);
      expect(depitptimOfficial.isComisaria, isFalse);
      expect(depitptimOfficial.canManageComisarias, isTrue);

      final comisariaOfficial = Policia(
        uid: 'pol-comisaria-01',
        nombre: 'Luis',
        apellido: 'Mendoza',
        numeroCip: '11223344',
        rango: 'Suboficial',
        unidad: 'Comisaría Sectorial Talavera',
        tipoUnidad: 'COMISARIA',
        depitptimPadreId: 'pol-depitptim-01',
        depitptimPadreNombre: 'DEPITPTIM Andahuaylas',
        departamento: 'APURÍMAC',
        telefono: '987654322',
        admin: false,
        rol: 'policia',
        fechaRegistro: DateTime(2025, 1, 1),
      );

      expect(comisariaOfficial.isComisaria, isTrue);
      expect(comisariaOfficial.isDepitptim, isFalse);
      expect(comisariaOfficial.canManageComisarias, isFalse);
      expect(comisariaOfficial.depitptimPadreNombre, equals('DEPITPTIM Andahuaylas'));
    });
  });

  group('Theme & UI Smoke Tests', () {
    test('AppTheme and AppColors define institutional PNP design system', () {
      expect(AppTheme.lightTheme, isNotNull);
      expect(AppTheme.darkTheme, isNotNull);
      expect(AppColors.primaryColor, equals(const Color(0xFF0F2027)));
      expect(AppColors.accentColor, equals(const Color(0xFFFFB300)));
      expect(AppColors.policeHeroGradient, isNotNull);
    });

    testWidgets('renders CommentBubble instantly with denormalized author and badge', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CommentBubble(
              text: 'Avistado en el terminal terrestre',
              timestamp: null,
              phoneNumber: '987654321',
              userId: 'user-test-01',
              isCurrentUser: false,
              userName: 'Rosa Quispe',
              estadoModeracion: 'aprobado',
            ),
          ),
        ),
      );

      expect(find.text('Rosa'), findsOneWidget);
      expect(find.text('Avistado en el terminal terrestre'), findsOneWidget);
      expect(find.text('Validado por IA PNP'), findsOneWidget);
    });

    testWidgets('renders basic branded widget with AppTheme', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(
            body: Center(
              child: Text(
                'Alerta Desaparecidos Perú',
                key: Key('app_title'),
              ),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('app_title')), findsOneWidget);
      expect(find.text('Alerta Desaparecidos Perú'), findsOneWidget);
    });
  });
}
