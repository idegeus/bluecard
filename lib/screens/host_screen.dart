import 'package:flutter/material.dart';
import '../services/bluetooth_host.dart';
import '../services/game_service.dart';

class HostScreen extends StatefulWidget {
  const HostScreen({Key? key}) : super(key: key);

  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  final BluetoothHost _bluetoothHost = BluetoothHost();
  final GameService _gameService = GameService();
  
  final List<String> _messages = [];
  bool _isServerStarted = false;
  int _clientCount = 0;
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
    _requestPermissions();
  }
  
  void _setupListeners() {
    // Luister naar Bluetooth berichten
    _bluetoothHost.messageStream.listen((message) {
      print('📬 [HostScreen] Received message: $message');
      setState(() {
        _messages.insert(0, message);
        if (_messages.length > 50) {
          _messages.removeLast();
        }
      });
    });
    
    // Luister naar client count updates
    _bluetoothHost.clientCountStream.listen((count) {
      print('📊 [HostScreen] Client count update: $count');
      setState(() {
        _clientCount = count;
      });
    });
    
    // Luister naar game events
    _gameService.eventStream.listen((event) {
      setState(() {
        _messages.insert(0, event);
        if (_messages.length > 50) {
          _messages.removeLast();
        }
      });
    });
  }
  
  Future<void> _requestPermissions() async {
    // Permissions worden automatisch gevraagd door flutter_blue_plus
    // bij het eerste gebruik
  }
  
  Future<void> _startServer() async {
    try {
      await _bluetoothHost.startServer();
      _gameService.initializeGame();
      
      setState(() {
        _isServerStarted = true;
      });
    } catch (e) {
      _showError('Fout bij starten server: $e');
    }
  }
  
  Future<void> _stopServer() async {
    await _bluetoothHost.stopServer();
    setState(() {
      _isServerStarted = false;
    });
  }
  
  Future<void> _sendTestNotification() async {
    await _bluetoothHost.sendNotificationToClients(
      '🧪 Test melding van host! Tijd: ${DateTime.now().toString().substring(11, 19)}'
    );
  }
  
  Future<void> _testCallback() async {
    await _bluetoothHost.testNativeCallback();
  }
  
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  @override
  void dispose() {
    _bluetoothHost.dispose();
    _gameService.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Host'),
        backgroundColor: Colors.green[700],
        actions: [
          if (_isServerStarted)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: Colors.green[300]),
                    SizedBox(width: 8),
                    Text('$_clientCount clients'),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: Column(
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
                      _isServerStarted ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _isServerStarted ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isServerStarted ? 'Server actief' : 'Server gestopt',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _isServerStarted 
                                ? 'Wachten op clients...'
                                : 'Start de server om te beginnen',
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
                
                if (!_isServerStarted) ...[
                  SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _startServer,
                      icon: Icon(Icons.play_arrow),
                      label: Text('Start Server'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
                
                if (_isServerStarted) ...[
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendTestNotification,
                          icon: Icon(Icons.notifications),
                          label: Text('Test Melding'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _testCallback,
                          icon: Icon(Icons.bug_report),
                          label: Text('Debug'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _stopServer,
                        icon: Icon(Icons.stop),
                        label: Text('Stop'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),
                ],
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
          
          SizedBox(height: 8),
          
          Expanded(
            child: Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[800]!),
              ),
              child: _messages.isEmpty
                  ? Center(
                      child: Text(
                        'Geen berichten',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    )
                  : ListView.builder(
                      reverse: false,
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            _messages[index],
                            style: TextStyle(
                              color: Colors.green[300],
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
