import 'package:flutter/material.dart';

InputDecoration getCustomDropdownDecoration({
  required BuildContext context, // AÑADIR ESTE PARÁMETRO
  String labelText = '',
  String? hintText,
  Icon? prefixIcon,
  // Puedes añadir más parámetros para personalizar el estilo si es necesario
  // ej: Color? fillColor, TextStyle? labelStyle, etc.
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0), // Bordes redondeados
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0), // USAR EL CONTEXTO AQUÍ
    ),
    filled: true,
    fillColor: Colors.white, // Color de fondo
    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0), // Padding interno
    labelStyle: TextStyle(color: Colors.grey.shade700),
    hintStyle: TextStyle(color: Colors.grey.shade500),
    // Aquí puedes añadir más propiedades de InputDecoration que desees estandarizar
    // por ejemplo, errorStyle, focusedErrorBorder, etc.
  );
}

// Puedes crear otras funciones para diferentes estilos de InputDecoration si lo necesitas
// InputDecoration getCustomTextFieldDecoration(...) { ... }

// ELIMINAR O COMENTAR ESTA CLAVE GLOBAL SI NO LA USAS EN OTRO LADO DE ESTE ARCHIVO
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();