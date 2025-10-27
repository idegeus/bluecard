import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _playerNameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadPlayerName();
  }

  Future<void> _loadPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    final playerName = prefs.getString('player_name') ?? '';
    _playerNameController.text = playerName;
  }

  Future<void> _savePlayerName() async {
    if (_playerNameController.text.trim().isEmpty) {
      _showError('Player name cannot be empty');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('player_name', _playerNameController.text.trim());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Player name saved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save player name: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $message'),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _playerNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF0A4025),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Player Identity',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'This name will be shown to other players when you join games.',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _playerNameController,
              decoration: const InputDecoration(
                labelText: 'Player Name',
                hintText: 'Enter your player name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              maxLength: 20,
              textCapitalization: TextCapitalization.words,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePlayerName,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Saving...'),
                        ],
                      )
                    : const Text(
                        'Save Player Name',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'Game Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.bluetooth),
                title: const Text('Bluetooth'),
                subtitle: const Text('Manage Bluetooth connections'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  // TODO: Add Bluetooth settings
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bluetooth settings coming soon!'),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.info),
                title: const Text('About'),
                subtitle: const Text('App version and info'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  showAboutDialog(
                    context: context,
                    applicationName: 'BlueCard',
                    applicationVersion: '1.0.0',
                    applicationIcon: const Icon(Icons.style, size: 48),
                    children: const [
                      Text('A multiplayer card game using Bluetooth connectivity.'),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper class to get/set player name globally
class PlayerSettings {
  static Future<String> getPlayerName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('player_name') ?? 'Player';
  }
  
  static Future<void> setPlayerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_name', name);
  }
}