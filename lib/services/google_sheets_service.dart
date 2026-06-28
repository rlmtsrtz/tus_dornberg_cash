import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/person.dart';
import '../models/penalty.dart';

class GoogleSheetsService {
  // Aktuelle URL aus der vorherigen Konfiguration
  static const String _scriptUrl = 'https://script.google.com/macros/s/AKfycbzIY4jYV2U8NEiRkJ0t4BDOuZ-Syist8XMn10VsyzJvyepcr69Ul3bPecR3lDVZTOO-/exec';

  static Future<Map<String, dynamic>> _post(Map<String, dynamic> data) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        body: jsonEncode(data),
      );

      if (response.statusCode == 302) {
        final redirectUrl = response.headers['location'];
        if (redirectUrl != null) {
          final res = await http.get(Uri.parse(redirectUrl));
          return jsonDecode(res.body);
        }
      }

      return jsonDecode(response.body);
    } catch (e) {
      print('Error in GoogleSheetsService: $e');
      return {'result': 'error', 'message': e.toString()};
    }
  }

  static Future<List<Person>> getPeople() async {
    final res = await _post({'action': 'getPeople'});
    if (res['result'] == 'success') {
      return (res['data'] as List).map((json) => Person.fromJson(json)).toList();
    }
    return [];
  }

  static Future<bool> addPerson(Person person) async {
    final res = await _post({
      'action': 'addPerson',
      'data': person.toJson(),
    });
    return res['result'] == 'success';
  }

  static Future<bool> deletePerson(String id) async {
    final res = await _post({
      'action': 'deletePerson',
      'id': id,
    });
    return res['result'] == 'success';
  }

  static Future<List<Penalty>> getPenalties() async {
    final res = await _post({'action': 'getPenalties'});
    if (res['result'] == 'success') {
      return (res['data'] as List).map((json) => Penalty.fromJson(json)).toList();
    }
    return [];
  }

  static Future<bool> addPenalty(Penalty penalty) async {
    final res = await _post({
      'action': 'addPenalty',
      'data': penalty.toJson(),
    });
    return res['result'] == 'success';
  }

  static Future<bool> deletePenalty(String id) async {
    final res = await _post({
      'action': 'deletePenalty',
      'id': id,
    });
    return res['result'] == 'success';
  }
}
