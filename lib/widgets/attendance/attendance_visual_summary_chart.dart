import 'package:flutter/material.dart';

import '../../models/attendance_model.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_semantic_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/attendance_display.dart';
import '../common/app_card.dart';

enum SummaryPeriod { day, week, month }

class AttendanceVisualSummaryChart extends StatefulWidget {
  final List<AttendanceRecordModel> records;

  const AttendanceVisualSummaryChart({super.key, required this.records});

  @override
  State<AttendanceVisualSummaryChart> createState() =>
      _AttendanceVisualSummaryChartState();
}

class _AttendanceVisualSummaryChartState
    extends State<AttendanceVisualSummaryChart> {
  SummaryPeriod _period = SummaryPeriod.day;
  DateTime _currentDate = DateTime.now();

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

  static const _weekDaysAr = <String>[
    'أحد',
    'إثنين',
    'ثلاثاء',
    'أربعاء',
    'خميس',
    'جمعة',
    'سبت',
  ];

  @override
  void didUpdateWidget(covariant AttendanceVisualSummaryChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.records.isNotEmpty && oldWidget.records != widget.records) {
      final sorted = [...widget.records]
        ..sort((a, b) => b.workDate.compareTo(a.workDate));
      _currentDate = sorted.first.workDate;
    }
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _weekStart(DateTime value) {
    final date = _dateOnly(value);
    final offset = date.weekday == DateTime.sunday ? 0 : date.weekday;
    return date.subtract(Duration(days: offset));
  }

  List<AttendanceRecordModel> get _currentRecords {
    final start = _weekStart(_currentDate);
    final end = start.add(const Duration(days: 6));

    return widget.records.where((record) {
      if (_statusFilter != 'all') {
        if (_statusFilter == 'present' &&
            record.status != 'present' &&
            (record.checkIn == null || record.checkOut == null))
          return false;
        if (_statusFilter == 'absent' && record.status != 'absent')
          return false;
        if (_statusFilter == 'late' && record.lateMinutes == 0) return false;
        if (_statusFilter == 'needs_review' &&
            record.status != 'needs_review' &&
            record.status != 'incomplete')
          return false;
      }
      final date = _dateOnly(record.workDate);
      switch (_period) {
        case SummaryPeriod.day:
          return DateUtils.isSameDay(date, _currentDate);
        case SummaryPeriod.week:
          return !date.isBefore(start) && !date.isAfter(end);
        case SummaryPeriod.month:
          return date.year == _currentDate.year &&
              date.month == _currentDate.month;
      }
    }).toList();
  }

  void _movePeriod(int direction) {
    setState(() {
      switch (_period) {
        case SummaryPeriod.day:
          _currentDate = _currentDate.add(Duration(days: direction));
        case SummaryPeriod.week:
          _currentDate = _currentDate.add(Duration(days: 7 * direction));
        case SummaryPeriod.month:
          _currentDate = DateTime(
            _currentDate.year,
            _currentDate.month + direction,
            1,
          );
      }
    });
  }

  String _dayMonth(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  String _periodLabel() {
    switch (_period) {
      case SummaryPeriod.day:
        return _dayMonth(_currentDate);
      case SummaryPeriod.week:
        final start = _weekStart(_currentDate);
        final end = start.add(const Duration(days: 6));
        return '${_dayMonth(start)} - ${_dayMonth(end)}';
      case SummaryPeriod.month:
        return _monthsAr[_currentDate.month - 1];
    }
  }

  String _time(DateTime? value) {
    if (value == null) return 'غير مسجل';
    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$hour12:$minute ${hour < 12 ? 'ص' : 'م'}';
  }

  Color _recordColor(BuildContext context, AttendanceRecordModel? record) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    if (record == null) return scheme.surfaceContainerHighest;
    if (record.status == 'absent') return scheme.error;
    if (record.status == 'needs_review' || record.status == 'incomplete') {
      return scheme.outline;
    }
    if (record.lateMinutes > 0 || record.earlyLeaveMinutes > 0) {
      return semantic.warning;
    }
    return semantic.success;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: _content(context),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        children: [
          SegmentedButton<SummaryPeriod>(
            segments: const [
              ButtonSegment(value: SummaryPeriod.day, label: Text('يوم')),
              ButtonSegment(value: SummaryPeriod.week, label: Text('أسبوع')),
              ButtonSegment(value: SummaryPeriod.month, label: Text('شهر')),
            ],
            selected: {_period},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              setState(() => _period = selection.first);
            },
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              IconButton(
                tooltip: 'الفترة السابقة',
                onPressed: () => _movePeriod(-1),
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Text(
                  _periodLabel(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'الفترة التالية',
                onPressed: () => _movePeriod(1),
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final records = _currentRecords;
    switch (_period) {
      case SummaryPeriod.day:
        return _dayView(context, records);
      case SummaryPeriod.week:
        return _weekView(context, records);
      case SummaryPeriod.month:
        return _monthView(context, records);
    }
  }

  Widget _dayView(BuildContext context, List<AttendanceRecordModel> records) {
    if (records.isEmpty) return _empty(context);

    final record = records.first;
    final color = _recordColor(context, record);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          borderColor: color.withValues(alpha: .28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      statusLabel(record.status),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    _dayMonth(record.workDate),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              _twoMetrics(
                context,
                _Metric('الدخول', _time(record.checkIn)),
                _Metric('الخروج', _time(record.checkOut)),
                color,
              ),
              const SizedBox(height: AppSpacing.xs),
              _twoMetrics(
                context,
                _Metric('التأخير', '${record.lateMinutes} د'),
                _Metric('الخروج المبكر', '${record.earlyLeaveMinutes} د'),
                color,
              ),
              const SizedBox(height: AppSpacing.xs),
              _metricBox(
                context,
                _Metric(
                  'الدوام المحتسب',
                  '${(record.creditedMinutes / 60).toStringAsFixed(1)} س',
                ),
                color,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _weekView(BuildContext context, List<AttendanceRecordModel> records) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final start = _weekStart(_currentDate);

    var present = 0;
    var absent = 0;
    var lateMinutes = 0;
    var review = 0;

    final days = <Widget>[];
    for (var index = 0; index < 7; index++) {
      final date = start.add(Duration(days: index));
      AttendanceRecordModel? record;
      for (final candidate in records) {
        if (DateUtils.isSameDay(candidate.workDate, date)) {
          record = candidate;
          break;
        }
      }

      if (record != null) {
        if (record.status == 'absent') {
          absent++;
        } else if (record.status == 'present' ||
            (record.checkIn != null && record.checkOut != null)) {
          present++;
        }
        if (record.status == 'needs_review' ||
            record.status == 'incomplete' ||
            (record.checkIn != null && record.checkOut == null) ||
            (record.checkIn == null && record.checkOut != null)) {
          review++;
        }
        lateMinutes += record.lateMinutes;
      }

      final color = _recordColor(context, record);
      days.add(
        Expanded(
          child: Column(
            children: [
              FittedBox(fit: BoxFit.scaleDown, child: Text(_weekDaysAr[index])),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${date.day}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                width: 22,
                height: 56,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(children: days),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'أيام الحضور',
                value: '$present',
                color: semantic.success,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _SummaryCard(
                label: 'أيام الغياب',
                value: '$absent',
                color: scheme.error,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _SummaryCard(
                label: 'إجمالي التأخير',
                value: '$lateMinutes د',
                color: semantic.warning,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _SummaryCard(
                label: 'حالات المراجعة',
                value: '$review',
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _monthView(BuildContext context, List<AttendanceRecordModel> records) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentDate.year,
      _currentDate.month,
    );

    var present = 0;
    var absent = 0;
    var lateDays = 0;
    var lateMinutes = 0;
    var earlyMinutes = 0;
    var review = 0;

    final cells = <Widget>[];
    for (var day = 1; day <= daysInMonth; day++) {
      AttendanceRecordModel? record;
      for (final candidate in records) {
        if (candidate.workDate.year == _currentDate.year &&
            candidate.workDate.month == _currentDate.month &&
            candidate.workDate.day == day) {
          record = candidate;
          break;
        }
      }

      if (record != null) {
        if (record.status == 'absent') {
          absent++;
        } else if (record.status == 'present' ||
            (record.checkIn != null && record.checkOut != null)) {
          present++;
        }
        if (record.lateMinutes > 0) lateDays++;
        lateMinutes += record.lateMinutes;
        earlyMinutes += record.earlyLeaveMinutes;
        if (record.status == 'needs_review' || record.status == 'incomplete') {
          review++;
        }
      }

      final color = _recordColor(context, record);
      cells.add(
        Container(
          margin: const EdgeInsets.all(AppSpacing.xxs),
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          alignment: Alignment.center,
          child: Text(
            '$day',
            style: theme.textTheme.labelSmall?.copyWith(
              color: record == null ? scheme.onSurfaceVariant : scheme.surface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: AppSpacing.sm),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 1.55,
          children: [
            _SummaryCard(
              label: 'الحضور',
              value: '$present',
              color: semantic.success,
            ),
            _SummaryCard(
              label: 'الغياب',
              value: '$absent',
              color: scheme.error,
            ),
            _SummaryCard(
              label: 'أيام التأخير',
              value: '$lateDays',
              color: semantic.warning,
            ),
            _SummaryCard(
              label: 'دقائق التأخير',
              value: '$lateMinutes',
              color: semantic.warning,
            ),
            _SummaryCard(
              label: 'خروج مبكر',
              value: '$earlyMinutes',
              color: semantic.warning,
            ),
            _SummaryCard(
              label: 'مراجعة',
              value: '$review',
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  Widget _twoMetrics(
    BuildContext context,
    _Metric first,
    _Metric second,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(child: _metricBox(context, first, color)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(child: _metricBox(context, second, color)),
      ],
    );
  }

  Widget _metricBox(BuildContext context, _Metric metric, Color color) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            metric.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            metric.value,
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

  Widget _filterChip(String label, String value) {
    final selected = _statusFilter == value;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _statusFilter = value),
      backgroundColor: scheme.surfaceContainerHighest,
      selectedColor: scheme.primaryContainer,
      labelStyle: theme.textTheme.labelMedium?.copyWith(
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.full),
        side: BorderSide(color: selected ? scheme.primary : Colors.transparent),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Text(
        'لا توجد بيانات دوام لهذه الفترة',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _Metric {
  final String label;
  final String value;

  const _Metric(this.label, this.value);
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 82),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxs,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 34,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 2,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
