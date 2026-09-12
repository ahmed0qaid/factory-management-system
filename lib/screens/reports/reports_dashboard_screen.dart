import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_scaffold.dart';
import 'employee_full_report_screen.dart';
import 'report_list_screen.dart';

class ReportsDashboardScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const ReportsDashboardScreen({super.key, required this.currentProfile});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_ReportEntry> _reports(BuildContext context) => [
        _ReportEntry(
          title: 'التقرير الشامل للموظف',
          description: 'ملف واحد يجمع الحضور والرواتب والسلف والجزاءات والإجازات.',
          category: _ReportCategory.employee,
          icon: Icons.badge_outlined,
          enabled: AppRoles.canViewEmployeeFullReport(widget.currentProfile.role),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EmployeeFullReportScreen(
                currentProfile: widget.currentProfile,
              ),
            ),
          ),
        ),
        _ReportEntry(
          title: 'الحضور والانصراف',
          description: 'مراجعة الحضور والغياب والتأخير وساعات العمل حسب الفترة.',
          category: _ReportCategory.employee,
          icon: Icons.calendar_month_outlined,
          enabled: AppRoles.canViewAttendanceReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.attendance),
        ),
        _ReportEntry(
          title: 'الإجازات',
          description: 'متابعة طلبات الإجازة وحالات الاعتماد ضمن الفترة المحددة.',
          category: _ReportCategory.employee,
          icon: Icons.event_available_outlined,
          enabled: AppRoles.canViewLeavesReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.leaves),
        ),
        _ReportEntry(
          title: 'العمل الإضافي',
          description: 'عرض ساعات العمل الإضافي وقيمتها وحالة اعتمادها.',
          category: _ReportCategory.employee,
          icon: Icons.timer_outlined,
          enabled: AppRoles.canViewOvertimeReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.overtime),
        ),
        _ReportEntry(
          title: 'الرواتب',
          description: 'صافي الرواتب والإضافات والخصومات حسب الموظف والفترة.',
          category: _ReportCategory.finance,
          icon: Icons.payments_outlined,
          enabled: AppRoles.canViewPayrollReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.payroll),
        ),
        _ReportEntry(
          title: 'السلف',
          description: 'إجمالي السلف والأقساط والمبالغ المتبقية للموظفين.',
          category: _ReportCategory.finance,
          icon: Icons.account_balance_wallet_outlined,
          enabled: AppRoles.canViewAdvancesReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.advances),
        ),
        _ReportEntry(
          title: 'الجزاءات',
          description: 'قيمة الجزاءات ودقائق الخصم وأسبابها وحالاتها.',
          category: _ReportCategory.finance,
          icon: Icons.gavel_outlined,
          enabled: AppRoles.canViewPenaltiesReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.penalties),
        ),
        _ReportEntry(
          title: 'مستندات الموظفين',
          description: 'مراجعة المستندات والملفات المرفقة لكل موظف.',
          category: _ReportCategory.documents,
          icon: Icons.folder_copy_outlined,
          enabled: AppRoles.canViewDocumentReports(widget.currentProfile.role),
          onTap: () => _openList(context, ReportKind.documents),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final reports = _reports(context);
    final availableCount = reports.where((report) => report.enabled).length;
    final normalizedQuery = _query.trim().toLowerCase();
    final visibleReports = reports.where((report) {
      if (normalizedQuery.isEmpty) return true;
      return report.title.toLowerCase().contains(normalizedQuery) ||
          report.description.toLowerCase().contains(normalizedQuery);
    }).toList();

    return AppScaffold(
      title: 'لوحة التقارير',
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final horizontalPadding = compact
              ? AppSpacing.sm + AppSpacing.xs
              : AppSpacing.lg;
          final maxContentWidth =
              constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxContentWidth,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? AppSpacing.sm + AppSpacing.xs : AppSpacing.lg,
                  horizontalPadding,
                  AppSpacing.xl,
                ),
                children: [
                  _DashboardHeader(
                    compact: compact,
                    availableCount: availableCount,
                    totalCount: reports.length,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث عن تقرير...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (visibleReports.isEmpty)
                    const AppEmptyState(
                      title: 'لا توجد تقارير مطابقة',
                      message: 'جرّب كتابة اسم تقرير آخر أو امسح البحث.',
                      icon: Icons.search_off_outlined,
                    )
                  else ...[
                    _ReportSection(
                      title: 'الموظفون والدوام',
                      subtitle: 'الحضور والإجازات والعمل الإضافي والتقرير الشامل',
                      icon: Icons.groups_2_outlined,
                      compact: compact,
                      reports: visibleReports
                          .where((item) =>
                              item.category == _ReportCategory.employee)
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ReportSection(
                      title: 'التقارير المالية',
                      subtitle: 'الرواتب والسلف والجزاءات',
                      icon: Icons.account_balance_outlined,
                      compact: compact,
                      reports: visibleReports
                          .where((item) => item.category == _ReportCategory.finance)
                          .toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _ReportSection(
                      title: 'المستندات',
                      subtitle: 'ملفات ووثائق الموظفين',
                      icon: Icons.folder_open_outlined,
                      compact: compact,
                      reports: visibleReports
                          .where((item) =>
                              item.category == _ReportCategory.documents)
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openList(BuildContext context, ReportKind kind) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReportListScreen(
          currentProfile: widget.currentProfile,
          kind: kind,
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  final bool compact;
  final int availableCount;
  final int totalCount;

  const _DashboardHeader({
    required this.compact,
    required this.availableCount,
    required this.totalCount,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مركز التقارير',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'اختر التقرير المطلوب ثم استخدم الموظف والفترة للوصول إلى البيانات بسرعة.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: AppRadius.control,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.assessment_outlined,
            size: 20,
            color: scheme.onPrimaryContainer,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$availableCount من $totalCount تقارير متاحة',
            style: theme.textTheme.labelLarge?.copyWith(
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );

    return AppCard(
      elevated: true,
      padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                intro,
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: badge,
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: intro),
                const SizedBox(width: AppSpacing.lg),
                badge,
              ],
            ),
    );
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool compact;
  final List<_ReportEntry> reports;

  const _ReportSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.compact,
    required this.reports,
  });

  @override
  Widget build(BuildContext context) {
    if (reports.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22, color: scheme.primary),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = compact
                ? 1
                : constraints.maxWidth >= 980
                    ? 3
                    : 2;
            const gap = AppSpacing.sm + AppSpacing.xs;
            final itemWidth =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: reports
                  .map(
                    (report) => SizedBox(
                      width: itemWidth,
                      child: _ReportCard(report: report),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _ReportCard extends StatelessWidget {
  final _ReportEntry report;

  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return AppCard(
      onTap: report.enabled ? report.onTap : null,
      padding: const EdgeInsets.all(AppSpacing.md),
      backgroundColor: report.enabled
          ? scheme.surfaceContainerLowest
          : scheme.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: report.enabled
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              borderRadius: AppRadius.control,
            ),
            child: Icon(
              report.icon,
              color: report.enabled
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppSpacing.sm + AppSpacing.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        report.title,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: report.enabled
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Icon(
                      report.enabled
                          ? (isRtl
                              ? Icons.chevron_left
                              : Icons.chevron_right)
                          : Icons.lock_outline,
                      size: 19,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  report.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (!report.enabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'غير متاح لصلاحية المستخدم الحالية',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _ReportCategory { employee, finance, documents }

class _ReportEntry {
  final String title;
  final String description;
  final _ReportCategory category;
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _ReportEntry({
    required this.title,
    required this.description,
    required this.category,
    required this.icon,
    required this.enabled,
    this.onTap,
  });
}
