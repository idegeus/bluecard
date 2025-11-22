import 'package:flutter/material.dart';
import '../services/bluetooth_host.dart';
import '../services/bluetooth_client.dart';
import '../models/game_message.dart';

/// Gedeeld game screen voor zowel host als client
class GameScreen extends StatefulWidget {
  final BluetoothHost? bluetoothHost;
  final BluetoothClient? bluetoothClient;
  final bool isHost;

  const GameScreen({
    super.key,
    this.bluetoothHost,
    this.bluetoothClient,
    required this.isHost,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    if (!widget.isHost && widget.bluetoothClient != null) {
      // Luister naar goodbye messages van host
      widget.bluetoothClient!.gameMessageStream.listen((gameMessage) {
        if (gameMessage.type == GameMessageType.goodbye && mounted) {
          // Host heeft game afgesloten
          _showHostQuitDialog();
        }
      });
    }
  }

  void _showHostQuitDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange[400]),
            SizedBox(width: 8),
            Text(
              'Host heeft afgesloten',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Text(
          'De host heeft de game afgesloten. Je wordt teruggebracht naar het hoofdmenu.',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              // Sluit dialog
              Navigator.pop(context);

              // Disconnect en ga naar home
              await widget.bluetoothClient?.disconnect();
              // NIET dispose() aanroepen - streams blijven beschikbaar

              if (mounted) {
                Navigator.of(
                  context,
                ).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showConnectionInfo() {
    final now = DateTime.now();

    // Haal lastSync direct uit de service
    final DateTime? lastSync = widget.isHost
        ? widget.bluetoothHost?.lastSyncTime
        : widget.bluetoothClient?.lastSyncTime;

    final timeSinceLastSync = lastSync != null
        ? now.difference(lastSync).inSeconds
        : null;

    // Haal playerIds en count direct uit de service
    final List<String> playerIds = widget.isHost
        ? (widget.bluetoothHost?.playerIds ?? [])
        : (widget.bluetoothClient?.playerIds ?? []);

    final int playerCount = widget.isHost
        ? (widget.bluetoothHost?.totalPlayerCount ?? 0)
        : (widget.bluetoothClient?.playerCount ?? 0);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue[400]),
            SizedBox(width: 8),
            Text('Verbindingsinfo', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.router,
              label: 'Rol',
              value: widget.isHost ? 'Host' : 'Client',
            ),
            SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.people,
              label: 'Spelers',
              value: '$playerCount (${playerIds.join(", ")})',
            ),
            SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.wifi_tethering,
              label: 'Laatste sync',
              value: timeSinceLastSync != null
                  ? '$timeSinceLastSync seconden geleden'
                  : 'Nog geen sync',
            ),
            SizedBox(height: 12),

            _buildInfoRow(
              icon: Icons.check_circle,
              label: 'Status',
              value: widget.isHost
                  ? (widget.bluetoothHost?.isAdvertising ?? false
                        ? 'Actief'
                        : 'Gestopt')
                  : (widget.bluetoothClient?.isConnected ?? false
                        ? 'Verbonden'
                        : 'Niet verbonden'),
              valueColor: widget.isHost
                  ? (widget.bluetoothHost?.isAdvertising ?? false
                        ? Colors.green
                        : Colors.red)
                  : (widget.bluetoothClient?.isConnected ?? false
                        ? Colors.green
                        : Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Sluiten'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmQuitGame() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Row(
          children: [
            Icon(Icons.exit_to_app, color: Colors.orange[400]),
            SizedBox(width: 8),
            Text('Game afsluiten?', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          widget.isHost
              ? 'Weet je zeker dat je de game wilt afsluiten? Alle spelers worden ontkoppeld.'
              : 'Weet je zeker dat je de game wilt verlaten?',
          style: TextStyle(color: Colors.grey[400]),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Annuleren'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red[700]),
            child: Text('Afsluiten'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _quitGame();
    }
  }

  Future<void> _quitGame() async {
    try {
      // Toon loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      // Roep de juiste quit methode aan
      if (widget.isHost) {
        await widget.bluetoothHost?.quitGame();
      } else {
        await widget.bluetoothClient?.quitGame();
      }

      // Verwijder loading indicator
      if (mounted) {
        Navigator.pop(context);

        // Ga terug naar home screen
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      // Verwijder loading indicator
      if (mounted) {
        Navigator.pop(context);

        // Toon error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fout bij afsluiten: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey[600]),
        SizedBox(width: 8),
        Text(
          '$label:',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Blokkeer terugknop - gebruiker moet quit gebruiken
      onWillPop: () async {
        _confirmQuitGame();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.grey[900],
        appBar: AppBar(
          title: Text(widget.isHost ? 'BlueCard - Host' : 'BlueCard - Speler'),
          backgroundColor: widget.isHost ? Colors.green[700] : Colors.blue[700],
          automaticallyImplyLeading: false, // Verwijder terugknop
          actions: [
            // Info button
            IconButton(
              icon: Icon(Icons.info_outline),
              onPressed: _showConnectionInfo,
              tooltip: 'Verbindingsinfo',
            ),
            // Quit button
            IconButton(
              icon: Icon(Icons.exit_to_app),
              onPressed: _confirmQuitGame,
              tooltip: 'Game afsluiten',
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.games, size: 100, color: Colors.grey[700]),
              SizedBox(height: 24),
              Text(
                'Game gestart!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Spel implementatie komt hier',
                style: TextStyle(fontSize: 16, color: Colors.grey[400]),
              ),
              SizedBox(height: 32),
              Container(
                padding: EdgeInsets.all(16),
                margin: EdgeInsets.symmetric(horizontal: 32),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.isHost ? '🎮 Je bent de host' : '🎯 Je speelt mee',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    SizedBox(height: 8),
                    Text(
                      widget.isHost
                          ? '${widget.bluetoothHost?.connectedClientCount ?? 0} speler(s) verbonden'
                          : '${widget.bluetoothClient?.playerCount ?? 0} totale spelers',
                      style: TextStyle(fontSize: 14, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
