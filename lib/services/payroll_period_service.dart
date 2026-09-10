class PayrollPeriodService {
  /// Returns the start and end dates of the payroll period for a given date.
  /// The payroll period starts on the 25th of the previous month (or current month)
  /// and ends on the 24th of the next month.
  static ({DateTime periodStart, DateTime periodEnd}) getCurrentPayrollPeriod(
    DateTime date,
  ) {
    DateTime periodStart;
    DateTime periodEnd;

    if (date.day >= 25) {
      // Start is the 25th of the current month
      periodStart = DateTime(date.year, date.month, 25);
      // End is the 24th of the next month
      periodEnd = DateTime(date.year, date.month + 1, 24, 23, 59, 59);
    } else {
      // Start is the 25th of the previous month
      periodStart = DateTime(date.year, date.month - 1, 25);
      // End is the 24th of the current month
      periodEnd = DateTime(date.year, date.month, 24, 23, 59, 59);
    }

    return (periodStart: periodStart, periodEnd: periodEnd);
  }

  /// Exclude Fridays (DateTime.friday == 5)
  static bool isWorkingDay(DateTime date) {
    return date.weekday != DateTime.friday;
  }

  /// Counts working days between two dates inclusive, excluding Fridays
  static int countWorkingDays(DateTime start, DateTime end) {
    int count = 0;
    DateTime current = DateTime(start.year, start.month, start.day);
    final endDate = DateTime(end.year, end.month, end.day);

    while (current.isBefore(endDate) || current.isAtSameMomentAs(endDate)) {
      if (isWorkingDay(current)) {
        count++;
      }
      current = current.add(const Duration(days: 1));
    }
    return count;
  }
}
