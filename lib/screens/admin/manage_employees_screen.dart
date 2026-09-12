// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../models/job_title_model.dart';
import '../../models/profile_model.dart';
import '../../services/admin_biometrics_service.dart';
import '../../services/admin_service.dart';
import '../../services/appwrite_service.dart';
import '../../services/job_title_service.dart';
import '../../theme/app_semantic_colors.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';
import 'create_employee_screen.dart';
import 'widgets/temporary_employees_list_view.dart';

class ManageEmployeesScreen extends StatefulWidget {
  final ProfileModel currentProfile;

  const ManageEmployeesScreen({super.key, required this.currentProfile});

  @override
  State<ManageEmployeesScreen> createState() => _ManageEmployeesScreenState();
}

class _ManageEmployeesScreenState extends State<ManageEmployeesScreen> {
  final AdminService _service = AdminService();
  bool _isLoading = true;
  List<ProfileModel> _allEmployees = [];
  List<ProfileModel> _filteredEmployees = [];
  final TextEditingController _searchController = TextEditingController();

  int _pendingTemporaryCount = 0;
  final _biometricsService = AdminBiometricsService();

  final _jobTitleService = JobTitleService();
  List<JobTitleModel> _activeJobTitles = [];

  @override
  void initState() {
    super.initState();
    _loadJobTitles();
    _loadEmployees();
    _loadPendingCount();
    _searchController.addListener(_filterEmployees);
  }

