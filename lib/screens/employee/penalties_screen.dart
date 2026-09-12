import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../models/penalty_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class PenaltiesScreen extends StatefulWidget {
  final bool showAppBar;

  const PenaltiesScreen({super.key, this.showAppBar = false});

  @override
  State<PenaltiesScreen> createState() => _PenaltiesScreenState();
}

class _PenaltiesScreenState extends State<PenaltiesScreen> {
  final _service = EmployeeService();
  late Future<List<PenaltyModel>> _penaltiesFuture;
  late Future<AdvanceBalanceInfo> _balanceFuture;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _penaltiesFuture = _service.getMyPenalties();
    _balanceFuture = _service.getAdvanceBalance();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([_penaltiesFuture, _balanceFuture]),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AppLoadingState(label: 'جاري تحميل الجزاءات');
        }
        if (snapshot.hasError) {
          return AppErrorState(
            title: 'تعذر تحميل الجزاءات',
            message: '${snapshot.error}',
            onRetry: () => setState(_reload),
          );
        }

        final items = snapshot.data![0] as List<PenaltyModel>;
        final balance = snapshot.data![1] as AdvanceBalanceInfo;
        final hasPenalties =
            balance.penaltiesCount > 0 || balance.penaltiesAmount > 0;
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final semantic = context.semanticColors;
        final accent = hasPenalties ? semantic.warning : scheme.onSurfaceVariant;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 84),
          children: [
            AppCard(
              borderColor: hasPenalties
                  ? accent.withValues(alpha: .32)
                  : scheme.outlineVariant,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملخص الفترة الحالية',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _line(
                    context,
                    'عدد الجزاءات',
                    '${balance.penaltiesCount}',
                    accent: hasPenalties ? accent : null,
                  ),
                  _line(
                    context,
                    'إجمالي مبالغ الجزاءات',
                    Formatters.money(balance.penaltiesAmount),
                    accent: hasPenalties ? accent : null,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'السجل الكامل',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (items.isEmpty)
              const AppEmptyState(
                title: 'لا توجد جزاءات',
                message: 'لا توجد جزاءات مسجلة على حسابك في الوقت الحالي.',
                icon: Icons.gavel_outlined,
              )
            else
              ...items.map(
                (penalty) => AppListItem(
                  title: Text(penalty.category),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التاريخ: ${Formatters.date(penalty.penaltyDate)}'),
                      Text('السبب: ${penalty.reason}'),
                      Text('المبلغ: ${Formatters.money(penalty.amount)}'),
                      if (penalty.minutesDeducted > 0)
                        Text('دقائق مخصومة: ${penalty.minutesDeducted}'),
                    ],
                  ),
                  trailing: _status(penalty.status),
                ),
              ),
          ],
        );
      },
    );

    if (!widget.showAppBar) return content;

    return AppScaffold(title: 'الجزاءات', body: content);
  }

  Widget _status(String status) {
    return switch (status) {
      'approved' => AppStatusPill.success('موافق عليها'),
      'rejected' => AppStatusPill.danger('مرفوضة'),
      _ => AppStatusPill.warning('قيد المراجعة'),
    };
  }

  Widget _line(
    BuildContext context,
    String title,
    String value, {
    Color? accent,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: accent ?? scheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
