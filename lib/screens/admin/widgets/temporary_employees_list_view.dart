import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../models/temporary_employee_model.dart';
import '../../../services/admin_biometrics_service.dart';
import '../../../widgets/common/app_empty_state.dart';
import '../../../widgets/common/app_list_item.dart';
import '../../../widgets/common/app_loading_state.dart';

import 'temporary_employee_details_dialog.dart';

class TemporaryEmployeesListView extends StatefulWidget {
  final String companyId;
  final VoidCallback? onEmployeeApproved;

  const TemporaryEmployeesListView({
    super.key,
    required this.companyId,
    this.onEmployeeApproved,
  });

  @override
  State<TemporaryEmployeesListView> createState() =>
      _TemporaryEmployeesListViewState();
}

class _TemporaryEmployeesListViewState
    extends State<TemporaryEmployeesListView> {
  final _biometricsService = AdminBiometricsService();
  List<TemporaryEmployeeModel> _employees = [];
  bool _isLoading = true;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final emps = await _biometricsService.getTemporaryEmployees(
        widget.companyId,
        status: _filter,
      );
      if (mounted) setState(() => _employees = emps);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDetails(TemporaryEmployeeModel emp) {
    showDialog(
      context: context,
      builder: (_) => TemporaryEmployeeDetailsDialog(
        employee: emp,
        onChanged: () {
          _loadEmployees();
          widget.onEmployeeApproved?.call();
        },
      ),
    );
  }

  String _getEmptyMessage() {
    return _filter == 'pending'
        ? 'لا يوجد موظفون مؤقتون بحاجة اعتماد.'
        : 'لا يوجد موظفون مؤقتون مرفوضون.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'pending',
                icon: Icon(Icons.pending_actions_outlined),
                label: Text('بحاجة اعتماد'),
              ),
              ButtonSegment(
                value: 'rejected',
                icon: Icon(Icons.person_off_outlined),
                label: Text('مرفوض'),
              ),
            ],
            selected: {_filter},
            onSelectionChanged: (selection) {
              setState(() => _filter = selection.first);
              _loadEmployees();
            },
          ),
        ),
        Expanded(
          child: _isLoading
              ? const AppLoadingState(label: 'جاري تحميل الموظفين')
              : _employees.isEmpty
              ? AppEmptyState(
                  title: 'لا يوجد موظفون',
                  message: _getEmptyMessage(),
                  icon: Icons.person_off_outlined,
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                      itemCount: _employees.length,
                      itemBuilder: (context, index) {
                        final emp = _employees[index];
                        final importedName = emp.employeeNameFromDevice?.trim();
                        final hasImportedName =
                            importedName != null && importedName.isNotEmpty;

                        return AppListItem(
                          leading: CircleAvatar(
                            backgroundColor: scheme.primaryContainer,
                            foregroundColor: scheme.onPrimaryContainer,
                            child: const Icon(Icons.person_outline),
                          ),
                          title: Text(
                            hasImportedName
                                ? importedName
                                : 'رقم البصمة: ${emp.biometricEmployeeId}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasImportedName)
                                  Text(
                                    'رقم البصمة: ${emp.biometricEmployeeId}',
                                  ),
                                Text(
                                  'أول ظهور: ${emp.firstSeenAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(emp.firstSeenAt!) : 'غير محدد'}',
                                ),
                                Text(
                                  'آخر ظهور: ${emp.lastSeenAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(emp.lastSeenAt!) : 'غير محدد'}',
                                ),
                              ],
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${emp.punchesCount}',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                'حركات',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _showDetails(emp),
                        );
                      },
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}
