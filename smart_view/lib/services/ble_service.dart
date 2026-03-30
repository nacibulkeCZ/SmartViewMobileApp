import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

/// BLE Service for managing connection to SmartGlasses device
class BleService {
  // UUIDs for the SmartGlasses BLE service and characteristics
  static final Guid serviceUuid = Guid("12345678-1234-1234-1234-1234567890ab");
  static final Guid rxCharacteristicUuid = Guid("12345678-1234-1234-1234-1234567890ac");
  static final Guid txCharacteristicUuid = Guid("12345678-1234-1234-1234-1234567890ad");

  // Device name to search for
  static const String targetDeviceName = "SmartGlasses";

  // Connection state
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _rxCharacteristic;
  BluetoothCharacteristic? _txCharacteristic;

  // Stream controllers
  final StreamController<String> _connectionStateController = StreamController<String>.broadcast();
  final StreamController<String> _receivedDataController = StreamController<String>.broadcast();

  // Subscriptions
  StreamSubscription? _deviceConnectionSubscription;
  StreamSubscription? _scanSubscription;

  /// Stream for connection state changes
  Stream<String> get connectionStateStream => _connectionStateController.stream;

  /// Stream for received data from TX characteristic
  Stream<String> get receivedDataStream => _receivedDataController.stream;

  /// Check if device is connected
  bool get isConnected => _connectedDevice != null;

  /// Get current connection state as string
  String get connectionState {
    if (_connectedDevice != null) {
      return "Connected";
    }
    return "Disconnected";
  }

  /// Start scanning and automatically connect to SmartGlasses device
  Future<void> scanAndConnect() async {
    try {
      // Check if Bluetooth is available and turned on
      if (await FlutterBluePlus.isSupported == false) {
        _connectionStateController.add("Bluetooth not supported");
        return;
      }

      // Update state
      _connectionStateController.add("Scanning");

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: const Duration(seconds: 15),
      );

      // Listen to scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) async {
        for (ScanResult result in results) {
          // Check if this is our target device
          if (result.device.platformName == targetDeviceName) {
            // Found the device! Stop scanning and connect
            await FlutterBluePlus.stopScan();
            await _connectToDevice(result.device);
            break;
          }
        }
      });

      // Wait for scan to complete or timeout
      await Future.delayed(const Duration(seconds: 15));

      // Stop scanning if still running
      await FlutterBluePlus.stopScan();

      // If not connected after scan, update state
      if (_connectedDevice == null) {
        _connectionStateController.add("Device not found");
        await Future.delayed(const Duration(seconds: 2));
        _connectionStateController.add("Disconnected");
      }
    } catch (e) {
      _connectionStateController.add("Error: $e");
      await Future.delayed(const Duration(seconds: 2));
      _connectionStateController.add("Disconnected");
    }
  }

  /// Connect to a specific device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      _connectionStateController.add("Connecting");

      // Connect to device
      await device.connect(timeout: const Duration(seconds: 10));
      _connectedDevice = device;

      // Listen to connection state changes
      _deviceConnectionSubscription = device.connectionState.listen((state) {
        if (state == BluetoothConnectionState.disconnected) {
          _handleDisconnection();
        }
      });

      // Discover services
      List<BluetoothService> services = await device.discoverServices();

      // Find our service and characteristics
      for (BluetoothService service in services) {
        if (service.uuid == serviceUuid) {
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            if (characteristic.uuid == rxCharacteristicUuid) {
              _rxCharacteristic = characteristic;
            } else if (characteristic.uuid == txCharacteristicUuid) {
              _txCharacteristic = characteristic;
              // Enable notifications on TX characteristic
              await _enableNotifications();
            }
          }
        }
      }

      // Update connection state
      _connectionStateController.add("Connected");
    } catch (e) {
      _connectionStateController.add("Connection failed: $e");
      await Future.delayed(const Duration(seconds: 2));
      await disconnect();
    }
  }

  /// Enable notifications on TX characteristic to receive data
  Future<void> _enableNotifications() async {
    if (_txCharacteristic != null) {
      try {
        // Enable notifications
        await _txCharacteristic!.setNotifyValue(true);

        // Listen to incoming data
        _txCharacteristic!.lastValueStream.listen((value) {
          if (value.isNotEmpty) {
            String receivedData = utf8.decode(value);
            _receivedDataController.add(receivedData);
          }
        });
      } catch (e) {
        print("Error enabling notifications: $e");
      }
    }
  }

  /// Disconnect from the device
  Future<void> disconnect() async {
    try {
      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }
      _handleDisconnection();
    } catch (e) {
      print("Error disconnecting: $e");
      _handleDisconnection();
    }
  }

  /// Handle disconnection cleanup
  void _handleDisconnection() {
    _connectedDevice = null;
    _rxCharacteristic = null;
    _txCharacteristic = null;
    _deviceConnectionSubscription?.cancel();
    _connectionStateController.add("Disconnected");
  }

  /// Send a command to the device via RX characteristic
  Future<bool> sendCommand(String command) async {
    if (_rxCharacteristic == null) {
      return false;
    }

    try {
      List<int> bytes = utf8.encode(command);
      await _rxCharacteristic!.write(bytes, withoutResponse: false);
      return true;
    } catch (e) {
      print("Error sending command: $e");
      return false;
    }
  }

  /// Send PING command
  Future<bool> sendPing() async {
    return await sendCommand("PING");
  }

  /// Send text message command
  Future<bool> sendText(String text) async {
    return await sendCommand("TXT:$text");
  }

  /// Send navigation command
  /// direction: L (left), R (right), U (up), D (down)
  /// distance: distance in meters
  Future<bool> sendNavigation(String direction, int distance) async {
    return await sendCommand("NAV:$direction:$distance");
  }

  /// Dispose resources
  void dispose() {
    _scanSubscription?.cancel();
    _deviceConnectionSubscription?.cancel();
    _connectionStateController.close();
    _receivedDataController.close();
  }
}
