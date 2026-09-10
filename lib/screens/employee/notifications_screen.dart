import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/notification_model.dart';
import '../../services/appwrite_service.dart';
import '../../services/notification_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/common/app_empty_state.dart';
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
  List<NotificationModel>? _notifications;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = (await AppwriteService.account.get()).$id;
    final data = await _service.getEmployeeNotifications(uid);
    if (mounted) setState(() => _notifications = data);
  }

  void _markAsRead(NotificationModel notification) async {
    if (notification.isRead) return;
    await _service.markAsRead(notification.id);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإشعارات',
      body: _notifications == null
          ? const AppLoadingState(label: 'جاري تحميل الإشعارات')
          : _notifications!.isEmpty
          ? const AppEmptyState(
              title: 'لا توجد إشعارات',
              message: 'ليس لديك أي إشعارات جديدة في الوقت الحالي.',
              icon: Icons.notifications_none,
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16.0),
              itemCount: _notifications!.length,
              itemBuilder: (context, index) {
                final n = _notifications![index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: AppListItem(
                    leading: CircleAvatar(
                      backgroundColor: n.isRead ? AppColors.surfaceContainerHigh : AppColors.primaryContainer,
                      child: Icon(
                        Icons.notifications_active,
                        color: n.isRead ? AppColors.textSecondary : AppColors.primary,
                      ),
                    ),
                    title: Text(
                      n.title,
                      style: TextStyle(
                        fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
                        color: n.isRead ? AppColors.textSecondary : AppColors.textPrimary,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.body),
                        const SizedBox(height: 4),
                        Text(
                          DateFormat('yyyy/MM/dd HH:mm').format(n.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                    trailing: n.isRead
                        ? null
                        : const Icon(Icons.circle, color: AppColors.secondary, size: 12),
                    onTap: () => _markAsRead(n),
                  ),
                );
              },
            ),
    );
  }
}

