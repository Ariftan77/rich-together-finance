import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../../../shared/theme/app_theme_mode.dart';
import '../../../../shared/theme/colors.dart';
import '../../../../shared/theme/theme_provider_widget.dart';
import '../../../../shared/utils/phosphor_icon_registry.dart';
import '../../../../shared/widgets/category_icon_widget.dart';

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
    with TickerProviderStateMixin {
  late String _selectedIcon;
  late String _selectedColorHex;
  late TabController _tabController;

  // 0 = Emoji, 1 = Curated Icons, 2 = All Icons
  int _sourceMode = 0;
  String _searchQuery = '';
  final _searchController = TextEditingController();

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

  static const List<String> _colors = [
    'transparent',
    // Reds & Pinks
    '#FF6B6B', '#E74C3C', '#D35400', '#FF4757', '#FF6348',
    '#C0392B', '#E84393', '#FD79A8',
    // Oranges & Yellows
    '#FF9F1C', '#E67E22', '#F39C12', '#F1C40F', '#FFE66D',
    '#FDCB6E', '#F0932B',
    // Greens
    '#2ECC71', '#27AE60', '#16A085', '#00B894', '#00CEC9',
    '#55E6C1', '#6AB04C',
    // Blues
    '#3498DB', '#2980B9', '#0984E3', '#74B9FF', '#48DBFB',
    '#00D2D3', '#54A0FF',
    // Purples
    '#9B59B6', '#8E44AD', '#6C5CE7', '#A29BFE', '#E056A0',
    '#BE2EDD', '#4834D4',
    // Neutrals & Dark
    '#1A535C', '#34495E', '#2C3E50', '#636E72', '#95A5A6',
    '#BDC3C7', '#DFE6E9',
  ];

  Map<String, List<String>> get _activeGroups {
    if (_sourceMode == 0) return _emojiGroups;
    if (_sourceMode == 1) return phosphorCuratedGroups;
    return phosphorAlphaGroups;
  }

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.initialIcon.isEmpty ? '📦' : widget.initialIcon;
    _selectedColorHex = widget.initialColorHex.isEmpty ? 'transparent' : widget.initialColorHex;
    if (CategoryIconWidget.isPhosphorIcon(_selectedIcon)) _sourceMode = 1;
    _tabController = TabController(length: _activeGroups.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _switchSource(int mode) {
    if (_sourceMode == mode) return;
    _tabController.dispose();
    setState(() {
      _sourceMode = mode;
      _searchQuery = '';
      _searchController.clear();
      _tabController = TabController(length: _activeGroups.length, vsync: this);
    });
  }

  Color _hexToColor(String hex) {
    if (hex == 'transparent') return Colors.transparent;
    hex = hex.replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    return Color(int.parse('0x$hex'));
  }

  Color _previewIconColor() {
    if (!CategoryIconWidget.isPhosphorIcon(_selectedIcon)) return Colors.white;
    return _selectedColorHex == 'transparent' ? AppColors.primaryGold : Colors.white;
  }

  /// Convert camelCase to readable: "creditCard" -> "credit card"
  String _humanize(String name) {
    return name.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (m) => ' ${m.group(0)!.toLowerCase()}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPhosphor = _sourceMode > 0;
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.65,
      maxChildSize: 0.95,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: isLight ? const Color(0xFFF8FAFC) : const Color(0xFF2D2416),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: isLight ? Colors.black.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Title and Save
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Select Icon & Color',
                      style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, {
                        'icon': _selectedIcon,
                        'color': _selectedColorHex,
                      }),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primaryGold),
                      child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ),
              ),
              Divider(color: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white24, height: 1),

              // Preview
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _hexToColor(_selectedColorHex),
                      shape: BoxShape.circle,
                      border: _selectedColorHex == 'transparent'
                          ? Border.all(color: isLight ? Colors.black.withValues(alpha: 0.15) : Colors.white24, width: 1.5)
                          : null,
                    ),
                    child: CategoryIconWidget(
                      iconString: _selectedIcon,
                      size: 40,
                      color: _previewIconColor(),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Source toggle: Emoji / Curated / All
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _buildSourceToggle(isLight),
              ),
              const SizedBox(height: 12),

              // Colors
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Colors',
                      style: TextStyle(
                        color: isLight ? AppColors.textPrimaryLight.withValues(alpha: 0.7) : Colors.white.withValues(alpha: 0.7),
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
                          final isSelected = hex == _selectedColorHex;
                          final isTransparent = hex == 'transparent';
                          final color = _hexToColor(hex);
                          return GestureDetector(
                            onTap: () => setState(() => _selectedColorHex = hex),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isTransparent ? Colors.transparent : color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected
                                      ? (isLight ? Colors.black : Colors.white)
                                      : isTransparent ? (isLight ? Colors.black38 : Colors.white38) : Colors.transparent,
                                  width: isSelected ? 3 : 1.5,
                                ),
                                boxShadow: isSelected && !isTransparent
                                    ? [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 2)]
                                    : null,
                              ),
                              child: isTransparent ? CustomPaint(painter: _CrossPainter(isLight: isLight)) : null,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search bar (Phosphor modes only)
              if (isPhosphor) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _searchController,
                      onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
                      style: TextStyle(color: isLight ? AppColors.textPrimaryLight : Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search icons...',
                        hintStyle: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.4), fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: AppColors.primaryGold.withValues(alpha: 0.8), size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? GestureDetector(
                                onTap: () => setState(() {
                                  _searchController.clear();
                                  _searchQuery = '';
                                }),
                                child: Icon(Icons.close, color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5), size: 18),
                              )
                            : null,
                        filled: true,
                        fillColor: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06),
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppColors.primaryGold.withValues(alpha: 0.5)),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Search results or tabbed content
              if (isPhosphor && _searchQuery.isNotEmpty)
                Expanded(child: _buildSearchResults(isLight))
              else ...[
                // Tab bar
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  labelColor: AppColors.primaryGold,
                  unselectedLabelColor: isLight ? const Color(0xFF94A3B8) : Colors.white54,
                  indicatorColor: AppColors.primaryGold,
                  indicatorSize: TabBarIndicatorSize.label,
                  dividerColor: isLight ? Colors.black.withValues(alpha: 0.1) : Colors.white24,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
                  tabs: _activeGroups.keys.map((name) => Tab(text: name)).toList(),
                ),
                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: isPhosphor ? _buildPhosphorTabs(isLight) : _buildEmojiTabs(),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSourceToggle(bool isLight) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          _buildToggleItem('Emoji', _sourceMode == 0, () => _switchSource(0), isLight),
          _buildToggleItem('Curated', _sourceMode == 1, () => _switchSource(1), isLight),
          _buildToggleItem('All Icons', _sourceMode == 2, () => _switchSource(2), isLight),
        ],
      ),
    );
  }

  Widget _buildToggleItem(String label, bool isSelected, VoidCallback onTap, bool isLight) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryGold.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.primaryGold : (isLight ? const Color(0xFF94A3B8) : Colors.white54),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isLight) {
    final results = phosphorIconMap.keys
        .where((name) => _humanize(name).contains(_searchQuery) || name.toLowerCase().contains(_searchQuery))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Text(
          'No icons found for "$_searchQuery"',
          style: TextStyle(color: isLight ? const Color(0xFF94A3B8) : Colors.white.withValues(alpha: 0.5)),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
      ),
      itemCount: results.length,
      itemBuilder: (context, index) {
        final name = results[index];
        return _buildPhosphorIconCell(name, isLight);
      },
    );
  }

  List<Widget> _buildEmojiTabs() {
    final themeMode = AppThemeProvider.of(context);
    final isLight = themeMode == AppThemeMode.light ||
        (themeMode == AppThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.light);
    return _emojiGroups.values.map((emojis) {
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
                    : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? AppColors.primaryGold : (isLight ? Colors.black.withValues(alpha: 0.06) : Colors.transparent),
                  width: 2,
                ),
              ),
              alignment: Alignment.center,
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      );
    }).toList();
  }

  List<Widget> _buildPhosphorTabs(bool isLight) {
    return _activeGroups.values.map((iconNames) {
      return GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 7,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
        ),
        itemCount: iconNames.length,
        itemBuilder: (context, index) => _buildPhosphorIconCell(iconNames[index], isLight),
      );
    }).toList();
  }

  Widget _buildPhosphorIconCell(String name, bool isLight) {
    final dbKey = 'ph:$name';
    final isSelected = dbKey == _selectedIcon;
    final iconData = phosphorIconMap[name] ?? PhosphorIconsFill.question;
    return GestureDetector(
      onTap: () => setState(() => _selectedIcon = dbKey),
      child: Container(
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryGold.withValues(alpha: 0.2)
              : (isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primaryGold : (isLight ? Colors.black.withValues(alpha: 0.06) : Colors.transparent),
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: PhosphorIcon(
          iconData,
          size: 22,
          color: isSelected ? AppColors.primaryGold : (isLight ? const Color(0xFF64748B) : Colors.white70),
        ),
      ),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final bool isLight;
  const _CrossPainter({this.isLight = false});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = isLight ? Colors.black38 : Colors.white38
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final inset = size.width * 0.25;
    canvas.drawLine(Offset(inset, inset), Offset(size.width - inset, size.height - inset), paint);
    canvas.drawLine(Offset(size.width - inset, inset), Offset(inset, size.height - inset), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
