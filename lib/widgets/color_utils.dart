import 'package:flutter/material.dart';

/// Returns black or white depending on which contrasts better with [bg].
Color contrastOn(Color bg) {
  // Perceived luminance (per WCAG-ish weighting).
  final luminance =
      (0.299 * bg.red + 0.587 * bg.green + 0.114 * bg.blue) / 255;
  return luminance > 0.55 ? Colors.black87 : Colors.white;
}

/// A palette of subject colors offered in the editor.
const List<int> kSubjectPalette = [
  0xFF3F51B5, // indigo
  0xFF00897B, // teal
  0xFFEF6C00, // orange
  0xFF8E24AA, // purple
  0xFF43A047, // green
  0xFFE53935, // red
  0xFF6D4C41, // brown
  0xFF1E88E5, // blue
  0xFFF4511E, // deep orange
  0xFF546E7A, // blue grey
];
