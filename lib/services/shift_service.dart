import 'package:appwrite/appwrite.dart';
import '../config/constants.dart';
import '../models/shift_model.dart';
import 'appwrite_service.dart';

class ShiftService {
  Future<List<ShiftModel>> getShifts(String companyId) async {
    final response = await AppwriteService.tablesDB.listRows(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      queries: [Query.equal('company_id', companyId)],
    );
    return response.rows
        .map((r) => ShiftModel.fromMap(r.data, id: r.$id))
        .toList();
  }

  Future<void> createShift(ShiftModel shift) async {
    await AppwriteService.tablesDB.createRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      rowId: ID.unique(),
      data: shift.toMap()..remove('id'),
    );
  }

  Future<void> updateShift(ShiftModel shift) async {
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
    await AppwriteService.tablesDB.updateRow(
      databaseId: AppConstants.databaseId,
      tableId: AppConstants.shiftsTable,
      rowId: shiftId,
      data: {'active': active},
    );
  }

  Future<void> seedDefaultShifts(String companyId) async {
    final existing = await getShifts(companyId);
    final existingNames = existing.map((e) => e.name).toSet();

    final defaults = [
      ShiftModel(
        id: '',
        companyId: companyId,
        name: 'الوردية الصباحية',
        startTime: '06:00',
        endTime: '14:00',
        isOvernight: false,
        active: true,
      ),
      ShiftModel(
        id: '',
        companyId: companyId,
        name: 'الوردية المسائية',
        startTime: '14:00',
        endTime: '22:00',
        isOvernight: false,
        active: true,
      ),
      ShiftModel(
        id: '',
        companyId: companyId,
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
