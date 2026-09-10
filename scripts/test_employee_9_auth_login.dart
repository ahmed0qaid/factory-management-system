import 'package:dart_appwrite/dart_appwrite.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  Client client = Client();
  client
      .setEndpoint('https://fra.cloud.appwrite.io/v1')
      .setProject('6a6a49d1000884049205')
      .setKey('standard_8831478838d66625e099e541665906fd006bd08bf2a3c096a2f8f9309808423ce8f9d92445107edbb603f6db41f75886a3e090cb5b8c1e38a8958ddf55527c53742cdb09a5ece5f901fac546e1540f37eefbe1dcfc4eb8e3b629bd485757dcd2c9eef58ca287bb38ee33c5538cac13c601c1a292125b91dd354467c72251ed93');

  Users users = Users(client);

  try {
    final userId = '6a71b9690026efc8c835'; // From previous diagnosis
    print('Resetting password for userId: $userId to 12345678');
    await users.updatePassword(userId: userId, password: '12345678');
    print('Password reset successfully.');

    // Now test login with client SDK equivalent
    final email = '9@hr.local';
    final password = '12345678';
    final url = Uri.parse('https://fra.cloud.appwrite.io/v1/account/sessions/email');

    print('Testing login with auth email: $email');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json',
        'X-Appwrite-Project': '6a6a49d1000884049205',
      },
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      print('login with auth email: success');
    } else {
      print('login with auth email: fail');
      final body = jsonDecode(response.body);
      print('Error type/message: ${body["message"]}');
    }

  } catch (e) {
    print('Error: $e');
  }
}
