import 'package:telephony/telephony.dart';

import '../models/pending_transaction_model.dart';
import '../models/transaction_model.dart';
import 'local_intelligence_service.dart';
import '../utils/sms_filters.dart';

class SMSParser {
  PendingTransaction? parseRawMessage({
    required String body,
    String sender = '',
    DateTime? receivedAt,
  }) {
    if (!SMSFilter.isTransactionSMS(body, sender)) return null;
    final amount = extractAmount(body);
    if (amount == null) return null;
    final referenceNumber = extractReferenceNumber(body);
    final merchant = extractMerchant(body, sender, referenceNumber);
    final type =
        isReceived(body) ? TransactionType.income : TransactionType.expense;
    final timestamp = receivedAt ?? DateTime.now();
    final confidence = calculateConfidence(body, amount, merchant, sender);
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return PendingTransaction(
      id: id,
      rawSms: body,
      detectedAt: DateTime.now(),
      needsReview: true,
      transaction: TrackrTransaction(
        id: id,
        type: type,
        amount: amount,
        description: merchant,
        categoryId: autoCategorize(merchant, amount, type, body),
        dateTime:
            extractTransactionDate(body, timestamp.millisecondsSinceEpoch),
        upiApp: detectUPIApp('$sender $body'),
        bankName: extractBankName(sender, body),
        accountLastDigits: extractAccountLastDigits(body),
        referenceNumber: referenceNumber,
        isAutoDetected: true,
        confidence: confidence,
      ),
    );
  }

  String transactionFingerprint(TrackrTransaction transaction) {
    final reference = transaction.referenceNumber;
    if (reference != null && reference.isNotEmpty) {
      return 'ref:${reference.toLowerCase()}';
    }
    return _fallbackFingerprint(transaction);
  }

  /// A durable, reference-free identity for the uncommon bank alert that does
  /// not include UPI Ref/UTR. It lets a resolved alert stay resolved when a
  /// bank resends it with a different SMS delivery timestamp.
  String transactionIdentity(TrackrTransaction transaction) {
    final bank = (transaction.bankName ?? '').toLowerCase().trim();
    final account = transaction.accountLastDigits ?? '';
    final merchant = LocalIntelligenceService.merchantKey(transaction.description);
    return '${transaction.type.name}|${transaction.amount.toStringAsFixed(2)}|$merchant|$bank|$account';
  }

  /// Uses a bank reference whenever both records have one. If a bank omitted
  /// the reference in one copy of an alert, fall back to its money movement
  /// details so confirmed history cannot return to Pending.
  bool isSameTransaction(
      TrackrTransaction first, TrackrTransaction second) {
    final firstReference = first.referenceNumber?.trim().toLowerCase() ?? '';
    final secondReference = second.referenceNumber?.trim().toLowerCase() ?? '';
    if (firstReference.isNotEmpty && secondReference.isNotEmpty) {
      return firstReference == secondReference;
    }
    return _fallbackFingerprint(first) == _fallbackFingerprint(second);
  }

  String _fallbackFingerprint(TrackrTransaction transaction) {
    final date = transaction.dateTime;
    return 'fallback:${transactionIdentity(transaction)}|${date.year}-${date.month}-${date.day}';
  }

  PendingTransaction? parseUPISMS(SmsMessage message) {
    final body = message.body ?? '';
    final sender = message.address ?? '';
    return parseRawMessage(
      body: body,
      sender: sender,
      receivedAt: message.date == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(message.date!),
    );
  }

