import 'package:flutter/material.dart';
import 'camera_widget.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: TakePictureScreen(),
      ),
    );
  }
}
