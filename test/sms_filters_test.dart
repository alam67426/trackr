import 'package:flutter_test/flutter_test.dart';
import 'package:trackr/models/transaction_model.dart';
import 'package:trackr/services/sms_parser.dart';
import 'package:trackr/utils/sms_filters.dart';

void main() {
  const hdfcTransaction = '''Sent Rs.1.00
From HDFC Bank A/C *9091
To MR MD AFTAB ALAM
On 31/07/26
Ref 657843118689''';
  const canaraCredit = '''Dear Customer, Acct XXXX2476 Dr. INR 10.00
on 31/07/26 to MR MD AFTAB ALAM UPI:
657826523976; Bal INR 900.00''';

  test('accepts a transactional HDFC sender with a trailing T suffix', () {
    expect(SMSFilter.classifyMessage(hdfcTransaction, 'JD-HDFCBK-T'),
        MessageType.transaction);
    expect(SMSFilter.isTransactionSMS(hdfcTransaction, 'JD-HDFCBK-T'), isTrue);
  });

  test('accepts HDFC service-suffix account transaction alerts', () {
    expect(SMSFilter.isTransactionSMS(hdfcTransaction, 'AD-HDFCBK-S'), isTrue);
  });

  test('rejects promotional and unrelated service sender suffixes', () {
    expect(SMSFilter.isTransactionSMS(hdfcTransaction, 'JD-HDFCBK-P'), isFalse);
    expect(SMSFilter.isTransactionSMS(hdfcTransaction, 'AD-STREAM-S'), isFalse);
  });

  test('requires both an amount and a money movement phrase for -T SMS', () {
    expect(SMSFilter.isTransactionSMS('Your UPI offer is ready', 'VM-TRACKR-T'),
        isFalse);
    expect(
        SMSFilter.isTransactionSMS(
            'Rs.500 has been debited from A/C', 'VM-BANK-T'),
        isTrue);
  });

  test('categorizes common merchants and person-to-person payments', () {
    final parser = SMSParser();
    expect(parser.autoCategorize('Swiggy Order', 420, TransactionType.expense),
        'food');
    expect(parser.autoCategorize('Amazon India', 1200, TransactionType.expense),
        'shopping');
    expect(
        parser.autoCategorize('MR MD AFTAB ALAM', 1, TransactionType.expense),
        'friends');
  });

  test('groups ride, metro, bus, auto, and bike payments as commute', () {
    final parser = SMSParser();
    for (final merchant in const [
      'Uber Trip',
      'Ola Money',
      'Rapido Bike Taxi',
      'Namma Yatri',
      'Metro Rail',
      'Redbus',
      'Auto Rickshaw',
      'Yulu Bike',
    ]) {
      expect(parser.autoCategorize(merchant, 120, TransactionType.expense),
          'commute');
    }
  });

  test('uses the transaction date written in an HDFC SMS', () {
    final date = SMSParser().extractTransactionDate(hdfcTransaction, null);
    expect(date.year, 2026);
    expect(date.month, 7);
    expect(date.day, 31);
  });

  test('accepts a Canara debit without depending on a TRAI sender suffix', () {
    final parser = SMSParser();
    expect(SMSFilter.isTransactionSMS(canaraCredit, 'Canara Bank'), isTrue);
    expect(parser.extractAmount(canaraCredit), 10);
    expect(parser.extractAccountLastDigits(canaraCredit), '2476');
    expect(parser.extractReferenceNumber(canaraCredit), '657826523976');
  });

  test('parses Canara merchant, confidence, and named month date formats', () {
    final parser = SMSParser();
    const message =
        'Rs. 500.00 debited from A/c XXXX2476 to Zomato on 31 Jul 2026 10:15.';
    expect(parser.extractMerchant(message, 'CANBK'), 'Zomato');
    expect(parser.extractTransactionDate(message, null),
        DateTime(2026, 7, 31, 10, 15));
    expect(parser.calculateConfidence(message, 500, 'Zomato', 'CANBK'),
        greaterThanOrEqualTo(.5));
  });

  test('rejects failed payments, collection requests, and OTPs', () {
    expect(
        SMSFilter.isTransactionSMS(
            'Your UPI payment of INR 500 failed', 'BANK-T'),
        isFalse);
    expect(
        SMSFilter.isTransactionSMS('UPI collect request for INR 500', 'BANK-T'),
        isFalse);
    expect(
        SMSFilter.isTransactionSMS(
            'OTP 123456 for payment of INR 500', 'BANK-T'),
        isFalse);
  });

  test('rejects future e-mandate deduction reminders', () {
    expect(
        SMSFilter.isTransactionSMS(
            'E-Mandate: Rs. 1499 will be deducted on 04/08/26 for Google Play mandate',
            'AD-HDFCBK-S'),
        isFalse);
  });

  test('accepts IDFC debit and credit messages with bank sender aliases', () {
    const debit =
        'Your A/c XX2254 debited by Rs. 500.00 to Abdul Gaffar on 31-07-2026 13:39.';
    const credit =
        'Your A/C XXXXX142254 is credited with Rs. 500.00 from Abdul Gaffar on 31-07-2026 14:40.';
    final parser = SMSParser();
    expect(SMSFilter.isTransactionSMS(debit, 'VM-IDFCFB'), isTrue);
    expect(SMSFilter.isTransactionSMS(credit, 'IDFC First Bank'), isTrue);
    expect(parser.extractAmount(debit), 500);
    expect(parser.extractMerchant(debit, 'VM-IDFCFB'), 'Abdul Gaffar');
    expect(parser.isReceived(credit), isTrue);
  });

  test('recognises completed account movement vocabulary and Dr/Cr shorthand',
      () {
    expect(
        SMSFilter.isTransactionSMS('A/c XX12 deducted by INR 50.00', 'CANBK'),
        isTrue);
    expect(SMSFilter.isTransactionSMS('A/c XX12 Dr INR 50.00 UPI', 'CANBK'),
        isTrue);
    expect(
        SMSFilter.isTransactionSMS(
            'A/c XX12 Cr. Rs. 50.00 deposited', 'IDFCFB'),
        isTrue);
    expect(SMSParser().isReceived('A/c XX12 Cr. Rs. 50.00 deposited'), isTrue);
  });

  test('accepts a bank name in an emulator-delivered message body', () {
    const message =
        'Bandhan Bank: A/c XX1234 Cr. INR 5,000.00 on 01/08/2026 from Freelance. UPI Ref 3000000010';
    final parsed = SMSParser().parseRawMessage(body: message, sender: '5556');
    expect(parsed, isNotNull);
    expect(parsed!.transaction.type, TransactionType.income);
    expect(parsed.transaction.amount, 5000);
    expect(parsed.transaction.referenceNumber, '3000000010');
  });

  test('parses a Central Bank standard debit with a numeric emulator sender', () {
    const message =
        'Central Bank of India: A/c XX6789 debited by Rs. 1,500.00 on 01-08-2026 at 14:30 to Amazon. UPI Ref 4000000001';
    final parsed = SMSParser().parseRawMessage(body: message, sender: '5556');
    expect(parsed, isNotNull);
    expect(parsed!.transaction.type, TransactionType.expense);
    expect(parsed.transaction.amount, 1500);
    expect(parsed.transaction.description, 'Amazon');
    expect(parsed.transaction.referenceNumber, '4000000001');
    expect(parsed.transaction.dateTime, DateTime(2026, 8, 1, 14, 30));
  });

  test('accepts the HDFC service-suffix transaction alert from Messages', () {
    const message = '''Sent Rs.1.00
From HDFC Bank A/C *9091
To MR MD AFTAB ALAM
On 31/07/26
Ref 657875392989''';
    expect(SMSFilter.isTransactionSMS(message, 'AD-HDFCBK-S'), isTrue);
    final parsed = SMSParser().parseRawMessage(
        body: message, sender: 'AD-HDFCBK-S');
    expect(parsed, isNotNull);
    expect(parsed!.transaction.amount, 1);
    expect(parsed.transaction.type, TransactionType.expense);
  });

  test('accepts the Central Bank credit alert from Messages', () {
    const message =
        'A/c XX5664 credited by Rs. 1.00 on 31/07/2026 via UPI from MR AFTAB ALAM via Ref No. 657849890346. -CBol';
    expect(SMSFilter.isTransactionSMS(message, 'AD-CENTBK-T'), isTrue);
    final parsed = SMSParser().parseRawMessage(
        body: message, sender: 'AD-CENTBK-T');
    expect(parsed, isNotNull);
    expect(parsed!.transaction.amount, 1);
    expect(parsed.transaction.type, TransactionType.income);
    expect(parsed.transaction.referenceNumber, '657849890346');
  });

  test('leniently queues a recognised bank UPI alert with unusual wording', () {
    const message =
        'HDFC Bank update: INR 349.00 A/c XX9091. UPI Ref 834920198765';
    expect(SMSFilter.isTransactionSMS(message, 'AD-HDFCBK-S'), isTrue);
    expect(SMSParser().parseRawMessage(body: message, sender: 'AD-HDFCBK-S'),
        isNotNull);
  });

  test('does not treat a plain account-balance message as a transaction', () {
    const message = 'HDFC Bank: A/c XX9091 balance is INR 1,500.00';
    expect(SMSFilter.isTransactionSMS(message, 'AD-HDFCBK-S'), isFalse);
  });

  test('extracts a bare standard numeric transaction date', () {
    final date = SMSParser().extractTransactionDate(
        'Central Bank debit Rs. 250 UPI Ref 1234567890 03/08/2026 10:40',
        null);
    expect(date, DateTime(2026, 8, 3, 10, 40));
  });

  test('uses a reference first, then amount, merchant, and date for duplicates',
      () {
    final parser = SMSParser();
    const first = '''Sent Rs.17000.00
From HDFC Bank A/C *9091
To A KHALEEL
On 01/08/26
Ref 127178338507''';
    final parsed = parser.parseRawMessage(body: first, sender: 'AD-HDFCBK-S');
    expect(parsed, isNotNull);
    final transaction = parsed!.transaction;
    expect(parser.isSameTransaction(transaction, transaction.copyWith()), isTrue);
    expect(
        parser.isSameTransaction(
            transaction,
            transaction.copyWith(referenceNumber: '127178338508')),
        isFalse);
    final withoutReference = TrackrTransaction(
      id: 'fallback-copy',
      type: transaction.type,
      amount: transaction.amount,
      description: transaction.description,
      categoryId: transaction.categoryId,
      dateTime: transaction.dateTime,
      bankName: transaction.bankName,
      accountLastDigits: transaction.accountLastDigits,
    );
    expect(
        parser.isSameTransaction(transaction, withoutReference), isTrue);
  });

  test('parses HDFC debit notification starting with Debit Rs.', () {
    const message = "Debit Rs.500.00\nFrom HDFC Bank A/C *9091\nTo MR MD AFTAB ALAM\nOn 31/10/26\nRef 657843118689";
    final parser = SMSParser();
    expect(SMSFilter.isTransactionSMS(message, 'AD-HDFCBK-T'), isTrue);
    final parsed = parser.parseRawMessage(body: message, sender: 'AD-HDFCBK-T');
    expect(parsed, isNotNull);
    expect(parsed!.transaction.amount, 500);
    expect(parsed.transaction.type, TransactionType.expense);
    expect(parsed.transaction.accountLastDigits, '9091');
    expect(parsed.transaction.bankName, 'Hdfc Bank');
    expect(parsed.transaction.description, 'MR MD AFTAB ALAM');
  });

  test('falls back gracefully when debit message omits recipient merchant', () {
    const message = 'Debit Rs.500.00 From HDFC Bank A/C *9091';
    final parser = SMSParser();
    expect(SMSFilter.isTransactionSMS(message, 'AD-HDFCBK-T'), isTrue);
    final parsed = parser.parseRawMessage(body: message, sender: 'AD-HDFCBK-T');
    expect(parsed, isNotNull);
    expect(parsed!.transaction.amount, 500);
    expect(parsed.transaction.type, TransactionType.expense);
    expect(parsed.transaction.bankName, 'Hdfc Bank');
    expect(parsed.transaction.description, 'Hdfc Bank Debit');
  });
}
