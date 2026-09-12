import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Reusable inline employee search and selection control.
///
/// The employee list stays in the current screen. Typing in the search field
/// filters the visible employees immediately, so no bottom sheet or extra
/// selection step is required.
class EmployeePickerField extends StatefulWidget {
  final List<ProfileModel> employees;
  final String? selectedEmployeeId;
  final ValueChanged<String?> onChanged;
  final bool allowAll;
  final String labelText;
  final String allEmployeesLabel;
  final bool enabled;
  final double maxResultsHeight;

  const EmployeePickerField({
    super.key,
    required this.employees,
    required this.selectedEmployeeId,
    required this.onChanged,
    this.allowAll = false,
    this.labelText = 'الموظف',
    this.allEmployeesLabel = 'كل الموظفين',
    this.enabled = true,
    this.maxResultsHeight = 320,
  });

  static String employeeMeta(ProfileModel employee) {
    final parts = <String>[employee.employeeNumber];
    if (employee.jobTitleName?.trim().isNotEmpty == true) {
      parts.add(employee.jobTitleName!.trim());
    }
    if (employee.departmentName?.trim().isNotEmpty == true) {
      parts.add(employee.departmentName!.trim());
    }
    return parts.join(' • ');
  }

  @override
  State<EmployeePickerField> createState() => _EmployeePickerFieldState();
}

class _EmployeePickerFieldState extends State<EmployeePickerField> {
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
        employee.roleLabel,
      ].join(' ').toLowerCase();
      return searchable.contains(query);
    }).toList();
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  void _selectEmployee(ProfileModel employee) {
    if (!widget.enabled) return;
    widget.onChanged(employee.id);
    FocusScope.of(context).unfocus();
  }

  void _selectAll() {
    if (!widget.enabled) return;
    widget.onChanged(null);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final results = _filteredEmployees;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _searchController,
          enabled: widget.enabled,
          textInputAction: TextInputAction.search,
          onChanged: (value) => setState(() => _query = value),
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: 'ابحث بالاسم أو الرقم الوظيفي أو القسم أو المسمى...',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'مسح البحث',
                    onPressed: widget.enabled ? _clearSearch : null,
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Text(
                _query.trim().isEmpty
                    ? '${widget.employees.length} موظف'
                    : '${results.length} نتيجة من ${widget.employees.length}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (widget.selectedEmployeeId != null)
              TextButton.icon(
                onPressed: widget.enabled
                    ? () {
                        widget.onChanged(null);
                        _clearSearch();
                      }
                    : null,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('إلغاء التحديد'),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        Container(
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: AppRadius.card,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: widget.maxResultsHeight),
            child: _buildResults(context, results),
          ),
        ),
      ],
    );
  }

  Widget _buildResults(
    BuildContext context,
    List<ProfileModel> results,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final showAllOption = widget.allowAll && _query.trim().isEmpty;
    final itemCount = results.length + (showAllOption ? 1 : 0);

    if (itemCount == 0) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.person_search_outlined,
              size: 34,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'لا يوجد موظف مطابق للبحث',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              'جرّب الاسم أو الرقم الوظيفي أو القسم أو المسمى.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      itemCount: itemCount,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: AppSpacing.md,
        endIndent: AppSpacing.md,
        color: scheme.outlineVariant.withValues(alpha: .7),
      ),
      itemBuilder: (context, index) {
        if (showAllOption && index == 0) {
          final selected = widget.selectedEmployeeId == null;
          return ListTile(
            enabled: widget.enabled,
            selected: selected,
            selectedTileColor: scheme.primaryContainer.withValues(alpha: .45),
            leading: CircleAvatar(
              backgroundColor: selected
                  ? scheme.primaryContainer
                  : scheme.secondaryContainer,
              foregroundColor: selected
                  ? scheme.onPrimaryContainer
                  : scheme.onSecondaryContainer,
              child: const Icon(Icons.groups_outlined),
            ),
            title: Text(widget.allEmployeesLabel),
            subtitle: const Text('بدون تصفية حسب موظف محدد'),
            trailing: selected
                ? Icon(Icons.check_circle_rounded, color: scheme.primary)
                : null,
            onTap: _selectAll,
          );
        }

        final employeeIndex = showAllOption ? index - 1 : index;
        final employee = results[employeeIndex];
        final selected = employee.id == widget.selectedEmployeeId;
        final trimmedName = employee.fullName.trim();

        return ListTile(
          enabled: widget.enabled,
          selected: selected,
          selectedTileColor: scheme.primaryContainer.withValues(alpha: .45),
          leading: CircleAvatar(
            backgroundColor: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            foregroundColor: selected
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
            child: Text(trimmedName.isEmpty ? 'م' : trimmedName[0]),
          ),
          title: Text(
            employee.fullName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: selected
                ? theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  )
                : null,
          ),
          subtitle: Text(
            EmployeePickerField.employeeMeta(employee),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : null,
          onTap: () => _selectEmployee(employee),
        );
      },
    );
  }
}
