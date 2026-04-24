import 'package:cultural_arts/utils/geo_utilities.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';


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

/// ---------------------------
/// APP
/// ---------------------------

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  LocationPermission permission = LocationPermission.unableToDetermine;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final result = await LocationService.checkPermission();
    setState(() {
      permission = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cultural Arts',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromRGBO(41, 182, 246, 1),
        ),
        useMaterial3: true,
      ),
      home: _buildHome(),
    );
  }

  Widget _buildHome() {
    switch (permission) {
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return const MyHomePage(title: 'Cultural Arts');

      case LocationPermission.denied:
      case LocationPermission.deniedForever:
        if (useFakeLocation) {
          return const MyHomePage(title: 'Cultural Arts (DEV MODE)');
        }
        return LocationPermissionWidget(onRetry: _init);

      default:
        return const LoadingScreen();
    }
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
  const LoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

/// ---------------------------
/// HOME
/// ---------------------------

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

  @override
Widget build(BuildContext context) {
  final photos = WebPhotoStorage.getPhotos();

  return Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
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
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    ),

    // ----------------------------
    // ALWAYS VISIBLE CAMERA BUTTON
    // ----------------------------
    floatingActionButton: FloatingActionButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const CameraScreen(),
          ),
        );
      },
      child: const Icon(Icons.add_a_photo),
    ),
  );
}
}