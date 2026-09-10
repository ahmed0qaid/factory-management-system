import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'formatters.dart';

String statusLabel(String status) {
  switch (status) {
    case 'present':
      return 'حاضر';
    case 'completed':
      return 'مكتمل';
    case 'absent':
      return 'غائب';
    case 'late':
      return 'متأخر';
    case 'needs_review':
      return 'تحتاج مراجعة';
    case 'pending':
      return 'بحاجة اعتماد';
    case 'approved':
      return 'معتمد';
    case 'rejected':
      return 'مرفوض';
    case 'paid':
      return 'مدفوع';
    case 'leave':
      return 'إجازة';
    case 'incomplete':
      return 'غير مكتمل';
    default:
      return 'غير محدد';
  }
}

Color statusColor(String status) {
  switch (status) {
    case 'present':
    case 'approved':
    case 'paid':
    case 'completed':
      return AppColors.success;
    case 'late':
    case 'pending':
    case 'incomplete':
    case 'needs_review':
      return AppColors.warning;
    case 'absent':
    case 'rejected':
    case 'cancelled':
      return AppColors.danger;
    default:
      return AppColors.secondary;
  }
}

String displayTime(DateTime? value) =>
    value == null ? '—' : Formatters.time(value);

String displayMinutes(int minutes) => Formatters.minutesToHours(minutes);

String displayMaybeComputedMinutes({
  required int minutes,
  required bool isComputed,
}) {
  if (!isComputed) return 'غير محسوب';
  return displayMinutes(minutes);
}
