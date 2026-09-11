import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../models/attendance_model.dart';
import '../../models/profile_model.dart';
import '../../services/employee_service.dart';
import '../../services/employee_tab_navigation.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/attendance_display.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/app_status_badge.dart';
import 'advance_balance_details_screen.dart';
import 'factory_stoppages_screen.dart';
import 'leave_requests_screen.dart';
import 'penalties_screen.dart';

class EmployeeHomeScreen extends StatefulWidget {
  final ProfileModel profile;

  const EmployeeHomeScreen({super.key, required this.profile});

  @override
  State<EmployeeHomeScreen> createState() => _EmployeeHomeScreenState();
}

class _EmployeeHomeScreenState extends State<EmployeeHomeScreen> {
  final _service = EmployeeService();
  late Future<_HomeSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    _summaryFuture = _loadSummary();
  }

  Future<_HomeSummary> _loadSummary() async {
    final results = await Future.wait<dynamic>([
      _service.getAdvanceBalance().catchError((error) {
        debugPrint('advances failed: $error');
        return AdvanceBalanceInfo(
          periodStart: DateTime.now(),
          periodEnd: DateTime.now(),
          workingDaysInPeriod: 0,
          workingDaysUntilToday: 0,
          attendanceDays: 0,
          monthlyEntitlement: 0,
          accruedSalary: 0,
          previousAdvances: 0,
          penaltiesCount: 0,
          penaltiesAmount: 0,
          availableBalance: 0,
          canRequestAdvance: false,
        );
      }),
      _service.getLeaveRequestsCount().catchError((error) {
        debugPrint('leave_requests failed: $error');
        return 0;
      }),
      _service.getFactoryStoppages().catchError((error) {
        debugPrint('factory_stoppages failed: $error');
        return <Map<String, dynamic>>[];
      }),
      _service.getMyAttendance(limit: 100).catchError((error) {
        debugPrint('attendance_records failed: $error');
        return <AttendanceRecordModel>[];
      }),
    ]);

    return _HomeSummary(
      balance: results[0] as AdvanceBalanceInfo,
      leavesCount: results[1] as int,
      stoppagesCount: (results[2] as List).length,
      attendance: results[3] as List<AttendanceRecordModel>,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        setState(_loadData);
        await _summaryFuture;
      },
      child: FutureBuilder<_HomeSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.screenBottom,
            ),
            children: [
              _employeeHeader(context),
              const SizedBox(height: AppSpacing.md),
              if (snapshot.connectionState != ConnectionState.done)
                const AppLoadingState(label: 'جاري تحميل ملخص الموظف')
              else if (snapshot.hasError)
                AppErrorState(
                  title: 'تعذر تحميل الملخص',
                  message: '${snapshot.error}',
                  onRetry: () => setState(_loadData),
                )
              else
                _summaryContent(context, snapshot.data!),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryContent(BuildContext context, _HomeSummary summary) {
    final attendance = _AttendanceSummary.from(summary.attendance);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'حالة الدوام'),
        const SizedBox(height: AppSpacing.xs),
        _attendanceOverviewCard(context, attendance),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(
          title: 'ملخص الفترة الحالية',
          icon: Icons.dashboard_outlined,
        ),
        const SizedBox(height: AppSpacing.xs),
        _periodGrid(context, summary),
        const SizedBox(height: AppSpacing.lg),
        const AppSectionHeader(
          title: 'مؤشرات الدوام',
          icon: Icons.query_stats_outlined,
        ),
        const SizedBox(height: AppSpacing.xs),
        _attendanceMetrics(context, attendance),
      ],
    );
  }

  Widget _employeeHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = widget.profile.fullName.trim().isNotEmpty
        ? widget.profile.fullName.trim()
        : widget.profile.employeeNumber;
    final jobTitle = widget.profile.jobTitleName?.trim().isNotEmpty == true
        ? widget.profile.jobTitleName!.trim()
        : widget.profile.roleLabel;
    final department = widget.profile.departmentName?.trim().isNotEmpty == true
        ? widget.profile.departmentName!.trim()
        : 'بدون قسم';

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 21,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              _employeeInitial,
              style: textTheme.titleMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        jobTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Text(
                      widget.profile.employeeNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                      child: Text(
                        '•',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.outline,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        department,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _attendanceOverviewCard(
    BuildContext context,
    _AttendanceSummary attendance,
  ) {
    if (!attendance.hasRecords) {
      return AppEmptyState(
        title: 'لا توجد سجلات دوام بعد',
        message: 'ستظهر حالة الحضور والانصراف هنا بعد تسجيل أول حركة.',
        icon: Icons.event_available_outlined,
        actionLabel: 'فتح سجل الدوام',
        onAction: _openAttendanceDetails,
      );
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final statusColor = _statusSemanticColor(attendance.latestStatus);

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: scheme.onPrimaryContainer,
                  size: 19,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آخر دوام',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      attendance.latestWorkDateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              AppStatusBadge(
                label: _localizedStatusLabel(attendance.latestStatus),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'آخر حضور',
                  value: attendance.latestCheckInText,
                  icon: Icons.login,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: _MiniMetric(
                  label: 'آخر انصراف',
                  value: attendance.latestCheckOutText,
                  icon: Icons.logout,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 36,
            child: FilledButton.tonalIcon(
              onPressed: _openAttendanceDetails,
              icon: const Icon(Icons.timeline_outlined, size: 17),
              label: const Text('عرض سجل الدوام'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _periodGrid(BuildContext context, _HomeSummary summary) {
    final items = [
      _DashboardItem(
        title: 'رصيد السلفة',
        value: Formatters.money(summary.balance.availableBalance),
        subtitle: 'المتاح حاليًا',
        icon: Icons.account_balance_wallet_outlined,
        color: AppColors.secondary,
        isActive: summary.balance.availableBalance > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AdvanceBalanceDetailsScreen(),
          ),
        ),
      ),
      _DashboardItem(
        title: 'توقفات المصنع',
        value: summary.stoppagesCount.toString(),
        subtitle: 'الحالات المسجلة',
        icon: Icons.factory_outlined,
        color: AppColors.tertiary,
        isActive: summary.stoppagesCount > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FactoryStoppagesScreen()),
        ),
      ),
      _DashboardItem(
        title: 'طلبات الإجازة',
        value: summary.leavesCount.toString(),
        subtitle: 'الطلبات المسجلة',
        icon: Icons.event_available_outlined,
        color: AppColors.primary,
        isActive: summary.leavesCount > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LeaveRequestsScreen()),
        ),
      ),
      _DashboardItem(
        title: 'الجزاءات',
        value: summary.balance.penaltiesCount.toString(),
        subtitle: Formatters.money(summary.balance.penaltiesAmount),
        icon: Icons.gavel_outlined,
        color: AppColors.tertiary,
        isActive: summary.balance.penaltiesCount > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PenaltiesScreen(showAppBar: true),
          ),
        ),
      ),
    ];

    return _CompactGrid(items: items);
  }

  Widget _attendanceMetrics(
    BuildContext context,
    _AttendanceSummary attendance,
  ) {
    if (!attendance.hasRecords) {
      return const AppEmptyState(
        title: 'لا توجد مؤشرات دوام',
        message: 'لم يتم العثور على بيانات كافية لحساب مؤشرات الدوام.',
        icon: Icons.query_stats_outlined,
      );
    }

    final items = [
      _DashboardItem(
        title: 'أيام الدوام',
        value: attendance.workDays.toString(),
        subtitle: 'في الفترة الحالية',
        icon: Icons.calendar_today_outlined,
        color: AppColors.primary,
        isActive: attendance.workDays > 0,
        onTap: _openAttendanceDetails,
      ),
      _DashboardItem(
        title: 'الغياب',
        value: attendance.absentDays.toString(),
        subtitle: 'أيام الغياب',
        icon: Icons.event_busy_outlined,
        color: AppColors.danger,
        isActive: attendance.absentDays > 0,
        onTap: _openAttendanceDetails,
      ),
      _DashboardItem(
        title: 'مراجعات البصمة',
        value: attendance.reviewDays.toString(),
        subtitle: 'تحتاج مراجعة',
        icon: Icons.fact_check_outlined,
        color: AppColors.warning,
        isActive: attendance.reviewDays > 0,
        onTap: _openAttendanceDetails,
      ),
      _DashboardItem(
        title: 'آخر دوام',
        value: attendance.latestWorkDateText,
        subtitle: _localizedStatusLabel(attendance.latestStatus),
        icon: Icons.history_toggle_off_outlined,
        color: AppColors.secondary,
        isActive: true,
        onTap: _openAttendanceDetails,
      ),
    ];

    return _CompactGrid(items: items);
  }

  void _openAttendanceDetails() {
    EmployeeTabNavigation.openAttendance();
  }

  String get _employeeInitial {
    final name = widget.profile.fullName.trim();
    if (name.isNotEmpty) return name.substring(0, 1);
    final employeeNumber = widget.profile.employeeNumber.trim();
    return employeeNumber.isNotEmpty ? employeeNumber.substring(0, 1) : 'م';
  }

  Color _statusSemanticColor(String status) {
    switch (status) {
      case 'present':
      case 'approved':
      case 'paid':
      case 'completed':
        return AppColors.success;
      case 'late':
      case 'pending':
      case 'incomplete':
      case 'needs_review':
        return AppColors.warning;
      case 'absent':
      case 'rejected':
      case 'cancelled':
        return AppColors.danger;
      default:
        return AppColors.secondary;
    }
  }

  String _localizedStatusLabel(String status) {
    switch (status) {
      case 'present':
        return 'حاضر';
      case 'completed':
        return 'مكتمل';
      case 'absent':
        return 'غائب';
      case 'late':
        return 'متأخر';
      case 'needs_review':
        return 'تحتاج مراجعة';
      case 'pending':
        return 'بحاجة اعتماد';
      case 'approved':
        return 'معتمد';
      case 'rejected':
        return 'مرفوض';
      case 'paid':
        return 'مدفوع';
      case 'leave':
        return 'إجازة';
      case 'incomplete':
        return 'غير مكتمل';
      default:
        return 'غير محدد';
    }
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Container(
      constraints: const BoxConstraints(minHeight: 54),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: colors.primary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontSize: 11,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactGrid extends StatelessWidget {
  final List<_DashboardItem> items;

  const _CompactGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 4 : 2;
        final itemWidth =
            (constraints.maxWidth - (AppSpacing.sm * (columns - 1))) / columns;
        const itemHeight = 112.0;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: itemWidth / itemHeight,
          ),
          itemBuilder: (context, index) => _HomeSummaryCard(item: items[index]),
        );
      },
    );
  }
}

