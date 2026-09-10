import 'package:flutter/material.dart';

class PaginationControls extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int itemsPerPage;
  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onItemsPerPageChanged;

  const PaginationControls({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.itemsPerPage,
    required this.onPageChanged,
    required this.onItemsPerPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final totalPages = (totalItems / itemsPerPage).ceil();
    final startItem = totalItems == 0
        ? 0
        : (currentPage - 1) * itemsPerPage + 1;
    final endItem = (currentPage * itemsPerPage > totalItems)
        ? totalItems
        : (currentPage * itemsPerPage);
    final scheme = Theme.of(context).colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 16,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('عدد السجلات في الصفحة:'),
              const SizedBox(width: 8),
              DropdownButton<int>(
                value: itemsPerPage,
                items: const [
                  DropdownMenuItem(value: 10, child: Text('10')),
                  DropdownMenuItem(value: 25, child: Text('25')),
                  DropdownMenuItem(value: 50, child: Text('50')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    onItemsPerPageChanged(val);
                  }
                },
                underline: const SizedBox(),
              ),
            ],
          ),

          Text(
            totalItems == 0
                ? 'لا توجد سجلات'
                : 'عرض $startItem - $endItem من إجمالي $totalItems',
            style: const TextStyle(),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(isRtl ? Icons.chevron_right : Icons.chevron_left),
                onPressed: currentPage > 1
                    ? () => onPageChanged(currentPage - 1)
                    : null,
                tooltip: 'السابق',
              ),
              Text('$currentPage / ${totalPages == 0 ? 1 : totalPages}'),
              IconButton(
                icon: Icon(isRtl ? Icons.chevron_left : Icons.chevron_right),
                onPressed: currentPage < totalPages
                    ? () => onPageChanged(currentPage + 1)
                    : null,
                tooltip: 'التالي',
              ),
            ],
          ),
        ],
      ),
    );
  }
}


