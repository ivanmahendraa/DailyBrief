import 'package:flutter/material.dart';

/// Palet warna dasar untuk aplikasi DailyBrief.
///
/// Dirancang dengan kontras tinggi dan latar belakang bersih untuk
/// mendukung kemudahan membaca serta aksesibilitas (PRD NFR-01).
class AppColors {
  AppColors._();

  // Background & Surface
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF4F7FD);

  // Primary Blue
  static const Color primary = Color(0xFF2453E6);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color primaryContainer = Color(0xFFE8EFFF);
  static const Color onPrimaryContainer = Color(0xFF0D256B);

  // Secondary Blue (Aksen & Elemen Pendukung)
  static const Color secondary = Color(0xFF8DBBFF);
  static const Color onSecondary = Color(0xFF0F172A);
  static const Color secondaryContainer = Color(0xFFEBF3FF);
  static const Color onSecondaryContainer = Color(0xFF143066);

  // Border & Divider
  static const Color border = Color(0xFFE2E8F5);
  static const Color divider = Color(0xFFEBF0FA);

  // Typography (Kontras Tinggi)
  static const Color textPrimary = Color(0xFF0F1A36);
  static const Color textSecondary = Color(0xFF415173);
  static const Color textTertiary = Color(0xFF7384A6);

  // Status & Feedback (Hanya untuk indikasi kondisi tertentu)
  static const Color error = Color(0xFFDC2626);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFEE2E2);
  static const Color onErrorContainer = Color(0xFF7F1D1D);

  static const Color success = Color(0xFF16A34A);
  static const Color onSuccess = Color(0xFFFFFFFF);
  static const Color successContainer = Color(0xFFDCFCE7);
  static const Color onSuccessContainer = Color(0xFF14532D);

  static const Color warning = Color(0xFFD97706);
  static const Color onWarning = Color(0xFFFFFFFF);
  static const Color warningContainer = Color(0xFFFEF3C7);
  static const Color onWarningContainer = Color(0xFF78350F);
}
