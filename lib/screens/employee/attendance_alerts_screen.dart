import 'package:flutter/material.dart';
import '../../models/attendance_model.dart';
import '../../services/employee_service.dart';
import '../../utils/formatters.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class AttendanceAlertsScreen extends StatefulWidget {
  const AttendanceAlertsScreen({super.key});

  @override
  State<AttendanceAlertsScreen> createState() => _AttendanceAlertsScreenState();
}

class _AttendanceAlertsScreenState extends State<AttendanceAlertsScreen> {
  final _employeeService = EmployeeService();
  bool _isLoading = true;
  List<AttendanceRecordModel> _alerts = [];

  @override
  void initState() {
    super.initState();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    setState(() => _isLoading = true);
    try {
      _alerts = await _employeeService.getAttendanceAlerts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل التنبيهات: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getIssueLabel(String? issueType) {
    switch (issueType) {
      case 'missing_check_in':
        return 'نقص بصمة الدخول';
      case 'missing_check_out':
        return 'نقص بصمة الخروج';
      case 'missing_both':
        return 'غياب بصمة الدخول والخروج';
      default:
        return 'مشكلة في البصمة';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'تنبيهات البصمة',
      body: _isLoading
          ? const AppLoadingState(label: 'جاري تحميل التنبيهات')
          : _alerts.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد تنبيهات',
              message: 'لا توجد تنبيهات حالية تتعلق بالبصمة.',
              icon: Icons.notifications_none,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _alerts.length,
              itemBuilder: (context, index) {
                final record = _alerts[index];
                return AppListItem(
                  title: Text(
                    Formatters.date(record.workDate),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  trailing: AppStatusPill(
                    color: record.reviewStatus == 'resolved' ? AppColors.success : AppColors.warning,
                    label: record.reviewStatus == 'resolved' ? 'محلولة' : 'قيد الانتظار',
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Divider(),
                      Text(
                        'المشكلة: ${_getIssueLabel(record.attendanceIssueType)}',
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'بصمة الدخول: ${record.checkIn != null ? Formatters.time(record.checkIn!) : "مفقودة"}',
                      ),
                      Text(
                        'بصمة الخروج: ${record.checkOut != null ? Formatters.time(record.checkOut!) : "مفقودة"}',
                      ),
                      const SizedBox(height: 8),
                      if (record.reviewNote != null &&
                          record.reviewNote!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'ملاحظة المراجعة: ${record.reviewNote}',
                          ),
                        )
                      else
                        const Text(
                          'يرجى مراجعة مدير الإنتاج لتصحيح البصمة.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
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


