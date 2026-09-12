import 'package:flutter/material.dart';

import '../../models/notification_model.dart';
import '../../services/appwrite_service.dart';
import '../../services/notification_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _service = NotificationService();
  late Future<List<NotificationModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<NotificationModel>> _load() async {
    final user = await AppwriteService.account.get();
    return _service.getEmployeeNotifications(user.$id);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    try {
      await _service.markAsRead(notification.id);
      if (mounted) _reload();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحديث الإشعار: $error')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإشعارات',
      body: FutureBuilder<List<NotificationModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(label: 'جاري تحميل الإشعارات');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل الإشعارات',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final notifications = snapshot.data ?? const <NotificationModel>[];
          if (notifications.isEmpty) {
            return const AppEmptyState(
              title: 'لا توجد إشعارات',
              message: 'لا توجد تحديثات أو إجراءات جديدة تحتاج إلى انتباهك.',
              icon: Icons.notifications_none_outlined,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: notifications.length,
                  itemBuilder: (context, index) {
                    final notification = notifications[index];
                    final colors = Theme.of(context).colorScheme;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppListItem(
                        leading: CircleAvatar(
                          backgroundColor: notification.isRead
                              ? colors.surfaceContainerHighest
                              : colors.primaryContainer,
                          child: Icon(
                            notification.isRead
                                ? Icons.notifications_none_outlined
                                : Icons.notifications_active_outlined,
                            color: notification.isRead
                                ? colors.onSurfaceVariant
                                : colors.onPrimaryContainer,
                          ),
                        ),
                        title: Text(
                          notification.title,
                          style: TextStyle(
                            fontWeight: notification.isRead
                                ? FontWeight.normal
                                : FontWeight.bold,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification.body),
                            const SizedBox(height: 5),
                            Text(
                              '${Formatters.date(notification.createdAt)} • ${Formatters.time(notification.createdAt)}',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant),
                            ),
                          ],
                        ),
                        trailing: notification.isRead
                            ? null
                            : Icon(
                                Icons.circle,
                                color: colors.primary,
                                size: 10,
                              ),
                        onTap: () => _markAsRead(notification),
                      ),
                    );
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
