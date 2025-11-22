import 'package:flutter/material.dart';
import '../services/bluetooth_host.dart';

class HostGameScreen extends StatefulWidget {
  final BluetoothHost bluetoothHost;

  const HostGameScreen({super.key, required this.bluetoothHost});

  @override
  State<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  final List<String> _messages = [];
  int _playerCount = 1; // Start met host
  DateTime? _lastSync;

  @override
  void initState() {
    super.initState();
    _playerCount = widget.bluetoothHost.totalPlayerCount;
    _lastSync = widget.bluetoothHost.lastSyncTime;
    _setupListeners();
  }

  void _setupListeners() {
    // Luister naar berichten
    widget.bluetoothHost.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
          if (_messages.length > 50) {
            _messages.removeLast();
          }
        });
      }
    });

    // Luister naar player IDs updates voor rebuild
    widget.bluetoothHost.playerIdsStream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });

    // Luister naar laatste sync updates
    widget.bluetoothHost.lastSyncStream.listen((time) {
      if (mounted) {
        setState(() {
          _lastSync = time;
        });
      }
    });
  }

  Future<void> _sendPing() async {
    try {
      await widget.bluetoothHost.sendPing();
    } catch (e) {
      _showError('Fout bij verzenden ping: $e');
    }
  }

  void _showConnectionInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[850],
        title: Text('Spelverbinding', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              Icons.people,
              'Spelers',
              '$_playerCount (inclusief host)',
            ),
            SizedBox(height: 12),
            _buildInfoRow(Icons.wifi, 'Status', 'Verbonden'),
            SizedBox(height: 12),
            _buildInfoRow(
              Icons.sync,
              'Laatste sync',
              _lastSync != null
                  ? '${_lastSync!.hour.toString().padLeft(2, '0')}:${_lastSync!.minute.toString().padLeft(2, '0')}:${_lastSync!.second.toString().padLeft(2, '0')}'
                  : 'Nog niet gesynchroniseerd',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Sluiten', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.blue, size: 20),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFF0D2E15),
        foregroundColor: Colors.white,
        title: Text('Spel'),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: Icon(Icons.info_outline),
            tooltip: 'Verbindingsinfo',
            onPressed: _showConnectionInfo,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0D2E15), Color(0xFF06210F), Color(0xFF04170B)],
          ),
        ),
        child: Column(
          children: [
            // Status kaart
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.videogame_asset,
                        color: Colors.green,
                        size: 32,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Game Actief',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Als: ${widget.bluetoothHost.playerId} | $_playerCount spelers',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _sendPing,
                      icon: Icon(Icons.wifi_tethering),
                      label: Text('Stuur Ping'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Berichten log
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.article, color: Colors.grey[600], size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Berichten Log',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(height: 12),

            // Berichten lijst
            Expanded(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _messages.isEmpty
                    ? Center(
                        child: Text(
                          'Geen berichten',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _messages.length,
                        padding: EdgeInsets.all(8),
                        itemBuilder: (context, index) {
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              _messages[index],
                              style: TextStyle(
                                color: Colors.grey[300],
                                fontSize: 12,
                                fontFamily: 'monospace',
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
