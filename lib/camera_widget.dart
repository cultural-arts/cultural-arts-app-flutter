import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cultural_arts/upload_widget.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:math' as math; // Import the math library

enum _DeviceOrientation {
  portraitUp,
  landscapeRight,
  portraitDown,
  landscapeLeft,
}

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
  late _DeviceOrientation _currentDeviceOrientation;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = null;
    _currentDeviceOrientation = _DeviceOrientation.portraitUp;
    _startOrientationDetection();
    _initializeCamera();
  }

  void _startOrientationDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      final double x = event.x;
      final double y = event.y;
      final double absX = x.abs();
      final double absY = y.abs();

      _DeviceOrientation newOrientation;
      if (absX > absY) {
        newOrientation = x > 0
            ? _DeviceOrientation.landscapeRight
            : _DeviceOrientation.landscapeLeft;
      } else {
        newOrientation = y > 0
            ? _DeviceOrientation.portraitDown
            : _DeviceOrientation.portraitUp;
      }

      if (newOrientation != _currentDeviceOrientation && mounted) {
        setState(() {
          _currentDeviceOrientation = newOrientation;
        });
      }
    });
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
    _accelerometerSubscription?.cancel();
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
              return Transform.rotate(
                angle: _previewRotationAngle(_currentDeviceOrientation),
                child: Center(
                  child: AspectRatio(
                    aspectRatio: _previewAspectRatio(_currentDeviceOrientation),
                    child: CameraPreview(_controller),
                  ),
                ),
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

            // Read the image bytes
            Uint8List imageBytes = await acquiredImage.readAsBytes();
            
            // Rotate the image based on device orientation and camera sensor
            imageBytes = await _rotateImageByDeviceOrientation(imageBytes, _currentDeviceOrientation);

            // If the picture was taken, save it in the local storage to show in the main screen.
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

  double _previewRotationAngle(_DeviceOrientation orientation) {
    switch (orientation) {
      case _DeviceOrientation.portraitUp:
        return 0;
      case _DeviceOrientation.landscapeRight:
        return -math.pi / 2;
      case _DeviceOrientation.portraitDown:
        return math.pi;
      case _DeviceOrientation.landscapeLeft:
        return math.pi / 2;
    }
  }

  double _previewAspectRatio(_DeviceOrientation orientation) {
    final aspectRatio = _controller.value.aspectRatio;
    if (orientation == _DeviceOrientation.landscapeRight || orientation == _DeviceOrientation.landscapeLeft) {
      return 1 / aspectRatio;
    }
    return aspectRatio;
  }

  int _deviceRotationDegrees(_DeviceOrientation orientation) {
    switch (orientation) {
      case _DeviceOrientation.portraitUp:
        return 0;
      case _DeviceOrientation.landscapeRight:
        return 90;
      case _DeviceOrientation.portraitDown:
        return 180;
      case _DeviceOrientation.landscapeLeft:
        return 270;
    }
  }

  Future<Uint8List> _rotateImageByDeviceOrientation(Uint8List imageBytes, _DeviceOrientation deviceOrientation) async {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      if (image == null) {
        return imageBytes; // Return original if decode fails
      }

      // Get camera sensor orientation
      final int sensorOrientation = _controller.description.sensorOrientation;
      final int deviceRotation = _deviceRotationDegrees(deviceOrientation);

      // Calculate rotation needed for upright image.
      final int totalRotation = (_controller.description.lensDirection == CameraLensDirection.front)
          ? (sensorOrientation + deviceRotation) % 360
          : (sensorOrientation - deviceRotation + 360) % 360;

      int rotation;
      if (totalRotation < 45 || totalRotation >= 315) {
        rotation = 0;
      } else if (totalRotation < 135) {
        rotation = 90;
      } else if (totalRotation < 225) {
        rotation = 180;
      } else {
        rotation = 270;
      }

      img.Image rotatedImage;
      switch (rotation) {
        case 90:
          rotatedImage = img.copyRotate(image, angle: 90);
          break;
        case 180:
          rotatedImage = img.copyRotate(image, angle: 180);
          break;
        case 270:
          rotatedImage = img.copyRotate(image, angle: 270);
          break;
        default:
          rotatedImage = image;
      }

      return Uint8List.fromList(img.encodeJpg(rotatedImage));
    } catch (e) {
      print('Error rotating image: $e');
      return imageBytes;
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
