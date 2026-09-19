import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Centralized design tokens. Screens should read colors from
/// `Theme.of(context).colorScheme` and never hardcode a `Colors.*` value,
/// so this file is the single place the app's palette is defined.
///
/// Semantic mapping used throughout the app:
///  - colorScheme.surface        -> card/sheet/dialog/appbar surfaces
///  - colorScheme.onSurface      -> primary text
///  - colorScheme.onSurfaceVariant -> secondary text
///  - colorScheme.primary        -> accent (today/selected/current/next)
///  - colorScheme.tertiary       -> answered/completed (muted green)
///  - colorScheme.error          -> destructive/overdue (muted red)
///  - colorScheme.outline / dividerColor -> hairline borders
class AppTheme {
  AppTheme._();

  static const accent = Color(0xFF4F6BED);

  static const _lightBackground = Color(0xFFFAF8F3);
  static const _darkBackground = Color(0xFF141311);

  /// Accent color for TEXT and ICONS on the light background (e.g. "This
  /// week", the active nav label, a today header). #4F6BED itself is just
  /// under 4.5:1 for small text on the off-white background, so text/icon
  /// uses this darker variant while fills (FAB, today circle, selected
  /// date) keep using [accent] directly. Mapped onto ColorScheme.secondary,
  /// which the app otherwise leaves unused.
  static const _accentTextLight = Color(0xFF3F58D6);
  static const _accentTextDark = Color(0xFF8CA0FF);

  static final ColorScheme _lightScheme = ColorScheme.light(
    primary: accent,
    onPrimary: Colors.white,
    secondary: _accentTextLight,
    onSecondary: Colors.white,
    surface: const Color(0xFFFFFEFB),
    onSurface: const Color(0xFF24211C),
    onSurfaceVariant: const Color(0xFF6A6357),
    tertiary: const Color(0xFF5F9568),
    onTertiary: Colors.white,
    error: const Color(0xFFB3413A),
    onError: Colors.white,
    outline: const Color(0xFFE8E4DA),
  );

  static final ColorScheme _darkScheme = ColorScheme.dark(
    primary: accent,
    onPrimary: Colors.white,
    secondary: _accentTextDark,
    onSecondary: Color(0xFF141311),
    surface: const Color(0xFF1B1A17),
    onSurface: const Color(0xFFF1EEE7),
    onSurfaceVariant: const Color(0xFFA39E93),
    tertiary: const Color(0xFF7FB587),
    onTertiary: const Color(0xFF141311),
    error: const Color(0xFFE5867D),
    onError: const Color(0xFF141311),
    outline: const Color(0xFF2E2C27),
  );

  static ThemeData get light => _build(
    _lightScheme,
    _lightBackground,
    CategoryColors.light,
    SurfaceTokens.light,
  );
  static ThemeData get dark => _build(
    _darkScheme,
    _darkBackground,
    CategoryColors.dark,
    SurfaceTokens.dark,
  );

  static ThemeData _build(
    ColorScheme scheme,
    Color background,
    CategoryColors categoryColors,
    SurfaceTokens surfaceTokens,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      extensions: [categoryColors, surfaceTokens],
    );
    final textTheme = GoogleFonts.interTextTheme(base.textTheme).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return base.copyWith(
      textTheme: textTheme,
      dividerColor: scheme.outline,
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.inter(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.inter(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.secondary : scheme.onSurfaceVariant,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      dialogTheme: DialogThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface,
        elevation: isDark ? 0 : null,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        surfaceTintColor: Colors.transparent,
        backgroundColor: scheme.surface,
        elevation: isDark ? 0 : null,
        modalElevation: isDark ? 0 : null,
      ),
      listTileTheme: ListTileThemeData(
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return scheme.primary;
          return null;
        }),
      ),
    );
  }
}

