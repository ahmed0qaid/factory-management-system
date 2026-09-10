enum ShiftSelectionMode { auto, manualOverride }

enum DuplicateHandlingMode { auto, manual }

enum PunchRole { checkIn, checkOut, duplicate, ignored, needsReview }

class BiometricPunch {
  final String id;
  final String biometricId;
  final DateTime time;
  final bool isValid;
  PunchRole role;

  BiometricPunch({
    required this.id,
    required this.biometricId,
    required this.time,
    required this.isValid,
    this.role = PunchRole.ignored,
  });
}

class ShiftDefinition {
  final String id;
  final String name;
  final int startHour;
  final int endHour;
  final int windowStartHour;
  final int windowEndHour;

  ShiftDefinition({
    required this.id,
    required this.name,
    required this.startHour,
    required this.endHour,
    required this.windowStartHour,
    required this.windowEndHour,
  });

  bool get crossesMidnight => endHour <= startHour;
  bool get windowCrossesMidnight => windowEndHour <= windowStartHour;
}

class ProcessedGroup {
  final String biometricId;
  final DateTime physicalDate;
  final List<BiometricPunch> punches;
  final String? employeeName;
  final int? sourceRowNumber;

  ShiftDefinition? suggestedShift;
  DateTime? shiftStart;
  DateTime? shiftEnd;

  DateTime? actualCheckIn;
  DateTime? actualCheckOut;

  late DateTime workDate;

  int expectedOvertimeMinutes = 0;
  int ignoredCount = 0;

  bool needsReview = false;
  bool isAbsent = false;
  String reviewReason = '';

  ProcessedGroup({
    required this.biometricId,
    required this.physicalDate,
    required this.punches,
    this.employeeName,
    this.sourceRowNumber,
  });
}

class PreprocessSummary {
  int totalPunches = 0;
  int matchedEmployees = 0;
  int unmatchedEmployees = 0;

  int autoDetectedShifts = 0;
  int needsReviewGroups = 0;

  int usedCheckIns = 0;
  int usedCheckOuts = 0;
  int ignoredDuplicates = 0;

  int missingCheckIns = 0;
  int missingCheckOuts = 0;
  int expectedOvertimeCases = 0;
  int excelRowsRead = 0;
  int absentCases = 0;

  List<ProcessedGroup> groups = [];
}

class BiometricPreprocessor {
  static const int overtimeMinimumTriggerMinutes = 60;

  static final List<ShiftDefinition> defaultShifts = [
    ShiftDefinition(
      id: 's1',
      name: 'صباحي 06-14',
      startHour: 6,
      endHour: 14,
      windowStartHour: 4,
      windowEndHour: 20,
    ),
    ShiftDefinition(
      id: 's2',
      name: 'مسائي 14-22',
      startHour: 14,
      endHour: 22,
      windowStartHour: 12,
      windowEndHour: 4,
    ),
    ShiftDefinition(
      id: 's3',
      name: 'ليلي 22-06',
      startHour: 22,
      endHour: 6,
      windowStartHour: 20,
      windowEndHour: 12,
    ),
  ];

