import 'package:flutter/material.dart';
import '../services/bluetooth_client.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({Key? key}) : super(key: key);

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final BluetoothClient _bluetoothClient = BluetoothClient();
  
  final List<String> _messages = [];
  bool _isConnected = false;
  bool _isSearching = false;
  String? _hostName;
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
    _requestPermissions();
  }
  
  void _setupListeners() {
    // Luister naar berichten
    _bluetoothClient.messageStream.listen((message) {
      setState(() {
        _messages.insert(0, message);
        if (_messages.length > 50) {
          _messages.removeLast();
        }
      });
      
      // Toon notificatie bij ontvangen berichten van host
      if (message.contains('📨 Notificatie van host:')) {
        _showNotification(message.substring(message.indexOf(':') + 2));
      }
    });
    
    // Luister naar verbindingsstatus
    _bluetoothClient.connectionStream.listen((connected) {
      setState(() {
        _isConnected = connected;
        if (connected && _bluetoothClient.hostDevice != null) {
          _hostName = _bluetoothClient.hostDevice!.platformName;
        } else {
          _hostName = null;
        }
      });
    });
  }
  
  Future<void> _requestPermissions() async {
    // Permissions worden automatisch gevraagd door flutter_blue_plus
    // bij het eerste gebruik
  }
  
  Future<void> _searchAndConnect() async {
    setState(() {
      _isSearching = true;
    });
    
    try {
      // Check eerst of we al connected zijn
      if (_isConnected) {
        _showError('Al verbonden met een host');
        setState(() {
          _isSearching = false;
        });
        return;
      }
      
      // Probeer de scan te starten
      _messages.insert(0, '🔍 Starting search for BlueCard hosts...');
      _messages.insert(0, '💡 Make sure:');
      _messages.insert(0, '   - Location is enabled on your device');
      _messages.insert(0, '   - Bluetooth permissions are granted');
      _messages.insert(0, '   - The host is running');
      setState(() {});
      
      await _bluetoothClient.searchForHost();
      
    } catch (e) {
      _showError('Fout bij zoeken: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }
  
  Future<void> _disconnect() async {
    await _bluetoothClient.disconnect();
  }
  
  Future<void> _sendTestAction() async {
    await _bluetoothClient.sendActionToHost({
      'type': 'test',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'message': 'Test actie van client!',
    });
  }
  
  void _showNotification(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.notifications, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.blue[700],
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
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
    _bluetoothClient.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Client'),
        backgroundColor: Colors.blue[700],
        actions: [
          if (_isConnected)
            Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: Row(
                  children: [
                    Icon(Icons.circle, size: 12, color: Colors.green[300]),
                    SizedBox(width: 8),
                    Text('Verbonden'),
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
                      _isConnected ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: _isConnected ? Colors.green : Colors.grey,
                      size: 32,
                    ),
                    SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isConnected ? 'Verbonden' : 'Niet verbonden',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            _isConnected
                                ? 'Host: ${_hostName ?? "Onbekend"}'
                                : 'Zoek naar een host om te verbinden',
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
                
                if (!_isConnected) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSearching ? null : _searchAndConnect,
                      icon: _isSearching
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(Icons.search),
                      label: Text(_isSearching ? 'Zoeken...' : 'Zoek Host'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ],
                
                if (_isConnected) ...[
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _sendTestAction,
                          icon: Icon(Icons.send),
                          label: Text('Test Actie'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: _disconnect,
                        icon: Icon(Icons.close),
                        label: Text('Disconnect'),
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
                              color: Colors.blue[300],
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
