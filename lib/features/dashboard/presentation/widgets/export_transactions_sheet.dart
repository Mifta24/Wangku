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
  State<ExportTransactionsSheet> createState() => _ExportTransactionsSheetState();
}

class _ExportTransactionsSheetState extends State<ExportTransactionsSheet> {
  final ReportExportService _exportService = ReportExportService();

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  String _selectedFormat = 'csv';
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
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
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
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Export Transaksi',
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    color: AppColors.textSecondary,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              SizedBox(height: 24.h),
              // Periode section
              Text(
                'Periode',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              GestureDetector(
                onTap: _pickMonth,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: AppColors.border),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_month_outlined,
                          color: AppColors.primary, size: 20.sp),
                      SizedBox(width: 10.w),
                      Expanded(
                        child: Text(
                          monthLabel,
                          style: GoogleFonts.inter(
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary, size: 20.sp),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              // Format File section
              Text(
                'Format File',
                style: GoogleFonts.inter(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: 8.h),
              Row(
                children: [
                  for (final format in ['csv', 'excel', 'pdf'])
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                          right: format != 'pdf' ? 8.w : 0,
                        ),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedFormat = format),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: _selectedFormat == format
                                  ? AppColors.primary
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: _selectedFormat == format
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            child: Text(
                              format.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: _selectedFormat == format
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(height: 28.h),
              // Export button
              SizedBox(
                height: 48.h,
                child: ElevatedButton(
                  onPressed: _isExporting ? null : () => _export(_selectedFormat),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r)),
                  ),
                  child: _isExporting
                      ? SizedBox(
                          height: 20.h,
                          width: 20.w,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          'Export Data',
                          style: GoogleFonts.inter(
                              fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
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
                  Text('${tempDate.year}',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
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
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
    if (picked != null) setState(() => _selectedMonth = picked);
  }

  Future<void> _export(String format) async {
    final auth = context.read<AuthProvider>();
    final userId = auth.currentUser?.id;
    if (userId == null) return;

    final profile = auth.profile;
    final meta = auth.currentUser?.userMetadata;
    final rawName = profile?.name.isNotEmpty == true
        ? profile!.name
        : (meta?['name'] ?? meta?['full_name'])?.toString();
    final userName = (rawName?.isNotEmpty == true)
        ? rawName
        : auth.currentUser?.email?.split('@').first;

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
        path = await _exportService.exportPdf(
          transactions: transactions,
          userName: userName,
          month: _selectedMonth,
        );
      }

      if (!mounted) return;
      if (path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Export belum tersedia di platform ini')),
        );
        return;
      }

      await SharePlus.instance.share(ShareParams(files: [XFile(path)]));
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
      return tx.date.year == _selectedMonth.year &&
          tx.date.month == _selectedMonth.month;
    }).toList();
  }
}
