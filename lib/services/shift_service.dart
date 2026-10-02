import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';
import '../models/shift_model.dart';
import '../permissions/role_permissions.dart';
import 'appwrite_service.dart';
import 'company_context_service.dart';

class ShiftService {
  List<String> _permissions(String companyId) => [
    Permission.read(Role.team(companyId)),
    Permission.update(Role.team(companyId, AppRoles.hrAdmin)),
    Permission.delete(Role.team(companyId, AppRoles.hrAdmin)),
  ];

  Future<void> _requireShift(String shiftId, String companyId) async {
    final row = await AppwriteService.tablesDB.getRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      rowId: shiftId,
    );
    if (row.data['company_id']?.toString() != companyId) {
      throw StateError('الوردية لا تتبع شركة المستخدم الحالية.');
    }
  }

  Future<List<ShiftModel>> getShifts(String companyId) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      queries: [Query.equal('company_id', scopedCompanyId)],
    );
    return response.rows
        .map((r) => ShiftModel.fromMap(r.data, id: r.$id))
        .toList();
  }

  Future<void> createShift(ShiftModel shift) async {
    final companyId = await CompanyContextService.requireCompany(
      shift.companyId,
    );
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      rowId: ID.unique(),
      data: shift.toMap()..remove('id'),
      permissions: _permissions(companyId),
    );
  }

  Future<void> updateShift(ShiftModel shift) async {
    final companyId = await CompanyContextService.requireCompany(
      shift.companyId,
    );
    await _requireShift(shift.id, companyId);
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      rowId: shift.id,
      data: shift.toMap()
        ..remove('id')
        ..remove('company_id'),
    );
  }

  Future<void> toggleActive(String shiftId, bool active) async {
    final companyId = await CompanyContextService.getCurrentCompanyId();
    await _requireShift(shiftId, companyId);
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      rowId: shiftId,
      data: {'active': active},
    );
  }

  Future<void> seedDefaultShifts(String companyId) async {
    final scopedCompanyId = await CompanyContextService.requireCompany(companyId);
    final existing = await getShifts(scopedCompanyId);
    final existingNames = existing.map((e) => e.name).toSet();

    final defaults = [
      ShiftModel(
        id: '',
        companyId: scopedCompanyId,
        name: 'الوردية الصباحية',
        startTime: '06:00',
        endTime: '14:00',
        isOvernight: false,
        active: true,
      ),
      ShiftModel(
        id: '',
        companyId: scopedCompanyId,
        name: 'الوردية المسائية',
        startTime: '14:00',
        endTime: '22:00',
        isOvernight: false,
        active: true,
      ),
      ShiftModel(
        id: '',
        companyId: scopedCompanyId,
        name: 'الوردية الليلية',
        startTime: '22:00',
        endTime: '06:00',
        isOvernight: true,
        active: true,
      ),
    ];

    for (final shift in defaults) {
      if (!existingNames.contains(shift.name)) {
        await createShift(shift);
      }
    }
  }
}
