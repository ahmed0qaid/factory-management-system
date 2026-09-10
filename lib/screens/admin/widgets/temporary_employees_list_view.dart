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

  const TemporaryEmployeesListView({super.key, required this.companyId, this.onEmployeeApproved});

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
          if (widget.onEmployeeApproved != null) {
            widget.onEmployeeApproved!();
          }
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'pending', label: Text('بحاجة اعتماد')),
              ButtonSegment(value: 'rejected', label: Text('مرفوض')),
            ],
            selected: {_filter},
            onSelectionChanged: (Set<String> newSelection) {
              setState(() => _filter = newSelection.first);
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
              : ListView.builder(
                  itemCount: _employees.length,
                  itemBuilder: (context, index) {
                    final emp = _employees[index];
                    final importedName = emp.employeeNameFromDevice?.trim();
                    final hasImportedName =
                        importedName != null && importedName.isNotEmpty;

                    return AppListItem(
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: .1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.person_outline,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        hasImportedName
                            ? importedName
                            : 'رقم البصمة: ${emp.biometricEmployeeId}',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${hasImportedName ? 'رقم البصمة: ${emp.biometricEmployeeId}\n' : ''}'
                          'أول ظهور: ${emp.firstSeenAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(emp.firstSeenAt!) : 'غير محدد'}\n'
                          'آخر ظهور: ${emp.lastSeenAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(emp.lastSeenAt!) : 'غير محدد'}',
                          style: const TextStyle(fontWeight: FontWeight.normal, height: 1.5),
                        ),
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '${emp.punchesCount}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const Text('حركات', style: TextStyle(fontSize: 12, fontWeight: FontWeight.normal)),
                        ],
                      ),
                      onTap: () => _showDetails(emp),
                    );
                  },
                ),
        ),
      ],
    );
  }
}


