import 'package:flutter/material.dart';

import '../../services/employee_tab_navigation.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class AttendanceTimelineScreen extends StatefulWidget {
  const AttendanceTimelineScreen({super.key});

  @override
  State<AttendanceTimelineScreen> createState() =>
      _AttendanceTimelineScreenState();
}

class _AttendanceTimelineScreenState extends State<AttendanceTimelineScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      EmployeeTabNavigation.openAttendance();
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'سجل الدوام',
      body: AppLoadingState(label: 'جاري فتح سجل الدوام'),
    );
  }
}
