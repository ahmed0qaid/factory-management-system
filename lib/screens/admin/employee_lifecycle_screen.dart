import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/employee_lifecycle_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class EmployeeLifecycleScreen extends StatefulWidget {
  const EmployeeLifecycleScreen({super.key});

  @override
  State<EmployeeLifecycleScreen> createState() =>
      _EmployeeLifecycleScreenState();
}

class _EmployeeLifecycleScreenState extends State<EmployeeLifecycleScreen> {
  final _adminService = AdminService();
  final _lifecycleService = EmployeeLifecycleService();
  final _searchController = TextEditingController();

  bool _loading = true;
  String? _processingId;
  String _statusFilter = 'all';
  List<ProfileModel> _employees = const [];

  @override
  void initState() {
    super.initState();
    _load();
    _searchController.addListener(_refreshFilter);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshFilter() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final employees = await _adminService.getEmployees(limit: 500);
      if (mounted) setState(() => _employees = employees);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الموظفين: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<ProfileModel> get _visibleEmployees {
    final query = _searchController.text.trim().toLowerCase();
    return _employees.where((employee) {
      final matchesStatus = _statusFilter == 'all' ||
          employee.employmentStatus == _statusFilter;
      final matchesQuery = query.isEmpty ||
          employee.fullName.toLowerCase().contains(query) ||
          employee.employeeNumber.toLowerCase().contains(query) ||
          (employee.departmentName ?? '').toLowerCase().contains(query);
      return matchesStatus && matchesQuery;
    }).toList();
  }

  Future<void> _reactivate(ProfileModel employee) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إعادة تفعيل الموظف'),
        content: Text(
          'سيُعاد تفعيل ${employee.fullName} ويمكنه تسجيل الدخول من جديد. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('إعادة التفعيل'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await _applyStatus(
      employee: employee,
      status: EmploymentStatus.active,
      reason: '',
    );
  }

  Future<void> _suspend(ProfileModel employee) async {
    final reason = await _askReason(
      title: 'إيقاف الموظف مؤقتًا',
      hint: 'اكتب سبب الإيقاف المؤقت',
      confirmText: 'إيقاف مؤقت',
    );
    if (reason == null) return;

    await _applyStatus(
      employee: employee,
      status: EmploymentStatus.suspended,
      reason: reason,
    );
  }

  Future<void> _terminate(ProfileModel employee) async {
    final result = await _askTermination(employee);
    if (result == null) return;

    await _applyStatus(
      employee: employee,
      status: EmploymentStatus.terminated,
      reason: result.$1,
      terminationDate: result.$2,
    );
  }

