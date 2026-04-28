import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cultural_arts/upload_widget.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key});

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void>? _initializeControllerFuture;
  late List<CameraDescription> _cameras;
  late Stream<AccelerometerEvent> _orientationStream;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = null;
    _orientationStream = accelerometerEventStream();
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

      // Lock capture orientation after initialization completes
      // _initializeControllerFuture?.then((_) {
        // Allows to make the camera fullscreen, do not solve the image orientation error when device rotates
        // _controller.lockCaptureOrientation(DeviceOrientation.portraitUp);
      // });

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
              return Stack(
                fit: StackFit.expand,
                children: [
                  // Camera preview - handles its own rotation and aspect ratio
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: CameraPreview(_controller),
                      ),
                    ),
                  ),
                  // Orientation text overlay with live updates
                  StreamBuilder<AccelerometerEvent>(
                    stream: _orientationStream,
                    builder: (context, snapshot) {
                      final orientationText = _orientationFromAccelerometer(snapshot.data);
                      return Positioned(
                        top: 10,
                        left: 10,
                        right: 0,
                        child: Container(
                          decoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          child: Text(
                            orientationText,
                            style: const TextStyle(
                              color: Color.fromARGB(255, 0, 0, 0),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      );
                    },
                  ),
                ],
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

  String _orientationFromAccelerometer(AccelerometerEvent? event) {
    if (event == null) {
      return 'unknown';
    }

    final x = event.x;
    final y = event.y;

    if (x.abs() > y.abs()) {
      return x > 0 ? 'landscape-right' : 'landscape-left';
    }

    return y > 0 ? 'portrait-upside-down' : 'portrait';
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
