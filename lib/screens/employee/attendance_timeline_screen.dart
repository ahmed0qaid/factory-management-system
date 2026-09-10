import 'package:flutter/material.dart';

import '../../widgets/common/app_scaffold.dart';
import 'attendance_screen.dart';

class AttendanceTimelineScreen extends StatelessWidget {
  const AttendanceTimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const AppScaffold(
      title: 'سجل الحضور والانصراف',
      body: AttendanceScreen(),
    );
  }
}
