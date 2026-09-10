import 'package:flutter/material.dart';

import '../../models/profile_model.dart';

/// Reusable searchable employee picker.
///
/// On compact and desktop layouts the field stays small in the form, while the
/// actual employee directory opens in a searchable bottom sheet. This scales
/// better than a long DropdownButton when the company has many employees.
class EmployeePickerField extends StatelessWidget {
  final List<ProfileModel> employees;
  final String? selectedEmployeeId;
  final ValueChanged<String?> onChanged;
  final bool allowAll;
  final String labelText;
  final String allEmployeesLabel;
  final bool enabled;

  const EmployeePickerField({
    super.key,
    required this.employees,
    required this.selectedEmployeeId,
    required this.onChanged,
    this.allowAll = false,
    this.labelText = 'الموظف',
    this.allEmployeesLabel = 'كل الموظفين',
    this.enabled = true,
  });

  ProfileModel? get _selectedEmployee {
    final id = selectedEmployeeId;
    if (id == null) return null;
    for (final employee in employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedEmployee;
    final primaryText = selected == null
        ? (allowAll ? allEmployeesLabel : 'اختر موظفًا')
        : selected.fullName;
    final secondaryText = selected == null
        ? (allowAll ? 'بدون تصفية حسب الموظف' : 'ابحث بالاسم أو الرقم الوظيفي')
        : _employeeMeta(selected);

    return InkWell(
      onTap: enabled ? () => _openPicker(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: labelText,
          border: const OutlineInputBorder(),
          enabled: enabled,
          prefixIcon: const Icon(Icons.person_search_outlined),
          suffixIcon: const Icon(Icons.keyboard_arrow_down),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              primaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 2),
            Text(
              secondaryText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final selected = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _EmployeePickerSheet(
        employees: employees,
        selectedEmployeeId: selectedEmployeeId,
        allowAll: allowAll,
        allEmployeesLabel: allEmployeesLabel,
      ),
    );

    // null is both the dismiss result and the "all employees" value, so the
    // sheet returns a sentinel for that explicit option.
    if (!context.mounted || selected == null) return;
    onChanged(selected == _EmployeePickerSheet.allSentinel ? null : selected);
  }

  static String _employeeMeta(ProfileModel employee) {
    final parts = <String>[employee.employeeNumber];
    if (employee.jobTitleName?.trim().isNotEmpty == true) {
      parts.add(employee.jobTitleName!.trim());
    }
    if (employee.departmentName?.trim().isNotEmpty == true) {
      parts.add(employee.departmentName!.trim());
    }
    return parts.join(' • ');
  }
}

class _EmployeePickerSheet extends StatefulWidget {
  static const allSentinel = '__ALL_EMPLOYEES__';

  final List<ProfileModel> employees;
  final String? selectedEmployeeId;
  final bool allowAll;
  final String allEmployeesLabel;

  const _EmployeePickerSheet({
    required this.employees,
    required this.selectedEmployeeId,
    required this.allowAll,
    required this.allEmployeesLabel,
  });

  @override
  State<_EmployeePickerSheet> createState() => _EmployeePickerSheetState();
}

class _EmployeePickerSheetState extends State<_EmployeePickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ProfileModel> get _filteredEmployees {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return widget.employees;
    return widget.employees.where((employee) {
      final searchable = [
        employee.fullName,
        employee.employeeNumber,
        employee.jobTitleName ?? '',
        employee.departmentName ?? '',
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final results = _filteredEmployees;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: FractionallySizedBox(
        heightFactor: height < 620 ? .92 : .78,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'اختيار الموظف',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'إغلاق',
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: 'ابحث بالاسم أو الرقم الوظيفي أو القسم...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'مسح البحث',
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _query = '');
                              },
                              icon: const Icon(Icons.close),
                            ),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.allowAll)
                  ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.groups_outlined),
                    ),
                    title: Text(widget.allEmployeesLabel),
                    subtitle: const Text('عرض التقرير لجميع الموظفين'),
                    trailing: widget.selectedEmployeeId == null
                        ? const Icon(Icons.check_circle)
                        : null,
                    onTap: () => Navigator.pop(
                      context,
                      _EmployeePickerSheet.allSentinel,
                    ),
                  ),
                if (widget.allowAll) const Divider(height: 1),
                Expanded(
                  child: results.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text('لا يوجد موظف مطابق لعملية البحث.'),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          itemCount: results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final employee = results[index];
                            final selected =
                                employee.id == widget.selectedEmployeeId;
                            final trimmedName = employee.fullName.trim();
                            return ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  trimmedName.isEmpty ? 'م' : trimmedName[0],
                                ),
                              ),
                              title: Text(
                                employee.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                EmployeePickerField._employeeMeta(employee),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: selected
                                  ? const Icon(Icons.check_circle)
                                  : const Icon(Icons.chevron_left),
                              onTap: () => Navigator.pop(context, employee.id),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
