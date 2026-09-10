// ignore_for_file: curly_braces_in_flow_control_structures

import 'package:flutter/material.dart';
import '../../theme/app_colors.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/appwrite_service.dart';
import '../../config/constants.dart';
import 'create_employee_screen.dart';
import 'widgets/temporary_employees_list_view.dart';
import '../../services/admin_biometrics_service.dart';
import '../../services/job_title_service.dart';
import '../../models/job_title_model.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_status_pill.dart';

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
    } catch (e) {
      // Ignore or log
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
    } catch (e) {
      // Ignored
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
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في جلب الموظفين: $e')));
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
              (e) =>
                  e.fullName.toLowerCase().contains(query) ||
                  e.employeeNumber.toLowerCase().contains(query),
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
            backgroundColor: AppColors.danger,
          ),
        );
      }
      return;
    }
    try {
      await _service.updateEmployeeStatus(employee.id, isActive);
      _loadEmployees();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم ${isActive ? 'تفعيل' : 'تعطيل'} الموظف بنجاح'),
          ),
        );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
    }
  }

  void _showEditDialog(ProfileModel employee) {
    final nameCtrl = TextEditingController(text: employee.fullName);
    final deptCtrl = TextEditingController(text: employee.departmentName ?? '');

    List<JobTitleModel> selectedJobTitles = [];
    if (employee.jobTitleId != null && employee.jobTitleId!.isNotEmpty) {
      final ids = employee.jobTitleId!.split(',');
      for (final id in ids) {
        try {
          final t = _activeJobTitles.firstWhere((t) => t.id == id.trim());
          if (!selectedJobTitles.contains(t)) {
            selectedJobTitles.add(t);
          }
        } catch (_) {}
      }
    } else if (employee.jobTitleName != null && employee.jobTitleName!.isNotEmpty) {
      final names = employee.jobTitleName!.split(',');
      for (final name in names) {
        try {
          final t = _activeJobTitles.firstWhere((t) => t.name == name.trim());
          if (!selectedJobTitles.contains(t)) {
            selectedJobTitles.add(t);
          }
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
    bool mustChangePass = employee.mustChangePassword;
    bool isActive = employee.active;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('تعديل الموظف: ${employee.employeeNumber}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'الاسم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: empNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم الموظف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: deptCtrl,
                      decoration: const InputDecoration(
                        labelText: 'القسم',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'المسمى الوظيفي',
                        hintText: 'اختر مسمى وظيفي واحد أو أكثر',
                        border: OutlineInputBorder(),
                      ),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: _activeJobTitles.map((title) {
                          final isSelected = selectedJobTitles.contains(title);
                          return FilterChip(
                            label: Text(title.name),
                            selected: isSelected,
                            onSelected: (selected) {
                              setDialogState(() {
                                if (selected) {
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
                    const SizedBox(height: 8),
                    TextField(
                      controller: biometricCtrl,
                      decoration: const InputDecoration(
                        labelText: 'رقم البصمة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'رقم الهاتف',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: baseSalaryCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الراتب الأساسي',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: bonusCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'المكافأة الشهرية',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: dailyWorkHoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'ساعات العمل اليومية',
                        helperText: 'ضمن بيانات الراتب/الدوام',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('نشط'),
                      subtitle: employee.isHrAdmin
                          ? const Text(
                              'حساب الموارد البشرية غير قابل للتعطيل',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 12,
                              ),
                            )
                          : null,
                      value: isActive,
                      onChanged: employee.isHrAdmin
                          ? null
                          : (val) => setDialogState(() => isActive = val),
                    ),
                    const Divider(),
                    const Text(
                      'تغيير كلمة المرور (اختياري)',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'كلمة مرور جديدة',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: confirmPassCtrl,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'تأكيد كلمة المرور',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: const Text('إجبار الموظف على تغيير كلمة المرور'),
                      value: mustChangePass,
                      onChanged: (val) =>
                          setDialogState(() => mustChangePass = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (employee.isHrAdmin && !isActive) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('لا يمكن تعطيل حساب الموارد البشرية'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    final empNum = empNumCtrl.text.trim();
                    if (empNum.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('رقم الموظف لا يمكن أن يكون فارغاً'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }
                    if (confirmPassCtrl.text.isNotEmpty &&
                        passCtrl.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('أدخل كلمة المرور الجديدة أولًا.'),
                          backgroundColor: AppColors.danger,
                        ),
                      );
                      return;
                    }

                    if (passCtrl.text.isNotEmpty) {
                      if (confirmPassCtrl.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('يرجى تأكيد كلمة المرور.'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        return;
                      }
                      if (passCtrl.text.length < 8) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'كلمة المرور يجب أن تكون 8 أحرف على الأقل',
                            ),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        return;
                      }
                      if (passCtrl.text != confirmPassCtrl.text) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('كلمة المرور وتأكيدها غير متطابقين'),
                            backgroundColor: AppColors.danger,
                          ),
                        );
                        return;
                      }
                    }

                    Navigator.pop(context); // Close dialog
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
                          newPassword: passCtrl.text.isNotEmpty
                              ? passCtrl.text
                              : null,
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
                        jobTitleId: selectedJobTitles.map((t) => t.id).join(','),
                        jobTitleName: selectedJobTitles.map((t) => t.name).join(','),
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

                      // Verify the update actually saved in Appwrite
                      final verifyDoc = await AppwriteService.tablesDB.getRow(
                        databaseId: AppConstants.databaseId,
                        tableId: AppConstants.profilesTable,
                        rowId: employee.id,
                      );

                      final inputBio = biometricCtrl.text.trim();
                      final savedBio =
                          verifyDoc.data['biometric_employee_id']?.toString() ??
                          '';

                      await _loadEmployees(); // Reload lists
                      if (context.mounted) {
                        if (inputBio == savedBio) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تم حفظ بيانات الموظف.'),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'تم إرسال التعديل لكن القيمة لم تحفظ في قاعدة البيانات. (المدخل: $inputBio, المحفوظ: $savedBio)',
                              ),
                              backgroundColor: AppColors.danger,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted)
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceAll('Exception: ', ''),
                            ),
                          ),
                        );
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

  void _showMobileDetails(ProfileModel employee) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تفاصيل الموظف',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(),
              ),
              const Divider(),
              _detailRow('الاسم:', employee.fullName),
              _detailRow('رقم الموظف:', employee.employeeNumber),
              _detailRow('الدور:', employee.roleLabel),
              _detailRow(
                'القسم:',
                employee.departmentName?.isNotEmpty == true
                    ? employee.departmentName!
                    : 'غير محدد',
              ),
              _detailRow(
                'المسمى:',
                employee.jobTitleName?.isNotEmpty == true
                    ? employee.jobTitleName!
                    : 'غير محدد',
              ),
              _detailRow(
                'رقم البصمة:',
                employee.biometricEmployeeId?.isNotEmpty == true
                    ? employee.biometricEmployeeId!
                    : 'غير محدد',
              ),
              _detailRow('الراتب الأساسي:', '${employee.baseSalary}'),
              _detailRow('المكافأة:', '${employee.monthlyBonus}'),
              _detailRow('ساعات العمل اليومية:', '${employee.dailyWorkHours}'),
              if (employee.phone != null && employee.phone!.isNotEmpty)
                _detailRow('الهاتف:', employee.phone!),
              _detailRow(
                'تاريخ التوظيف:',
                employee.hireDate.toIso8601String().substring(0, 10),
              ),
              _detailRow('الحالة:', employee.active ? 'نشط' : 'غير نشط'),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: const Text('تعديل'),
                    onPressed: () {
                      Navigator.pop(context);
                      _showEditDialog(employee);
                    },
                  ),
                  if (!employee.isHrAdmin)
                    ElevatedButton.icon(
                      icon: Icon(
                        employee.active ? Icons.block : Icons.check_circle,
                        size: 18,
                      ),
                      label: Text(employee.active ? 'تعطيل' : 'تفعيل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: employee.active
                            ? AppColors.danger
                            : AppColors.success,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimary,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _toggleStatus(employee, !employee.active);
                      },
                    ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('رجوع'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(color: AppColors.secondary),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle())),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: AppScaffold(
        title: 'إدارة الموظفين',
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
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
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: AppColors.danger,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_pendingTemporaryCount',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 12,
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
                  padding: const EdgeInsets.all(16.0),
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      labelText: 'بحث بالاسم أو رقم الموظف',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
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
                                  final e = _filteredEmployees[index];
                                  return AppListItem(
                                      leading: Container(
                                        width: 44,
                                        height: 44,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary
                                              .withValues(alpha: .1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.person_outline,
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                      ),
                                      title: Text(
                                        e.fullName,
                                      ),
                                      subtitle: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${e.employeeNumber} — ${e.jobTitleName ?? "بدون مسمى"}',
                                          ),
                                          if (e.biometricEmployeeId == null ||
                                              e.biometricEmployeeId!.isEmpty)
                                            Container(
                                              margin: const EdgeInsets.only(
                                                top: 4,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: AppColors.warning
                                                    .withValues(alpha: .15),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'رقم البصمة غير محدد',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: AppColors.warning,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      trailing: AppStatusPill(
                                        label: e.active ? 'نشط' : 'معطل',
                                        color: e.active ? AppColors.success : AppColors.danger,
                                      ),
                                      onTap: () => _showMobileDetails(e),
                                  );
                                },
                              );
                            }

                            return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: SingleChildScrollView(
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(
                                    Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHighest,
                                  ),
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
                                  rows: _filteredEmployees
                                      .map(
                                        (e) => DataRow(
                                          cells: [
                                            DataCell(Text(e.fullName)),
                                            DataCell(Text(e.employeeNumber)),
                                            DataCell(Text(e.roleLabel)),
                                            DataCell(
                                              Text(
                                                e.departmentName?.isNotEmpty ==
                                                        true
                                                    ? e.departmentName!
                                                    : '-',
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                e.jobTitleName?.isNotEmpty ==
                                                        true
                                                    ? e.jobTitleName!
                                                    : '-',
                                              ),
                                            ),
                                            DataCell(
                                              Switch(
                                                value: e.active,
                                                onChanged: e.isHrAdmin
                                                    ? null
                                                    : (val) =>
                                                          _toggleStatus(e, val),
                                                activeThumbImage: null,
                                                activeTrackColor: AppColors
                                                    .success
                                                    .withValues(alpha: .4),
                                                activeThumbColor:
                                                    AppColors.success,
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                e
                                                            .biometricEmployeeId
                                                            ?.isNotEmpty ==
                                                        true
                                                    ? e.biometricEmployeeId!
                                                    : 'غير محدد',
                                              ),
                                            ),
                                            DataCell(
                                              IconButton(
                                                icon: Icon(
                                                  Icons.edit,
                                                  color: Theme.of(
                                                    context,
                                                  ).colorScheme.primary,
                                                ),
                                                tooltip: 'تعديل',
                                                onPressed: () =>
                                                    _showEditDialog(e),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
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
