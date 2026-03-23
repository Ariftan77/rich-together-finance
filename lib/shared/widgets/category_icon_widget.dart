import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../utils/phosphor_icon_registry.dart';

/// Renders a category icon from its DB string.
/// Emoji strings render as Text; "ph:name" strings render as PhosphorIcon.
class CategoryIconWidget extends StatelessWidget {
  final String iconString;
  final double size;
  final Color? color;

  const CategoryIconWidget({
    super.key,
    required this.iconString,
    this.size = 20,
    this.color,
  });

  static bool isPhosphorIcon(String icon) => icon.startsWith('ph:');

  static String phosphorName(String icon) => icon.substring(3);

  @override
  Widget build(BuildContext context) {
    if (isPhosphorIcon(iconString)) {
      final name = phosphorName(iconString);
      final iconData = phosphorIconMap[name] ?? PhosphorIconsFill.question;
      return PhosphorIcon(
        iconData,
        size: size,
        color: color ?? Colors.white,
      );
    }
    return Text(iconString, style: TextStyle(fontSize: size));
  }
}
