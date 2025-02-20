import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart'; // Import the camera screen file
import 'dart:async';
import 'transformers.dart';

Future<void> runTransformers() async {

  await Future.doWhile(() async {
    await Future.delayed(Duration(milliseconds: 500));
    return !isAnalyzeSentimentReady;
  });

  // pipeline returns a Promise (JSPromise), we do not call await 
  var partial = await analyzeSentiment("How love you?").toDart;
  print(partial);
}

Future<void> main() async{

  runTransformers();

  runApp(const MyApp());
}

Future<LocationPermission> initPosition() async {
  bool serviceEnabled;
  LocationPermission permission;

  // Check if location services are enabled
  serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return LocationPermission.unableToDetermine;
  }

  // Request location permission
  permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied ||
      permission == LocationPermission.deniedForever) {
    return await Geolocator.requestPermission();
  }

  return permission;
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // Initialize a variable to track whether location data has been loaded
  late LocationPermission locationDataState =
      LocationPermission.unableToDetermine;

  void updateLocationDataState() {
    initPosition().then((value) {
      setState(() {
        locationDataState = value;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    // Call initPosition() asynchronously and wait for it to complete
    updateLocationDataState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cultural-arts.com app',
      theme: ThemeData(
        colorScheme:
            ColorScheme.fromSeed(seedColor: Color.fromRGBO(41, 182, 246, 1)),
        useMaterial3: true,
      ),
      home: _buildHomeWidget(locationDataState, updateLocationDataState),
    );
  }
}

Widget _buildHomeWidget(LocationPermission locationDataState,
    void Function() askForLocationsPermission) {
  switch (locationDataState) {
    case LocationPermission.whileInUse:
      return const MyHomePage(title: 'cultural-arts.com');
    case LocationPermission.always:
      return const MyHomePage(title: 'cultural-arts.com');
    case LocationPermission.denied:
      return LocationPermissionWidget(
        onPermissionRequested: () {
          askForLocationsPermission();
        },
      );
    case LocationPermission.deniedForever:
      return LocationPermissionWidget(
        onPermissionRequested: () {
          askForLocationsPermission();
        },
      );
    default:
      return const LoadingScreen();
  }
}

class LocationPermissionWidget extends StatelessWidget {
  final VoidCallback onPermissionRequested;

  const LocationPermissionWidget(
      {super.key, required this.onPermissionRequested});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        const Text(
          'To use this app, we need your location permission.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () {
            // Call the provided callback to request location permission
            onPermissionRequested();
          },
          child: const Text('Grant Location Permission'),
        ),
      ],
    );
  }
}

class LoadingScreen extends StatelessWidget {
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(), // Show a loading indicator
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool enableTakePicture = false;

  void _enableCameraPreview() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method
      enableTakePicture = true;
    });
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/take_statue_picture.png'),
            fit: BoxFit.cover, // You can adjust the fit as needed
          ),
        ),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
          ),
          itemCount: 0,
          itemBuilder: (BuildContext context, int index) {
            return Card(
              child: Center(
                child: Text('Item $index'),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  const CameraScreen(), // Navigate to CameraScreen
            ),
          );
        },
        tooltip: 'Take picture',
        child: const Icon(Icons.add_a_photo),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
