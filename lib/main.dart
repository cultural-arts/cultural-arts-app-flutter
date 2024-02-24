import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart'; // Import the camera screen file

void main() {
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title),
            const SizedBox(height: 8),
            const Text(
              "Bio Colonization Detection v0.1",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          // Use ColorFiltered to apply opacity to the background image
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              const Color.fromARGB(255, 255, 255, 255)
                  .withOpacity(0.90), // Adjust the opacity as needed
              BlendMode.srcOver,
            ),
            child: Image.asset(
              'assets/images/take_statue_picture.png',
              fit: BoxFit.contain,
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
            ),
          ),
          Center(
            // Ensure the Column is centered within the Stack
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const Text(
                  'Detect defects in arts by taking a picture!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: Colors.black), // Adjust the color as needed
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0), // Adjust the padding as needed
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: const TextSpan(
                      text: 'Interested in ',
                      style: TextStyle(fontSize: 16, color: Colors.black),
                      children: [
                        TextSpan(
                          text: 'high-resolution outcomes',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: ' or',
                        ),
                        TextSpan(
                          text: ' integration with a surveillance camera',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: '? Contact us at ',
                        ),
                        TextSpan(
                          text: 'info@cultural-arts.com',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'NOTICE: maximum 100 calls/day per ip due to computational resources',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.black), // Adjust the color as needed
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CameraScreen(),
            ),
          );
        },
        tooltip: 'Take picture',
        child: const Icon(Icons.add_a_photo),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }
}