class _HomeSummaryCard extends StatelessWidget {
  final _DashboardItem item;

  const _HomeSummaryCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final borderColor = item.isActive
        ? item.color.withValues(alpha: .30)
        : colors.outlineVariant;
    final valueColor = item.isActive ? item.color : colors.onSurfaceVariant;

    return AppCard(
      onTap: item.onTap,
      padding: const EdgeInsets.all(AppSpacing.sm),
      borderColor: borderColor,
      elevated: item.isActive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 27,
                height: 27,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(item.icon, size: 16, color: item.color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleMedium?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          if (item.subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              item.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
                fontSize: 10.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isActive;
  final VoidCallback onTap;

  const _DashboardItem({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isActive = true,
    required this.onTap,
  });
}

class _AttendanceSummary {
  final bool hasRecords;
  final int workDays;
  final int reviewDays;
  final int absentDays;
  final String latestStatus;
  final String latestWorkDateText;
  final String latestCheckInText;
  final String latestCheckOutText;

  const _AttendanceSummary({
    required this.hasRecords,
    required this.workDays,
    required this.reviewDays,
    required this.absentDays,
    required this.latestStatus,
    required this.latestWorkDateText,
    required this.latestCheckInText,
    required this.latestCheckOutText,
  });

  factory _AttendanceSummary.from(List<AttendanceRecordModel> records) {
    final deduped = _deduplicateAttendance(records);
    if (deduped.isEmpty) {
      return const _AttendanceSummary(
        hasRecords: false,
        workDays: 0,
        reviewDays: 0,
        absentDays: 0,
        latestStatus: 'incomplete',
        latestWorkDateText: '-',
        latestCheckInText: '-',
        latestCheckOutText: '-',
      );
    }

    final now = DateTime.now();
    final currentMonth = deduped
        .where(
          (item) =>
              item.workDate.year == now.year &&
              item.workDate.month == now.month,
        )
        .toList();
    final visibleRecords = currentMonth.isNotEmpty ? currentMonth : deduped;
    final latest = visibleRecords.first;

    return _AttendanceSummary(
      hasRecords: true,
      workDays: _distinctWorkDates(
        visibleRecords.where((item) => item.status != 'absent'),
      ).length,
      reviewDays: _distinctWorkDates(
        visibleRecords.where((item) => item.status == 'needs_review'),
      ).length,
      absentDays: _distinctWorkDates(
        visibleRecords.where((item) => item.status == 'absent'),
      ).length,
      latestStatus: latest.status,
      latestWorkDateText: Formatters.date(latest.workDate),
      latestCheckInText: displayTime(latest.checkIn),
      latestCheckOutText: displayTime(latest.checkOut),
    );
  }

  static List<AttendanceRecordModel> _deduplicateAttendance(
    List<AttendanceRecordModel> items,
  ) {
    final sorted = [...items]..sort((a, b) => b.workDate.compareTo(a.workDate));
    final seen = <String>{};
    final result = <AttendanceRecordModel>[];
    for (final item in sorted) {
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

  static Set<String> _distinctWorkDates(
    Iterable<AttendanceRecordModel> records,
  ) {
    return records.map((item) => Formatters.date(item.workDate)).toSet();
  }
}

class _HomeSummary {
  final AdvanceBalanceInfo balance;
  final int leavesCount;
  final int stoppagesCount;
  final List<AttendanceRecordModel> attendance;

  const _HomeSummary({
    required this.balance,
    required this.leavesCount,
    required this.stoppagesCount,
    required this.attendance,
  });
}