  static Future<PreprocessSummary> process({
    required List<Map<String, dynamic>> rawLogs,
    required ShiftSelectionMode shiftMode,
    required DuplicateHandlingMode duplicateMode,
    ShiftDefinition? globalShift,
    Map<String, bool> validBiometricIds = const {},
  }) async {
    final summary = PreprocessSummary();
    summary.totalPunches = rawLogs.length;

    // 1. Convert to punches
    final List<BiometricPunch> punches = [];
    int counter = 0;
    final Set<String> distinctMatched = {};
    final Set<String> distinctUnmatched = {};
    for (var log in rawLogs) {
      if (log['is_valid'] == true) {
        final bId = log['biometric_employee_id'].toString();
        punches.add(
          BiometricPunch(
            id: 'p${counter++}',
            biometricId: bId,
            time: log['punch_time'] as DateTime,
            isValid: true,
          ),
        );

        if (validBiometricIds.isEmpty || validBiometricIds.containsKey(bId)) {
          distinctMatched.add(bId);
        } else {
          distinctUnmatched.add(bId);
        }
      } else {
        final bId = log['biometric_employee_id']?.toString() ?? 'unknown';
        distinctUnmatched.add(bId);
      }
    }

    summary.matchedEmployees = distinctMatched.length;
    summary.unmatchedEmployees = distinctUnmatched.length;

    // 2. Group by employee
    final Map<String, List<BiometricPunch>> empPunches = {};
    for (var p in punches) {
      empPunches.putIfAbsent(p.biometricId, () => []).add(p);
    }

    // 3. Process each employee
    for (var empId in empPunches.keys) {
      final eList = empPunches[empId]!;
      eList.sort((a, b) => a.time.compareTo(b.time));

      // Attempt to group by physical day
      // A physical day typically starts at 04:00 AM.
      final Map<String, List<BiometricPunch>> dayGroups = {};
      for (var p in eList) {
        DateTime effectiveDate;
        if (dayGroups.isNotEmpty) {
          final lastKey = dayGroups.keys.last;
          final lastPunch = dayGroups[lastKey]!.last;
          final gap = p.time.difference(lastPunch.time).inHours;
          if (gap <= 14 && lastPunch.time.hour >= 12 && p.time.hour < 12) {
            effectiveDate = DateTime.parse(lastKey);
          } else {
            effectiveDate = p.time.hour < 4
                ? p.time.subtract(const Duration(days: 1))
                : p.time;
          }
        } else {
          effectiveDate = p.time.hour < 4
              ? p.time.subtract(const Duration(days: 1))
              : p.time;
        }

        final dateKey =
            "${effectiveDate.year}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}";
        dayGroups.putIfAbsent(dateKey, () => []).add(p);
      }

      for (var dateKey in dayGroups.keys) {
        final dayList = dayGroups[dateKey]!;
        final groupDate = DateTime.parse(dateKey);

        final group = ProcessedGroup(
          biometricId: empId,
          physicalDate: groupDate,
          punches: dayList,
        );

        // 4. Shift Selection
        if (shiftMode == ShiftSelectionMode.manualOverride &&
            globalShift != null) {
          group.suggestedShift = globalShift;
        } else {
          group.suggestedShift = _detectShift(dayList, groupDate);
        }

        if (group.suggestedShift == null) {
          group.needsReview = true;
          group.reviewReason = 'لم يتم تحديد الوردية تلقائيًا.';
          for (var p in dayList) {
            p.role = PunchRole.needsReview;
          }
          summary.needsReviewGroups++;
        } else {
          summary.autoDetectedShifts++;

          final s = group.suggestedShift!;
          group.shiftStart = DateTime(
            groupDate.year,
            groupDate.month,
            groupDate.day,
            s.startHour,
            0,
          );
          group.shiftEnd = DateTime(
            groupDate.year,
            groupDate.month,
            groupDate.day,
            s.endHour,
            0,
          );

          if (s.crossesMidnight) {
            group.shiftEnd = group.shiftEnd!.add(const Duration(days: 1));
          }

          // 5. Duplicate Handling
          if (duplicateMode == DuplicateHandlingMode.auto) {
            _handleAutoDuplicates(group, summary);
          } else {
            // Manual: just set all to ignored initially, let user pick
            for (var p in group.punches) {
              p.role = PunchRole.ignored;
            }
            group.needsReview = true;
            group.reviewReason = 'التعامل مع التكرارات يدوي';
          }
        }

        if (group.shiftStart != null) {
          group.workDate = DateTime(
            group.shiftStart!.year,
            group.shiftStart!.month,
            group.shiftStart!.day,
          );
        } else {
          group.workDate = group.physicalDate;
        }

        summary.groups.add(group);
      }
    }

    summary.groups.sort((a, b) {
      final dateCompare = a.workDate.compareTo(b.workDate);
      if (dateCompare != 0) return dateCompare;

      final empCompare = a.biometricId.compareTo(b.biometricId);
      if (empCompare != 0) return empCompare;

      final aStart = a.shiftStart ?? a.physicalDate;
      final bStart = b.shiftStart ?? b.physicalDate;
      return aStart.compareTo(bStart);
    });

    return summary;
  }

