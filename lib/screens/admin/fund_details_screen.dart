import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/fund_model.dart';
import '../../models/fund_transaction_model.dart';
import '../../models/profile_model.dart';
import '../../services/fund_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/app_confirm_dialog.dart';
import '../../widgets/common/app_empty_state.dart';
import '../../widgets/common/app_form_dialog.dart';
import '../../widgets/common/app_form_field.dart';
import '../../widgets/common/app_list_item.dart';
import '../../widgets/common/app_loading_state.dart';
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
              prefixIcon: Icons.payments_outlined,
            ),
            const SizedBox(height: 16),
            AppFormField(
              controller: descCtrl,
              labelText: 'البيان / الوصف',
              prefixIcon: Icons.notes_outlined,
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
      content:
          'هل أنت متأكد من تصفية حركة الصندوق وفتح حركة ليوم جديد؟ لا يمكن التراجع عن هذه الخطوة.',
      confirmText: 'تصفية وإغلاق',
      isDestructive: true,
    );

    if (confirm != true) return;

    try {
      await _service.closeDailyMovement(
        widget.fund.id,
        widget.currentProfile.id,
      );
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final negativeBalance = widget.fund.balance < 0;

    return AppScaffold(
      title: widget.fund.name,
      actions: [
        IconButton(
          icon: const Icon(Icons.done_all),
          tooltip: 'تصفية الحركة اليومية',
          onPressed: _closeMovement,
        ),
      ],
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: AppCard(
                  elevated: true,
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_outlined,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'الرصيد الحالي',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              Formatters.money(widget.fund.balance),
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: negativeBalance
                                    ? scheme.error
                                    : scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _showAddTransactionDialog('in'),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('إيداع (وارد)'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: scheme.error,
                          side: BorderSide(
                            color: scheme.error.withValues(alpha: .55),
                          ),
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
                    ? const AppLoadingState(label: 'جاري تحميل الحركات')
                    : _transactions.isEmpty
                        ? const AppEmptyState(
                            title: 'لا توجد حركات',
                            message: 'لم يتم تسجيل حركات مالية في هذا الصندوق بعد.',
                            icon: Icons.receipt_long_outlined,
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _transactions.length,
                            itemBuilder: (context, index) {
                              final tx = _transactions[index];
                              final isIn = tx.type == 'in';
                              final accent = isIn ? scheme.primary : scheme.error;
                              final background = isIn
                                  ? scheme.primaryContainer
                                  : scheme.errorContainer;
                              final foreground = isIn
                                  ? scheme.onPrimaryContainer
                                  : scheme.onErrorContainer;
                              return AppListItem(
                                leading: CircleAvatar(
                                  backgroundColor: background,
                                  foregroundColor: foreground,
                                  child: Icon(
                                    isIn
                                        ? Icons.arrow_downward
                                        : Icons.arrow_upward,
                                  ),
                                ),
                                title: Text(tx.description),
                                subtitle: Text(
                                  DateFormat('yyyy/MM/dd HH:mm').format(tx.date),
                                ),
                                trailing: Text(
                                  '${isIn ? '+' : '-'}${Formatters.money(tx.amount)}',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: accent,
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
