import 'package:flutter/material.dart';

/// Safely parses a hex color string stored in the database.
///
/// Accepts: `null`, `'transparent'`, `'#RRGGBB'`, `'#AARRGGBB'`,
///          `'RRGGBB'`, `'AARRGGBB'`.
/// Returns [Colors.transparent] for null, empty, 'transparent', or
/// any value that cannot be parsed.
Color parseHexColor(String? raw) {
  if (raw == null || raw.isEmpty || raw == 'transparent') {
    return Colors.transparent;
  }
  final hex = raw.startsWith('#') ? raw.substring(1) : raw;
  final val = int.tryParse(hex.length == 6 ? 'FF$hex' : hex, radix: 16);
  return val != null ? Color(val) : Colors.transparent;
}
