import 'package:flutter/material.dart';

@immutable
class AppSurfaceTheme extends ThemeExtension<AppSurfaceTheme> {
  const AppSurfaceTheme({
    required this.background,
    required this.backgroundRaised,
    required this.panel,
    required this.panelMuted,
    required this.panelStrong,
    required this.border,
    required this.borderStrong,
    required this.textMuted,
    required this.textSoft,
    required this.accent,
    required this.accentSoft,
    required this.success,
    required this.warning,
    required this.danger,
  });

  final Color background;
  final Color backgroundRaised;
  final Color panel;
  final Color panelMuted;
  final Color panelStrong;
  final Color border;
  final Color borderStrong;
  final Color textMuted;
  final Color textSoft;
  final Color accent;
  final Color accentSoft;
  final Color success;
  final Color warning;
  final Color danger;

  @override
  AppSurfaceTheme copyWith({
    Color? background,
    Color? backgroundRaised,
    Color? panel,
    Color? panelMuted,
    Color? panelStrong,
    Color? border,
    Color? borderStrong,
    Color? textMuted,
    Color? textSoft,
    Color? accent,
    Color? accentSoft,
    Color? success,
    Color? warning,
    Color? danger,
  }) {
    return AppSurfaceTheme(
      background: background ?? this.background,
      backgroundRaised: backgroundRaised ?? this.backgroundRaised,
      panel: panel ?? this.panel,
      panelMuted: panelMuted ?? this.panelMuted,
      panelStrong: panelStrong ?? this.panelStrong,
      border: border ?? this.border,
      borderStrong: borderStrong ?? this.borderStrong,
      textMuted: textMuted ?? this.textMuted,
      textSoft: textSoft ?? this.textSoft,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      success: success ?? this.success,
      warning: warning ?? this.warning,
      danger: danger ?? this.danger,
    );
  }

