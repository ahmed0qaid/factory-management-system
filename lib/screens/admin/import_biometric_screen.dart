import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../services/admin_biometrics_service.dart';
import '../../services/excel_attendance_import_parser.dart';
import '../../services/biometric_preprocessor.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_loading_button.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
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
  }

  Future<void> _generatePreview() async {
    if (_selectedFile == null || _selectedFile!.bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار ملف صحيح')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final parsed = ExcelAttendanceImportParser.parse(_selectedFile!.bytes!);

      setState(() {
        _previewData = parsed.rawLogs;
        _summary = parsed.summary;
        _currentPage = 1;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('فشل تحليل الملف: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importData() async {
    if (_summary == null || _summary!.groups.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء معاينة الملف أولاً')),
      );
      return;
    }

    final validCount = _summary!.groups.length;
    if (validCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد سجلات صالحة في الملف للاستيراد')),
      );
      return;
    }

    if (_summary!.needsReviewGroups > 0) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('حالات تحتاج مراجعة'),
          content: const Text(
            'توجد حالات تحتاج مراجعة. هل تريد استيراد السجلات الجاهزة فقط؟\nسيتم حفظ الحالات غير المكتملة كسجلات "تحتاج مراجعة" وتنبيهات للموظفين.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('استيراد'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تأكيد الاستيراد'),
          content: const Text(
            'سيتم حفظ نتائج المعاينة في قاعدة البيانات. هل تريد المتابعة؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('متابعة'),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final result = await _adminBiometrics.commitProcessedBiometricImport(
        companyId: widget.companyId,
        fileName: _selectedFile?.name ?? 'unknown.xlsx',
        summary: _summary!,
        rawLogs: _previewData,
      );

      if (mounted) {
        bool hasErrors =
            result['errors'] != null && (result['errors'] as List).isNotEmpty;
        String dialogTitle = hasErrors
            ? 'تم الاستيراد بنجاح جزئي'
            : 'اكتمل الاستيراد بنجاح';

        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: Text(
              dialogTitle,
              style: TextStyle(color: hasErrors ? Colors.orange : Colors.green),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Batch محفوظ: ${result['batch_saved'] == true ? "نعم" : "لا"}',
                  ),
                  Text(
                    'صفوف Excel المقروءة: ${result['excel_rows_read'] ?? _summary?.excelRowsRead ?? 0}',
                  ),
                  Text(
                    'الموظفون المطابقون: ${result['matched_employees'] ?? 0}',
                  ),
                  Text(
                    'أرقام البصمة غير المرتبطة: ${result['unmatched'] ?? 0}',
                  ),
                  const SizedBox(height: 8),
                  Text('سجلات بصمة محفوظة: ${result['logs_saved'] ?? 0}'),
                  Text(
                    'سجلات بصمة موجودة مسبقًا / متخطاة: ${result['logs_skipped'] ?? 0}',
                  ),
                  Text('سجلات بصمة فشلت: ${result['logs_failed'] ?? 0}'),
                  const SizedBox(height: 8),
                  Text(
                    'سجلات حضور منشأة: ${result['created_attendance'] ?? 0}',
                  ),
                  Text(
                    'سجلات حضور موجودة مسبقًا / متخطاة: ${result['skipped_attendance'] ?? 0}',
                  ),
                  const SizedBox(height: 8),
                  Text('إضافي منشأ: ${result['created_overtime'] ?? 0}'),
                  Text(
                    'إضافي موجود مسبقًا / متخطى: ${result['skipped_overtime'] ?? 0}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'تنبيهات منشأة: ${result['created_notifications'] ?? 0}',
                  ),
                  Text('حالات تحتاج مراجعة: ${result['needs_review'] ?? 0}'),
                  Text('حالات غياب: ${result['absent_cases'] ?? 0}'),
                  Text(
                    'حالات دخول بدون خروج: ${result['missing_check_out'] ?? 0}',
                  ),
                  Text(
                    'حالات خروج بدون دخول: ${result['missing_check_in'] ?? 0}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'موظفون مؤقتون جدد: ${result['created_temporary'] ?? 0}',
                  ),
                  Text(
                    'موظفون مؤقتون محدثون: ${result['updated_temporary'] ?? 0}',
                  ),
                  Text(
                    'موظفون مؤقتون موجودون مسبقًا / متخطون: ${result['skipped_temporary'] ?? 0}',
                  ),
                  Text(
                    'موظفون مؤقتون فشل حفظهم: ${result['temporary_failed'] ?? 0}',
                  ),
                  Text(
                    'موظفون مؤقتون بأسماء من Excel: ${result['temporary_with_imported_names'] ?? 0}',
                  ),
                  if (result['errors'] != null &&
                      (result['errors'] as List).isNotEmpty) ...[
                    const Divider(),
                    const Text(
                      'أخطاء جزئية:',
                      style: TextStyle(
                        color: Colors.red,
                        
                      ),
                    ),
                    for (var err in result['errors'])
                      Text(
                        '- $err',
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e, st) {
      if (mounted) {
        String msg = e.toString();
        debugPrint('IMPORT_UI_FAILED: $e');
        debugPrint('IMPORT_UI_STACK: $st');

        String displayMsg = 'فشل الاستيراد: حدث خطأ غير متوقع.';
        if (msg.contains('صلاحية') || msg.contains('401')) {
          displayMsg = msg.replaceFirst('Exception: ', '');
          if (!displayMsg.contains('صلاحية'))
            displayMsg =
                'فشل الاستيراد: لا توجد صلاحية لحفظ سجلات البصمة في Appwrite.';
        } else if (msg.contains('حقل غير موجود') || msg.contains('Attribute')) {
          displayMsg = msg.replaceFirst('Exception: ', '');
          if (!displayMsg.contains('حقل غير موجود'))
            displayMsg =
                'فشل الاستيراد: حقل غير موجود أو نوع بيانات غير صحيح. راجع Debug Console.';
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
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final groups = _summary?.groups ?? [];

    List<ProcessedGroup> displayGroups = groups;

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage < displayGroups.length)
        ? startIndex + _itemsPerPage
        : displayGroups.length;
    final currentView = displayGroups.isNotEmpty
        ? displayGroups.sublist(startIndex, endIndex)
        : <ProcessedGroup>[];

    return AppScaffold(
      title: 'استيراد ملف الحضور Excel',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 700;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppCard(
                  padding: const EdgeInsets.all(16.0),
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
                  const Center(child: CircularProgressIndicator())
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
                          totalItems: displayGroups.length,
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

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AppLoadingButton(
                        onPressed: _isLoading ? null : _importData,
                        icon: Icons.save,
                        text: 'بدء الاستيراد والمعالجة',
                      ),
                    ],
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(
                      child: Text(
                        'اختر ملف واضغط على معاينة لعرض البيانات',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildControls(ThemeData theme, bool isMobile) {
    return [
      ElevatedButton.icon(
        onPressed: _pickFile,
        icon: const Icon(Icons.attach_file),
        label: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isMobile ? double.infinity : 150,
          ),
          child: Text(
            _selectedFile != null ? _selectedFile!.name : 'اختر ملف Excel',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      if (isMobile) const SizedBox(height: 8),
      const Text(
        'يقبل النظام ملفات Excel بصيغة xlsx فقط وبالأعمدة المحددة.',
        style: TextStyle(color: Colors.grey, fontSize: 12),
      ),
      if (isMobile) const SizedBox(height: 8),
      ElevatedButton.icon(
        onPressed: (_selectedFile != null && !_isLoading)
            ? _generatePreview
            : null,
        icon: const Icon(Icons.visibility),
        label: const Text('معاينة الملف'),
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.colorScheme.secondary,
          foregroundColor: Colors.white,
        ),
      ),
    ];
  }

  Widget _buildSummaryCard(PreprocessSummary s) {
    final dates = s.groups.map((g) => g.workDate).toSet().toList();
    dates.sort();
    final uniqueDatesCount = dates.length;
    final firstDate = dates.isNotEmpty ? Formatters.date(dates.first) : '-';
    final lastDate = dates.isNotEmpty ? Formatters.date(dates.last) : '-';

    return AppCard(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text(
              'تقرير المعاينة قبل الاستيراد',
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.normal,
              ),
            ),
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 8),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _summaryLine('صفوف Excel المقروءة', '${s.excelRowsRead}'),
                _summaryLine('أرقام بصمة في الملف', '${s.matchedEmployees}'),
                _summaryLine(
                  'ورديات من Excel',
                  '${s.groups.where((g) => g.shiftStart != null && g.shiftEnd != null).length}',
                ),
                _summaryLine('تواريخ الدوام المكتشفة', '$uniqueDatesCount'),
                _summaryLine('من تاريخ', firstDate),
                _summaryLine('إلى تاريخ', lastDate),
                _summaryLine('دخول مستخدم', '${s.usedCheckIns}'),
                _summaryLine('خروج مستخدم', '${s.usedCheckOuts}'),
                _summaryLine(
                  'حالات غياب',
                  '${s.absentCases}',
                  color: s.absentCases > 0 ? Colors.red : null,
                ),
                _summaryLine(
                  'فقدان بصمة دخول',
                  '${s.missingCheckIns}',
                  color: s.missingCheckIns > 0 ? Colors.red : null,
                ),
                _summaryLine(
                  'فقدان بصمة خروج',
                  '${s.missingCheckOuts}',
                  color: s.missingCheckOuts > 0 ? Colors.red : null,
                ),
                _summaryLine('إضافي متوقع', '${s.expectedOvertimeCases} حالة'),
                _summaryLine(
                  'مجموعات تحتاج مراجعة',
                  '${s.needsReviewGroups}',
                  color: s.needsReviewGroups > 0 ? Colors.orange : null,
                ),
              ],
            ),
          ],
        ),
      );
  }

  Widget _summaryLine(String title, String value, {Color? color}) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              
              color: color ?? Colors.black87,
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
        final statusLabel = group.isAbsent
            ? 'غياب'
            : (isReady ? 'جاهز' : 'يحتاج مراجعة');
        final statusColor = group.isAbsent
            ? Colors.red
            : (isReady ? Colors.green : Colors.orange);

        final bool isFirstOfDate =
            index == 0 || currentView[index - 1].workDate != group.workDate;

        String checkOutStr = "مفقود";
        if (group.actualCheckOut != null) {
          if (group.actualCheckOut!.day != group.workDate.day ||
              group.actualCheckOut!.month != group.workDate.month ||
              group.actualCheckOut!.year != group.workDate.year) {
            checkOutStr =
                '${Formatters.date(group.actualCheckOut)} ${Formatters.time(group.actualCheckOut)}';
          } else {
            checkOutStr = Formatters.time(group.actualCheckOut);
          }
        }

        String checkInStr = "مفقود";
        if (group.actualCheckIn != null) {
          if (group.actualCheckIn!.day != group.workDate.day ||
              group.actualCheckIn!.month != group.workDate.month ||
              group.actualCheckIn!.year != group.workDate.year) {
            checkInStr =
                '${Formatters.date(group.actualCheckIn)} ${Formatters.time(group.actualCheckIn)}';
          } else {
            checkInStr = Formatters.time(group.actualCheckIn);
          }
        }

        final card = AppCard(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'رقم البصمة: ${group.biometricId}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  AppStatusPill(
                    label: statusLabel,
                    color: statusColor,
                  ),
                ],
              ),
                const SizedBox(height: 8),
                const Divider(),
                const SizedBox(height: 8),
                if (group.employeeName != null)
                  _buildDataField('الاسم', group.employeeName!),
                _buildDataField('تاريخ الدوام', Formatters.date(group.workDate)),
                _buildDataField('الوردية المقترحة', group.suggestedShift?.name ?? "غير معروف"),
                if (group.shiftEnd != null)
                  _buildDataField('نهاية الدوام الرسمي', Formatters.time(group.shiftEnd!)),
                const Divider(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildDataField('الدخول المستخدم', checkInStr)),
                    Expanded(child: _buildDataField('الخروج الفعلي', checkOutStr)),
                  ],
                ),
                if (group.shiftEnd != null)
                  _buildDataField('شرط احتساب الإضافي', 'بعد تجاوز ${BiometricPreprocessor.overtimeMinimumTriggerMinutes} دقيقة', valueColor: Colors.grey),
                if (group.expectedOvertimeMinutes > 0)
                  _buildDataField('الإضافي المتوقع', Formatters.minutesToHours(group.expectedOvertimeMinutes), valueColor: Colors.blue),
                if (group.ignoredCount > 0)
                  _buildDataField('المكرر المتجاهل', '${group.ignoredCount}', valueColor: Colors.grey),
                if ((group.needsReview || group.isAbsent) && group.reviewReason.isNotEmpty)
                  _buildDataField('السبب', group.reviewReason, valueColor: Colors.red),
              ],
            ),
          );

        if (isFirstOfDate) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16, bottom: 8, right: 8),
                child: Text(
                  'تاريخ الدوام: ${Formatters.date(group.workDate)}',
                  style: const TextStyle(
                    
                    fontSize: 18,
                    color: Colors.blueGrey,
                  ),
                ),
              ),
              card,
            ],
          );
        }

        return card;
      },
    );
  }

  Widget _buildDataField(String title, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.normal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: valueColor ?? Colors.black87,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}


