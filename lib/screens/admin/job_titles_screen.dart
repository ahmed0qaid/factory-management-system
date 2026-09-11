import 'package:flutter/material.dart';
import '../../models/job_title_model.dart';
import '../../services/job_title_service.dart';
import '../../theme/app_colors.dart';

import '../../models/profile_model.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
import '../../widgets/common/app_scaffold.dart';
import '../../widgets/common/app_status_pill.dart';

class JobTitlesScreen extends StatefulWidget {
  final ProfileModel currentProfile;
  const JobTitlesScreen({super.key, required this.currentProfile});

  @override
  State<JobTitlesScreen> createState() => _JobTitlesScreenState();
}

class _JobTitlesScreenState extends State<JobTitlesScreen> {
  final JobTitleService _jobTitleService = JobTitleService();
  List<JobTitleModel> _jobTitles = [];
  bool _isLoading = true;
  String? _companyId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profile = widget.currentProfile;
      _companyId = profile.companyId;
      _jobTitles = await _jobTitleService.getJobTitles(
        companyId: _companyId!,
        activeOnly: false, // Show all in admin
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showAddEditDialog([JobTitleModel? jobTitle]) {
    final nameController = TextEditingController(text: jobTitle?.name ?? '');
    bool isActive = jobTitle?.active ?? true;

    AppFormDialog.show(
      context,
      title: jobTitle == null ? 'إضافة مسمى وظيفي' : 'تعديل المسمى الوظيفي',
      submitText: 'حفظ',
      onSubmit: () async {
        final name = nameController.text.trim();
        if (name.isEmpty) return false;

        setState(() => _isLoading = true);

        try {
          if (jobTitle == null) {
            await _jobTitleService.createJobTitle(
              companyId: _companyId!,
              name: name,
            );
          } else {
            await _jobTitleService.updateJobTitle(
              id: jobTitle.id,
              name: name,
              active: isActive,
            );
          }
          _loadData();
          return true;
        } catch (e) {
          if (mounted) {
            setState(() => _isLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('خطأ: $e')),
            );
          }
          return false;
        }
      },
      builder: (context, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppFormField(
              controller: nameController,
              labelText: 'اسم المسمى الوظيفي',
              prefixIcon: Icons.badge_outlined,
            ),
            if (jobTitle != null) ...[
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('مفعل'),
                value: isActive,
                onChanged: (val) => setDialogState(() => isActive = val),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        );
      },
    );
  }

  void _confirmDeactivate(JobTitleModel jobTitle) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'تعطيل المسمى الوظيفي',
      content:
          'هل أنت متأكد من تعطيل "${jobTitle.name}"؟ لن يظهر هذا المسمى في قوائم اختيار الموظفين الجدد.',
      confirmText: 'تعطيل',
      isDestructive: true,
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _jobTitleService.deactivateJobTitle(jobTitle.id);
        _loadData();
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')),
          );
        }
      }
    }
  }

  void _confirmDelete(JobTitleModel jobTitle) async {
    final confirmed = await AppConfirmDialog.show(
      context,
      title: 'حذف المسمى الوظيفي',
      content:
          'هل أنت متأكد من حذف "${jobTitle.name}" نهائياً؟ لا يمكن التراجع عن هذا الإجراء.',
      confirmText: 'حذف',
      isDestructive: true,
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      try {
        await _jobTitleService.deleteJobTitle(jobTitle.id);
        _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المسمى الوظيفي بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'.replaceAll('Exception: ', ''))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'المسميات الوظيفية',
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddEditDialog(),
        child: const Icon(Icons.add),
      ),
      body: _isLoading
          ? const AppLoadingState(label: 'جاري تحميل المسميات الوظيفية')
          : _jobTitles.isEmpty
              ? const AppEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'لا توجد مسميات وظيفية',
                  message: 'قم بإضافة مسميات وظيفية جديدة للشركة',
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _jobTitles.length,
                  itemBuilder: (context, index) {
                    final jobTitle = _jobTitles[index];
                    return AppListItem(
                      title: Text(
                        jobTitle.name,
                        style: TextStyle(
                          decoration:
                              jobTitle.active ? null : TextDecoration.lineThrough,
                          color: jobTitle.active
                              ? AppColors.textPrimary
                              : Colors.grey,
                        ),
                      ),
                      subtitle: jobTitle.active
                          ? AppStatusPill.success('مفعل')
                          : AppStatusPill.danger('معطل'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.edit,
                              color: AppColors.primary,
                            ),
                            tooltip: 'تعديل',
                            onPressed: () => _showAddEditDialog(jobTitle),
                          ),
                          if (jobTitle.active)
                            IconButton(
                              icon: const Icon(
                                Icons.block,
                                color: Colors.orange,
                              ),
                              tooltip: 'تعطيل',
                              onPressed: () => _confirmDeactivate(jobTitle),
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            tooltip: 'حذف',
                            onPressed: () => _confirmDelete(jobTitle),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
