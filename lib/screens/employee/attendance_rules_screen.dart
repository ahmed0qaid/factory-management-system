import 'package:flutter/material.dart';

import '../../models/attendance_policy_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class AttendanceRulesScreen extends StatefulWidget {
  const AttendanceRulesScreen({super.key});

  @override
  State<AttendanceRulesScreen> createState() => _AttendanceRulesScreenState();
}

class _AttendanceRulesScreenState extends State<AttendanceRulesScreen> {
  final _employeeService = EmployeeService();
  bool _isLoading = true;
  AttendancePolicyModel? _policy;

  @override
  void initState() {
    super.initState();
    _loadPolicy();
  }

  Future<void> _loadPolicy() async {
    setState(() => _isLoading = true);
    try {
      _policy = await _employeeService.getActiveAttendancePolicy();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل القواعد: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'قواعد احتساب الدوام',
      body: _isLoading
          ? const AppLoadingState(label: 'جاري تحميل السياسة')
          : _policy == null
          ? const AppEmptyState(
              title: 'لا توجد سياسة',
              message: 'لا توجد سياسة دوام محددة حاليًا.',
              icon: Icons.rule,
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildRuleCard(
                  title: 'السماح بالتأخير',
                  icon: Icons.timer_outlined,
                  content: _buildLateRule(),
                ),
                const SizedBox(height: 12),
                _buildRuleCard(
                  title: 'الخروج المبكر',
                  icon: Icons.directions_run_outlined,
                  content: _buildEarlyLeaveRule(),
                ),
                const SizedBox(height: 12),
                _buildRuleCard(
                  title: 'الوقت الإضافي',
                  icon: Icons.more_time,
                  content: _buildOvertimeRule(),
                ),
                const SizedBox(height: 12),
                _buildRuleCard(
                  title: 'نقص البصمات',
                  icon: Icons.fingerprint,
                  content:
                      'في حال فقدان بصمة الدخول أو الخروج لن يكتمل احتساب اليوم، وسيظهر لك تنبيه لمراجعة الإدارة وتصحيح البصمة.',
                  isWarning: true,
                ),
              ],
            ),
    );
  }

  Widget _buildRuleCard({
    required String title,
    required IconData icon,
    required String content,
    bool isWarning = false,
  }) {
    final color = isWarning
        ? AppColors.danger
        : AppColors.primary;
    return AppCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: color, size: 26),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    softWrap: true,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isWarning ? AppColors.danger : AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text(content, softWrap: true, style: const TextStyle(height: 1.55)),
          ],
        ),
      ),
    );
  }

  String _buildLateRule() {
    final grace = _policy!.graceLateMinutes;
    final mode = _policy!.lateCalculationMode;
    final buffer = StringBuffer(
      'يسمح بالتأخير حتى $grace دقيقة بعد بداية الدوام.',
    );
    if (mode == 'full_time') {
      buffer.write(
        ' عند تجاوز مدة السماح يتم احتساب مدة التأخير كاملة من وقت بداية الدوام.',
      );
    } else {
      buffer.write(
        ' عند تجاوز مدة السماح يتم احتساب التأخير بعد خصم مدة السماح فقط.',
      );
    }
    return buffer.toString();
  }

  String _buildEarlyLeaveRule() {
    final grace = _policy!.graceEarlyLeaveMinutes;
    final mode = _policy!.earlyLeaveCalculationMode;
    final buffer = StringBuffer(
      'يسمح بالخروج قبل نهاية الدوام حتى $grace دقيقة.',
    );
    if (mode == 'full_time') {
      buffer.write(' عند تجاوز مدة السماح يتم احتساب الخروج المبكر كاملًا.');
    } else {
      buffer.write(' يتم احتساب الخروج المبكر بعد خصم مدة السماح فقط.');
    }
    return buffer.toString();
  }

  String _buildOvertimeRule() {
    final minMinutes = _policy!.overtimeMinimumMinutes;
    final hrApproval = _policy!.overtimeRequiresHrApproval;
    final buffer = StringBuffer(
      'يبدأ احتساب الوقت الإضافي بعد تجاوز $minMinutes دقيقة من نهاية الدوام الرسمي.',
    );
    if (hrApproval) {
      buffer.write(
        ' ملاحظة: الوقت الإضافي يتطلب اعتماد الموارد البشرية قبل إضافته في مسير الراتب.',
      );
    }
    return buffer.toString();
  }
}


