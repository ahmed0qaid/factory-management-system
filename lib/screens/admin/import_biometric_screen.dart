import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../services/admin_biometrics_service.dart';
import '../../services/biometric_preprocessor.dart';
import '../../services/excel_attendance_import_parser.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';
import '../../widgets/common/pagination_controls.dart';

class ImportBiometricScreen extends StatefulWidget {
  final String companyId;

  const ImportBiometricScreen({super.key, required this.companyId});

  @override
  State<ImportBiometricScreen> createState() => _ImportBiometricScreenState();
}

class _ImportBiometricScreenState extends State<ImportBiometricScreen> {
  final _adminBiometrics = AdminBiometricsService();

  bool _isLoading = false;
  PlatformFile? _selectedFile;
  List<Map<String, dynamic>> _previewData = [];
  PreprocessSummary? _summary;
  int _currentPage = 1;
  int _itemsPerPage = 10;

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.extension?.toLowerCase() != 'xlsx') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('يجب اختيار ملف Excel بصيغة xlsx فقط.')),
        );
      }
      return;
    }

    setState(() {
      _selectedFile = file;
      _previewData = [];
      _summary = null;
      _currentPage = 1;
    });
  }

  Future<void> _generatePreview() async {
    final file = _selectedFile;
    if (file == null || file.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار ملف Excel صحيح.')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final parsed = ExcelAttendanceImportParser.parse(file.bytes!);
      final canonicalSummary = await _adminBiometrics
          .prepareProcessedBiometricPreview(
            companyId: widget.companyId,
            summary: parsed.summary,
          );
      if (!mounted) return;
      setState(() {
        _previewData = parsed.rawLogs;
        _summary = canonicalSummary;
        _currentPage = 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل تحليل الملف: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importData() async {
    final summary = _summary;
    if (summary == null || summary.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء معاينة الملف أولاً.')),
      );
      return;
    }

    final hasReviewCases = summary.needsReviewGroups > 0;
    final confirmed = await AppConfirmDialog.show(
      context,
      title: hasReviewCases ? 'حالات تحتاج مراجعة' : 'تأكيد الاستيراد',
      content: hasReviewCases
          ? 'توجد حالات تحتاج مراجعة وفق جدول الدوام الداخلي. سيتم حفظها بحالة «تحتاج مراجعة» دون الاعتماد على أوقات الدوام الموجودة في Excel. هل تريد المتابعة؟'
          : 'سيتم إنشاء الحضور باستخدام employee_work_schedules كمصدر رسمي لأوقات الدوام. هل تريد المتابعة؟',
      confirmText: 'استيراد',
    );
    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final result = await _adminBiometrics.commitProcessedBiometricImport(
        companyId: widget.companyId,
        fileName: _selectedFile?.name ?? 'unknown.xlsx',
        summary: summary,
        rawLogs: _previewData,
      );
      if (mounted) await _showImportResult(result);
    } catch (e, st) {
      debugPrint('IMPORT_UI_FAILED: $e');
      debugPrint('IMPORT_UI_STACK: $st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الاستيراد: ${e.toString().replaceFirst('Exception: ', '')}',
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = _summary?.groups ?? const <ProcessedGroup>[];
    final start = ((_currentPage - 1) * _itemsPerPage).clamp(0, groups.length);
    final end = (start + _itemsPerPage).clamp(0, groups.length);
    final currentGroups = groups.sublist(start, end);

    return AppScaffold(
      title: 'استيراد ملف الحضور Excel',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSourceNotice(),
                const SizedBox(height: 12),
                _buildFileCard(),
                const SizedBox(height: 16),
                if (_isLoading)
                  const AppLoadingState(label: 'جاري معالجة ملف البصمة')
                else if (_summary != null) ...[
                  _buildSummaryCard(_summary!),
                  const SizedBox(height: 16),
                  if (groups.isEmpty)
                    const AppEmptyState(
                      title: 'لا توجد بيانات قابلة للمعالجة',
                      message: 'لم يتم العثور على صفوف حضور صالحة في الملف.',
                      icon: Icons.event_busy_outlined,
                    )
                  else
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'معاينة حسب جدول الدوام الداخلي',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          ...currentGroups.map(_buildGroupTile),
                          const SizedBox(height: 8),
                          PaginationControls(
                            currentPage: _currentPage,
                            totalItems: groups.length,
                            itemsPerPage: _itemsPerPage,
                            onPageChanged: (page) =>
                                setState(() => _currentPage = page),
                            onItemsPerPageChanged: (count) => setState(() {
                              _itemsPerPage = count;
                              _currentPage = 1;
                            }),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 16),
                  AppLoadingButton(
                    onPressed: _importData,
                    isLoading: _isLoading,
                    text: 'اعتماد واستيراد النتائج',
                    icon: Icons.cloud_upload_outlined,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSourceNotice() {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      backgroundColor: scheme.primaryContainer.withValues(alpha: .42),
      borderColor: scheme.primary.withValues(alpha: .22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.verified_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'المصدر الرسمي للدوام هو جدول employee_work_schedules. أعمدة «الحضور المطلوب» و«الانصراف المطلوب» في Excel لا تستخدم لحساب التأخير أو الإضافي أو وقت الدوام المحفوظ.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFileCard() {
    final file = _selectedFile;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ملف البصمة',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          if (file != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.description_outlined),
              title: Text(file.name),
              subtitle: Text('${file.size} bytes'),
            )
          else
            const Text('لم يتم اختيار ملف بعد.'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              OutlinedButton.icon(
                onPressed: _isLoading ? null : _pickFile,
                icon: const Icon(Icons.attach_file),
                label: Text(file == null ? 'اختيار ملف' : 'تغيير الملف'),
              ),
              FilledButton.icon(
                onPressed: file == null || _isLoading ? null : _generatePreview,
                icon: const Icon(Icons.preview_outlined),
                label: const Text('معاينة'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(PreprocessSummary summary) {
    final semantic = context.semanticColors;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ملخص المعالجة',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _summaryChip('صفوف Excel', summary.excelRowsRead),
              _summaryChip('موظفون مطابقون', summary.matchedEmployees),
              _summaryChip('غير مرتبطين', summary.unmatchedEmployees),
              _summaryChip('غياب', summary.absentCases),
              _summaryChip(
                'تحتاج مراجعة',
                summary.needsReviewGroups,
                color: summary.needsReviewGroups > 0
                    ? semantic.warningContainer
                    : null,
              ),
              _summaryChip('إضافي متوقع', summary.expectedOvertimeCases),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryChip(String label, int value, {Color? color}) {
    return Chip(
      backgroundColor: color,
      label: Text('$label: $value'),
    );
  }

  Widget _buildGroupTile(ProcessedGroup group) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    Widget statusPill;
    if (group.skipAttendance) {
      statusPill = AppStatusPill.neutral('راحة');
    } else if (!group.canonicalScheduleResolved) {
      statusPill = AppStatusPill.warning('بدون جدول داخلي');
    } else if (group.needsReview) {
      statusPill = AppStatusPill.warning('تحتاج مراجعة');
    } else if (group.isAbsent) {
      statusPill = AppStatusPill.neutral('غياب');
    } else {
      statusPill = AppStatusPill.success('جاهز');
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  group.employeeName?.trim().isNotEmpty == true
                      ? group.employeeName!.trim()
                      : 'رقم البصمة ${group.biometricId}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              statusPill,
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18,
            runSpacing: 8,
            children: [
              _dataText('رقم البصمة', group.biometricId),
              _dataText('تاريخ الدوام', Formatters.date(group.workDate)),
              _dataText(
                'الوردية',
                group.suggestedShift?.name ??
                    (group.skipAttendance ? 'يوم راحة' : 'غير محددة'),
              ),
              _dataText(
                'بداية الدوام',
                group.shiftStart == null
                    ? '-'
                    : Formatters.time(group.shiftStart!),
              ),
              _dataText(
                'نهاية الدوام',
                group.shiftEnd == null ? '-' : Formatters.time(group.shiftEnd!),
              ),
              _dataText(
                'دخول فعلي',
                group.actualCheckIn == null
                    ? '-'
                    : Formatters.time(group.actualCheckIn!),
              ),
              _dataText(
                'خروج فعلي',
                group.actualCheckOut == null
                    ? '-'
                    : Formatters.time(group.actualCheckOut!),
              ),
            ],
          ),
          if (group.reviewReason.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              group.reviewReason,
              style: theme.textTheme.bodySmall?.copyWith(
                color: group.needsReview
                    ? context.semanticColors.warning
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _dataText(String label, String value) {
    return Text('$label: $value');
  }

  Future<void> _showImportResult(Map<String, dynamic> result) async {
    final errors = result['errors'] as List? ?? const [];
    final hasErrors = errors.isNotEmpty;
    final scheme = Theme.of(context).colorScheme;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(hasErrors ? 'اكتمل الاستيراد مع ملاحظات' : 'اكتمل الاستيراد'),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _resultLine('Batch محفوظ', result['batch_saved'] == true ? 'نعم' : 'لا'),
                _resultLine('صفوف Excel', '${result['excel_rows_read'] ?? 0}'),
                _resultLine('الموظفون المطابقون', '${result['matched_employees'] ?? 0}'),
                _resultLine('غير المرتبطين', '${result['unmatched'] ?? 0}'),
                const Divider(),
                _resultLine('Logs محفوظة', '${result['logs_saved'] ?? 0}'),
                _resultLine('Logs متخطاة', '${result['logs_skipped'] ?? 0}'),
                _resultLine('حضور منشأ', '${result['created_attendance'] ?? 0}'),
                _resultLine('حضور متخطى', '${result['skipped_attendance'] ?? 0}'),
                _resultLine('أيام راحة متخطاة', '${result['skipped_rest_days'] ?? 0}'),
                _resultLine('إضافي منشأ', '${result['created_overtime'] ?? 0}'),
                _resultLine('تحتاج مراجعة', '${result['needs_review'] ?? 0}'),
                _resultLine('غياب', '${result['absent_cases'] ?? 0}'),
                _resultLine('موظفون مؤقتون جدد', '${result['created_temporary'] ?? 0}'),
                _resultLine('موظفون مؤقتون محدثون', '${result['updated_temporary'] ?? 0}'),
                if (hasErrors) ...[
                  const Divider(),
                  Text(
                    'ملاحظات وأخطاء جزئية',
                    style: TextStyle(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (final error in errors) Text('• $error'),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('حسنًا'),
          ),
        ],
      ),
    );
  }

  Widget _resultLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
