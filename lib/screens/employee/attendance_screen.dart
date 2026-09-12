import 'package:flutter/material.dart';

import '../../models/attendance_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_semantic_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/attendance_display.dart';
import '../../utils/formatters.dart';
import '../../widgets/attendance/attendance_visual_summary_chart.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_status_pill.dart';

enum AttendanceViewType { timeline, visual }

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final _service = EmployeeService();
  late Future<List<AttendanceRecordModel>> _future;

  AttendanceViewType _viewType = AttendanceViewType.timeline;
  int? _selectedYear;
  int? _selectedMonth;

  static const _monthsAr = <String>[
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.getMyAttendance(limit: 500);
  }

  void _reload() {
    setState(() {
      _future = _service.getMyAttendance(limit: 500);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AttendanceRecordModel>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(label: 'جاري تحميل سجلات الدوام');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'تعذر تحميل سجلات الدوام',
            message: '${snapshot.error}',
            onRetry: _reload,
          );
        }

        final rawItems = _deduplicate(snapshot.data ?? const []);
        final availableYears =
            rawItems.map((record) => record.workDate.year).toSet().toList()
              ..sort((a, b) => b.compareTo(a));

        final items = _applyFilters(rawItems);

        return Column(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AppDropdownField<int>(
                          hintText: 'السنة',
                          value: _selectedYear,
                          items: availableYears.map((year) {
                            return DropdownMenuItem(
                              value: year,
                              child: Text('$year'),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedYear = val;
                              _selectedMonth = null;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: AppDropdownField<int>(
                          hintText: 'الشهر',
                          value: _selectedMonth,
                          items: _selectedYear == null
                              ? []
                              : List.generate(12, (index) {
                                  final month = index + 1;
                                  return DropdownMenuItem(
                                    value: month,
                                    child: Text(_monthsAr[index]),
                                  );
                                }),
                          onChanged: (val) {
                            setState(() {
                              _selectedMonth = val;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  if (_selectedYear != null && _selectedMonth != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SegmentedButton<AttendanceViewType>(
                      segments: const [
                        ButtonSegment(
                          value: AttendanceViewType.timeline,
                          icon: Icon(Icons.timeline_outlined),
                          label: Text('المخطط الزمني'),
                        ),
                        ButtonSegment(
                          value: AttendanceViewType.visual,
                          icon: Icon(Icons.bar_chart_outlined),
                          label: Text('العرض الرسومي'),
                        ),
                      ],
                      selected: {_viewType},
                      showSelectedIcon: false,
                      onSelectionChanged: (selection) {
                        setState(() => _viewType = selection.first);
                      },
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: (_selectedYear == null || _selectedMonth == null)
                  ? const AppEmptyState(
                      title: 'اختر السنة والشهر',
                      message: 'يرجى تحديد الفترة لعرض تفاصيل الدوام.',
                      icon: Icons.calendar_month_outlined,
                    )
                  : _viewType == AttendanceViewType.visual
                  ? AttendanceVisualSummaryChart(records: items)
                  : items.isEmpty
                  ? const AppEmptyState(
                      title: 'لا توجد سجلات مطابقة',
                      message: 'لا توجد سجلات دوام في هذا الشهر.',
                      icon: Icons.event_busy_outlined,
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _future;
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          AppSpacing.md,
                          AppSpacing.xxs,
                          AppSpacing.md,
                          AppSpacing.xl,
                        ),
                        itemCount: items.length,
                        itemBuilder: (context, index) => _TimelineItem(
                          record: items[index],
                          isLast: index == items.length - 1,
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  List<AttendanceRecordModel> _applyFilters(
    List<AttendanceRecordModel> source,
  ) {
    var items = List<AttendanceRecordModel>.from(source);

    if (_selectedYear != null) {
      items = items
          .where((item) => item.workDate.year == _selectedYear)
          .toList();
    }
    if (_selectedMonth != null) {
      items = items
          .where((item) => item.workDate.month == _selectedMonth)
          .toList();
    }

    items.sort((a, b) {
      return b.workDate.compareTo(a.workDate);
    });
    return items;
  }

  List<AttendanceRecordModel> _deduplicate(List<AttendanceRecordModel> items) {
    final seen = <String>{};
    final result = <AttendanceRecordModel>[];
    for (final item in items) {
      final key = [
        Formatters.date(item.workDate),
        item.checkIn?.toIso8601String() ?? '',
        item.checkOut?.toIso8601String() ?? '',
        item.status,
      ].join('|');
      if (seen.add(key)) result.add(item);
    }
    return result;
  }
}

class _TimelineItem extends StatelessWidget {
  final AttendanceRecordModel record;
  final bool isLast;

  const _TimelineItem({required this.record, required this.isLast});

  String _dayMonth(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final color = _statusColor(context, record.status);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: AppSpacing.xl,
            child: Column(
              children: [
                Container(
                  width: AppSpacing.sm,
                  height: AppSpacing.sm,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xxs,
                      ),
                      color: color.withValues(alpha: .24),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.sm),
              borderColor: color.withValues(alpha: .24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _dayMonth(record.workDate),
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      _statusPill(record.status),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBox(
                          label: 'الحضور',
                          value: displayTime(record.checkIn),
                          color: color,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _MetricBox(
                          label: 'الانصراف',
                          value: displayTime(record.checkOut),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: _MetricBox(
                          label: 'التأخير',
                          value: displayMinutes(record.lateMinutes),
                          color: color,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: _MetricBox(
                          label: 'الانصراف المبكر',
                          value: displayMaybeComputedMinutes(
                            minutes: record.earlyLeaveMinutes,
                            isComputed: record.checkOut != null,
                          ),
                          color: color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  _MetricBox(
                    label: 'الدوام المحتسب',
                    value: displayMinutes(record.creditedMinutes),
                    color: color,
                  ),
                  if (record.reviewNote?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: Text(
                        record.reviewNote!.trim(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final label = statusLabel(status);
    switch (status) {
      case 'present':
      case 'approved':
      case 'paid':
      case 'completed':
        return AppStatusPill.success(label);
      case 'late':
      case 'pending':
      case 'incomplete':
      case 'needs_review':
        return AppStatusPill.warning(label);
      case 'absent':
      case 'rejected':
      case 'cancelled':
        return AppStatusPill.danger(label);
      default:
        return AppStatusPill.neutral(label);
    }
  }
}

class _MetricBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricBox({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(BuildContext context, String status) {
  final scheme = Theme.of(context).colorScheme;
  final semantic = context.semanticColors;

  switch (status) {
    case 'present':
    case 'approved':
    case 'paid':
    case 'completed':
      return semantic.success;
    case 'late':
    case 'pending':
    case 'incomplete':
    case 'needs_review':
      return semantic.warning;
    case 'absent':
    case 'rejected':
    case 'cancelled':
      return scheme.error;
    default:
      return scheme.onSurfaceVariant;
  }
}
