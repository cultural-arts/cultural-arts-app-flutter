import 'package:cultural_arts/utils/geo_utilities.dart';
import 'package:cultural_arts/utils/web_storage.dart';
import 'package:cultural_arts/models/photo_record.dart';
import 'package:cultural_arts/photo_detail_screen.dart';
import 'package:cultural_arts/widgets/ai_disclosure.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'camera_screen.dart'; // Import the camera screen file
import 'package:hive_flutter/hive_flutter.dart';

// final log = Logger('Main');

void main() async {
  // hive stuff
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox('photos');
  await WebPhotoStorage.migrateLegacyPhotos();
  await WebPhotoStorage.markInterruptedGenerations();

  // main app
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
  // Initialize a variable to track whether location data has been loaded
  late LocationPermission permission = LocationPermission.unableToDetermine;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final result = await LocationService.checkPermission();
    if (!mounted) return;
    setState(() {
      permission = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'cultural-arts.com',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color.fromRGBO(41, 182, 246, 1)),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          displaySmall: TextStyle(
            fontSize: 32,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          headlineMedium: TextStyle(
            fontSize: 24,
            height: 1.2,
            fontWeight: FontWeight.w700,
          ),
          headlineSmall: TextStyle(
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            fontSize: 20,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            height: 1.35,
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: TextStyle(fontSize: 16, height: 1.55),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45),
          bodySmall: TextStyle(fontSize: 12, height: 1.4),
          labelLarge: TextStyle(
            fontSize: 14,
            height: 1.3,
            fontWeight: FontWeight.w600,
          ),
        ),
        useMaterial3: true,
      ),
      home: _buildHomeWidget(permission, _init),
    );
  }
}

Widget _buildHomeWidget(
    LocationPermission permission, void Function() askForLocationsPermission) {
  final loadingMessageNotifier = ValueNotifier<String>(
      "You can't deny basic serives as camera or internet connections by using this app...");

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
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ));
  }
}

class MyHomePage extends StatefulWidget {
  final String title;

  const MyHomePage({super.key, required this.title});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
    final photos = WebPhotoStorage.getPhotoRecords();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: _showVersionDialog,
          child: Text(widget.title),
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            tooltip: 'Delete all photos',
            icon: const Icon(Icons.delete_forever),
            onPressed: photos.isEmpty
                ? null
                : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Delete all photos?'),
                        content: const Text(
                          'This will permanently remove all saved photos and descriptions.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('Delete'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await WebPhotoStorage.clear();
                      if (mounted) setState(() {});
                    }
                  },
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (useFakeLocation)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Chip(label: Text('DEV MODE - FAKE LOCATION')),
                    ),
                  Text(
                    'Discover cultural heritage',
                    style: theme.textTheme.displaySmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Capture a place or artwork and explore the story behind it.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 16),
                  const AiDisclosureCard(),
                  if (photos.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    Text('Your discoveries', style: theme.textTheme.titleLarge),
                  ],
                ],
              ),
            ),
          ),
          if (photos.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.photo_camera_outlined,
                        size: 48,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Your discoveries will appear here',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Take your first photo to get started.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildPhotoCard(photos[index]),
                  childCount: photos.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 270,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Take a photo',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CameraScreen(),
            ),
          );

          if (mounted) setState(() {});
        },
        icon: const Icon(Icons.add_a_photo),
        label: const Text('Take a photo'),
      ),
    );
  }

  Widget _buildPhotoCard(PhotoRecord photo) {
    final theme = Theme.of(context);
    final subtitle = switch (photo.status) {
      PhotoGenerationStatus.ready => photo.description!,
      PhotoGenerationStatus.pending => 'Generating your description…',
      PhotoGenerationStatus.failed => 'Description unavailable · Tap to retry',
      PhotoGenerationStatus.notGenerated => 'Generate an AI description',
    };

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context)
            .push(
          MaterialPageRoute<void>(
            builder: (_) => PhotoDetailScreen(photoId: photo.id),
          ),
        )
            .then((_) {
          if (mounted) setState(() {});
        }),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.memory(
                    photo.imageBytes,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    semanticLabel: 'Saved cultural heritage photo',
                  ),
                  if (photo.status == PhotoGenerationStatus.pending)
                    const Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: LinearProgressIndicator(),
                    ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formattedDate(photo.capturedAt),
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 4),
                    if (photo.status == PhotoGenerationStatus.ready)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: AiGeneratedBadge(),
                      ),
                    Expanded(
                      child: Text(
                        subtitle,
                        maxLines:
                            photo.status == PhotoGenerationStatus.ready ? 2 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formattedDate(DateTime date) {
    final localDate = date.toLocal();
    final month = localDate.month.toString().padLeft(2, '0');
    final day = localDate.day.toString().padLeft(2, '0');
    return '$month/$day/${localDate.year}';
  }
}
