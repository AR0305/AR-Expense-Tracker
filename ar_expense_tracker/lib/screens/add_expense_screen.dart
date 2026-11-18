import '../utils/haptics.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:loading_indicator_m3e/loading_indicator_m3e.dart';
import '../database/expense_database.dart';
import '../providers/expense_provider.dart';
import '../providers/custom_category_provider.dart';
import '../widgets/category_picker_sheet.dart';
import '../utils/category_utils.dart';
import '../utils/receipt_parser.dart';
import '../widgets/micro_interactions.dart';
import 'home_screen.dart';

class AddExpenseScreen extends ConsumerStatefulWidget {
  final ExpenseGroup group;
  final Expense? existingExpense;
  final String? prefilledImagePath;
  final double? initialAmount;
  final String? initialTitle;
  final String? initialCategory;
  final String? initialNote;

  const AddExpenseScreen({
    super.key,
    required this.group,
    this.existingExpense,
    this.prefilledImagePath,
    this.initialAmount,
    this.initialTitle,
    this.initialCategory,
    this.initialNote,
  });

  @override
  ConsumerState<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class SubExpenseItemState {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  int quantity;
  SubExpenseItemState(this.nameCtrl, this.amountCtrl, {this.quantity = 1});
  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _AddExpenseScreenState extends ConsumerState<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  String? _selectedCategory;
  bool _showCategoryWarning = false;
  bool _showAmountWarning = false;
  
  final List<File> _selectedImages = [];
  bool _isSaving = false;
  
  // Recurring state
  bool _isRecurring = false;
  bool _omitFromAvg = false;
  String _recurrencePeriod = 'Monthly';
  final List<String> _periods = ['Daily', 'Weekly', 'Monthly', 'Quarterly', 'Yearly'];

  // Sub Expenses state
  bool _hasSubExpenses = false;
  final List<SubExpenseItemState> _subExpenses = [];

  void _calculateTotalFromSubExpenses() {
    if (!_hasSubExpenses) return;
    double total = 0;
    for (var item in _subExpenses) {
      final val = double.tryParse(item.amountCtrl.text) ?? 0;
      total += val * item.quantity;
    }
    _amountController.text = total > 0 ? total.toStringAsFixed(total.truncateToDouble() == total ? 0 : 2) : '';
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingExpense != null) {
      final exp = widget.existingExpense!;
      _titleController.text = exp.title ?? '';
      _amountController.text = exp.amount.toString();
      _noteController.text = exp.note ?? '';
      _selectedDate = exp.date;
      
      // Category is just a string name
      _selectedCategory = exp.category;
      
      if (exp.imagePaths != null) {
        for (String path in exp.imagePaths!) {
          if (File(path).existsSync()) {
            _selectedImages.add(File(path));
          }
        }
      }
      
      _isRecurring = exp.isRecurring;
      _omitFromAvg = exp.omitFromAvg;
      _recurrencePeriod = exp.recurrencePeriod ?? 'Monthly';
      
      if (exp.subExpenses != null && exp.subExpenses!.isNotEmpty) {
        _hasSubExpenses = true;
        for (var sub in exp.subExpenses!) {
          final item = SubExpenseItemState(
            TextEditingController(text: sub.name),
            TextEditingController(text: sub.amount.toString()),
            quantity: sub.quantity,
          );
          item.amountCtrl.addListener(_calculateTotalFromSubExpenses);
          _subExpenses.add(item);
        }
      }
    } else {
      if (widget.initialAmount != null && widget.initialAmount! > 0) {
        final amt = widget.initialAmount!;
        _amountController.text = amt % 1 == 0 ? amt.toInt().toString() : amt.toStringAsFixed(2);
      }
      if (widget.initialTitle != null && widget.initialTitle!.isNotEmpty) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
        _selectedCategory = widget.initialCategory;
      }
      if (widget.initialNote != null && widget.initialNote!.isNotEmpty) {
        _noteController.text = widget.initialNote!;
      }
    }

