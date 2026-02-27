import 'package:flutter/material.dart';
import '../../../../shared/theme/colors.dart';

class CategoryIconPicker extends StatefulWidget {
  final String initialIcon;
  final String initialColorHex;

  const CategoryIconPicker({
    super.key,
    required this.initialIcon,
    required this.initialColorHex,
  });

  static Future<Map<String, String>?> show(
    BuildContext context, {
    required String initialIcon,
    required String initialColorHex,
  }) {
    return showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategoryIconPicker(
        initialIcon: initialIcon,
        initialColorHex: initialColorHex,
      ),
    );
  }

  @override
  State<CategoryIconPicker> createState() => _CategoryIconPickerState();
}

class _CategoryIconPickerState extends State<CategoryIconPicker> {
  late String _selectedIcon;
  late String _selectedColorHex;

  // Curated list of emojis
  static const List<String> _emojis = [
    '🍔', '🚗', '🏥', '🏠', '🎮', '🛒', '🛍️', '✈️', '📱', '🎓', '🎁', '🔧', '🐶',
    '🍽️', '☕', '🏢', '🚂', '⛽', '💰', '💳', '👗', '👟', '🎬', '📚', '🏋️',
    '🩺', '💊', '🛀', '🔌', '💡', '📶', '🛒', '🍎', '🥩', '🍹', '🚌', '🚕',
    '🚲', '🛠️', '⚙️', '🧹', '🧺', '🪴', '🎸', '🎨', '🧩', '🧸', '🐈', '🐾',
  ];

  // Curated list of colors (Hex Strings)
  static const List<String> _colors = [
    '#FF6B6B', // Red
    '#4ECDC4', // Teal
    '#FFE66D', // Yellow
    '#1A535C', // Dark Teal
    '#FF9F1C', // Orange
    '#2ECC71', // Green
    '#3498DB', // Blue
    '#9B59B6', // Purple
    '#E74C3C', // Dark Red
    '#34495E', // Navy
    '#F1C40F', // Sun Yellow
    '#E67E22', // Carrot
    '#BDC3C7', // Silver
    '#95A5A6', // Gray
    '#D35400', // Rust
    '#8E44AD', // Deep Purple
    '#16A085', // Sea Green
    '#27AE60', // Emerald
    '#2980B9', // Strong Blue
    '#F39C12', // Orange Yellow
  ];

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon.isEmpty ? '📦' : widget.initialIcon;
    _selectedColorHex = widget.initialColorHex.isEmpty ? '#BDC3C7' : widget.initialColorHex;
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse('0x$hex'));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF2D2416),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title and Save Button inside Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Icon & Color',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context, {
                          'icon': _selectedIcon,
                          'color': _selectedColorHex,
                        });
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primaryGold,
                      ),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              // Scrollable Content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  children: [
                    // Preview
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _hexToColor(_selectedColorHex).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _selectedIcon,
                          style: const TextStyle(fontSize: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Colors Section
                    Text(
                      'Colors',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: _colors.map((hex) {
                        final color = _hexToColor(hex);
                        final isSelected = hex == _selectedColorHex;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedColorHex = hex),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: isSelected
                                  ? Border.all(color: Colors.white, width: 3)
                                  : null,
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: color.withValues(alpha: 0.5),
                                        blurRadius: 8,
                                        spreadRadius: 2,
                                      )
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 32),

                    // Icons Section
                    Text(
                      'Icons',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 6,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                      ),
                      itemCount: _emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = _emojis[index];
                        final isSelected = emoji == _selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIcon = emoji),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryGold.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: isSelected
                                  ? Border.all(color: AppColors.primaryGold, width: 2)
                                  : Border.all(color: Colors.transparent, width: 2),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

