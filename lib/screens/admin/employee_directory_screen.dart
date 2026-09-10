import 'package:flutter/material.dart';

import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class EmployeeDirectoryScreen extends StatefulWidget {
  const EmployeeDirectoryScreen({super.key});

  @override
  State<EmployeeDirectoryScreen> createState() => _EmployeeDirectoryScreenState();
}

class _EmployeeDirectoryScreenState extends State<EmployeeDirectoryScreen> {
  final _service = AdminService();
  final _searchController = TextEditingController();
  late Future<List<ProfileModel>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _future = _service.getEmployees(limit: 500);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _reload() => setState(() => _future = _service.getEmployees(limit: 500));

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'دليل الموظفين',
      body: FutureBuilder<List<ProfileModel>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData && !snapshot.hasError) {
            return const AppLoadingState(label: 'جاري تحميل الموظفين');
          }
          if (snapshot.hasError) {
            return Center(
              child: FilledButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
              ),
            );
          }

          final all = snapshot.data ?? const <ProfileModel>[];
          final query = _query.trim().toLowerCase();
          final employees = query.isEmpty
              ? all
              : all.where((employee) {
                  final searchable = [
                    employee.fullName,
                    employee.employeeNumber,
                    employee.departmentName ?? '',
                    employee.jobTitleName ?? '',
                    employee.roleLabel,
                  ].join(' ').toLowerCase();
                  return searchable.contains(query);
                }).toList();

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (value) => setState(() => _query = value),
                      decoration: InputDecoration(
                        hintText: 'ابحث بالاسم أو الرقم أو القسم أو المسمى...',
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
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Text('${employees.length} موظف'),
                    ),
                  ),
                  Expanded(
                    child: employees.isEmpty
                        ? const AppEmptyState(
                            title: 'لا توجد نتائج',
                            message: 'لم يتم العثور على موظف مطابق للبحث.',
                            icon: Icons.person_search_outlined,
                          )
                        : ListView.separated(
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                            itemCount: employees.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (context, index) {
                              final employee = employees[index];
                              final details = <String>[
                                employee.employeeNumber,
                                if (employee.jobTitleName?.trim().isNotEmpty == true)
                                  employee.jobTitleName!.trim(),
                                if (employee.departmentName?.trim().isNotEmpty == true)
                                  employee.departmentName!.trim(),
                              ].join(' • ');
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(
                                    child: Text(
                                      employee.fullName.isEmpty ? 'م' : employee.fullName[0],
                                    ),
                                  ),
                                  title: Text(
                                    employee.fullName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    details,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: AppStatusPill(
                                    label: employee.active ? employee.roleLabel : 'موقوف',
                                    color: employee.active
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context).colorScheme.error,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
