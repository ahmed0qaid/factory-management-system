import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
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
          final horizontalPadding = compact ? 12.0 : 20.0;
          final maxContentWidth = constraints.maxWidth > 1200 ? 1200.0 : constraints.maxWidth;

          return Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: maxContentWidth,
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  horizontalPadding,
                  compact ? 12 : 20,
                  horizontalPadding,
                  24,
                ),
                children: [
                  _DashboardHeader(
                    compact: compact,
                    availableCount: availableCount,
                    totalCount: reports.length,
                  ),
                  const SizedBox(height: 16),
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
                      filled: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (visibleReports.isEmpty)
                    const _EmptySearchState()
                  else ...[
                    _ReportSection(
                      title: 'الموظفون والدوام',
                      subtitle: 'الحضور والإجازات والعمل الإضافي والتقرير الشامل',
                      icon: Icons.groups_2_outlined,
                      compact: compact,
                      reports: visibleReports
                          .where((item) => item.category == _ReportCategory.employee)
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _ReportSection(
                      title: 'التقارير المالية',
                      subtitle: 'الرواتب والسلف والجزاءات',
                      icon: Icons.account_balance_outlined,
                      compact: compact,
                      reports: visibleReports
                          .where((item) => item.category == _ReportCategory.finance)
                          .toList(),
                    ),
                    const SizedBox(height: 18),
                    _ReportSection(
                      title: 'المستندات',
                      subtitle: 'ملفات ووثائق الموظفين',
                      icon: Icons.folder_open_outlined,
                      compact: compact,
                      reports: visibleReports
                          .where((item) => item.category == _ReportCategory.documents)
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
    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'مركز التقارير',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'اختر التقرير المطلوب ثم استخدم الموظف والفترة للوصول إلى البيانات بسرعة.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.assessment_outlined, size: 20),
          const SizedBox(width: 8),
          Text('$availableCount من $totalCount تقارير متاحة'),
        ],
      ),
    );

    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 16 : 20),
        child: compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  intro,
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerRight, child: badge),
                ],
              )
            : Row(
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 20),
                  badge,
                ],
              ),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = compact
                ? 1
                : constraints.maxWidth >= 980
                    ? 3
                    : 2;
            final gap = 12.0;
            final itemWidth = (constraints.maxWidth - gap * (columns - 1)) / columns;
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
    final colors = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: report.enabled ? report.onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: report.enabled
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  report.icon,
                  color: report.enabled ? colors.primary : colors.outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            report.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        Icon(
                          report.enabled
                              ? Icons.arrow_back_ios_new_rounded
                              : Icons.lock_outline,
                          size: 16,
                          color: report.enabled ? colors.primary : colors.outline,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      report.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (!report.enabled) ...[
                      const SizedBox(height: 8),
                      Text(
                        'غير متاح لصلاحية المستخدم الحالية',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: colors.outline,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptySearchState extends StatelessWidget {
  const _EmptySearchState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Icon(Icons.search_off_outlined, size: 52),
          const SizedBox(height: 12),
          Text(
            'لا توجد تقارير مطابقة للبحث',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('جرّب كتابة اسم تقرير آخر.'),
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
