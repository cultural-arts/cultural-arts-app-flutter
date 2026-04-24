import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cultural_arts/upload_widget.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'dart:math' as math; // Import the math library

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void>? _initializeControllerFuture;
  late List<CameraDescription> _cameras; // Add this line

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = null;
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      // Ensure that plugin services are initialized so that `availableCameras()`
      WidgetsFlutterBinding.ensureInitialized();
      // Obtain a list of available cameras
      _cameras = await availableCameras();

      // Initialize the controller with the first camera in the list
      _controller = CameraController(_cameras.last, ResolutionPreset.medium,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);

      // Initialize the controller. This returns a Future.
      _initializeControllerFuture = _controller.initialize();

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // This container will take up the entire screen
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.blue, Colors.transparent],
          ),
        ),
        // Enforce portrait orientation and take up the full screen
        constraints: const BoxConstraints.expand(),
        child: FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return OrientationBuilder(
                builder: (context, orientation) {
                  return Transform.rotate(
                    angle: _getCameraAngle(orientation),
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: CameraPreview(_controller),
                      ),
                    ),
                  );
                },
              );
            } else {
              // Otherwise, display a loading indicator.
              return const Center(child: CircularProgressIndicator());
            }
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initializeControllerFuture;

            // Attempt to take a picture and get the file `image`
            // where it was saved.
            final acquiredImage = await _controller.takePicture();

            if (!mounted) return;

            // If the picture was taken, save it in the local storage to show in the main screen.
            Uint8List imageBytes = await acquiredImage.readAsBytes();
            await WebPhotoStorage.savePhoto(imageBytes);

            // If the picture was taken, pass it to the upload screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UploadPhoto(
                  // Pass the automatically generated path to
                  // the DisplayPictureScreen widget.
                  acquiredImage: acquiredImage,
                ),
              ),
            );
          } catch (e) {
            // If an error occurs, log the error to the console.
            print(e);
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }

  double _getCameraAngle(Orientation orientation) {
    if (_controller.description.lensDirection == CameraLensDirection.front) {
      return -(_getOrientationAngle(orientation));
    } else {
      return _getOrientationAngle(orientation);
    }
  }

  double _getOrientationAngle(Orientation orientation) {
    switch (orientation) {
      case Orientation.portrait:
        return 0;
      case Orientation.landscape:
        return 0;
    }
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final String imagePath;

  const DisplayPictureScreen({super.key, required this.imagePath});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the Picture')),
      // The image is stored as a file on the device. Use the `Image.file`
      // constructor with the given path to display the image.
      body: Image.file(File(imagePath)),
    );
  }
}
