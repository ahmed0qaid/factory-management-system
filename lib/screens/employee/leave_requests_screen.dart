import 'package:flutter/material.dart';

import '../../models/leave_model.dart';
import '../../services/employee_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_error_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class LeaveRequestsScreen extends StatefulWidget {
  const LeaveRequestsScreen({super.key});

  @override
  State<LeaveRequestsScreen> createState() => _LeaveRequestsScreenState();
}

class _LeaveRequestsScreenState extends State<LeaveRequestsScreen> {
  final _service = EmployeeService();
  late Future<List<dynamic>> _future;

  static const _leaveTypes = [
    'سنوية',
    'مرضية',
    'طارئة',
    'بدون راتب',
    'استئذان',
  ];

  @override
  void initState() {
    super.initState();
    _future = _service.getMyLeaves();
  }

  void _reload() => setState(() => _future = _service.getMyLeaves());

  Future<void> _showRequestDialog() async {
    final reason = TextEditingController();
    var leaveType = _leaveTypes.first;
    DateTime? startDate;
    DateTime? endDate;

    try {
      await AppFormDialog.show(
        context,
        title: 'طلب إجازة أو استئذان',
        submitText: 'إرسال الطلب',
        builder: (dialogContext, setDialogState) => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppDropdownField<String>(
              labelText: 'نوع الطلب',
              value: leaveType,
              items: _leaveTypes
                  .map(
                    (type) => DropdownMenuItem(value: type, child: Text(type)),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setDialogState(() => leaveType = value);
                }
              },
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final startButton = _DateFieldButton(
                  label: 'تاريخ البداية',
                  value: startDate,
                  icon: Icons.event_outlined,
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: startDate ?? DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked == null) return;
                    setDialogState(() {
                      startDate = picked;
                      if (endDate != null && endDate!.isBefore(picked)) {
                        endDate = picked;
                      }
                    });
                  },
                );
                final endButton = _DateFieldButton(
                  label: 'تاريخ النهاية',
                  value: endDate,
                  icon: Icons.event_available_outlined,
                  onPressed: () async {
                    final minDate = startDate ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: endDate ?? minDate,
                      firstDate: minDate,
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) {
                      setDialogState(() => endDate = picked);
                    }
                  },
                );

                if (constraints.maxWidth < 420) {
                  return Column(
                    children: [
                      startButton,
                      const SizedBox(height: 10),
                      endButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: startButton),
                    const SizedBox(width: 10),
                    Expanded(child: endButton),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            AppFormField(
              controller: reason,
              labelText: 'السبب أو الملاحظة (اختياري)',
              maxLines: 3,
              prefixIcon: Icons.notes_outlined,
            ),
          ],
        ),
        onSubmit: () async {
          if (startDate == null || endDate == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('حدد تاريخ البداية والنهاية.')),
              );
            }
            return false;
          }
          if (endDate!.isBefore(startDate!)) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تاريخ النهاية يجب ألا يسبق تاريخ البداية.'),
                ),
              );
            }
            return false;
          }

          try {
            await _service.requestLeave(
              leaveType: leaveType,
              startDate: startDate!.toIso8601String(),
              endDate: endDate!.toIso8601String(),
              reason: reason.text.trim(),
            );
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال الطلب للإدارة.')),
              );
              _reload();
            }
            return true;
          } catch (error) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تعذر إرسال الطلب: $error')),
              );
            }
            return false;
          }
        },
      );
    } finally {
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'الإجازات والاستئذان',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        icon: const Icon(Icons.add),
        label: const Text('طلب جديد'),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const AppLoadingState(label: 'جاري تحميل الطلبات');
          }
          if (snapshot.hasError) {
            return AppErrorState(
              title: 'تعذر تحميل الطلبات',
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }

          final items = snapshot.data ?? const <dynamic>[];
          if (items.isEmpty) {
            return AppEmptyState(
              title: 'لا توجد طلبات',
              message: 'لم ترسل أي طلب إجازة أو استئذان حتى الآن.',
              icon: Icons.event_available_outlined,
              actionLabel: 'إنشاء طلب',
              onAction: _showRequestDialog,
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  itemCount: items.length,
                  itemBuilder: (_, index) {
                    final request = LeaveModel.fromMap(items[index].data);
                    return AppListItem(
                      title: Text(request.leaveType),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${Formatters.date(request.startDate)} — ${Formatters.date(request.endDate)}',
                          ),
                          if (request.reason?.trim().isNotEmpty == true)
                            Text('السبب: ${request.reason}'),
                        ],
                      ),
                      trailing: _status(request.status),
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

  Widget _status(String status) {
    return switch (status) {
      'approved' => AppStatusPill.success('معتمد'),
      'rejected' => AppStatusPill.danger('مرفوض'),
      _ => AppStatusPill.warning('قيد المراجعة'),
    };
  }
}

class _DateFieldButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onPressed;

  const _DateFieldButton({
    required this.label,
    required this.value,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(
          value == null ? label : Formatters.date(value),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
