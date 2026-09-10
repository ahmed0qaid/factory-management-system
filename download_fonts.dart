import 'dart:io';
import 'package:http/http.dart' as http;

void main() async {
  final url = 'https://raw.githubusercontent.com/google/fonts/main/ofl/cairo/Cairo%5Bslnt%2Cwght%5D.ttf';
  
  try {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode == 200) {
      File('assets/fonts/cairo/Cairo.ttf')
        ..createSync(recursive: true)
        ..writeAsBytesSync(res.bodyBytes);
      print('Downloaded Cairo.ttf (${res.bodyBytes.length} bytes)');
    } else {
      print('Failed with status: ${res.statusCode}');
    }
  } catch (e) {
    print('Failed : $e');
  }
}
