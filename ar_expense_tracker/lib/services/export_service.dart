// ignore_for_file: deprecated_member_use, prefer_interpolation_to_compose_strings

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import '../database/expense_database.dart';

class ExportService {
  static Future<void> exportAndShareExpenses(ExpenseGroup group, List<Expense> expenses) async {
    List<List<dynamic>> rows = [];
    // Headers
    rows.add([
      'ID',
      'Date',
      'Time',
      'Title',
      'Category',
      'Amount',
      'Sub-Expenses',
      'Notes',
      'Recurring',
      'Omit from Avg',
    ]);

    // Data rows sorted chronologically descending
    final sortedExpenses = List<Expense>.from(expenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    double totalAmount = 0.0;
    for (var exp in sortedExpenses) {
      totalAmount += exp.amount;
      final subExpensesStr = exp.subExpenses != null && exp.subExpenses!.isNotEmpty
          ? exp.subExpenses!.map((s) => '${s.quantity}x ${s.name} (${s.amount.toStringAsFixed(2)})').join('; ')
          : '';

      rows.add([
        exp.id,
        DateFormat('yyyy-MM-dd').format(exp.date),
        DateFormat('HH:mm').format(exp.date),
        exp.title ?? '',
        exp.category,
        exp.amount.toStringAsFixed(2),
        subExpensesStr,
        exp.note ?? '',
        exp.isRecurring ? 'Yes (${exp.recurrencePeriod ?? 'Monthly'})' : 'No',
        exp.omitFromAvg ? 'Yes' : 'No',
      ]);
    }

    // Summary section
    rows.add([]);
    rows.add(['Summary', '', '', '', '', '', '', '', '', '']);
    rows.add(['Total Transactions', sortedExpenses.length, '', '', '', '', '', '', '', '']);
    rows.add(['Total Spending', totalAmount.toStringAsFixed(2), '', '', '', '', '', '', '', '']);

    final buffer = StringBuffer();
    for (var row in rows) {
      if (row.isEmpty) {
        buffer.writeln('');
        continue;
      }
      buffer.writeln(row.map((e) => '"${e.toString().replaceAll('"', '""')}"').join(','));
    }

    final directory = await getApplicationDocumentsDirectory();
    final cleanGroupName = group.name.replaceAll(RegExp(r'[^\w\s\.-]'), '_').trim().replaceAll(' ', '_');
    final path = '${directory.path}/expense_report_${cleanGroupName}_${DateFormat('yyyyMMdd').format(DateTime.now())}.csv';
    final file = File(path);
    await file.writeAsString(buffer.toString());

    await Share.shareXFiles([XFile(path)], text: 'Expense Report for ${group.name}');
  }
}
