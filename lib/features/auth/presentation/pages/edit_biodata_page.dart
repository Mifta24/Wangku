import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:wangku/core/theme/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/auth_provider.dart';

class EditBiodataPage extends StatefulWidget {
  const EditBiodataPage({super.key});

  @override
  State<EditBiodataPage> createState() => _EditBiodataPageState();
}

class _EditBiodataPageState extends State<EditBiodataPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _bioController;
  late final TextEditingController _jobController;
  late final TextEditingController _cityController;

  DateTime? _birthDate;
  String? _gender;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthProvider>();
    // Utamakan data dari tabel profiles, fallback ke userMetadata
    final profile = auth.profile;
    final meta = auth.currentUser?.userMetadata ?? {};

    _nameController = TextEditingController(
        text: profile?.name.isNotEmpty == true
            ? profile!.name
            : meta['name']?.toString() ?? '');
    _phoneController = TextEditingController(
        text: profile?.phone.isNotEmpty == true
            ? profile!.phone
            : meta['phone']?.toString() ?? '');
    _bioController = TextEditingController(
        text: profile?.bio.isNotEmpty == true
            ? profile!.bio
            : meta['bio']?.toString() ?? '');
    _jobController = TextEditingController(
        text: profile?.job.isNotEmpty == true
            ? profile!.job
            : meta['job']?.toString() ?? '');
    _cityController = TextEditingController(
        text: profile?.city.isNotEmpty == true
            ? profile!.city
            : meta['city']?.toString() ?? '');

    _birthDate = profile?.birthDate ??
        (meta['birth_date'] != null
            ? DateTime.tryParse(meta['birth_date'].toString())
            : null);

    final rawGender = profile?.gender ?? meta['gender']?.toString();
    if (rawGender == 'Laki-laki' || rawGender == 'Perempuan') {
      _gender = rawGender;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 20),
      firstDate: DateTime(1940),
      lastDate: DateTime(now.year - 5),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: Colors.white,
            surface: AppColors.surface,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final data = <String, dynamic>{
      'name': _nameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'bio': _bioController.text.trim(),
      'job': _jobController.text.trim(),
      'city': _cityController.text.trim(),
      if (_gender != null) 'gender': _gender,
      if (_birthDate != null)
        'birth_date': _birthDate!.toIso8601String().split('T').first,
    };

    final success = await auth.updateProfileData(data);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success ? 'Biodata berhasil disimpan' : auth.errorMessage ?? 'Gagal menyimpan',
          style: GoogleFonts.inter(),
        ),
        backgroundColor: success ? AppColors.success : AppColors.error,
      ),
    );
    if (success && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<AuthProvider>().isLoading;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(LucideIcons.arrowLeft, size: 20.sp, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Biodata',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
          children: [
            // ── Informasi Dasar ──────────────────────────────────────
            _SectionHeader(label: 'Informasi Dasar'),
            SizedBox(height: 12.h),

            _FieldCard(
              children: [
                _FormField(
                  label: 'Nama Lengkap',
                  child: _buildTextField(
                    controller: _nameController,
                    hint: 'Masukkan nama lengkap',
                    icon: LucideIcons.user,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Nama tidak boleh kosong'
                        : null,
                  ),
                ),
                _Divider(),
                _FormField(
                  label: 'Nomor HP',
                  child: _buildTextField(
                    controller: _phoneController,
                    hint: '08123456789',
                    icon: LucideIcons.phone,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  ),
                ),
                _Divider(),
                _FormField(
                  label: 'Tanggal Lahir',
                  child: GestureDetector(
                    onTap: _pickBirthDate,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 14.h),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Icon(LucideIcons.calendar,
                              color: AppColors.hint, size: 18.sp),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Text(
                              _birthDate != null
                                  ? _formatDate(_birthDate!)
                                  : 'Pilih tanggal lahir',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                color: _birthDate != null
                                    ? AppColors.textPrimary
                                    : AppColors.hint,
                              ),
                            ),
                          ),
                          Icon(LucideIcons.chevronRight,
                              color: AppColors.hint, size: 16.sp),
                        ],
                      ),
                    ),
                  ),
                ),
                _Divider(),
                _FormField(
                  label: 'Jenis Kelamin',
                  child: Row(
                    children: ['Laki-laki', 'Perempuan'].map((g) {
                      final selected = _gender == g;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _gender = g),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            margin: EdgeInsets.only(
                                right: g == 'Laki-laki' ? 8.w : 0),
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.10)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10.r),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  g == 'Laki-laki'
                                      ? Icons.male_rounded
                                      : Icons.female_rounded,
                                  size: 18.sp,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.hint,
                                ),
                                SizedBox(width: 6.w),
                                Text(
                                  g,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: selected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: selected
                                        ? AppColors.primary
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // ── Pekerjaan & Lokasi ───────────────────────────────────
            _SectionHeader(label: 'Pekerjaan & Lokasi'),
            SizedBox(height: 12.h),

            _FieldCard(
              children: [
                _FormField(
                  label: 'Pekerjaan',
                  child: _buildTextField(
                    controller: _jobController,
                    hint: 'Mahasiswa, Karyawan Swasta, dll.',
                    icon: LucideIcons.briefcase,
                  ),
                ),
                _Divider(),
                _FormField(
                  label: 'Kota / Domisili',
                  child: _buildTextField(
                    controller: _cityController,
                    hint: 'Jakarta, Bandung, dll.',
                    icon: LucideIcons.mapPin,
                  ),
                ),
              ],
            ),
            SizedBox(height: 20.h),

            // ── Bio ──────────────────────────────────────────────────
            _SectionHeader(label: 'Bio'),
            SizedBox(height: 12.h),

            _FieldCard(
              children: [
                _FormField(
                  label: 'Tentang Saya',
                  child: TextFormField(
                    controller: _bioController,
                    maxLines: 4,
                    maxLength: 120,
                    style: GoogleFonts.inter(fontSize: 14.sp),
                    decoration: InputDecoration(
                      hintText: 'Ceritakan sedikit tentang dirimu...',
                      hintStyle: GoogleFonts.inter(color: AppColors.hint),
                      counterStyle: GoogleFonts.inter(
                          fontSize: 11.sp, color: AppColors.hint),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.r),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 12.h),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 32.h),

            AppButton(
              label: 'Simpan Biodata',
              isLoading: isLoading,
              onPressed: _handleSave,
            ),
            SizedBox(height: 24.h),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      validator: validator,
      style: GoogleFonts.inter(fontSize: 14.sp),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.hint),
        prefixIcon: Icon(icon, color: AppColors.hint, size: 18.sp),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}

// ── Helper Widgets ─────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 12.sp,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 0.4,
      ),
    );
  }
}

class _FieldCard extends StatelessWidget {
  const _FieldCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(14.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, thickness: 1, color: AppColors.border);
  }
}
