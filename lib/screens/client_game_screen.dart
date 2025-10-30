import 'package:flutter/material.dart';
import '../services/bluetooth_client.dart';
import '../models/game_message.dart';

class ClientGameScreen extends StatefulWidget {
  final BluetoothClient bluetoothClient;
  
  const ClientGameScreen({
    Key? key,
    required this.bluetoothClient,
  }) : super(key: key);

  @override
  State<ClientGameScreen> createState() => _ClientGameScreenState();
}

class _ClientGameScreenState extends State<ClientGameScreen> {
  final List<String> _messages = [];
  final List<PingInfo> _pings = [];
  
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }
  
  void _setupListeners() {
    // Luister naar berichten
    widget.bluetoothClient.messageStream.listen((message) {
      if (mounted) {
        setState(() {
          _messages.insert(0, message);
          if (_messages.length > 50) {
            _messages.removeLast();
          }
        });
      }
    });
    
    // Luister naar ping updates
    widget.bluetoothClient.pingStream.listen((pingInfo) {
      if (mounted) {
        setState(() {
          _pings.insert(0, pingInfo);
          if (_pings.length > 20) {
            _pings.removeLast();
          }
        });
      }
    });
  }
  
  Future<void> _sendPing() async {
    try {
      await widget.bluetoothClient.sendPing();
    } catch (e) {
      _showError('Fout bij verzenden ping: $e');
    }
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBar(
        title: Text('Game - Client'),
        backgroundColor: Colors.grey[850],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () async {
            await widget.bluetoothClient.disconnect();
            if (mounted) {
              Navigator.pop(context);
            }
          },
        ),
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
                            'Verbonden als: ${widget.bluetoothClient.playerId}',
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
          
          // Ping overzicht
          if (_pings.isNotEmpty) ...[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.wifi_tethering, color: Colors.grey[600], size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Ping Overzicht',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  Container(
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[850],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ListView.builder(
                      itemCount: _pings.length,
                      itemBuilder: (context, index) {
                        final ping = _pings[index];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.person, color: Colors.blue, size: 16),
                          title: Text(
                            'Player: ${ping.playerId}',
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          subtitle: Text(
                            'Timestamp: ${ping.timestamp}',
                            style: TextStyle(color: Colors.grey[500], fontSize: 10),
                          ),
                          trailing: Text(
                            DateTime.fromMillisecondsSinceEpoch(ping.timestamp)
                                .toString()
                                .substring(11, 19),
                            style: TextStyle(color: Colors.grey[400], fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                ],
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
    );
  }
}
