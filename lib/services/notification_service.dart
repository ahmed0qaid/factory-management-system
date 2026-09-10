import 'package:appwrite/appwrite.dart';
import '../config/constants.dart';
import '../models/notification_model.dart';
import 'appwrite_service.dart';

class NotificationService {
  final TablesDB _db = AppwriteService.tablesDB;

  Future<void> createNotification({
    required String companyId,
    required String employeeId,
    required String title,
    required String body,
    required String type,
    String? referenceTable,
    String? referenceId,
  }) async {
    try {
      await _db.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        rowId: ID.unique(),
        data: {
          'company_id': companyId,
          'employee_id': employeeId,
          'title': title,
          'body': body,
          'type': type,
          if (referenceTable != null) 'reference_table': referenceTable,
          if (referenceId != null) 'reference_id': referenceId,
          'is_read': false,
          'created_at': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.user(employeeId)),
          Permission.update(Role.user(employeeId)),
          Permission.read(Role.team('company_main')),
          Permission.update(Role.team('company_main')),
          Permission.delete(Role.team('company_main')),
        ],
      );
    } catch (e) {
      // Don't crash the app if notification fails
      print('Error creating notification: $e');
    }
  }

  Future<List<NotificationModel>> getEmployeeNotifications(
    String employeeId,
  ) async {
    try {
      final response = await _db.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        queries: [
          Query.equal('employee_id', employeeId),
          Query.orderDesc('created_at'),
          Query.limit(50),
        ],
      );
      return response.rows
          .map((d) => NotificationModel.fromMap(d.data))
          .toList();
    } catch (e) {
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      await _db.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        rowId: notificationId,
        data: {'is_read': true},
      );
    } catch (e) {
      print('Error marking notification as read: $e');
    }
  }
}
