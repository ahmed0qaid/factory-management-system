import 'package:flutter/material.dart';

import '../utils/attendance_display.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);

    return Chip(
      label: Text(statusLabel(status)),
      backgroundColor: color.withValues(alpha: .12),
      labelStyle: TextStyle(color: color, ),
      side: BorderSide(color: color.withValues(alpha: .2)),
    );
  }
}


