enum MessageType { transaction, promotional, service, otp, other }

class SMSFilter {
  /// Supporting sender identities for Indian banks and common UPI services.
  /// A match here is never sufficient by itself: amount, completed movement,
  /// and transaction context are all still required below.
  static const bankSenderAliases = <String>[
    'sbi',
    'sbin',
    'statebank',
    'pnb',
    'pnbin',
    'bankbaroda',
    'bob',
    'canara',
    'canbk',
    'cbk',
    'cnrb',
    'canarabank',
    'unionbank',
    'uboi',
    'indianbank',
    'idib',
    'iob',
    'centralbank',
    'central bank',
    'central bank of india',
    'cbiind',
    'cbind',
    'bankindia',
    'boi',
    'maharashtra',
    'bom',
    'uco',
    'punjabsind',
    'psib',
    'hdfc',
    'hdfcbk',
    'icici',
    'icicib',
    'axis',
    'axisbk',
    'kotak',
    'kotakb',
    'idfc',
    'idfcfb',
    'idfcfirst',
    'idfcfirstbank',
    'indusind',
    'yesbank',
    'yesbk',
    'federal',
    'federl',
    'rbl',
    'rblbk',
    'bandhan',
    'aubank',
    'equitas',
    'ujjivan',
    'southindian',
    'sib',
    'karnataka',
    'karurvysya',
    'kvb',
    'cityunion',
    'cub',
    'dcbbank',
    'dcb',
    'jammukashmir',
    'tmb',
    'tamilnadmercantile',
    'nainital',
    'saraswat',
    'standardchartered',
    'scb',
    'hsbc',
    'deutsche',
    'dbs',
    'citi',
    'amex',
    'paytm',
    'phonepe',
    'gpay',
    'googlepay',
    'bhim',
    'amazonpay',
    'upi',
  ];
  static MessageType classifyMessage(String message, [String sender = '']) {
    final text = '$sender $message'.toLowerCase();
    if (isOTP(message)) return MessageType.otp;
    if (_hasTraiSuffix(text, 'p')) return MessageType.promotional;
    if (_hasTraiSuffix(text, 's')) return MessageType.service;
    if (_hasTraiSuffix(text, 't')) return MessageType.transaction;
    return MessageType.other;
  }

  static bool isTransactionSMS(String message, [String sender = '']) {
    final type = classifyMessage(message, sender);
    if (isOTP(message)) return false;
    if (isScheduledDebit(message)) return false;
    if (_containsAny(message, _rejectKeywords)) return false;
    if (type == MessageType.promotional) return false;
    // Do not allow an unrelated service sender to borrow a bank name from the
    // message body. Actual HDFC-style service alerts still pass because their
    // sender itself contains the recognised bank identity.
    if (type == MessageType.service &&
        _hasTraiSuffix(sender.toLowerCase(), 's') &&
        !_senderLooksLikeBank(sender)) {
      return false;
    }

    // Sender suffixes are useful signals but not the source of truth. Banks
    // such as Canara can deliver verified transaction SMS without a visible
    // DLT suffix, often using `Dr.` or `Cr.` shorthand.
    final hasAmount = _hasAmount(message);
    final hasMovement = hasDebitSignal(message) || hasCreditSignal(message);
    final hasBankContext = _containsAny('$sender $message', const [
      'bank',
      'a/c',
      'acct',
      'account',
      'upi',
      'imps',
      'neft',
      'rtgs',
      'utr',
      'reference',
      'txn',
      'transaction',
    ]);
    if (!(hasAmount && hasBankContext)) return false;

    final bankSource = _senderLooksLikeBank(sender) ||
        _containsAny(message, bankSenderAliases);
    final hasTransactionReference = _containsAny(message, const [
      'upi',
      'utr',
      'ref no',
      'reference',
      'transaction id',
      'txn id',
      'imps',
      'neft',
      'rtgs',
    ]);

    // Bank wording varies widely. A strong sender plus an amount and a UPI or
    // reference signal is enough to create a review-only candidate even when
    // a debit/credit verb is absent. Plain account-balance messages still
    // fail because they do not carry a transaction reference or movement.
    if (!hasMovement && !hasTransactionReference) return false;
    if (type == MessageType.transaction) return true;

    // Physical devices normally expose the bank sender ID. Android emulators
    // use a numeric sender, though, and some notification sources expose the
    // bank name only in their visible text. Permit that source only when the
    // message has already passed every completed-transaction safety check.
    return bankSource;
  }

  static bool isOTP(String message) => _containsAny(message, const [
        'otp',
        'one time password',
        'verification code',
        'login code',
        'security code',
      ]);

  /// A mandate reminder is not proof that money has moved. A later completed
  /// debit alert will contain a past-tense debit/Dr signal and can be reviewed.
  static bool isScheduledDebit(String message) => _containsAny(message, const [
        'will be deducted',
        'will be debited',
        'scheduled to be deducted',
        'scheduled to be debited',
        'e-mandate',
        'emandate',
        'mandate due',
      ]);

  static bool _hasTraiSuffix(String text, String suffix) {
    final escaped = RegExp.escape(suffix);
    // DLT sender IDs are commonly displayed as `JD-HDFCBK-T`. The suffix is
    // part of the sender header, so it must be allowed after an alphanumeric
    // bank identifier while still ending at a non-alphanumeric boundary.
    return RegExp('-$escaped(?:[^a-z0-9]|\$)', caseSensitive: false)
        .hasMatch(text);
  }

  static bool _containsAny(String message, List<String> keywords) {
    final lower = message.toLowerCase();
    return keywords.any(lower.contains);
  }

  static bool _hasAmount(String message) =>
      RegExp(r'(?:rs\.?|inr|₹)\s*[0-9]', caseSensitive: false)
          .hasMatch(message);

  static bool hasDebitSignal(String message) =>
      _containsAny(message, debitKeywords) ||
      RegExp(r'\bdr\.?\s*(?:inr|rs\.?|₹|[0-9])', caseSensitive: false)
          .hasMatch(message);

  static bool hasCreditSignal(String message) =>
      _containsAny(message, creditKeywords) ||
      RegExp(r'\bcr\.?\s*(?:inr|rs\.?|₹|[0-9])', caseSensitive: false)
          .hasMatch(message);

  static bool _senderLooksLikeBank(String sender) =>
      _containsAny(sender, bankSenderAliases) ||
      sender.toLowerCase().contains('bank');

  static const debitKeywords = [
    'debited',
    'debit',
    'deducted',
    ' dr.',
    ' dr ',
    'spent',
    'paid',
    'transferred',
    'transfer',
    'sent',
    'withdrawn',
    'withdrawal',
    'purchase',
    'upi payment',
  ];

  static const creditKeywords = [
    'credited',
    'credit',
    ' cr.',
    ' cr ',
    'received',
    'deposited',
    'deposit',
    'refund',
    'reversed',
    'cashback',
  ];

  static const _rejectKeywords = [
    'loan offer',
    'pre-approved',
    'cashback offer',
    'subscribe',
    'subscription renewed',
    'renewal',
    'sale',
    'discount',
    'apply now',
    'limited period',
    'failed',
    'failure',
    'declined',
    'unsuccessful',
    'pending payment',
    'payment request',
    'collect request',
    'request money',
    'mandate request',
  ];
}
