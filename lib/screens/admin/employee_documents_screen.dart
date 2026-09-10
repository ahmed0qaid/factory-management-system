import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:appwrite/appwrite.dart';
import '../../models/profile_model.dart';
import '../../services/admin_service.dart';
import '../../services/appwrite_service.dart';
import '../../config/constants.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_button.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_section_header.dart';
import '../../theme/app_colors.dart';
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
  ProfileModel? _selectedEmployee;

  String _documentType = 'عقد';
  final List<String> _documentTypes = ['عقد', 'هوية', 'شهادة', 'ملف آخر'];

  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  PlatformFile? _selectedFile;
  List<dynamic> _employeeDocuments = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    setState(() => _isLoading = true);
    try {
      final emps = await _service.getEmployees(limit: 500);
      if (mounted) {
        setState(() {
          _employees = emps;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadDocuments(String employeeId) async {
    setState(() => _isLoading = true);
    try {
      final docs = await AppwriteService.tablesDB.listRows(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeDocumentsTable,
        queries: [
          Query.equal('employee_id', employeeId),
          Query.orderDesc('created_at'),
        ],
      );
      if (mounted) {
        setState(() {
          _employeeDocuments = docs.rows;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في جلب المستندات: $e')));
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
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _selectedFile = result.files.first;
        });
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في اختيار الملف: $e')));
    }
  }

  Future<void> _uploadDocument() async {
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الموظف')));
      return;
    }
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء كتابة عنوان المستند')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      String? fileId;
      String? fileName;

      if (_selectedFile != null && _selectedFile!.bytes != null) {
        final uploadedFile = await AppwriteService.storage.createFile(
          bucketId: AppConstants.employeeFilesBucket,
          fileId: ID.unique(),
          file: InputFile.fromBytes(
            bytes: _selectedFile!.bytes!,
            filename: _selectedFile!.name,
          ),
          permissions: [
            Permission.read(Role.user(_selectedEmployee!.id)),
            Permission.read(Role.team('company_main', 'hr_admin')),
            Permission.update(Role.team('company_main', 'hr_admin')),
            Permission.delete(Role.team('company_main', 'hr_admin')),
          ],
        );
        fileId = uploadedFile.$id;
        fileName = _selectedFile!.name;
      }

      await AppwriteService.tablesDB.createRow(
        databaseId: AppConstants.databaseId,
        tableId: AppConstants.employeeDocumentsTable,
        rowId: ID.unique(),
        data: {
          'company_id': _selectedEmployee!.companyId,
          'employee_id': _selectedEmployee!.id,
          'document_type': _documentType,
          'title': _titleController.text.trim(),
          'notes': _notesController.text.trim(),
          'file_id': fileId,
          'file_name': fileName,
          'uploaded_by':
              'HR Admin', // In a real app, this would be the logged in admin's name/id
          'created_at': DateTime.now().toIso8601String(),
        },
        permissions: [
          Permission.read(Role.user(_selectedEmployee!.id)),
          Permission.read(Role.team('company_main', 'hr_admin')),
          Permission.update(Role.team('company_main', 'hr_admin')),
          Permission.delete(Role.team('company_main', 'hr_admin')),
        ],
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حفظ المستند بنجاح')));
        _titleController.clear();
        _notesController.clear();
        setState(() => _selectedFile = null);
        _loadDocuments(_selectedEmployee!.id);
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'مستندات الموظفين',
      body: _isLoading && _employees.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppCard(
                        padding: const EdgeInsets.all(16),
                        child: AppDropdownField<ProfileModel>(
                          labelText: 'الموظف',
                          prefixIcon: Icons.person_outline,
                          value: _selectedEmployee,
                          items: _employees
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                    '${e.fullName} (${e.employeeNumber})',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            setState(() {
                              _selectedEmployee = val;
                              _employeeDocuments.clear();
                            });
                            if (val != null) _loadDocuments(val.id);
                          },
                        ),
                      ),
                      const SizedBox(height: 16),

                      if (_selectedEmployee != null) ...[
                        AppCard(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const AppSectionHeader(
                                title: 'إضافة مستند جديد',
                                icon: Icons.post_add_outlined,
                              ),
                              const SizedBox(height: 16),
                              AppDropdownField<String>(
                                labelText: 'نوع المستند',
                                prefixIcon: Icons.category_outlined,
                                value: _documentType,
                                items: _documentTypes
                                    .map(
                                      (t) => DropdownMenuItem(
                                        value: t,
                                        child: Text(t),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => _documentType = val!),
                              ),
                              const SizedBox(height: 16),
                              AppFormField(
                                controller: _titleController,
                                labelText: 'عنوان المستند',
                                prefixIcon: Icons.title_outlined,
                              ),
                              const SizedBox(height: 16),
                              AppFormField(
                                controller: _notesController,
                                maxLines: 2,
                                labelText: 'ملاحظات (اختياري)',
                                prefixIcon: Icons.notes_outlined,
                              ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed: _pickFile,
                                      icon: const Icon(Icons.attach_file),
                                      label: const Text('اختيار ملف'),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Text(
                                        _selectedFile != null
                                            ? _selectedFile!.name
                                            : 'لم يتم اختيار ملف',
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                              const SizedBox(height: 16),
                              AppLoadingButton(
                                onPressed: _uploadDocument,
                                text: 'حفظ ورفع المستند',
                                icon: Icons.upload_file,
                                isLoading: _isLoading,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        const AppSectionHeader(
                          title: 'مستندات الموظف الحالية:',
                          icon: Icons.folder_open_outlined,
                        ),
                        const SizedBox(height: 8),
                        if (_employeeDocuments.isEmpty)
                          const Text('لا توجد مستندات مسجلة لهذا الموظف.')
                        else
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _employeeDocuments.length,
                            itemBuilder: (context, index) {
                              final doc = _employeeDocuments[index].data;
                              return AppListItem(
                                leading: const CircleAvatar(
                                  backgroundColor: AppColors.primary,
                                  child: Icon(Icons.description_outlined, color: Colors.white),
                                ),
                                title: Text('${doc["title"]} (${doc["document_type"]})'),
                                subtitle: Text('تاريخ الرفع: ${Formatters.date(DateTime.parse(doc["created_at"]))}'),
                                trailing: doc['file_id'] != null
                                    ? IconButton(
                                        icon: const Icon(Icons.download, color: Colors.blue),
                                        tooltip: 'تحميل',
                                        onPressed: () {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(
                                              content: Text('التحميل يتطلب فتح الرابط في المتصفح، هذه الميزة برمجية حالياً.'),
                                            ),
                                          );
                                        },
                                      )
                                    : null,
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
