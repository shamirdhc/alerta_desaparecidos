import 'package:flutter/material.dart';

/// Un `IndexedStack` de alto rendimiento con carga perezosa (Lazy Loading) y
/// congelamiento automático de VSync / Tickers en pestañas invisibles.
///
/// Beneficios clave de rendimiento:
/// 1. **Cero sobrecarga inicial**: Las pantallas NO se construyen ni inicializan
///    hasta que el usuario navega a ellas por primera vez.
/// 2. **Preservación total de estado**: Una vez que una pantalla se visita, se
///    mantiene en memoria sin perder formularios, scroll ni estado interno.
/// 3. **Pausa inteligente de animaciones (0% CPU)**: Envolvemos cada pestaña en
///    un `TickerMode(enabled: isCurrent)`. Cuando la pestaña está oculta, todos
///    sus `AnimationController`, bucles `.repeat()` y timers de dibujo se pausan
///    automáticamente, evitando drenaje de batería y recalentamiento.
/// 4. **Aislamiento de renderizado (`RepaintBoundary`)**: Cada pantalla cargada
///    se aísla en su propia capa gráfica para que los repintados no se propaguen.
class LazyIndexedStack extends StatefulWidget {
  final int index;
  final List<WidgetBuilder> builders;
  final AlignmentGeometry alignment;
  final StackFit sizing;
  final TextDirection? textDirection;

  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
    this.textDirection,
  });

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  late final List<Widget?> _initializedWidgets;

  @override
  void initState() {
    super.initState();
    _initializedWidgets = List<Widget?>.filled(widget.builders.length, null);
    _activateIndex(widget.index);
  }

  @override
  void didUpdateWidget(covariant LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.builders.length != _initializedWidgets.length) {
      final oldWidgets = List<Widget?>.from(_initializedWidgets);
      _initializedWidgets.length = widget.builders.length;
      for (int i = 0; i < widget.builders.length; i++) {
        _initializedWidgets[i] = i < oldWidgets.length ? oldWidgets[i] : null;
      }
    }
    _activateIndex(widget.index);
  }

  void _activateIndex(int index) {
    if (index >= 0 && index < widget.builders.length) {
      if (_initializedWidgets[index] == null) {
        _initializedWidgets[index] = widget.builders[index](context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    _activateIndex(widget.index);

    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      sizing: widget.sizing,
      textDirection: widget.textDirection,
      children: List.generate(widget.builders.length, (i) {
        final isCurrent = i == widget.index;
        final child = _initializedWidgets[i];

        if (child == null) {
          // Aún no visitado: ocupador liviano sin coste de memoria ni CPU
          return const SizedBox.shrink();
        }

        // Si ya fue visitado: aislamos su repintado y pausamos sus tickers si no está visible
        return RepaintBoundary(
          child: TickerMode(
            enabled: isCurrent,
            child: child,
          ),
        );
      }),
    );
  }
}
