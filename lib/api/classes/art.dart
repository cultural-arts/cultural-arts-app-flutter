import 'package:flutter/foundation.dart';
import 'audio.dart';

@immutable
class Art {
  final String id;
  final String intro;
  final String artName;
  final String? inferenceType;
  final String? artStartOfWorks;
  final String? artEndOfWorks;
  final String? cover;
  final Audio? audio;
  final String? licence;

  Art({
    required this.id,
    required this.intro,
    required this.artName,
    this.inferenceType,
    this.artStartOfWorks,
    this.artEndOfWorks,
    this.cover,
    this.audio,
    this.licence,
  });

  factory Art.fromJson(Map<String, dynamic> json) {
    return Art(
      id: json['id'],
      intro: json['intro'],
      artName: json['art_name'],
      inferenceType: json['inference_type'],
      artStartOfWorks: json['art_start_of_works'],
      artEndOfWorks: json['art_end_of_works'],
      cover: json['cover'],
      audio: json['audio'] != null ? Audio.fromJson(json['audio']) : null,
      licence: json['licence'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'intro': intro,
      'art_name': artName,
      'inference_type': inferenceType,
      'art_start_of_works': artStartOfWorks,
      'art_end_of_works': artEndOfWorks,
      'cover': cover,
      'audio': audio?.toJson(),
      'licence': licence,
    };
  }
}
