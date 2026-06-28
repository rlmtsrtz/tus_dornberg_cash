import 'dart:convert';
import 'package:http/http.dart' as http;

class GoogleSheetsService {
  // Spreadsheet Link: https://docs.google.com/spreadsheets/d/1_MKnby7lcBM_yIuBWJJ_AA1yiP9En3JKupWyHT8BjDM/edit?usp=sharing
  // TODO: Replace this with your actual Google Apps Script Web App URL after deployment
  static const String _scriptUrl = 'https://docs.google.com/spreadsheets/d/1_MKnby7lcBM_yIuBWJJ_AA1yiP9En3JKupWyHT8BjDM/edit?usp=sharing';

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
