import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import '../models/fund_model.dart';
import '../models/fund_transaction_model.dart';
import '../models/fund_closure_model.dart';
import 'appwrite_service.dart';
import '../config/constants.dart';

class FundService {
  final _tablesDB = AppwriteService.tablesDB;
  final String _dbId = AppConstants.databaseId;

  Map<String, dynamic> _data(models.Row row) => {...row.data, 'id': row.$id};

  Future<List<FundModel>> getFunds() async {
    final response = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'funds',
    );
    return response.rows.map((d) => FundModel.fromMap(_data(d))).toList();
  }

  Future<void> createFund(String name, String type) async {
    await _tablesDB.createRow(
      databaseId: _dbId,
      tableId: 'funds',
      rowId: ID.unique(),
      data: {'name': name, 'type': type, 'balance': 0.0, 'active': true},
    );
  }

  Future<void> addTransaction({
    required String fundId,
    required String type, // 'in' or 'out'
    required double amount,
    required String description,
    required String createdBy,
    String? referenceId,
  }) async {
    // 1. Create the transaction
    await _tablesDB.createRow(
      databaseId: _dbId,
      tableId: 'fund_transactions',
      rowId: ID.unique(),
      data: {
        'fund_id': fundId,
        'type': type,
        'amount': amount,
        'description': description,
        'date': DateTime.now().toIso8601String(),
        'created_by': createdBy,
        if (referenceId != null) 'reference_id': referenceId,
      },
    );

    // 2. Update the fund balance
    final fundDoc = await _tablesDB.getRow(
      databaseId: _dbId,
      tableId: 'funds',
      rowId: fundId,
    );
    final currentBalance = (fundDoc.data['balance'] ?? 0.0).toDouble();
    final newBalance = type == 'in'
        ? currentBalance + amount
        : currentBalance - amount;

    await _tablesDB.updateRow(
      databaseId: _dbId,
      tableId: 'funds',
      rowId: fundId,
      data: {'balance': newBalance},
    );
  }

  Future<List<FundTransactionModel>> getTransactions(String fundId) async {
    final response = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'fund_transactions',
      queries: [
        Query.equal('fund_id', fundId),
        Query.orderDesc('date'),
        Query.limit(100),
      ],
    );
    return response.rows
        .map((d) => FundTransactionModel.fromMap(_data(d)))
        .toList();
  }

  Future<List<FundClosureModel>> getClosures(String fundId) async {
    final response = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'fund_closures',
      queries: [
        Query.equal('fund_id', fundId),
        Query.orderDesc('date'),
        Query.limit(30),
      ],
    );
    return response.rows
        .map((d) => FundClosureModel.fromMap(_data(d)))
        .toList();
  }

  Future<void> closeDailyMovement(String fundId, String closedBy) async {
    // Determine the last closure date
    final closures = await getClosures(fundId);
    DateTime? lastClosureDate;
    double openingBalance = 0.0;
    if (closures.isNotEmpty) {
      lastClosureDate = closures.first.date;
      openingBalance = closures.first.closingBalance;
    }

    // Get all transactions since last closure
    final List<String> queries = [Query.equal('fund_id', fundId)];
    if (lastClosureDate != null) {
      queries.add(Query.greaterThan('date', lastClosureDate.toIso8601String()));
    }

    final txResponse = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'fund_transactions',
      queries: queries,
    );

    double totalIn = 0.0;
    double totalOut = 0.0;

    for (var doc in txResponse.rows) {
      final t = FundTransactionModel.fromMap(_data(doc));
      if (t.type == 'in') totalIn += t.amount;
      if (t.type == 'out') totalOut += t.amount;
    }

    final closingBalance = openingBalance + totalIn - totalOut;

    await _tablesDB.createRow(
      databaseId: _dbId,
      tableId: 'fund_closures',
      rowId: ID.unique(),
      data: {
        'fund_id': fundId,
        'date': DateTime.now().toIso8601String(),
        'opening_balance': openingBalance,
        'total_in': totalIn,
        'total_out': totalOut,
        'closing_balance': closingBalance,
        'closed_by': closedBy,
      },
    );
  }
}
