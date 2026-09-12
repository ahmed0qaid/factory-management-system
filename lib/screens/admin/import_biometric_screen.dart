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
          const SnackBar(
            content: Text('يجب اختيار ملف Excel بصيغة xlsx فقط.'),
          ),
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
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار ملف صحيح')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final parsed = ExcelAttendanceImportParser.parse(_selectedFile!.bytes!);
      if (!mounted) return;
      setState(() {
        _previewData = parsed.rawLogs;
        _summary = parsed.summary;
        _currentPage = 1;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تحليل الملف: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importData() async {
    final summary = _summary;
    if (summary == null || summary.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء معاينة الملف أولاً')),
      );
      return;
    }

    final hasReviewCases = summary.needsReviewGroups > 0;
    final confirm = await AppConfirmDialog.show(
      context,
      title: hasReviewCases ? 'حالات تحتاج مراجعة' : 'تأكيد الاستيراد',
      content: hasReviewCases
          ? 'توجد حالات تحتاج مراجعة. سيتم حفظ الحالات غير المكتملة كسجلات «تحتاج مراجعة» وتنبيهات للموظفين. هل تريد المتابعة؟'
          : 'سيتم حفظ نتائج المعاينة في قاعدة البيانات. هل تريد المتابعة؟',
      confirmText: hasReviewCases ? 'استيراد ومتابعة' : 'متابعة',
    );
    if (confirm != true) return;

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
      if (mounted) {
        final msg = e.toString();
        debugPrint('IMPORT_UI_FAILED: $e');
        debugPrint('IMPORT_UI_STACK: $st');

        String displayMsg = 'فشل الاستيراد: حدث خطأ غير متوقع.';
        if (msg.contains('صلاحية') || msg.contains('401')) {
          displayMsg = msg.replaceFirst('Exception: ', '');
          if (!displayMsg.contains('صلاحية')) {
            displayMsg =
                'فشل الاستيراد: لا توجد صلاحية لحفظ سجلات البصمة في Appwrite.';
          }
        } else if (msg.contains('حقل غير موجود') ||
            msg.contains('Attribute')) {
          displayMsg = msg.replaceFirst('Exception: ', '');
          if (!displayMsg.contains('حقل غير موجود')) {
            displayMsg =
                'فشل الاستيراد: حقل غير موجود أو نوع بيانات غير صحيح. راجع Debug Console.';
          }
        } else {
          final cleanMsg = msg
              .split('\n')
              .first
              .replaceFirst('Exception: ', '')
              .trim();
          displayMsg = 'فشل الاستيراد: $cleanMsg';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(displayMsg),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showImportResult(Map<String, dynamic> result) async {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final errors = result['errors'] as List? ?? const [];
    final hasErrors = errors.isNotEmpty;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasErrors
                    ? semantic.warningContainer
                    : semantic.successContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasErrors ? Icons.warning_amber_rounded : Icons.check_rounded,
                color: hasErrors
                    ? semantic.onWarningContainer
                    : semantic.onSuccessContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hasErrors
                    ? 'تم الاستيراد بنجاح جزئي'
                    : 'اكتمل الاستيراد بنجاح',
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _resultLine(
                  'Batch محفوظ',
                  result['batch_saved'] == true ? 'نعم' : 'لا',
                ),
                _resultLine(
                  'صفوف Excel المقروءة',
                  '${result['excel_rows_read'] ?? _summary?.excelRowsRead ?? 0}',
                ),
                _resultLine(
                  'الموظفون المطابقون',
                  '${result['matched_employees'] ?? 0}',
                ),
                _resultLine(
                  'أرقام البصمة غير المرتبطة',
                  '${result['unmatched'] ?? 0}',
                ),
                const Divider(height: 20),
                _resultLine(
                  'سجلات بصمة محفوظة',
                  '${result['logs_saved'] ?? 0}',
                ),
                _resultLine(
                  'سجلات بصمة متخطاة',
                  '${result['logs_skipped'] ?? 0}',
                ),
                _resultLine(
                  'سجلات بصمة فشلت',
                  '${result['logs_failed'] ?? 0}',
                  color: (result['logs_failed'] ?? 0) != 0 ? scheme.error : null,
                ),
                const Divider(height: 20),
                _resultLine(
                  'سجلات حضور منشأة',
                  '${result['created_attendance'] ?? 0}',
                ),
                _resultLine(
                  'سجلات حضور متخطاة',
                  '${result['skipped_attendance'] ?? 0}',
                ),
                _resultLine(
                  'إضافي منشأ',
                  '${result['created_overtime'] ?? 0}',
                ),
                _resultLine(
                  'إضافي متخطى',
                  '${result['skipped_overtime'] ?? 0}',
                ),
                _resultLine(
                  'تنبيهات منشأة',
                  '${result['created_notifications'] ?? 0}',
                ),
                _resultLine(
                  'حالات تحتاج مراجعة',
                  '${result['needs_review'] ?? 0}',
                  color: (result['needs_review'] ?? 0) != 0
                      ? semantic.warning
                      : null,
                ),
                _resultLine(
                  'حالات غياب',
                  '${result['absent_cases'] ?? 0}',
                  color:
                      (result['absent_cases'] ?? 0) != 0 ? scheme.error : null,
                ),
                _resultLine(
                  'دخول بدون خروج',
                  '${result['missing_check_out'] ?? 0}',
                ),
                _resultLine(
                  'خروج بدون دخول',
                  '${result['missing_check_in'] ?? 0}',
                ),
                const Divider(height: 20),
                _resultLine(
                  'موظفون مؤقتون جدد',
                  '${result['created_temporary'] ?? 0}',
                ),
                _resultLine(
                  'موظفون مؤقتون محدثون',
                  '${result['updated_temporary'] ?? 0}',
                ),
                _resultLine(
                  'موظفون مؤقتون متخطون',
                  '${result['skipped_temporary'] ?? 0}',
                ),
                _resultLine(
                  'موظفون مؤقتون فشل حفظهم',
                  '${result['temporary_failed'] ?? 0}',
                  color: (result['temporary_failed'] ?? 0) != 0
                      ? scheme.error
                      : null,
                ),
                _resultLine(
                  'موظفون مؤقتون بأسماء من Excel',
                  '${result['temporary_with_imported_names'] ?? 0}',
                ),
                if (hasErrors) ...[
                  const Divider(height: 24),
                  Text(
                    'أخطاء جزئية',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: scheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: scheme.errorContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final error in errors)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Text(
                              '• $error',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onErrorContainer,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
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

  Widget _resultLine(String label, String value, {Color? color}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: color ?? scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final groups = _summary?.groups ?? [];
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final safeStart = startIndex < 0
        ? 0
        : (startIndex > groups.length ? groups.length : startIndex);
    final endIndex = safeStart + _itemsPerPage < groups.length
        ? safeStart + _itemsPerPage
        : groups.length;
    final currentView = groups.isNotEmpty
        ? groups.sublist(safeStart, endIndex)
        : <ProcessedGroup>[];

    return AppScaffold(
      title: 'استيراد ملف الحضور Excel',
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 700;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppCard(
                      padding: const EdgeInsets.all(16),
                      child: isMobile
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: _buildControls(theme, isMobile),
                            )
                          : Wrap(
                              spacing: 16,
                              runSpacing: 16,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: _buildControls(theme, isMobile),
                            ),
                    ),
                    const SizedBox(height: 16),
                    if (_isLoading)
                      const AppLoadingState(label: 'جاري معالجة ملف البصمة')
                    else if (_summary != null) ...[
                      _buildSummaryCard(_summary!),
                      const SizedBox(height: 16),
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildMobileList(currentView),
                            const Divider(height: 1),
                            PaginationControls(
                              currentPage: _currentPage,
                              totalItems: groups.length,
                              itemsPerPage: _itemsPerPage,
                              onPageChanged: (page) =>
                                  setState(() => _currentPage = page),
                              onItemsPerPageChanged: (items) => setState(() {
                                _itemsPerPage = items;
                                _currentPage = 1;
                              }),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: AppLoadingButton(
                          onPressed: _isLoading ? null : _importData,
                          icon: Icons.save_outlined,
                          text: 'بدء الاستيراد والمعالجة',
                        ),
                      ),
                    ] else
                      AppEmptyState(
                        title: 'لا توجد معاينة بعد',
                        message:
                            'اختر ملف Excel ثم اضغط «معاينة الملف» لفحص البيانات قبل الاستيراد.',
                        icon: Icons.table_view_outlined,
                        actionLabel:
                            _selectedFile == null ? 'اختيار ملف Excel' : null,
                        onAction: _selectedFile == null ? _pickFile : null,
                      ),
                    if (_selectedFile != null &&
                        _summary == null &&
                        !_isLoading)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'الملف المحدد: ${_selectedFile!.name}',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  List<Widget> _buildControls(ThemeData theme, bool isMobile) {
    final scheme = theme.colorScheme;
    return [
      OutlinedButton.icon(
        onPressed: _isLoading ? null : _pickFile,
        icon: const Icon(Icons.attach_file),
        label: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 190,
          ),
          child: Text(
            _selectedFile != null ? _selectedFile!.name : 'اختر ملف Excel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      if (isMobile) const SizedBox(height: 8),
      Text(
        'يقبل النظام ملفات Excel بصيغة xlsx فقط وبالأعمدة المحددة.',
        style: theme.textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
      if (isMobile) const SizedBox(height: 8),
      FilledButton.tonalIcon(
        onPressed: (_selectedFile != null && !_isLoading)
            ? _generatePreview
            : null,
        icon: const Icon(Icons.visibility_outlined),
        label: const Text('معاينة الملف'),
      ),
    ];
  }

  Widget _buildSummaryCard(PreprocessSummary summary) {
    final dates = summary.groups.map((g) => g.workDate).toSet().toList()..sort();
    final firstDate = dates.isNotEmpty ? Formatters.date(dates.first) : '-';
    final lastDate = dates.isNotEmpty ? Formatters.date(dates.last) : '-';
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تقرير المعاينة قبل الاستيراد',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'راجع الأرقام والحالات أدناه قبل تثبيت الاستيراد.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const Divider(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            children: [
              _summaryLine('صفوف Excel المقروءة', '${summary.excelRowsRead}'),
              _summaryLine('أرقام بصمة في الملف', '${summary.matchedEmployees}'),
              _summaryLine(
                'ورديات من Excel',
                '${summary.groups.where((g) => g.shiftStart != null && g.shiftEnd != null).length}',
              ),
              _summaryLine('تواريخ الدوام المكتشفة', '${dates.length}'),
              _summaryLine('من تاريخ', firstDate),
              _summaryLine('إلى تاريخ', lastDate),
              _summaryLine('دخول مستخدم', '${summary.usedCheckIns}'),
              _summaryLine('خروج مستخدم', '${summary.usedCheckOuts}'),
              _summaryLine(
                'حالات غياب',
                '${summary.absentCases}',
                color: summary.absentCases > 0 ? scheme.error : null,
              ),
              _summaryLine(
                'فقدان بصمة دخول',
                '${summary.missingCheckIns}',
                color: summary.missingCheckIns > 0 ? scheme.error : null,
              ),
              _summaryLine(
                'فقدان بصمة خروج',
                '${summary.missingCheckOuts}',
                color: summary.missingCheckOuts > 0 ? scheme.error : null,
              ),
              _summaryLine(
                'إضافي متوقع',
                '${summary.expectedOvertimeCases} حالة',
              ),
              _summaryLine(
                'مجموعات تحتاج مراجعة',
                '${summary.needsReviewGroups}',
                color: summary.needsReviewGroups > 0 ? semantic.warning : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryLine(String title, String value, {Color? color}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: 160,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color ?? scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileList(List<ProcessedGroup> currentView) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(8),
      itemCount: currentView.length,
      itemBuilder: (context, index) {
        final group = currentView[index];
        final isReady = !group.needsReview;
        final isFirstOfDate =
            index == 0 || currentView[index - 1].workDate != group.workDate;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final semantic = context.semanticColors;

        final checkOutStr = _displayPunch(group.actualCheckOut, group.workDate);
        final checkInStr = _displayPunch(group.actualCheckIn, group.workDate);

        final card = AppCard(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'رقم البصمة: ${group.biometricId}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (group.isAbsent)
                    AppStatusPill.danger('غياب')
                  else if (isReady)
                    AppStatusPill.success('جاهز')
                  else
                    AppStatusPill.warning('يحتاج مراجعة'),
                ],
              ),
              const Divider(height: 24),
              if (group.employeeName != null)
                _buildDataField('الاسم', group.employeeName!),
              _buildDataField(
                'تاريخ الدوام',
                Formatters.date(group.workDate),
              ),
              _buildDataField(
                'الوردية المقترحة',
                group.suggestedShift?.name ?? 'غير معروف',
              ),
              if (group.shiftEnd != null)
                _buildDataField(
                  'نهاية الدوام الرسمي',
                  Formatters.time(group.shiftEnd!),
                ),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDataField('الدخول المستخدم', checkInStr),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildDataField('الخروج الفعلي', checkOutStr),
                  ),
                ],
              ),
              if (group.shiftEnd != null)
                _buildDataField(
                  'شرط احتساب الإضافي',
                  'بعد تجاوز ${BiometricPreprocessor.overtimeMinimumTriggerMinutes} دقيقة',
                  valueColor: scheme.onSurfaceVariant,
                ),
              if (group.expectedOvertimeMinutes > 0)
                _buildDataField(
                  'الإضافي المتوقع',
                  Formatters.minutesToHours(group.expectedOvertimeMinutes),
                  valueColor: scheme.primary,
                ),
              if (group.ignoredCount > 0)
                _buildDataField(
                  'المكرر المتجاهل',
                  '${group.ignoredCount}',
                  valueColor: scheme.onSurfaceVariant,
                ),
              if ((group.needsReview || group.isAbsent) &&
                  group.reviewReason.isNotEmpty)
                _buildDataField(
                  'السبب',
                  group.reviewReason,
                  valueColor:
                      group.isAbsent ? scheme.error : semantic.warning,
                ),
            ],
          ),
        );

        if (!isFirstOfDate) return card;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(
                top: 16,
                bottom: 8,
                start: 8,
              ),
              child: Text(
                'تاريخ الدوام: ${Formatters.date(group.workDate)}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            card,
          ],
        );
      },
    );
  }

  String _displayPunch(DateTime? value, DateTime workDate) {
    if (value == null) return 'مفقود';
    final differentDay = value.day != workDate.day ||
        value.month != workDate.month ||
        value.year != workDate.year;
    return differentDay
        ? '${Formatters.date(value)} ${Formatters.time(value)}'
        : Formatters.time(value);
  }

  Widget _buildDataField(String title, String value, {Color? valueColor}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: valueColor ?? scheme.onSurface,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
