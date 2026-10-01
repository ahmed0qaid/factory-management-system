import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../services/appwrite_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';

class MyDocumentsScreen extends StatefulWidget {
  final String employeeId;

  const MyDocumentsScreen({
    super.key,
    required this.employeeId,
  });

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  late Future<List<models.Row>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<models.Row>> _load() async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.employeeDocumentsTable,
      queries: [
        Query.equal('employee_id', widget.employeeId),
        Query.orderDesc('created_at'),
        Query.limit(200),
      ],
    );
    return response.rows;
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مستنداتي',
      body: FutureBuilder<List<models.Row>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(label: 'جاري تحميل المستندات');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل المستندات',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final documents = snapshot.data ?? const <models.Row>[];
          if (documents.isEmpty) {
            return const AppEmptyState(
              title: 'لا توجد مستندات',
              message: 'لم تضف الموارد البشرية مستندات إلى ملفك حتى الآن.',
              icon: Icons.folder_open_outlined,
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
                  itemCount: documents.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) =>
                      _DocumentCard(document: documents[index]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final models.Row document;

  const _DocumentCard({required this.document});

  @override
  Widget build(BuildContext context) {
    final data = document.data;
    final title = data['title']?.toString().trim();
    final type = data['document_type']?.toString().trim();
    final notes = data['notes']?.toString().trim();
    final fileName = data['file_name']?.toString().trim();
    final hasFile = data['file_id'] != null && fileName?.isNotEmpty == true;
    final createdAt = DateTime.tryParse(data['created_at']?.toString() ?? '');
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundColor: scheme.primaryContainer,
            foregroundColor: scheme.onPrimaryContainer,
            child: Icon(
              hasFile ? Icons.description_outlined : Icons.article_outlined,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title?.isNotEmpty == true ? title! : 'مستند',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  type?.isNotEmpty == true ? type! : 'بدون تصنيف',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (notes?.isNotEmpty == true) ...[
                  const SizedBox(height: 6),
                  Text(notes!),
                ],
                if (hasFile) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.attach_file, size: 17),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          fileName!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  'أضيف في ${Formatters.date(createdAt)}',
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
