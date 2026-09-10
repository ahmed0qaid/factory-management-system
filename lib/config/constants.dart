class AppConstants {
  static const technicalEmailDomain = 'hr.local';

  static String databaseId = 'hr';
  static String createEmployeeFunctionId = 'create_employee';
  static String updateEmployeeCredentialsFunctionId = 'update_employee_credentials';

  // Appwrite TablesDB table IDs.
  // These IDs can be the same IDs that were previously used as collection IDs.
  static const profilesTable = 'profiles';
  static const attendanceTable = 'attendance_records';
  static const penaltiesTable = 'penalties';
  static const payrollTable = 'payroll_records';
  static const advancesTable = 'advances';
  static const announcementsTable = 'announcements';
  static const notificationsTable = 'notifications';
  static const String leaveRequestsTable = 'leave_requests';
  static const String factoryStoppagesTable = 'factory_stoppages';
  static const String attendancePoliciesTable = 'attendance_policies';
  static const String employeeDocumentsTable = 'employee_documents';
  static const String jobTitlesTable = 'job_titles';

  // Biometrics and Shifts
  static const String biometricImportBatchesTable = 'biometric_import_batches';
  static const String biometricLogsTable = 'biometric_logs';
  static const String temporaryBiometricEmployeesTable =
      'temporary_biometric_employees';
  static const String shiftsTable = 'shifts';
  static const String employeeShiftAssignmentsTable =
      'employee_shift_assignments';
  static const String employeeWorkSchedulesTable = 'employee_work_schedules';
  static const String overtimeRecordsTable = 'overtime_records';

  // Backward-compatible aliases in case older screens still reference the old names.
  static const profilesCollection = profilesTable;
  static const attendanceCollection = attendanceTable;
  static const penaltiesCollection = penaltiesTable;
  static const payrollCollection = payrollTable;
  static const advancesCollection = advancesTable;
  static const announcementsCollection = announcementsTable;
  static const notificationsCollection = notificationsTable;
  static const leaveRequestsCollection = leaveRequestsTable;

  static const employeeFilesBucket = 'employee_files';
}
