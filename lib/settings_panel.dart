import 'package:flutter/material.dart';
import 'package:cultural_arts/utils/web_storage.dart';

class SettingsPanel extends StatefulWidget {
  final VoidCallback onChanged;
  const SettingsPanel({required this.onChanged});

  @override
  State<SettingsPanel> createState() => SettingsPanelState();
}

class SettingsPanelState extends State<SettingsPanel> {
  late bool _offlineMode;

  @override
  void initState() {
    super.initState();
    _offlineMode = WebSettingsStorage.getOfflineMode();
  }

  Future<void> _confirmDeleteAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete all photos?"),
        content:
            const Text("This will permanently remove all stored images."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Delete")),
        ],
      ),
    );
    if (confirm == true) {
      await WebPhotoStorage.clear();
      widget.onChanged();
      if (mounted) Navigator.pop(context); // close panel
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Settings',
              style:
                  TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Divider(height: 28),

          // Offline mode toggle
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Offline mode'),
            subtitle: const Text('Skip API calls, save locally only'),
            value: _offlineMode,
            onChanged: (val) {
              WebSettingsStorage.setOfflineMode(val); // implement in WebSettingsStorage
              setState(() => _offlineMode = val);
            },
          ),
          const Divider(height: 28),

          // Delete all photos
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
                const Icon(Icons.delete_forever, color: Colors.red),
            title: const Text('Delete all photos',
                style: TextStyle(color: Colors.red)),
            onTap: _confirmDeleteAll,
          ),
        ],
      ),
    );
  }
}