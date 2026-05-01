import 'dart:io';

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
    await file.writeAsString(buffer.toString());
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
