import 'package:appwrite/appwrite.dart';

import '../config/constants.dart';

class AppwriteService {
  AppwriteService._();

  static final Client client = Client();
  static late final Account account;
  static late final TablesDB tablesDB;
  static late final Functions functions;
  static late final Storage storage;

  static Future<void> init({
    required String endpoint,
    required String projectId,
    required String databaseId,
    required String createEmployeeFunctionId,
  }) async {
    AppConstants.databaseId = databaseId;
    AppConstants.createEmployeeFunctionId = createEmployeeFunctionId;

    client
      ..setEndpoint(endpoint)
      ..setProject(projectId);

    account = Account(client);
    tablesDB = TablesDB(client);
    functions = Functions(client);
    storage = Storage(client);
  }
}
