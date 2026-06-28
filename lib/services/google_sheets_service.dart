import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  // URL https://script.google.com/macros/s/AKfycbwl22GNvzkc51JyeTBEHSbg7raC1V9lXseojqb2ZPZnpygjKKTLoU72pkmJyAxjxfzw/exec
  // ID AKfycbxTPMs9d8eWOo67KqgwfvjvF--ECLc4FFd-FOwa_OvjlZcG9vrTN-On6chW-0JR8fWj
  // TODO: Replace this with your actual Google Apps Script Web App URL after deployment
  static const String _scriptUrl = 'https://script.google.com/macros/s/AKfycbwl22GNvzkc51JyeTBEHSbg7raC1V9lXseojqb2ZPZnpygjKKTLoU72pkmJyAxjxfzw/exec';

  static Future<bool> saveNumber(int value) async {
    if (_scriptUrl == 'YOUR_APPS_SCRIPT_URL_HERE') {
      print('Error: Apps Script URL not set.');
      return false;
    }

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        body: jsonEncode({'value': value}),
      );

      if (response.statusCode == 302) {
        // GAS often redirects on success
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final redirectResponse = await http.get(Uri.parse(redirectUrl));
          return redirectResponse.statusCode == 200;
        }
      }

      return response.statusCode == 200;
    } catch (e) {
      print('Error saving to Google Sheets: $e');
      return false;
    }
  }
}
