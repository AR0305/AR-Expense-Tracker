import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FontOption {
  final String name;
  final String displayName;
  final String category;
  final bool isDefaultTitle;
  final bool isDefaultBody;

  const FontOption({
    required this.name,
    required this.displayName,
    required this.category,
    this.isDefaultTitle = false,
    this.isDefaultBody = false,
  });
}

class FontUtils {
  static const String defaultTitleFont = 'Mea Culpa';
  static const String defaultBodyFont = 'Elms Sans';
  static const String robotoFont = 'Roboto';

  static const List<FontOption> availableFonts = [
    FontOption(
      name: 'Mea Culpa',
      displayName: 'Mea Culpa (Default Title)',
      category: 'Handwritten',
      isDefaultTitle: true,
    ),
    FontOption(
      name: 'Elms Sans',
      displayName: 'Elms Sans (Default Body)',
      category: 'Sans-Serif',
      isDefaultBody: true,
    ),
    FontOption(
      name: 'Roboto',
      displayName: 'Roboto',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Inter',
      displayName: 'Inter',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Poppins',
      displayName: 'Poppins',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Outfit',
      displayName: 'Outfit',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Lato',
      displayName: 'Lato',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Montserrat',
      displayName: 'Montserrat',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Open Sans',
      displayName: 'Open Sans',
      category: 'Sans-Serif',
    ),
    FontOption(
      name: 'Dancing Script',
      displayName: 'Dancing Script',
      category: 'Handwritten',
    ),
    FontOption(
      name: 'Great Vibes',
      displayName: 'Great Vibes',
      category: 'Handwritten',
    ),
    FontOption(
      name: 'Caveat',
      displayName: 'Caveat',
      category: 'Handwritten',
    ),
    FontOption(
      name: 'Playfair Display',
      displayName: 'Playfair Display',
      category: 'Serif',
    ),
    FontOption(
      name: 'Lora',
      displayName: 'Lora',
      category: 'Serif',
    ),
    FontOption(
      name: 'Merriweather',
      displayName: 'Merriweather',
      category: 'Serif',
    ),
    FontOption(
      name: 'Cinzel',
      displayName: 'Cinzel',
      category: 'Serif',
    ),
    FontOption(
      name: 'Oswald',
      displayName: 'Oswald',
      category: 'Display',
    ),
    FontOption(
      name: 'Pacifico',
      displayName: 'Pacifico',
      category: 'Display',
    ),
    FontOption(
      name: 'Bebas Neue',
      displayName: 'Bebas Neue',
      category: 'Display',
    ),
    FontOption(
      name: 'Lobster',
      displayName: 'Lobster',
      category: 'Display',
    ),
    FontOption(
      name: 'System Default',
      displayName: 'System Default',
      category: 'System',
    ),
  ];

  /// Resolves a TextStyle for a given font name safely with fallbacks
  static TextStyle getFontTextStyle(String fontName, TextStyle baseStyle) {
    if (fontName == 'System Default') {
      return baseStyle;
    }
    try {
      return GoogleFonts.getFont(
        fontName,
        textStyle: baseStyle,
      );
    } catch (_) {
      return baseStyle.copyWith(fontFamily: fontName);
    }
  }

  /// Resolves a TextTheme for a given font name safely with fallbacks
  static TextTheme getTextTheme(String fontName, TextTheme baseTheme) {
    if (fontName == 'System Default') {
      return baseTheme;
    }
    try {
      return GoogleFonts.getTextTheme(fontName, baseTheme);
    } catch (_) {
      return baseTheme;
    }
  }

  /// Builds a combined TextTheme applying titleFont to display, headline, and title styles
  /// and bodyFont to body and label styles across the entire application.
  static TextTheme buildCombinedTextTheme(
    TextTheme baseTheme,
    String titleFont,
    String bodyFont,
  ) {
    final bodyTheme = getTextTheme(bodyFont, baseTheme);
    final titleTheme = getTextTheme(titleFont, baseTheme);

    return bodyTheme.copyWith(
      displayLarge: titleTheme.displayLarge,
      displayMedium: titleTheme.displayMedium,
      displaySmall: titleTheme.displaySmall,
      headlineLarge: titleTheme.headlineLarge,
      headlineMedium: titleTheme.headlineMedium,
      headlineSmall: titleTheme.headlineSmall,
      titleLarge: titleTheme.titleLarge,
      titleMedium: titleTheme.titleMedium,
      titleSmall: titleTheme.titleSmall,
    );
  }
}
