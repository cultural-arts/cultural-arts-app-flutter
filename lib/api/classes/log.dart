class CulturalArtsLog {
  final String source;
  final String severity;
  final String description;

  CulturalArtsLog({
    required this.source,
    required this.severity,
    required this.description,
  });

  static const String SEVERITY_CRITICAL = 'C';
  static const String SEVERITY_ERROR = 'E';
  static const String SEVERITY_WARNING = 'W';
  static const String SEVERITY_INFO = 'I';
  static const String SEVERITY_DEBUG = 'D';
  static const String SEVERITY_NOTSET = 'N';

  Map<String, dynamic> toJson() {
    return {
      'source': source,
      'severity': severity,
      'description': description,
    };
  }
}
