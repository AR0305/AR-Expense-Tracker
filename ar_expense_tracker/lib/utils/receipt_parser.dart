// ignore_for_file: curly_braces_in_flow_control_structures, prefer_conditional_assignment

import 'dart:math';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptData {
  final double? amount;
  final String? storeName;
  final String? suggestedCategory;
  final List<Map<String, dynamic>> subExpenses;
  final ReceiptType detectedType;
  final String rawText;

  ReceiptData({
    this.amount,
    this.storeName,
    this.suggestedCategory,
    this.subExpenses = const [],
    this.detectedType = ReceiptType.printed,
    this.rawText = '',
  });
}

enum ReceiptType { printed, ecommerce, quickCommerce, upiScreenshot, foodDeliveryHistory }

class ReceiptParser {
  static final _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  static void _debugLog(String message) {}

  // ── Shared Regex ──────────────────────────────────────────────────────────
  // Matches a currency-tagged amount, a comma-grouped amount (2,499 / 2,499.00
  // / 1,29,999 Indian-style), or a plain decimal amount (499.00). Deliberately
  // does NOT match bare integers with no symbol/grouping/decimal — those are
  // ambiguous (a rating, a date, a quantity) and are only accepted
  // contextually elsewhere (see _extractMisreadPriceEnd).
  static final _priceRegex = RegExp(
    r'(?:[₹$£€]|Rs\.?|INR)\s*\d{1,3}(?:[,\s]\d{2,3})*(?:\.\d{1,2})?'
    r'|\b\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?\b'
    r'|\b\d{1,6}\.\d{2}\b',
    caseSensitive: false,
  );

  // Sanity cap on a plausible personal-expense amount — not a truncation cap.
  static const double _maxPlausibleAmount = 5000000;

  // ── Public API ────────────────────────────────────────────────────────────
  static Future<ReceiptData> parseReceipt(String imagePath, List<String> availableCategories) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

    final fullText = recognizedText.text;
    final debugDump = _buildDebugDump(recognizedText);
    _debugLog('--- OCR DEBUG START ---');
    _debugLog(debugDump);
    _debugLog('-----------------------');

    // ── Step 1: Check Filename for metadata ────────────────────────────────
    final filename = imagePath.split('/').last.replaceAll('%20', ' ');
    var (filenameAmount, filenameStore) = _parseFilename(filename);

    // ── Step 2: Build visual lines ─────────────────────────────────────────
    final visualLines = _buildVisualLines(recognizedText);

    // ── Step 3: Detect receipt type ────────────────────────────────────────
    var receiptType = _detectReceiptType(fullText);
    
    // If filename implies Google Pay or UPI, force type
    if (filename.toLowerCase().contains('google pay') || filename.toLowerCase().contains('paytm') || filename.toLowerCase().contains('phonepe')) {
      receiptType = ReceiptType.upiScreenshot;
    }
    
    _debugLog('DEBUG: Detected receipt type → $receiptType');

    // ── Step 4: Dispatch to type-specific strategy ─────────────────────────
    double? amount;
    String? storeName;
    List<Map<String, dynamic>> subExpenses;

    switch (receiptType) {
      case ReceiptType.ecommerce:
        final result = _parseEcommerceBill(visualLines, fullText, recognizedText);
        amount = result.$1;
        storeName = result.$2;
        subExpenses = result.$3;
        break;
      case ReceiptType.upiScreenshot:
        final result = _parseUpiScreenshot(visualLines, fullText, recognizedText);
        amount = result.$1;
        storeName = result.$2;
        subExpenses = result.$3;
        break;
      case ReceiptType.quickCommerce:
        final result = _parseQuickCommerceBill(visualLines, fullText, recognizedText);
        amount = result.$1;
        storeName = result.$2;
        subExpenses = result.$3;
        break;
      case ReceiptType.foodDeliveryHistory:
        final result = _parseFoodDeliveryHistory(visualLines, fullText, recognizedText);
        amount = result.$1;
        storeName = result.$2;
        subExpenses = result.$3;
        break;
      case ReceiptType.printed:
        final result = _parsePrintedBill(visualLines, fullText, recognizedText);
        amount = result.$1;
        storeName = result.$2;
        subExpenses = result.$3;
        break;
    }

    // Override with filename data if available (filename is the source of truth if provided by the app)
    if (filenameAmount != null) amount = filenameAmount;
    if (filenameStore != null) storeName = filenameStore;

    // ── Step 5: Category detection (shared) ────────────────────────────────
    final suggestedCategory = _suggestCategory(fullText, availableCategories);

    // ── Step 5: Post-process – Fix Rupee symbol misreads ───────────────────
    if (amount != null && subExpenses.isNotEmpty) {
      final fixed = _fixRupeeMisread(amount, subExpenses);
      amount = fixed.$1;
      subExpenses = fixed.$2;
    }

    // ── Step 6: Post-process – Subset Sum filter ───────────────────────────
    subExpenses = _subsetSumFilter(subExpenses, amount);

    _debugLog('DEBUG: Final Amount: $amount');
    _debugLog('DEBUG: Store Name: $storeName');
    _debugLog('DEBUG: Extracted SubExpenses (${subExpenses.length}): $subExpenses');
    _debugLog('DEBUG: Suggested Category: $suggestedCategory');
    _debugLog('--- OCR DEBUG END ---');

