import 'package:flutter/material.dart';

import '../../models/advance_model.dart';
import '../../models/penalty_model.dart';
import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_status_pill.dart';
import '../../widgets/common/app_scaffold.dart';

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
    _penaltiesFuture = _service.getMyPenalties();
    _balanceFuture = _service.getAdvanceBalance();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder(
      future: Future.wait([_penaltiesFuture, _balanceFuture]),
      builder: (context, AsyncSnapshot<List<dynamic>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final items = snapshot.data![0] as List<PenaltyModel>;
        final balance = snapshot.data![1] as AdvanceBalanceInfo;
        final hasPenalties = balance.penaltiesCount > 0 || balance.penaltiesAmount > 0;

        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            AppCard(
              backgroundColor: Colors.white,
              borderColor: hasPenalties
                  ? AppColors.tertiary.withValues(alpha: .35)
                  : AppColors.border,
              borderWidth: 1.2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ملخص الفترة الحالية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _line('عدد الجزاءات', '${balance.penaltiesCount}', hasPenalties),
                  _line(
                    'إجمالي مبالغ الجزاءات',
                    Formatters.money(balance.penaltiesAmount),
                    hasPenalties,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 12),
              child: Text(
                'السجل الكامل',
                style: TextStyle(fontSize: 16),
              ),
            ),
            if (items.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('لا توجد جزاءات.'),
                ),
              )
            else
              ...items.map(
                (p) => AppListItem(
                  title: Text(p.category),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('التاريخ: ${Formatters.date(p.penaltyDate)}'),
                      Text('السبب: ${p.reason}'),
                      Text('المبلغ: ${Formatters.money(p.amount)}'),
                      if (p.minutesDeducted > 0)
                        Text('دقائق مخصومة: ${p.minutesDeducted}'),
                    ],
                  ),
                  trailing: AppStatusPill(
                    label: p.status == 'approved' ? 'موافق عليها' : p.status == 'rejected' ? 'مرفوضة' : 'قيد المراجعة',
                    color: p.status == 'approved' ? AppColors.success : p.status == 'rejected' ? AppColors.danger : AppColors.warning,
                  ),
                ),
              ),
          ],
        );
      },
    );

    if (!widget.showAppBar) return content;

    return AppScaffold(
      title: 'الجزاءات',
      body: content,
    );
  }

  Widget _line(String title, String value, [bool isActive = false]) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: isActive ? AppColors.tertiary : AppColors.textSecondary)),
          Text(
            value,
            style: TextStyle(
              color: isActive ? AppColors.tertiary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}


