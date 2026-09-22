import 'package:flutter/material.dart';

/// -----------------------------------------------------------------------
/// Design tokens
/// -----------------------------------------------------------------------
/// Color tokens ported 1:1 from src/styles/global.css (:root variables),
/// refined for a more polished, professional finish. All field names are
/// preserved so every existing call site keeps working unchanged.
class AppColors {
  static const navy = Color(0xFF0F2038);
  static const navy2 = Color(0xFF0B1626);
  static const orange = Color(0xFFD9772B);
  static const orangeDeep = Color(0xFFB85F1D);
  static const white = Color(0xFFFFFFFF);
  static const offWhite = Color(0xFFF6F1E6);
  static const gray = Color(0xFF5B6B7D);
  static const light = Color(0xFFDCE3E9);
  static const ink = Color(0xFF16202B);
  static const bg = Color(0xFFF2EEE4);
  static const surface = Color(0xD2FFFAF2); // rgba(255,250,242,0.82)
  static const text = Color(0xFF1D281D);
  static const muted = Color(0xFF5B6459);
  static const line = Color(0x263C4E3E);
  static const primary = Color(0xFF1B6349);
  static const primaryDark = Color(0xFF134A38);
  static const accent = Color(0xFFCF6A29);
  static const danger = Color(0xFFA23636);

  // Extra neutral/elevation tokens (additive, non-breaking).
  static const border = Color(0xFFE1E7E1);
  static const cardTop = Color(0xFFFFFDF8);
  static const shadow = Color(0xFF0E1A12);
  static const success = Color(0xFF1B6349);

  // Status pill colors (approx, based on usage across the app)
  static const statusCompleted = primary;
  static const statusPending = accent;
  static const statusLeave = Color(0xFF7A5AF8);
  static const statusHoliday = Color(0xFF2478C7);
  static const statusCompOff = Color(0xFF0E9F8E);
  static const statusBlocked = danger;
  static const statusNeedsSupport = Color(0xFFAD7A0A);
  static const statusRejected = danger;
  static const statusApproved = primary;
}

/// Consistent spacing scale used for new/updated layout code. Existing
/// hard-coded paddings elsewhere are untouched, so nothing regresses.
class AppSpacing {
  static const xs = 6.0;
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppRadius {
  static const sm = 10.0;
  static const md = 14.0;
  static const lg = 20.0;
  static const pill = 999.0;
}

ThemeData buildAppTheme() {
  final textTheme = const TextTheme(
    displayLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.5),
    headlineMedium: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, letterSpacing: -0.3),
    titleLarge: TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 20),
    titleMedium: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink, fontSize: 16),
    bodyLarge: TextStyle(color: AppColors.text, fontSize: 15, height: 1.45),
    bodyMedium: TextStyle(color: AppColors.text, fontSize: 14, height: 1.45),
    labelLarge: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.2),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: 'Roboto',
    splashFactory: InkRipple.splashFactory,
    textTheme: textTheme,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      error: AppColors.danger,
      surface: AppColors.bg,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 24),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.navy,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white.withValues(alpha: 0.86),
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white,
      selectedColor: AppColors.primary,
      side: const BorderSide(color: AppColors.border),
      labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppColors.ink),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: AppColors.primaryDark,
      contentTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      elevation: 4,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primary),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
        disabledForegroundColor: Colors.white.withValues(alpha: 0.85),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryDark,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.gray),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      hintStyle: TextStyle(color: AppColors.gray.withValues(alpha: 0.8)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.light),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.light),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
      ),
    ),
  );
}

/// A rounded, softly-shadowed card matching `.glass-card` styling, refined
/// with a subtle top highlight and crisper hairline border for a more
/// premium, layered feel. API is unchanged from the original component.
class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.cardTop.withValues(alpha: 0.92),
            Colors.white.withValues(alpha: 0.80),
          ],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.07),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
          BoxShadow(
            color: AppColors.shadow.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        hoverColor: AppColors.primary.withValues(alpha: 0.04),
        splashColor: AppColors.primary.withValues(alpha: 0.08),
        child: card,
      ),
    );
  }
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          margin: const EdgeInsets.only(right: 7),
          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        ),
        Flexible(
          child: Text(
            text.toUpperCase(),
            style: const TextStyle(
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
              fontSize: 12,
              letterSpacing: 1.1,
            ),
          ),
        ),
      ],
    );
  }
}

class MutedText extends StatelessWidget {
  final String text;
  final TextAlign? align;
  const MutedText(this.text, {super.key, this.align});
  @override
  Widget build(BuildContext context) {
    return Text(text, textAlign: align, style: const TextStyle(color: AppColors.muted, fontSize: 13, height: 1.4));
  }
}

/// A small circular avatar showing a person's initial(s), used in headers
/// to give a more finished, branded look. Purely additive/new widget.
class InitialAvatar extends StatelessWidget {
  final String name;
  final double size;
  const InitialAvatar({super.key, required this.name, this.size = 40});

  String get _initials {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0].substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDark],
        ),
        boxShadow: [
          BoxShadow(color: AppColors.primary.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Text(
        _initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.38),
      ),
    );
  }
}

/// A compact brand mark (wordmark + accent dot) reused on the login screen
/// and module headers for a consistent, professional identity.
class BrandMark extends StatelessWidget {
  final double fontSize;
  const BrandMark({super.key, this.fontSize = 15});
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          'TXTILPROS',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            letterSpacing: 1.4,
            color: AppColors.navy,
          ),
        ),
      ],
    );
  }
}
