import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/custom_category_provider.dart';
import '../database/expense_database.dart';
import '../utils/category_utils.dart';

class CreateCategorySheet extends ConsumerStatefulWidget {
  final ExpenseGroup group;

  const CreateCategorySheet({super.key, required this.group});

  @override
  ConsumerState<CreateCategorySheet> createState() => _CreateCategorySheetState();
}

class _CreateCategorySheetState extends ConsumerState<CreateCategorySheet> {
  final _nameController = TextEditingController();
  final _emojiController = TextEditingController(text: '🍔');
  
  Color _selectedColor = Colors.red.shade600;

  final List<Color> _presetColors = [
    Colors.red.shade600,
    Colors.green.shade600,
    Colors.blue.shade600,
    Colors.purple.shade600,
    Colors.orange.shade600,
  ];

  void _showFullColorPicker() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Pick a Color'),
        content: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: Colors.primaries.map((color) {
            return InkWell(
              onTap: () {
                setState(() {
                  _selectedColor = color.shade600;
                });
                Navigator.pop(ctx);
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.shade600,
                  shape: BoxShape.circle,
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _save() {
    final name = _nameController.text.trim();
    final emoji = _emojiController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a name')));
      return;
    }
    
    if (emoji.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter an emoji')));
      return;
    }

    // Check if category already exists in default categories
    final isDefault = CategoryUtils.defaultCategories.any(
      (c) => (c['name'] as String).toLowerCase() == name.toLowerCase(),
    );
    if (isDefault) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('"$name" is already a default category')),
      );
      return;
    }

    // Check if category already exists in custom categories
    final existingCustom = ref.read(customCategoryProvider(widget.group));
    if (existingCustom.any((c) => c.name.toLowerCase() == name.toLowerCase())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Category "$name" already exists')),
      );
      return;
    }
    
    ref.read(customCategoryProvider(widget.group).notifier).addCategory(
      name, 
      emoji, 
      // ignore: deprecated_member_use
      _selectedColor.value,
    );
    
    Navigator.pop(context, name);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24, left: 24, right: 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Create Custom Category',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                SizedBox(
                  width: 60,
                  child: TextField(
                    controller: _emojiController,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 24),
                    inputFormatters: [
                      TextInputFormatter.withFunction((oldValue, newValue) {
                        if (newValue.text.isEmpty) return newValue;
                        // Limit to 2 grapheme clusters (allows 2 letters or 2 emojis)
                        // Also, if someone types an emoji, we want to restrict it to just 1 emoji if it's an emoji, 
                        // but a simple 2-character limit is usually enough for "2 letters or 1 emoji" visually.
                        final hasEmoji = newValue.text.runes.any((r) => r > 127);
                        final maxLen = hasEmoji ? 1 : 2;
                        
                        if (newValue.text.characters.length > maxLen) {
                          return oldValue;
                        }
                        return newValue;
                      }),
                    ],
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Category Name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Color',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ..._presetColors.map((c) {
                  // ignore: deprecated_member_use
                  final isSelected = c.value == _selectedColor.value;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = c),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
                      ),
                      child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                    ),
                  );
                }),
                // Rainbow color picker
                GestureDetector(
                  onTap: _showFullColorPicker,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: SweepGradient(
                        colors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                          Colors.indigo,
                          Colors.purple,
                          Colors.red,
                        ],
                      ),
                    ),
                    child: const Icon(Icons.colorize_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              child: const Text('Save Category'),
            ),
          ],
        ),
      ),
    );
  }
}
