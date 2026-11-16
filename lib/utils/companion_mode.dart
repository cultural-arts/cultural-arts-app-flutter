import 'package:hive/hive.dart';

enum CompanionMode {
  standard(
    'standard',
    'Standard',
    'A balanced description of the place or artwork.',
  ),
  snapshot(
    'snapshot',
    'Snapshot',
    'A short, quick overview.',
  ),
  insight(
    'insight',
    'Insight',
    'A more detailed look at meaning and context.',
  );

  const CompanionMode(this.value, this.title, this.description);

  final String value;
  final String title;
  final String description;

  static CompanionMode? fromValue(String? value) {
    for (final mode in values) {
      if (mode.value == value) return mode;
    }
    return null;
  }
}

class CompanionModeStorage {
  static const _modeKey = 'companion_mode';

  static final _box = Hive.box('settings');

  static CompanionMode? get mode =>
      CompanionMode.fromValue(_box.get(_modeKey) as String?);

  static Future<void> save(CompanionMode mode) =>
      _box.put(_modeKey, mode.value);
}
