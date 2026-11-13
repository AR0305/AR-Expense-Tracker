import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../database/expense_database.dart';
import '../providers/custom_category_provider.dart';
import '../utils/category_utils.dart';
import '../utils/haptics.dart';
import '../screens/add_expense_screen.dart';
import 'dynamic_icon_bg.dart';

class ExpandableExpenseCard extends ConsumerStatefulWidget {
  final Expense expense;
  final ExpenseGroup group;
  final double dailyTotal;

  const ExpandableExpenseCard({
    super.key,
    required this.expense,
    required this.group,
    required this.dailyTotal,
  });

  @override
  ConsumerState<ExpandableExpenseCard> createState() => _ExpandableExpenseCardState();
}

class _ExpandableExpenseCardState extends ConsumerState<ExpandableExpenseCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoryProvider(widget.group));
    final categoryColor = CategoryUtils.getColor(widget.expense.category, customCategories);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      margin: const EdgeInsets.only(bottom: 6),
      decoration: ShapeDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLowest,
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(48),
          side: BorderSide(
            color: _isExpanded
                ? Theme.of(context).colorScheme.primary.withAlpha(100)
                : Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.all(Radius.circular(24)),
        child: Column(
          children: [
            InkWell(
              borderRadius: const BorderRadius.all(Radius.circular(24)),
              splashColor: Theme.of(context).colorScheme.primary.withAlpha(20),
              highlightColor: Colors.transparent,
              onTap: () {
                Haptics.lightImpact();
                setState(() {
                  _isExpanded = !_isExpanded;
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Row(
                  children: [
                    // Icon
                    DynamicIconBg(
                      width: 48,
                      height: 48,
                      padding: 0,
                      alignment: Alignment.center,
                      color: categoryColor.withAlpha(25),
                      child: CategoryUtils.getIconWidget(
                        widget.expense.category,
                        customCategories,
                        size: 22,
                        color: categoryColor,
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Text Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.expense.title != null && widget.expense.title!.isNotEmpty
                                ? widget.expense.title!
                                : widget.expense.category,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              if (widget.expense.isRecurring || widget.expense.recurrencePeriod != null)
                                Padding(
                                  padding: const EdgeInsets.only(right: 6.0),
                                  child: Icon(
                                    Icons.autorenew_rounded,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  widget.expense.note != null && widget.expense.note!.isNotEmpty
                                      ? '${widget.expense.category} • ${widget.expense.note!}'
                                      : widget.expense.category,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (widget.expense.imagePaths != null && widget.expense.imagePaths!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.attach_file_rounded,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.expense.imagePaths!.length} photo(s)',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (widget.expense.subExpenses != null && widget.expense.subExpenses!.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.receipt_long_rounded,
                                    size: 14,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${widget.expense.subExpenses!.fold<int>(0, (sum, item) => sum + item.quantity)} items',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Amount & Arrow
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          NumberFormat.currency(symbol: '₹ ').format(widget.expense.amount),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        AnimatedRotation(
                          turns: _isExpanded ? 0.5 : 0.0,
                          duration: const Duration(milliseconds: 300),
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(150),
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // Expanded Content (Preview)
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 16),
                    if (widget.expense.subExpenses != null && widget.expense.subExpenses!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Items',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(100),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: widget.expense.subExpenses!.map((sub) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${sub.quantity}x ${sub.name}',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  Text(
                                    NumberFormat.currency(symbol: '₹').format(sub.amount),
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (widget.expense.note != null && widget.expense.note!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Note',
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          widget.expense.note!,
                          style: TextStyle(
                            fontSize: 13,
                            color: Theme.of(context).colorScheme.onSurface,
                            height: 1.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (widget.expense.imagePaths != null && widget.expense.imagePaths!.isNotEmpty) ...[
                      Builder(
                        builder: (context) {
                          final validImages = widget.expense.imagePaths!
                              .map((p) => File(p))
                              .where((f) => f.existsSync())
                              .toList();
                          if (validImages.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Receipts & Attachments',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 72,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: validImages.length,
                                  separatorBuilder: (context, index) => const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final file = validImages[index];
                                    return ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: InkWell(
                                        onTap: () {
                                          Haptics.lightImpact();
                                          showDialog(
                                            context: context,
                                            builder: (ctx) => Dialog(
                                              backgroundColor: Colors.transparent,
                                              insetPadding: EdgeInsets.zero,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  GestureDetector(
                                                    onTap: () => Navigator.pop(ctx),
                                                    child: Container(color: Colors.black87),
                                                  ),
                                                  InteractiveViewer(
                                                    panEnabled: true,
                                                    minScale: 0.5,
                                                    maxScale: 4.0,
                                                    child: Image.file(file, fit: BoxFit.contain),
                                                  ),
                                                  Positioned(
                                                    top: 40,
                                                    right: 20,
                                                    child: IconButton(
                                                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                                                      onPressed: () => Navigator.pop(ctx),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                        child: Image.file(
                                          file,
                                          width: 72,
                                          height: 72,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Container(
                                            width: 72,
                                            height: 72,
                                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                            child: const Icon(Icons.broken_image_rounded),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                            ],
                          );
                        },
                      ),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Haptics.lightImpact();
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (ctx) => AddExpenseScreen(
                              group: widget.group,
                              existingExpense: widget.expense,
                            ),
                          );
                        },
                        icon: const Icon(Icons.edit_rounded, size: 18),
                        label: const Text('Edit Expense'),
                      ),
                    ),
                  ],
                ),
              ),
              crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),
          ],
        ),
      ),
    );
  }
}
