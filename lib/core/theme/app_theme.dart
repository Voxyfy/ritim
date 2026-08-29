import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_metrics.dart';
/// Uygulamanın [ThemeData] nesnesini kurar.
///
/// Tek yazı ailesi (Plus Jakarta Sans) kullanılıyor. Başlık ve metin için ayrı
/// aile denendi ama iki aile bu boyuttaki bir arayüzde hiyerarşi yerine
/// dağınıklık üretti; ağırlık farkı (400 - 800) tek başına yeterli ayrım
/// veriyor.
///
/// Sayılar her yerde tabular: haftalık özet ve istatistik satırlarında
/// rakamların genişliği değiştiğinde sütunlar oynuyordu.
abstract final class AppTheme {
  static const _family = 'Jakarta';

  /// Rakamların eşit genişlikte dizilmesi için ortak özellik listesi.
  static const _tabular = [FontFeature.tabularFigures()];

  static ThemeData light() {
    const scheme = ColorScheme.light(
      primary: AppColors.accent,
      onPrimary: AppColors.onAccent,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.surfaceMuted,
      outlineVariant: AppColors.border,
      error: AppColors.overdue,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _family,
      scaffoldBackgroundColor: AppColors.background,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        // fontFamily burada elle veriliyor. `ThemeData.fontFamily` yalnızca
        // `textTheme`e uygulanıyor; bileşen temalarındaki biçemler kapsam
        // dışında kalıyor ve başlık, uygulamadaki tek sistem yazı tipiyle
        // çizilen metin oluyordu.
        titleTextStyle: TextStyle(
          fontFamily: _family,
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      // Derinlik AppCard'ın kenar çizgisinden geliyor. Material'ın kendi
      // yükseklik gölgesi yüzeyi tonluyor ve bu sıcak zeminde beyaz kartları
      // griye çeviriyor.
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.md),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 34,
          height: 1.15,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.8,
          color: AppColors.textPrimary,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.2,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.6,
          color: AppColors.textPrimary,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: AppColors.textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          height: 1.4,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
        ),
        labelSmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
          color: AppColors.textTertiary,
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          fontFeatures: _tabular,
          color: AppColors.textPrimary,
        ),
      ),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.textPrimary,
        iconColor: AppColors.textSecondary,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accent,
          foregroundColor: AppColors.onAccent,
          minimumSize: const Size.fromHeight(54),
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: _family,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.md),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(Radii.lg),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: _family,
          color: AppColors.surface,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sm),
        ),
        // Yüzen sekme çubuğunun üstünde duruyor; varsayılan konumda çubuğun
        // altında kalıp yarısı görünmüyordu.
        insetPadding: const EdgeInsets.fromLTRB(
          Gap.page,
          Gap.page,
          Gap.page,
          Gap.floatingClearance,
        ),
      ),
    );
  }
}
