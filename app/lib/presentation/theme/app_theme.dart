import 'package:flutter/material.dart';

/// 温柔治愈系视觉：低饱和暖粉 + 大留白 + 圆润卡片。
///
/// 注意：主色刻意不使用高饱和粉，以保证强光下的文字对比度，
/// 并避免与「流量分级配色」争夺视觉通道（流量改用图标数量编码）。
class AppColors {
  static const seed = Color(0xFFE8A0B4);
  static const backgroundLight = Color(0xFFFFF8F9);
  static const surfaceLight = Color(0xFFFFFFFF);

  /// 实际经期（已记录）。
  static const period = Color(0xFFD4678A);

  /// 预测经期。
  static const predicted = Color(0xFFF0A9C0);

  /// 排卵期 / 易孕窗口（低饱和，弱于经期色）。
  static const fertile = Color(0xFFB8A5D6);

  /// 异常关注提示（琥珀，不使用红色告警）。
  static const attention = Color(0xFFE0A24A);
}

class AppTheme {
  static const double cardRadius = 16;
  static const double sheetRadius = 24;

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.seed,
      brightness: brightness,
      surface: brightness == Brightness.light ? AppColors.surfaceLight : null,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          brightness == Brightness.light ? AppColors.backgroundLight : null,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      // —— 弹窗 / 提示 / 路由：统一圆角与顺滑过渡 ——
      dialogTheme: DialogThemeData(
        backgroundColor: brightness == Brightness.light
            ? AppColors.surfaceLight
            : scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor:
            brightness == Brightness.light ? const Color(0xFF3A3035) : scheme.inverseSurface,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: brightness == Brightness.light
            ? AppColors.surfaceLight
            : scheme.surfaceContainerHigh,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(sheetRadius),
          ),
        ),
        showDragHandle: true,
        dragHandleColor: scheme.outlineVariant,
      ),
      datePickerTheme: DatePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          // fadeUpwards 温和的淡入上滑，比 M3 默认缩放过渡更柔和。
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
      splashFactory: InkSparkle.splashFactory,
    );
  }
}
