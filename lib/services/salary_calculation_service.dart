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
  final num attendanceSalary;
  final num absenceDeduction;
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
    required this.attendanceSalary,
    required this.absenceDeduction,
    required this.penaltiesDeduction,
    required this.advanceDeduction,
    required this.netSalary,
  });

  String get monthKey => '$year-${month.toString().padLeft(2, '0')}';
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
      if (DateTime(year, month, day).weekday == DateTime.friday) {
        count++;
      }
    }
    return count;
  }

  static int calculateSalaryDays(
    int year,
    int month, {
    required bool includeFridays,
  }) {
    final days = getDaysInMonth(year, month);
    if (includeFridays) return days;
    return days - countFridays(year, month);
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

    final presentDays = attendanceRecords.where(_isPresent).length;
    final absentDays = attendanceRecords.where(_isAbsent).length;
    final attendanceSalary = presentDays * dailyWage;
    final absenceDeduction = absentDays * dailyWage;
    final penaltiesDeduction = penalties.fold<num>(
      0,
      (total, penalty) => total + penalty.amount,
    );
    final advanceDeduction = advancesTotal;
    final netSalary =
        grossSalary - absenceDeduction - penaltiesDeduction - advanceDeduction;

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
      attendanceSalary: attendanceSalary,
      absenceDeduction: absenceDeduction,
      penaltiesDeduction: penaltiesDeduction,
      advanceDeduction: advanceDeduction,
      netSalary: netSalary,
    );
  }

  static bool _isPresent(AttendanceRecordModel record) {
    return record.status == 'present' ||
        record.status == 'late' ||
        record.checkIn != null;
  }

  static bool _isAbsent(AttendanceRecordModel record) {
    return record.status == 'absent';
  }
}
