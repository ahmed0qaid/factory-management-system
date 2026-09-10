import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../models/attendance_model.dart';
import '../../models/profile_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/attendance_display.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_action_card.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/app_stat_card.dart';
import '../../widgets/common/app_status_badge.dart';
import 'advance_balance_details_screen.dart';
import 'attendance_timeline_screen.dart';
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
      _service.getAdvanceBalance().catchError((e) {
        debugPrint('advances failed: $e');
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
      _service.getLeaveRequestsCount().catchError((e) {
        debugPrint('leave_requests failed: $e');
        return 0;
      }),
      _service.getFactoryStoppages().catchError((e) {
        debugPrint('factory_stoppages failed: $e');
        return <Map<String, dynamic>>[];
      }),
      _service.getMyAttendance(limit: 100).catchError((e) {
        debugPrint('attendance_records failed: $e');
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
      onRefresh: () async => setState(_loadData),
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
              const SizedBox(height: AppSpacing.lg),
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _attendanceOverviewCard(context, attendance),
        const SizedBox(height: AppSpacing.xl),
        AppSectionHeader(
          title: 'ملخص الفترة الحالية',
          actionLabel: 'تفاصيل الدوام',
          actionIcon: Icons.timeline,
          onAction: _openAttendanceDetails,
        ),
        const SizedBox(height: AppSpacing.sm),
        _periodGrid(context, summary),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(title: 'مؤشرات الدوام'),
        const SizedBox(height: AppSpacing.sm),
        _attendanceMetrics(context, attendance),
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(title: 'إجراءات سريعة'),
        const SizedBox(height: AppSpacing.sm),
        _quickActions(context, summary),
      ],
    );
  }

  Widget _employeeHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final jobTitle = widget.profile.jobTitleName?.trim().isNotEmpty == true
        ? widget.profile.jobTitleName!.trim()
        : 'غير محدد';
    final department = widget.profile.departmentName?.trim().isNotEmpty == true
        ? widget.profile.departmentName!.trim()
        : 'بدون قسم محدد';

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  _employeeInitial,
                  style: textTheme.headlineSmall?.copyWith(
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أهلاً، ${widget.profile.fullName}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      jobTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              AppStatusBadge(
                label: 'رقم الموظف: ${widget.profile.employeeNumber}',
                color: AppColors.primary,
                icon: Icons.badge_outlined,
              ),
              AppStatusBadge(
                label: department,
                color: AppColors.primary,
                icon: Icons.apartment_outlined,
              ),
            ],
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
      return const AppEmptyState(
        title: 'لا توجد سجلات دوام بعد',
        message: 'ستظهر حالة الحضور والانصراف هنا بعد تسجيل أول حركة.',
        icon: Icons.event_available_outlined,
      );
    }

    final textTheme = Theme.of(context).textTheme;
    final statusColor = _statusSemanticColor(attendance.latestStatus);

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      backgroundColor: Colors.white,
      borderColor: AppColors.border,
      borderWidth: 1.2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: .15),
                  ),
                ),
                child: const Icon(
                  Icons.fingerprint,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'حالة الدوام',
                      style: textTheme.titleMedium?.copyWith(
                        
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      'آخر تحديث: ${attendance.latestWorkDateText}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              AppStatusBadge(
                label: _localizedStatusLabel(attendance.latestStatus),
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: _MiniMetric(
                  label: 'آخر حضور',
                  value: attendance.latestCheckInText,
                  icon: Icons.login,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MiniMetric(
                  label: 'آخر انصراف',
                  value: attendance.latestCheckOutText,
                  icon: Icons.logout,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Expanded(
                child: AppLoadingButton(
                  onPressed: _openAttendanceDetails,
                  icon: Icons.timeline,
                  text: 'عرض سجل الدوام الكامل',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _periodGrid(BuildContext context, _HomeSummary summary) {
    final items = [
      _DashboardItem(
        title: 'الرصيد المتاح للسلفة',
        value: Formatters.money(summary.balance.availableBalance),
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
        title: 'الإجازات',
        value: summary.leavesCount.toString(),
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
        isActive: summary.balance.penaltiesCount > 0 || summary.balance.penaltiesAmount > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const PenaltiesScreen(showAppBar: true),
          ),
        ),
      ),
      _DashboardItem(
        title: 'توقفات المصنع',
        value: summary.stoppagesCount.toString(),
        icon: Icons.factory_outlined,
        color: AppColors.tertiary,
        isActive: summary.stoppagesCount > 0,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const FactoryStoppagesScreen()),
        ),
      ),
    ];

    return _ResponsiveGrid(
      minItemWidth: 156,
      itemHeight: 156,
      children: [
        for (final item in items)
          AppStatCard(
            title: item.title,
            value: item.value,
            subtitle: item.subtitle,
            icon: item.icon,
            color: item.color,
            isActive: item.isActive,
            onTap: item.onTap,
          ),
      ],
    );
  }

  Widget _attendanceMetrics(
    BuildContext context,
    _AttendanceSummary attendance,
  ) {
    if (!attendance.hasRecords) {
      return const AppEmptyState(
        title: 'لا توجد مؤشرات',
        message: 'لم يتم العثور على بيانات كافية لحساب مؤشرات الدوام.',
        icon: Icons.query_stats_outlined,
      );
    }

    final items = [
      _DashboardItem(
        title: 'أيام الدوام',
        value: attendance.workDays.toString(),
        icon: Icons.calendar_today,
        color: AppColors.primary,
        isActive: attendance.workDays > 0,
        onTap: _openAttendanceDetails,
      ),
      _DashboardItem(
        title: 'تحتاج مراجعة',
        value: attendance.reviewDays.toString(),
        icon: Icons.report_outlined,
        color: AppColors.tertiary,
        isActive: attendance.reviewDays > 0,
        onTap: _openAttendanceDetails,
      ),
      _DashboardItem(
        title: 'الغياب',
        value: attendance.absentDays.toString(),
        icon: Icons.event_busy_outlined,
        color: AppColors.tertiary,
        isActive: attendance.absentDays > 0,
        onTap: _openAttendanceDetails,
      ),
    ];

    return _ResponsiveGrid(
      minItemWidth: 156,
      itemHeight: 156,
      children: [
        for (final item in items)
          AppStatCard(
            title: item.title,
            value: item.value,
            icon: item.icon,
            color: item.color,
            isActive: item.isActive,
            onTap: item.onTap,
          ),
      ],
    );
  }

  Widget _quickActions(BuildContext context, _HomeSummary summary) {
    return Column(
      children: [
        AppActionCard(
          title: 'تفاصيل رصيد السلفة',
          subtitle:
              'متاح الآن ${Formatters.money(summary.balance.availableBalance)}',
          icon: Icons.account_balance_wallet_outlined,
          color: AppColors.primary,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdvanceBalanceDetailsScreen(),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AppActionCard(
          title: 'سجل الدوام',
          subtitle: 'مراجعة الحضور والانصراف والحالات التي تحتاج متابعة',
          icon: Icons.timeline,
          color: AppColors.primary,
          onTap: _openAttendanceDetails,
        ),
      ],
    );
  }

  void _openAttendanceDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AttendanceTimelineScreen()),
    );
  }

  String get _employeeInitial {
    final name = widget.profile.fullName.trim();
    return name.isEmpty ? 'م' : name.characters.first;
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.titleSmall?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double minItemWidth;
  final double itemHeight;

  const _ResponsiveGrid({
    required this.children,
    required this.minItemWidth,
    required this.itemHeight,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final count = (width / minItemWidth).floor().clamp(1, 4).toInt();

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: count,
          mainAxisSpacing: AppSpacing.sm,
          crossAxisSpacing: AppSpacing.sm,
          childAspectRatio: (width / count) / itemHeight,
          children: children,
        );
      },
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
  final String latestPunchText;

  const _AttendanceSummary({
    required this.hasRecords,
    required this.workDays,
    required this.reviewDays,
    required this.absentDays,
    required this.latestStatus,
    required this.latestWorkDateText,
    required this.latestCheckInText,
    required this.latestCheckOutText,
    required this.latestPunchText,
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
        latestPunchText: '-',
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
      latestPunchText: _latestPunchText(visibleRecords),
    );
  }

  static List<AttendanceRecordModel> _deduplicateAttendance(
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

  static Set<String> _distinctWorkDates(
    Iterable<AttendanceRecordModel> records,
  ) {
    return records.map((item) => Formatters.date(item.workDate)).toSet();
  }

  static String _latestPunchText(List<AttendanceRecordModel> records) {
    final punches = <DateTime>[];
    for (final item in records) {
      if (item.checkIn != null) punches.add(item.checkIn!);
      if (item.checkOut != null) punches.add(item.checkOut!);
    }
    if (punches.isEmpty) return '-';
    punches.sort((a, b) => b.compareTo(a));
    final latest = punches.first;
    return '${Formatters.date(latest)} ${displayTime(latest)}';
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


