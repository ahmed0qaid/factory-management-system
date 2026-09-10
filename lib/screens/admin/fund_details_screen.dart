import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/fund_model.dart';
import '../../models/fund_transaction_model.dart';
import '../../models/profile_model.dart';
import '../../services/fund_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_scaffold.dart';

class FundDetailsScreen extends StatefulWidget {
  final FundModel fund;
  final ProfileModel currentProfile;

  const FundDetailsScreen({
    super.key,
    required this.fund,
    required this.currentProfile,
  });

  @override
  State<FundDetailsScreen> createState() => _FundDetailsScreenState();
}

class _FundDetailsScreenState extends State<FundDetailsScreen> {
  final _service = FundService();
  List<FundTransactionModel> _transactions = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() => _loading = true);
    try {
      final txs = await _service.getTransactions(widget.fund.id);
      if (mounted) {
        setState(() {
          _transactions = txs;
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

  void _showAddTransactionDialog(String type) {
    final amountCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    AppFormDialog.show(
      context,
      title: type == 'in' ? 'إيداع نقدي' : 'سحب / صرف',
      submitText: 'حفظ',
      onSubmit: () async {
        final amount = double.tryParse(amountCtrl.text.trim());
        if (amount == null || amount <= 0) return false;
        if (descCtrl.text.trim().isEmpty) return false;

        try {
          await _service.addTransaction(
            fundId: widget.fund.id,
            type: type,
            amount: amount,
            description: descCtrl.text.trim(),
            createdBy: widget.currentProfile.id,
          );
          _loadTransactions();
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
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              labelText: 'المبلغ',
            ),
            const SizedBox(height: 16),
            AppFormField(
              controller: descCtrl,
              labelText: 'البيان / الوصف',
            ),
          ],
        );
      },
    );
  }

  Future<void> _closeMovement() async {
    final confirm = await AppConfirmDialog.show(
      context,
      title: 'تصفية الحركة اليومية',
      content: 'هل أنت متأكد من تصفية حركة الصندوق وفتح حركة ليوم جديد؟ لا يمكن التراجع عن هذه الخطوة.',
      confirmText: 'تصفية وإغلاق',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await _service.closeDailyMovement(widget.fund.id, widget.currentProfile.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت تصفية حركة الصندوق بنجاح')),
        );
        _loadTransactions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // We calculate a running balance assuming the latest transaction is first.
    // However, the DB stores the current total balance in widget.fund.balance.
    // For proper running balance, we'd iterate backwards, but for now we just show list.
    
    return AppScaffold(
      title: widget.fund.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.done_all),
          tooltip: 'تصفية الحركة اليومية',
          onPressed: _closeMovement,
        )
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: AppCard(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الرصيد الحالي:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(
                    Formatters.money(widget.fund.balance),
                    style: TextStyle(
                      fontSize: 20, 
                      fontWeight: FontWeight.bold, 
                      color: Theme.of(context).colorScheme.primary
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade100,
                      foregroundColor: Colors.green.shade900,
                      elevation: 0,
                    ),
                    onPressed: () => _showAddTransactionDialog('in'),
                    icon: const Icon(Icons.arrow_downward),
                    label: const Text('إيداع (وارد)'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade100,
                      foregroundColor: Colors.red.shade900,
                      elevation: 0,
                    ),
                    onPressed: () => _showAddTransactionDialog('out'),
                    icon: const Icon(Icons.arrow_upward),
                    label: const Text('سحب (منصرف)'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _transactions.isEmpty
                    ? const Center(child: Text('لا توجد حركات مسجلة'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _transactions.length,
                        itemBuilder: (context, index) {
                          final tx = _transactions[index];
                          final isIn = tx.type == 'in';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppListItem(
                              leading: CircleAvatar(
                                backgroundColor: isIn ? Colors.green.shade100 : Colors.red.shade100,
                                child: Icon(
                                  isIn ? Icons.arrow_downward : Icons.arrow_upward,
                                  color: isIn ? Colors.green.shade900 : Colors.red.shade900,
                                ),
                              ),
                            title: Text(tx.description),
                            subtitle: Text(DateFormat('yyyy/MM/dd HH:mm').format(tx.date)),
                            trailing: Text(
                              (isIn ? '+' : '-') + Formatters.money(tx.amount),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isIn ? Colors.green : Colors.red,
                              ),
                            ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
