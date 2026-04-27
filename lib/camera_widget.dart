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
  late Orientation _currentOrientation; // Track current orientation
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _deviceRotation = 0; // Device rotation in degrees

  @override
  void initState() {
    super.initState();
    _initializeControllerFuture = null;
    _currentOrientation = Orientation.portrait; // Default to portrait
    _startOrientationDetection();
    _initializeCamera();
  }

  void _startOrientationDetection() {
    _accelerometerSubscription = accelerometerEventStream().listen((AccelerometerEvent event) {
      // Calculate device rotation based on accelerometer data
      double rotation = math.atan2(event.y, event.x) * (180 / math.pi);
      
      // Normalize to 0-360 degrees
      if (rotation < 0) rotation += 360;
      
      // Determine orientation based on rotation
      Orientation newOrientation;
      if ((rotation >= 45 && rotation < 135) || 
          (rotation >= 225 && rotation < 315)) {
        newOrientation = Orientation.landscape;
      } else {
        newOrientation = Orientation.portrait;
      }
      
      if (newOrientation != _currentOrientation && mounted) {
        setState(() {
          _currentOrientation = newOrientation;
          _deviceRotation = rotation;
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
              return OrientationBuilder(
                builder: (context, orientation) {
                  // Use detected device orientation instead of app orientation
                  return Transform.rotate(
                    angle: _getCameraAngle(_currentOrientation),
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

            // Capture the current device rotation when the picture is taken
            double captureRotation = _deviceRotation;

            // Read the image bytes
            Uint8List imageBytes = await acquiredImage.readAsBytes();
            
            // Rotate the image based on device orientation and camera sensor
            imageBytes = await _rotateImageByDeviceOrientation(imageBytes, captureRotation);

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
        return math.pi / 2; // 90 degrees in radians
    }
  }

  Future<Uint8List> _rotateImageByDeviceOrientation(Uint8List imageBytes, double deviceRotation) async {
    try {
      // Decode the image
      img.Image? image = img.decodeImage(imageBytes);
      
      if (image == null) {
        return imageBytes; // Return original if decode fails
      }

      // Get camera sensor orientation
      int sensorOrientation = _controller.description.sensorOrientation;
      
      // Calculate total rotation needed
      // Camera sensor orientation + device rotation
      int totalRotation = (sensorOrientation + deviceRotation.round()) % 360;
      
      // Normalize to 0, 90, 180, 270
      if (totalRotation >= 315 || totalRotation < 45) {
        totalRotation = 0;
      } else if (totalRotation >= 45 && totalRotation < 135) {
        totalRotation = 90;
      } else if (totalRotation >= 135 && totalRotation < 225) {
        totalRotation = 180;
      } else {
        totalRotation = 270;
      }

      // Rotate the image based on calculated rotation
      img.Image rotatedImage;
      switch (totalRotation) {
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

      // Encode back to bytes
      return Uint8List.fromList(img.encodeJpg(rotatedImage));
    } catch (e) {
      print('Error rotating image: $e');
      return imageBytes; // Return original if rotation fails
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
