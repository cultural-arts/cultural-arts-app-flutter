import 'package:hive/hive.dart';

enum CompanionMode {
  standard(
    'standard',
    'Standard',
    'Discover the highlights and stories behind this cultural heritage artifact with an engaging, well-rounded description.',
  ),
  snapshot(
    'snapshot',
    'Snapshot',
    'Get to know this cultural heritage artifact at a glance with a quick, captivating overview.',
  ),
  insight(
    'insight',
    'Insight',
    'Go beyond the surface with an in-depth exploration of its history, cultural significance, artistic meaning, and hidden details.',
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
