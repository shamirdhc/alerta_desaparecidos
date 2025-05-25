import 'package:flutter/material.dart';

InputDecoration getCustomDropdownDecoration({
  required BuildContext context,
  String labelText = '',
  String? hintText,
  Icon? prefixIcon,
  Color? customFillColor, // NUEVO PARÁMETRO OPCIONAL
}) {
  return InputDecoration(
    labelText: labelText,
    hintText: hintText,
    prefixIcon: prefixIcon,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Colors.grey.shade400),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12.0),
      borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2.0),
    ),
    filled: true,
    // Usar customFillColor si se proporciona, sino el color por defecto
    fillColor: customFillColor ?? Colors.white, // CAMBIO AQUÍ
    contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
    labelStyle: TextStyle(color: Colors.grey.shade700),
    hintStyle: TextStyle(color: Colors.grey.shade500),
  );
}

// Puedes crear otras funciones para diferentes estilos de InputDecoration si lo necesitas
// InputDecoration getCustomTextFieldDecoration(...) { ... }

// ELIMINAR O COMENTAR ESTA CLAVE GLOBAL SI NO LA USAS EN OTRO LADO DE ESTE ARCHIVO
// final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();