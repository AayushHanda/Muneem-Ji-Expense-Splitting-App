import 'package:flutter/material.dart';

/// Color palette inspired by the app logo (teal/cyan chevron)
class AppColors {
  // ========================
  // BRAND PALETTE (Logo-matched teal/sky-blue)
  // ========================
  static const Color brand      = Color(0xFF00BFA5); // Teal accent
  static const Color brandDark  = Color(0xFF00897B); // Deep teal
  static const Color brandDeep  = Color(0xFF004D40); // Darker teal accent
  static const Color brandLight = Color(0xFFB2DFDB); // Very light teal

  // ========================
  // LIGHT THEME
  // ========================
  static const Color backgroundLight    = Color(0xFFF5FAFE); // Near-white with blue tint
  static const Color surfaceLight       = Color(0xFFFFFFFF);
  static const Color textPrimaryLight   = Color(0xFF0D2137); // Very dark navy
  static const Color textSecondaryLight = Color(0xFF6B8299); // Muted blue-gray

  // ========================
  // DARK THEME
  // ========================
  static const Color backgroundDark    = Color(0xFF0A1929); // Deep navy (logo dark)
  static const Color surfaceDark       = Color(0xFF102033); // Slightly lighter navy
  static const Color cardDark          = Color(0xFF153047); // Card navy
  static const Color textPrimaryDark   = Color(0xFFE8F4FD); // Warm off-white
  static const Color textSecondaryDark = Color(0xFF7BAFC7); // Muted sky blue

  // ========================
  // SEMANTIC
  // ========================
  static const Color success = Color(0xFF26A65B);
  static const Color error   = Color(0xFFE53935);
  static const Color warning = Color(0xFFF57C00);

  // ========================
  // LEGACY SHORTCUTS (used across existing widgets)
  // ========================
  static const Color background    = backgroundLight;
  static const Color surface       = surfaceLight;
  static const Color primary       = brand;
  static const Color primaryDark   = brandDark;
  static const Color secondary     = brandLight;
  static const Color tertiary      = Color(0xFFE1F5FE);
  static const Color textPrimary   = textPrimaryLight;
  static const Color textSecondary = textSecondaryLight;
  static const Color textDark      = Color(0xFFFFFFFF);

  // ========================
  // GRADIENTS
  // ========================
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [brand, brandDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [brandDeep, brandDark, brand],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient oweYouGradient = LinearGradient(
    colors: [Color(0xFF26A65B), Color(0xFF1E8449)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient youOweGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFC62828)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme  => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isDark       = brightness == Brightness.dark;
    final bg           = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final surface      = isDark ? AppColors.surfaceDark     : AppColors.surfaceLight;
    final card         = isDark ? AppColors.cardDark        : AppColors.surfaceLight;
    final textPrimary  = isDark ? AppColors.textPrimaryDark  : AppColors.textPrimaryLight;
    final textSecondary= isDark ? AppColors.textSecondaryDark: AppColors.textSecondaryLight;
    final inputFill    = isDark ? const Color(0xFF1A3050)    : const Color(0xFFECF5FC);
    final dividerColor = isDark ? Colors.white12             : const Color(0xFFD6EAF8);

    return ThemeData(
      brightness          : brightness,
      scaffoldBackgroundColor: bg,
      primaryColor        : AppColors.brand,
      colorScheme: ColorScheme(
        brightness : brightness,
        primary    : AppColors.brand,
        onPrimary  : Colors.white,
        secondary  : AppColors.brandLight,
        onSecondary: AppColors.textPrimaryLight,
        error      : AppColors.error,
        onError    : Colors.white,
        surface    : surface,
        onSurface  : textPrimary,
      ),
      fontFamily: 'Inter',

      appBarTheme: AppBarTheme(
        backgroundColor   : bg,
        elevation         : 0,
        centerTitle       : true,
        scrolledUnderElevation: 0,
        surfaceTintColor  : Colors.transparent,
        iconTheme         : IconThemeData(color: textPrimary),
        titleTextStyle    : TextStyle(
          color      : textPrimary,
          fontSize   : 20,
          fontWeight : FontWeight.bold,
          letterSpacing: 0.3,
          fontFamily : 'Inter',
        ),
      ),

      cardTheme: CardThemeData(
        color      : card,
        elevation  : isDark ? 0 : 3,
        shadowColor: AppColors.brand.withOpacity(0.08),
        shape      : RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: isDark ? BorderSide(color: Colors.white.withOpacity(0.06)) : BorderSide.none,
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation      : 3,
          shadowColor    : AppColors.brand.withOpacity(0.4),
          padding        : const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape          : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle      : const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled       : true,
        fillColor    : inputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide  : const BorderSide(color: AppColors.brand, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide  : const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle     : TextStyle(color: textSecondary),
        labelStyle    : TextStyle(color: textSecondary),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
      ),

      chipTheme: ChipThemeData(
        backgroundColor : inputFill,
        selectedColor   : AppColors.brand.withOpacity(0.25),
        labelStyle      : TextStyle(color: textPrimary),
        padding         : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape           : RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide.none),
      ),

      dividerTheme: DividerThemeData(color: dividerColor, thickness: 1),

      listTileTheme: ListTileThemeData(
        textColor  : textPrimary,
        iconColor  : textSecondary,
        tileColor  : Colors.transparent,
      ),

      bottomSheetTheme: BottomSheetThemeData(backgroundColor: surface),

      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle : TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
        contentTextStyle: TextStyle(color: textSecondary, fontSize: 14),
      ),

      textTheme: TextTheme(
        bodyLarge  : TextStyle(color: textPrimary),
        bodyMedium : TextStyle(color: textPrimary),
        bodySmall  : TextStyle(color: textSecondary),
        titleLarge : TextStyle(color: textPrimary, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall : TextStyle(color: textSecondary),
      ),

      switchTheme: SwitchThemeData(
        thumbColor    : WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.brand : Colors.grey),
        trackColor    : WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? AppColors.brand.withOpacity(0.4) : Colors.grey.withOpacity(0.3)),
      ),
    );
  }
}
