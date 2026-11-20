import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class Palette extends ThemeExtension<Palette> {
  // Text, icons, borders and filled buttons.
  final Color ink;
  // Page background, and text on filled buttons.
  final Color paper;
  // Cards, pads and keys.
  final Color surface;
  final Color wheel;
  final Color wheelShine;
  final Color idle;
  final Color warning;

  const Palette({
    required this.ink,
    required this.paper,
    required this.surface,
    required this.wheel,
    required this.wheelShine,
    required this.idle,
    required this.warning,
  });

  static const light = Palette(
    ink: Colors.black,
    paper: Colors.white,
    surface: Color(0xFFF4F4F6),
    wheel: Color(0xFFFAFAFC),
    wheelShine: Colors.white,
    idle: Color(0xFFE5E5EA),
    warning: Color(0xFFFFF4E5),
  );

  static const dark = Palette(
    ink: Colors.white,
    paper: Colors.black,
    surface: Color(0xFF1C1C1E),
    wheel: Color(0xFF141416),
    wheelShine: Color(0xFF2C2C2E),
    idle: Color(0xFF3A3A3C),
    warning: Color(0xFF3A2A12),
  );

  @override
  Palette copyWith() => this;

  @override
  Palette lerp(Palette? other, double t) {
    if (other == null) return this;
    return Palette(
      ink: Color.lerp(ink, other.ink, t)!,
      paper: Color.lerp(paper, other.paper, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      wheel: Color.lerp(wheel, other.wheel, t)!,
      wheelShine: Color.lerp(wheelShine, other.wheelShine, t)!,
      idle: Color.lerp(idle, other.idle, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
    );
  }
}

extension PaletteContext on BuildContext {
  Palette get palette => Theme.of(this).extension<Palette>() ?? Palette.light;
}

ThemeData buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final palette = dark ? Palette.dark : Palette.light;
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: palette.paper,
    fontFamily: GoogleFonts.plusJakartaSans().fontFamily,
    colorScheme: dark
        ? const ColorScheme.dark(
            primary: Colors.white,
            secondary: Color(0xFFE5E5EA),
            surface: Color(0xFF1C1C1E),
            // Snackbars. The paste progress snackbar has white text in both
            // themes, so keep them dark here too.
            inverseSurface: Color(0xFF2C2C2E),
            onInverseSurface: Colors.white,
          )
        : const ColorScheme.light(
            primary: Colors.black,
            secondary: Color(0xFF1C1C1E),
            surface: Color(0xFFF4F4F6),
          ),
    // The app bar is transparent, which Flutter takes for a dark background
    // and answers with white status bar icons, even on the white page.
    appBarTheme: AppBarTheme(
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: brightness,
      ),
    ),
    extensions: [palette],
    useMaterial3: true,
  );
}
