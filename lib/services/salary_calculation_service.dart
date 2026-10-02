import '../models/attendance_model.dart';
import '../models/penalty_model.dart';
import '../models/profile_model.dart';

enum FridaySalaryMode { includeFridays, excludeFridays }

extension FridaySalaryModeLabel on FridaySalaryMode {
  String get label {
    return switch (this) {
      FridaySalaryMode.includeFridays => 'احتساب الجمعة ضمن أيام الشهر',
      FridaySalaryMode.excludeFridays => 'استبعاد الجمعة من أيام العمل',
    };
  }
}

class MonthlySalaryReport {
  final ProfileModel employee;
  final int year;
  final int month;
  final num baseSalary;
  final num monthlyBonus;
  final num grossSalary;
  final FridaySalaryMode fridayMode;
  final int daysInMonth;
  final int fridaysCount;
  final int salaryDays;
  final num dailyWage;
  final num dailyWorkHours;
  final num hourlyWage;
  final int presentDays;
  final int absentDays;
  final int paidLeaveDays;
  final int unpaidLeaveDays;
  final int paidStoppageDays;
  final int unpaidStoppageDays;
  final int unresolvedAttendanceCount;
  final num attendanceSalary;
  final num absenceDeduction;
  final num unpaidLeaveDeduction;
  final num unpaidStoppageDeduction;
  final num penaltiesDeduction;
  final num advanceDeduction;
  final num netSalary;

  MonthlySalaryReport({
    required this.employee,
    required this.year,
    required this.month,
    required this.baseSalary,
    required this.monthlyBonus,
    required this.grossSalary,
    required this.fridayMode,
    required this.daysInMonth,
    required this.fridaysCount,
    required this.salaryDays,
    required this.dailyWage,
    required this.dailyWorkHours,
    required this.hourlyWage,
    required this.presentDays,
    required this.absentDays,
    required this.paidLeaveDays,
    required this.unpaidLeaveDays,
    required this.paidStoppageDays,
    required this.unpaidStoppageDays,
    required this.unresolvedAttendanceCount,
    required this.attendanceSalary,
    required this.absenceDeduction,
    required this.unpaidLeaveDeduction,
    required this.unpaidStoppageDeduction,
    required this.penaltiesDeduction,
    required this.advanceDeduction,
    required this.netSalary,
  });

  String get monthKey => '$year-${month.toString().padLeft(2, '0')}';
  bool get isAttendanceFinalized => unresolvedAttendanceCount == 0;
  int get paidProtectedDays => paidLeaveDays + paidStoppageDays;
  int get unpaidProtectedDays => unpaidLeaveDays + unpaidStoppageDays;
}

class SalaryCalculationService {
  static num calculateGrossSalary(num baseSalary, num? monthlyBonus) {
    return baseSalary + (monthlyBonus ?? 0);
  }

  static int getDaysInMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  static int countFridays(int year, int month) {
    final days = getDaysInMonth(year, month);
    var count = 0;
    for (var day = 1; day <= days; day++) {
      if (DateTime(year, month, day).weekday == DateTime.friday) count++;
    }
    return count;
  }

  static int calculateSalaryDays(
    int year,
    int month, {
    required bool includeFridays,
  }) {
    final days = getDaysInMonth(year, month);
    return includeFridays ? days : days - countFridays(year, month);
  }

  static num calculateDailyWage(num grossSalary, int salaryDays) {
    if (salaryDays <= 0) return 0;
    return grossSalary / salaryDays;
  }

  static num calculateHourlyWage(num dailyWage, num? dailyWorkHours) {
    final hours = (dailyWorkHours == null || dailyWorkHours <= 0)
        ? 8
        : dailyWorkHours;
    return dailyWage / hours;
  }

