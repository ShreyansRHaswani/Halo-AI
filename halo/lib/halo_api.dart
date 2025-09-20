import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Import for kDebugMode

// Your backend's host URL.
const String _kBaseUrl = 'http://127.0.0.1:8000';

class HaloApi {
  // Helper method for API calls
  static Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_kBaseUrl$path');
    try {
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );
      if (kDebugMode) {
        print('POST $path response: ${response.statusCode}');
        print('Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API POST error on $path: $e');
      }
      rethrow;
    }
  }

  // Helper method for GET requests
  static Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$_kBaseUrl$path');
    try {
      final response = await http.get(uri);
      if (kDebugMode) {
        print('GET $path response: ${response.statusCode}');
        print('Body: ${response.body}');
      }
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('API GET error on $path: $e');
      }
      rethrow;
    }
  }

  // --- NEW: Child Registration ---
  static Future<void> registerChild({
    required String uid,
    required String name,
    required String parentUid,
    String? dob,
    String? address,
    String? bloodGroup,
    List<String>? parentContacts,
  }) async {
    await _post('/child/register', {
      'uid': uid,
      'name': name,
      'parent_uid': parentUid,
      'dob': dob,
      'address': address,
      'blood_group': bloodGroup,
      'parent_contacts': parentContacts ?? [],
    });
  }

  // --- NEW: SOS Alert ---
  static Future<void> sendSos({
    required String childId,
    double? lat,
    double? lng,
  }) async {
    await _post('/child/sos', {'uid': childId, 'lat': lat, 'lng': lng});
  }

  // --- NEW: Report Text ---
  static Future<void> reportText(String text, {required String childId}) async {
    await _post('/child/report_text', {'child_uid': childId, 'text_content': text});
  }

  // --- App Usage ---
  static Future<dynamic> getAppUsageSummary(String childUid) async {
    return await _get('/child/usage_summary/$childUid');
  }

  // --- Journal ---
  static Future<void> saveJournal({
    required String childUid,
    required List<String> good,
    required List<String> bad,
  }) async {
    await _post('/child/journal', {
      'uid': childUid,
      'good': good,
      'bad': bad,
    });
  }

  // --- NEW: Get Child Journals (for Parent) ---
  static Future<List<dynamic>> getChildJournals(String parentUid) async {
    final response = await _get('/parent/journals/$parentUid');
    return response['journals'];
  }

  // --- Reminder ---
  static Future<void> setReminder({
    required String childUid,
    required String type,
    required int intervalMinutes,
  }) async {
    await _post('/child/reminder', {
      'uid': childUid,
      'type': type,
      'interval_minutes': intervalMinutes,
    });
  }

  // --- Flashcards ---
  static Future<List<dynamic>> getFlashcards() async {
    final response = await _get('/child/flashcards');
    return response['cards'];
  }

  // --- Location ---
  static Future<void> updateLocation({
    required String childUid,
    required double lat,
    required double lng,
  }) async {
    await _post('/child/location', {
      'uid': childUid,
      'lat': lat,
      'lng': lng,
    });
  }

  static Future<dynamic> getChildLocation(String childUid) async {
    final response = await _get('/parent/find_child/$childUid');
    return response['location'];
  }

  // --- Alerts ---
  static Future<List<dynamic>> getAlerts(String parentUid) async {
    final response = await _get('/parent/alerts/$parentUid');
    return response['alerts'];
  }

  static Future<void> markAlertRead(String alertId) async {
    await _post('/parent/alert/$alertId', {'acknowledged': true});
  }
}