import 'package:flutter/material.dart';

/// 🏛️ Sistema de Diseño Institucional y Moderno para Alerta PNP Desaparecidos
class AppColors {
  // 🔹 Identidad Principal PNP (Midnight Navy y Acero Táctico)
  static const Color primaryColor = Color(0xFF0F2027); // Deep Midnight Navy
  static const Color primaryColorLight = Color(0xFF1E3E62); // Slate Police Navy
  static const Color primaryDark = Color(0xFF081014); // Ultra Deep Navy
  
  // 🌟 Distintivo Dorado Policial (Institucional & Alertas de Atención)
  static const Color accentColor = Color(0xFFFFB300); // Gold Amber PNP
  static const Color goldLight = Color(0xFFFFFBEB);
  static const Color goldDark = Color(0xFFB45309);

  // 🚨 Estados de Alerta y Emergencia
  static const Color errorColor = Color(0xFFE11D48); // Emergency Crimson
  static const Color emergencyLight = Color(0xFFFFF1F2);
  static const Color successColor = Color(0xFF10B981); // Emerald Verde Encontrado
  static const Color successLight = Color(0xFFECFDF5);
  static const Color warningColor = Color(0xFFF59E0B); // Amber Alerta
  static const Color infoColor = Color(0xFF0284C7); // Sky Blue Institucional

  // 📄 Tipografía y Contrastes (Escala Slate WCAG AAA)
  static const Color textColorPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textColorSecondary = Color(0xFF475569); // Slate 600
  static const Color textColorMuted = Color(0xFF94A3B8); // Slate 400
  static const Color textColorInverse = Color(0xFFFFFFFF);
  static const Color buttonTextColor = Color(0xFFFFFFFF);

  // 🎨 Superficies y Fondos
  static const Color backgroundColor = Color(0xFFF8FAFC); // Clean Canvas
  static const Color surfaceWhite = Color(0xFFFFFFFF);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF0F2027);
  static const Color surfaceGlass = Color(0xE6FFFFFF);
  static const Color surfaceGlassDark = Color(0xCC0F2027);

  // 🔲 Bordes y Separadores Sutiles
  static const Color borderSubtle = Color(0xFFE2E8F0); // Slate 200
  static const Color borderMedium = Color(0xFFCBD5E1); // Slate 300
  static const Color borderFocus = Color(0xFF1E3E62);

  // 🌈 Gradientes de Élite
  static const LinearGradient policeHeroGradient = LinearGradient(
    colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient emergencyCardGradient = LinearGradient(
    colors: [Color(0xFFBE123C), Color(0xFFE11D48)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient goldBadgeGradient = LinearGradient(
    colors: [Color(0xFFFFB300), Color(0xFFF59E0B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient surfaceCardGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFC)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}
