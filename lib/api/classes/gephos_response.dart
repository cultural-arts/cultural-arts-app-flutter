import 'package:flutter/foundation.dart';

@immutable
class GEPHOSResponse {
  final Map<String, double> defaultPhoto;
  final Map<String, double> extraPhoto;

  GEPHOSResponse({
    required this.defaultPhoto,
    required this.extraPhoto,
  });

  factory GEPHOSResponse.fromJson(Map<String, dynamic> json) {
    return GEPHOSResponse(
      defaultPhoto: Map<String, double>.from(json['default_photo']),
      extraPhoto: Map<String, double>.from(json['extra_photo']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'default_photo': defaultPhoto,
      'extra_photo': extraPhoto,
    };
  }
}
