import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../../services/announcement_service.dart';
import '../../services/employee_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({super.key});

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _announcementService = AnnouncementService();
  final _employeeService = EmployeeService();
  late Future<List<models.Row>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<models.Row>> _load() async {
    final profile = await _employeeService.getMyProfile();
    return _announcementService.getActiveAnnouncements(
      companyId: profile.companyId,
    );
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإعلانات والتعاميم',
      body: FutureBuilder<List<models.Row>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(label: 'جاري تحميل الإعلانات');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل الإعلانات',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final announcements = snapshot.data ?? const <models.Row>[];
          if (announcements.isEmpty) {
            return const AppEmptyState(
              title: 'لا توجد إعلانات حالية',
              message: 'ستظهر هنا التعاميم والإعلانات المنشورة من الإدارة.',
              icon: Icons.campaign_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: announcements.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final announcement = announcements[index];
                    return _AnnouncementCard(announcement: announcement);
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final models.Row announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context) {
    final title = announcement.data['title']?.toString() ?? '';
    final body = announcement.data['body']?.toString() ?? '';
    final publishAt = _parseDate(announcement.data['publish_at']);
    final expiresAt = _parseDate(announcement.data['expires_at']);
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      elevated: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: const Icon(Icons.campaign_outlined),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(body),
                const SizedBox(height: 10),
                Text(
                  [
                    if (publishAt != null) 'نشر: ${_formatDate(publishAt)}',
                    if (expiresAt != null) 'متاح حتى: ${_formatDate(expiresAt)}',
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _parseDate(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