    return ReceiptData(
      amount: amount,
      storeName: storeName,
      suggestedCategory: suggestedCategory,
      subExpenses: subExpenses,
      detectedType: receiptType,
      rawText: debugDump,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  DEBUG DUMP (block/line structure as ML Kit sees it)
  // ═══════════════════════════════════════════════════════════════════════════

  static String _buildDebugDump(RecognizedText recognizedText) {
    final buffer = StringBuffer();
    for (int b = 0; b < recognizedText.blocks.length; b++) {
      final block = recognizedText.blocks[b];
      buffer.writeln('BLOCK $b:');
      for (final line in block.lines) {
        final box = line.boundingBox;
        buffer.writeln(
          '  "${line.text}"  [Y:${box.top.toStringAsFixed(0)} H:${box.height.toStringAsFixed(0)} X:${box.left.toStringAsFixed(0)}]',
        );
      }
    }
    return buffer.toString();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FILENAME PARSER
  // ═══════════════════════════════════════════════════════════════════════════

  static (double?, String?) _parseFilename(String filename) {
    // Expected format: "1783800029 - 160.00 To S Subash on Google Pay.png"
    // Regex matches: <amount> To <name> on <app>
    final regex = RegExp(r'([\d,]+\.?\d*)\s+To\s+(.+?)\s+on\s+(Google Pay|PhonePe|Paytm|Amazon Pay)', caseSensitive: false);
    final match = regex.firstMatch(filename);
    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      final amount = double.tryParse(amountStr ?? '');
      final name = match.group(2)?.trim();
      return (amount, name);
    }
    return (null, null);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  RECEIPT TYPE DETECTION
  // ═══════════════════════════════════════════════════════════════════════════

  static ReceiptType _detectReceiptType(String fullText) {
    final lower = fullText.toLowerCase();

    // Food Delivery History keywords
    if (lower.contains('your orders') || lower.contains('order placed on')) {
      if (lower.contains('zomato') || lower.contains('swiggy')) {
        return ReceiptType.foodDeliveryHistory;
      }
    }

    // UPI Screenshot keywords
    const upiFingerprints = [
      'paid to', 'sent to', 'paying', 'transaction successful', 'payment successful',
      'upi transaction id', 'upi ref', 'google pay', 'phonepe', 'paytm',
      'amazon pay', 'cred upi', 'bhim', 'transfer details', 'banking name'
    ];
    int upiScore = 0;
    for (final kw in upiFingerprints) {
      if (lower.contains(kw)) upiScore++;
    }
    if (upiScore >= 1) return ReceiptType.upiScreenshot;

    // Quick commerce keywords (check first — they're a subset of e-commerce)
    const quickCommerceFingerprints = [
      'zepto', 'blinkit', 'instamart', 'swiggy instamart', 'bigbasket',
      'dunzo', 'jiomart', 'grofers', 'bb now', 'bbdaily', 'zomato', 'swiggy',
      'handling fee', 'platform fee', 'surge fee', 'rain fee',
      'delivery partner', 'dark store',
    ];
    int qcScore = 0;
    for (final kw in quickCommerceFingerprints) {
      if (lower.contains(kw)) qcScore++;
    }
    if (qcScore >= 1) return ReceiptType.quickCommerce;

    // E-commerce keywords
    const ecommerceFingerprints = [
      'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa',
      'tata cliq', 'snapdeal', 'shopsy',
      'order id', 'order summary', 'order details',
      'sold by', 'shipped by', 'seller',
      'mrp', 'list price', 'you save', 'discount',
      'delivery charge', 'shipping charge',
      'estimated delivery', 'return policy',
    ];
    int ecScore = 0;
    for (final kw in ecommerceFingerprints) {
      if (lower.contains(kw)) ecScore++;
    }
    if (ecScore >= 2) return ReceiptType.ecommerce;

    // Default: printed bill
    return ReceiptType.printed;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  VISUAL LINE BUILDER (shared)
  // ═══════════════════════════════════════════════════════════════════════════

  static List<List<TextElement>> _buildVisualLines(RecognizedText recognizedText) {
    List<TextElement> allElements = [];
    for (TextBlock block in recognizedText.blocks) {
      for (TextLine line in block.lines) {
        allElements.addAll(line.elements);
        _debugLog('DEBUG LINE: "${line.text}" Y:${line.boundingBox.top.toStringAsFixed(1)} H:${line.boundingBox.height.toStringAsFixed(1)}');
      }
    }

    allElements.sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));

    List<List<TextElement>> visualLines = [];
    for (var element in allElements) {
      bool added = false;
      final elementCenterY = element.boundingBox.top + element.boundingBox.height / 2;

      for (var line in visualLines) {
        final lineCenterY = line.first.boundingBox.top + line.first.boundingBox.height / 2;
        final tolerance = line.first.boundingBox.height * 0.6;
        if ((elementCenterY - lineCenterY).abs() < tolerance) {
          line.add(element);
          added = true;
          break;
        }
      }
      if (!added) {
        visualLines.add([element]);
      }
    }

    for (var line in visualLines) {
      line.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
    }

    return visualLines;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  NOISE DETECTION (shared)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Returns true if the line text is noise (phone numbers, IDs, dates, etc.)
  static bool _isNoiseLine(String text) {
    final lower = text.toLowerCase();

    // Phone numbers: 10+ continuous digits
    if (RegExp(r'\d{10,}').hasMatch(text)) return true;

    // GST numbers: 15-char alphanumeric starting with 2 digits
    if (RegExp(r'\b\d{2}[A-Z0-9]{13}\b').hasMatch(text)) return true;

    // PIN codes: exactly 6 digits near "pin" or standalone
    if (RegExp(r'\bpin\b', caseSensitive: false).hasMatch(text) &&
        RegExp(r'\b\d{6}\b').hasMatch(text)) return true;

    // HSN codes
    if (lower.contains('hsn') || lower.contains('sac')) return true;

    // Pure date lines
    if (RegExp(r'^\s*\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4}\s*$').hasMatch(text)) return true;

    // Order/Invoice ID lines (just IDs, no useful data)
    if (RegExp(r'(order|invoice|ref|txn|transaction)\s*(id|no|#|number)', caseSensitive: false).hasMatch(text) &&
        !_priceRegex.hasMatch(text)) return true;

    // Address lines (contain pin code patterns or common address words with no price)
    if ((lower.contains('address') || lower.contains('deliver to') || lower.contains('ship to')) &&
        !_priceRegex.hasMatch(text)) return true;

    // Lines that are just numbers with no letters (barcode, serial number)
    if (RegExp(r'^\s*[\d\s\-]+\s*$').hasMatch(text) && text.replaceAll(RegExp(r'\D'), '').length > 8) return true;

    return false;
  }

  /// Returns true if a number looks like a non-price value
  static bool _isNoiseNumber(double value) {
    if (value <= 0) return true;
    if (value > _maxPlausibleAmount) return true;
    return false;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  UPI SCREENSHOT PARSER
  // ═══════════════════════════════════════════════════════════════════════════

  static (double?, String?, List<Map<String, dynamic>>) _parseUpiScreenshot(
    List<List<TextElement>> visualLines,
    String fullText,
    RecognizedText recognizedText,
  ) {
    double? bestAmount;
    
    // 1. Scan for the largest font size number (amount is always huge on UPI receipts)
    double? maxFontSize;
    for (int i = 0; i < visualLines.length; i++) {
      for (var element in visualLines[i]) {
        final text = element.text;
        
        // Remove currency symbols, commas, and formatting to parse pure numbers
        final cleaned = text.replaceAll(RegExp(r'[^\d.]'), '');
        // Must contain at least one digit
        if (cleaned.isEmpty || !RegExp(r'\d').hasMatch(cleaned)) continue;
        
        // Count decimal dots to prevent multiple dots from crashing double.tryParse
        final dots = '.'.allMatches(cleaned).length;
        String parsable = cleaned;
        if (dots > 1) {
          final lastDot = cleaned.lastIndexOf('.');
          parsable = cleaned.substring(0, lastDot).replaceAll('.', '') + cleaned.substring(lastDot);
        }
        
        final numValue = double.tryParse(parsable);
        if (numValue != null && !_isNoiseNumber(numValue)) {
          final height = element.boundingBox.height;
          if (maxFontSize == null || height > maxFontSize) {
            maxFontSize = height;
            bestAmount = numValue;
          }
        }
      }
    }

    // 2. Extract recipient name
    String? storeName;
    for (int i = 0; i < visualLines.length; i++) {
      final text = _lineText(visualLines[i]);
      final lineLower = text.toLowerCase();
      
      String? matchedPrefix;
      if (lineLower.contains('paid to')) matchedPrefix = 'paid to';
      else if (lineLower.contains('sent to')) matchedPrefix = 'sent to';
      else if (lineLower.contains('paying')) matchedPrefix = 'paying';
      else if (lineLower.contains('banking name')) matchedPrefix = 'banking name';
      else if (lineLower.contains('beneficiary name')) matchedPrefix = 'beneficiary name';
      else if (lineLower.contains('transfer to')) matchedPrefix = 'transfer to';
      else if (lineLower.startsWith('to ')) matchedPrefix = 'to ';
      
      if (matchedPrefix != null) {
        // Try extracting from the same line first (e.g. "Paid to John Doe" or "to Nadeem")
        final index = lineLower.indexOf(matchedPrefix);
        final afterPrefix = text.substring(index + matchedPrefix.length).trim();
        
        // Sometimes it has a colon like "Paid to: John Doe"
        final cleanedAfterPrefix = afterPrefix.replaceAll(RegExp(r'^[:\-]+'), '').trim();
        
        if (cleanedAfterPrefix.isNotEmpty && !_priceRegex.hasMatch(cleanedAfterPrefix) && !RegExp(r'\d').hasMatch(cleanedAfterPrefix)) {
          storeName = cleanedAfterPrefix;
          break;
        }
        
        // If empty on the same line, look at the next line
        if (i + 1 < visualLines.length) {
          final possibleName = _lineText(visualLines[i + 1]).trim();
          if (possibleName.isNotEmpty && !_priceRegex.hasMatch(possibleName) && !RegExp(r'\d').hasMatch(possibleName)) {
            storeName = possibleName;
            break;
          }
        }
      }
    }

    return (bestAmount, storeName, []);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PRICE EXTRACTION HELPERS (shared)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Parses a price-shaped string into a double, correctly distinguishing a
  /// decimal separator from a thousands-grouping separator (so "2,499.00"
  /// parses as 2499.00, not 499.00 — the old code truncated on this), and
  /// normalizing the common OCR digit/letter confusion 'O'/'o' → '0' once the
  /// token has already been identified as numeric (e.g. "1O" → "10").
  ///
  /// Deliberately does NOT try to strip a misread '₹' (commonly OCR'd as a
  /// leading '7', 'Z', or 'T') here — a lone leading '7' is indistinguishable
  /// from a legitimately-leading-7 amount without more context. That
  /// correction happens later, validated against the receipt total, in
  /// [_fixRupeeMisread].
  static double? _extractPrice(String text) {
    var s = text.trim();
    if (s.isEmpty) return null;

    final symbolMatch = RegExp(r'^(?:[₹$£€]|Rs\.?|INR)\s*', caseSensitive: false).firstMatch(s);
    if (symbolMatch != null) s = s.substring(symbolMatch.end);

    s = s.trim();
    s = s.replaceAll(RegExp(r'[Oo]'), '0');
    s = s.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (s.isEmpty) return null;

    final lastComma = s.lastIndexOf(',');
    final lastDot = s.lastIndexOf('.');
    final sepIdx = lastComma > lastDot ? lastComma : lastDot;
    if (sepIdx >= 0) {
      final fracLen = s.length - sepIdx - 1;
      if (fracLen > 0 && fracLen <= 2) {
        // The last separator is a decimal point; everything before it
        // (commas or dots) is thousands-grouping and gets dropped, not
        // truncated.
        final intPart = s.substring(0, sepIdx).replaceAll(RegExp(r'[.,]'), '');
        final fracPart = s.substring(sepIdx + 1);
        return double.tryParse('$intPart.$fracPart');
      }
    }
    // No valid decimal tail — every separator present is thousands-grouping.
    return double.tryParse(s.replaceAll(RegExp(r'[.,]'), ''));
  }

  static List<double> _extractAllPrices(String text) {
    final matches = _priceRegex.allMatches(text);
    List<double> prices = [];
    for (final match in matches) {
      final p = _extractPrice(match.group(0) ?? '');
      if (p != null && !_isNoiseNumber(p)) prices.add(p);
    }
    return prices;
  }

  static String _lineText(List<TextElement> line) => line.map((e) => e.text).join(' ');

  /// Strips only the matched price span(s), currency symbols, and stray
  /// separators from an item name. Unlike the old version, this preserves
  /// digits, units, and parentheses ("45 Liter", "Pack of 5", "1kg (400 ml)")
  /// — they're part of the product's real identity, not noise.
  static String _cleanItemName(String text) {
    var name = text;
    name = name.replaceAll(_priceRegex, ' ');
    name = name.replaceAll(_ecomPriceRegex, ' ');
    name = name.replaceAll(RegExp(r'[₹$£€]'), ' ');
    name = name.replaceAll('|', ' ');
    name = name.replaceAll(RegExp(r'\s{2,}'), ' ').trim();
    name = name.replaceAll(RegExp(r'^[\s\-:,.]+|[\s\-:,.]+$'), '');
    return name;
  }

  /// Extracts the trailing contiguous digit run from a line — used to catch a
  /// price glued directly onto the end of a name with no separating space,
  /// including severe OCR misreads like "T296" (₹296), "Z455" (₹455), or
  /// "7350" (₹350 where ₹ was read as 7). Letters immediately before the
  /// digits (a misread symbol, or incidental word fragments) are naturally
  /// excluded since only [\d,.] characters are matched.
  static double? _extractMisreadPriceEnd(String text) {
    final match = RegExp(r'[\d,]+(?:[.,]\d{1,2})?$').firstMatch(text.trim());
    if (match == null) return null;
    return _extractPrice(match.group(0)!);
  }

  /// Removes the trailing digit run matched by [_extractMisreadPriceEnd] so
  /// the remainder can be used as the item's name.
  static String _stripTrailingMisreadPrice(String text) {
    return text.trim().replaceFirst(RegExp(r'[\d,]+(?:[.,]\d{1,2})?$'), '').trim();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ROW-BASED ITEM EXTRACTION (shared by e-commerce & quick-commerce)
  // ═══════════════════════════════════════════════════════════════════════════
  //
  // ML Kit's block segmentation does NOT reliably keep a product's name and
  // its price(s) in the same TextBlock. On real Zepto/Blinkit/Flipkart/Myntra
  // screenshots the name (left-aligned, often wrapping 1-2 lines) and the
  // price (right-aligned, sometimes stacked bold+strikethrough) frequently
  // land in different blocks — verified against real OCR dumps where a
  // product's price ended up in a block with zero letters and was silently
  // dropped by the old block-iteration approach. Visual-row clustering (by
  // Y-position, across the whole page, ignoring block boundaries — already
  // used correctly for total detection) is what actually reconstructs each
  // item, so item extraction is done on rows here instead.

  /// Rows describing app-chrome/section structure rather than a product.
  /// Hitting one of these always closes out whatever item is pending.
  static const _nonItemRowKeywords = [
    'shipment', 'item in', 'items in', 'delivered', 'arrived in', 'order #',
    'order id', 'get help', 'rate order', 'order again', 'track order',
    'exchange', 'eligible for', 'return', 'replace', 'valid till', 'valid until',
    'thank you', 'ship to', 'deliver to', 'delivery address', 'shipping address',
    'sold by', 'shipped by', 'fulfilled by', 'seller', 'estimated delivery',
  ];

  /// Context words that mean a trailing bare number is NOT a price (a date,
  /// a return-window caption, a rating) — guards the "price glued onto the
  /// end of the name" fallback from grabbing something like "...till Jul 14".
  static final _nonPriceContextWords = RegExp(
    r'\b(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec|till|valid|expiry|'
    r'exchange|eligible|return|replace|rated|star|review|warranty|guarantee)\b',
    caseSensitive: false,
  );

  static bool _isMetadataRow(String text) {
    final t = text.trim();
    if (RegExp(r'^\d+\s*(pc|pcs|ml|l|g|kg|mg|unit|units|pack|packs)\b', caseSensitive: false).hasMatch(t)) {
      return true;
    }
    if (RegExp(r'^(qty|size|color)\b', caseSensitive: false).hasMatch(t)) return true;
    return false;
  }

  /// Finds the row index where the bill's fee/total section begins, so item
  /// extraction never wanders into "Item Total", "Delivery Fee", or a
  /// wallet-credit line like "Zepto Cash Applied" and misreads it as a
  /// product (confirmed failure mode on a real receipt).
  static int _findBillSummaryBoundary(List<List<TextElement>> visualLines) {
    const headerKeywords = ['bill summary', 'price details', 'payment summary', 'fare summary'];
    for (int i = 0; i < visualLines.length; i++) {
      final text = _lineText(visualLines[i]).toLowerCase();
      if (headerKeywords.any((kw) => text.contains(kw))) return i;
    }
    return visualLines.length;
  }

  static List<Map<String, dynamic>> _extractItemsFromRows(List<List<TextElement>> visualLines) {
    final items = <Map<String, dynamic>>[];
    final boundary = _findBillSummaryBoundary(visualLines);
    final qtyPattern = RegExp(r'[x×]\s*(\d+)|qty[:\s]*(\d+)', caseSensitive: false);
    final hasLetters = RegExp(r'[a-zA-Z]{2,}');

    List<String> pendingNames = [];
    List<double> pendingPrices = [];
    int? pendingQty;

    void flush() {
      if (pendingNames.isNotEmpty && pendingPrices.isNotEmpty) {
        var name = pendingNames.join(' ').trim();
        if (name.length > 80) name = '${name.substring(0, 77)}...';
        final price = pendingPrices.reduce(min);
        if (name.length >= 2 && price > 0) {
          final isDuplicate = items.any((it) {
            final existingName = (it['title'] as String).toLowerCase();
            final existingAmt = it['amount'] as double;
            return existingName == name.toLowerCase() && (existingAmt - price).abs() < 0.5;
          });
          if (!isDuplicate) {
            items.add({
              'title': name,
              'amount': price,
              if (pendingQty != null && pendingQty! > 1) 'quantity': pendingQty,
            });
          }
        }
      }
      pendingNames = [];
      pendingPrices = [];
      pendingQty = null;
    }

    for (int i = 0; i < boundary; i++) {
      final row = visualLines[i];
      final text = _lineText(row);
      if (text.trim().isEmpty || _isNoiseLine(text)) continue;
      final lower = text.toLowerCase();

      if (_nonItemRowKeywords.any((kw) => lower.contains(kw))) {
        flush();
        continue;
      }

      if (_isMetadataRow(text)) {
        final qtyMatch = qtyPattern.firstMatch(text);
        if (qtyMatch != null) {
          final q = qtyMatch.group(1) ?? qtyMatch.group(2);
          if (q != null) pendingQty = int.tryParse(q);
        }
        flush();
        continue;
      }

      // Explicit price (currency symbol, decimal, or grouped) somewhere in the row.
      final explicitPrices = _extractAllEcomPrices(text);
      if (explicitPrices.isNotEmpty) {
        pendingPrices.addAll(explicitPrices);
        final remainder = _stripPriceTokens(text);
        if (hasLetters.hasMatch(remainder)) {
          final cleaned = _cleanItemName(remainder);
          if (cleaned.length >= 2) pendingNames.add(cleaned);
        }
        continue;
      }

      // No explicit price. A bare number glued to the end of a name line
      // (e.g. "...Zero 54") is only trusted as a price on the FIRST name row
      // of a pending item, and only when the row has no date/caption context
      // — that combination is what distinguished a real glued-on price from
      // a phantom one like "Eligible for Exchange till Jul 14" in testing.
      if (pendingNames.isEmpty && hasLetters.hasMatch(text) && !_nonPriceContextWords.hasMatch(text)) {
        final bare = _extractMisreadPriceEnd(text);
        if (bare != null && !_isNoiseNumber(bare)) {
          pendingPrices.add(bare);
          final cleaned = _cleanItemName(_stripTrailingMisreadPrice(text));
          if (cleaned.length >= 2) pendingNames.add(cleaned);
          continue;
        }
      }

      if (hasLetters.hasMatch(text)) {
        var lineForName = text;
        if (pendingPrices.isNotEmpty) {
          // We already have a price for this item — a trailing bare number
          // on a continuation row is very likely a second price (e.g. the
          // strikethrough MRP), so capture it instead of leaving it as text.
          final extra = _extractMisreadPriceEnd(text);
          if (extra != null && !_isNoiseNumber(extra)) {
            pendingPrices.add(extra);
            lineForName = _stripTrailingMisreadPrice(text);
          }
        }
        final cleaned = _cleanItemName(lineForName);
        if (cleaned.length >= 2) pendingNames.add(cleaned);
      }
    }
    flush();
    return items;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STRATEGY 1: PRINTED BILLS (thermal receipts, restaurant bills)
  // ═══════════════════════════════════════════════════════════════════════════

  static (double?, String?, List<Map<String, dynamic>>) _parsePrintedBill(
    List<List<TextElement>> visualLines, String fullText, RecognizedText recognized,
  ) {
    double? bestAmount;
    String? storeName;
    List<Map<String, dynamic>> subExpenses = [];
    double? itemTotal;

    // ── Store name: first meaningful text line ──────────────────────────────
    if (recognized.blocks.isNotEmpty) {
      final firstLine = recognized.blocks.first.lines.first.text;
      // Skip if it's just numbers or very short
      if (RegExp(r'[a-zA-Z]{2,}').hasMatch(firstLine)) {
        storeName = firstLine;
      }
    }

    // ── Total extraction: scan bottom-up for total keywords ─────────────────
    final totalKeywords = ['grand total', 'net total', 'total amount', 'amount payable',
      'net amount', 'net payable', 'bill total', 'total bill', 'total due',
      'amount due', 'you pay', 'to pay', 'payable'];
    final subtotalKeywords = ['sub total', 'subtotal', 'item total', 'items total'];

    // First pass: look for grand total keywords (bottom-up)
    for (int i = visualLines.length - 1; i >= 0; i--) {
      final text = _lineText(visualLines[i]);
      final lower = text.toLowerCase();
      if (_isNoiseLine(text)) continue;

      for (final kw in totalKeywords) {
        if (lower.contains(kw)) {
          final prices = _extractAllPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.last; // rightmost number on total line
            _debugLog('DEBUG [printed]: Found grand total "$kw" → $bestAmount');
            break;
          }
        }
      }
      if (bestAmount != null) break;
    }

    // Second pass: plain "total" keyword (bottom-up), skip subtotals
    if (bestAmount == null) {
      for (int i = visualLines.length - 1; i >= 0; i--) {
        final text = _lineText(visualLines[i]);
        final lower = text.toLowerCase();
        if (_isNoiseLine(text)) continue;

        final isSubtotal = subtotalKeywords.any((kw) => lower.contains(kw));
        if (lower.contains('total') && !isSubtotal) {
          final prices = _extractAllPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.last;
            _debugLog('DEBUG [printed]: Found "total" → $bestAmount');
            break;
          }
        }

        // Also capture item total for subset-sum later
        if (isSubtotal) {
          final prices = _extractAllPrices(text);
          if (prices.isNotEmpty) itemTotal = prices.last;
        }
      }
    }

    // Third pass: "paid" or "amount"
    if (bestAmount == null) {
      for (int i = visualLines.length - 1; i >= 0; i--) {
        final text = _lineText(visualLines[i]);
        final lower = text.toLowerCase();
        if (_isNoiseLine(text)) continue;

        if (lower.contains('paid') || lower.contains('amount')) {
          final prices = _extractAllPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.last;
            _debugLog('DEBUG [printed]: Found "paid/amount" → $bestAmount');
            break;
          }
        }
      }
    }

    // ── Sub-expense extraction ──────────────────────────────────────────────
    final skipKeywords = [
      'total', 'tax', 'gst', 'cgst', 'sgst', 'igst', 'cess',
      'discount', 'coupon', 'promo', 'saving', 'cashback',
      'amount', 'paid', 'change', 'cash', 'card', 'upi',
      'thank', 'visit', 'welcome', 'invoice', 'bill no',
      'date', 'time', 'counter', 'cashier', 'gstin',
      'address', 'phone', 'tel', 'fax', 'email',
      'round', 'rounding',
    ];
    final hasLetters = RegExp(r'[a-zA-Z]{2,}');

    for (var line in visualLines) {
      final text = _lineText(line);
      final lower = text.toLowerCase();
      if (_isNoiseLine(text)) continue;
      if (skipKeywords.any((kw) => lower.contains(kw))) continue;

      if (hasLetters.hasMatch(text)) {
        final prices = _extractAllPrices(text);
        if (prices.isNotEmpty) {
          // For printed bills, rightmost price is the line total
          final price = prices.last;
          final name = _cleanItemName(text);
          if (name.length >= 2 && price > 0) {
            subExpenses.add({'title': name, 'amount': price});
          }
        } else {
          // Try trailing number without currency symbol
          final endMatch = RegExp(r'\s+(\d{1,5})(?:[.,]\d{2})?\s*$').firstMatch(text);
          if (endMatch != null) {
            final price = double.tryParse(endMatch.group(0)!.trim().replaceAll(',', '.'));
            if (price != null && price > 0) {
              final name = _cleanItemName(text.substring(0, endMatch.start));
              if (name.length >= 2) {
                subExpenses.add({'title': name, 'amount': price});
              }
            }
          } else if (subExpenses.isNotEmpty) {
            // Continuation line — append to previous item name
            var extra = text.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), '').trim();
            extra = extra.replaceAll(RegExp(r'\s{2,}'), ' ');
            if (extra.length > 2) {
              subExpenses.last['title'] = '${subExpenses.last['title']} $extra';
            }
          }
        }
      }
    }

    // ── Fallback total ──────────────────────────────────────────────────────
    if (bestAmount == null) {
      bestAmount = itemTotal ?? _fallbackTotal(visualLines, subExpenses);
    }

    return (bestAmount, storeName, subExpenses);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  STRATEGY 2: E-COMMERCE BILLS (Amazon, Flipkart, Myntra, etc.)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Broader price regex for e-commerce/quick-commerce — matches currency-
  /// tagged amounts (with or without decimals), comma-grouped amounts, and
  /// plain decimals. No digit-count cap, so large grouped amounts like
  /// "1,29,999" are no longer truncated.
  static final _ecomPriceRegex = RegExp(
    r'(?:[₹$£€]|Rs\.?|INR)\s*\d{1,3}(?:[,\s]\d{2,3})*(?:\.\d{1,2})?'
    r'|\b\d{1,3}(?:,\d{2,3})+(?:\.\d{1,2})?\b'
    r'|\b\d{1,6}\.\d{2}\b',
    caseSensitive: false,
  );

  static List<double> _extractAllEcomPrices(String text) {
    final matches = _ecomPriceRegex.allMatches(text);
    List<double> prices = [];
    for (final match in matches) {
      final p = _extractPrice(match.group(0) ?? '');
      if (p != null && !_isNoiseNumber(p)) prices.add(p);
    }
    return prices;
  }

  /// Strips every matched price token, leaving text usable as an item name.
  static String _stripPriceTokens(String text) {
    return text.replaceAll(_ecomPriceRegex, ' ').replaceAll(_priceRegex, ' ');
  }

  static (double?, String?, List<Map<String, dynamic>>) _parseEcommerceBill(
    List<List<TextElement>> visualLines, String fullText, RecognizedText recognized,
  ) {
    double? bestAmount;
    String? storeName;
    List<Map<String, dynamic>> subExpenses = [];

    // ── Store/Platform name ─────────────────────────────────────────────────
    final lower = fullText.toLowerCase();
    const platforms = ['amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa', 'tata cliq', 'snapdeal', 'shopsy'];
    for (final p in platforms) {
      if (lower.contains(p)) {
        storeName = p[0].toUpperCase() + p.substring(1);
        break;
      }
    }

    // Try "sold by" / "shipped by" for seller name
    if (storeName == null) {
      final soldByMatch = RegExp(r'(?:sold|shipped|fulfilled)\s+by[:\s]+([A-Za-z][A-Za-z\s&]+)', caseSensitive: false).firstMatch(fullText);
      if (soldByMatch != null) {
        storeName = soldByMatch.group(1)?.trim();
      }
    }

    // ── Total extraction ────────────────────────────────────────────────────
    final grandTotalKeywords = ['order total', 'grand total', 'amount payable',
      'total amount', 'you pay', 'to pay', 'payable amount', 'amount paid'];
    final ignoreTotalKeywords = ['item total', 'sub total', 'subtotal', 'items total', 'cart total'];
    final strikethroughKeywords = ['mrp', 'list price', 'was', 'you save',
      'you saved', 'save', 'off', 'discount', 'coupon', 'cashback'];

    // Grand total pass
    for (int i = visualLines.length - 1; i >= 0; i--) {
      final text = _lineText(visualLines[i]);
      final lineLower = text.toLowerCase();
      if (_isNoiseLine(text)) continue;

      for (final kw in grandTotalKeywords) {
        if (lineLower.contains(kw)) {
          final prices = _extractAllEcomPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.reduce(min);
            _debugLog('DEBUG [ecom]: Found grand total "$kw" → $bestAmount');
            break;
          }
        }
      }
      if (bestAmount != null) break;
    }

    // Plain "total" pass
    if (bestAmount == null) {
      for (int i = visualLines.length - 1; i >= 0; i--) {
        final text = _lineText(visualLines[i]);
        final lineLower = text.toLowerCase();
        if (_isNoiseLine(text)) continue;
        if (ignoreTotalKeywords.any((kw) => lineLower.contains(kw))) continue;

        if (lineLower.contains('total')) {
          final prices = _extractAllEcomPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.reduce(min);
            _debugLog('DEBUG [ecom]: Found "total" → $bestAmount');
            break;
          }
        }
      }
    }

    // "paid" / "amount" pass
    if (bestAmount == null) {
      for (int i = visualLines.length - 1; i >= 0; i--) {
        final text = _lineText(visualLines[i]);
        final lineLower = text.toLowerCase();
        if (_isNoiseLine(text)) continue;

        if (lineLower.contains('paid') || lineLower.contains('amount')) {
          if (strikethroughKeywords.any((kw) => lineLower.contains(kw))) continue;
          final prices = _extractAllEcomPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.reduce(min);
            _debugLog('DEBUG [ecom]: Found "paid/amount" → $bestAmount');
            break;
          }
        }
      }
    }