  double? extractAmount(String body) {
    final patterns = [
      RegExp(r'amount\s*[:.-]?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false),
      RegExp(r'(?:debit|credit)\s*[:.-]?\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false),
      RegExp(r'(?:inr|rs\.?|₹)\s*([0-9,]+(?:\.[0-9]{1,2})?)',
          caseSensitive: false),
      RegExp(r'([0-9,]+(?:\.[0-9]{1,2})?)\s*(?:inr|rs\.?|₹)',
          caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null)
        return double.tryParse(match.group(1)!.replaceAll(',', ''));
    }
    return null;
  }

  DateTime extractTransactionDate(String body, int? smsTimestamp) {
    final contextualMatch = RegExp(
      r'(?:on|dated|date)\s*[:.-]?\s*(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})',
      caseSensitive: false,
    ).firstMatch(body);
    final match = contextualMatch ??
        RegExp(r'\b(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})\b')
            .firstMatch(body);
    final fallback = smsTimestamp == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(smsTimestamp);
    if (match == null) {
      final namedDate = RegExp(
        r'(?:on|dated|date)\s*[:.-]?\s*(\d{1,2})\s+([a-z]{3,9})\s+(\d{2,4})',
        caseSensitive: false,
      ).firstMatch(body) ??
          RegExp(r'\b(\d{1,2})\s+([a-z]{3,9})\s+(\d{2,4})\b',
                  caseSensitive: false)
              .firstMatch(body);
      if (namedDate == null) return fallback;
      final month = _monthNumber(namedDate.group(2)!);
      final day = int.tryParse(namedDate.group(1)!);
      final rawYear = int.tryParse(namedDate.group(3)!);
      if (month == null || day == null || rawYear == null) return fallback;
      final year = rawYear < 100 ? 2000 + rawYear : rawYear;
      final time = _extractTransactionTime(body, fallback);
      final parsed = DateTime(year, month, day, time.hour, time.minute);
      return parsed.year == year && parsed.month == month && parsed.day == day
          ? parsed
          : fallback;
    }

    final day = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    final rawYear = int.tryParse(match.group(3)!);
    if (day == null || month == null || rawYear == null) return fallback;

    final year = rawYear < 100 ? 2000 + rawYear : rawYear;
    final time = _extractTransactionTime(body, fallback);
    final parsed = DateTime(year, month, day, time.hour, time.minute);
    // DateTime normalizes invalid dates, so reject values such as 31/02/26.
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return fallback;
    }
    return parsed;
  }

  int? _monthNumber(String value) {
    const months = {
      'jan': 1,
      'feb': 2,
      'mar': 3,
      'apr': 4,
      'may': 5,
      'jun': 6,
      'jul': 7,
      'aug': 8,
      'sep': 9,
      'oct': 10,
      'nov': 11,
      'dec': 12,
    };
    return months[value.trim().toLowerCase().substring(0, 3)];
  }

  DateTime _extractTransactionTime(String body, DateTime fallback) {
    final twelveHour = RegExp(
      r'(?:at|time)\s*[:.-]?\s*(\d{1,2}):(\d{2})\s*(am|pm)',
      caseSensitive: false,
    ).firstMatch(body);
    if (twelveHour != null) {
      var hour = int.tryParse(twelveHour.group(1)!) ?? fallback.hour;
      final minute = int.tryParse(twelveHour.group(2)!) ?? fallback.minute;
      final period = twelveHour.group(3)!.toLowerCase();
      if (hour == 12) hour = 0;
      if (period == 'pm') hour += 12;
      if (hour <= 23 && minute <= 59) {
        return DateTime(
            fallback.year, fallback.month, fallback.day, hour, minute);
      }
    }
    final twentyFourHour = RegExp(
      r'(?:at|time)\s*[:.-]?\s*([01]?\d|2[0-3]):([0-5]\d)',
      caseSensitive: false,
    ).firstMatch(body);
    if (twentyFourHour != null) {
      return DateTime(
        fallback.year,
        fallback.month,
        fallback.day,
        int.parse(twentyFourHour.group(1)!),
        int.parse(twentyFourHour.group(2)!),
      );
    }
    final standaloneTime =
        RegExp(r'\b([01]?\d|2[0-3]):([0-5]\d)\b').firstMatch(body);
    if (standaloneTime != null) {
      return DateTime(
        fallback.year,
        fallback.month,
        fallback.day,
        int.parse(standaloneTime.group(1)!),
        int.parse(standaloneTime.group(2)!),
      );
    }
    return fallback;
  }

  String extractMerchant(String body, [String sender = '', String? reference]) {
    final patterns = [
      RegExp(
          r'(?:paid to|sent to|transfer(?:red)? to|to|at)\s+([a-z0-9 .&_-]{3,60})',
          caseSensitive: false),
      RegExp(r'(?:from|received from|credited from)\s+([a-z0-9 .&_-]{3,40})',
          caseSensitive: false),
      RegExp(r'upi[:\s]+([a-z0-9._-]{3,40})', caseSensitive: false),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(body);
      if (match != null) return _clean(match.group(1)!);
    }
    if (sender.toLowerCase().contains('can')) {
      return reference == null
          ? 'Canara Bank Transaction'
          : 'Canara Bank Transaction $reference';
    }
    return 'UPI Transaction';
  }

  UpiApp detectUPIApp(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('gpay') || lower.contains('google pay'))
      return UpiApp.gpay;
    if (lower.contains('phonepe')) return UpiApp.phonePe;
    if (lower.contains('paytm')) return UpiApp.paytm;
    if (lower.contains('bhim')) return UpiApp.bhim;
    return UpiApp.other;
  }

  bool isReceived(String body) {
    return SMSFilter.hasCreditSignal(body) && !SMSFilter.hasDebitSignal(body);
  }

  String? extractBankName(String sender, String body) {
    final source = '$sender $body';
    final match = RegExp(
      r'\b(canara|hdfc|icici|sbi|state bank|axis|kotak|indusind|idfc|federal|yes bank|pnb|punjab national|bank of baroda|union bank|central bank)\b',
      caseSensitive: false,
    ).firstMatch(source);
    if (match == null) return null;
    final value = match.group(1)!;
    return '${value[0].toUpperCase()}${value.substring(1).toLowerCase()} Bank';
  }

  String? extractAccountLastDigits(String body) {
    final match = RegExp(
      r'(?:a/c|acct|account)\s*[:#-]?\s*(?:x+|\*+)?\s*(\d{3,6})',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1);
  }

