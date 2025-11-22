import 'package:flutter/material.dart';
import '../services/settings_service.dart';
import '../services/player_identity_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _nameController = TextEditingController();

  String _deviceName = '';
  String _playerDigest = '';
  bool _isLoading = true;
  bool _isSaving = false;
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final userName = await SettingsService.getUserName();
      final deviceName = await SettingsService.getDeviceName();
      final playerDigest = await PlayerIdentityService.getPlayerDigest();

      setState(() {
        _deviceName = deviceName;
        _playerDigest = playerDigest;
        _nameController.text = userName;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError('Kon instellingen niet laden: $e');
    }
  }

  Future<void> _saveName() async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    try {
      await SettingsService.setUserName(_nameController.text);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Naam opgeslagen!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError('Kon naam niet opslaan: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _resetToDeviceName() async {
    try {
      await SettingsService.resetToDeviceName();
      setState(() {
        _nameController.text = _deviceName;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Naam gereset naar apparaatnaam'),
          backgroundColor: Colors.blue,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      _showError('Kon naam niet resetten: $e');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Instellingen'),
        backgroundColor: Color(0xFF0D2E15),
        foregroundColor: Colors.white,
      ),
      backgroundColor: Color(0xFF06210F),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Gebruikersnaam',
                    icon: Icons.person,
                    children: [
                      Text(
                        'Deze naam wordt getoond aan andere spelers via Bluetooth.',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        style: TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: 'Naam',
                          labelStyle: TextStyle(color: Colors.grey[400]),
                          hintText: 'Voer je naam in',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[600]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.blue[400]!),
                          ),
                        ),
                        onSubmitted: (_) => _saveName(),
                      ),
                      SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveName,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                foregroundColor: Colors.white,
                              ),
                              child: _isSaving
                                  ? SizedBox(
                                      height: 20,
                                      width: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text('Opslaan'),
                            ),
                          ),
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: _resetToDeviceName,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[700],
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Apparaatnaam'),
                          ),
                        ],
                      ),
                      if (_deviceName.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(
                          'Apparaatnaam: $_deviceName',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: 24),
                  _buildSection(
                    title: 'Speler Identiteit',
                    icon: Icons.fingerprint,
                    children: [
                      Text(
                        'Unieke identificatie die je onderscheidt van andere spelers.',
                        style: TextStyle(color: Colors.grey[400]),
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.tag, color: Colors.blue[400]),
                            SizedBox(width: 8),
                            Text(
                              'ID: $_playerDigest',
                              style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.blue[400]),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}
