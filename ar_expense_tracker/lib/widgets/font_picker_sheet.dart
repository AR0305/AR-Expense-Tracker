import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/theme_provider.dart';
import '../utils/font_utils.dart';
import '../utils/haptics.dart';

class FontPickerSheet extends ConsumerStatefulWidget {
  final bool initialIsTitleFont;

  const FontPickerSheet({
    super.key,
    required this.initialIsTitleFont,
  });

  @override
  ConsumerState<FontPickerSheet> createState() => _FontPickerSheetState();
}

class _FontPickerSheetState extends ConsumerState<FontPickerSheet> {
  late bool _isTitleFont;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _searchQuery = '';

  final List<String> _categories = [
    'All',
    'Handwritten',
    'Sans-Serif',
    'Serif',
    'Display',
    'System',
  ];

  @override
  void initState() {
    super.initState();
    _isTitleFont = widget.initialIsTitleFont;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentTitleFont = ref.watch(titleFontProvider);
    final currentBodyFont = ref.watch(bodyFontProvider);
    final activeSelectedFont = _isTitleFont ? currentTitleFont : currentBodyFont;

    final filteredFonts = FontUtils.availableFonts.where((font) {
      final matchesSearch = font.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          font.category.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' || font.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    final colorScheme = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 12),
            // Sheet Drag Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header Title & Close Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Row(
                children: [
                  Icon(
                    _isTitleFont ? Icons.title_rounded : Icons.text_fields_rounded,
                    color: colorScheme.primary,
                    size: 26,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _isTitleFont ? 'Customize Title Font' : 'Customize Body Font',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Title vs Body Segmented Selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment<bool>(
                    value: true,
                    label: Text(
                      'Title Font',
                      style: TextStyle(
                        fontWeight: _isTitleFont ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    icon: const Icon(Icons.title_rounded, size: 18),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    label: Text(
                      'Body Font',
                      style: TextStyle(
                        fontWeight: !_isTitleFont ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    icon: const Icon(Icons.text_fields_rounded, size: 18),
                  ),
                ],
                selected: {_isTitleFont},
                onSelectionChanged: (Set<bool> newSelection) {
                  Haptics.selectionClick();
                  setState(() {
                    _isTitleFont = newSelection.first;
                  });
                },
                style: ButtonStyle(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Quick Preset Action Chips
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Presets',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: (currentTitleFont == FontUtils.defaultTitleFont &&
                                      currentBodyFont == FontUtils.defaultBodyFont)
                                  ? colorScheme.primary
                                  : colorScheme.outline.withAlpha(100),
                              width: (currentTitleFont == FontUtils.defaultTitleFont &&
                                      currentBodyFont == FontUtils.defaultBodyFont)
                                  ? 2
                                  : 1,
                            ),
                          ),
                          onPressed: () {
                            Haptics.selectionClick();
                            ref.read(titleFontProvider.notifier).setFont(FontUtils.defaultTitleFont);
                            ref.read(bodyFontProvider.notifier).setFont(FontUtils.defaultBodyFont);
                          },
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: (currentTitleFont == FontUtils.defaultTitleFont &&
                                      currentBodyFont == FontUtils.defaultBodyFont)
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: (currentTitleFont == FontUtils.robotoFont &&
                                      currentBodyFont == FontUtils.robotoFont)
                                  ? colorScheme.primary
                                  : colorScheme.outline.withAlpha(100),
                              width: (currentTitleFont == FontUtils.robotoFont &&
                                      currentBodyFont == FontUtils.robotoFont)
                                  ? 2
                                  : 1,
                            ),
                          ),
                          onPressed: () {
                            Haptics.selectionClick();
                            ref.read(titleFontProvider.notifier).setFont(FontUtils.robotoFont);
                            ref.read(bodyFontProvider.notifier).setFont(FontUtils.robotoFont);
                          },
                          child: Text(
                            'Roboto',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: (currentTitleFont == FontUtils.robotoFont &&
                                      currentBodyFont == FontUtils.robotoFont)
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            side: BorderSide(
                              color: (currentTitleFont == 'Outfit' && currentBodyFont == 'Inter')
                                  ? colorScheme.primary
                                  : colorScheme.outline.withAlpha(100),
                              width: (currentTitleFont == 'Outfit' && currentBodyFont == 'Inter')
                                  ? 2
                                  : 1,
                            ),
                          ),
                          onPressed: () {
                            Haptics.selectionClick();
                            ref.read(titleFontProvider.notifier).setFont('Outfit');
                            ref.read(bodyFontProvider.notifier).setFont('Inter');
                          },
                          child: Text(
                            'Modern',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: (currentTitleFont == 'Outfit' && currentBodyFont == 'Inter')
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Live Interactive Sample Preview Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withAlpha(120),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(60),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'LIVE PREVIEW',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: colorScheme.primary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _isTitleFont ? 'Title: $currentTitleFont' : 'Body: $currentBodyFont',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Expense Summary',
                      style: FontUtils.getFontTextStyle(
                        currentTitleFont,
                        TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Total spend: ₹ 4,850 • 12 Transactions this month',
                      style: FontUtils.getFontTextStyle(
                        currentBodyFont,
                        TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: TextField(
                controller: _searchController,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Search fonts...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest.withAlpha(80),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Category Filter Chips
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        Haptics.selectionClick();
                        setState(() {
                          _selectedCategory = cat;
                        });
                      }
                    },
                    selectedColor: colorScheme.primaryContainer,
                    labelStyle: TextStyle(
                      color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 13,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Font List
            Expanded(
              child: filteredFonts.isEmpty
                  ? Center(
                      child: Text(
                        'No fonts matching "$_searchQuery"',
                        style: TextStyle(color: colorScheme.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: filteredFonts.length,
                      itemBuilder: (context, index) {
                        final font = filteredFonts[index];
                        final isSelected = font.name == activeSelectedFont;

                        return Card(
                          elevation: 0,
                          color: isSelected
                              ? colorScheme.primaryContainer.withAlpha(140)
                              : colorScheme.surfaceContainerHighest.withAlpha(60),
                          margin: const EdgeInsets.only(bottom: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: isSelected
                                ? BorderSide(color: colorScheme.primary, width: 1.5)
                                : BorderSide.none,
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            title: Text(
                              font.displayName,
                              style: FontUtils.getFontTextStyle(
                                font.name,
                                TextStyle(
                                  fontSize: _isTitleFont ? 20 : 16,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                            subtitle: Text(
                              'Category: ${font.category}',
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: isSelected
                                ? Icon(Icons.check_circle_rounded, color: colorScheme.primary)
                                : null,
                            onTap: () {
                              Haptics.selectionClick();
                              if (_isTitleFont) {
                                ref.read(titleFontProvider.notifier).setFont(font.name);
                              } else {
                                ref.read(bodyFontProvider.notifier).setFont(font.name);
                              }
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
