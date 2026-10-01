import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import 'appwrite_service.dart';

class AnnouncementPublishResult {
  final String announcementId;
  final int notificationsSent;
  final int notificationsFailed;
  final bool notificationDeliveryCompleted;

  const AnnouncementPublishResult({
    required this.announcementId,
    required this.notificationsSent,
    required this.notificationsFailed,
    required this.notificationDeliveryCompleted,
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

  Future<List<models.Row>> getActiveAnnouncements({
    required String companyId,
    int limit = 50,
  }) async {
    final rows = await getAnnouncements(companyId: companyId, limit: limit);
    final now = DateTime.now();
    return rows.where((row) {
      final publishAt = _parseDate(row.data['publish_at']);
      final expiresAt = _parseDate(row.data['expires_at']);
      if (publishAt != null && publishAt.isAfter(now)) return false;
      if (expiresAt != null && expiresAt.isBefore(now)) return false;
      return true;
    }).toList();
  }

  Future<AnnouncementPublishResult> createAnnouncement({
    required String companyId,
    required String title,
    required String body,
    DateTime? publishAt,
    DateTime? expiresAt,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      throw ArgumentError('عنوان الإعلان ونصه مطلوبان.');
    }
    if (cleanTitle.length > 160) {
      throw ArgumentError('عنوان الإعلان يجب ألا يتجاوز 160 حرفًا.');
    }
    if (cleanBody.length > 5000) {
      throw ArgumentError('نص الإعلان يجب ألا يتجاوز 5000 حرف.');
    }

    final publishedAt = publishAt ?? DateTime.now();
    final announcementId = ID.unique();

    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      rowId: announcementId,
      data: {
        'company_id': companyId,
        'title': cleanTitle,
        'body': cleanBody,
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

    var sent = 0;
    var failed = 0;
    var deliveryCompleted = true;

    try {
      final profiles = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.profilesTable,
        queries: [
          Query.equal('company_id', companyId),
          Query.equal('active', true),
          Query.limit(500),
        ],
      );

      final notificationBody = cleanBody.length > 1000
          ? '${cleanBody.substring(0, 997)}...'
          : cleanBody;

      for (final profile in profiles.rows) {
        try {
          await AppwriteService.tablesDB.createRow(
            databaseId: AppConstants.databaseId,
            tableId: AppConstants.notificationsTable,
            rowId: ID.unique(),
            data: {
              'company_id': companyId,
              'employee_id': profile.$id,
              'title': cleanTitle,
              'body': notificationBody,
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
    } catch (_) {
      deliveryCompleted = false;
    }

    return AnnouncementPublishResult(
      announcementId: announcementId,
      notificationsSent: sent,
      notificationsFailed: failed,
      notificationDeliveryCompleted: deliveryCompleted,
    );
  }

  Future<void> updateAnnouncement({
    required String announcementId,
    required String title,
    required String body,
    DateTime? expiresAt,
  }) async {
    final cleanTitle = title.trim();
    final cleanBody = body.trim();
    if (cleanTitle.isEmpty || cleanBody.isEmpty) {
      throw ArgumentError('عنوان الإعلان ونصه مطلوبان.');
    }
    if (cleanTitle.length > 160) {
      throw ArgumentError('عنوان الإعلان يجب ألا يتجاوز 160 حرفًا.');
    }
    if (cleanBody.length > 5000) {
      throw ArgumentError('نص الإعلان يجب ألا يتجاوز 5000 حرف.');
    }

    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.announcementsTable,
      rowId: announcementId,
      data: {
        'title': cleanTitle,
        'body': cleanBody,
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

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }
}
