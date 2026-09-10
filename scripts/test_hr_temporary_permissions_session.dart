import 'dart:io';
import 'dart:convert';

void main() async {
  final envFile = File('.env');
  final lines = await envFile.readAsLines();
  final env = <String, String>{};
  for (var line in lines) {
    final parts = line.split('=');
    if (parts.length >= 2) {
      env[parts[0].trim()] = parts
          .sublist(1)
          .join('=')
          .trim()
          .replaceAll("'", "");
    }
  }

  final endpoint = env['APPWRITE_ENDPOINT'] ?? 'https://cloud.appwrite.io/v1';
  final projectId = env['APPWRITE_PROJECT_ID'];
  final databaseId = env['APPWRITE_DATABASE_ID'];

  if (projectId == null || databaseId == null) {
    print('Missing Appwrite variables in .env');
    exit(1);
  }

  final client = HttpClient();
  final cookies = <Cookie>[];
  final collectionId = 'temporary_biometric_employees';
  final baseDocsUrl =
      '$endpoint/databases/$databaseId/collections/$collectionId/documents';
  final profilesDocsUrl =
      '$endpoint/databases/$databaseId/collections/profiles/documents';

  // Helper: make request with session cookies
  Future<Map<String, dynamic>> request(
    String method,
    String url, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(url);
    late HttpClientRequest req;
    switch (method) {
      case 'GET':
        req = await client.getUrl(uri);
        break;
      case 'POST':
        req = await client.postUrl(uri);
        break;
      case 'PATCH':
        req = await client.patchUrl(uri);
        break;
      case 'DELETE':
        req = await client.deleteUrl(uri);
        break;
      default:
        req = await client.getUrl(uri);
    }
    req.headers.set('x-appwrite-project', projectId);
    req.headers.set('content-type', 'application/json');
    // Set cookies
    for (final c in cookies) {
      req.cookies.add(c);
    }
    if (body != null) {
      req.write(jsonEncode(body));
    }
    final res = await req.close();
    // Collect cookies from response
    for (final c in res.cookies) {
      cookies.removeWhere((existing) => existing.name == c.name);
      cookies.add(c);
    }
    final resBody = await res.transform(utf8.decoder).join();
    return {
      'statusCode': res.statusCode,
      'body': resBody.isNotEmpty ? jsonDecode(resBody) : {},
    };
  }

  try {
    // 1. Login
    print('HR001 login...');
    final loginRes = await request(
      'POST',
      '$endpoint/account/sessions/email',
      body: {'email': 'hr001@hr.local', 'password': '12345678'},
    );
    if (loginRes['statusCode'] >= 400) {
      print(
        'HR001 login: fail (code: ${loginRes['statusCode']}, message: ${loginRes['body']})',
      );
      return;
    }
    print('HR001 login: success');

    final accountRes = await request('GET', '$endpoint/account');
    String? hrCompanyId;
    if (accountRes['statusCode'] < 400) {
      final prefs = accountRes['body']['prefs'];
      if (prefs is Map && prefs['company_id'] != null) {
        hrCompanyId = prefs['company_id'].toString();
      }
    }
    print('HR001 company_id: ${hrCompanyId ?? '-'}');
    final accountId = accountRes['statusCode'] < 400
        ? accountRes['body']['\$id']?.toString()
        : null;
    String? hrProfileCompanyId;
    if (accountId != null) {
      final profileRes = await request('GET', '$profilesDocsUrl/$accountId');
      if (profileRes['statusCode'] < 400) {
        hrProfileCompanyId = profileRes['body']['company_id']?.toString();
      }
    }
    print('HR001 profile company_id: ${hrProfileCompanyId ?? '-'}');

    // 2. Read pending / approved / rejected
    for (final status in ['pending', 'approved', 'rejected']) {
      final query = Uri.encodeComponent(
        '{"method":"equal","attribute":"status","values":["$status"]}',
      );
      final companyQuery = hrCompanyId == null
          ? null
          : Uri.encodeComponent(
              '{"method":"equal","attribute":"company_id","values":["$hrCompanyId"]}',
            );
      final limitQuery = Uri.encodeComponent(
        '{"method":"limit","values":[100]}',
      );
      final url = companyQuery == null
          ? '$baseDocsUrl?queries[]=$query&queries[]=$limitQuery'
          : '$baseDocsUrl?queries[]=$query&queries[]=$companyQuery&queries[]=$limitQuery';
      final res = await request('GET', url);
      if (res['statusCode'] < 400) {
        print('HR001 read $status: success, count = ${res['body']['total']}');
        if (status == 'pending') {
          final documents = (res['body']['documents'] as List?) ?? const [];
          print('First 20 pending:');
          for (final doc in documents.take(20)) {
            final data = doc as Map<String, dynamic>;
            print('- \$id: ${data['\$id']}');
            print('  company_id: ${data['company_id']}');
            print('  biometric_employee_id: ${data['biometric_employee_id']}');
            print('  status: ${data['status']}');
            print('  punches_count: ${data['punches_count']}');
          }
        }
      } else {
        print(
          'HR001 read $status: fail (code: ${res['statusCode']}, message: ${res['body']['message'] ?? res['body']})',
        );
      }
    }

    // 3. Create or update TMP_PERMISSION_001
    final docId = 'temp_TMP_PERMISSION_001';
    print('\nHR001 create/update TMP_PERMISSION_001...');

    // Check if exists first
    final checkRes = await request('GET', '$baseDocsUrl/$docId');
    bool exists = checkRes['statusCode'] < 400;

    if (exists) {
      // Update existing
      final updateRes = await request(
        'PATCH',
        '$baseDocsUrl/$docId',
        body: {
          'data': {
            'status': 'pending',
            'last_seen_at': DateTime.now().toIso8601String(),
            'notes': 'Permission test row - safe to ignore',
          },
        },
      );
      if (updateRes['statusCode'] < 400) {
        print(
          'HR001 create TMP_PERMISSION_001: success (already existed, updated to pending)',
        );
      } else {
        print(
          'HR001 create TMP_PERMISSION_001: fail (code: ${updateRes['statusCode']}, message: ${updateRes['body']['message'] ?? updateRes['body']})',
        );
      }
    } else {
      // Create new
      final createRes = await request(
        'POST',
        baseDocsUrl,
        body: {
          'documentId': docId,
          'data': {
            'company_id': 'company_main',
            'biometric_employee_id': 'TMP_PERMISSION_001',
            'status': 'pending',
            'first_seen_at': DateTime.now().toIso8601String(),
            'last_seen_at': DateTime.now().toIso8601String(),
            'punches_count': 1,
            'notes': 'Permission test row - safe to ignore',
          },
        },
      );
      if (createRes['statusCode'] < 400) {
        print('HR001 create TMP_PERMISSION_001: success');
      } else {
        print(
          'HR001 create TMP_PERMISSION_001: fail (code: ${createRes['statusCode']}, message: ${createRes['body']['message'] ?? createRes['body']})',
        );
      }
    }

    // 4. Read by rowId
    final readRes = await request('GET', '$baseDocsUrl/$docId');
    if (readRes['statusCode'] < 400) {
      print(
        'HR001 read TMP_PERMISSION_001: success, status = ${readRes['body']['status']}',
      );
    } else {
      print(
        'HR001 read TMP_PERMISSION_001: fail (code: ${readRes['statusCode']}, message: ${readRes['body']['message'] ?? readRes['body']})',
      );
    }

    // 5. Update to rejected
    final rejectRes = await request(
      'PATCH',
      '$baseDocsUrl/$docId',
      body: {
        'data': {'status': 'rejected'},
      },
    );
    if (rejectRes['statusCode'] < 400) {
      print('HR001 update TMP_PERMISSION_001 to rejected: success');
    } else {
      print(
        'HR001 update TMP_PERMISSION_001 to rejected: fail (code: ${rejectRes['statusCode']}, message: ${rejectRes['body']['message'] ?? rejectRes['body']})',
      );
    }

    // 6. Read after rejected
    final readRejRes = await request('GET', '$baseDocsUrl/$docId');
    if (readRejRes['statusCode'] < 400) {
      print(
        'HR001 read TMP_PERMISSION_001 after rejected: success, status = ${readRejRes['body']['status']}',
      );
    } else {
      print('HR001 read TMP_PERMISSION_001 after rejected: fail');
    }

    // 7. Update back to pending
    final pendRes = await request(
      'PATCH',
      '$baseDocsUrl/$docId',
      body: {
        'data': {
          'status': 'pending',
          'notes': 'Permission test row - safe to ignore',
        },
      },
    );
    if (pendRes['statusCode'] < 400) {
      print('HR001 update TMP_PERMISSION_001 back to pending: success');
    } else {
      print(
        'HR001 update TMP_PERMISSION_001 back to pending: fail (code: ${pendRes['statusCode']}, message: ${pendRes['body']['message'] ?? pendRes['body']})',
      );
    }

    // 8. Read after pending
    final readPendRes = await request('GET', '$baseDocsUrl/$docId');
    if (readPendRes['statusCode'] < 400) {
      print(
        'HR001 read TMP_PERMISSION_001 after pending: success, status = ${readPendRes['body']['status']}',
      );
    } else {
      print('HR001 read TMP_PERMISSION_001 after pending: fail');
    }
  } catch (e) {
    print('Error: $e');
  } finally {
    client.close();
  }
}