    // ── Sub-expense (item) extraction ────────────────────────────────────────
    // Row-based, not block-based: real screenshots do NOT reliably keep a
    // product's name and price in the same ML Kit TextBlock. See
    // _extractItemsFromRows for why.
    subExpenses = _extractItemsFromRows(visualLines);

    // Also extract delivery/shipping as a sub-expense (if present)
    final deliveryTitleAdded = <String>{};
    for (var line in visualLines) {
      final text = _lineText(line);
      final lineLower = text.toLowerCase();
      if (lineLower.contains('delivery') || lineLower.contains('shipping') || lineLower.contains('handling')) {
        if (lineLower.contains('free') || lineLower.contains('₹0') || lineLower.contains('rs 0') || lineLower.contains('rs.0')) continue;
        final prices = _extractAllEcomPrices(text);
        if (prices.isNotEmpty && prices.last > 0 && deliveryTitleAdded.add('Delivery / Shipping')) {
          subExpenses.add({'title': 'Delivery / Shipping', 'amount': prices.last});
        }
      }
    }

    // ── Fallback total ──────────────────────────────────────────────────────
    if (bestAmount == null) {
      bestAmount = _fallbackTotal(visualLines, subExpenses);
    }

    return (bestAmount, storeName, subExpenses);
  }


  // ═══════════════════════════════════════════════════════════════════════════
  //  STRATEGY 3: QUICK COMMERCE (Zepto, Blinkit, Instamart, etc.)
  // ═══════════════════════════════════════════════════════════════════════════

  // ═══════════════════════════════════════════════════════════════════════════
  //  STRATEGY 3: QUICK COMMERCE (Zepto, Blinkit, Instamart, etc.)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Extracts the last contiguous number from a string, even without a
  /// currency symbol. Useful for explicit keyword lines like "To Pay 490" or
  /// "Total Bill 495 350" (where ₹ was dropped entirely by OCR).
  static double? _extractLastBareNumber(String text) {
    final matches = RegExp(r'\d[\d,]*(?:[.,]\d{1,2})?').allMatches(text);
    if (matches.isEmpty) return null;
    final last = matches.last.group(0) ?? '';
    return _extractPrice(last);
  }

  static (double?, String?, List<Map<String, dynamic>>) _parseQuickCommerceBill(
    List<List<TextElement>> visualLines, String fullText, RecognizedText recognized,
  ) {
    double? bestAmount;
    String? storeName;
    List<Map<String, dynamic>> subExpenses = [];

    // ── Platform name ───────────────────────────────────────────────────────
    final lower = fullText.toLowerCase();
    const platforms = {
      'zepto': 'Zepto', 'blinkit': 'Blinkit', 'instamart': 'Swiggy Instamart',
      'bigbasket': 'BigBasket', 'dunzo': 'Dunzo', 'jiomart': 'JioMart',
      'bb now': 'BigBasket Now', 'grofers': 'Blinkit', 'zomato': 'Zomato', 'swiggy': 'Swiggy',
    };
    for (final entry in platforms.entries) {
      if (lower.contains(entry.key)) {
        storeName = entry.value;
        break;
      }
    }

    // ── Total extraction ────────────────────────────────────────────────────
    final grandTotalKeywords = ['grand total', 'bill total', 'total bill', 'to pay', 'amount paid',
      'paid via', 'total payable', 'you pay', 'total amount', 'order total'];
    final ignoreTotalKeywords = ['item total', 'items total', 'sub total', 'subtotal', 'cart value'];

    for (int i = visualLines.length - 1; i >= 0; i--) {
      final text = _lineText(visualLines[i]);
      final lineLower = text.toLowerCase();
      if (_isNoiseLine(text)) continue;

      for (final kw in grandTotalKeywords) {
        if (lineLower.contains(kw)) {
          // Try strict price first, fallback to bare number
          final prices = _extractAllEcomPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.last;
            _debugLog('DEBUG [qcom]: Found grand total (strict) "$kw" → $bestAmount');
            break;
          } else {
            final bare = _extractLastBareNumber(text);
            if (bare != null && !_isNoiseNumber(bare)) {
              bestAmount = bare;
              _debugLog('DEBUG [qcom]: Found grand total (bare) "$kw" → $bestAmount');
              break;
            }
          }
        }
      }
      if (bestAmount != null) break;
    }

    // Fallback: plain "total"
    if (bestAmount == null) {
      for (int i = visualLines.length - 1; i >= 0; i--) {
        final text = _lineText(visualLines[i]);
        final lineLower = text.toLowerCase();
        if (_isNoiseLine(text)) continue;
        if (ignoreTotalKeywords.any((kw) => lineLower.contains(kw))) continue;

        if (lineLower.contains('total')) {
          final prices = _extractAllEcomPrices(text);
          if (prices.isNotEmpty) {
            bestAmount = prices.last;
            _debugLog('DEBUG [qcom]: Found "total" (strict) → $bestAmount');
            break;
          } else {
            final bare = _extractLastBareNumber(text);
            if (bare != null && !_isNoiseNumber(bare)) {
              bestAmount = bare;
              _debugLog('DEBUG [qcom]: Found "total" (bare) → $bestAmount');
              break;
            }
          }
        }
      }
    }

    // ── Sub-expense (item) extraction ────────────────────────────────────────
    // Row-based, not block-based — see _extractItemsFromRows.
    subExpenses = _extractItemsFromRows(visualLines);

    // ── Extract fees as separate sub-expenses ───────────────────────────────
    final feeKeywords = {
      'delivery charge': 'Delivery Charge',
      'delivery fee': 'Delivery Fee',
      'handling fee': 'Handling Fee',
      'handling charge': 'Handling Charge',
      'platform fee': 'Platform Fee',
      'surge fee': 'Surge Fee',
      'rain fee': 'Rain Fee',
      'packaging': 'Packaging Fee',
      'convenience fee': 'Convenience Fee',
      'small cart fee': 'Small Cart Fee',
      'small cart charge': 'Small Cart Charge',
      'small order fee': 'Small Order Fee',
    };

    for (var line in visualLines) {
      final text = _lineText(line);
      final lineLowerText = text.toLowerCase();
      if (lineLowerText.contains('free') || lineLowerText.contains('waived')) continue;

      for (final entry in feeKeywords.entries) {
        if (lineLowerText.contains(entry.key)) {
          // Try strict price, then bare number
          double? feePrice;
          final prices = _extractAllEcomPrices(text);
          if (prices.isNotEmpty) {
            feePrice = prices.last;
          } else {
            final bare = _extractLastBareNumber(text);
            if (bare != null && !_isNoiseNumber(bare)) feePrice = bare;
          }

          if (feePrice != null && feePrice > 0) {
            final alreadyAdded = subExpenses.any((s) => s['title'] == entry.value);
            if (!alreadyAdded) {
              subExpenses.add({'title': entry.value, 'amount': feePrice});
              _debugLog('DEBUG [qcom]: Added fee → "${entry.value}" = $feePrice');
            }
          }
          break;
        }
      }
    }

    // ── Fallback total ──────────────────────────────────────────────────────
    if (bestAmount == null) {
      bestAmount = _fallbackTotal(visualLines, subExpenses);
    }

    return (bestAmount, storeName, subExpenses);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  FALLBACK TOTAL (shared)
  // ═══════════════════════════════════════════════════════════════════════════

  static double? _fallbackTotal(List<List<TextElement>> visualLines, List<Map<String, dynamic>> subExpenses) {
    // Strategy 1: Sum of sub-expenses
    if (subExpenses.isNotEmpty) {
      final sum = subExpenses.fold<double>(0.0, (s, e) => s + (e['amount'] as double));
      if (sum > 0) {
        _debugLog('DEBUG [fallback]: Using sub-expense sum → $sum');
        return sum;
      }
    }

    // Strategy 2: Last price on the last line that has a currency symbol
    for (int i = visualLines.length - 1; i >= 0; i--) {
      final text = _lineText(visualLines[i]);
      if (_isNoiseLine(text)) continue;
      // Only consider lines with an actual currency indicator
      if (RegExp(r'[₹$£€]|Rs|INR', caseSensitive: false).hasMatch(text)) {
        final prices = _extractAllPrices(text);
        if (prices.isNotEmpty) {
          _debugLog('DEBUG [fallback]: Last currency line → ${prices.last}');
          return prices.last;
        }
      }
    }

    // Strategy 3: (last resort) largest price found anywhere — but not above 50000
    List<double> allPrices = [];
    for (var line in visualLines) {
      final text = _lineText(line);
      if (_isNoiseLine(text)) continue;
      allPrices.addAll(_extractAllPrices(text));
    }
    allPrices = allPrices.where((p) => p <= 50000).toList();
    if (allPrices.isNotEmpty) {
      final maxPrice = allPrices.reduce(max);
      _debugLog('DEBUG [fallback]: Max price → $maxPrice');
      return maxPrice;
    }

    return null;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  SUBSET SUM FILTER (shared post-processing)
  // ═══════════════════════════════════════════════════════════════════════════

  static List<Map<String, dynamic>> _subsetSumFilter(List<Map<String, dynamic>> subExpenses, double? total) {
    if (subExpenses.length <= 1 || subExpenses.length > 15) return subExpenses;
    final target = total;
    if (target == null || target <= 0) return subExpenses;

    List<Map<String, dynamic>>? bestSubset;
    for (int i = 1; i < (1 << subExpenses.length); i++) {
      double currentSum = 0;
      List<Map<String, dynamic>> currentSubset = [];
      for (int j = 0; j < subExpenses.length; j++) {
        if ((i & (1 << j)) != 0) {
          currentSum += subExpenses[j]['amount'] as double;
          currentSubset.add(subExpenses[j]);
        }
      }
      if ((currentSum - target).abs() < 1.0) {
        // Prefer the subset with MORE items (more likely the correct one)
        if (bestSubset == null || currentSubset.length > bestSubset.length) {
          bestSubset = currentSubset;
        }
      }
    }
    if (bestSubset != null) {
      _debugLog('DEBUG: Subset Sum matched! Filtered ${subExpenses.length} → ${bestSubset.length} items.');
      return bestSubset;
    }
    return subExpenses;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  OCR FIXES
  // ═══════════════════════════════════════════════════════════════════════════

  /// A leading '7' immediately touching digits is a common OCR misread of a
  /// low-contrast '₹' (e.g. "₹296" → "7296"). It can't be told apart from a
  /// genuinely-leading-7 amount at the single-value level, so the correction
  /// is only ever applied here, validated against how well it reconciles the
  /// item sum with the receipt total.
  static double? _strip7(double amount) {
    final s = amount.toStringAsFixed(2);
    if (!s.startsWith('7')) return null;
    return double.tryParse(s.substring(1));
  }

  static (double, List<Map<String, dynamic>>) _fixRupeeMisread(
    double total,
    List<Map<String, dynamic>> subExpenses,
  ) {
    if (subExpenses.isEmpty) return (total, subExpenses);

    // 1. Every item AND the total share the same misread (e.g. ₹350 → 7350,
    //    ₹28 → 728, across the whole receipt).
    bool allStrippable = true;
    double strippedSum = 0;
    final strippedAll = <Map<String, dynamic>>[];
    for (final exp in subExpenses) {
      final stripped = _strip7(exp['amount'] as double);
      if (stripped == null) {
        allStrippable = false;
        break;
      }
      strippedSum += stripped;
      strippedAll.add({...exp, 'amount': stripped});
    }
    final strippedTotalGlobal = _strip7(total);
    if (allStrippable && strippedTotalGlobal != null && (strippedTotalGlobal - strippedSum).abs() < 1.0) {
      _debugLog('DEBUG: Detected GLOBAL ₹ symbol misread as 7. Correcting all items and total.');
      return (strippedTotalGlobal, strippedAll);
    }

    // 2. Only SOME items are misread (the common real-world case — e.g. one
    //    product's price OCR'd as "7296" while a sibling item and the total
    //    were read correctly). Try stripping each item independently and
    //    keep whichever single correction brings the item sum closest to
    //    the total.
    final sumOriginal = subExpenses.fold<double>(0.0, (s, e) => s + (e['amount'] as double));
    final targetTotal = _strip7(total) ?? total;
    if ((sumOriginal - targetTotal).abs() >= 1.0) {
      double bestDiff = (sumOriginal - targetTotal).abs();
      final candidate = subExpenses.map((e) => Map<String, dynamic>.from(e)).toList();
      bool corrected = false;
      for (int i = 0; i < candidate.length; i++) {
        final stripped = _strip7(candidate[i]['amount'] as double);
        if (stripped == null) continue;
        final trialSum = sumOriginal - (candidate[i]['amount'] as double) + stripped;
        final diff = (trialSum - targetTotal).abs();
        if (diff < bestDiff) {
          bestDiff = diff;
          candidate[i] = {...candidate[i], 'amount': stripped};
          corrected = true;
        }
      }
      if (corrected && bestDiff < 1.0) {
        _debugLog('DEBUG: Corrected a single item\'s ₹ symbol misread as 7 (reconciled against total).');
        return (targetTotal, candidate);
      }
    }

    // 3. Items are already correct; only the total was misread.
    if (sumOriginal > 0) {
      final strippedTotalOnly = _strip7(total);
      if (strippedTotalOnly != null && (strippedTotalOnly - sumOriginal).abs() < 1.0) {
        _debugLog('DEBUG: Detected ₹ symbol misread as 7 on TOTAL ONLY. Correcting $total to $sumOriginal');
        return (sumOriginal, subExpenses);
      }
    }

    return (total, subExpenses);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  CATEGORY SUGGESTION (shared)
  // ═══════════════════════════════════════════════════════════════════════════

  static String? _suggestCategory(String fullText, List<String> availableCategories) {
    final lowerText = fullText.toLowerCase();

    final Map<String, List<String>> categoryKeywords = {
      'Food': [
        'restaurant', 'cafe', 'bistro', 'zomato', 'swiggy', 'pizza', 'burger',
        'kitchen', 'food', 'bakery', 'dhaba', 'biryani', 'dosa', 'thali',
        'zepto', 'blinkit', 'instamart', 'bigbasket', 'jiomart', 'dmart',
        'reliance fresh', 'more supermarket', 'grofers', 'bb now',
        'dunzo', 'bbdaily',
      ],
      'Groceries': [
        'supermarket', 'mart', 'store', 'bazaar', 'grocery', 'dairy',
        'kirana', 'provision', 'general store', 'departmental',
      ],
      'Transport': [
        'uber', 'ola', 'taxi', 'cab', 'transit', 'railway', 'flight',
        'petrol', 'fuel', 'pump', 'rapido', 'metro', 'irctc', 'redbus',
        'makemytrip', 'goibibo', 'namma yatri', 'indigo', 'air india',
        'spicejet', 'vistara', 'cleartrip',
      ],
      'Shopping': [
        'mall', 'apparel', 'clothing', 'shoes', 'electronics',
        'amazon', 'flipkart', 'myntra', 'ajio', 'meesho', 'nykaa',
        'tata cliq', 'snapdeal', 'shopsy', 'croma', 'reliance digital',
      ],
      'Health': [
        'pharmacy', 'hospital', 'clinic', 'medical', 'chemist',
        'pharmeasy', '1mg', 'netmeds', 'apollo', 'practo', 'medplus',
        'wellness', 'healthkart',
      ],
      'Entertainment': [
        'cinema', 'movie', 'pvr', 'inox', 'theatre', 'netflix',
        'bookmyshow', 'paytm insider', 'disney', 'hotstar', 'spotify',
        'youtube', 'prime video', 'jiocinema',
      ],
      'Bills': [
        'recharge', 'airtel', 'jio', 'vodafone', 'vi ', 'bsnl',
        'electricity', 'water', 'gas', 'broadband', 'wifi',
        'insurance', 'lic', 'premium',
      ],
      'Education': [
        'school', 'college', 'university', 'tuition', 'coaching',
        'udemy', 'coursera', 'unacademy', 'byjus', 'vedantu',
      ],
    };

    // The app's actual default categories (see CategoryUtils.defaultCategories)
    // don't match these keyword-group names exactly ("Food" vs "Food & Dining",
    // "Transport" vs "Transportation", etc.) — matching required an exact
    // string equality, so only "Shopping" and "Entertainment" could ever hit.
    // Match on normalized containment instead, against a canonical alias per
    // keyword group, so it still finds the right category regardless of the
    // app's exact label (and works for slightly-renamed custom categories).
    const categoryCanonicalAlias = {
      'Food': 'Food & Dining',
      'Groceries': 'Food & Dining',
      'Transport': 'Transportation',
      'Shopping': 'Shopping',
      'Health': 'Health & Medical',
      'Entertainment': 'Entertainment',
      'Bills': 'Bills & Utilities',
      'Education': 'Education',
    };

    String? matchedCategory;
    for (final entry in categoryKeywords.entries) {
      if (!entry.value.any((keyword) => lowerText.contains(keyword))) continue;
      final alias = categoryCanonicalAlias[entry.key] ?? entry.key;
      final match = availableCategories.where((c) => _categoryNamesMatch(c, alias)).firstOrNull;
      if (match != null) {
        matchedCategory = match;
        break;
      }
    }

    // Direct category name match as fallback
    if (matchedCategory == null) {
      for (final cat in availableCategories) {
        if (lowerText.contains(cat.toLowerCase())) {
          matchedCategory = cat;
          break;
        }
      }
    }

    return matchedCategory;
  }

  static String _normalizeCategoryName(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  static bool _categoryNamesMatch(String a, String b) {
    final na = _normalizeCategoryName(a);
    final nb = _normalizeCategoryName(b);
    if (na.isEmpty || nb.isEmpty) return false;
    return na == nb || na.contains(nb) || nb.contains(na);
  }

  static (double?, String?, List<Map<String, dynamic>>) _parseFoodDeliveryHistory(
    List<List<TextElement>> visualLines, String fullText, RecognizedText recognized,
  ) {
    double? bestAmount;
    String? storeName;
    List<Map<String, dynamic>> subExpenses = [];
    final qtyPattern = RegExp(r'^(\d+)\s*[xX]\s*(.+)$');

    // 1. Total extraction
    // Scan for something that looks like the grand total (e.g. ₹383.40).
    for (int i = visualLines.length - 1; i >= 0; i--) {
      final text = _lineText(visualLines[i]);
      final prices = _extractAllEcomPrices(text);
      if (prices.isNotEmpty) {
        bestAmount = prices.last;
        break; // Assume the bottom-most price is the total in an order history card
      }
    }

    // 2. Store name
    // After "Search by restaurant or dish", the next non-empty, non-noise line is usually the store name.
    bool foundSearch = false;
    for (int i = 0; i < visualLines.length; i++) {
      final text = _lineText(visualLines[i]).trim();
      final lower = text.toLowerCase();
      if (lower.contains('search by restaurant')) {
        foundSearch = true;
        continue;
      }
      if (foundSearch && text.isNotEmpty && text.length > 2 && !_isNoiseLine(text)) {
        storeName = text;
        break;
      }
    }

    // Fallback if "Search by" is not found (maybe cropped)
    if (storeName == null) {
      // Just guess the first line that looks like a name and isn't "Your Orders"
      for (int i = 0; i < visualLines.length; i++) {
        final text = _lineText(visualLines[i]).trim();
        final lower = text.toLowerCase();
        if (lower.contains('your orders') || text.length < 3) continue;
        storeName = text;
        break;
      }
    }

    // 3. Items (subExpenses)
    // Any line matching "1 x Burger" etc.
    for (int i = 0; i < visualLines.length; i++) {
      final text = _lineText(visualLines[i]).trim();
      final match = qtyPattern.firstMatch(text);
      if (match != null) {
        final qtyStr = match.group(1);
        final itemName = match.group(2)?.trim();
        if (itemName != null && itemName.isNotEmpty) {
          subExpenses.add({
            'title': itemName,
            'amount': 0.0, // Order history screens don't show individual item prices
            if (qtyStr != null) 'quantity': int.tryParse(qtyStr) ?? 1,
          });
        }
      }
    }

    return (bestAmount, storeName, subExpenses);
  }

  static void dispose() {
    _textRecognizer.close();
  }
}
