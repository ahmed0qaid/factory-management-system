import 'package:flutter/material.dart';

import '../../models/attendance_model.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_semantic_colors.dart';
import '../../theme/app_spacing.dart';
import '../../utils/attendance_display.dart';

/// Period used by the employee attendance visual summary.
enum SummaryPeriod { day, week, month }

class AttendanceVisualSummaryChart extends StatefulWidget {
  final List<AttendanceRecordModel> records;

  const AttendanceVisualSummaryChart({
    super.key,
    required this.records,
  });

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
      final latest = [...widget.records]
        ..sort((a, b) => b.workDate.compareTo(a.workDate));
      _currentDate = latest.first.workDate;
    }
  }

  List<AttendanceRecordModel> get _currentRecords {
    final startOfWeek = _weekStart(_currentDate);
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return widget.records.where((record) {
      final date = _dateOnly(record.workDate);
      switch (_period) {
        case SummaryPeriod.day:
          return DateUtils.isSameDay(date, _currentDate);
        case SummaryPeriod.week:
          return !date.isBefore(startOfWeek) && !date.isAfter(endOfWeek);
        case SummaryPeriod.month:
          return date.year == _currentDate.year &&
              date.month == _currentDate.month;
      }
    }).toList();
  }

  DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  DateTime _weekStart(DateTime value) {
    final date = _dateOnly(value);
    final daysToSubtract = date.weekday == DateTime.sunday ? 0 : date.weekday;
    return date.subtract(Duration(days: daysToSubtract));
  }

  void _previous() {
    setState(() {
      switch (_period) {
        case SummaryPeriod.day:
          _currentDate = _currentDate.subtract(const Duration(days: 1));
        case SummaryPeriod.week:
          _currentDate = _currentDate.subtract(const Duration(days: 7));
        case SummaryPeriod.month:
          _currentDate = DateTime(
            _currentDate.year,
            _currentDate.month - 1,
            1,
          );
      }
    });
  }

  void _next() {
    setState(() {
      switch (_period) {
        case SummaryPeriod.day:
          _currentDate = _currentDate.add(const Duration(days: 1));
        case SummaryPeriod.week:
          _currentDate = _currentDate.add(const Duration(days: 7));
        case SummaryPeriod.month:
          _currentDate = DateTime(
            _currentDate.year,
            _currentDate.month + 1,
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

  String _formatTime(DateTime? value) {
    if (value == null) return 'غير مسجل';
    final hour = value.hour;
    final minute = value.minute.toString().padLeft(2, '0');
    final hour12 = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final period = hour < 12 ? 'ص' : 'م';
    return '$hour12:$minute $period';
  }

  Color _recordColor(BuildContext context, AttendanceRecordModel? record) {
    final scheme = Theme.of(context).colorScheme;
    final semantic = context.semanticColors;

    if (record == null) return scheme.surfaceContainerHighest;
    if (record.status == 'absent') return scheme.error;
    if (record.lateMinutes > 0 || record.earlyLeaveMinutes > 0) {
      return semantic.warning;
    }
    if (record.status == 'needs_review' ||
        record.status == 'incomplete' ||
        (record.checkIn != null && record.checkOut == null) ||
        (record.checkIn == null && record.checkOut != null)) {
      return scheme.outline;
    }
    if (record.checkIn != null && record.checkOut != null) {
      return semantic.success;
    }
    return scheme.primary;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(context),
        const SizedBox(height: AppSpacing.sm),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsetsDirectional.fromSTEB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: _buildContent(context),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

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
                onPressed: _previous,
                icon: const Icon(Icons.chevron_right),
              ),
              Expanded(
                child: Text(
                  _periodLabel(),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'الفترة التالية',
                onPressed: _next,
                icon: const Icon(Icons.chevron_left),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final records = _currentRecords;
    switch (_period) {
      case SummaryPeriod.day:
        return _buildDayView(context, records);
      case SummaryPeriod.week:
        return _buildWeekView(context, records);
      case SummaryPeriod.month:
        return _buildMonthView(context, records);
    }
  }

  Widget _buildDayView(
    BuildContext context,
    List<AttendanceRecordModel> records,
  ) {
    if (records.isEmpty) {
      return _emptyPeriod(context);
    }

    final record = records.first;
    final color = _recordColor(context, record);
    final needsReview = record.status == 'needs_review' ||
        record.status == 'incomplete' ||
        (record.checkIn != null && record.checkOut == null) ||
        (record.checkIn == null && record.checkOut != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.sm),
        _buildDayTimeline(context, record, color),
        const SizedBox(height: AppSpacing.lg),
        if (needsReview) ...[
          _attentionBanner(context, 'يحتاج هذا اليوم إلى مراجعة'),
          const SizedBox(height: AppSpacing.sm),
        ],
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppSpacing.xs,
          crossAxisSpacing: AppSpacing.xs,
          childAspectRatio: 2.15,
          children: [
            _SummaryCard(
              label: 'الحالة',
              value: statusLabel(record.status),
              color: color,
            ),
            _SummaryCard(
              label: 'الدخول',
              value: _formatTime(record.checkIn),
              color: color,
            ),
            _SummaryCard(
              label: 'الخروج',
              value: _formatTime(record.checkOut),
              color: color,
            ),
            _SummaryCard(
              label: 'التأخير',
              value: '${record.lateMinutes} د',
              color: context.semanticColors.warning,
            ),
            _SummaryCard(
              label: 'خروج مبكر',
              value: '${record.earlyLeaveMinutes} د',
              color: context.semanticColors.warning,
            ),
            _SummaryCard(
              label: 'ساعات العمل',
              value: '${(record.workedMinutes / 60).toStringAsFixed(1)} س',
              color: context.semanticColors.success,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDayTimeline(
    BuildContext context,
    AttendanceRecordModel record,
    Color mainColor,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    var start = record.scheduledStart;
    var end = record.scheduledEnd;

    if (start == null || end == null) {
      if (record.checkIn == null) return _emptyPeriod(context);
      start = record.checkIn!.subtract(const Duration(hours: 1));
      end = (record.checkOut ?? record.checkIn!).add(const Duration(hours: 1));
    }

    if (end.isBefore(start)) end = end.add(const Duration(days: 1));
    final totalMinutes = end.difference(start).inMinutes;
    if (totalMinutes <= 0) return _emptyPeriod(context);

    var actualOut = record.checkOut;
    if (record.checkIn != null &&
        actualOut != null &&
        actualOut.isBefore(record.checkIn!)) {
      actualOut = actualOut.add(const Duration(days: 1));
    }

    double percent(DateTime? value) {
      if (value == null) return 0;
      var adjusted = value;
      if (adjusted.isBefore(start!.subtract(const Duration(hours: 12)))) {
        adjusted = adjusted.add(const Duration(days: 1));
      }
      final difference = adjusted.difference(start).inMinutes.clamp(0, totalMinutes);
      return difference / totalMinutes;
    }

    final inPosition = percent(record.checkIn);
    final outPosition = percent(actualOut ?? record.checkIn);
    final workPercent = (outPosition - inPosition).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatTime(start), style: theme.textTheme.bodySmall),
            Text(_formatTime(end), style: theme.textTheme.bodySmall),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return Container(
              height: 18,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Stack(
                children: [
                  if (record.status == 'absent')
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.error,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    )
                  else if (record.checkIn != null)
                    PositionedDirectional(
                      start: inPosition * width,
                      width: record.checkOut == null
                          ? AppSpacing.xs
                          : workPercent * width,
                      top: 0,
                      bottom: 0,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: mainColor,
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            if (record.checkIn != null)
              Expanded(
                child: Text(
                  'دخول: ${_formatTime(record.checkIn)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: mainColor),
                ),
              ),
            if (record.checkOut != null)
              Expanded(
                child: Text(
                  'خروج: ${_formatTime(record.checkOut)}',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodySmall?.copyWith(color: mainColor),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekView(
    BuildContext context,
    List<AttendanceRecordModel> records,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final start = _weekStart(_currentDate);

    var presentCount = 0;
    var absentCount = 0;
    var totalLate = 0;
    var reviewCount = 0;

    final dayColumns = <Widget>[];
    for (var index = 0; index < 7; index++) {
      final date = start.add(Duration(days: index));
      AttendanceRecordModel? record;
      for (final candidate in records) {
        if (DateUtils.isSameDay(candidate.workDate, date)) {
          record = candidate;
          break;
        }
      }

      final color = _recordColor(context, record);
      if (record != null) {
        if (record.status == 'absent') {
          absentCount++;
        } else if (record.status == 'present' ||
            (record.checkIn != null && record.checkOut != null)) {
          presentCount++;
        }
        if (record.status == 'needs_review' ||
            record.status == 'incomplete' ||
            (record.checkIn != null && record.checkOut == null) ||
            (record.checkIn == null && record.checkOut != null)) {
          reviewCount++;
        }
        totalLate += record.lateMinutes;
      }

      dayColumns.add(
        Expanded(
          child: Column(
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(_weekDaysAr[index], style: theme.textTheme.bodySmall),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                '${date.day}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                height: 56,
                width: 22,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                height: 18,
                child: record != null && record.lateMinutes > 0
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${record.lateMinutes} د',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: semantic.warning,
                          ),
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: dayColumns,
        ),
        const SizedBox(height: AppSpacing.lg),
        Divider(color: scheme.outlineVariant),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: 'أيام الحضور',
                value: '$presentCount',
                color: semantic.success,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _SummaryCard(
                label: 'أيام الغياب',
                value: '$absentCount',
                color: scheme.error,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _SummaryCard(
                label: 'إجمالي التأخير',
                value: '$totalLate د',
                color: semantic.warning,
                compact: true,
              ),
            ),
            const SizedBox(width: AppSpacing.xxs),
            Expanded(
              child: _SummaryCard(
                label: 'حالات المراجعة',
                value: '$reviewCount',
                color: scheme.onSurfaceVariant,
                compact: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthView(
    BuildContext context,
    List<AttendanceRecordModel> records,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentDate.year,
      _currentDate.month,
    );

    var presentCount = 0;
    var absentCount = 0;
    var lateDaysCount = 0;
    var totalLateMinutes = 0;
    var totalEarlyMinutes = 0;
    var reviewCount = 0;

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

      final color = _recordColor(context, record);
      if (record != null) {
        if (record.status == 'absent') {
          absentCount++;
        } else if (record.status == 'present' ||
            (record.checkIn != null && record.checkOut != null)) {
          presentCount++;
        }
        if (record.lateMinutes > 0) lateDaysCount++;
        totalLateMinutes += record.lateMinutes;
        totalEarlyMinutes += record.earlyLeaveMinutes;
        if (record.status == 'needs_review' ||
            record.status == 'incomplete' ||
            (record.checkIn != null && record.checkOut == null) ||
            (record.checkIn == null && record.checkOut != null)) {
          reviewCount++;
        }
      }

      cells.add(
        Container(
          margin: const EdgeInsets.all(AppSpacing.xxs),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
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
        const SizedBox(height: AppSpacing.sm),
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
          childAspectRatio: 1.65,
          children: [
            _SummaryCard(
              label: 'الحضور',
              value: '$presentCount',
              color: semantic.success,
            ),
            _SummaryCard(
              label: 'الغياب',
              value: '$absentCount',
              color: scheme.error,
            ),
            _SummaryCard(
              label: 'أيام التأخير',
              value: '$lateDaysCount',
              color: semantic.warning,
            ),
            _SummaryCard(
              label: 'دقائق التأخير',
              value: '$totalLateMinutes',
              color: semantic.warning,
            ),
            _SummaryCard(
              label: 'خروج مبكر',
              value: '$totalEarlyMinutes',
              color: semantic.warning,
            ),
            _SummaryCard(
              label: 'مراجعة',
              value: '$reviewCount',
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ],
    );
  }

  Widget _attentionBanner(BuildContext context, String text) {
    final semantic = context.semanticColors;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: semantic.warningContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: semantic.onWarningContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _emptyPeriod(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xl),
      child: Text(
        'لا توجد بيانات دوام لهذه الفترة',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool compact;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      constraints: BoxConstraints(minHeight: compact ? 82 : 88),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? AppSpacing.xxs : AppSpacing.xs,
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
            height: compact ? 34 : 36,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
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
              textAlign: TextAlign.center,
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
