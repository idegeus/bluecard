import 'package:flutter/material.dart';
import '../services/bluetooth_client.dart';
import '../models/game_message.dart';
import 'client_game_screen.dart';

class ClientScreen extends StatefulWidget {
  const ClientScreen({Key? key}) : super(key: key);

  @override
  State<ClientScreen> createState() => _ClientScreenState();
}

class _ClientScreenState extends State<ClientScreen> {
  final BluetoothClient _bluetoothClient = BluetoothClient();
  
  final List<String> _messages = [];
  final List<PingInfo> _pings = [];
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
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
          if (_messages.length > 50) {
            _messages.removeLast();
          }
        });
      }
      
      // Toon notificatie bij ontvangen berichten van host
      if (message.contains('📨 Notificatie van host:')) {
        _showNotification(message.substring(message.indexOf(':') + 2));
      }
    });
    
    // Luister naar ping berichten van host
    _bluetoothClient.pingStream.listen((pingInfo) {
      if (mounted) {
        setState(() {
          _pings.insert(0, pingInfo);
          if (_pings.length > 20) {
            _pings.removeLast();
          }
        });
      }
    });
    
    // Luister naar verbindingsstatus
    _bluetoothClient.connectionStream.listen((connected) {
      if (mounted) {
        setState(() {
          _isConnected = connected;
          if (connected) {
            _hostName = _bluetoothClient.connectedHostName ?? 'BlueCard Host';
          } else {
            _hostName = null;
          }
        });
      }
    });
    
    // Luister naar game messages voor auto-navigatie
    _bluetoothClient.gameMessageStream.listen((gameMessage) {
      if (gameMessage.type == GameMessageType.startGame && mounted) {
        // Navigeer naar game screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ClientGameScreen(
              bluetoothClient: _bluetoothClient,
            ),
          ),
        );
      }
    });
  }
  
  Future<void> _requestPermissions() async {
    // Permissions worden automatisch gevraagd door de service
    // bij het starten van de ClientService
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
      
      // Start de Client Foreground Service die automatisch zoekt naar hosts
      _messages.insert(0, '🔍 Starting Client Service...');
      _messages.insert(0, '💡 De service draait in de achtergrond');
      _messages.insert(0, '💡 Je ontvangt een notificatie tijdens het zoeken');
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
    // Stop de Client Service (sluit verbinding en stopt de foreground service)
    await _bluetoothClient.disconnect();
  }
  
  Future<void> _sendTestAction() async {
    await _bluetoothClient.sendMessage(
      type: GameMessageType.ping,
      content: {
        'message': 'Test actie van client!',
        'extra': 'Extra informatie',
      },
    );
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
          
          // Ping overzicht (alleen tonen als verbonden)
          if (_isConnected && _pings.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.wifi_tethering, color: Colors.green[400], size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Pings van Host',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey[400],
                    ),
                  ),
                  Spacer(),
                  Text(
                    '${_pings.length} ontvangen',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8),
            
            Container(
              margin: EdgeInsets.symmetric(horizontal: 16),
              constraints: BoxConstraints(maxHeight: 150),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green[800]!),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _pings.length,
                itemBuilder: (context, index) {
                  final ping = _pings[index];
                  final latency = ping.receivedAt.difference(
                    DateTime.fromMillisecondsSinceEpoch(ping.timestamp)
                  ).inMilliseconds;
                  
                  return Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[800]!,
                          width: index < _pings.length - 1 ? 1 : 0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.router, color: Colors.green[400], size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Ping van host',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ),
                        Text(
                          '${latency}ms',
                          style: TextStyle(
                            color: latency < 100 ? Colors.green[400] : Colors.orange,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            SizedBox(height: 16),
          ],
          
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
