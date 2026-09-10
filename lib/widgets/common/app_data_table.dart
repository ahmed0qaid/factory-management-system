import 'package:flutter/material.dart';
import 'app_card.dart';

class AppDataTable extends StatelessWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final bool showCheckboxColumn;
  final double? dataRowMaxHeight;

  const AppDataTable({
    Key? key,
    required this.columns,
    required this.rows,
    this.showCheckboxColumn = false,
    this.dataRowMaxHeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: columns,
          rows: rows,
          showCheckboxColumn: showCheckboxColumn,
          dataRowMaxHeight: dataRowMaxHeight,
        ),
      ),
    );
  }
}
