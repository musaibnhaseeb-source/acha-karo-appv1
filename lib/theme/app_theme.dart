import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Ported directly from the CSS custom properties in the web version's globals.css.
// Same hex values, same names (minus the -- prefix), so this stays easy to cross-reference.
class AppColors {
  static const olive = Color(0xFF9FAE6E);
  static const oliveDeep = Color(0xFF3C4A2C);
  static const oliveCard = Color(0x298C9A5C); // rgba(140,154,92,0.16)
  static const oliveCardStrong = Color(0x428C9A5C); // rgba(140,154,92,0.26)
  static const gold = Color(0xFFD9A62E);
  static const rust = Color(0xFFC1573D);
  static const text = Color(0xFFF6F5EC);
  static const textSoft = Color(0xFFC9CDBC);
  static const inkOnGold = Color(0xFF1B1706);
  static const bg1 = Color(0xFF081209);
  static const bg2 = Color(0xFF0F2016);
  static const bg4 = Color(0xFF0B1710);
}

// Font families ported from the same Google Fonts used on the web version. Fraunces is used
// for headings/titles, Inter for body text, IBM Plex Mono for numbers/labels/timers, and Noto
// Nastaliq Urdu specifically for the Urdu tier names and the خوش آمدید welcome text.
class AppFonts {
  // decoration: TextDecoration.none is set explicitly on all four now — found a real underline
  // bug on the نستعلیق text that a previous fix only patched at the call site instead of here,
  // so it silently kept happening on other text using the same font. Fixing centrally instead.
  static TextStyle fraunces({double size = 16, FontWeight weight = FontWeight.w600, Color? color, double? height}) =>
      GoogleFonts.fraunces(fontSize: size, fontWeight: weight, color: color ?? AppColors.text, height: height, decoration: TextDecoration.none);

  static TextStyle inter({double size = 14, FontWeight weight = FontWeight.w400, Color? color, double? height}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color ?? AppColors.text, height: height, decoration: TextDecoration.none);

  static TextStyle plexMono({double size = 11, FontWeight weight = FontWeight.w600, Color? color, double? height}) =>
      GoogleFonts.ibmPlexMono(fontSize: size, fontWeight: weight, color: color ?? AppColors.textSoft, height: height, decoration: TextDecoration.none);

  static TextStyle nastaliq({double size = 22, Color? color}) =>
      GoogleFonts.notoNastaliqUrdu(fontSize: size, color: color ?? AppColors.gold, decoration: TextDecoration.none);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg1,
    colorScheme: ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.olive,
      surface: AppColors.bg2,
      error: AppColors.rust,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}
