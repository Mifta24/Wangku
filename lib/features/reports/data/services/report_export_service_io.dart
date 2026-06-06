import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../transactions/domain/models/transaction_model.dart';

class ReportExportService {
  Future<String?> exportCsv({required List<TransactionModel> transactions}) async {
    final buffer = StringBuffer();
    buffer.writeln('No.,Tanggal,Tipe,Kategori,Catatan,Jumlah');

    final dateFmt = DateFormat('dd/MM/yyyy');
    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    for (var i = 0; i < sorted.length; i++) {
      final tx = sorted[i];
      final date = dateFmt.format(tx.date);
      final type = tx.type == 'income' ? 'Pemasukan' : 'Pengeluaran';
      final category = tx.category?.name ?? 'Uncategorized';
      final note = _escapeCsv(tx.note);
      final amount = tx.amount.toStringAsFixed(0);
      buffer.writeln('${i + 1},$date,$type,$category,$note,$amount');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = _buildFileName('csv');
    final file = File('${dir.path}/$fileName');
    // BOM UTF-8 agar Excel baca karakter non-ASCII dengan benar
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
    return file.path;
  }

  Future<Uint8List> buildPdfBytes({
    required List<TransactionModel> transactions,
    String? userName,
    DateTime? month,
  }) async {
    final pdf = pw.Document();
    _buildPdfContent(pdf, transactions: transactions, userName: userName, month: month);
    return pdf.save();
  }

  Future<String?> exportPdf({
    required List<TransactionModel> transactions,
    String? userName,
    DateTime? month,
  }) async {
    final pdf = pw.Document();
    _buildPdfContent(pdf, transactions: transactions, userName: userName, month: month);

    final dir = await getApplicationDocumentsDirectory();
    final fileName = _buildFileName('pdf');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  void _buildPdfContent(
    pw.Document pdf, {
    required List<TransactionModel> transactions,
    String? userName,
    DateTime? month,
  }) {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final monthLabel =
        month != null ? DateFormat('MMMM yyyy', 'id_ID').format(month) : '';
    final generatedAt = DateFormat('d MMMM yyyy, HH:mm').format(DateTime.now());

    double totalIncome = 0;
    double totalExpense = 0;
    for (final tx in transactions) {
      if (tx.type == 'income') {
        totalIncome += tx.amount;
      } else {
        totalExpense += tx.amount;
      }
    }
    final net = totalIncome - totalExpense;

    const primaryColor = PdfColor.fromInt(0xFF4D96FF);
    const primaryLight = PdfColor.fromInt(0xFFEBF3FF);
    const incomeColor = PdfColor.fromInt(0xFF22C55E);
    const expenseColor = PdfColor.fromInt(0xFFEF4444);
    const borderColor = PdfColor.fromInt(0xFFE5E7EB);
    const bgAlt = PdfColor.fromInt(0xFFF9FAFB);

    final nf = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    String fmt(double v) => nf.format(v.abs());

    pw.Widget summaryBox(String label, double amount, PdfColor color) {
      return pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: pw.BoxDecoration(
            color: primaryLight,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: borderColor, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                label,
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                fmt(amount),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sortedTx = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        footer: (ctx) => pw.Container(
          padding: const pw.EdgeInsets.only(top: 8),
          decoration: const pw.BoxDecoration(
            border: pw.Border(top: pw.BorderSide(color: borderColor, width: 0.5)),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'Dibuat oleh Wangku · $generatedAt',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
              pw.Text(
                'Halaman ${ctx.pageNumber} / ${ctx.pagesCount}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
              ),
            ],
          ),
        ),
        build: (ctx) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(18),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: pw.BorderRadius.circular(12),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Wangku',
                      style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Halo, ${userName ?? 'Pengguna'}',
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'Laporan Keuangan',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.white),
                    ),
                    if (monthLabel.isNotEmpty) ...[
                      pw.SizedBox(height: 3),
                      pw.Text(
                        monthLabel,
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.white,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 14),
          pw.Row(
            children: [
              summaryBox('Pemasukan', totalIncome, incomeColor),
              pw.SizedBox(width: 8),
              summaryBox('Pengeluaran', totalExpense, expenseColor),
              pw.SizedBox(width: 8),
              summaryBox(net >= 0 ? 'Surplus' : 'Defisit', net.abs(),
                  net >= 0 ? incomeColor : expenseColor),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Detail Transaksi  (${sortedTx.length} transaksi)',
            style: pw.TextStyle(
              fontSize: 12,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.grey800,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Table(
            border: pw.TableBorder.all(color: borderColor, width: 0.5),
            columnWidths: {
              0: const pw.FixedColumnWidth(24),
              1: const pw.FixedColumnWidth(58),
              2: const pw.FixedColumnWidth(68),
              3: const pw.FlexColumnWidth(2),
              4: const pw.FlexColumnWidth(2),
              5: const pw.FixedColumnWidth(72),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: primaryColor),
                children: [
                  'No.',
                  'Tanggal',
                  'Tipe',
                  'Kategori',
                  'Catatan',
                  'Jumlah',
                ].map((h) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                    child: pw.Text(
                      h,
                      style: pw.TextStyle(
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 9,
                        color: PdfColors.white,
                      ),
                    ),
                  );
                }).toList(),
              ),
              ...sortedTx.asMap().entries.map((entry) {
                final i = entry.key;
                final tx = entry.value;
                final isIncome = tx.type == 'income';
                final rowBg = i.isEven ? PdfColors.white : bgAlt;
                return pw.TableRow(
                  decoration: pw.BoxDecoration(color: rowBg),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text('${i + 1}', style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(dateFmt.format(tx.date),
                          style: const pw.TextStyle(fontSize: 8)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(
                        isIncome ? 'Pemasukan' : 'Pengeluaran',
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: isIncome ? incomeColor : expenseColor,
                        ),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(
                        tx.category?.name ?? '-',
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(
                        tx.note.isEmpty ? '-' : tx.note,
                        style: const pw.TextStyle(fontSize: 8),
                      ),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                      child: pw.Text(
                        fmt(tx.amount),
                        style: pw.TextStyle(
                          fontSize: 8,
                          fontWeight: pw.FontWeight.bold,
                          color: isIncome ? incomeColor : expenseColor,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Future<String?> exportExcel({required List<TransactionModel> transactions}) async {
    final dateFmt = DateFormat('dd/MM/yyyy');
    final excel = Excel.createExcel();
    final sheet = excel['Laporan'];

    final headers = ['No.', 'Tanggal', 'Tipe', 'Kategori', 'Catatan', 'Jumlah'];
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
    }

    final sorted = List<TransactionModel>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));
    for (var rowIdx = 0; rowIdx < sorted.length; rowIdx++) {
      final tx = sorted[rowIdx];
      final row = rowIdx + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          IntCellValue(rowIdx + 1);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(dateFmt.format(tx.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(tx.type == 'income' ? 'Pemasukan' : 'Pengeluaran');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(tx.category?.name ?? 'Uncategorized');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
          TextCellValue(tx.note);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 5, rowIndex: row)).value =
          DoubleCellValue(tx.amount);
    }

    // Hapus sheet default 'Sheet1' jika ada
    excel.delete('Sheet1');

    final dir = await getApplicationDocumentsDirectory();
    final fileName = _buildFileName('xlsx');
    final file = File('${dir.path}/$fileName');
    final bytes = excel.encode();
    if (bytes == null) return null;
    await file.writeAsBytes(Uint8List.fromList(bytes));
    return file.path;
  }

  String _buildFileName(String ext) {
    final now = DateTime.now();
    final stamp = DateFormat('yyyyMMdd_HHmm').format(now);
    return 'wangku_report_$stamp.$ext';
  }

  String _escapeCsv(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(',') || escaped.contains('\n')) {
      return '"$escaped"';
    }
    return escaped;
  }
}
