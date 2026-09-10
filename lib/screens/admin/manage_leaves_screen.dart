import 'package:flutter/material.dart';
import '../../services/admin_service.dart';
import '../../utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class ManageLeavesScreen extends StatefulWidget {
  const ManageLeavesScreen({super.key});

  @override
  State<ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<ManageLeavesScreen> {
  final _service = AdminService();
  bool _loading = true;
  List<dynamic> _leaves = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await _service.getPendingLeaves();
      if (mounted) setState(() => _leaves = items);
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateStatus(
    String id,
    String companyId,
    String employeeId,
    String status,
  ) async {
    try {
      await _service.updateLeaveStatus(
        leaveId: id,
        companyId: companyId,
        employeeId: employeeId,
        status: status,
      );
      _load();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تحديث حالة الإجازة.')));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مراجعة الإجازات',
      body: _loading
          ? const AppLoadingState(label: 'جاري تحميل الطلبات')
          : _leaves.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد طلبات',
              message: 'لا توجد إجازات قيد المراجعة في الوقت الحالي.',
              icon: Icons.beach_access_outlined,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _leaves.length,
              itemBuilder: (context, index) {
                final item = _leaves[index];
                final data = item.data;
                return AppListItem(
                  title: Text('طلب إجازة ${data['leave_type']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'تاريخ البداية: ${Formatters.date(DateTime.parse(data['start_date']))}',
                      ),
                      Text(
                        'تاريخ النهاية: ${Formatters.date(DateTime.parse(data['end_date']))}',
                      ),
                      if (data['reason'] != null &&
                          data['reason'].toString().isNotEmpty)
                        Text('السبب: ${data['reason']}'),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check, color: AppColors.success),
                        onPressed: () => _updateStatus(
                          item.$id,
                          data['company_id'],
                          data['employee_id'],
                          'approved',
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.danger),
                        onPressed: () => _updateStatus(
                          item.$id,
                          data['company_id'],
                          data['employee_id'],
                          'rejected',
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
