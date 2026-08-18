import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary palette (Navy / Dark Blue for headers & core elements)
  static const Color primary = Color(0xFF0F2C59);
  static const Color primaryDark = Color(0xFF0A1F3F);
  static const Color primaryLight = Color(0xFF1E4E8C);

  // Actions (Bright Blue for buttons and interactive items)
  static const Color accent = Color(0xFF1A73E8);

  // Background and Surfaces (Modern light aesthetic)
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFEBF3FE);

  // Text Colors
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF9CA3AF);

  // Borders & Dividers
  static const Color border = Color(0xFFE5E7EB);
  static const Color divider = Color(0xFFF3F4F6);

  // Semantic Status Colors (Badges and dynamic states)
  // Surtido (Green)
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);

  // Parcialmente surtido (Orange)
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);

  // Pendiente / Informativo (Soft Blue)
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // Error / Cancelado (Red)
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
}
