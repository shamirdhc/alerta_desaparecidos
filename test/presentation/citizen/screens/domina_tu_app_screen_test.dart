import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:alerta_desaparecidos/presentation/citizen/screens/domina_tu_app_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('DominaTuAppScreen Visual & Flow Tests', () {
    testWidgets('renders DominaTuAppScreen with friendly colors and all essential sections', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: DominaTuAppScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verificar Título Principal y Hero
      expect(find.text('Domina tu Aplicación'), findsOneWidget);
      expect(find.text('GUÍA CIUDADANA'), findsOneWidget);
      expect(find.text('ELIGE LA HERRAMIENTA QUE QUIERES CONOCER:'), findsOneWidget);

      // Verificar los 3 pilares
      expect(find.text('Desaparecidos'), findsOneWidget);
      expect(find.text('Comisarías'), findsOneWidget);
      expect(find.text('Mi Familia'), findsOneWidget);

      // Verificar tarjeta de propósito humano
      expect(find.text('PROPÓSITO HUMANO Y FAMILIAR'), findsOneWidget);

      // Verificar Mockup de Smartphone
      expect(find.text('TUTORIAL PASO A PASO'), findsOneWidget);
      expect(find.text('Paso 1 de 3'), findsOneWidget);

      // Botón de acción directa
      expect(find.text('Ir a Personas Desaparecidas'), findsOneWidget);
    });

    testWidgets('switches to Comisarías pillar and updates theme colors and content', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: DominaTuAppScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Tap en Comisarías
      await tester.tap(find.text('Comisarías'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll para ver el botón de acción
      await tester.ensureVisible(find.text('Abrir Central 360° y Comisarías'));
      expect(find.text('Abrir Central 360° y Comisarías'), findsOneWidget);

      // Tap en Mi Familia
      await tester.ensureVisible(find.text('Mi Familia'));
      await tester.tap(find.text('Mi Familia'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Scroll para ver el botón de acción de Mi Familia
      await tester.ensureVisible(find.text('Crear Carnet en Mi Familia Segura'));
      expect(find.text('Crear Carnet en Mi Familia Segura'), findsOneWidget);
    });

    testWidgets('navigates steps forward and backward smoothly', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 1000));

      await tester.pumpWidget(
        const MaterialApp(
          home: DominaTuAppScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verificar primer paso
      expect(find.text('Paso 1 de 3'), findsOneWidget);

      // Scroll hacia el botón de siguiente paso
      await tester.ensureVisible(find.text('Siguiente Paso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap Siguiente Paso
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Ahora estamos en Paso 2
      expect(find.text('Paso 2 de 3'), findsOneWidget);
      expect(find.text('Anterior'), findsOneWidget);

      // Tap Siguiente Paso hacia Paso 3
      await tester.tap(find.text('Siguiente Paso'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Paso 3 de 3'), findsOneWidget);
      expect(find.text('¡Completar y Ganar +150 XP!'), findsOneWidget);

      // Tap Anterior para regresar
      await tester.tap(find.text('Anterior'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Paso 2 de 3'), findsOneWidget);
    });
  });
}
