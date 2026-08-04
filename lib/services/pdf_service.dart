import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/transaction_model.dart';
import '../models/reimbursement_model.dart';
import '../models/user_profile.dart';
import '../utils/constants.dart';
import '../utils/formatters.dart';

class PdfService {
  Future<File> generateReport({
    required List<TrackrTransaction> transactions,
    required DateTime from,
    required DateTime to,
    required String reportType,
    UserProfile? profile,
    List<Reimbursement> reimbursements = const [],
  }) async {
    final pdf = pw.Document();
    final logoBytes =
        (await rootBundle.load('assets/branding/trackr_launcher_logo.jpeg'))
            .buffer
            .asUint8List();
    final logo = pw.MemoryImage(logoBytes);
    final profileImage =
        profile?.imagePath != null && File(profile!.imagePath!).existsSync()
            ? pw.MemoryImage(await File(profile.imagePath!).readAsBytes())
            : null;
    final filtered = transactions
        .where((t) => !t.dateTime.isBefore(from) && !t.dateTime.isAfter(to))
        .toList();
    final totalExpenses = filtered
        .where((t) => t.type == TransactionType.expense)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalIncome = filtered
        .where((t) => t.type == TransactionType.income)
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalSavings = totalIncome - totalExpenses;

    pdf.addPage(
      pw.MultiPage(
        pageTheme: const pw.PageTheme(pageFormat: PdfPageFormat.a4),
        footer: (context) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 10),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Trackr | Local-first expense tracking',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
              pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
                  style: const pw.TextStyle(
                      fontSize: 8, color: PdfColors.grey600)),
            ],
          ),
        ),
        build: (context) => [
          pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
            pw.Container(
              width: 46,
              height: 46,
              decoration: const pw.BoxDecoration(color: PdfColors.black),
              child: pw.Image(logo, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 12),
            pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Trackr',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColor.fromInt(0xFF073B5C))),
                  pw.Text('$reportType Expense Report',
                      style: const pw.TextStyle(
                          fontSize: 11, color: PdfColors.grey700)),
                ]),
            if (profileImage != null) ...[
              pw.Spacer(),
              pw.ClipOval(
                  child: pw.Image(profileImage,
                      width: 40, height: 40, fit: pw.BoxFit.cover)),
            ],
          ]),
          pw.SizedBox(height: 18),
          if (profile != null &&
              (profile.fullName.isNotEmpty ||
                  profile.contactNumber.isNotEmpty ||
                  profile.email.isNotEmpty))
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFF8FAFB),
                  borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                        profile.fullName.isEmpty
                            ? 'Trackr user'
                            : profile.fullName,
                        style: pw.TextStyle(
                            fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    if (profile.contactNumber.isNotEmpty ||
                        profile.email.isNotEmpty)
                      pw.Text(
                          [profile.contactNumber, profile.email]
                              .where((value) => value.isNotEmpty)
                              .join('  |  '),
                          style: const pw.TextStyle(
                              fontSize: 8.5, color: PdfColors.grey700)),
                    pw.Text('Export generated: ${shortDate(DateTime.now())}',
                        style: const pw.TextStyle(
                            fontSize: 8, color: PdfColors.grey600)),
                  ]),
            ),
          if (profile != null) pw.SizedBox(height: 12),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF1F7F8),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('REPORT PERIOD',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey600)),
                  pw.SizedBox(height: 3),
                  pw.Text('${shortDate(from)} to ${shortDate(to)}',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 12),
                  pw.Row(children: [
                    pw.Expanded(
                        child: _summaryAmount('TOTAL EXPENSE', totalExpenses,
                            PdfColors.red700, PdfColor.fromInt(0xFFFFEBEE))),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                        child: _summaryAmount('TOTAL INCOME', totalIncome,
                            PdfColors.green700, PdfColor.fromInt(0xFFE8F5E9))),
                    pw.SizedBox(width: 8),
                    pw.Expanded(
                        child: _summaryAmount(
                            'TOTAL SAVINGS',
                            totalSavings,
                            totalSavings < 0
                                ? PdfColors.red700
                                : PdfColors.teal700,
                            totalSavings < 0
                                ? PdfColor.fromInt(0xFFFFEBEE)
                                : PdfColor.fromInt(0xFFE0F2F1))),
                  ]),
                ]),
          ),
          pw.SizedBox(height: 20),
          pw.Text('Confirmed transactions',
              style:
                  pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: ['Date', 'Type', 'Category', 'Description', 'Amount'],
            data: filtered.map((t) {
              final category = AppCategories.byId(t.categoryId);
              return [
                shortDate(t.dateTime),
                _titleCase(t.type.name),
                category.name,
                _descriptionWithSettlement(t, reimbursements),
                inr(t.amount)
              ];
            }).toList(),
          ),
          pw.SizedBox(height: 24),
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColor.fromInt(0xFFB9D8D6)),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('Report notes and terms',
                      style: pw.TextStyle(
                          fontSize: 11, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      'This report is generated from transactions recorded and confirmed in Trackr on this device. Totals and category calculations reflect the selected date range and may change when records are edited, added, or removed.',
                      style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 2)),
                  pw.SizedBox(height: 5),
                  pw.Text(
                      'Trackr processes SMS and financial records locally. Smart insights are informational only and are not investment, tax, credit, or legal advice. Verify important figures against your bank statement before making financial decisions.',
                      style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 2)),
                ]),
          ),
        ],
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/trackr_${reportType.toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}.pdf');
    await file.writeAsBytes(await pdf.save());
    return file;
  }

  Future<File> generateCsv(List<TrackrTransaction> transactions) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(
        '${dir.path}/trackr_export_${DateTime.now().millisecondsSinceEpoch}.csv');
    final rows = [
      'id,type,amount,description,category,dateTime,note,upiApp,isAutoDetected,confidence',
      ...transactions.map((t) => [
            t.id,
            t.type.name,
            t.amount,
            _csv(t.description),
            t.categoryId,
            t.dateTime.toIso8601String(),
            _csv(t.note ?? ''),
            t.upiApp.name,
            t.isAutoDetected,
            t.confidence,
          ].join(',')),
    ];
    await file.writeAsString(rows.join('\n'));
    return file;
  }

  Future<void> share(File file) => Share.shareXFiles([XFile(file.path)]);

  String _csv(String value) => '"${value.replaceAll('"', '""')}"';

  String inr(num value) => 'INR ${value.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(?<=\d)(?=(\d{3})+(?!\d))'),
        (_) => ',',
      )}';

  pw.Widget _summaryAmount(
          String label, double value, PdfColor color, PdfColor background) =>
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: background,
          borderRadius: pw.BorderRadius.circular(5),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label,
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
          pw.SizedBox(height: 3),
          pw.Text(inr(value),
              style: pw.TextStyle(
                  fontSize: 10, fontWeight: pw.FontWeight.bold, color: color)),
        ]),
      );

  String _titleCase(String value) => value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.length == 1
          ? word.toUpperCase()
          : '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
      .join(' ');

  String _descriptionWithSettlement(
      TrackrTransaction transaction, List<Reimbursement> reimbursements) {
    if (transaction.splitWith.isEmpty)
      return _titleCase(transaction.description);
    final relevant =
        reimbursements.where((item) => item.expenseId == transaction.id);
    final received = relevant.fold<double>(0, (sum, item) => sum + item.amount);
    final recoverable =
        transaction.splitWith.fold<double>(0, (sum, item) => sum + item.amount);
    final people = transaction.splitWith
        .map((item) => '${_titleCase(item.name)} (${inr(item.amount)})')
        .join(', ');
    return '${_titleCase(transaction.description)}\nSplit with: $people\nReceived: ${inr(received)} | Pending: ${inr((recoverable - received).clamp(0, double.infinity))}';
  }
}
