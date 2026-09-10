import 'package:flutter/material.dart';

import '../../services/employee_service.dart';
import '../../theme/app_colors.dart';
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

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'توقفات المصنع',
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError)
            return const AppLoadingState(label: 'جاري تحميل التوقفات');
          if (snapshot.hasError)
            return AppErrorState(
              title: 'خطأ',
              message: '${snapshot.error}',
              onRetry: () => setState(() => _future = _service.getFactoryStoppages()),
            );

          final stoppages = snapshot.data!;
          if (stoppages.isEmpty) {
            return const AppEmptyState(
              title: 'لا يوجد توقفات',
              message: 'لا توجد توقفات مصنع خلال الفترة الحالية.',
              icon: Icons.factory_outlined,
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(8),
            itemCount: stoppages.length,
            itemBuilder: (context, index) {
              final stoppage = stoppages[index];
              final isPaid = stoppage['is_paid'] as bool? ?? false;

              return AppCard(
                borderColor: AppColors.tertiary.withValues(alpha: .35),
                borderWidth: 1.2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            stoppage['title'] ?? 'بدون عنوان',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  
                                  color: AppColors.textPrimary,
                                ),
                          ),
                        ),
                        AppStatusPill(
                          label: isPaid ? 'مدفوع' : 'غير مدفوع',
                          color: isPaid ? AppColors.secondary : AppColors.tertiary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _line(
                      Icons.calendar_today,
                      'من:',
                      Formatters.date(DateTime.parse(stoppage['start_date'])),
                    ),
                    _line(
                      Icons.calendar_month,
                      'إلى:',
                      Formatters.date(DateTime.parse(stoppage['end_date'])),
                    ),
                    if (stoppage['reason'] != null &&
                        stoppage['reason'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'السبب:',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      Text(stoppage['reason']),
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

  Widget _line(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 8),
          Text(value, style: const TextStyle()),
        ],
      ),
    );
  }
}


