import 'package:flutter/foundation.dart';

@immutable
class ArtSuggestions {
  final Photo? photo;
  final List<Art?>? suggestions;

  const ArtSuggestions({
    this.photo,
    this.suggestions,
  });

  factory ArtSuggestions.fromJson(Map<String, dynamic> json) {
    return ArtSuggestions(
      photo: json['photo'] != null ? Photo.fromJson(json['photo']) : null,
      suggestions: (json['suggestions'] as List<dynamic>?)
          ?.map((e) => e != null ? Art.fromJson(e) : null)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'photo': photo?.toJson(),
      'suggestions': suggestions?.map((e) => e?.toJson()).toList(),
    };
  }
}

class Photo {
  final String id; // Replace with the actual properties of the Photo class

  Photo({
    required this.id,
  });

  factory Photo.fromJson(Map<String, dynamic> json) {
    return Photo(
      id: json['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}

class Art {
  final String id; // Replace with the actual properties of the Art class

  Art({
    required this.id,
  });

  factory Art.fromJson(Map<String, dynamic> json) {
    return Art(
      id: json['id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
    };
  }
}
