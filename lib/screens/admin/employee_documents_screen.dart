import 'package:appwrite/appwrite.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../config/constants.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/appwrite_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';
import '../../widgets/common/employee_picker_field.dart';

class EmployeeDocumentsScreen extends StatefulWidget {
  const EmployeeDocumentsScreen({super.key});

  @override
  State<EmployeeDocumentsScreen> createState() =>
      _EmployeeDocumentsScreenState();
}

class _EmployeeDocumentsScreenState extends State<EmployeeDocumentsScreen> {
  final AdminService _service = AdminService();
  bool _isLoading = false;
  List<ProfileModel> _employees = [];
  String? _selectedEmployeeId;

  String _documentType = 'عقد';
  final List<String> _documentTypes = ['عقد', 'هوية', 'شهادة', 'ملف آخر'];

  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  PlatformFile? _selectedFile;
  List<dynamic> _employeeDocuments = [];

  ProfileModel? get _selectedEmployee {
    final id = _selectedEmployeeId;
    if (id == null) return null;
    for (final employee in _employees) {
      if (employee.id == id) return employee;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final employees = await _service.getEmployees(limit: 500);
      if (mounted) {
        setState(() => _employees = employees.where((e) => e.active).toList());
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر تحميل الموظفين: $error')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectEmployee(String? employeeId) async {
    setState(() {
      _selectedEmployeeId = employeeId;
      _employeeDocuments = [];
      _selectedFile = null;
      _titleController.clear();
      _notesController.clear();
    });
    if (employeeId != null) await _loadDocuments(employeeId);
  }

  Future<void> _loadDocuments(String employeeId) async {
    setState(() => _isLoading = true);
    try {
      final response = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeDocumentsTable,
        queries: [
          Query.equal('employee_id', employeeId),
          Query.orderDesc('created_at'),
        ],
      );
      if (mounted) setState(() => _employeeDocuments = response.rows);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر جلب مستندات الموظف: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _selectedFile = result.files.first);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر اختيار الملف: $error')));
      }
    }
  }

  Future<void> _uploadDocument() async {
    final employee = _selectedEmployee;
    if (employee == null) {
      _message('اختر الموظف أولًا.');
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      _message('اكتب عنوان المستند.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? fileId;
      String? fileName;

      if (_selectedFile?.bytes != null) {
        final uploaded = await AppwriteService.storage.createFile(
          bucketId: AppConstants.employeeFilesBucket,
          fileId: ID.unique(),
          file: InputFile.fromBytes(
            bytes: _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ),
          permissions: [
            Permission.read(Role.user(employee.id)),
            Permission.read(Role.team('company_main', 'hr_admin')),
            Permission.update(Role.team('company_main', 'hr_admin')),
            Permission.delete(Role.team('company_main', 'hr_admin')),
          ],
        );
        fileId = uploaded.$id;
        fileName = _selectedFile!.name;
      }

      await AppwriteService.tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeDocumentsTable,
        rowId: ID.unique(),
        data: {
          'company_id': employee.companyId,
          'employee_id': employee.id,
          'document_type': _documentType,
          'title': _titleController.text.trim(),
          'notes': _notesController.text.trim(),
          'file_id': fileId,
          'file_name': fileName,
          'uploaded_by': 'hr_admin',
          'created_at': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.user(employee.id)),
          Permission.read(Role.team('company_main', 'hr_admin')),
          Permission.update(Role.team('company_main', 'hr_admin')),
          Permission.delete(Role.team('company_main', 'hr_admin')),
        ],
      );

      if (!mounted) return;
      _titleController.clear();
      _notesController.clear();
      setState(() => _selectedFile = null);
      _message('تم حفظ المستند بنجاح.');
      await _loadDocuments(employee.id);
    } catch (error) {
      _message('تعذر حفظ المستند: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final employee = _selectedEmployee;

    return AppScaffold(
      title: 'مستندات الموظفين',
      body: _isLoading && _employees.isEmpty
          ? const AppLoadingState(label: 'جاري تحميل الموظفين')
          : Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  children: [
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const AppSectionHeader(
                            title: 'اختيار الموظف',
                            icon: Icons.person_search_outlined,
                          ),
                          const SizedBox(height: 12),
                          EmployeePickerField(
                            employees: _employees,
                            selectedEmployeeId: _selectedEmployeeId,
                            onChanged: _selectEmployee,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (employee == null)
                      const AppEmptyState(
                        title: 'اختر موظفًا',
                        message: 'اختر موظفًا لعرض ملفاته وإضافة مستند جديد.',
                        icon: Icons.folder_shared_outlined,
                      )
                    else ...[
                      AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: scheme.primaryContainer,
                                  foregroundColor: scheme.onPrimaryContainer,
                                  child: Text(
                                    employee.fullName.isEmpty
                                        ? 'م'
                                        : employee.fullName[0],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        employee.fullName,
                                        style: theme.textTheme.titleSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      Text(
                                        '${employee.employeeNumber}${employee.departmentName?.trim().isNotEmpty == true ? ' • ${employee.departmentName}' : ''}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            const AppSectionHeader(
                              title: 'إضافة مستند جديد',
                              icon: Icons.post_add_outlined,
                            ),
                            const SizedBox(height: 12),
                            AppDropdownField<String>(
                              labelText: 'نوع المستند',
                              prefixIcon: Icons.category_outlined,
                              value: _documentType,
                              items: _documentTypes
                                  .map(
                                    (type) => DropdownMenuItem(
                                      value: type,
                                      child: Text(type),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _documentType = value);
                                }
                              },
                            ),
                            const SizedBox(height: 14),
                            AppFormField(
                              controller: _titleController,
                              labelText: 'عنوان المستند',
                              prefixIcon: Icons.title_outlined,
                              textInputAction: TextInputAction.next,
                            ),
                            const SizedBox(height: 14),
                            AppFormField(
                              controller: _notesController,
                              maxLines: 2,
                              labelText: 'ملاحظات (اختياري)',
                              prefixIcon: Icons.notes_outlined,
                            ),
                            const SizedBox(height: 14),
                            OutlinedButton.icon(
                              onPressed: _isLoading ? null : _pickFile,
                              icon: const Icon(Icons.attach_file),
                              label: Text(
                                _selectedFile == null
                                    ? 'إرفاق ملف (اختياري)'
                                    : _selectedFile!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(height: 16),
                            AppLoadingButton(
                              onPressed: _uploadDocument,
                              text: 'حفظ المستند',
                              icon: Icons.upload_file_outlined,
                              isLoading: _isLoading,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'مستندات الموظف',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            '${_employeeDocuments.length} مستند',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (_isLoading)
                        const AppLoadingState(
                          label: 'جاري تحميل المستندات',
                          fallbackHeight: 140,
                        )
                      else if (_employeeDocuments.isEmpty)
                        const AppEmptyState(
                          title: 'لا توجد مستندات',
                          message: 'لم يتم تسجيل مستندات لهذا الموظف حتى الآن.',
                          icon: Icons.description_outlined,
                        )
                      else
                        ..._employeeDocuments.map((row) {
                          final data = row.data;
                          final createdAt = DateTime.tryParse(
                            data['created_at']?.toString() ?? '',
                          );
                          final hasFile = data['file_id'] != null;
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: scheme.surfaceContainerHighest,
                                foregroundColor: scheme.onSurfaceVariant,
                                child: const Icon(Icons.description_outlined),
                              ),
                              title: Text(
                                '${data['title'] ?? 'مستند'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                '${data['document_type'] ?? '-'} • ${Formatters.date(createdAt)}${data['file_name'] != null ? '\n${data['file_name']}' : ''}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: hasFile
                                  ? const Tooltip(
                                      message: 'يوجد ملف مرفق',
                                      child: Icon(Icons.attach_file),
                                    )
                                  : null,
                            ),
                          );
                        }),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}