  String? extractReferenceNumber(String body) {
    final match = RegExp(
      r'(?:upi\s*(?:ref(?:erence)?|id)?|utr|ref(?:erence)?(?:\s*(?:no|number))?|txn(?:\s*id)?)\s*[:#.-]?\s*([a-z0-9]{6,})',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1)?.toUpperCase();
  }

  String autoCategorize(
    String merchant,
    double amount,
    TransactionType type, [
    String context = '',
  ]) {
    final learned = LocalIntelligenceService.instance.categoryFor(merchant);
    if (learned != null) return learned;
    final lower = '$merchant $context'.toLowerCase();
    if (type == TransactionType.income) return 'salary';

    if (_matches(lower, const [
      'zomato',
      'swiggy',
      'dominos',
      'pizza hut',
      'mcdonald',
      'kfc',
      'restaurant',
      'cafe',
      'bakery',
      'starbucks',
      'eatfit'
    ])) return 'food';
    if (_matches(lower, const [
      'dmart',
      'grocery',
      'supermarket',
      'bigbasket',
      'blinkit',
      'zepto',
      'instamart',
      'reliance retail',
      'more retail',
      'spencer'
    ])) return 'groceries';
    if (_matches(lower, const [
      'uber',
      'ola',
      'rapido',
      'metro',
      'namma yatri',
      'nammayatri',
      'in drive',
      'indrive',
      'blusmart',
      'yulu',
      'bounce',
      'bike taxi',
      'rental bike',
      'auto fare',
      'auto rickshaw',
      'bus',
      'redbus',
      'abhibus',
      'local train',
      'commute'
    ])) return 'commute';
    if (_matches(lower, const [
      'petrol',
      'fuel',
      'hpcl',
      'iocl',
      'indian oil',
      'bpcl',
      'bharat petroleum'
    ])) return 'fuel';
    if (_matches(lower, const [
      'amazon',
      'flipkart',
      'myntra',
      'ajio',
      'meesho',
      'nykaa'
    ])) return 'shopping';
    if (_matches(lower, const [
      'netflix',
      'prime video',
      'hotstar',
      'spotify',
      'youtube premium',
      'sony liv'
    ])) return 'subscriptions';
    if (_matches(lower, const ['pvr', 'inox', 'bookmyshow', 'cinema', 'movie']))
      return 'entertainment';
    if (_matches(lower, const [
      'airtel',
      'jio',
      'vodafone',
      'vi prepaid',
      'bsnl',
      'broadband',
      'electricity',
      'water bill',
      'gas bill',
      'utility'
    ])) return 'bills';
    if (_matches(lower, const [
      'apollo',
      'pharmacy',
      'medplus',
      '1mg',
      'tata 1mg',
      'hospital',
      'clinic'
    ])) return 'healthcare';
    if (_matches(lower, const [
      'makemytrip',
      'goibibo',
      'cleartrip',
      'yatra',
      'indigo',
      'air india',
      'irctc'
    ])) return 'travel';
    if (_matches(lower, const ['cult fit', 'cultfit', 'gym', 'fitness']))
      return 'fitness';
    if (_matches(lower, const [
      'udemy',
      'coursera',
      'unacademy',
      'byju',
      'school',
      'college',
      'tuition'
    ])) return 'education';
    if (_matches(lower, const [
      'groww',
      'zerodha',
      'coin by zerodha',
      'kuvera',
      'mutual fund'
    ])) return 'mutual_funds';
    if (_matches(
        lower, const ['lic', 'policybazaar', 'insurance premium', 'hdfc ergo']))
      return 'insurance';
    if (_looksLikePerson(merchant)) return 'friends';
    if (amount > 25000) return 'rent';
    return 'uncategorized';
  }

  bool _matches(String text, List<String> values) => values.any(text.contains);

  bool _looksLikePerson(String merchant) {
    final normalized = merchant.trim().toLowerCase();
    return normalized.startsWith('mr ') ||
        normalized.startsWith('mrs ') ||
        normalized.startsWith('ms ') ||
        normalized.startsWith('shri ') ||
        normalized.startsWith('smt ');
  }

  double calculateConfidence(
      String body, double amount, String merchant, String sender) {
    var score = .72;
    if (SMSFilter.classifyMessage(body, sender) == MessageType.transaction)
      score += .12;
    final isCanara = SMSFilter.bankSenderAliases
        .where((value) =>
            value.startsWith('can') || value == 'cbk' || value == 'cnrb')
        .any(sender.toLowerCase().contains);
    if (isCanara) score += .10;
    if (body.toLowerCase().contains('upi')) score += .06;
    if (amount > 0) score += .05;
    if (merchant != 'UPI Transaction') score += .05;
    if (SMSFilter.classifyMessage(body, sender) != MessageType.transaction) {
      score *= .7;
    }
    return score.clamp(.5, 1);
  }

  String _clean(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(
            RegExp(r'\b(?:on|ref|upi|txn)\b.*$', caseSensitive: false), '')
        .trim()
        .replaceFirst(RegExp(r'[.;,:-]+$'), '');
  }
}
