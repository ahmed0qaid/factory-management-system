import 'package:flutter/material.dart';

import '../../services/attendance_review_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class ManageAttendanceReviewScreen extends StatefulWidget {
  const ManageAttendanceReviewScreen({super.key});

  @override
  State<ManageAttendanceReviewScreen> createState() =>
      _ManageAttendanceReviewScreenState();
}

class _ManageAttendanceReviewScreenState
    extends State<ManageAttendanceReviewScreen> {
  final AttendanceReviewService _service = AttendanceReviewService();
  List<AttendanceReviewCase> _cases = [];
  bool _loading = true;
  String _filter = 'pending';
  String? _savingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _service.getReviews(filter: _filter);
      if (mounted) setState(() => _cases = result);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل حالات مراجعة الحضور: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openResolve(AttendanceReviewCase item) async {
    String resolution = 'present';
    DateTime? checkIn = item.checkIn;
    DateTime? checkOut = item.checkOut;
    final noteController = TextEditingController();

    DateTime withTime(DateTime base, TimeOfDay time) => DateTime(
      base.year,
      base.month,
      base.day,
      time.hour,
      time.minute,
    );

    Future<DateTime?> pickTime(
      BuildContext dialogContext,
      DateTime? current,
      bool isCheckout,
    ) async {
      final base = current ?? item.workDate;
      final picked = await showTimePicker(
        context: dialogContext,
        initialTime: TimeOfDay.fromDateTime(current ?? item.workDate),
      );
      if (picked == null) return current;
      var value = withTime(item.workDate, picked);
      if (isCheckout && checkIn != null && !value.isAfter(checkIn!)) {
        value = value.add(const Duration(days: 1));
      }
      return value;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text('مراجعة حضور ${item.employeeName}'),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('التاريخ: ${_date(item.workDate)}'),
                    const SizedBox(height: 6),
                    Text('نوع المشكلة: ${_issueLabel(item.issueType)}'),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: resolution,
                      decoration: const InputDecoration(labelText: 'القرار'),
                      items: const [
                        DropdownMenuItem(
                          value: 'present',
                          child: Text('اعتماد كحضور'),
                        ),
                        DropdownMenuItem(
                          value: 'absent',
                          child: Text('اعتماد كغياب'),
                        ),
                        DropdownMenuItem(
                          value: 'rest_day',
                          child: Text('اعتماد كيوم راحة'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => resolution = value);
                        }
                      },
                    ),
                    if (resolution == 'present') ...[
                      const SizedBox(height: 14),
                      _timeButton(
                        label: 'الدخول',
                        value: checkIn,
                        onPressed: () async {
                          final value = await pickTime(
                            dialogContext,
                            checkIn,
                            false,
                          );
                          setDialogState(() => checkIn = value);
                        },
                      ),
                      const SizedBox(height: 8),
                      _timeButton(
                        label: 'الخروج',
                        value: checkOut,
                        onPressed: () async {
                          final value = await pickTime(
                            dialogContext,
                            checkOut,
                            true,
                          );
                          setDialogState(() => checkOut = value);
                        },
                      ),
                    ],
                    const SizedBox(height: 14),
                    TextField(
                      controller: noteController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة القرار *',
                        hintText: 'اكتب سبب التصحيح أو الاعتماد',
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton.icon(
                onPressed: () {
                  if (noteController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('ملاحظة القرار مطلوبة.')),
                    );
                    return;
                  }
                  if (resolution == 'present' &&
                      (checkIn == null || checkOut == null)) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('اعتماد الحضور يتطلب دخولًا وخروجًا.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('حسم الحالة'),
              ),
            ],
          );
        },
      ),
    );

    if (confirmed != true) {
      noteController.dispose();
      return;
    }

    setState(() => _savingId = item.id);
    try {
      await _service.resolveReview(
        attendanceId: item.id,
        resolution: resolution,
        note: noteController.text,
        checkIn: checkIn,
        checkOut: checkOut,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حسم حالة الحضور بنجاح.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر حسم حالة الحضور: $error')),
        );
      }
    } finally {
      noteController.dispose();
      if (mounted) setState(() => _savingId = null);
    }
  }

  Widget _timeButton({
    required String label,
    required DateTime? value,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.schedule_outlined),
      label: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text('$label: ${value == null ? 'غير محدد' : _time(value)}'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مراجعة استثناءات الحضور',
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'حالات تحتاج قرارًا إداريًا',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'يجب حسم حالات البصمة الناقصة أو أيام الراحة أو غياب الجدول قبل اعتماد راتب الفترة.',
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'pending', label: Text('معلقة')),
                      ButtonSegment(value: 'resolved', label: Text('محسومة')),
                      ButtonSegment(value: 'all', label: Text('الكل')),
                    ],
                    selected: {_filter},
                    onSelectionChanged: (values) {
                      setState(() => _filter = values.first);
                      _load();
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const AppLoadingState(label: 'جاري تحميل حالات الحضور')
            else if (_cases.isEmpty)
              const AppEmptyState(
                title: 'لا توجد حالات',
                message: 'لا توجد حالات حضور مطابقة للفلتر الحالي.',
                icon: Icons.fact_check_outlined,
              )
            else
              ..._cases.map(_caseCard),
          ],
        ),
      ),
    );
  }

  Widget _caseCard(AttendanceReviewCase item) {
    final pending = item.reviewStatus != 'resolved';
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    pending ? Icons.priority_high : Icons.check_rounded,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.employeeName,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${_date(item.workDate)} • ${_issueLabel(item.issueType)}'),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: pending
                        ? scheme.errorContainer
                        : scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(pending ? 'معلقة' : 'محسومة'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                Text('الدوام: ${_timeRange(item.scheduledStart, item.scheduledEnd)}'),
                Text('الفعلي: ${_timeRange(item.checkIn, item.checkOut)}'),
                Text('الحالة: ${_statusLabel(item.status)}'),
              ],
            ),
            if (item.reviewNote?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text('ملاحظة: ${item.reviewNote}'),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: _savingId == item.id
                    ? null
                    : () => _openResolve(item),
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(
                  _savingId == item.id ? 'جاري الحفظ...' : 'مراجعة وحسم',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';

  String _timeRange(DateTime? start, DateTime? end) {
    if (start == null && end == null) return 'غير محدد';
    return '${start == null ? '—' : _time(start)} → ${end == null ? '—' : _time(end)}';
  }

  String _issueLabel(String value) {
    return switch (value) {
      'missing_check_in' => 'بصمة دخول مفقودة',
      'missing_check_out' => 'بصمة خروج مفقودة',
      'missing_both' => 'الدخول والخروج مفقودان',
      'missing_schedule' => 'جدول الدوام مفقود',
      'invalid_schedule' => 'جدول الدوام غير مكتمل',
      'rest_day_punch' => 'بصمة في يوم راحة',
      _ => value.trim().isEmpty ? 'استثناء حضور' : value,
    };
  }

  String _statusLabel(String value) {
    return switch (value) {
      'present' => 'حاضر',
      'late' => 'حاضر مع تأخير',
      'absent' => 'غائب',
      'rest_day' => 'يوم راحة',
      'needs_review' => 'يحتاج مراجعة',
      _ => value,
    };
  }
}
