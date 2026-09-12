import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/admin_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManageLeavesScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const ManageLeavesScreen({super.key, required this.currentProfile});

  @override
  State<ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<ManageLeavesScreen> {
  final _service = AdminService();
  bool _loading = true;
  List<dynamic> _leaves = [];
  Map<String, ProfileModel> _employeesById = {};

  bool get _canManage =>
      AppRoles.canManageLeaveRequests(widget.currentProfile.role);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _service.getPendingLeaves(),
        _service.getEmployees(limit: 500),
      ]);
      if (!mounted) return;
      final employees = results[1] as List<ProfileModel>;
      setState(() {
        _leaves = results[0] as List<dynamic>;
        _employeesById = {
          for (final employee in employees) employee.id: employee,
        };
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل طلبات الإجازة: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<bool> _confirmAction({
    required String employeeName,
    required bool approve,
  }) async {
    final result = await AppConfirmDialog.show(
      context,
      title: approve ? 'اعتماد الإجازة' : 'رفض الإجازة',
      content: approve
          ? 'هل تريد اعتماد طلب الإجازة للموظف $employeeName؟'
          : 'هل تريد رفض طلب الإجازة للموظف $employeeName؟',
      confirmText: approve ? 'اعتماد' : 'رفض',
      isDestructive: !approve,
    );
    return result ?? false;
  }

  Future<void> _updateStatus(
    String id,
    String companyId,
    String employeeId,
    String status,
  ) async {
    if (!_canManage) return;
    final employeeName = _employeesById[employeeId]?.fullName ?? employeeId;
    final confirmed = await _confirmAction(
      employeeName: employeeName,
      approve: status == 'approved',
    );
    if (!confirmed) return;

    try {
      await _service.updateLeaveStatus(
        leaveId: id,
        companyId: companyId,
        employeeId: employeeId,
        status: status,
      );
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              status == 'approved'
                  ? 'تم اعتماد الإجازة بنجاح.'
                  : 'تم رفض الإجازة.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الطلب: $error')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مراجعة الإجازات',
      body: _loading
          ? const AppLoadingState(label: 'جاري تحميل الطلبات')
          : !_canManage
              ? const AppEmptyState(
                  title: 'لا توجد صلاحية للإدارة',
                  message:
                      'يمكنك الرجوع إلى التقارير للاطلاع على بيانات الإجازات.',
                  icon: Icons.lock_outline,
                )
              : _leaves.isEmpty
                  ? const AppEmptyState(
                      title: 'لا توجد طلبات',
                      message:
                          'لا توجد إجازات قيد المراجعة في الوقت الحالي.',
                      icon: Icons.beach_access_outlined,
                    )
                  : Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 900),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _leaves.length,
                          itemBuilder: (context, index) {
                            final item = _leaves[index];
                            final data = item.data;
                            final employeeId =
                                data['employee_id']?.toString() ?? '';
                            final employee = _employeesById[employeeId];
                            final employeeName =
                                employee?.fullName ?? 'موظف غير معروف';
                            final employeeMeta = <String>[
                              if (employee != null) employee.employeeNumber,
                              if (employee?.departmentName?.trim().isNotEmpty ==
                                  true)
                                employee!.departmentName!.trim(),
                            ].join(' • ');

                            return _LeaveReviewCard(
                              employeeName: employeeName,
                              employeeMeta: employeeMeta,
                              leaveType:
                                  data['leave_type']?.toString() ?? 'غير محدد',
                              startDate: DateTime.parse(data['start_date']),
                              endDate: DateTime.parse(data['end_date']),
                              reason: data['reason']?.toString(),
                              onApprove: () => _updateStatus(
                                item.$id,
                                data['company_id'],
                                employeeId,
                                'approved',
                              ),
                              onReject: () => _updateStatus(
                                item.$id,
                                data['company_id'],
                                employeeId,
                                'rejected',
                              ),
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}

class _LeaveReviewCard extends StatelessWidget {
  final String employeeName;
  final String employeeMeta;
  final String leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String? reason;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  const _LeaveReviewCard({
    required this.employeeName,
    required this.employeeMeta,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    required this.onApprove,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: scheme.primaryContainer,
                foregroundColor: scheme.onPrimaryContainer,
                child: Text(employeeName.isEmpty ? 'م' : employeeName[0]),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      employeeName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (employeeMeta.isNotEmpty)
                      Text(
                        employeeMeta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppStatusPill.warning('قيد المراجعة'),
            ],
          ),
          const Divider(height: 22),
          Text(
            'طلب إجازة: $leaveType',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.date_range_outlined,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'من ${Formatters.date(startDate)} إلى ${Formatters.date(endDate)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          if (reason?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.notes_outlined,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason!.trim(),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: onApprove,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('اعتماد'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(
                      color: scheme.error.withValues(alpha: .55),
                    ),
                  ),
                  icon: const Icon(Icons.close),
                  label: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