  Future<String?> _askReason({
    required String title,
    required String hint,
    required String confirmText,
  }) async {
    final controller = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'السبب',
              hintText: hint,
              prefixIcon: const Icon(Icons.notes_outlined),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final reason = controller.text.trim();
                if (reason.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(content: Text('سبب تغيير الحالة مطلوب.')),
                  );
                  return;
                }
                Navigator.pop(dialogContext, reason);
              },
              child: Text(confirmText),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<(String, DateTime)?> _askTermination(ProfileModel employee) async {
    final controller = TextEditingController();
    var date = DateTime.now();
    try {
      return await showDialog<(String, DateTime)>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إنهاء خدمة الموظف'),
            content: SizedBox(
              width: 460,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'سيتم إنهاء خدمة ${employee.fullName} مع الاحتفاظ بجميع سجلاته السابقة. لا يمكن إعادة تفعيله من هذه المرحلة بعد الإنهاء.',
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: controller,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'سبب إنهاء الخدمة',
                      prefixIcon: Icon(Icons.notes_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date,
                        firstDate: employee.hireDate,
                        lastDate: DateTime.now(),
                        helpText: 'تاريخ انتهاء الخدمة',
                      );
                      if (picked != null) {
                        setDialogState(() => date = picked);
                      }
                    },
                    icon: const Icon(Icons.event_busy_outlined),
                    label: Text('تاريخ انتهاء الخدمة: ${Formatters.date(date)}'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                onPressed: () {
                  final reason = controller.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('سبب إنهاء الخدمة مطلوب.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, (reason, date));
                },
                child: const Text('إنهاء الخدمة'),
              ),
            ],
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  Future<void> _applyStatus({
    required ProfileModel employee,
    required String status,
    required String reason,
    DateTime? terminationDate,
  }) async {
    setState(() => _processingId = employee.id);
    try {
      await _lifecycleService.changeEmploymentStatus(
        employee: employee,
        employmentStatus: status,
        reason: reason,
        terminationDate: terminationDate,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم تحديث حالة ${employee.fullName} إلى ${EmploymentStatus.label(status)}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processingId = null);
    }
  }

  Widget _status(ProfileModel employee) {
    switch (employee.employmentStatus) {
      case EmploymentStatus.active:
        return AppStatusPill.success('نشط');
      case EmploymentStatus.suspended:
        return AppStatusPill.warning('موقوف مؤقتًا');
      case EmploymentStatus.terminated:
        return AppStatusPill.danger('منتهي الخدمة');
      default:
        return AppStatusPill.neutral(employee.employmentStatusLabel);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final visibleEmployees = _visibleEmployees;

    return AppScaffold(
      title: 'دورة حياة الموظفين',
      body: _loading && _employees.isEmpty
          ? const AppLoadingState(label: 'جاري تحميل حالات الموظفين')
          : RefreshIndicator(
              onRefresh: _load,
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1000),
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'إدارة الحالة الوظيفية',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'الإيقاف المؤقت يمنع الدخول مع الاحتفاظ بالموظف، وإنهاء الخدمة يحفظ كل السجلات التاريخية ولا يحذف الحساب أو الحركات المرتبطة به.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _searchController,
                              decoration: const InputDecoration(
                                labelText: 'بحث بالاسم أو الرقم أو القسم',
                                prefixIcon: Icon(Icons.search),
                              ),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: _statusFilter,
                              decoration: const InputDecoration(
                                labelText: 'الحالة الوظيفية',
                                prefixIcon: Icon(Icons.manage_accounts_outlined),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('كل الحالات'),
                                ),
                                DropdownMenuItem(
                                  value: EmploymentStatus.active,
                                  child: Text('نشط'),
                                ),
                                DropdownMenuItem(
                                  value: EmploymentStatus.suspended,
                                  child: Text('موقوف مؤقتًا'),
                                ),
                                DropdownMenuItem(
                                  value: EmploymentStatus.terminated,
                                  child: Text('منتهي الخدمة'),
                                ),
                              ],
                              onChanged: (value) => setState(
                                () => _statusFilter = value ?? 'all',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (visibleEmployees.isEmpty)
                        const AppEmptyState(
                          title: 'لا توجد نتائج',
                          message: 'لا يوجد موظفون مطابقون للفلاتر الحالية.',
                          icon: Icons.person_search_outlined,
                        )
                      else
                        ...visibleEmployees.map(
                          (employee) => _LifecycleCard(
                            employee: employee,
                            status: _status(employee),
                            processing: _processingId == employee.id,
                            onSuspend: employee.isHrAdmin ||
                                    employee.isTerminated ||
                                    employee.isSuspended
                                ? null
                                : () => _suspend(employee),
                            onReactivate: employee.isHrAdmin ||
                                    !employee.isSuspended
                                ? null
                                : () => _reactivate(employee),
                            onTerminate: employee.isHrAdmin ||
                                    employee.isTerminated
                                ? null
                                : () => _terminate(employee),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _LifecycleCard extends StatelessWidget {
  final ProfileModel employee;
  final Widget status;
  final bool processing;
  final VoidCallback? onSuspend;
  final VoidCallback? onReactivate;
  final VoidCallback? onTerminate;

  const _LifecycleCard({
    required this.employee,
    required this.status,
    required this.processing,
    required this.onSuspend,
    required this.onReactivate,
    required this.onTerminate,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(
                  employee.fullName.isEmpty ? 'م' : employee.fullName[0],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employee.fullName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${employee.employeeNumber} • ${employee.departmentName?.isNotEmpty == true ? employee.departmentName : 'قسم غير محدد'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              status,
            ],
          ),
          const Divider(height: 24),
          _row('تاريخ التعيين', Formatters.date(employee.hireDate)),
          _row(
            'المسمى الوظيفي',
            employee.jobTitleName?.isNotEmpty == true
                ? employee.jobTitleName!
                : 'غير محدد',
          ),
          if (employee.statusReason?.trim().isNotEmpty == true)
            _row('سبب آخر تغيير', employee.statusReason!.trim()),
          if (employee.terminationDate != null)
            _row(
              'تاريخ انتهاء الخدمة',
              Formatters.date(employee.terminationDate),
            ),
          const SizedBox(height: 12),
          if (processing)
            const Center(child: CircularProgressIndicator())
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                if (onReactivate != null)
                  FilledButton.tonalIcon(
                    onPressed: onReactivate,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('إعادة التفعيل'),
                  ),
                if (onSuspend != null)
                  OutlinedButton.icon(
                    onPressed: onSuspend,
                    icon: const Icon(Icons.pause_circle_outline),
                    label: const Text('إيقاف مؤقت'),
                  ),
                if (onTerminate != null)
                  OutlinedButton.icon(
                    onPressed: onTerminate,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: scheme.error,
                      side: BorderSide(color: scheme.error.withValues(alpha: .55)),
                    ),
                    icon: const Icon(Icons.person_off_outlined),
                    label: const Text('إنهاء الخدمة'),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 132, child: Text(label)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
