import 'package:flutter/material.dart';

import '../../models/factory_stoppage_model.dart';
import '../../models/leave_model.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/leave_stoppage_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class ManageLeavesScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const ManageLeavesScreen({super.key, required this.currentProfile});

  @override
  State<ManageLeavesScreen> createState() => _ManageLeavesScreenState();
}

class _ManageLeavesScreenState extends State<ManageLeavesScreen> {
  final LeaveStoppageService _service = LeaveStoppageService();
  final AdminService _adminService = AdminService();

  bool _loading = true;
  String? _busyId;
  List<LeaveModel> _leaves = [];
  List<FactoryStoppageModel> _stoppages = [];
  Map<String, String> _employeeNames = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait<dynamic>([
        _service.getLeaveRequests(),
        _service.getFactoryStoppages(),
        _adminService.getEmployees(limit: 500),
      ]);
      final employees = results[2] as List<ProfileModel>;
      if (!mounted) return;
      setState(() {
        _leaves = results[0] as List<LeaveModel>;
        _stoppages = results[1] as List<FactoryStoppageModel>;
        _employeeNames = {
          for (final employee in employees) employee.id: employee.fullName,
        };
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحميل الإجازات والتوقفات: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'الإجازات وتوقفات المصنع',
        body: _loading
            ? const AppLoadingState(label: 'جاري تحميل البيانات')
            : Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(icon: Icon(Icons.event_available_outlined), text: 'الإجازات'),
                      Tab(icon: Icon(Icons.factory_outlined), text: 'توقفات المصنع'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildLeaves(),
                        _buildStoppages(),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildLeaves() {
    if (_leaves.isEmpty) {
      return const AppEmptyState(
        title: 'لا توجد طلبات إجازة',
        message: 'ستظهر طلبات الموظفين هنا عند إرسالها.',
        icon: Icons.event_available_outlined,
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _leaves.length,
        itemBuilder: (context, index) {
          final leave = _leaves[index];
          final employeeName = _employeeNames[leave.employeeId] ?? leave.employeeId;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CircleAvatar(child: Icon(Icons.event_note_outlined)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              employeeName,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 3),
                            Text('${leave.leaveType} • ${Formatters.date(leave.startDate)} — ${Formatters.date(leave.endDate)}'),
                          ],
                        ),
                      ),
                      _leaveStatus(leave),
                    ],
                  ),
                  if (leave.reason?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 10),
                    Text('السبب: ${leave.reason}'),
                  ],
                  if (leave.reviewNote?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text('ملاحظة المراجعة: ${leave.reviewNote}'),
                  ],
                  if (leave.isApproved) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          leave.isPaid == false
                              ? Icons.money_off_outlined
                              : Icons.payments_outlined,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          leave.isPaid == false
                              ? 'بدون راتب — تؤثر على الاستحقاق'
                              : 'مدفوعة — لا تخصم من الراتب',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ],
                  if (leave.isPending) ...[
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        FilledButton.icon(
                          onPressed: _busyId == null
                              ? () => _approveLeave(leave)
                              : null,
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('اعتماد'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busyId == null
                              ? () => _rejectLeave(leave)
                              : null,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text('رفض'),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoppages() {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AppCard(
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'التوقفات الرسمية للمصنع',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text('يتم ربط أيام التوقف بجداول الموظفين حتى لا تتحول تلقائيًا إلى غياب.'),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: _busyId == null ? _createStoppage : null,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة توقف'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_stoppages.isEmpty)
            const AppEmptyState(
              title: 'لا توجد توقفات مسجلة',
              message: 'أضف فترة توقف رسمية عند إغلاق المصنع أو توقف الإنتاج.',
              icon: Icons.factory_outlined,
            )
          else
            ..._stoppages.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            child: Icon(
                              item.isPaid
                                  ? Icons.domain_verification_outlined
                                  : Icons.money_off_outlined,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                Text('${Formatters.date(item.startDate)} — ${Formatters.date(item.endDate)}'),
                              ],
                            ),
                          ),
                          item.isPaid
                              ? AppStatusPill.success('مدفوع')
                              : AppStatusPill.warning('غير مدفوع'),
                        ],
                      ),
                      if (item.reason?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 10),
                        Text('السبب: ${item.reason}'),
                      ],
                      const SizedBox(height: 10),
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton.icon(
                          onPressed: _busyId == null
                              ? () => _deleteStoppage(item)
                              : null,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('حذف وإعادة تسوية الأيام'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaveStatus(LeaveModel leave) {
    if (leave.isApproved) return AppStatusPill.success('معتمد');
    if (leave.isRejected) return AppStatusPill.danger('مرفوض');
    return AppStatusPill.warning('قيد المراجعة');
  }

  Future<void> _approveLeave(LeaveModel leave) async {
    var isPaid = leave.leaveType.trim() != 'بدون راتب';
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('اعتماد الإجازة'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('حدد الأثر المالي لإجازة ${_employeeNames[leave.employeeId] ?? leave.employeeId}.'),
                    const SizedBox(height: 12),
                    RadioListTile<bool>(
                      value: true,
                      groupValue: isPaid,
                      onChanged: leave.leaveType.trim() == 'بدون راتب'
                          ? null
                          : (value) => setDialogState(() => isPaid = value ?? true),
                      title: const Text('إجازة مدفوعة'),
                      subtitle: const Text('لا تخصم أيام الإجازة من الراتب.'),
                    ),
                    RadioListTile<bool>(
                      value: false,
                      groupValue: isPaid,
                      onChanged: (value) => setDialogState(() => isPaid = value ?? false),
                      title: const Text('إجازة بدون راتب'),
                      subtitle: const Text('تخصم أيام العمل الواقعة داخل فترة الإجازة.'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: note,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظة الاعتماد *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('اعتماد'),
                ),
              ],
            ),
          ),
        ) ??
        false;
    if (!confirmed) {
      note.dispose();
      return;
    }
    if (note.text.trim().isEmpty) {
      note.dispose();
      _message('ملاحظة الاعتماد مطلوبة.');
      return;
    }

    setState(() => _busyId = leave.id);
    try {
      await _service.approveLeave(
        leaveId: leave.id,
        isPaid: isPaid,
        reviewNote: note.text,
      );
      _message('تم اعتماد الإجازة وربطها بالحضور والراتب.');
      await _load();
    } catch (error) {
      _message('تعذر اعتماد الإجازة: $error');
    } finally {
      note.dispose();
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _rejectLeave(LeaveModel leave) async {
    final note = TextEditingController();
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('رفض الإجازة'),
            content: TextField(
              controller: note,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'سبب الرفض *',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('رفض'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) {
      note.dispose();
      return;
    }
    if (note.text.trim().isEmpty) {
      note.dispose();
      _message('سبب الرفض مطلوب.');
      return;
    }

    setState(() => _busyId = leave.id);
    try {
      await _service.rejectLeave(leaveId: leave.id, reviewNote: note.text);
      _message('تم رفض الطلب.');
      await _load();
    } catch (error) {
      _message('تعذر رفض الطلب: $error');
    } finally {
      note.dispose();
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _createStoppage() async {
    final title = TextEditingController();
    final reason = TextEditingController();
    var isPaid = true;
    DateTime? start;
    DateTime? end;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              title: const Text('إضافة توقف مصنع'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: title,
                      decoration: const InputDecoration(
                        labelText: 'عنوان التوقف *',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _DateButton(
                      label: 'تاريخ البداية',
                      value: start,
                      onTap: () async {
                        final value = await showDatePicker(
                          context: dialogContext,
                          initialDate: start ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (value != null) {
                          setDialogState(() {
                            start = value;
                            if (end != null && end!.isBefore(value)) end = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    _DateButton(
                      label: 'تاريخ النهاية',
                      value: end,
                      onTap: () async {
                        final min = start ?? DateTime(2020);
                        final value = await showDatePicker(
                          context: dialogContext,
                          initialDate: end ?? start ?? DateTime.now(),
                          firstDate: min,
                          lastDate: DateTime.now().add(const Duration(days: 730)),
                        );
                        if (value != null) setDialogState(() => end = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      value: isPaid,
                      onChanged: (value) => setDialogState(() => isPaid = value),
                      title: const Text('توقف مدفوع'),
                      subtitle: Text(
                        isPaid
                            ? 'لا يخصم من رواتب الموظفين.'
                            : 'يخصم يوم العمل المتوقف من الراتب.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: reason,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'السبب أو الملاحظة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirmed) {
      title.dispose();
      reason.dispose();
      return;
    }
    if (title.text.trim().isEmpty || start == null || end == null) {
      title.dispose();
      reason.dispose();
      _message('العنوان وتاريخ البداية والنهاية مطلوبة.');
      return;
    }

    setState(() => _busyId = 'new_stoppage');
    try {
      await _service.createFactoryStoppage(
        title: title.text,
        startDate: start!,
        endDate: end!,
        isPaid: isPaid,
        reason: reason.text,
      );
      _message('تم تسجيل توقف المصنع وربطه بجداول الحضور والرواتب.');
      await _load();
    } catch (error) {
      _message('تعذر إضافة التوقف: $error');
    } finally {
      title.dispose();
      reason.dispose();
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _deleteStoppage(FactoryStoppageModel item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('حذف توقف المصنع'),
            content: Text(
              'سيتم حذف "${item.title}" وإعادة تسوية أيام الحضور المرتبطة بالفترة. هل تريد المتابعة؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('حذف'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;

    setState(() => _busyId = item.id);
    try {
      await _service.deleteFactoryStoppage(item.id);
      _message('تم حذف التوقف وإعادة تسوية الأيام.');
      await _load();
    } catch (error) {
      _message('تعذر حذف التوقف: $error');
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

class _DateButton extends StatelessWidget {
  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  const _DateButton({required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.calendar_today_outlined),
      label: Text(value == null ? label : Formatters.date(value)),
    );
  }
}
