import 'package:flutter/material.dart';

/// Palet warna aplikasi.
///
/// Dark mode: latar paling gelap dipakai [bgBase], card sedikit lebih terang
/// ([bgCard]) supaya konten terbaca tanpa perlu garis batas tebal.
class AppColors {
  const AppColors._();

  // Biru utama sesuai brief.
  static const primary = Color(0xFF2563EB);
  static const primaryLight = Color(0xFF60A5FA);
  static const primaryDark = Color(0xFF1D4ED8);

  // Aksen ungu untuk gradient.
  static const accent = Color(0xFF7C3AED);
  static const accentLight = Color(0xFFA78BFA);

  // Latar bertingkat.
  static const bgBase = Color(0xFF0B1120);
  static const bgCard = Color(0xFF151D2E);
  static const bgCardAlt = Color(0xFF1C2639);
  static const divider = Color(0xFF253048);

  // Teks.
  static const textPrimary = Color(0xFFF1F5F9);
  static const textSecondary = Color(0xFF94A3B8);
  static const textMuted = Color(0xFF64748B);

  // Status: hijau untuk aktif, oranye untuk idle, merah untuk
  // offline/shutdown/revoke.
  static const active = Color(0xFF22C55E);
  static const activeSoft = Color(0x3322C55E);
  static const idle = Color(0xFFF59E0B);
  static const idleSoft = Color(0x33F59E0B);
  static const danger = Color(0xFFEF4444);
  static const dangerSoft = Color(0x33EF4444);
  static const info = Color(0xFF0EA5E9);
  static const infoSoft = Color(0x330EA5E9);

  /// Gradient biru-ungu untuk header dan aksen utama.
  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, accent],
  );

  /// Gradient yang lebih soft untuk card aksi.
  static const brandGradientSoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2563EB), Color(0xFF6D28D9)],
  );
}
