import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_service.dart';
import 'debug_service.dart';

class BluetoothSetupScreen extends StatefulWidget {
  const BluetoothSetupScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothSetupScreen> createState() => _BluetoothSetupScreenState();
}

class _BluetoothSetupScreenState extends State<BluetoothSetupScreen> {
  final BluetoothGameService _bluetoothService = BluetoothGameService();

  @override
  void initState() {
    super.initState();
    _bluetoothService.addListener(_onBluetoothStateChanged);
    _bluetoothService.onPlayerConnected = _onPlayerConnected;
    _bluetoothService.onPlayerDisconnected = _onPlayerDisconnected;
  }

  @override
  void dispose() {
    _bluetoothService.removeListener(_onBluetoothStateChanged);
    super.dispose();
  }

  void _onBluetoothStateChanged() {
    setState(() {});
  }

  void _onPlayerConnected(String playerId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Player connected: $playerId'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _onPlayerDisconnected(String playerId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Player disconnected: $playerId'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F5132),
      appBar: AppBar(
        title: const Text(
          'Bluetooth Multiplayer',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0A4025),
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            _bluetoothService.disconnect();
            Navigator.pop(context);
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status display
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A4025),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    _getStatusIcon(),
                    size: 48,
                    color: _getStatusColor(),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _getStatusText(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Action buttons
            if (_bluetoothService.state == BluetoothGameState.disconnected) ...[
              ElevatedButton.icon(
                onPressed: _startHosting,
                icon: const Icon(Icons.wifi_tethering),
                label: const Text('HOST GAME'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              ElevatedButton.icon(
                onPressed: _startScanning,
                icon: const Icon(Icons.search),
                label: const Text('JOIN GAME'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              OutlinedButton.icon(
                onPressed: _showDebugWindow,
                icon: const Icon(Icons.bug_report),
                label: const Text('DEBUG LOG'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey[700],
                  side: BorderSide(color: Colors.grey[400]!),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
            
            // Host waiting screen
            if (_bluetoothService.state == BluetoothGameState.hosting) ...[
              const Text(
                '🎮 Game Host Active!',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                'Your device is now discoverable.\nOther players can find and join your game.',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue, width: 1),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 24),
                    SizedBox(height: 8),
                    Text(
                      'Players should tap "JOIN GAME" on their devices to find and connect to your game.',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 20),
              
              ElevatedButton(
                onPressed: _startGame,
                child: const Text('START GAME'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
            
            // Client scanning/device list
            if (_bluetoothService.state == BluetoothGameState.scanning) ...[
              const Text(
                '🔍 Scanning for BlueCard games...',
                style: TextStyle(
                  color: Colors.blue,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 10),
              
              const Text(
                'Looking for nearby devices hosting BlueCard games',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 20),
              
              Expanded(
                child: _bluetoothService.discoveredDevices.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: Colors.blue,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Searching for game hosts...\nMake sure the host has started their game.',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Text(
                              'Found ${_bluetoothService.discoveredDevices.length} game host(s):',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _bluetoothService.discoveredDevices.length,
                              itemBuilder: (context, index) {
                                final device = _bluetoothService.discoveredDevices[index];
                                return Card(
                                  color: const Color(0xFF0A4025),
                                  child: ListTile(
                                    leading: const Icon(
                                      Icons.videogame_asset,
                                      color: Colors.green,
                                    ),
                                    title: Text(
                                      device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                    subtitle: Text(
                                      'BlueCard Host • ${device.remoteId.toString().substring(0, 8)}...',
                                      style: const TextStyle(color: Colors.green),
                                    ),
                                    trailing: const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.white54,
                                      size: 16,
                                    ),
                                    onTap: () => _connectToDevice(device),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
              ),
            ],
            
            // Connected state
            if (_bluetoothService.state == BluetoothGameState.connected) ...[
              const Text(
                'Connected! Waiting for host to start game...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            const SizedBox(height: 20),
            
            // Disconnect button
            if (_bluetoothService.state != BluetoothGameState.disconnected)
              ElevatedButton(
                onPressed: _disconnect,
                child: const Text('DISCONNECT'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon() {
    switch (_bluetoothService.state) {
      case BluetoothGameState.disconnected:
        return Icons.bluetooth_disabled;
      case BluetoothGameState.scanning:
        return Icons.bluetooth_searching;
      case BluetoothGameState.connecting:
        return Icons.bluetooth_connected;
      case BluetoothGameState.connected:
        return Icons.bluetooth_connected;
      case BluetoothGameState.hosting:
        return Icons.wifi_tethering;
    }
  }

  Color _getStatusColor() {
    switch (_bluetoothService.state) {
      case BluetoothGameState.disconnected:
        return Colors.grey;
      case BluetoothGameState.scanning:
        return Colors.blue;
      case BluetoothGameState.connecting:
        return Colors.orange;
      case BluetoothGameState.connected:
        return Colors.green;
      case BluetoothGameState.hosting:
        return Colors.green;
    }
  }

  String _getStatusText() {
    switch (_bluetoothService.state) {
      case BluetoothGameState.disconnected:
        return 'Not Connected';
      case BluetoothGameState.scanning:
        return 'Scanning for Games';
      case BluetoothGameState.connecting:
        return 'Connecting...';
      case BluetoothGameState.connected:
        return 'Connected to Game';
      case BluetoothGameState.hosting:
        return 'Hosting Game';
    }
  }

  Future<void> _startHosting() async {
    await _bluetoothService.startHosting();
  }

  Future<void> _startScanning() async {
    await _bluetoothService.scanForHosts();
  }

  void _showDebugWindow() {
    showDialog(
      context: context,
      builder: (context) => const DebugWindow(),
    );
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final success = await _bluetoothService.connectToHost(device);
    if (success) {
      // Wait for game to start
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to connect to device'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _disconnect() {
    _bluetoothService.disconnect();
  }

  void _startGame() {
    // Navigate to game screen with Bluetooth mode
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => const BluetoothGameScreen(),
      ),
    );
  }
}

class BluetoothGameScreen extends StatefulWidget {
  const BluetoothGameScreen({Key? key}) : super(key: key);

  @override
  State<BluetoothGameScreen> createState() => _BluetoothGameScreenState();
}

class _BluetoothGameScreenState extends State<BluetoothGameScreen> {
  final BluetoothGameService _bluetoothService = BluetoothGameService();

  @override
  void initState() {
    super.initState();
    _bluetoothService.onMessageReceived = _handleGameMessage;
  }

  void _handleGameMessage(GameMessage message) {
    switch (message.type) {
      case GameMessageType.gameState:
        // Update game state from host
        break;
      case GameMessageType.playCard:
        // Handle card play from other player
        break;
      case GameMessageType.drawCard:
        // Handle card draw from other player
        break;
      case GameMessageType.nextTurn:
        // Move to next turn
        break;
      case GameMessageType.playerJoined:
        // New player joined
        break;
      case GameMessageType.playerLeft:
        // Player left game
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F5132),
      appBar: AppBar(
        title: Text(
          _bluetoothService.isHost ? 'BlueCard - Host' : 'BlueCard - Client',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0A4025),
        elevation: 0,
      ),
      body: const Center(
        child: Text(
          'Bluetooth Game Coming Soon!\nGame synchronization will be implemented here.',
          style: TextStyle(color: Colors.white, fontSize: 18),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _bluetoothService.onMessageReceived = null;
    super.dispose();
  }
}