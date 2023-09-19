import 'package:flutter/foundation.dart';

@immutable
class Audio {
  final String id;
  final String audioFile;
  final String status;
  final String addedBy;
  final String language;

  Audio({
    required this.id,
    required this.audioFile,
    required this.status,
    required this.addedBy,
    required this.language,
  });

  factory Audio.fromJson(Map<String, dynamic> json) {
    return Audio(
      id: json['id'],
      audioFile: json['audio_file'],
      status: json['status'],
      addedBy: json['added_by'],
      language: json['language'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'audio_file': audioFile,
      'status': status,
      'added_by': addedBy,
      'language': language,
    };
  }
}
