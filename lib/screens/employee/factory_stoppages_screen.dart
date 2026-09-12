import 'package:flutter/material.dart';

import '../../services/employee_service.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class FactoryStoppagesScreen extends StatefulWidget {
  const FactoryStoppagesScreen({super.key});

  @override
  State<FactoryStoppagesScreen> createState() => _FactoryStoppagesScreenState();
}

class _FactoryStoppagesScreenState extends State<FactoryStoppagesScreen> {
  final _service = EmployeeService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.getFactoryStoppages();
  }

  void _reload() {
    setState(() => _future = _service.getFactoryStoppages());
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'توقفات المصنع',
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const AppLoadingState(label: 'جاري تحميل التوقفات');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل التوقفات',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final stoppages = snapshot.data!;
          if (stoppages.isEmpty) {
            return const AppEmptyState(
              title: 'لا توجد توقفات',
              message: 'لا توجد توقفات مصنع خلال الفترة الحالية.',
              icon: Icons.factory_outlined,
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: stoppages.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final theme = Theme.of(context);
              final scheme = theme.colorScheme;
              final semantic = context.semanticColors;
              final stoppage = stoppages[index];
              final isPaid = stoppage['is_paid'] as bool? ?? false;
              final accent = isPaid ? semantic.success : semantic.warning;

              return AppCard(
                borderColor: accent.withValues(alpha: .26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: accent.withValues(
                              alpha: theme.brightness == Brightness.dark
                                  ? .18
                                  : .08,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.factory_outlined,
                            size: 18,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            stoppage['title'] ?? 'بدون عنوان',
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: scheme.onSurface,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        isPaid
                            ? AppStatusPill.success('مدفوع')
                            : AppStatusPill.warning('غير مدفوع'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _line(
                      context,
                      Icons.calendar_today_outlined,
                      'من',
                      Formatters.date(DateTime.parse(stoppage['start_date'])),
                    ),
                    _line(
                      context,
                      Icons.calendar_month_outlined,
                      'إلى',
                      Formatters.date(DateTime.parse(stoppage['end_date'])),
                    ),
                    if (stoppage['reason'] != null &&
                        stoppage['reason'].toString().trim().isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'السبب',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              stoppage['reason'].toString(),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _line(
    BuildContext context,
    IconData icon,
    String title,
    String value,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            '$title:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
