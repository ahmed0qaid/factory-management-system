import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'app_empty_state.dart';

/// Reusable searchable employee picker.
///
/// The form keeps a compact selected-value field, while the actual directory
/// opens in a searchable bottom sheet. This scales better than a long dropdown
/// when the company has many employees.
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final selected = _selectedEmployee;
    final primaryText = selected == null
        ? (allowAll ? allEmployeesLabel : 'اختر موظفًا')
        : selected.fullName;
    final secondaryText = selected == null
        ? (allowAll ? 'بدون تصفية حسب الموظف' : 'ابحث بالاسم أو الرقم الوظيفي')
        : _employeeMeta(selected);

    return Semantics(
      button: true,
      enabled: enabled,
      label: '$labelText: $primaryText',
      child: InkWell(
        onTap: enabled ? () => _openPicker(context) : null,
        borderRadius: AppRadius.control,
        child: InputDecorator(
          isEmpty: selected == null && !allowAll,
          decoration: InputDecoration(
            labelText: labelText,
            enabled: enabled,
            prefixIcon: const Icon(Icons.person_search_outlined),
            suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                primaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: enabled ? scheme.onSurface : scheme.onSurfaceVariant,
                  fontWeight: selected == null
                      ? FontWeight.w500
                      : FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                secondaryText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final height = MediaQuery.sizeOf(context).height;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final results = _filteredEmployees;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

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
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(
                      top: AppSpacing.sm,
                      bottom: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsetsDirectional.fromSTEB(
                    AppSpacing.md,
                    AppSpacing.xs,
                    AppSpacing.xs,
                    AppSpacing.sm,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'اختيار الموظف',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${results.length} من ${widget.employees.length} موظف',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  child: TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
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
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (widget.allowAll) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: scheme.secondaryContainer,
                        foregroundColor: scheme.onSecondaryContainer,
                        child: const Icon(Icons.groups_outlined),
                      ),
                      title: Text(widget.allEmployeesLabel),
                      subtitle: const Text('عرض التقرير لجميع الموظفين'),
                      trailing: widget.selectedEmployeeId == null
                          ? Icon(Icons.check_circle, color: scheme.primary)
                          : Icon(
                              isRtl ? Icons.chevron_left : Icons.chevron_right,
                              color: scheme.onSurfaceVariant,
                            ),
                      selected: widget.selectedEmployeeId == null,
                      selectedTileColor: scheme.primaryContainer.withValues(
                        alpha: .45,
                      ),
                      onTap: () => Navigator.pop(
                        context,
                        _EmployeePickerSheet.allSentinel,
                      ),
                    ),
                  ),
                  const Divider(height: AppSpacing.md),
                ],
                Expanded(
                  child: results.isEmpty
                      ? const AppEmptyState(
                          title: 'لا توجد نتائج',
                          message: 'جرّب البحث باسم آخر أو بالرقم الوظيفي.',
                          icon: Icons.person_search_outlined,
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.sm,
                            0,
                            AppSpacing.sm,
                            AppSpacing.md,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.xxs),
                          itemBuilder: (context, index) {
                            final employee = results[index];
                            final selected =
                                employee.id == widget.selectedEmployeeId;
                            final trimmedName = employee.fullName.trim();
                            return ListTile(
                              selected: selected,
                              selectedTileColor: scheme.primaryContainer
                                  .withValues(alpha: .45),
                              leading: CircleAvatar(
                                backgroundColor: selected
                                    ? scheme.primaryContainer
                                    : scheme.surfaceContainerHighest,
                                foregroundColor: selected
                                    ? scheme.onPrimaryContainer
                                    : scheme.onSurfaceVariant,
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
                                  ? Icon(
                                      Icons.check_circle,
                                      color: scheme.primary,
                                    )
                                  : Icon(
                                      isRtl
                                          ? Icons.chevron_left
                                          : Icons.chevron_right,
                                      color: scheme.onSurfaceVariant,
                                    ),
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
