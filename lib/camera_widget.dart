import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:cultural_arts/upload_widget.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';

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
  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  double _zoomLevel = 1;
  double _zoomAtScaleStart = 1;
  double? _pendingZoomLevel;
  bool _isApplyingZoom = false;
  Offset? _focusIndicatorPosition;
  Timer? _focusIndicatorTimer;

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
      _controller = CameraController(_cameras.last, ResolutionPreset.high,
          enableAudio: false, imageFormatGroup: ImageFormatGroup.jpeg);

      _initializeControllerFuture = _controller.initialize().then((_) async {
        final minZoomLevel = await _controller.getMinZoomLevel();
        final maxZoomLevel = await _controller.getMaxZoomLevel();
        if (!mounted) return;
        setState(() {
          _minZoomLevel = minZoomLevel;
          _maxZoomLevel = maxZoomLevel;
          _zoomLevel = minZoomLevel;
        });
      });

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
    _focusIndicatorTimer?.cancel();
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
          // Wait until the controller is initialized before displaying the
          // camera preview. Use a FutureBuilder to display a loading spinner until the
          // controller has finished initializing.
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  Positioned.fill(
                    child: FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height,
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final previewSize = Size(
                              constraints.maxWidth,
                              constraints.maxHeight,
                            );
                            final focusIndicatorPosition =
                                _focusIndicatorPosition;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTapUp: (details) => _focusAt(
                                details.localPosition,
                                previewSize,
                              ),
                              onScaleStart: (_) {
                                _zoomAtScaleStart = _zoomLevel;
                              },
                              onScaleUpdate: (details) {
                                final zoomLevel =
                                    (_zoomAtScaleStart * details.scale).clamp(
                                  _minZoomLevel,
                                  _maxZoomLevel,
                                );
                                _setZoomLevel(zoomLevel.toDouble());
                              },
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  CameraPreview(_controller),
                                  if (focusIndicatorPosition != null)
                                    Positioned(
                                      left: (focusIndicatorPosition.dx - 32)
                                          .clamp(0, previewSize.width - 64)
                                          .toDouble(),
                                      top: (focusIndicatorPosition.dy - 32)
                                          .clamp(0, previewSize.height - 64)
                                          .toDouble(),
                                      child: const IgnorePointer(
                                        child: Icon(
                                          Icons.center_focus_weak,
                                          color: Colors.white,
                                          size: 64,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
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
            final photoId = await WebPhotoStorage.savePhoto(imageBytes);

            // If the picture was taken, pass it to the upload screen.
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => UploadPhoto(
                  photoId: photoId,
                  imageBytes: imageBytes,
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

  Future<void> _focusAt(Offset position, Size previewSize) async {
    if (previewSize.isEmpty || !_controller.value.isInitialized) return;

    final focusPoint = Offset(
      (position.dx / previewSize.width).clamp(0.0, 1.0),
      (position.dy / previewSize.height).clamp(0.0, 1.0),
    );

    try {
      await _controller.setFocusPoint(focusPoint);
      try {
        await _controller.setExposurePoint(focusPoint);
      } on CameraException catch (error) {
        debugPrint('Unable to set camera exposure point: ${error.description}');
      }

      if (!mounted) return;
      _focusIndicatorTimer?.cancel();
      setState(() => _focusIndicatorPosition = position);
      _focusIndicatorTimer = Timer(const Duration(seconds: 1), () {
        if (mounted) setState(() => _focusIndicatorPosition = null);
      });
    } on CameraException catch (error) {
      debugPrint('Unable to set camera focus point: ${error.description}');
    }
  }

  void _setZoomLevel(double zoomLevel) {
    _zoomLevel = zoomLevel;
    _pendingZoomLevel = zoomLevel;
    if (_isApplyingZoom) return;
    _applyPendingZoom();
  }

  Future<void> _applyPendingZoom() async {
    _isApplyingZoom = true;
    try {
      while (_pendingZoomLevel != null && mounted) {
        final zoomLevel = _pendingZoomLevel!;
        _pendingZoomLevel = null;
        try {
          await _controller.setZoomLevel(zoomLevel);
        } on CameraException catch (error) {
          debugPrint('Unable to set camera zoom: ${error.description}');
          _pendingZoomLevel = null;
        }
      }
    } finally {
      _isApplyingZoom = false;
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
