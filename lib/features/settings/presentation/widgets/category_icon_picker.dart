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

class _CategoryIconPickerState extends State<CategoryIconPicker>
    with SingleTickerProviderStateMixin {
  late String _selectedIcon;
  late String _selectedColorHex;
  late TabController _tabController;

  // Curated emojis grouped by category
  static const Map<String, List<String>> _emojiGroups = {
    'Food & Drink': [
      '🍔', '🍕', '🍜', '🍣', '🍱', '🥗', '🌮', '🥪', '🍗', '🥐',
      '🍎', '🍹', '☕', '🧋', '🍺', '🥂', '🍰', '🧁', '🍦', '🍿',
    ],
    'Transport': [
      '🚗', '🚌', '🚂', '✈️', '🚲', '🛵', '🚕', '⛽', '🚁', '🚢',
      '🏍️', '🛻', '🚐', '🚜', '🛞', '🛺',
    ],
    'Shopping': [
      '🛒', '🛍️', '👗', '👟', '👔', '👜', '💎', '🎁', '🧥', '👒',
      '👞', '🎀', '👘', '🕶️',
    ],
    'Home': [
      '🏠', '🛋️', '🛏️', '🪴', '🧹', '🧺', '🔧', '🛠️', '💡', '🔌',
      '🚿', '🧼', '🏡', '🪑', '🧯', '🪣',
    ],
    'Health & Fitness': [
      '🏥', '💊', '🩺', '🩻', '🏋️', '🧘', '🏃', '🚴', '🩹', '🦷',
      '👁️', '💆', '🥦', '🧬',
    ],
    'Entertainment': [
      '🎮', '🎬', '🎵', '🎸', '🎨', '🎭', '🎯', '🎲', '🎟️', '🎤',
      '🎪', '🎡', '🎻', '🥁',
    ],
    'Finance': [
      '💰', '💳', '🏦', '📈', '📉', '💵', '💸', '🪙', '🏧', '💹',
      '🧾', '📊',
    ],
    'Education': [
      '🎓', '📚', '📖', '✏️', '📝', '🔬', '🔭', '📐', '📏', '🗓️',
      '🖊️', '🏫',
    ],
    'Technology': [
      '📱', '💻', '🖥️', '⌨️', '📶', '🔋', '📡', '🎧', '📷', '🎥',
      '🖱️', '🖨️',
    ],
    'Pets & Nature': [
      '🐶', '🐈', '🐠', '🐹', '🐇', '🐾', '🌿', '🌸', '🌳', '🦮',
      '🌻', '🍀',
    ],
    'Business': [
      '🏢', '💼', '📋', '📌', '📎', '🗂️', '📁', '✅', '🤝', '📣',
      '🏗️', '🖇️',
    ],
    'Other': [
      '📦', '🎉', '🌍', '🏖️', '⚙️', '🔑', '🧩', '🎂', '🚀', '⭐',
      '🎃', '🛎️', '🧸', '🪆',
    ],
  };

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
    _tabController = TabController(length: _emojiGroups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
      initialChildSize: 0.85,
      minChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (context, _) {
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

              // Title and Save Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select Icon & Color',
                      style: TextStyle(
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
                      child: const Text(
                        'Save',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white24, height: 1),

              // Preview
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Center(
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
              ),
              const SizedBox(height: 16),

              // Colors — horizontal scrollable row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colors',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 44,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _colors.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
                        itemBuilder: (context, index) {
                          final hex = _colors[index];
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
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tab bar — one tab per emoji group
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelColor: AppColors.primaryGold,
                unselectedLabelColor: Colors.white54,
                indicatorColor: AppColors.primaryGold,
                indicatorSize: TabBarIndicatorSize.label,
                dividerColor: Colors.white24,
                labelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                tabs: _emojiGroups.keys
                    .map((name) => Tab(text: name))
                    .toList(),
              ),

              // Tab content — emoji grid per group
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: _emojiGroups.values.map((emojis) {
                    return GridView.builder(
                      padding: const EdgeInsets.all(16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                      ),
                      itemCount: emojis.length,
                      itemBuilder: (context, index) {
                        final emoji = emojis[index];
                        final isSelected = emoji == _selectedIcon;
                        return GestureDetector(
                          onTap: () => setState(() => _selectedIcon = emoji),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primaryGold.withValues(alpha: 0.2)
                                  : Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primaryGold
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              emoji,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
