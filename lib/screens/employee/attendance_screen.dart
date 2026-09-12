import 'package:flutter/material.dart';

import '../../models/attendance_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/attendance_display.dart';
import '../../utils/formatters.dart';
import '../../widgets/attendance/attendance_visual_summary_chart.dart';
import '../../widgets/common/app_bottom_sheet.dart';
import '../../widgets/common/app_card.dart';
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
  AttendanceViewType _viewType = AttendanceViewType.timeline;
  String _statusFilter = 'all';
  int? _yearFilter;
  int? _monthFilter;
  bool _sortDescending = true;

  final List<String> _monthsAr = const [
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

  int _getActiveFiltersCount() {
    var count = 0;
    if (_statusFilter != 'all') count++;
    if (_yearFilter != null) count++;
    if (_monthFilter != null) count++;
    if (!_sortDescending) count++;
    return count;
  }

  void _resetFilters() {
    setState(() {
      _statusFilter = 'all';
      _yearFilter = null;
      _monthFilter = null;
      _sortDescending = true;
    });
  }

  void _showFilterBottomSheet(List<int> availableYears) {
    var tempStatus = _statusFilter;
    var tempYear = _yearFilter;
    var tempMonth = _monthFilter;
    var tempSort = _sortDescending;

    AppBottomSheet.show(
      context,
      title: 'الفلاتر',
      child: StatefulBuilder(
        builder: (ctx, setModalState) {
          final textTheme = Theme.of(ctx).textTheme;
          final sectionStyle = textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('الحالة', style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModalChip(
                    'الكل',
                    tempStatus == 'all',
                    () => setModalState(() => tempStatus = 'all'),
                  ),
                  _buildModalChip(
                    'حاضر',
                    tempStatus == 'present',
                    () => setModalState(() => tempStatus = 'present'),
                  ),
                  _buildModalChip(
                    'غائب',
                    tempStatus == 'absent',
                    () => setModalState(() => tempStatus = 'absent'),
                  ),
                  _buildModalChip(
                    'تحتاج مراجعة',
                    tempStatus == 'needs_review',
                    () => setModalState(() => tempStatus = 'needs_review'),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('الترتيب', style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModalChip(
                    'الأحدث أولاً',
                    tempSort,
                    () => setModalState(() => tempSort = true),
                  ),
                  _buildModalChip(
                    'الأقدم أولاً',
                    !tempSort,
                    () => setModalState(() => tempSort = false),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('السنة', style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModalChip(
                    'الكل',
                    tempYear == null,
                    () => setModalState(() => tempYear = null),
                  ),
                  ...availableYears.map(
                    (year) => _buildModalChip(
                      year.toString(),
                      tempYear == year,
                      () => setModalState(() => tempYear = year),
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('الشهر', style: sectionStyle),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildModalChip(
                    'الكل',
                    tempMonth == null,
                    () => setModalState(() => tempMonth = null),
                  ),
                  ...List.generate(12, (index) {
                    final monthNum = index + 1;
                    return _buildModalChip(
                      _monthsAr[index],
                      tempMonth == monthNum,
                      () => setModalState(() => tempMonth = monthNum),
                    );
                  }),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _resetFilters();
                      },
                      child: const Text('إعادة تعيين'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        setState(() {
                          _statusFilter = tempStatus;
                          _yearFilter = tempYear;
                          _monthFilter = tempMonth;
                          _sortDescending = tempSort;
                        });
                        Navigator.pop(ctx);
                      },
                      child: const Text('تطبيق'),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildModalChip(String label, bool isSelected, VoidCallback onTap) {
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = EmployeeService();

    return FutureBuilder<List<AttendanceRecordModel>>(
      future: service.getMyAttendance(limit: 500),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(label: 'جاري تحميل سجلات الدوام');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'تعذر تحميل سجلات الدوام',
            message: '${snapshot.error}',
          );
        }

        final rawItems = _deduplicate(snapshot.data ?? const []);
        final availableYears = rawItems
            .map((record) => record.workDate.year)
            .toSet()
            .toList()
          ..sort((a, b) => b.compareTo(a));

        var items = List<AttendanceRecordModel>.from(rawItems);
        if (_statusFilter != 'all') {
          items = items
              .where((item) => item.status == _statusFilter)
              .toList();
        }
        if (_yearFilter != null) {
          items = items
              .where((item) => item.workDate.year == _yearFilter)
              .toList();
        }
        if (_monthFilter != null) {
          items = items
              .where((item) => item.workDate.month == _monthFilter)
              .toList();
        }
        items.sort((a, b) {
          final comparison = a.workDate.compareTo(b.workDate);
          return _sortDescending ? -comparison : comparison;
        });

        final activeCount = _getActiveFiltersCount();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                  if (_viewType == AttendanceViewType.timeline) ...[
                    const SizedBox(height: 8),
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.filter_list),
                        label: Text(
                          activeCount > 0
                              ? 'الفلاتر ($activeCount)'
                              : 'الفلاتر',
                        ),
                        onPressed: () =>
                            _showFilterBottomSheet(availableYears),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              child: _viewType == AttendanceViewType.visual
                  ? AttendanceVisualSummaryChart(records: rawItems)
                  : items.isEmpty
                      ? const AppEmptyState(
                          title: 'لا توجد سجلات مطابقة',
                          message:
                              'غيّر الفلاتر أو أعد تعيينها لعرض سجلات أخرى.',
                          icon: Icons.event_busy_outlined,
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                          itemCount: items.length,
                          itemBuilder: (context, index) {
                            return _TimelineItem(
                              record: items[index],
                              isLast: index == items.length - 1,
                            );
                          },
                        ),
            ),
          ],
        );
      },
    );
  }

  List<AttendanceRecordModel> _deduplicate(
    List<AttendanceRecordModel> items,
  ) {
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
            width: 24,
            child: Column(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: color.withValues(alpha: .28),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AppCard(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              borderColor: color.withValues(alpha: .24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          Formatters.date(record.workDate),
                          textAlign: TextAlign.start,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: scheme.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusPill(record.status),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _MetricPair(
                    color: color,
                    first: _MetricValue(
                      'الحضور',
                      displayTime(record.checkIn),
                    ),
                    second: _MetricValue(
                      'الانصراف',
                      displayTime(record.checkOut),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetricPair(
                    color: color,
                    first: _MetricValue(
                      'التأخير',
                      displayMinutes(record.lateMinutes),
                    ),
                    second: _MetricValue(
                      'الانصراف المبكر',
                      displayMaybeComputedMinutes(
                        minutes: record.earlyLeaveMinutes,
                        isComputed: record.checkOut != null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MetricBox(
                    value: _MetricValue(
                      'الدوام المحتسب',
                      displayMinutes(record.creditedMinutes),
                    ),
                    color: color,
                  ),
                  if (record.reviewNote != null &&
                      record.reviewNote!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer,
                        borderRadius: BorderRadius.circular(10),
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

  Widget _buildStatusPill(String status) {
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

class _MetricPair extends StatelessWidget {
  final _MetricValue first;
  final _MetricValue second;
  final Color color;

  const _MetricPair({
    required this.first,
    required this.second,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _MetricBox(value: first, color: color)),
        const SizedBox(width: 8),
        Expanded(child: _MetricBox(value: second, color: color)),
      ],
    );
  }
}

class _MetricValue {
  final String label;
  final String value;

  const _MetricValue(this.label, this.value);
}

class _MetricBox extends StatelessWidget {
  final _MetricValue value;
  final Color color;

  const _MetricBox({required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: .22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            value.label,
            maxLines: 1,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value.value,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: scheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
