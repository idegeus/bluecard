import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'bluetooth_service.dart';
import 'debug_service.dart';
import 'settings_screen.dart';

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
    _bluetoothService.onMessageReceived = _handleGameMessage;
  }

  @override
  void dispose() {
    _bluetoothService.removeListener(_onBluetoothStateChanged);
    super.dispose();
  }

  void _onBluetoothStateChanged() {
    DebugService().log('🔄 Bluetooth state changed to: ${_bluetoothService.state}');
    setState(() {});
  }

  void _onPlayerConnected(String playerId) {
    // Only show "Player connected" for hosts when clients join
    // Don't show it for clients when they successfully connect
    if (_bluetoothService.isHost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Player connected: $playerId'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  void _onPlayerDisconnected(String playerId) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Player disconnected: $playerId'),
        backgroundColor: Colors.orange,
      ),
    );
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
      case GameMessageType.ping:
        // Handle ping message - just log it for now
        DebugService().log('🏓 Received ping from ${message.playerId}');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F5132),
      appBar: AppBar(
        title: const Text(
          '',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF0A4025),
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            icon: const Icon(Icons.settings, color: Colors.white),
          ),
        ],
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
            
            // Debug state display
            Text(
              'Current State: ${_bluetoothService.state}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 10),
            
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
            ],
            
            // Starting host loading screen
            if (_bluetoothService.state == BluetoothGameState.startingHost) ...[
              const Center(
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: CircularProgressIndicator(
                    color: Colors.green,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Starting Game Host...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Setting up Bluetooth advertising',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            
            // Host waiting screen
            if (_bluetoothService.state == BluetoothGameState.hosting)
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      const SizedBox(height: 10),
                      
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
                      
                      // Connected Clients Section
                      if (_bluetoothService.connectedClients.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.green, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.people, color: Colors.green, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Connected Players (${_bluetoothService.connectedClients.length})',
                                    style: const TextStyle(
                                      color: Colors.green,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ..._bluetoothService.connectedClients.map((client) => 
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person, color: Colors.white70, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        client['name'] ?? 'Unknown Player',
                                        style: const TextStyle(color: Colors.white),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withOpacity(0.3),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Text(
                                          'ONLINE',
                                          style: TextStyle(
                                            color: Colors.green,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ).toList(),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
                      // Ping History Section
                      if (_bluetoothService.pingHistory.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue, width: 1),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.timeline, color: Colors.blue, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Ping History (${_bluetoothService.pingHistory.length})',
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              // Make ping history scrollable and taller
                              SizedBox(
                                height: 200,
                                child: ListView.builder(
                                  itemCount: _bluetoothService.pingHistory.length,
                                  itemBuilder: (context, index) {
                                    final ping = _bluetoothService.pingHistory[index];
                                    final timestamp = ping['timestamp'] as DateTime;
                                    final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
                                    final direction = ping['direction'] as String;
                                    final playerId = ping['playerId'] as String;
                                    final message = ping['message'] as String;
                                    
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 1),
                                      child: Row(
                                        children: [
                                          Icon(
                                            direction == 'sent' ? Icons.arrow_upward : Icons.arrow_downward,
                                            color: direction == 'sent' ? Colors.orange : Colors.green,
                                            size: 16,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            timeString,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontFamily: 'monospace',
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              '${direction == 'sent' ? 'To' : 'From'} $playerId: $message',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                      
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
                      const SizedBox(height: 20), // Extra bottom padding
                    ],
                  ),
                ),
              ),
            
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
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                color: Colors.blue,
                              ),
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
              
              const SizedBox(height: 20),
              
              // Ping History Section for Client
              if (_bluetoothService.pingHistory.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.purple, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.sync_alt, color: Colors.purple, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Connection Activity (${_bluetoothService.pingHistory.length})',
                            style: const TextStyle(
                              color: Colors.purple,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 100,
                        child: ListView.builder(
                          itemCount: _bluetoothService.pingHistory.length,
                          itemBuilder: (context, index) {
                            final ping = _bluetoothService.pingHistory[index];
                            final timestamp = ping['timestamp'] as DateTime;
                            final timeString = '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
                            final direction = ping['direction'] as String;
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 1),
                              child: Row(
                                children: [
                                  Icon(
                                    direction == 'sent' ? Icons.arrow_upward : Icons.arrow_downward,
                                    color: direction == 'sent' ? Colors.orange : Colors.green,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    timeString,
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${direction == 'sent' ? 'Ping sent' : 'Ping from host'}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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
      case BluetoothGameState.startingHost:
        return Icons.wifi_tethering;
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
      case BluetoothGameState.startingHost:
        return Colors.orange;
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
      case BluetoothGameState.startingHost:
        return 'Starting Host...';
      case BluetoothGameState.hosting:
        return 'Hosting Game';
    }
  }

  Future<void> _startHosting() async {
    DebugService().log('🎯 Host Game button pressed!');
    try {
      await _bluetoothService.startHosting();
      DebugService().log('✅ Host Game button completed successfully');
    } catch (e) {
      DebugService().log('❌ Host Game button error: $e');
    }
  }

  Future<void> _startScanning() async {
    await _bluetoothService.scanForHosts();
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    final success = await _bluetoothService.connectToHost(device);
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Connected to ${device.platformName}'),
          backgroundColor: Colors.green,
        ),
      );
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

  void _startGame() async {
    // Start the game via bluetooth service (this sends messages to clients and starts host pings)
    await _bluetoothService.startGame();
    
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