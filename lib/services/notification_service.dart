import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/notification_model.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

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
      final scopedCompanyId = await CompanyContextService.requireCompany(
        companyId,
      );
      await _db.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        rowId: ID.unique(),
        data: {
          'company_id': scopedCompanyId,
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
          Permission.read(Role.team(scopedCompanyId, 'hr_admin')),
          Permission.update(Role.team(scopedCompanyId, 'hr_admin')),
          Permission.delete(Role.team(scopedCompanyId, 'hr_admin')),
        ],
      );
    } catch (e) {
      // Notifications must not crash the parent business operation.
      // ignore: avoid_print
      print('Error creating notification: $e');
    }
  }

  Future<List<NotificationModel>> getEmployeeNotifications(
    String employeeId,
  ) async {
    try {
      final profile = await CompanyContextService.getCurrentProfile();
      if (employeeId != profile.id) {
        throw StateError('لا يمكن عرض إشعارات مستخدم آخر.');
      }
      final response = await _db.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        queries: [
          Query.equal('company_id', profile.companyId),
          Query.equal('employee_id', profile.id),
          Query.orderDesc('created_at'),
          Query.limit(50),
        ],
      );
      return response.rows
          .map((d) => NotificationModel.fromMap(d.data))
          .toList();
    } catch (e) {
      // ignore: avoid_print
      print('Error getting notifications: $e');
      return [];
    }
  }

  Future<void> markAsRead(String notificationId) async {
    try {
      final profile = await CompanyContextService.getCurrentProfile();
      final row = await _db.getRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        rowId: notificationId,
      );
      if (row.data['company_id'] != profile.companyId ||
          row.data['employee_id'] != profile.id) {
        throw StateError('لا يمكن تعديل إشعار تابع لمستخدم أو شركة أخرى.');
      }
      await _db.updateRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.notificationsTable,
        rowId: notificationId,
        data: {'is_read': true},
      );
    } catch (e) {
      // ignore: avoid_print
      print('Error marking notification as read: $e');
    }
  }
}
