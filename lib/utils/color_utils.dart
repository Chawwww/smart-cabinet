import 'package:flutter/material.dart';

class ColorUtils {
  /// Convert "#FF0000" -> Color
  static Color hexToColor(String hex) {
    final buffer = StringBuffer();

    if (hex.length == 6 || hex.length == 7) {
      buffer.write('ff');
    }

    buffer.write(hex.replaceFirst('#', ''));

    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Convert Color -> "#RRGGBB"
  static String colorToHex(Color color, {bool leadingHashSign = true}) {
    return '${leadingHashSign ? '#' : ''}'
        '${color.toARGB32().toRadixString(16).substring(2).toUpperCase()}';
  }

  /// Whether color is dark
  static bool isDarkColor(Color color) {
    return color.computeLuminance() < 0.5;
  }

  /// White text for dark colors, black text for light colors
  static Color getContrastColor(Color color) {
    return isDarkColor(color)
        ? Colors.white
        : Colors.black;
  }

  /// Preset category colors
  static const List<Color> categoryColors = [
    Color(0xFFFF6B6B),
    Color(0xFFFFA94D),
    Color(0xFFFDCB6E),
    Color(0xFF00B894),
    Color(0xFF4ECDC4),
    Color(0xFF45B7D1),
    Color(0xFF6C5CE7),
    Color(0xFFA29BFE),
    Color(0xFFFD79A8),
    Color(0xFFE17055),
  ];

  static List<Color> getCategoryColors() => categoryColors;

  /// Item status colors
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'inside':
        return const Color(0xFF00B894);

      case 'taken':
        return const Color(0xFFFDCB6E);

      case 'used':
        return const Color(0xFF6C5CE7);

      case 'damaged':
        return const Color(0xFFFF6B6B);

      default:
        return Colors.grey;
    }
  }

  /// Expiry colors
  static Color getExpiryColor(String status) {
    switch (status.toLowerCase()) {
      case 'expired':
        return const Color(0xFFFF6B6B);

      case 'expiring_soon':
        return const Color(0xFFFFA94D);

      default:
        return const Color(0xFF00B894);
    }
  }

  /// Low stock color
  static Color getStockColor({
    required int quantity,
    required int threshold,
  }) {
    if (quantity <= 0) {
      return const Color(0xFFFF6B6B);
    }

    if (quantity <= threshold) {
      return const Color(0xFFFFA94D);
    }

    return const Color(0xFF00B894);
  }

  /// Favorite item color
  static Color getFavoriteColor(bool isFavorite) {
    return isFavorite
        ? Colors.redAccent
        : Colors.grey;
  }
}