import 'package:flutter/material.dart';
import '../services/ble_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final BleService _bleService = BleService();
  String _connectionStatus = "Disconnected";
  String _lastReceivedData = "No data yet";
  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  @override
  void dispose() {
    _bleService.dispose();
    super.dispose();
  }

  /// Setup listeners for BLE service streams
  void _setupListeners() {
    // Listen to connection state changes
    _bleService.connectionStateStream.listen((state) {
      setState(() {
        _connectionStatus = state;
        _isScanning = state == "Scanning" || state == "Connecting";
      });
    });

    // Listen to received data
    _bleService.receivedDataStream.listen((data) {
      setState(() {
        _lastReceivedData = data;
      });
    });
  }

  /// Handle scan and connect button press
  Future<void> _handleScanAndConnect() async {
    setState(() {
      _isScanning = true;
    });
    await _bleService.scanAndConnect();
  }

  /// Handle disconnect button press
  Future<void> _handleDisconnect() async {
    await _bleService.disconnect();
  }

  /// Handle send PING button press
  Future<void> _handleSendPing() async {
    bool success = await _bleService.sendPing();
    if (!success) {
      _showSnackBar("Failed to send PING");
    } else {
      _showSnackBar("PING sent");
    }
  }

  /// Handle send text button press
  Future<void> _handleSendText() async {
    // Show dialog to input text
    String? text = await _showTextInputDialog();
    if (text != null && text.isNotEmpty) {
      bool success = await _bleService.sendText(text);
      if (!success) {
        _showSnackBar("Failed to send text");
      } else {
        _showSnackBar("Text sent: $text");
      }
    }
  }

  /// Handle send navigation button press
  Future<void> _handleSendNavigation() async {
    // Show dialog to input navigation parameters
    Map<String, dynamic>? navData = await _showNavigationInputDialog();
    if (navData != null) {
      bool success = await _bleService.sendNavigation(
        navData['direction'],
        navData['distance'],
      );
      if (!success) {
        _showSnackBar("Failed to send navigation");
      } else {
        _showSnackBar("Navigation sent: ${navData['direction']} ${navData['distance']}m");
      }
    }
  }

  /// Show a snackbar message
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        backgroundColor: Colors.cyan.shade700,
      ),
    );
  }

  /// Show text input dialog
  Future<String?> _showTextInputDialog() async {
    TextEditingController controller = TextEditingController(text: "Hello");
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text("Send Text", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "Enter text message",
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyan),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.cyan, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text("Send", style: TextStyle(color: Colors.cyan)),
          ),
        ],
      ),
    );
  }

  /// Show navigation input dialog
  Future<Map<String, dynamic>?> _showNavigationInputDialog() async {
    String selectedDirection = "L";
    int distance = 120;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E1E),
          title: const Text("Send Navigation", style: TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Direction selector
              const Text("Direction:", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildDirectionButton("L", selectedDirection, (dir) {
                    setDialogState(() => selectedDirection = dir);
                  }),
                  _buildDirectionButton("R", selectedDirection, (dir) {
                    setDialogState(() => selectedDirection = dir);
                  }),
                  _buildDirectionButton("U", selectedDirection, (dir) {
                    setDialogState(() => selectedDirection = dir);
                  }),
                  _buildDirectionButton("D", selectedDirection, (dir) {
                    setDialogState(() => selectedDirection = dir);
                  }),
                ],
              ),
              const SizedBox(height: 20),
              // Distance input
              const Text("Distance (meters):", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 8),
              TextField(
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: "120",
                  hintStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.cyan, width: 2),
                  ),
                ),
                onChanged: (value) {
                  int? parsed = int.tryParse(value);
                  if (parsed != null) distance = parsed;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, {
                'direction': selectedDirection,
                'distance': distance,
              }),
              child: const Text("Send", style: TextStyle(color: Colors.cyan)),
            ),
          ],
        ),
      ),
    );
  }

  /// Build direction button for navigation dialog
  Widget _buildDirectionButton(String direction, String selected, Function(String) onSelect) {
    bool isSelected = direction == selected;
    return GestureDetector(
      onTap: () => onSelect(direction),
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? Colors.cyan : Colors.grey.shade800,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            direction,
            style: TextStyle(
              color: isSelected ? Colors.black : Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isConnected = _connectionStatus == "Connected";

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A), // Almost black
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A1A1A),
        elevation: 0,
        title: const Text(
          "Smart Glasses",
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              _buildStatusCard(),
              const SizedBox(height: 24),

              // Connection Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildPrimaryButton(
                      label: _isScanning ? "Scanning..." : "Scan & Connect",
                      icon: Icons.bluetooth_searching,
                      onPressed: !isConnected && !_isScanning ? _handleScanAndConnect : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSecondaryButton(
                      label: "Disconnect",
                      icon: Icons.bluetooth_disabled,
                      onPressed: isConnected ? _handleDisconnect : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Controls Section
              const Text(
                "Controls",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              _buildControlButton(
                label: "Send PING",
                icon: Icons.wifi_tethering,
                onPressed: isConnected ? _handleSendPing : null,
              ),
              const SizedBox(height: 12),

              _buildControlButton(
                label: "Send Text",
                icon: Icons.message,
                onPressed: isConnected ? _handleSendText : null,
              ),
              const SizedBox(height: 12),

              _buildControlButton(
                label: "Send Navigation",
                icon: Icons.navigation,
                onPressed: isConnected ? _handleSendNavigation : null,
              ),
              const SizedBox(height: 32),

              // Incoming Data Section
              const Text(
                "Incoming Data",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              _buildDataCard(),
            ],
          ),
        ),
      ),
    );
  }

  /// Build status card widget
  Widget _buildStatusCard() {
    Color statusColor;
    if (_connectionStatus == "Connected") {
      statusColor = Colors.green;
    } else if (_connectionStatus == "Scanning" || _connectionStatus == "Connecting") {
      statusColor = Colors.orange;
    } else {
      statusColor = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: statusColor.withOpacity(0.5),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Text(
            _connectionStatus,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build primary button widget
  Widget _buildPrimaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.cyan,
        foregroundColor: Colors.black,
        disabledBackgroundColor: Colors.grey.shade800,
        disabledForegroundColor: Colors.grey.shade600,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: onPressed != null ? 4 : 0,
        shadowColor: Colors.cyan.withOpacity(0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build secondary button widget
  Widget _buildSecondaryButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.cyan,
        disabledForegroundColor: Colors.grey.shade600,
        side: BorderSide(
          color: onPressed != null ? Colors.cyan : Colors.grey.shade800,
          width: 2,
        ),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// Build control button widget
  Widget _buildControlButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A1A1A),
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFF151515),
        disabledForegroundColor: Colors.grey.shade700,
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        elevation: onPressed != null ? 2 : 0,
        shadowColor: Colors.black.withOpacity(0.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 22),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Build data display card widget
  Widget _buildDataCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.cyan.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.sensors, color: Colors.cyan, size: 20),
              const SizedBox(width: 8),
              const Text(
                "Last Received:",
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _lastReceivedData,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
