import 'package:appwrite/models.dart' as models;

import 'advance_model.dart';
import 'attendance_model.dart';
import 'leave_model.dart';
import 'overtime_record_model.dart';
import 'payroll_model.dart';
import 'penalty_model.dart';
import 'profile_model.dart';

class EmployeeFullReport {
  final ProfileModel employee;
  final List<AttendanceRecordModel> attendance;
  final List<PayrollRecordModel> payroll;
  final List<AdvanceModel> advances;
  final List<PenaltyModel> penalties;
  final List<LeaveModel> leaves;
  final List<OvertimeRecordModel> overtime;
  final List<models.Row> documents;

  const EmployeeFullReport({
    required this.employee,
    required this.attendance,
    required this.payroll,
    required this.advances,
    required this.penalties,
    required this.leaves,
    required this.overtime,
    required this.documents,
  });

  int get presentDays => attendance
      .where((record) => record.status == 'present' || record.checkIn != null)
      .length;

  int get absentDays =>
      attendance.where((record) => record.status == 'absent').length;

  int get lateCount =>
      attendance.where((record) => record.lateMinutes > 0).length;

  int get totalLateMinutes =>
      attendance.fold(0, (total, record) => total + record.lateMinutes);

  int get totalWorkedMinutes =>
      attendance.fold(0, (total, record) => total + record.workedMinutes);

  num get totalPayroll =>
      payroll.fold<num>(0, (total, record) => total + record.netSalary);

  num get totalAdvances =>
      advances.fold<num>(0, (total, record) => total + record.principalAmount);

  num get remainingAdvances =>
      advances.fold<num>(0, (total, record) => total + record.remainingAmount);

  num get totalPenalties =>
      penalties.fold<num>(0, (total, record) => total + record.amount);

  num get totalOvertime => overtime.fold<num>(
    0,
    (total, record) => total + (record.overtimeAmount ?? 0),
  );
}
