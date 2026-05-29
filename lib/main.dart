import 'package:cultural_arts/settings_panel.dart';
import 'package:cultural_arts/upload_photo_screen.dart';
import 'package:cultural_arts/utils/geo_utilities.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('photos');
  await Hive.openBox('settings');
  runApp(const MyApp());
}

/// ---------------------------
/// CONFIG
/// ---------------------------

const bool useFakeLocation = kDebugMode;
const String appVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: 'unknown');
const String appEnv = String.fromEnvironment('APP_ENV',
    defaultValue: kReleaseMode ? 'production' : 'development');

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
    setState(() => permission = result);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cultural-arts.com',
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
        return const MyHomePage(title: 'cultural-arts.com');
      case LocationPermission.denied:
      case LocationPermission.deniedForever:
        if (useFakeLocation) {
          return const MyHomePage(title: 'cultural-arts.com (DEV MODE)');
        }
        return LocationPermissionWidget(onRetry: _init);
      default:
        return const LoadingScreen();
    }
  }
}

/// ---------------------------
/// UI WIDGETS (unchanged)
/// ---------------------------

class LocationPermissionWidget extends StatelessWidget {
  final VoidCallback onRetry;
  const LocationPermissionWidget({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Location permission is required to use this app.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                  onPressed: onRetry,
                  child: const Text('Retry permission')),
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
        body: Center(child: CircularProgressIndicator()));
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
    setState(() => position = pos);
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
              child: const Text('Close')),
        ],
      ),
    );
  }

  // NEW ─ Settings bottom sheet
  void _showSettingsPanel() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SettingsPanel(onChanged: () => setState(() {})),
    );
  }

  // NEW ─ Pick local photos and push UploadLocalPhotosScreen
  Future<void> _pickAndUploadLocalPhotos() async {
    final List<StorageContainer> photos = WebPhotoStorage.getPhotos();
    if (!photos.isNotEmpty) return;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UploadLocalPhotosScreen(),
      ),
    );
    setState(() {}); // refresh grid after upload
  }

  @override
  Widget build(BuildContext context) {
    final photos = WebPhotoStorage.getPhotos();
    final pendingUploads = photos.where((photo) => !photo.isUploaded).length;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showVersionDialog,
          child: Text(widget.title),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          // NEW ─ Upload local photos button with pending count badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              IconButton(
                icon: const Icon(Icons.upload),
                tooltip: 'Upload local photos',
                onPressed: _pickAndUploadLocalPhotos,
              ),
              if (pendingUploads > 0)
                Positioned(
                  right: 6,
                  top: 20,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 11,
                      minHeight: 11,
                    ),
                    child: Text(
                      '$pendingUploads',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          // CHANGED ─ Was delete, now opens settings panel
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Settings',
            onPressed: _showSettingsPanel,
          ),
        ],
      ),

      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/images/take_statue_picture.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          if (useFakeLocation)
            const Positioned(
              top: 40,
              left: 20,
              child: Chip(label: Text("DEV MODE - FAKE LOCATION")),
            ),
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
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(photos[index].imageBytes,
                        fit: BoxFit.cover),
                  ),
                ),
              ),
            ),
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

      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(context,
              MaterialPageRoute(builder: (_) => const CameraScreen()));
          setState(() {});
        },
        child: const Icon(Icons.add_a_photo),
      ),
    );
  }
}