    if (widget.prefilledImagePath != null && widget.existingExpense == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _processReceiptImage(widget.prefilledImagePath!);
      });
    }
  }

  DateTime _addMonthsSafe(DateTime date, int monthsToAdd) {
    final newYear = date.year + ((date.month - 1 + monthsToAdd) ~/ 12);
    final newMonth = ((date.month - 1 + monthsToAdd) % 12) + 1;
    final maxDays = DateTime(newYear, newMonth + 1, 0).day;
    final newDay = date.day > maxDays ? maxDays : date.day;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute, date.second);
  }

  DateTime _calculateNextDate(DateTime current, String period) {
    switch (period) {
      case 'Daily': return current.add(const Duration(days: 1));
      case 'Weekly': return current.add(const Duration(days: 7));
      case 'Monthly': return _addMonthsSafe(current, 1);
      case 'Quarterly': return _addMonthsSafe(current, 3);
      case 'Yearly': return _addMonthsSafe(current, 12);
      default: return current.add(const Duration(days: 30));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    for (var item in _subExpenses) {
      item.dispose();
    }
    super.dispose();
  }

  void _presentDatePicker() async {
    final firstDate = DateTime(2000);
    Haptics.lightImpact();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: firstDate,
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 70);
    
    if (pickedFile != null) {
      setState(() {
        _selectedImages.add(File(pickedFile.path));
      });
    }
  }

  void _showCategoryPicker() {
    CategoryPickerSheet.show(
      context,
      group: widget.group,
      selectedCategory: _selectedCategory,
      onCategorySelected: (cat) {
        setState(() {
          _selectedCategory = cat;
          _showCategoryWarning = false;
        });
      },
    );
  }

  Future<List<String>> _saveImagesLocally() async {
    List<String> savedPaths = [];
    if (_selectedImages.isEmpty) return savedPaths;

    final appDir = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${appDir.path}/expense_images');
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    for (var imageFile in _selectedImages) {
      if (imageFile.path.startsWith(imagesDir.path)) {
        savedPaths.add(imageFile.path);
      } else {
        final fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(imageFile.path)}';
        final savedImage = await imageFile.copy('${imagesDir.path}/$fileName');
        savedPaths.add(savedImage.path);
      }
    }

    return savedPaths;
  }

  Future<void> _scanReceipt() async {
    final picker = ImagePicker();
    final pickedFile = await showDialog<XFile?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Scan Receipt'),
        content: const Text('Choose image source:'),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.photo_library),
            label: const Text('Gallery'),
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.gallery);
              if (ctx.mounted) Navigator.pop(ctx, img);
            }
          ),
          TextButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Camera'),
            onPressed: () async {
              final img = await picker.pickImage(source: ImageSource.camera);
              if (ctx.mounted) Navigator.pop(ctx, img);
            }
          ),
        ],
      ),
    );
    
    if (pickedFile == null) return;
    await _processReceiptImage(pickedFile.path);
  }

  Future<void> _processReceiptImage(String path) async {
    setState(() {
      _isSaving = true;
      if (!_selectedImages.any((f) => f.path == path)) {
        _selectedImages.add(File(path));
      }
    });

    try {
      final customCategories = ref.read(customCategoryProvider(widget.group));
      final availableCats = [
        ...CategoryUtils.defaultCategories.map((c) => c['name'] as String),
        ...customCategories.map((c) => c.name)
      ];

      final data = await ReceiptParser.parseReceipt(path, availableCats);
      
      if (mounted) {
        // --- DEBUG DIALOG ---
        final debugText =
            'Path: $path\n\n'
            'Amount: ${data.amount}\n'
            'Store: ${data.storeName}\n'
            'Category: ${data.suggestedCategory}\n'
            'SubExpenses: ${data.subExpenses.length}\n'
            '${data.subExpenses}\n\n'
            '--- RAW OCR (block/line structure) ---\n'
            '${data.rawText}';

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('OCR Debug Info'),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: SelectableText(debugText),
              ),
            ),
            actions: [
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: debugText));
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      const SnackBar(content: Text('Copied to clipboard')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
                label: const Text('Copy'),
              ),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
            ],
          )
        );
      }

      setState(() {
        if (data.amount != null && (_amountController.text.isEmpty || _amountController.text == '0')) {
          _amountController.text = data.amount.toString();
        }
        
        if (data.storeName != null && _titleController.text.isEmpty) {
          if (widget.prefilledImagePath != null) {
            _titleController.text = 'Paid to: ${data.storeName!}';
          } else {
            _titleController.text = data.storeName!;
          }
        }
        
        if (data.suggestedCategory != null && _selectedCategory == null) {
          _selectedCategory = data.suggestedCategory;
        }
        
        if (data.subExpenses.isNotEmpty && _subExpenses.isEmpty) {
          _hasSubExpenses = true;
          for (final sub in data.subExpenses) {
            final item = SubExpenseItemState(
              TextEditingController(text: sub['title'] as String),
              TextEditingController(text: (sub['amount'] as double).toString()),
              quantity: (sub['quantity'] as int?) ?? 1,
            );
            item.amountCtrl.addListener(_calculateTotalFromSubExpenses);
            _subExpenses.add(item);
          }
          if (_amountController.text.isEmpty || _amountController.text == '0') {
            _calculateTotalFromSubExpenses();
          }
        }
      });
      
      if (mounted) {
        Haptics.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Receipt scanned and fields auto-filled!')),
        );
      }
    } catch (_) {
      if (mounted) {
        Haptics.lightImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Could not parse receipt details automatically. You can enter them manually.'),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _processReceiptImage(path),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _saveExpense() async {
    Haptics.lightImpact();
    
    bool isValid = true;
    
    final amountVal = double.tryParse(_amountController.text);
    if (amountVal == null || amountVal <= 0) {
      setState(() => _showAmountWarning = true);
      isValid = false;
    } else {
      setState(() => _showAmountWarning = false);
    }
    
    if (_selectedCategory == null) {
      setState(() => _showCategoryWarning = true);
      isValid = false;
    } else {
      setState(() => _showCategoryWarning = false);
    }

    if (!isValid) {
      Haptics.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }
    
    if (_formKey.currentState!.validate()) {

      final enteredAmount = double.parse(_amountController.text);
      final finalCategory = _selectedCategory!;

      bool isLockedToMonth = widget.group.isMonthlyBudget;
      if (!isLockedToMonth) {
        // Fallback for older groups that were created before the explicit toggle existed
        try {
          DateFormat('MMMM yyyy').parseStrict(widget.group.name);
          isLockedToMonth = true;
        } catch (_) {}
      }

      if (isLockedToMonth) {
        if (_selectedDate.month != widget.group.createdAt.month || 
            _selectedDate.year != widget.group.createdAt.year) {
            
          final confirm = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final expenseMonth = DateFormat('MMMM yyyy').format(_selectedDate);
              final groupMonth = DateFormat('MMMM yyyy').format(widget.group.createdAt);
              return AlertDialog(
                title: const Text('Create New Book?'),
                content: Text('This expense is for $expenseMonth, but this book is restricted to $groupMonth.\n\nDo you want to automatically create a new book for $expenseMonth and save this expense there?'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep it here')),
                  FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Create & Move')),
                ],
              );
            }
          );

          if (confirm == true) {
            setState(() => _isSaving = true);
            final savedImagePaths = await _saveImagesLocally();
            final finalSubExpenses = _hasSubExpenses ? _subExpenses
                .where((e) => e.nameCtrl.text.trim().isNotEmpty && (double.tryParse(e.amountCtrl.text) ?? 0) > 0)
                .map((e) => SubExpense(
                  name: e.nameCtrl.text.trim(), 
                  amount: double.tryParse(e.amountCtrl.text) ?? 0,
                  quantity: e.quantity,
                ))
                .toList() : null;

            final targetGroupName = DateFormat('MMMM yyyy').format(_selectedDate);
            final existingGroups = ref.read(groupProvider);
            ExpenseGroup? targetGroup;
            for (var g in existingGroups) {
              if (g.name == targetGroupName) {
                targetGroup = g;
                break;
              }
            }
            
            targetGroup ??= await ref.read(groupProvider.notifier).addGroup(
              targetGroupName,
              widget.group.icon,
              monthlyBudget: widget.group.monthlyBudget,
              isMonthlyBudget: true,
              createdAt: _selectedDate,
            );

            await ref.read(expenseProvider(targetGroup).notifier).addExpense(
              title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
              amount: enteredAmount,
              date: _selectedDate,
              category: finalCategory,
              note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
              imagePaths: savedImagePaths,
              isRecurring: _isRecurring,
              recurrencePeriod: _isRecurring ? _recurrencePeriod : null,
              nextRecurringDate: _isRecurring ? _calculateNextDate(_selectedDate, _recurrencePeriod) : null,
              subExpenses: finalSubExpenses,
              omitFromAvg: _omitFromAvg,
            );

            if (mounted) {
              Navigator.pop(context, true); // Close AddExpenseScreen (true = saved)
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => HomeScreen(group: targetGroup!))
              );
            }
            return;
          }
        }
      }

      setState(() {
        _isSaving = true;
      });

      // Save images first
      final savedImagePaths = await _saveImagesLocally();

      List<SubExpense>? finalSubExpenses;
      if (_hasSubExpenses) {
        finalSubExpenses = <SubExpense>[];
        for (final item in _subExpenses) {
          final name = item.nameCtrl.text.trim();
          final amount = double.tryParse(item.amountCtrl.text) ?? 0;
          if (name.isNotEmpty && amount > 0) {
            finalSubExpenses.add(SubExpense(name: name, amount: amount, quantity: item.quantity));
          }
        }
      }

      if (widget.existingExpense != null) {
        await ref.read(expenseProvider(widget.group).notifier).updateExpense(
          id: widget.existingExpense!.id,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          amount: enteredAmount,
          date: _selectedDate,
          category: finalCategory,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          imagePaths: savedImagePaths,
          isRecurring: _isRecurring,
          recurrencePeriod: _isRecurring ? _recurrencePeriod : null,
          nextRecurringDate: _isRecurring ? _calculateNextDate(_selectedDate, _recurrencePeriod) : null,
          subExpenses: finalSubExpenses,
          omitFromAvg: _omitFromAvg,
        );
      } else {
        await ref.read(expenseProvider(widget.group).notifier).addExpense(
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          amount: enteredAmount,
          date: _selectedDate,
          category: finalCategory,
          note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
          imagePaths: savedImagePaths,
          isRecurring: _isRecurring,
          recurrencePeriod: _isRecurring ? _recurrencePeriod : null,
          nextRecurringDate: _isRecurring ? _calculateNextDate(_selectedDate, _recurrencePeriod) : null,
          subExpenses: finalSubExpenses,
          omitFromAvg: _omitFromAvg,
        );
      }
      
      if (mounted) {
        Navigator.pop(context, true); // true = saved
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final customCategories = ref.watch(customCategoryProvider(widget.group));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    
    bool isLockedToMonth = widget.group.isMonthlyBudget;
    if (!isLockedToMonth) {
      try {
        DateFormat('MMMM yyyy').parseStrict(widget.group.name);
        isLockedToMonth = true;
      } catch (_) {}
    }
    
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withAlpha(50),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (true)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Cancel',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        if (widget.existingExpense == null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.document_scanner_rounded),
                                tooltip: 'Scan Receipt with OCR',
                                onPressed: () {
                                  Haptics.lightImpact();
                                  _scanReceipt();
                                },
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.tertiaryContainer,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'EXPERIMENTAL',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (widget.existingExpense == null)
                      const SizedBox()
                    else
                      const SizedBox(),


                  ],
                ),
              const SizedBox(height: 16),
              
              // Giant Amount Input
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(64),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '₹',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w600,
                            color: _showAmountWarning 
                                ? Theme.of(context).colorScheme.error 
                                : Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IntrinsicWidth(
                          child: TextFormField(
                            controller: _amountController,
                            readOnly: _hasSubExpenses,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 72,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -2,
                              color: _showAmountWarning 
                                  ? Theme.of(context).colorScheme.error 
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: TextStyle(
                                color: _showAmountWarning 
                                    ? Theme.of(context).colorScheme.error.withAlpha(100)
                                    : Theme.of(context).colorScheme.onSurface.withAlpha(50),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            onChanged: (val) {
                              setState(() {
                                if (_showAmountWarning && val.isNotEmpty) {
                                  _showAmountWarning = false;
                                }
                              });
                            },
                            validator: (value) => null, // Validation done manually
                          ),
                        ),
                      ],
                    ),
                    if (_showAmountWarning && _amountController.text.isEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 16),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'REQUIRED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onErrorContainer,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ).animate().fadeIn(duration: 200.ms).scale(duration: 200.ms),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),

              // Title Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.title_rounded, 
                      color: Theme.of(context).colorScheme.primary.withAlpha(200)
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _titleController,
                        readOnly: false,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                        decoration: InputDecoration(
                          hintText: 'Expense Title (Optional)',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface.withAlpha(100)
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Note Input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
                      width: 1.0,
                    ),
                  ),
                ),
                child: TextFormField(
                  controller: _noteController,
                  readOnly: false,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'What was this for? (Optional)',
                    hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                    icon: Icon(Icons.edit_note_rounded, color: Theme.of(context).colorScheme.primary.withAlpha(200)),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  maxLines: 1,
                ),
              ),

              // Sub Expenses Toggle
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: ShapeDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                  shape: ContinuousRectangleBorder(
                    borderRadius: BorderRadius.circular(40),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
                      width: 1.0,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Split into Sub-expenses',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    Switch(
                      value: _hasSubExpenses,
                      onChanged: (val) {
                        setState(() {
                          _hasSubExpenses = val;
                          if (val && _subExpenses.isEmpty) {
                            final item = SubExpenseItemState(TextEditingController(), TextEditingController());
                            item.amountCtrl.addListener(_calculateTotalFromSubExpenses);
                            _subExpenses.add(item);
                          }
                          _calculateTotalFromSubExpenses();
                        });
                      },
                    ),
                  ],
                ),
              ),
              if (_hasSubExpenses) ...[
                const SizedBox(height: 8),
                ReorderableListView.builder(
                  shrinkWrap: true,
                  buildDefaultDragHandles: false,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _subExpenses.length,
                  onReorderItem: (oldIndex, newIndex) {
                    setState(() {
                      final item = _subExpenses.removeAt(oldIndex);
                      _subExpenses.insert(newIndex, item);
                    });
                  },
                  itemBuilder: (context, index) {
                    final item = _subExpenses[index];
                    return Padding(
                      key: ValueKey(item),
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Container(
                        padding: const EdgeInsets.only(left: 16, right: 8, top: 2, bottom: 2),
                        decoration: ShapeDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(32),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50)),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              flex: 3,
                              child: TextFormField(
                                controller: item.nameCtrl,
                                readOnly: false,
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                                decoration: InputDecoration(
                                  hintText: 'Item name',
                                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(150),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove),
                                    iconSize: 14,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    onPressed: (item.quantity <= 1) ? null : () {
                                      Haptics.lightImpact();
                                      setState(() {
                                        item.quantity--;
                                        _calculateTotalFromSubExpenses();
                                      });
                                    },
                                  ),
                                  Container(
                                    constraints: const BoxConstraints(minWidth: 16),
                                    alignment: Alignment.center,
                                    child: Text(
                                      '${item.quantity}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add),
                                    iconSize: 14,
                                    padding: EdgeInsets.zero,
                                    visualDensity: VisualDensity.compact,
                                    constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    onPressed: () {
                                      Haptics.lightImpact();
                                      setState(() {
                                        item.quantity++;
                                        _calculateTotalFromSubExpenses();
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 24,
                              width: 1,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              color: Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
                            ),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: item.amountCtrl,
                                readOnly: false,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                                style: TextStyle(
                                  fontWeight: FontWeight.w700, 
                                  fontSize: 16,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                decoration: InputDecoration(
                                  prefixText: '₹ ',
                                  prefixStyle: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(150)),
                                  hintText: '0.00',
                                  hintStyle: TextStyle(color: Theme.of(context).colorScheme.primary.withAlpha(100)),
                                  isDense: true,
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            if (true) ...[
                              IconButton(
                                icon: Icon(Icons.remove_circle, size: 20, color: Theme.of(context).colorScheme.error.withAlpha(200)),
                                onPressed: () {
                                  setState(() {
                                    item.amountCtrl.removeListener(_calculateTotalFromSubExpenses);
                                    item.dispose();
                                    _subExpenses.removeAt(index);
                                    _calculateTotalFromSubExpenses();
                                  });
                                },
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: Icon(Icons.drag_indicator_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withAlpha(80)),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (true) ...[
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        final item = SubExpenseItemState(TextEditingController(), TextEditingController());
                        item.amountCtrl.addListener(_calculateTotalFromSubExpenses);
                        _subExpenses.add(item);
                      });
                    },
                    icon: const Icon(Icons.add_circle_outline),
                    label: const Text('Add Another Item'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer.withAlpha(50),
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      shape: ContinuousRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                  ),
                ],

              ],

              // Attachments
              if (_selectedImages.isNotEmpty) ...[
                const SizedBox(height: 24),
                SizedBox(
                  height: 60,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      ..._selectedImages.asMap().entries.map((entry) {
                        final index = entry.key;
                        final file = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Stack(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: InkWell(
                                  onTap: () {
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
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              if (true)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: InkWell(
                                    onTap: () {
                                      setState(() {
                                        _selectedImages.removeAt(index);
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: Colors.black54,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, size: 12, color: Colors.white),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                      if (true)
                        InkWell(
                          onTap: () => _pickImage(ImageSource.gallery),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(128)),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.add_photo_alternate_rounded, size: 24, color: Theme.of(context).colorScheme.onSurface),
                          ),
                        ),
                    ],
                  ),
                ),
              ] else if (true) ...[
                const SizedBox(height: 24),
                InkWell(
                  onTap: () => _pickImage(ImageSource.gallery),
                  child: Row(
                    children: [
                      Icon(Icons.add_photo_alternate_rounded, size: 20, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                      const SizedBox(width: 8),
                      Text(
                        'Add Receipt / Photo',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              
              const SizedBox(height: 32),

              // Categories
              InkWell(
                onTap: _showCategoryPicker,
                borderRadius: BorderRadius.circular(40),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                  decoration: ShapeDecoration(
                    color: _showCategoryWarning 
                        ? Theme.of(context).colorScheme.errorContainer.withAlpha(50)
                        : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(40),
                      side: BorderSide(
                        color: _showCategoryWarning 
                            ? Theme.of(context).colorScheme.error 
                            : Theme.of(context).colorScheme.outlineVariant.withAlpha(50),
                        width: _showCategoryWarning ? 1.5 : 1.0,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        child: _selectedCategory == null
                            ? Icon(
                                Icons.category_outlined,
                                color: Theme.of(context).colorScheme.primary,
                                size: 20,
                              )
                            : CategoryUtils.getIconWidget(
                                _selectedCategory!, 
                                customCategories,
                                color: CategoryUtils.getColor(_selectedCategory!, customCategories),
                                size: 20,
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Category',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _selectedCategory == null
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.onSurface.withAlpha(150),
                                  ),
                                ),
                                if (_showCategoryWarning && _selectedCategory == null)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).colorScheme.errorContainer,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'REQUIRED',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: Theme.of(context).colorScheme.onErrorContainer,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ).animate().fadeIn().scale(),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _selectedCategory ?? 'Select Category',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded, color: Theme.of(context).colorScheme.onSurface.withAlpha(150)),
                    ],
                  ),
                ),
              ),


              const SizedBox(height: 40),

              // Date & Recurring Row
              Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: _presentDatePicker,
                      borderRadius: BorderRadius.circular(40),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        decoration: ShapeDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                          shape: ContinuousRectangleBorder(
                            borderRadius: BorderRadius.circular(40),
                            side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50)),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface.withAlpha(128),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              DateFormat('MMM dd, yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  
                  if (isLockedToMonth) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _isRecurring = !_isRecurring;
                          });
                        },
                        borderRadius: BorderRadius.circular(40),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                          decoration: ShapeDecoration(
                            color: _isRecurring ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                            shape: ContinuousRectangleBorder(
                              borderRadius: BorderRadius.circular(40),
                              side: BorderSide(
                                color: _isRecurring 
                                    ? Theme.of(context).colorScheme.onSurface 
                                    : Theme.of(context).colorScheme.outlineVariant.withAlpha(50)
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Recurring',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isRecurring ? Theme.of(context).colorScheme.surface.withAlpha(180) : Theme.of(context).colorScheme.onSurface.withAlpha(128),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                _isRecurring ? _recurrencePeriod : 'Off',
                                style: TextStyle(
                                  fontSize: 15, 
                                  fontWeight: FontWeight.w800,
                                  color: _isRecurring ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              
              if (isLockedToMonth && _isRecurring) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: ShapeDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(80),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(32),
                      side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withAlpha(50)),
                    ),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: _recurrencePeriod,
                      items: _periods.map((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
                        );
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _recurrencePeriod = newValue!;
                        });
                      },
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 32),
              
              SwitchListTile(
                title: const Text('Omit from daily average', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('Exclude this expense from dashboard averages', style: TextStyle(fontSize: 12)),
                value: _omitFromAvg,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                onChanged: (val) {
                  setState(() {
                    _omitFromAvg = val;
                  });
                },
              ),

              if (true) ...[
                const SizedBox(height: 48),

                // Full Width Save Button
                PressableButton(
                  scaleFactor: 0.96,
                  onTap: _isSaving ? null : _saveExpense,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: ShapeDecoration(
                      color: _isSaving 
                          ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)
                          : Theme.of(context).colorScheme.onSurface,
                      shape: ContinuousRectangleBorder(
                        borderRadius: BorderRadius.circular(64),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: _isSaving 
                        ? SizedBox(
                            width: 32, 
                            height: 32, 
                            child: LoadingIndicatorM3E(
                              color: Theme.of(context).colorScheme.surface,
                            )
                          )
                        : Text(
                            widget.existingExpense != null ? 'Update Expense' : 'Save Expense', 
                            style: TextStyle(
                              fontSize: 16, 
                              fontWeight: FontWeight.w800, 
                              letterSpacing: 0.5,
                              color: _isSaving 
                                  ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)
                                  : Theme.of(context).colorScheme.surface,
                            ),
                          ),
                  ),
                ),
              ],
            ].animate(interval: 40.ms).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn(duration: 400.ms),
          ),
        ),
      ),
    );
  }
}