  static ShiftDefinition? _detectShift(
    List<BiometricPunch> punches,
    DateTime groupDate,
  ) {
    if (punches.isEmpty) return null;

    ShiftDefinition? bestShift;
    int bestScore = -1;

    for (var shift in defaultShifts) {
      DateTime windowStart = DateTime(
        groupDate.year,
        groupDate.month,
        groupDate.day,
        shift.windowStartHour,
        0,
      );
      DateTime windowEnd = DateTime(
        groupDate.year,
        groupDate.month,
        groupDate.day,
        shift.windowEndHour,
        0,
      );

      if (shift.windowCrossesMidnight) {
        windowEnd = windowEnd.add(const Duration(days: 1));
      }

      int score = 0;
      for (var p in punches) {
        if (p.time.isAfter(windowStart.subtract(const Duration(seconds: 1))) &&
            p.time.isBefore(windowEnd.add(const Duration(seconds: 1)))) {
          score++;
        }
      }

      if (score > bestScore && score > 0) {
        bestScore = score;
        bestShift = shift;
      }
    }

    // If all punches fall into the window of bestShift, return it.
    // If they scatter across multiple, return null (needs review).
    if (bestScore > 0 && bestScore == punches.length) {
      return bestShift;
    }

    return null;
  }

  static void _handleAutoDuplicates(
    ProcessedGroup group,
    PreprocessSummary summary,
  ) {
    final punches = group.punches;
    final shiftStart = group.shiftStart!;
    final shiftEnd = group.shiftEnd!;

    if (punches.length == 1) {
      final p = punches.first;
      final diffStart = p.time.difference(shiftStart).inMinutes.abs();
      final diffEnd = p.time.difference(shiftEnd).inMinutes.abs();

      if (diffStart < diffEnd) {
        // Closer to start => check_in
        p.role = PunchRole.checkIn;
        group.actualCheckIn = p.time;
        group.needsReview = true;
        group.reviewReason = 'لم يتم العثور على بصمة خروج.';
        summary.missingCheckOuts++;
        summary.usedCheckIns++;
      } else if (diffEnd < diffStart) {
        // Closer to end => check_out
        p.role = PunchRole.checkOut;
        group.actualCheckOut = p.time;
        group.needsReview = true;
        group.reviewReason = 'لم يتم العثور على بصمة دخول.';
        summary.missingCheckIns++;
        summary.usedCheckOuts++;

        final overtimeRaw = group.actualCheckOut!
            .difference(shiftEnd)
            .inMinutes;
        if (overtimeRaw > overtimeMinimumTriggerMinutes) {
          group.expectedOvertimeMinutes = overtimeRaw;
          summary.expectedOvertimeCases++;
        }
      } else {
        p.role = PunchRole.needsReview;
        group.needsReview = true;
        group.reviewReason = 'بصمة واحدة فقط في المنتصف.';
      }
      summary.needsReviewGroups++;
      return;
    }

    // At least 2 punches
    final checkInPunch = punches.first;
    final checkOutPunch = punches.last;

    checkInPunch.role = PunchRole.checkIn;
    group.actualCheckIn = checkInPunch.time;
    summary.usedCheckIns++;

    checkOutPunch.role = PunchRole.checkOut;
    group.actualCheckOut = checkOutPunch.time;
    summary.usedCheckOuts++;

    // Middle punches
    for (int i = 1; i < punches.length - 1; i++) {
      punches[i].role = PunchRole.duplicate;
      group.ignoredCount++;
      summary.ignoredDuplicates++;
    }

    final overtimeRaw = group.actualCheckOut!.difference(shiftEnd).inMinutes;
    if (overtimeRaw > overtimeMinimumTriggerMinutes) {
      group.expectedOvertimeMinutes = overtimeRaw;
      summary.expectedOvertimeCases++;
    }
  }
}