  static MonthlySalaryReport calculateMonthlySalaryReport({
    required ProfileModel employee,
    required List<AttendanceRecordModel> attendanceRecords,
    required List<PenaltyModel> penalties,
    required num advancesTotal,
    required int year,
    required int month,
    required FridaySalaryMode fridayMode,
  }) {
    final unresolvedAttendanceCount = attendanceRecords
        .where((record) => record.hasUnresolvedReview)
        .length;
    if (unresolvedAttendanceCount > 0) {
      final monthKey = '$year-${month.toString().padLeft(2, '0')}';
      throw StateError(
        'لا يمكن احتساب أو اعتماد راتب ${employee.fullName} عن $monthKey قبل حسم $unresolvedAttendanceCount حالة حضور معلقة.',
      );
    }

    final grossSalary = calculateGrossSalary(
      employee.baseSalary,
      employee.monthlyBonus,
    );
    final includeFridays = fridayMode == FridaySalaryMode.includeFridays;
    final daysInMonth = getDaysInMonth(year, month);
    final fridaysCount = countFridays(year, month);
    final salaryDays = calculateSalaryDays(
      year,
      month,
      includeFridays: includeFridays,
    );
    final dailyWage = calculateDailyWage(grossSalary, salaryDays);
    final dailyWorkHours = employee.dailyWorkHours;
    final hourlyWage = calculateHourlyWage(dailyWage, dailyWorkHours);

    final finalizedAttendance = attendanceRecords
        .where((record) => !record.hasUnresolvedReview)
        .toList();

    final presentDays = finalizedAttendance.where(_isPresent).length;
    final paidLeaveDays = finalizedAttendance
        .where((record) => _isExceptionDay(record, 'paid_leave'))
        .length;
    final unpaidLeaveDays = finalizedAttendance
        .where((record) => _isExceptionDay(record, 'unpaid_leave'))
        .length;
    final paidStoppageDays = finalizedAttendance
        .where((record) => _isExceptionDay(record, 'factory_stoppage_paid'))
        .length;
    final unpaidStoppageDays = finalizedAttendance
        .where((record) => _isExceptionDay(record, 'factory_stoppage_unpaid'))
        .length;
    final absentDays = finalizedAttendance.where(_isChargeableAbsence).length;

    final attendanceSalary =
        (presentDays + paidLeaveDays + paidStoppageDays) * dailyWage;
    final absenceDeduction = absentDays * dailyWage;
    final unpaidLeaveDeduction = unpaidLeaveDays * dailyWage;
    final unpaidStoppageDeduction = unpaidStoppageDays * dailyWage;
    final penaltiesDeduction = penalties.fold<num>(
      0,
      (total, penalty) => total + penalty.amount,
    );
    final advanceDeduction = advancesTotal;
    final netSalary =
        grossSalary -
        absenceDeduction -
        unpaidLeaveDeduction -
        unpaidStoppageDeduction -
        penaltiesDeduction -
        advanceDeduction;

    return MonthlySalaryReport(
      employee: employee,
      year: year,
      month: month,
      baseSalary: employee.baseSalary,
      monthlyBonus: employee.monthlyBonus,
      grossSalary: grossSalary,
      fridayMode: fridayMode,
      daysInMonth: daysInMonth,
      fridaysCount: fridaysCount,
      salaryDays: salaryDays,
      dailyWage: dailyWage,
      dailyWorkHours: dailyWorkHours,
      hourlyWage: hourlyWage,
      presentDays: presentDays,
      absentDays: absentDays,
      paidLeaveDays: paidLeaveDays,
      unpaidLeaveDays: unpaidLeaveDays,
      paidStoppageDays: paidStoppageDays,
      unpaidStoppageDays: unpaidStoppageDays,
      unresolvedAttendanceCount: 0,
      attendanceSalary: attendanceSalary,
      absenceDeduction: absenceDeduction,
      unpaidLeaveDeduction: unpaidLeaveDeduction,
      unpaidStoppageDeduction: unpaidStoppageDeduction,
      penaltiesDeduction: penaltiesDeduction,
      advanceDeduction: advanceDeduction,
      netSalary: netSalary,
    );
  }

  static bool _isPresent(AttendanceRecordModel record) {
    if (record.hasUnresolvedReview) return false;
    return record.status == 'present' || record.status == 'late';
  }

  static bool _isExceptionDay(AttendanceRecordModel record, String type) {
    if (record.hasUnresolvedReview || record.hasActualPresence) return false;
    return record.calendarExceptionType == type;
  }

  static bool _isChargeableAbsence(AttendanceRecordModel record) {
    if (record.hasUnresolvedReview || record.hasActualPresence) return false;
    if (record.hasCalendarException) return false;
    return record.status == 'absent';
  }
}
