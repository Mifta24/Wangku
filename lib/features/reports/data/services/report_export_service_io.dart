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
    buffer.writeln('Tanggal,Tipe,Kategori,Catatan,Jumlah');

    final dateFmt = DateFormat('yyyy-MM-dd');
    for (final tx in transactions) {
      final date = dateFmt.format(tx.date);
      final type = tx.type;
      final category = tx.category?.name ?? 'Uncategorized';
      final note = _escapeCsv(tx.note);
      final amount = tx.amount.toStringAsFixed(0);
      buffer.writeln('$date,$type,$category,$note,$amount');
    }

    final dir = await getApplicationDocumentsDirectory();
    final fileName = _buildFileName('csv');
    final file = File('${dir.path}/$fileName');
    // BOM UTF-8 agar Excel baca karakter non-ASCII dengan benar
    await file.writeAsBytes([0xEF, 0xBB, 0xBF, ...utf8.encode(buffer.toString())]);
    return file.path;
  }

  Future<String?> exportPdf({required List<TransactionModel> transactions}) async {
    final pdf = pw.Document();
    final dateFmt = DateFormat('yyyy-MM-dd');

    final headers = ['Tanggal', 'Tipe', 'Kategori', 'Catatan', 'Jumlah'];
    final rows = transactions.map((tx) {
      return [
        dateFmt.format(tx.date),
        tx.type,
        tx.category?.name ?? 'Uncategorized',
        tx.note,
        tx.amount.toStringAsFixed(0),
      ];
    }).toList();

    pdf.addPage(
      pw.Page(
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('Laporan Transaksi',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 12),
              pw.TableHelper.fromTextArray(
                headers: headers,
                data: rows,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerLeft,
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFFEFEFEF),
                ),
                cellStyle: const pw.TextStyle(fontSize: 10),
              ),
            ],
          );
        },
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final fileName = _buildFileName('pdf');
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }

  Future<String?> exportExcel({required List<TransactionModel> transactions}) async {
    final dateFmt = DateFormat('yyyy-MM-dd');
    final excel = Excel.createExcel();
    final sheet = excel['Laporan'];

    // Header
    final headers = ['Tanggal', 'Tipe', 'Kategori', 'Catatan', 'Jumlah'];
    for (var i = 0; i < headers.length; i++) {
      sheet
          .cell(CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0))
          .value = TextCellValue(headers[i]);
    }

    // Data rows
    for (var rowIdx = 0; rowIdx < transactions.length; rowIdx++) {
      final tx = transactions[rowIdx];
      final row = rowIdx + 1;
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row)).value =
          TextCellValue(dateFmt.format(tx.date));
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: row)).value =
          TextCellValue(tx.type);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: row)).value =
          TextCellValue(tx.category?.name ?? 'Uncategorized');
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: row)).value =
          TextCellValue(tx.note);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: row)).value =
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
