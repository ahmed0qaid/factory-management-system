import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import 'appwrite_service.dart';

class AnnouncementPublishResult {
  final String announcementId;
  final int notificationsSent;
  final int notificationsFailed;

  const AnnouncementPublishResult({
    required this.announcementId,
    required this.notificationsSent,
    required this.notificationsFailed,
  });
}

class AnnouncementService {
  Future<List<models.Row>> getAnnouncements({
    required String companyId,
    int limit = 100,
  }) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.orderDesc('publish_at'),
        Query.limit(limit),
      ],
    );
    return response.rows;
  }

  Future<AnnouncementPublishResult> createAnnouncement({
    required String companyId,
    required String title,
    required String body,
    DateTime? publishAt,
    DateTime? expiresAt,
  }) async {
    final publishedAt = publishAt ?? DateTime.now();
    final announcementId = ID.unique();

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      rowId: announcementId,
      data: {
        'company_id': companyId,
        'title': title.trim(),
        'body': body.trim(),
        'publish_at': publishedAt.toIso8601String(),
        'expires_at': expiresAt?.toIso8601String(),
      },
      permissions: [
        Permission.read(Role.team(companyId)),
        Permission.update(Role.team(companyId, 'hr_admin')),
        Permission.delete(Role.team(companyId, 'hr_admin')),
        Permission.update(Role.team(companyId, 'general_manager')),
        Permission.delete(Role.team(companyId, 'general_manager')),
      ],
    );

    final profiles = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.profilesTable,
      queries: [
        Query.equal('company_id', companyId),
        Query.equal('active', true),
        Query.limit(500),
      ],
    );

    var sent = 0;
    var failed = 0;
    for (final profile in profiles.rows) {
      try {
        await AppwriteService.tablesDB.createRow(
          databaseId: AppConstants.databaseId,
          tableId: AppConstants.notificationsTable,
          rowId: ID.unique(),
          data: {
            'company_id': companyId,
            'employee_id': profile.$id,
            'title': title.trim(),
            'body': body.trim(),
            'type': 'announcement',
            'reference_table': AppConstants.announcementsTable,
            'reference_id': announcementId,
            'is_read': false,
            'created_at': DateTime.now().toIso8601String(),
          },
          permissions: [
            Permission.read(Role.user(profile.$id)),
            Permission.update(Role.user(profile.$id)),
            Permission.read(Role.team(companyId, 'hr_admin')),
          ],
        );
        sent++;
      } catch (_) {
        failed++;
      }
    }

    return AnnouncementPublishResult(
      announcementId: announcementId,
      notificationsSent: sent,
      notificationsFailed: failed,
    );
  }

  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String body,
    DateTime? expiresAt,
  }) async {
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      rowId: announcementId,
      data: {
        'title': title.trim(),
        'body': body.trim(),
        'expires_at': expiresAt?.toIso8601String(),
      },
    );
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    await AppwriteService.tablesDB.deleteRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      rowId: announcementId,
    );
  }
}
