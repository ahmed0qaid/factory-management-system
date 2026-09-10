import 'package:flutter/foundation.dart';

class EmployeeTabNavigation {
  static final ValueNotifier<int?> requestedIndex = ValueNotifier<int?>(null);

  static void openHome() => requestedIndex.value = 0;
  static void openAttendance() => requestedIndex.value = 1;
  static void openPayroll() => requestedIndex.value = 2;
  static void openAdvances() => requestedIndex.value = 3;
  static void openProfile() => requestedIndex.value = 4;

  static void clear() {
    requestedIndex.value = null;
  }
}
