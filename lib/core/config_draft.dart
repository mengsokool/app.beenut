import 'dart:convert';
import 'models.dart';

/// Keep only edited leaves so a live refresh cannot overwrite unrelated settings.
class ConfigDraft {
  final Map<String, dynamic> _changes = {};
  bool get isDirty => _changes.isNotEmpty;

  MachineConfig resolve(MachineConfig current) =>
      MachineConfig.fromJson(_merge(current.toJson(), _changes));

  void update(MachineConfig current, MachineConfig edited) {
    final previous = resolve(current).toJson();
    final delta = _difference(previous, edited.toJson());
    final combined = _merge(_changes, delta);
    final resolved = _merge(current.toJson(), combined);
    _changes
      ..clear()
      ..addAll(_difference(current.toJson(), resolved));
  }

  void clear() => _changes.clear();

  static Map<String, dynamic> _difference(
    Map<String, dynamic> from,
    Map<String, dynamic> to,
  ) {
    final delta = <String, dynamic>{};
    for (final entry in to.entries) {
      final before = from[entry.key];
      if (before is Map<String, dynamic> &&
          entry.value is Map<String, dynamic>) {
        final nested = _difference(before, entry.value);
        if (nested.isNotEmpty) delta[entry.key] = nested;
      } else if (jsonEncode(before) != jsonEncode(entry.value)) {
        delta[entry.key] = entry.value;
      }
    }
    return delta;
  }

  static Map<String, dynamic> _merge(
    Map<String, dynamic> base,
    Map<String, dynamic> patch,
  ) {
    final result = Map<String, dynamic>.from(base);
    for (final entry in patch.entries) {
      final before = result[entry.key];
      result[entry.key] =
          before is Map<String, dynamic> && entry.value is Map<String, dynamic>
          ? _merge(before, entry.value)
          : entry.value;
    }
    return result;
  }
}
