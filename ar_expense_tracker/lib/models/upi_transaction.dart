import 'dart:convert';

class UpiTransaction {
  final String id;
  final double amount;
  final String merchant;
  final String category;
  final int timestamp;
  final String sourcePackage;

  /// Optional note from the source, e.g. UPI ID, bank reference and account.
  final String note;

  const UpiTransaction({
    required this.id,
    required this.amount,
    required this.merchant,
    required this.category,
    required this.timestamp,
    this.sourcePackage = '',
    this.note = '',
  });

  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestamp);

  Map<String, dynamic> toJson() => {
        'id': id,
        'amount': amount,
        'merchant': merchant,
        'category': category,
        'timestamp': timestamp,
        'sourcePackage': sourcePackage,
        'note': note,
      };

  factory UpiTransaction.fromJson(Map<String, dynamic> json) => UpiTransaction(
        id: json['id'] as String? ?? DateTime.now().millisecondsSinceEpoch.toString(),
        amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
        merchant: json['merchant'] as String? ?? 'UPI Expense',
        category: json['category'] as String? ?? 'General',
        timestamp: json['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
        sourcePackage: json['sourcePackage'] as String? ?? '',
        note: json['note'] as String? ?? '',
      );

  /// Decodes the native approved queue. Skips bad entries one by one, and entries without an `id`
  /// (they could not be de-duplicated or removed from the queue, so they would repeat).
  static List<UpiTransaction> decodeList(String jsonString) {
    if (jsonString.isEmpty || jsonString == '[]') return [];
    final List<dynamic> decoded;
    try {
      decoded = jsonDecode(jsonString) as List<dynamic>;
    } catch (_) {
      return [];
    }
    final result = <UpiTransaction>[];
    for (final item in decoded) {
      try {
        final map = item as Map<String, dynamic>;
        final id = map['id'];
        if (id is! String || id.isEmpty) continue;
        result.add(UpiTransaction.fromJson(map));
      } catch (_) {}
    }
    return result;
  }

  static String encodeList(List<UpiTransaction> list) {
    return jsonEncode(list.map((item) => item.toJson()).toList());
  }
}