/// Applies tabular (fixed-width) figures to a style, for anywhere numeric
/// alignment matters: times, dates, calendar numbers, durations.
TextStyle tabularNums(TextStyle? style) {
  return (style ?? const TextStyle()).copyWith(
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}

/// The supporting palette layered on top of the neutral design to give
/// different kinds of content a subtle, consistent identity: sage for
/// 1-on-1 studies, lavender for groups, amber for events, rose for general
/// notes, teal for prayer. Each has a very pale "tint" for backgrounds/pills.
/// This is a [ThemeExtension] (rather than a field on [ColorScheme]) because
/// these colors are specific to this app, not part of Material's palette.
@immutable
class CategoryColors extends ThemeExtension<CategoryColors> {
  final Color sage;
  final Color sageTint;
  final Color lavender;
  final Color lavenderTint;
  final Color amber;
  final Color amberTint;
  final Color rose;
  final Color roseTint;
  final Color teal;
  final Color tealTint;

  const CategoryColors({
    required this.sage,
    required this.sageTint,
    required this.lavender,
    required this.lavenderTint,
    required this.amber,
    required this.amberTint,
    required this.rose,
    required this.roseTint,
    required this.teal,
    required this.tealTint,
  });

  static const light = CategoryColors(
    sage: Color(0xFF6E9B78),
    sageTint: Color(0xFFEBF2EC),
    lavender: Color(0xFF8B7BB8),
    lavenderTint: Color(0xFFF0EDF6),
    amber: Color(0xFFC58A3A),
    amberTint: Color(0xFFF8F0E4),
    rose: Color(0xFFC97979),
    roseTint: Color(0xFFF8EBEB),
    teal: Color(0xFF4F9690),
    tealTint: Color(0xFFE9F3F2),
  );

  // Dark tints are the strong color itself at ~12% opacity, composited
  // live over the dark surface -- not a separate hand-picked pastel, per
  // the "do not reuse light-mode pastels in dark mode" rule.
  static const _sageDark = Color(0xFF8DB897);
  static const _lavenderDark = Color(0xFFA99BD6);
  static const _amberDark = Color(0xFFD9A55E);
  static const _roseDark = Color(0xFFDB9494);
  static const _tealDark = Color(0xFF6DB5AE);

  static final dark = CategoryColors(
    sage: _sageDark,
    sageTint: _sageDark.withValues(alpha: 0.12),
    lavender: _lavenderDark,
    lavenderTint: _lavenderDark.withValues(alpha: 0.12),
    amber: _amberDark,
    amberTint: _amberDark.withValues(alpha: 0.12),
    rose: _roseDark,
    roseTint: _roseDark.withValues(alpha: 0.12),
    teal: _tealDark,
    tealTint: _tealDark.withValues(alpha: 0.12),
  );

  @override
  CategoryColors copyWith({
    Color? sage,
    Color? sageTint,
    Color? lavender,
    Color? lavenderTint,
    Color? amber,
    Color? amberTint,
    Color? rose,
    Color? roseTint,
    Color? teal,
    Color? tealTint,
  }) {
    return CategoryColors(
      sage: sage ?? this.sage,
      sageTint: sageTint ?? this.sageTint,
      lavender: lavender ?? this.lavender,
      lavenderTint: lavenderTint ?? this.lavenderTint,
      amber: amber ?? this.amber,
      amberTint: amberTint ?? this.amberTint,
      rose: rose ?? this.rose,
      roseTint: roseTint ?? this.roseTint,
      teal: teal ?? this.teal,
      tealTint: tealTint ?? this.tealTint,
    );
  }

  @override
  CategoryColors lerp(ThemeExtension<CategoryColors>? other, double t) {
    if (other is! CategoryColors) return this;
    return CategoryColors(
      sage: Color.lerp(sage, other.sage, t)!,
      sageTint: Color.lerp(sageTint, other.sageTint, t)!,
      lavender: Color.lerp(lavender, other.lavender, t)!,
      lavenderTint: Color.lerp(lavenderTint, other.lavenderTint, t)!,
      amber: Color.lerp(amber, other.amber, t)!,
      amberTint: Color.lerp(amberTint, other.amberTint, t)!,
      rose: Color.lerp(rose, other.rose, t)!,
      roseTint: Color.lerp(roseTint, other.roseTint, t)!,
      teal: Color.lerp(teal, other.teal, t)!,
      tealTint: Color.lerp(tealTint, other.tealTint, t)!,
    );
  }
}

/// Shorthand for `Theme.of(context).extension<CategoryColors>()!`.
CategoryColors categoryColors(BuildContext context) {
  return Theme.of(context).extension<CategoryColors>()!;
}

/// Chrome tokens with no existing ColorScheme equivalent: the tinted band
/// behind a day header, the track behind the Day/Week toggle, its selected
/// segment's raised pill, the overdue-status text color, and the neutral
/// ring on an unchecked to-do circle.
@immutable
class SurfaceTokens extends ThemeExtension<SurfaceTokens> {
  final Color dayBand;
  final Color toggleTrack;
  final Color selectedPill;
  final Color overdueText;
  final Color checkboxRing;

  const SurfaceTokens({
    required this.dayBand,
    required this.toggleTrack,
    required this.selectedPill,
    required this.overdueText,
    required this.checkboxRing,
  });

  static const light = SurfaceTokens(
    dayBand: Color(0xFFF2EFE8),
    toggleTrack: Color(0xFFEFECE5),
    selectedPill: Color(0xFFFFFEFB),
    overdueText: Color(0xFFB0413E),
    checkboxRing: Color(0xFFC4BDAE),
  );

  static const dark = SurfaceTokens(
    dayBand: Color(0xFF1E1D1A),
    toggleTrack: Color(0xFF26241F),
    selectedPill: Color(0xFF3A3733),
    overdueText: Color(0xFFE58A86),
    checkboxRing: Color(0xFF5A564E),
  );

  @override
  SurfaceTokens copyWith({
    Color? dayBand,
    Color? toggleTrack,
    Color? selectedPill,
    Color? overdueText,
    Color? checkboxRing,
  }) {
    return SurfaceTokens(
      dayBand: dayBand ?? this.dayBand,
      toggleTrack: toggleTrack ?? this.toggleTrack,
      selectedPill: selectedPill ?? this.selectedPill,
      overdueText: overdueText ?? this.overdueText,
      checkboxRing: checkboxRing ?? this.checkboxRing,
    );
  }

  @override
  SurfaceTokens lerp(ThemeExtension<SurfaceTokens>? other, double t) {
    if (other is! SurfaceTokens) return this;
    return SurfaceTokens(
      dayBand: Color.lerp(dayBand, other.dayBand, t)!,
      overdueText: Color.lerp(overdueText, other.overdueText, t)!,
      checkboxRing: Color.lerp(checkboxRing, other.checkboxRing, t)!,
      toggleTrack: Color.lerp(toggleTrack, other.toggleTrack, t)!,
      selectedPill: Color.lerp(selectedPill, other.selectedPill, t)!,
    );
  }
}

/// Shorthand for `Theme.of(context).extension<SurfaceTokens>()!`.
SurfaceTokens surfaceTokens(BuildContext context) {
  return Theme.of(context).extension<SurfaceTokens>()!;
}