  @override
  AppSurfaceTheme lerp(ThemeExtension<AppSurfaceTheme>? other, double t) {
    if (other is! AppSurfaceTheme) {
      return this;
    }

    return AppSurfaceTheme(
      background: Color.lerp(background, other.background, t)!,
      backgroundRaised:
          Color.lerp(backgroundRaised, other.backgroundRaised, t)!,
      panel: Color.lerp(panel, other.panel, t)!,
      panelMuted: Color.lerp(panelMuted, other.panelMuted, t)!,
      panelStrong: Color.lerp(panelStrong, other.panelStrong, t)!,
      border: Color.lerp(border, other.border, t)!,
      borderStrong: Color.lerp(borderStrong, other.borderStrong, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      textSoft: Color.lerp(textSoft, other.textSoft, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

extension AppThemeContext on BuildContext {
  AppSurfaceTheme get surfaces => Theme.of(this).extension<AppSurfaceTheme>()!;
}

class AppTheme {
  static const _lightSurfaces = AppSurfaceTheme(
    background: Color(0xFFF1EFE9),
    backgroundRaised: Color(0xFFE7E3DB),
    panel: Color(0xFFFAF8F2),
    panelMuted: Color(0xFFF0ECE3),
    panelStrong: Color(0xFF212623),
    border: Color(0xFFD7D1C5),
    borderStrong: Color(0xFFB0A99C),
    textMuted: Color(0xFF5F645D),
    textSoft: Color(0xFF7A7F78),
    accent: Color(0xFF33574E),
    accentSoft: Color(0xFFD9E3DE),
    success: Color(0xFF35694E),
    warning: Color(0xFF8D6637),
    danger: Color(0xFF9A4B44),
  );

  static const _darkSurfaces = AppSurfaceTheme(
    background: Color(0xFF151916),
    backgroundRaised: Color(0xFF1B201C),
    panel: Color(0xFF1C211D),
    panelMuted: Color(0xFF232A25),
    panelStrong: Color(0xFFE7E2D7),
    border: Color(0xFF343A35),
    borderStrong: Color(0xFF4D544F),
    textMuted: Color(0xFFA6ADA5),
    textSoft: Color(0xFF818880),
    accent: Color(0xFF89A99D),
    accentSoft: Color(0xFF2A3832),
    success: Color(0xFF7DB897),
    warning: Color(0xFFD0A06A),
    danger: Color(0xFFD78A84),
  );

  static ThemeData light([ColorScheme? dynamicScheme]) {
    return _buildTheme(
      brightness: Brightness.light,
      surfaces: _lightSurfaces,
      secondary: const Color(0xFF6B6254),
      tertiary: const Color(0xFF4C6D83),
      onSurface: const Color(0xFF1A1E1B),
      dynamicScheme: dynamicScheme,
    );
  }

  static ThemeData dark([ColorScheme? dynamicScheme]) {
    return _buildTheme(
      brightness: Brightness.dark,
      surfaces: _darkSurfaces,
      secondary: const Color(0xFFC8BAA7),
      tertiary: const Color(0xFFA1BAC6),
      onSurface: const Color(0xFFE8E4DA),
      dynamicScheme: dynamicScheme,
    );
  }

  static ThemeData _buildTheme({
    required Brightness brightness,
    required AppSurfaceTheme surfaces,
    required Color secondary,
    required Color tertiary,
    required Color onSurface,
    ColorScheme? dynamicScheme,
  }) {
    final defaultScheme = ColorScheme.fromSeed(
      seedColor: surfaces.accent,
      brightness: brightness,
      primary: surfaces.accent,
      secondary: secondary,
      tertiary: tertiary,
      surface: surfaces.panel,
      error: surfaces.danger,
      onPrimary: brightness == Brightness.light
          ? const Color(0xFFF8F6F0)
          : const Color(0xFF101311),
      onSecondary: brightness == Brightness.light
          ? const Color(0xFFF8F6F0)
          : const Color(0xFF101311),
      onTertiary: brightness == Brightness.light
          ? const Color(0xFFF8F6F0)
          : const Color(0xFF101311),
      onSurface: onSurface,
    );

    final colorScheme = (dynamicScheme ?? defaultScheme).copyWith(
      outline: surfaces.border,
      outlineVariant: surfaces.borderStrong,
      surfaceContainerHighest: surfaces.panelMuted,
      surfaceTint: Colors.transparent,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: surfaces.background,
      canvasColor: surfaces.background,
      fontFamily: 'NotoSansSC',
      extensions: <ThemeExtension<dynamic>>[surfaces],
      textTheme: _textTheme(
        brightness == Brightness.light
            ? Typography.blackMountainView
            : Typography.whiteMountainView,
        onSurface,
        surfaces.textMuted,
      ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: onSurface,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        color: surfaces.panel,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: surfaces.border),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: surfaces.border,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaces.panelMuted,
        labelStyle: TextStyle(color: surfaces.textMuted),
        hintStyle: TextStyle(color: surfaces.textSoft),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: surfaces.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: surfaces.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          disabledBackgroundColor: surfaces.panelMuted,
          disabledForegroundColor: surfaces.textSoft,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: base.textTheme.labelLarge?.copyWith(
            color: colorScheme.onPrimary,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: surfaces.borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: base.textTheme.labelLarge,
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: surfaces.panelMuted,
        disabledColor: surfaces.panelMuted,
        selectedColor: colorScheme.primaryContainer,
        side: BorderSide(color: surfaces.border),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
        labelStyle: base.textTheme.labelMedium?.copyWith(
          color: onSurface,
        ),
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: colorScheme.primary,
        inactiveTrackColor: surfaces.border,
        thumbColor: colorScheme.primary,
        overlayColor: colorScheme.primary.withValues(alpha: 0.10),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: colorScheme.primary,
        linearTrackColor: surfaces.panelMuted,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.fixed,
        backgroundColor: surfaces.panelStrong,
        contentTextStyle: base.textTheme.bodyMedium?.copyWith(
          color: brightness == Brightness.light
              ? const Color(0xFFF4F1E9)
              : const Color(0xFF121613),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaces.panel,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: surfaces.border),
        ),
      ),
      switchTheme: SwitchThemeData(
        trackOutlineColor: WidgetStatePropertyAll(surfaces.borderStrong),
      ),
    );
  }

  static TextTheme _textTheme(
    TextTheme base,
    Color onSurface,
    Color textMuted,
  ) {
    return base.copyWith(
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: 'NotoSerifSC',
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 1.1,
        letterSpacing: -0.8,
        color: onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: 'NotoSerifSC',
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.12,
        letterSpacing: -0.6,
        color: onSurface,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 22,
        height: 1.2,
        letterSpacing: -0.2,
        color: onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 18,
        height: 1.26,
        letterSpacing: -0.1,
        color: onSurface,
      ),
      titleSmall: base.titleSmall?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 15,
        height: 1.3,
        color: onSurface,
      ),
      bodyLarge: base.bodyLarge?.copyWith(
        fontSize: 15,
        height: 1.55,
        color: onSurface,
      ),
      bodyMedium: base.bodyMedium?.copyWith(
        fontSize: 14,
        height: 1.5,
        color: onSurface,
      ),
      bodySmall: base.bodySmall?.copyWith(
        fontSize: 12,
        height: 1.45,
        color: textMuted,
      ),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 14,
        letterSpacing: 0.2,
        color: onSurface,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        letterSpacing: 0.35,
        color: textMuted,
      ),
    );
  }
}
