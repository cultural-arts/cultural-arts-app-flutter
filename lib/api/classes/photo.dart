import 'package:flutter/foundation.dart';

@immutable
class Photo {
  final String id;
  final String photo;

  const Photo({
    required this.id,
    required this.photo,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
      photo: json['photo'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'photo': photo,
    };
  }
}
