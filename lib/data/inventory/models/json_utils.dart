// تحويلات آمنة لاستجابات Supabase (uuid/numeric/jsonb قد تصل بأنواع مختلفة)

String asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

String? asStringOrNull(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

double asDouble(dynamic value, {double fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? asDoubleOrNull(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

int asInt(dynamic value, {int fallback = 0}) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

bool asBool(dynamic value, {bool fallback = false}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final s = value.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return fallback;
}

DateTime asDateTime(dynamic value) {
  if (value is DateTime) return value;
  return DateTime.parse(value.toString());
}

DateTime? asDateTimeOrNull(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  return DateTime.tryParse(value.toString());
}

Map<String, dynamic> asJsonMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

List<Map<String, dynamic>> asJsonMapList(dynamic value) {
  if (value == null) return [];
  if (value is List) {
    return value
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
  if (value is Map) {
    final values = value.values.toList();
    if (values.isNotEmpty && values.first is Map) {
      return values
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
  }
  return [];
}
