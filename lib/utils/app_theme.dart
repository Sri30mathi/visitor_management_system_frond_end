// lib/utils/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ── Palette ────────────────────────────────────────────────
  static const Color primary      = Color(0xFF1B4FFF);
  static const Color primaryLight = Color(0xFFEEF2FF);
  static const Color accent       = Color(0xFF00C896);
  static const Color background   = Color(0xFFF5F7FF);
  static const Color surface      = Color(0xFFFFFFFF);
  static const Color border       = Color(0xFFE8ECFF);
  static const Color textPrimary  = Color(0xFF0D1B4B);
  static const Color textSecondary= Color(0xFF6B7AAD);
  static const Color textMuted    = Color(0xFFADB5D6);

  static const Color statusIn     = Color(0xFF00C27C);
  static const Color statusWait   = Color(0xFFFF9500);
  static const Color statusOut    = Color(0xFF8896C8);
  static const Color statusError  = Color(0xFFFF3B5C);

  // ── Gradients ──────────────────────────────────────────────
  static const LinearGradient brandGrad = LinearGradient(
    colors: [Color(0xFF1B4FFF), Color(0xFF4472FF)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );
  static const LinearGradient darkGrad = LinearGradient(
    colors: [Color(0xFF0D1B4B), Color(0xFF1A2E7A)],
    begin: Alignment.topLeft, end: Alignment.bottomRight,
  );

  // ── Shadows ────────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
    BoxShadow(color: const Color(0xFF1B4FFF).withOpacity(0.06),
        blurRadius: 20, offset: const Offset(0, 4)),
    BoxShadow(color: Colors.black.withOpacity(0.03),
        blurRadius: 6, offset: const Offset(0, 2)),
  ];
  static List<BoxShadow> get btnShadow => [
    BoxShadow(color: const Color(0xFF1B4FFF).withOpacity(0.35),
        blurRadius: 20, offset: const Offset(0, 6)),
  ];

  // ── Radii ──────────────────────────────────────────────────
  static final BorderRadius r8  = BorderRadius.circular(8);
  static final BorderRadius r12 = BorderRadius.circular(12);
  static final BorderRadius r16 = BorderRadius.circular(16);
  static final BorderRadius r24 = BorderRadius.circular(24);

  // ── Status helpers ─────────────────────────────────────────
  static Color statusColor(String s) {
    switch (s) {
      case 'Registered': return statusWait;
      case 'CheckedIn':  return statusIn;
      case 'CheckedOut': return statusOut;
      default:           return primary;
    }
  }

  static String statusLabel(String s) {
    switch (s) {
      case 'CheckedIn':  return 'Checked In';
      case 'CheckedOut': return 'Checked Out';
      default:           return s;
    }
  }

  static IconData statusIcon(String s) {
    switch (s) {
      case 'Registered': return Icons.schedule_rounded;
      case 'CheckedIn':  return Icons.check_circle_rounded;
      case 'CheckedOut': return Icons.logout_rounded;
      default:           return Icons.help_outline_rounded;
    }
  }

  // ── ThemeData ──────────────────────────────────────────────
  static ThemeData get theme => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary, surface: surface,
      error: statusError,
    ),
    scaffoldBackgroundColor: background,
    fontFamily: 'Outfit',

    appBarTheme: const AppBarTheme(
      backgroundColor: surface, foregroundColor: textPrimary,
      elevation: 0, scrolledUnderElevation: 0.5,
      shadowColor: border, centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: 'Outfit', fontSize: 18,
          fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.3),
      iconTheme: IconThemeData(color: textSecondary, size: 20),
    ),

    cardTheme: CardThemeData(
      elevation: 0, color: surface, surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border)),
      margin: EdgeInsets.zero,
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: statusError)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(color: textSecondary, fontFamily: 'Outfit', fontSize: 14),
      hintStyle: const TextStyle(color: textMuted, fontFamily: 'Outfit', fontSize: 14),
      prefixIconColor: textMuted,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary, foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Outfit',
            fontWeight: FontWeight.w600, fontSize: 15),
        elevation: 0,
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        side: const BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontFamily: 'Outfit',
            fontWeight: FontWeight.w500, fontSize: 14),
      ),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: const Color(0xFFF0F3FF),
      selectedColor: primaryLight,
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      labelStyle: const TextStyle(fontFamily: 'Outfit',
          fontSize: 12, fontWeight: FontWeight.w500),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    ),

    dividerTheme: const DividerThemeData(
        color: border, thickness: 1, space: 1),

    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: surface, elevation: 0,
      surfaceTintColor: Colors.transparent,
      indicatorColor: primaryLight,
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
        color: s.contains(WidgetState.selected) ? primary : textMuted, size: 22)),
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
        fontFamily: 'Outfit', fontSize: 11,
        fontWeight: s.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w400,
        color: s.contains(WidgetState.selected) ? primary : textMuted,
      )),
    ),

    navigationRailTheme: const NavigationRailThemeData(
      backgroundColor: surface, indicatorColor: primaryLight,
      selectedIconTheme: IconThemeData(color: primary, size: 22),
      unselectedIconTheme: IconThemeData(color: textMuted, size: 22),
      selectedLabelTextStyle: TextStyle(fontFamily: 'Outfit',
          fontSize: 13, fontWeight: FontWeight.w600, color: primary),
      unselectedLabelTextStyle: TextStyle(fontFamily: 'Outfit',
          fontSize: 13, fontWeight: FontWeight.w400, color: textMuted),
    ),
  );
}

