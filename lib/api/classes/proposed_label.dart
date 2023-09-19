class ProposedLabel {
  final bool isHit;
  final String? type;
  final String artId;
  final String imgId;

  ProposedLabel({
    required this.isHit,
    this.type,
    required this.artId,
    required this.imgId,
  });

  static const String LABEL_PERFECT_MATCH = "PM";
  static const String LABEL_FIRST_STRIKE = "FS";
  static const String LABEL_SECOND_STRIKE = "SS";

  Map<String, dynamic> toJson() {
    return {
      'is_hit': isHit,
      'type': type,
      'art_id': artId,
      'img_id': imgId,
    };
  }
}
