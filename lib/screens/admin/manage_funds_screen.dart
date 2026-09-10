import 'package:flutter/material.dart';
import '../../models/fund_model.dart';
import '../../models/profile_model.dart';
import '../../services/fund_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_dropdown_field.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_scaffold.dart';
import 'fund_details_screen.dart';

class ManageFundsScreen extends StatefulWidget {
  final ProfileModel currentProfile;
  const ManageFundsScreen({super.key, required this.currentProfile});

  @override
  State<ManageFundsScreen> createState() => _ManageFundsScreenState();
}

class _ManageFundsScreenState extends State<ManageFundsScreen> {
  final _service = FundService();
  List<FundModel> _funds = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadFunds();
  }

  Future<void> _loadFunds() async {
    setState(() => _loading = true);
    try {
      final funds = await _service.getFunds();
      if (mounted) {
        setState(() {
          _funds = funds;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  void _showCreateDialog() {
    final nameCtrl = TextEditingController();
    String type = 'local'; // local, bank, wallet

    AppFormDialog.show(
      context,
      title: 'إضافة صندوق جديد',
      submitText: 'حفظ',
      onSubmit: () async {
        if (nameCtrl.text.trim().isEmpty) return false;
        try {
          await _service.createFund(nameCtrl.text.trim(), type);
          _loadFunds();
          return true;
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString())),
            );
          }
          return false;
        }
      },
      builder: (dialogContext, setDialogState) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppFormField(
              controller: nameCtrl,
              labelText: 'اسم الصندوق',
            ),
            const SizedBox(height: 16),
            AppDropdownField<String>(
              value: type,
              labelText: 'النوع',
              items: const [
                DropdownMenuItem(value: 'local', child: Text('صندوق محلي (نقد)')),
                DropdownMenuItem(value: 'bank', child: Text('حساب بنكي')),
                DropdownMenuItem(value: 'wallet', child: Text('محفظة إلكترونية')),
              ],
              onChanged: (val) {
                if (val != null) setDialogState(() => type = val);
              },
            ),
          ],
        );
      },
    );
  }

  IconData _getIcon(String type) {
    switch (type) {
      case 'bank':
        return Icons.account_balance;
      case 'wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.money;
    }
  }

  String _getTypeLabel(String type) {
    switch (type) {
      case 'bank':
        return 'حساب بنكي';
      case 'wallet':
        return 'محفظة إلكترونية';
      default:
        return 'صندوق محلي';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'إدارة الصناديق',
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateDialog,
        icon: const Icon(Icons.add),
        label: const Text('صندوق جديد'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _funds.isEmpty
              ? const Center(child: Text('لا توجد صناديق، قم بإضافة صندوق جديد'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _funds.length,
                  itemBuilder: (context, index) {
                    final fund = _funds[index];
                    return AppListItem(
                      leading: CircleAvatar(
                        child: Icon(_getIcon(fund.type)),
                      ),
                      title: Text(fund.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(_getTypeLabel(fund.type)),
                      trailing: Text(
                        Formatters.money(fund.balance),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: fund.balance >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => FundDetailsScreen(
                              fund: fund,
                              currentProfile: widget.currentProfile,
                            ),
                          ),
                        ).then((_) => _loadFunds());
                      },
                    );
                  },
                ),
    );
  }
}
