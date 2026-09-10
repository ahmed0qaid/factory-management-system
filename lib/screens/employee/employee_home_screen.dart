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
import '../../widgets/common/app_stat_card.dart';
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
    final needsAttention = attendance.reviewDays > 0 ||
        attendance.absentDays > 0 ||
        summary.balance.penaltiesCount > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'حالة الدوام'),
        const SizedBox(height: AppSpacing.sm),
        _attendanceOverviewCard(context, attendance),
        if (needsAttention) ...[
          const SizedBox(height: AppSpacing.xl),
          const AppSectionHeader(
            title: 'بحاجة إلى انتباه',
            icon: Icons.notification_important_outlined,
          ),
          const SizedBox(height: AppSpacing.sm),
          _attentionCard(context, summary, attendance),
        ],
        const SizedBox(height: AppSpacing.xl),
        const AppSectionHeader(
          title: 'ملخص الفترة الحالية',
          icon: Icons.dashboard_outlined,
        ),
        const SizedBox(height: AppSpacing.sm),
        _periodGrid(context, summary),
      ],
    );
  }

  Widget _employeeHeader(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final jobTitle = widget.profile.jobTitleName?.trim().isNotEmpty == true
        ? widget.profile.jobTitleName!.trim()
        : 'بدون مسمى وظيفي محدد';
    final department = widget.profile.departmentName?.trim().isNotEmpty == true
        ? widget.profile.departmentName!.trim()
        : 'بدون قسم محدد';

    return AppCard(
      elevated: true,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'مرحبًا، ${widget.profile.fullName}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    AppStatusBadge(
                      label: widget.profile.employeeNumber,
                      color: scheme.primary,
                      icon: Icons.badge_outlined,
                    ),
                    AppStatusBadge(
                      label: department,
                      color: scheme.secondary,
                      icon: Icons.apartment_outlined,
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Icon(
                  Icons.fingerprint,
                  color: scheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'آخر حالة مسجلة',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      attendance.latestWorkDateText,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
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
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 430;
              final items = [
                _MiniMetric(
                  label: 'آخر حضور',
                  value: attendance.latestCheckInText,
                  icon: Icons.login,
                ),
                _MiniMetric(
                  label: 'آخر انصراف',
                  value: attendance.latestCheckOutText,
                  icon: Icons.logout,
                ),
              ];
              if (compact) {
                return Column(
                  children: [
                    items[0],
                    const SizedBox(height: AppSpacing.sm),
                    items[1],
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: items[0]),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: items[1]),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              Chip(label: Text('أيام الدوام: ${attendance.workDays}')),
              if (attendance.absentDays > 0)
                Chip(label: Text('غياب: ${attendance.absentDays}')),
              if (attendance.reviewDays > 0)
                Chip(label: Text('تحتاج مراجعة: ${attendance.reviewDays}')),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: _openAttendanceDetails,
              icon: const Icon(Icons.timeline_outlined),
              label: const Text('فتح سجل الدوام'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _attentionCard(
    BuildContext context,
    _HomeSummary summary,
    _AttendanceSummary attendance,
  ) {
    final rows = <Widget>[];

    if (attendance.reviewDays > 0) {
      rows.add(
        _AttentionRow(
          icon: Icons.fact_check_outlined,
          title: '${attendance.reviewDays} يوم يحتاج مراجعة',
          subtitle: 'راجع تفاصيل الحضور والانصراف والحالة المسجلة.',
          onTap: _openAttendanceDetails,
        ),
      );
    }
    if (attendance.absentDays > 0) {
      rows.add(
        _AttentionRow(
          icon: Icons.event_busy_outlined,
          title: '${attendance.absentDays} يوم غياب في الفترة الحالية',
          subtitle: 'افتح سجل الدوام لمراجعة الأيام والتفاصيل.',
          onTap: _openAttendanceDetails,
        ),
      );
    }
    if (summary.balance.penaltiesCount > 0) {
      rows.add(
        _AttentionRow(
          icon: Icons.gavel_outlined,
          title: '${summary.balance.penaltiesCount} جزاء مسجل',
          subtitle:
              'إجمالي القيمة ${Formatters.money(summary.balance.penaltiesAmount)}',
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const PenaltiesScreen(showAppBar: true),
            ),
          ),
        ),
      );
    }

    return AppCard(
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const Divider(height: 1),
            rows[index],
          ],
        ],
      ),
    );
  }

  Widget _periodGrid(BuildContext context, _HomeSummary summary) {
    final items = [
      _DashboardItem(
        title: 'رصيد السلفة المتاح',
        value: Formatters.money(summary.balance.availableBalance),
        subtitle: 'تفاصيل الاستحقاق والسلف',
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
        title: 'طلبات الإجازة',
        value: summary.leavesCount.toString(),
        subtitle: 'عرض الطلبات أو إنشاء طلب',
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
    ];

    return _ResponsiveGrid(
      minItemWidth: 165,
      itemHeight: 164,
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

  void _openAttendanceDetails() {
    EmployeeTabNavigation.openAttendance();
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

class _AttentionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttentionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(child: Icon(icon)),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_left),
      onTap: onTap,
    );
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
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: colors.primary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
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
