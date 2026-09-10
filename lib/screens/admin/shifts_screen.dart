import 'package:flutter/material.dart';
import '../../models/profile_model.dart';
import '../../models/shift_model.dart';
import '../../permissions/role_permissions.dart';
import '../../services/shift_service.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';
import '../../theme/app_colors.dart';

class ShiftsScreen extends StatefulWidget {
  final ProfileModel profile;

  const ShiftsScreen({super.key, required this.profile});

  @override
  State<ShiftsScreen> createState() => _ShiftsScreenState();
}

class _ShiftsScreenState extends State<ShiftsScreen> {
  final ShiftService _shiftService = ShiftService();
  late Future<List<ShiftModel>> _shiftsFuture;

  @override
  void initState() {
    super.initState();
    _loadShifts();
  }

  void _loadShifts() {
    setState(() {
      _shiftsFuture = _shiftService.getShifts(widget.profile.companyId).then((shifts) async {
        if (shifts.isEmpty && AppRoles.isHr(widget.profile.role)) {
          await _shiftService.seedDefaultShifts(widget.profile.companyId);
          return _shiftService.getShifts(widget.profile.companyId);
        }
        return shifts;
      });
    });
  }

  String _formatTime(String time24) {
    if (time24.isEmpty) return '';
    final parts = time24.split(':');
    if (parts.length < 2) return time24;
    int h = int.parse(parts[0]);
    final m = parts[1];
    final ampm = h >= 12 ? 'م' : 'ص';
    if (h > 12) h -= 12;
    if (h == 0) h = 12;
    return '$h:$m $ampm';
  }

  void _showShiftDialog({ShiftModel? shift}) {
    if (!AppRoles.isHr(widget.profile.role)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('صلاحية تعديل الورديات مخصصة للموارد البشرية فقط')),
      );
      return;
    }

    final nameController = TextEditingController(text: shift?.name ?? '');
    final notesController = TextEditingController(text: shift?.notes ?? '');
    final graceLateController = TextEditingController(text: shift?.graceLateMinutes?.toString() ?? '15');
    final graceEarlyController = TextEditingController(text: shift?.graceEarlyLeaveMinutes?.toString() ?? '15');
    
    TimeOfDay? startTime = shift != null ? _parseTime(shift.startTime) : const TimeOfDay(hour: 6, minute: 0);
    TimeOfDay? endTime = shift != null ? _parseTime(shift.endTime) : const TimeOfDay(hour: 14, minute: 0);
    bool isOvernight = shift?.isOvernight ?? false;

    AppFormDialog.show(
      context,
      title: shift == null ? 'إضافة وردية' : 'تعديل الوردية',
      submitText: 'حفظ',
      onSubmit: () async {
        if (nameController.text.isEmpty || startTime == null || endTime == null) return false;
        
        final newShift = ShiftModel(
          id: shift?.id ?? '',
          companyId: widget.profile.companyId,
          name: nameController.text,
          startTime: '${startTime!.hour.toString().padLeft(2, '0')}:${startTime!.minute.toString().padLeft(2, '0')}',
          endTime: '${endTime!.hour.toString().padLeft(2, '0')}:${endTime!.minute.toString().padLeft(2, '0')}',
          graceLateMinutes: int.tryParse(graceLateController.text),
          graceEarlyLeaveMinutes: int.tryParse(graceEarlyController.text),
          isOvernight: isOvernight,
          active: shift?.active ?? true,
          notes: notesController.text.isEmpty ? null : notesController.text,
        );

        try {
          if (shift == null) {
            await _shiftService.createShift(newShift);
          } else {
            await _shiftService.updateShift(newShift);
          }
          _loadShifts();
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
          }
          return false;
        }
      },
      builder: (ctx, setDialogState) {
        Future<void> pickTime(bool isStart) async {
          final initialTime = isStart ? startTime : endTime;
          final picked = await showTimePicker(
            context: ctx,
            initialTime: initialTime ?? TimeOfDay.now(),
          );
          if (picked != null) {
            setDialogState(() {
              if (isStart) startTime = picked;
              else endTime = picked;
            });
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFormField(
              controller: nameController,
              labelText: 'اسم الوردية',
              prefixIcon: Icons.badge_outlined,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => pickTime(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'وقت البداية', prefixIcon: Icon(Icons.access_time)),
                      child: Text(startTime != null ? startTime!.format(ctx) : 'اختيار'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: () => pickTime(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'وقت النهاية', prefixIcon: Icon(Icons.access_time)),
                      child: Text(endTime != null ? endTime!.format(ctx) : 'اختيار'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('وردية ليلية (تعبر منتصف الليل)'),
              value: isOvernight,
              onChanged: (val) => setDialogState(() => isOvernight = val),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: AppFormField(
                    controller: graceLateController,
                    labelText: 'سماحية التأخير (دقائق)',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppFormField(
                    controller: graceEarlyController,
                    labelText: 'سماحية الخروج المبكر',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AppFormField(
              controller: notesController,
              labelText: 'ملاحظات',
              maxLines: 2,
              prefixIcon: Icons.notes,
            ),
          ],
        );
      },
    );
  }

  TimeOfDay _parseTime(String time24) {
    final parts = time24.split(':');
    if (parts.length < 2) return const TimeOfDay(hour: 0, minute: 0);
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  Future<void> _toggleActive(ShiftModel shift) async {
    if (!AppRoles.isHr(widget.profile.role)) return;
    try {
      await _shiftService.toggleActive(shift.id, !shift.active);
      _loadShifts();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('حدث خطأ: \$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHr = AppRoles.isHr(widget.profile.role);

    return AppScaffold(
      title: 'إدارة الورديات',
      floatingActionButton: isHr
          ? FloatingActionButton.extended(
              onPressed: () => _showShiftDialog(),
              icon: const Icon(Icons.add),
              label: const Text('إضافة وردية'),
            )
          : null,
      body: FutureBuilder<List<ShiftModel>>(
        future: _shiftsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: \${snapshot.error}'));
          }

          final shifts = snapshot.data ?? [];
          if (shifts.isEmpty) {
            return const Center(child: Text('لا توجد ورديات.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: shifts.length,
            itemBuilder: (context, index) {
              final shift = shifts[index];
              return AppCard(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            shift.name,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        shift.active
                            ? AppStatusPill.success('نشطة')
                            : AppStatusPill.danger('موقوفة'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 16, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text('${_formatTime(shift.startTime)} - ${_formatTime(shift.endTime)}'),
                        if (shift.isOvernight) ...[
                          const SizedBox(width: 8),
                          AppStatusPill.info('ليلية'),
                        ]
                      ],
                    ),
                    if (shift.graceLateMinutes != null || shift.graceEarlyLeaveMinutes != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.info_outline, size: 16, color: AppColors.secondary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'تأخير: ${shift.graceLateMinutes ?? 0} د | خروج مبكر: ${shift.graceEarlyLeaveMinutes ?? 0} د',
                              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (shift.notes != null && shift.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'ملاحظات: ${shift.notes}',
                        style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ],
                    if (isHr) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton.icon(
                            onPressed: () => _toggleActive(shift),
                            icon: Icon(shift.active ? Icons.pause : Icons.play_arrow),
                            label: Text(shift.active ? 'تعطيل' : 'تفعيل'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showShiftDialog(shift: shift),
                            icon: const Icon(Icons.edit, size: 18),
                            label: const Text('تعديل'),
                          ),
                        ],
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
}
