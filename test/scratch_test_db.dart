import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  const url = 'https://xwkdshemuykzotpczxvx.supabase.co';
  const anonKey = 'sb_publishable_z9CCFNKYJf3gSAGXHh1UPw_7NJYzGyz';

  final headers = {
    'apikey': anonKey,
    'Authorization': 'Bearer $anonKey',
    'Content-Type': 'application/json',
  };

  print('--- 1. Testing notifications query ---');
  try {
    final res = await http.get(
      Uri.parse('$url/rest/v1/notifications?select=*&limit=5'),
      headers: headers,
    );
    print('Notifications status: ${res.statusCode}');
    print('Notifications body: ${res.body}');
  } catch (e) {
    print('Notifications error: $e');
  }

  print('\n--- 2. Testing hr_decide_leave_request call ---');
  try {
    final res = await http.post(
      Uri.parse('$url/rest/v1/rpc/hr_decide_leave_request'),
      headers: headers,
      body: jsonEncode({
        'p_id': '00000000-0000-0000-0000-000000000000',
        'p_status': 'rejected',
      }),
    );
    print('decide status: ${res.statusCode}');
    print('decide body: ${res.body}');
  } catch (e) {
    print('decide error: $e');
  }

  print('\n--- 3. Testing hr_submit_attendance call ---');
  try {
    final res = await http.post(
      Uri.parse('$url/rest/v1/rpc/hr_submit_attendance'),
      headers: headers,
      body: jsonEncode({
        'p_employee_id': '00000000-0000-0000-0000-000000000000',
        'p_record_date': '2026-10-13',
        'p_status': 'present',
        'p_context': 'hr',
      }),
    );
    print('attendance status: ${res.statusCode}');
    print('attendance body: ${res.body}');
  } catch (e) {
    print('attendance error: $e');
  }

  print('\n--- 4. Checking OpenAPI definitions for RPC signatures ---');
  try {
    final res = await http.get(
      Uri.parse('$url/rest/v1/?select=rpc/hr_decide_leave_request'),
      headers: headers,
    );
    print('OpenAPI status: ${res.statusCode}');
    final swagger = jsonDecode(res.body);
    final paths = swagger['paths'] as Map<String, dynamic>?;
    if (paths != null) {
      for (final key in paths.keys) {
        if (key.contains('hr_decide') || key.contains('hr_submit') || key.contains('notification')) {
          print('Found endpoint: $key -> ${paths[key]}');
        }
      }
    }
  } catch (e) {
    print('OpenAPI error: $e');
  }
}
