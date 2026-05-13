import 'package:cultural_arts/utils/geo_utilities.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart'; // Import the camera screen file
import 'dart:async';
import 'onnx_vlm.dart';
import 'dart:js_interop';
import 'package:hive_flutter/hive_flutter.dart';

// final log = Logger('Main');

void main() async {
  // hive stuff
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('photos');

  // main app
  runApp(const MyApp());
}

/// ---------------------------
/// CONFIG
/// ---------------------------

const bool useFakeLocation = kDebugMode;
const String appVersion = String.fromEnvironment('APP_VERSION', defaultValue: 'unknown');
const String appEnv = String.fromEnvironment('APP_ENV', defaultValue: kReleaseMode ? 'production' : 'development');

/// ---------------------------
/// APP
/// ---------------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {

  final loadingMessageNotifier = ValueNotifier<String>("Loading AI Models, please wait...");

  // Initialize a variable to track whether location data has been loaded
  late Future<bool> vlmLoadingFuture;
  late LocationPermission permission = LocationPermission.unableToDetermine;

  @override
  void initState() {
    super.initState();
    // Call initPosition() asynchronously and wait for it to complete
    updateUILoadingSteps = updateLoadingSteps.toJS;
    vlmLoadingFuture = loadNanoVLM().toDart as Future<bool>;
    _init();
  }

  Future<void> _init() async {
    final result = await LocationService.checkPermission();
    setState(() {
      permission = result;
    });
  }

  void updateLoadingSteps(JSString text){
    loadingMessageNotifier.value = text.toDart;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cultural-arts.com',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromRGBO(41, 182, 246, 1)),
        useMaterial3: true,
      ),
      home: FutureBuilder<bool>(
        future: vlmLoadingFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show spinner while VLM loads
            return LoadingScreen(notifier: loadingMessageNotifier); 
          } else if (snapshot.hasError || snapshot.data == false) {
            // Show error if loading fails
            return const ErrorScreen(); 
          }
          // Check location permission
          return _buildHomeWidget(permission, _init);
        },
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  const ErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text("Failed to load SmolVLM. Please try again.")),
    );
  }
}

Widget _buildHomeWidget(LocationPermission permission, void Function() askForLocationsPermission) {

  final loadingMessageNotifier = ValueNotifier<String>("You can't deny basic serives as camera or internet connections by using this app...");

  switch (permission) {
    case LocationPermission.whileInUse:
      return const MyHomePage(title: 'cultural-arts.com');
    case LocationPermission.always:
      return const MyHomePage(title: 'cultural-arts.com');
    case LocationPermission.denied:
      return LocationPermissionWidget(onRetry: askForLocationsPermission);
    case LocationPermission.deniedForever:
      return LocationPermissionWidget(onRetry: askForLocationsPermission);
    default:
      return LoadingScreen(notifier: loadingMessageNotifier);
  }
}

/// ---------------------------
/// UI WIDGETS
/// ---------------------------

class LocationPermissionWidget extends StatelessWidget {
  final VoidCallback onRetry;

  const LocationPermissionWidget({
    super.key,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Location permission is required to use this app.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onRetry,
                child: const Text('Retry permission'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LoadingScreen extends StatelessWidget {
  final ValueNotifier<String> notifier;

  const LoadingScreen({super.key, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ValueListenableBuilder(
          valueListenable: notifier,
          builder: (context, message, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  message,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
        ),
      )
    );
  }
}


class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Position? position;

  @override
  void initState() {
    super.initState();
    _loadPosition();
  }

  Future<void> _loadPosition() async {
    final pos = await LocationService.getPosition();
    setState(() {
      position = pos;
    });
  }

  void _showVersionDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/official_logo_bw.png', height: 80),
            const SizedBox(height: 16),
            const Text('Environment: $appEnv\nVersion: $appVersion'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = WebPhotoStorage.getPhotos();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showVersionDialog,
          child: Text(widget.title),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text("Delete all photos?"),
                  content: const Text(
                    "This will permanently remove all stored images.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text("Cancel"),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text("Delete"),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await WebPhotoStorage.clear();
                setState(() {});
              }
            },
          ),
        ],
      ),

      body: Stack(
        children: [
          // ----------------------------
          // BACKGROUND / EMPTY STATE
          // ----------------------------
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/take_statue_picture.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // ----------------------------
          // DEV MODE INDICATOR
          // ----------------------------
          if (useFakeLocation)
            const Positioned(
              top: 40,
              left: 20,
              child: Chip(
                label: Text("DEV MODE - FAKE LOCATION"),
              ),
            ),

          // ----------------------------
          // PHOTO GRID (IF EXISTS)
          // ----------------------------
          if (photos.isNotEmpty)
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: GridView.builder(
                  itemCount: photos.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemBuilder: (context, index) {
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.memory(
                        photos[index],
                        fit: BoxFit.cover,
                      ),
                    );
                  },
                ),
              ),
            ),

          // ----------------------------
          // EMPTY STATE MESSAGE
          // ----------------------------
          if (photos.isEmpty)
            const Center(
              child: Text(
                "No photos yet.\nStart capturing cultural heritage!",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color.fromARGB(255, 0, 0, 0),
                  fontSize: 20,
                  fontFamily: 'Roboto',
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),

      // ----------------------------
      // ALWAYS VISIBLE CAMERA BUTTON
      // ----------------------------
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CameraScreen(),
            ),
          );

          setState(() {}); // refresh
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