// ─────────────────────────────────────────────────────────
//  SHARED WIDGETS
// ─────────────────────────────────────────────────────────

/// Coloured status badge with icon
class StatusBadge extends StatelessWidget {
  final String status;
  const StatusBadge(this.status, {super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppTheme.statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: c.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(AppTheme.statusIcon(status), size: 11, color: c),
        const SizedBox(width: 5),
        Text(AppTheme.statusLabel(status),
            style: TextStyle(color: c, fontSize: 11,
                fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
      ]),
    );
  }
}

/// Gradient filled button with shadow
class GradientButton extends StatelessWidget {
  final String     label;
  final IconData?  icon;
  final VoidCallback? onTap;
  final bool       loading;
  final double     height;

  const GradientButton({super.key, required this.label, this.icon,
      this.onTap, this.loading = false, this.height = 50});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity, height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: onTap == null
              ? const LinearGradient(colors: [Color(0xFFADB5D6), Color(0xFFADB5D6)])
              : AppTheme.brandGrad,
          borderRadius: AppTheme.r12,
          boxShadow: onTap == null ? [] : AppTheme.btnShadow,
        ),
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: AppTheme.r12),
          ),
          child: loading
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
              : Row(mainAxisSize: MainAxisSize.min, children: [
                  if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
                  Text(label, style: const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w600, color: Colors.white)),
                ]),
        ),
      ),
    );
  }
}

/// White card with border + shadow
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final VoidCallback? onTap;
  final BorderRadius? radius;

  const AppCard({super.key, required this.child,
      this.padding, this.onTap, this.radius});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: radius ?? AppTheme.r16,
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: onTap != null
          ? Material(
              color: Colors.transparent, borderRadius: radius ?? AppTheme.r16,
              child: InkWell(
                onTap: onTap, borderRadius: radius ?? AppTheme.r16,
                child: Padding(
                    padding: padding ?? const EdgeInsets.all(16), child: child),
              ))
          : Padding(padding: padding ?? const EdgeInsets.all(16), child: child),
    );
  }
}

/// Dashboard stat card
class StatCard extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData icon;
  final Color    color;
  final String?  tag;

  const StatCard({super.key, required this.label, required this.value,
      required this.icon, required this.color, this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: AppTheme.r16,
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 19),
              ),
              if (tag != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text(tag!, style: TextStyle(color: color, fontSize: 9,
                      fontWeight: FontWeight.w700, fontFamily: 'Outfit')),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: color,
              fontFamily: 'Outfit',
              letterSpacing: -0.5,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary,
              fontFamily: 'Outfit',
            ),
          ),
        ],
      ),
    );
  }
}