  Future<void> _loadJobTitles() async {
    try {
      final titles = await _jobTitleService.getJobTitles(
        companyId: widget.currentProfile.companyId,
        activeOnly: true,
      );
      if (mounted) setState(() => _activeJobTitles = titles);
    } catch (_) {
      // Keep employee management usable if job-title lookup fails.
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPendingCount() async {
    try {
      final emps = await _biometricsService.getTemporaryEmployees(
        widget.currentProfile.companyId,
        status: 'pending',
      );
      if (mounted) setState(() => _pendingTemporaryCount = emps.length);
    } catch (_) {
      // Badge is auxiliary; don't block the screen if its request fails.
    }
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _service.getEmployees(limit: 500);
      if (mounted) {
        setState(() {
          _allEmployees = employees;
          _filterEmployees();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في جلب الموظفين: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterEmployees() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = _allEmployees;
      } else {
        _filteredEmployees = _allEmployees
            .where(
              (employee) =>
                  employee.fullName.toLowerCase().contains(query) ||
                  employee.employeeNumber.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  Future<void> _toggleStatus(ProfileModel employee, bool isActive) async {
    if (employee.isHrAdmin && !isActive) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن تعطيل حساب الموارد البشرية'),
          ),
        );
      }
      return;
    }
    try {
      await _service.updateEmployeeStatus(employee.id, isActive);
      await _loadEmployees();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ${isActive ? 'تفعيل' : 'تعطيل'} الموظف بنجاح'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _showEditDialog(ProfileModel employee) {
    final nameCtrl = TextEditingController(text: employee.fullName);
    final deptCtrl = TextEditingController(text: employee.departmentName ?? '');

    final selectedJobTitles = <JobTitleModel>[];
    if (employee.jobTitleId != null && employee.jobTitleId!.isNotEmpty) {
      final ids = employee.jobTitleId!.split(',');
      for (final id in ids) {
        try {
          final title = _activeJobTitles.firstWhere((t) => t.id == id.trim());
          if (!selectedJobTitles.contains(title)) selectedJobTitles.add(title);
        } catch (_) {}
      }
    } else if (employee.jobTitleName != null &&
        employee.jobTitleName!.isNotEmpty) {
      final names = employee.jobTitleName!.split(',');
      for (final name in names) {
        try {
          final title =
              _activeJobTitles.firstWhere((t) => t.name == name.trim());
          if (!selectedJobTitles.contains(title)) selectedJobTitles.add(title);
        } catch (_) {}
      }
    }

    final biometricCtrl = TextEditingController(
      text: employee.biometricEmployeeId ?? '',
    );
    final phoneCtrl = TextEditingController(text: employee.phone ?? '');
    final baseSalaryCtrl = TextEditingController(
      text: employee.baseSalary.toString(),
    );
    final bonusCtrl = TextEditingController(
      text: employee.monthlyBonus.toString(),
    );
    final dailyWorkHoursCtrl = TextEditingController(
      text: employee.dailyWorkHours.toString(),
    );
    final empNumCtrl = TextEditingController(text: employee.employeeNumber);
    final passCtrl = TextEditingController();
    final confirmPassCtrl = TextEditingController();
    var mustChangePass = employee.mustChangePassword;
    var isActive = employee.active;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final scheme = theme.colorScheme;
            return AlertDialog(
              title: Text('تعديل الموظف: ${employee.employeeNumber}'),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppFormField(
                        controller: nameCtrl,
                        labelText: 'الاسم',
                        prefixIcon: Icons.person_outline,
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: empNumCtrl,
                        labelText: 'رقم الموظف',
                        prefixIcon: Icons.badge_outlined,
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: deptCtrl,
                        labelText: 'القسم',
                        prefixIcon: Icons.apartment_outlined,
                      ),
                      const SizedBox(height: 12),
                      InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'المسمى الوظيفي',
                          hintText: 'اختر مسمى وظيفي واحد أو أكثر',
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: _activeJobTitles.map((title) {
                            final selected = selectedJobTitles.contains(title);
                            return FilterChip(
                              label: Text(title.name),
                              selected: selected,
                              onSelected: (value) {
                                setDialogState(() {
                                  if (value) {
                                    selectedJobTitles.add(title);
                                  } else {
                                    selectedJobTitles.remove(title);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: biometricCtrl,
                        labelText: 'رقم البصمة',
                        prefixIcon: Icons.fingerprint,
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: phoneCtrl,
                        keyboardType: TextInputType.phone,
                        labelText: 'رقم الهاتف',
                        prefixIcon: Icons.phone_outlined,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: AppFormField(
                              controller: baseSalaryCtrl,
                              keyboardType: TextInputType.number,
                              labelText: 'الراتب الأساسي',
                              prefixIcon: Icons.payments_outlined,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: AppFormField(
                              controller: bonusCtrl,
                              keyboardType: TextInputType.number,
                              labelText: 'المكافأة الشهرية',
                              prefixIcon: Icons.card_giftcard_outlined,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: dailyWorkHoursCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        labelText: 'ساعات العمل اليومية',
                        hintText: 'ضمن بيانات الراتب/الدوام',
                        prefixIcon: Icons.schedule_outlined,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('الحساب نشط'),
                        subtitle: employee.isHrAdmin
                            ? Text(
                                'حساب الموارد البشرية غير قابل للتعطيل',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: scheme.onSurfaceVariant,
                                ),
                              )
                            : null,
                        value: isActive,
                        onChanged: employee.isHrAdmin
                            ? null
                            : (value) =>
                                setDialogState(() => isActive = value),
                      ),
                      const Divider(height: 24),
                      Text(
                        'تغيير كلمة المرور (اختياري)',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      AppFormField(
                        controller: passCtrl,
                        isPassword: true,
                        labelText: 'كلمة مرور جديدة',
                        prefixIcon: Icons.lock_reset_outlined,
                      ),
                      const SizedBox(height: 12),
                      AppFormField(
                        controller: confirmPassCtrl,
                        isPassword: true,
                        labelText: 'تأكيد كلمة المرور',
                        prefixIcon: Icons.check_circle_outline,
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'إجبار الموظف على تغيير كلمة المرور',
                        ),
                        value: mustChangePass,
                        onChanged: (value) =>
                            setDialogState(() => mustChangePass = value),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (employee.isHrAdmin && !isActive) {
                      _showDialogMessage('لا يمكن تعطيل حساب الموارد البشرية');
                      return;
                    }
                    final empNum = empNumCtrl.text.trim();
                    if (empNum.isEmpty) {
                      _showDialogMessage('رقم الموظف لا يمكن أن يكون فارغاً');
                      return;
                    }
                    if (confirmPassCtrl.text.isNotEmpty && passCtrl.text.isEmpty) {
                      _showDialogMessage('أدخل كلمة المرور الجديدة أولًا.');
                      return;
                    }
                    if (passCtrl.text.isNotEmpty) {
                      if (confirmPassCtrl.text.isEmpty) {
                        _showDialogMessage('يرجى تأكيد كلمة المرور.');
                        return;
                      }
                      if (passCtrl.text.length < 8) {
                        _showDialogMessage(
                          'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
                        );
                        return;
                      }
                      if (passCtrl.text != confirmPassCtrl.text) {
                        _showDialogMessage(
                          'كلمة المرور وتأكيدها غير متطابقين',
                        );
                        return;
                      }
                    }

                    Navigator.pop(dialogContext);
                    setState(() => _isLoading = true);
                    try {
                      if (empNum != employee.employeeNumber ||
                          passCtrl.text.isNotEmpty ||
                          mustChangePass != employee.mustChangePassword) {
                        await _service.updateEmployeeCredentials(
                          profileId: employee.id,
                          newEmployeeNumber: empNum != employee.employeeNumber
                              ? empNum
                              : null,
                          newPassword:
                              passCtrl.text.isNotEmpty ? passCtrl.text : null,
                          mustChangePassword:
                              mustChangePass != employee.mustChangePassword
                                  ? mustChangePass
                                  : null,
                        );
                      }

                      await _service.updateEmployeeData(
                        employee.id,
                        fullName: nameCtrl.text.trim(),
                        departmentName: deptCtrl.text.trim(),
                        jobTitleId:
                            selectedJobTitles.map((t) => t.id).join(','),
                        jobTitleName:
                            selectedJobTitles.map((t) => t.name).join(','),
                        biometricEmployeeId: biometricCtrl.text.trim(),
                        phone: phoneCtrl.text.trim(),
                        baseSalary:
                            num.tryParse(baseSalaryCtrl.text.trim()) ??
                                employee.baseSalary,
                        monthlyBonus:
                            num.tryParse(bonusCtrl.text.trim()) ??
                                employee.monthlyBonus,
                        dailyWorkHours:
                            num.tryParse(dailyWorkHoursCtrl.text.trim()) ?? 8,
                        active: isActive,
                      );

                      final verifyDoc = await AppwriteService.tablesDB.getRow(
                        databaseId: AppConstants.databaseId,
                        tableId: AppConstants.profilesTable,
                        rowId: employee.id,
                      );

                      final inputBio = biometricCtrl.text.trim();
                      final savedBio =
                          verifyDoc.data['biometric_employee_id']?.toString() ??
                              '';

                      await _loadEmployees();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              inputBio == savedBio
                                  ? 'تم حفظ بيانات الموظف.'
                                  : 'تم إرسال التعديل لكن قيمة رقم البصمة لم تحفظ كما أُدخلت.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isLoading = false);
                    }
                  },
                  child: const Text('حفظ'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDialogMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _showMobileDetails(ProfileModel employee) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final scheme = theme.colorScheme;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            MediaQuery.viewInsetsOf(sheetContext).bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: scheme.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    foregroundColor: scheme.onPrimaryContainer,
                    child: Text(
                      employee.fullName.isEmpty ? 'م' : employee.fullName[0],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          employee.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          employee.employeeNumber,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  employee.active
                      ? AppStatusPill.success('نشط')
                      : AppStatusPill.neutral('معطل'),
                ],
              ),
              const Divider(height: 24),
              _detailRow(sheetContext, 'الدور', employee.roleLabel),
              _detailRow(
                sheetContext,
                'القسم',
                employee.departmentName?.isNotEmpty == true
                    ? employee.departmentName!
                    : 'غير محدد',
              ),
              _detailRow(
                sheetContext,
                'المسمى',
                employee.jobTitleName?.isNotEmpty == true
                    ? employee.jobTitleName!
                    : 'غير محدد',
              ),
              _detailRow(
                sheetContext,
                'رقم البصمة',
                employee.biometricEmployeeId?.isNotEmpty == true
                    ? employee.biometricEmployeeId!
                    : 'غير محدد',
              ),
              _detailRow(
                sheetContext,
                'الراتب الأساسي',
                Formatters.money(employee.baseSalary),
              ),
              _detailRow(
                sheetContext,
                'المكافأة',
                Formatters.money(employee.monthlyBonus),
              ),
              _detailRow(
                sheetContext,
                'ساعات العمل اليومية',
                '${employee.dailyWorkHours}',
              ),
              if (employee.phone != null && employee.phone!.isNotEmpty)
                _detailRow(sheetContext, 'الهاتف', employee.phone!),
              _detailRow(
                sheetContext,
                'تاريخ التوظيف',
                Formatters.date(employee.hireDate),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('رجوع'),
                  ),
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل'),
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      _showEditDialog(employee);
                    },
                  ),
                  if (!employee.isHrAdmin)
                    OutlinedButton.icon(
                      icon: Icon(
                        employee.active
                            ? Icons.block_outlined
                            : Icons.check_circle_outline,
                        size: 18,
                      ),
                      label: Text(employee.active ? 'تعطيل' : 'تفعيل'),
                      style: employee.active
                          ? OutlinedButton.styleFrom(
                              foregroundColor: scheme.error,
                              side: BorderSide(
                                color: scheme.error.withValues(alpha: .55),
                              ),
                            )
                          : null,
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _toggleStatus(employee, !employee.active);
                      },
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final semantic = context.semanticColors;

    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'إدارة الموظفين',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined),
            tooltip: 'إضافة موظف',
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateEmployeeScreen(
                    currentProfile: widget.currentProfile,
                  ),
                ),
              );
              _loadEmployees();
            },
          ),
        ],
        bottom: TabBar(
          isScrollable: true,
          tabs: [
            const Tab(text: 'الموظفون الرسميون'),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('الموظفون المؤقتون'),
                  if (_pendingTemporaryCount > 0) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: semantic.warningContainer,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '$_pendingTemporaryCount',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: semantic.onWarningContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث بالاسم أو رقم الموظف',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                ),
                Expanded(
                  child: _isLoading
                      ? const AppLoadingState(label: 'جاري تحميل الموظفين')
                      : _filteredEmployees.isEmpty
                          ? const AppEmptyState(
                              title: 'لا يوجد موظفون',
                              message: 'لا يوجد موظفون مطابقون لبحثك.',
                              icon: Icons.group_off_outlined,
                            )
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                if (constraints.maxWidth < 700) {
                                  return ListView.builder(
                                    itemCount: _filteredEmployees.length,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemBuilder: (context, index) {
                                      final employee =
                                          _filteredEmployees[index];
                                      return AppListItem(
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              scheme.primaryContainer,
                                          foregroundColor:
                                              scheme.onPrimaryContainer,
                                          child: const Icon(Icons.person_outline),
                                        ),
                                        title: Text(employee.fullName),
                                        subtitle: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${employee.employeeNumber} • ${employee.jobTitleName ?? 'بدون مسمى'}',
                                            ),
                                            if (employee.biometricEmployeeId ==
                                                    null ||
                                                employee.biometricEmployeeId!
                                                    .isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 4,
                                                ),
                                                child: AppStatusPill.warning(
                                                  'رقم البصمة غير محدد',
                                                ),
                                              ),
                                          ],
                                        ),
                                        trailing: employee.active
                                            ? AppStatusPill.success('نشط')
                                            : AppStatusPill.neutral('معطل'),
                                        onTap: () =>
                                            _showMobileDetails(employee),
                                      );
                                    },
                                  );
                                }

                                return SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('الاسم')),
                                        DataColumn(label: Text('الرقم')),
                                        DataColumn(label: Text('الدور')),
                                        DataColumn(label: Text('القسم')),
                                        DataColumn(label: Text('المسمى')),
                                        DataColumn(label: Text('الحالة')),
                                        DataColumn(label: Text('رقم البصمة')),
                                        DataColumn(label: Text('إجراءات')),
                                      ],
                                      rows: _filteredEmployees.map((employee) {
                                        return DataRow(
                                          cells: [
                                            DataCell(Text(employee.fullName)),
                                            DataCell(
                                              Text(employee.employeeNumber),
                                            ),
                                            DataCell(Text(employee.roleLabel)),
                                            DataCell(
                                              Text(
                                                employee.departmentName
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? employee.departmentName!
                                                    : '-',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                employee.jobTitleName
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? employee.jobTitleName!
                                                    : '-',
                                              ),
                                            ),
                                            DataCell(
                                              Switch(
                                                value: employee.active,
                                                onChanged: employee.isHrAdmin
                                                    ? null
                                                    : (value) => _toggleStatus(
                                                          employee,
                                                          value,
                                                        ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                employee.biometricEmployeeId
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? employee
                                                        .biometricEmployeeId!
                                                    : 'غير محدد',
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.edit_outlined,
                                                ),
                                                tooltip: 'تعديل',
                                                onPressed: () =>
                                                    _showEditDialog(employee),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
            TemporaryEmployeesListView(
              companyId: widget.currentProfile.companyId,
              onEmployeeApproved: () {
                _loadEmployees();
                _loadPendingCount();
              },
            ),
          ],
        ),
      ),
    );
  }
}
