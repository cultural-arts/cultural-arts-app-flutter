import 'package:flutter/material.dart';
import 'package:flutter_fullscreen/flutter_fullscreen.dart';
import 'camera_widget.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {

  @override
  void initState() {
    super.initState();
    _enterFullscreen();
  }


  Future<void> _enterFullscreen() async {
    
    WidgetsFlutterBinding.ensureInitialized();
    await FullScreen.ensureInitialized();

    FullScreen.setFullScreen(true);

  }

  @override

  void dispose() {
    FullScreen.setFullScreen(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: TakePictureScreen(),
    );
  }
}
