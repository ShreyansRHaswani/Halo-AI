// lib/halo_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

const String _kBaseUrl = 'http://127.0.0.1:8000';

class HaloApi {
  static Future<dynamic> _post(String path, Map<String, dynamic> data) async {
    final uri = Uri.parse('$_kBaseUrl$path');
    try {
      final response = await http.post(uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(data));
      if (kDebugMode) {
        print('POST $path -> ${response.statusCode}');
        print(response.body);
      }
      return jsonDecode(response.body);
    } catch (e) {
      if (kDebugMode) print('POST error $path: $e');
      rethrow;
    }
  }

  static Future<dynamic> _get(String path) async {
    final uri = Uri.parse('$_kBaseUrl$path');
    try {
      final response = await http.get(uri);
      if (kDebugMode) {
        print('GET $path -> ${response.statusCode}');
        print(response.body);
      }
      return jsonDecode(response.body);
    } catch (e) {
      if (kDebugMode) print('GET error $path: $e');
      rethrow;
    }
  }

  // Parent
  static Future<String?> parentLogin(String username, String password) async {
    final res = await _post('/parent/login', {'username': username, 'password': password});
    return res['ok'] == true ? res['parent_uid'] as String? : null;
  }

  static Future<List<dynamic>> getChildren(String parentUid) async {
    final res = await _get('/parent/children/$parentUid');
    return (res['children'] as List<dynamic>?) ?? [];
  }

  static Future<List<dynamic>> getAlerts(String parentUid) async {
    final res = await _get('/parent/alerts/$parentUid');
    return (res['alerts'] as List<dynamic>?) ?? [];
  }

  static Future<List<dynamic>> getAlertTrends(String parentUid) async {
    final res = await _get('/parent/alerts/trends/$parentUid');
    return (res['trends'] as List<dynamic>?) ?? [];
  }

  static Future<List<dynamic>> getChildJournals(String parentUid) async {
    final res = await _get('/parent/journals/$parentUid');
    return (res['journals'] as List<dynamic>?) ?? [];
  }

  static Future<Map<String, dynamic>> getJournalStats(String parentUid) async {
    final res = await _get('/parent/journal_stats/$parentUid');
    return {'good': res['good'] ?? 0, 'bad': res['bad'] ?? 0};
  }

  static Future<List<dynamic>> getParentMessages(String parentUid) async {
    final res = await _get('/parent/messages/$parentUid');
    return (res['messages'] as List<dynamic>?) ?? [];
  }

  static Future<void> acknowledgeAlert(String alertId, {bool acknowledged = true, String? feedback}) async {
    await _post('/parent/alert/$alertId', {'acknowledged': acknowledged, 'feedback': feedback});
  }

  // Child
  static Future<String?> childLogin(String uid) async {
    final res = await _post('/child/login', {'uid': uid});
    return res['ok'] == true ? res['child_uid'] as String? : null;
  }

  static Future<bool> checkChildExists(String uid) async {
    final res = await _get('/child/exists/$uid');
    return res['exists'] == true;
  }

  static Future<void> registerChild({required String uid, required String name, required String parentUid}) async {
    await _post('/child/register', {'uid': uid, 'name': name, 'parent_uid': parentUid});
  }

  static Future<void> saveJournal({required String childUid, required List<String> good, required List<String> bad}) async {
    await _post('/child/journal', {'uid': childUid, 'good': good, 'bad': bad});
  }

  static Future<List<dynamic>> getReminders(String childUid) async {
    final res = await _get('/child/reminders/$childUid');
    return (res['reminders'] as List<dynamic>?) ?? [];
  }

  static Future<Map<String, dynamic>> getUsageSummary(String childUid) async {
    final res = await _get('/child/usage_summary/$childUid');
    return {
      'ok': res['ok'] ?? false,
      'total_seconds': res['total_seconds'] ?? 0,
      'unlock_count': res['unlock_count'] ?? 0,
      'summary': (res['summary'] as List<dynamic>?) ?? []
    };
  }

  static Future<List<dynamic>> getFlashcards() async {
    final res = await _get('/child/flashcards');
    return (res['cards'] as List<dynamic>?) ?? [];
  }

  static Future<List<dynamic>> getChildMessages(String childUid) async {
    final res = await _get('/child/messages/$childUid');
    return (res['messages'] as List<dynamic>?) ?? [];
  }

  static Future<void> sendMessage({required String sender, required String recipient, required String text}) async {
    await _post('/message/send', {'sender': sender, 'recipient': recipient, 'text': text});
  }

  static Future<void> sendSos({required String childId}) async {
    await _post('/child/sos', {'uid': childId});
  }

  static Future<void> reportText({required String childUid, required String text}) async {
    await _post('/child/report_text', {'child_uid': childUid, 'text_content': text});
  }

  static Future<void> setReminder({required String childUid, required String type, int? intervalMinutes}) async {
    await _post('/child/reminder', {'uid': childUid, 'type': type, 'interval_minutes': intervalMinutes});
  }
}
