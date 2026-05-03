import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../reports/data/services/report_export_service.dart';
import '../../../transactions/domain/models/transaction_model.dart';
import '../../../transactions/presentation/providers/transaction_provider.dart';

class ExportTransactionsSheet extends StatefulWidget {
  const ExportTransactionsSheet({super.key});

  @override
  State<ExportTransactionsSheet> createState() =>
      _ExportTransactionsSheetState();
}

class _ExportTransactionsSheetState extends State<ExportTransactionsSheet> {
  final ReportExportService _exportService = ReportExportService();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selectedType = 'all';
  bool _isExporting = false;

  @override
  Widget build(BuildContext context) {
    final monthLabel = DateFormat('MMMM yyyy', 'id_ID').format(_selectedMonth);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'Export Transaksi',
                style: GoogleFonts.inter(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 16.h),
              OutlinedButton.icon(
                onPressed: _pickMonth,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(monthLabel),
              ),
              SizedBox(height: 12.h),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('Semua')),
                  ButtonSegment(value: 'expense', label: Text('Keluar')),
                  ButtonSegment(value: 'income', label: Text('Masuk')),
                ],
                selected: {_selectedType},
                onSelectionChanged: (value) {
                  setState(() => _selectedType = value.first);
                },
              ),
              SizedBox(height: 16.h),
              _ExportButton(
                icon: Icons.table_chart_outlined,
                label: 'Export CSV',
                onPressed: _isExporting ? null : () => _export('csv'),
              ),
              SizedBox(height: 8.h),
              _ExportButton(
                icon: Icons.grid_on_outlined,
                label: 'Export Excel',
                onPressed: _isExporting ? null : () => _export('excel'),
              ),
              SizedBox(height: 8.h),
              _ExportButton(
                icon: Icons.picture_as_pdf_outlined,
                label: 'Export PDF',
                onPressed: _isExporting ? null : () => _export('pdf'),
              ),
              if (_isExporting) ...[
                SizedBox(height: 16.h),
                const Center(child: CircularProgressIndicator()),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    DateTime tempDate = _selectedMonth;
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => setDialogState(
                      () => tempDate = DateTime(tempDate.year - 1, tempDate.month),
                    ),
                  ),
                  Text(
                    '${tempDate.year}',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => setDialogState(
                      () => tempDate = DateTime(tempDate.year + 1, tempDate.month),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: GridView.builder(
                  shrinkWrap: true,
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.6,
                  ),
                  itemBuilder: (context, index) {
                    final month = index + 1;
                    final selected = tempDate.year == _selectedMonth.year &&
                        month == _selectedMonth.month;
                    return InkWell(
                      onTap: () =>
                          Navigator.pop(context, DateTime(tempDate.year, month)),
                      child: Container(
                        alignment: Alignment.center,
                        margin: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          DateFormat('MMM', 'id_ID').format(DateTime(2024, month)),
                          style: GoogleFonts.inter(
                            color: selected ? Colors.white : AppColors.textPrimary,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedMonth = picked);
    }
  }

  Future<void> _export(String format) async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    setState(() => _isExporting = true);
    try {
      final transactions = await _monthlyTransactions(userId);
      if (transactions.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak ada transaksi pada bulan ini')),
        );
        return;
      }

      String? path;
      if (format == 'csv') {
        path = await _exportService.exportCsv(transactions: transactions);
      } else if (format == 'excel') {
        path = await _exportService.exportExcel(transactions: transactions);
      } else {
        path = await _exportService.exportPdf(transactions: transactions);
      }

      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export belum tersedia di platform ini')),
        );
        return;
      }

      await Share.shareXFiles([XFile(path)]);
      await OpenFilex.open(path);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal export: $e')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<List<TransactionModel>> _monthlyTransactions(String userId) async {
    final provider = context.read<TransactionProvider>();
    final start = DateTime(_selectedMonth.year, _selectedMonth.month);
    final end = DateTime(_selectedMonth.year, _selectedMonth.month + 1);

    await provider.loadByDateRange(userId, start, end);

    return provider.transactions.where((tx) {
      final inMonth = tx.date.year == _selectedMonth.year &&
          tx.date.month == _selectedMonth.month;
      final matchType = _selectedType == 'all' || tx.type == _selectedType;
      return inMonth && matchType;
    }).toList();
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 14.h),
        alignment: Alignment.centerLeft,
      ),
    );
  }
}
