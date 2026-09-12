import 'package:flutter/material.dart';

import '../../models/attendance_model.dart';
import '../../services/employee_service.dart';
import '../../utils/formatters.dart';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحميل التنبيهات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return AppScaffold(
      title: 'تنبيهات البصمة',
      body: _isLoading
          ? const AppLoadingState(label: 'جاري تحميل التنبيهات')
          : _alerts.isEmpty
              ? const AppEmptyState(
                  title: 'لا توجد تنبيهات',
                  message: 'لا توجد تنبيهات حالية تتعلق بالبصمة.',
                  icon: Icons.notifications_none_outlined,
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _alerts.length,
                      itemBuilder: (context, index) {
                        final record = _alerts[index];
                        final resolved = record.reviewStatus == 'resolved';
                        return AppListItem(
                          title: Text(
                            Formatters.date(record.workDate),
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          trailing: resolved
                              ? AppStatusPill.success('محلولة')
                              : AppStatusPill.warning('قيد الانتظار'),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(),
                              Text(
                                'المشكلة: ${_getIssueLabel(record.attendanceIssueType)}',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: scheme.error,
                                  fontWeight: FontWeight.w700,
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
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: scheme.outlineVariant,
                                    ),
                                  ),
                                  child: Text(
                                    'ملاحظة المراجعة: ${record.reviewNote}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                )
                              else
                                Text(
                                  'يرجى مراجعة مدير الإنتاج لتصحيح البصمة.',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
    );
  }
}
