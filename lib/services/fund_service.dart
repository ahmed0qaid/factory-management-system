import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;

import '../config/constants.dart';
import '../models/fund_closure_model.dart';
import '../models/fund_model.dart';
import '../models/fund_transaction_model.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

class FundService {
  final _tablesDB = AppwriteService.tablesDB;
  final String _dbId = AppConstants.databaseId;

  Map<String, dynamic> _data(models.Row row) => {...row.data, 'id': row.$id};

  List<String> _fundPermissions(String companyId) => [
    Permission.read(Role.team(companyId, 'hr_admin')),
    Permission.read(Role.team(companyId, 'financial_manager')),
    Permission.update(Role.team(companyId, 'hr_admin')),
    Permission.update(Role.team(companyId, 'financial_manager')),
    Permission.delete(Role.team(companyId, 'hr_admin')),
  ];

  List<String> _ledgerPermissions(String companyId) => [
    Permission.read(Role.team(companyId, 'hr_admin')),
    Permission.read(Role.team(companyId, 'financial_manager')),
    Permission.update(Role.team(companyId, 'hr_admin')),
    Permission.update(Role.team(companyId, 'financial_manager')),
  ];

  Future<models.Row> _requireFundInCurrentCompany(String fundId) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    final fund = await _tablesDB.getRow(
      databaseId: _dbId,
      tableId: 'funds',
      rowId: fundId,
    );
    if (fund.data['company_id']?.toString() != companyId) {
      throw StateError('الصندوق لا يتبع شركة المستخدم الحالية.');
    }
    return fund;
  }

  Future<List<FundModel>> getFunds() async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    final response = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'funds',
      queries: [
        Query.equal('company_id', companyId),
        Query.orderAsc('name'),
      ],
    );
    return response.rows.map((d) => FundModel.fromMap(_data(d))).toList();
  }

  Future<void> createFund(String name, String type) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    await _tablesDB.createRow(
      databaseId: _dbId,
      tableId: 'funds',
      rowId: ID.unique(),
      data: {
        'company_id': companyId,
        'name': name,
        'type': type,
        'balance': 0.0,
        'active': true,
      },
      permissions: _fundPermissions(companyId),
    );
  }

  Future<void> addTransaction({
    required String fundId,
    required String type,
    required double amount,
    required String description,
    required String createdBy,
    String? referenceId,
  }) async {
    final profile = await CompanyContextService.getCurrentProfile();
    if (createdBy != profile.id) {
      throw StateError('منشئ الحركة لا يطابق المستخدم الحالي.');
    }
    if (type != 'in' && type != 'out') {
      throw ArgumentError('نوع حركة الصندوق غير صالح.');
    }
    if (amount <= 0) {
      throw ArgumentError('مبلغ الحركة يجب أن يكون أكبر من صفر.');
    }

    final fundDoc = await _requireFundInCurrentCompany(fundId);

    // The atomic ledger redesign is handled in the dedicated fund phase.
    // Phase 3 only guarantees company isolation for the existing flow.
    await _tablesDB.createRow(
      databaseId: _dbId,
      tableId: 'fund_transactions',
      rowId: ID.unique(),
      data: {
        'company_id': profile.companyId,
        'fund_id': fundId,
        'type': type,
        'amount': amount,
        'description': description,
        'date': DateTime.now().toIso8601String(),
        'created_by': profile.id,
        if (referenceId != null) 'reference_id': referenceId,
      },
      permissions: _ledgerPermissions(profile.companyId),
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
    final companyId = await CompanyContextService.getCurrentCompanyId();
    await _requireFundInCurrentCompany(fundId);
    final response = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'fund_transactions',
      queries: [
        Query.equal('company_id', companyId),
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
    final companyId = await CompanyContextService.getCurrentCompanyId();
    await _requireFundInCurrentCompany(fundId);
    final response = await _tablesDB.listRows(
      databaseId: _dbId,
      tableId: 'fund_closures',
      queries: [
        Query.equal('company_id', companyId),
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
    final profile = await CompanyContextService.getCurrentProfile();
    if (closedBy != profile.id) {
      throw StateError('منفذ التصفية لا يطابق المستخدم الحالي.');
    }
    await _requireFundInCurrentCompany(fundId);

    final closures = await getClosures(fundId);
    DateTime? lastClosureDate;
    double openingBalance = 0.0;
    if (closures.isNotEmpty) {
      lastClosureDate = closures.first.date;
      openingBalance = closures.first.closingBalance;
    }

    final queries = <String>[
      Query.equal('company_id', profile.companyId),
      Query.equal('fund_id', fundId),
    ];
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
    for (final doc in txResponse.rows) {
      final transaction = FundTransactionModel.fromMap(_data(doc));
      if (transaction.type == 'in') totalIn += transaction.amount;
      if (transaction.type == 'out') totalOut += transaction.amount;
    }

    final closingBalance = openingBalance + totalIn - totalOut;

    await _tablesDB.createRow(
      databaseId: _dbId,
      tableId: 'fund_closures',
      rowId: ID.unique(),
      data: {
        'company_id': profile.companyId,
        'fund_id': fundId,
        'date': DateTime.now().toIso8601String(),
        'opening_balance': openingBalance,
        'total_in': totalIn,
        'total_out': totalOut,
        'closing_balance': closingBalance,
        'closed_by': profile.id,
      },
      permissions: _ledgerPermissions(profile.companyId),
    );
  }
}
