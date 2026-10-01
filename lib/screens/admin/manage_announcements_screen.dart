import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/announcement_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class ManageAnnouncementsScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const ManageAnnouncementsScreen({
    super.key,
    required this.currentProfile,
  });

  @override
  State<ManageAnnouncementsScreen> createState() =>
      _ManageAnnouncementsScreenState();
}

class _ManageAnnouncementsScreenState
    extends State<ManageAnnouncementsScreen> {
  final _service = AnnouncementService();
  late Future<List<models.Row>> _announcementsFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _announcementsFuture = _service.getAnnouncements(
      companyId: widget.currentProfile.companyId,
    );
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _announcementsFuture;
  }

  Future<void> _showEditor({models.Row? announcement}) async {
    final titleController = TextEditingController(
      text: announcement?.data['title']?.toString() ?? '',
    );
    final bodyController = TextEditingController(
      text: announcement?.data['body']?.toString() ?? '',
    );
    DateTime? expiresAt = _parseDate(announcement?.data['expires_at']);
    var isSaving = false;

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: !isSaving,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> save() async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();
              if (title.isEmpty || body.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('أدخل عنوان الإعلان ونصه قبل الحفظ.'),
                  ),
                );
                return;
              }

              setDialogState(() => isSaving = true);
              try {
                if (announcement == null) {
                  final result = await _service.createAnnouncement(
                    companyId: widget.currentProfile.companyId,
                    title: title,
                    body: body,
                    expiresAt: expiresAt,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                  final message = result.notificationsFailed == 0
                      ? 'تم نشر الإعلان وإرسال إشعار إلى ${result.notificationsSent} موظفًا.'
                      : 'تم نشر الإعلان. أُرسل ${result.notificationsSent} إشعارًا وتعذر إرسال ${result.notificationsFailed}.';
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(content: Text(message)),
                  );
                } else {
                  await _service.updateAnnouncement(
                    announcementId: announcement.$id,
                    title: title,
                    body: body,
                    expiresAt: expiresAt,
                  );
                  if (!mounted || !dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تحديث الإعلان بنجاح.'),
                    ),
                  );
                }
              } catch (error) {
                if (!dialogContext.mounted) return;
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('تعذر حفظ الإعلان: $error')),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isSaving = false);
                }
              }
            }

            return AlertDialog(
              title: Text(announcement == null ? 'إعلان جديد' : 'تعديل الإعلان'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppFormField(
                        controller: titleController,
                        labelText: 'عنوان الإعلان',
                        prefixIcon: Icons.campaign_outlined,
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 14),
                      AppFormField(
                        controller: bodyController,
                        labelText: 'نص الإعلان',
                        prefixIcon: Icons.notes_outlined,
                        minLines: 4,
                        maxLines: 8,
                      ),
                      const SizedBox(height: 14),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.event_busy_outlined),
                        title: const Text('تاريخ انتهاء العرض'),
                        subtitle: Text(
                          expiresAt == null
                              ? 'بدون تاريخ انتهاء'
                              : _formatDate(expiresAt!),
                        ),
                        trailing: expiresAt == null
                            ? const Icon(Icons.chevron_left)
                            : IconButton(
                                tooltip: 'إزالة تاريخ الانتهاء',
                                onPressed: isSaving
                                    ? null
                                    : () => setDialogState(
                                        () => expiresAt = null,
                                      ),
                                icon: const Icon(Icons.close),
                              ),
                        onTap: isSaving
                            ? null
                            : () async {
                                final now = DateTime.now();
                                final selected = await showDatePicker(
                                  context: context,
                                  initialDate: expiresAt ?? now.add(
                                    const Duration(days: 7),
                                  ),
                                  firstDate: DateTime(
                                    now.year,
                                    now.month,
                                    now.day,
                                  ),
                                  lastDate: DateTime(now.year + 5),
                                );
                                if (selected != null) {
                                  setDialogState(
                                    () => expiresAt = DateTime(
                                      selected.year,
                                      selected.month,
                                      selected.day,
                                      23,
                                      59,
                                      59,
                                    ),
                                  );
                                }
                              },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSaving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text('إلغاء'),
                ),
                SizedBox(
                  width: 145,
                  child: AppLoadingButton(
                    text: announcement == null ? 'نشر الإعلان' : 'حفظ التعديل',
                    icon: announcement == null ? Icons.send : Icons.save,
                    isLoading: isSaving,
                    onPressed: save,
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    titleController.dispose();
    bodyController.dispose();

    if (saved == true && mounted) {
      setState(_reload);
    }
  }

  Future<void> _delete(models.Row announcement) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الإعلان'),
        content: Text(
          'هل تريد حذف الإعلان «${announcement.data['title'] ?? ''}»؟\nالإشعارات التي سبق إرسالها للموظفين لن تُحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await _service.deleteAnnouncement(announcement.$id);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف الإعلان.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تعذر حذف الإعلان: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإعلانات والتعاميم',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEditor,
        icon: const Icon(Icons.add),
        label: const Text('إعلان جديد'),
      ),
      body: FutureBuilder<List<models.Row>>(
        future: _announcementsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(label: 'جاري تحميل الإعلانات');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل الإعلانات',
              message: '${snapshot.error}',
              onRetry: () => setState(_reload),
            );
          }

          final announcements = snapshot.data ?? const <models.Row>[];
          if (announcements.isEmpty) {
            return AppEmptyState(
              title: 'لا توجد إعلانات بعد',
              message: 'أنشئ أول إعلان ليصل إلى موظفي المصنع.',
              icon: Icons.campaign_outlined,
              actionLabel: 'إنشاء إعلان',
              onAction: _showEditor,
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              itemCount: announcements.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final announcement = announcements[index];
                return _AnnouncementCard(
                  announcement: announcement,
                  onEdit: () => _showEditor(announcement: announcement),
                  onDelete: () => _delete(announcement),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final models.Row announcement;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AnnouncementCard({
    required this.announcement,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = announcement.data['title']?.toString() ?? '';
    final body = announcement.data['body']?.toString() ?? '';
    final publishAt = _parseDate(announcement.data['publish_at']);
    final expiresAt = _parseDate(announcement.data['expires_at']);
    final expired = expiresAt != null && expiresAt.isBefore(DateTime.now());

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            child: Icon(
              expired ? Icons.campaign_outlined : Icons.campaign,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (expired)
                      const Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text('منتهي'),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  [
                    if (publishAt != null) 'نشر: ${_formatDate(publishAt)}',
                    if (expiresAt != null) 'ينتهي: ${_formatDate(expiresAt)}',
                  ].join(' • '),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('تعديل')),
              PopupMenuItem(value: 'delete', child: Text('حذف')),
            ],
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
