import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';

class BluetoothDevicesSheet extends ConsumerWidget {
  final bool isRegistered;
  final Future<void> Function(String address, String name) onConnect;
  final Future<void> Function() onDisconnect;
  final VoidCallback onOpenBluetoothSettings;

  const BluetoothDevicesSheet({
    super.key,
    required this.isRegistered,
    required this.onConnect,
    required this.onDisconnect,
    required this.onOpenBluetoothSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    final devicesAsync = ref.watch(pairedDevicesProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 20.0,
          vertical: isLandscape ? 8.0 : 16.0,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.bluetooth,
                      color: Color(0xFF00E5FF),
                      size: 24,
                    ),
                    SizedBox(width: 10),
                    Text(
                      "Bluetooth Connections",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: Colors.white54,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.invalidate(pairedDevicesProvider);
                  },
                ),
              ],
            ),
            Divider(
              color: const Color(0x18FFFFFF),
              height: isLandscape ? 12 : 24,
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0C0C12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: connection.isConnected
                      ? const Color(0x200DF5E3)
                      : const Color(0x08FFFFFF),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connection.isConnected
                          ? const Color(0xFF0DF5E3)
                          : Colors.redAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      connection.isConnected
                          ? "Connected: ${connection.connectedDeviceName ?? 'Host Laptop'}"
                          : "Disconnected",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: connection.isConnected
                            ? const Color(0xFF0DF5E3)
                            : Colors.white70,
                      ),
                    ),
                  ),
                  if (connection.isConnected)
                    TextButton(
                      onPressed: () async {
                        await onDisconnect();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "Disconnect",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
            const Text(
              "PAIRED DEVICES",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white30,
                letterSpacing: 1.0,
              ),
            ),
            SizedBox(height: isLandscape ? 4 : 8),
            Flexible(
              child: devicesAsync.when(
                data: (devices) {
                  if (devices.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      alignment: Alignment.center,
                      child: const Text(
                        "No paired devices found.\nMake sure your phone is paired to your computer.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white30,
                          fontSize: 13,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final device = devices[index];
                      final name = device['name'] ?? "Unknown Device";
                      final address = device['address'] ?? "";
                      final isConnectingThis = connection.isConnecting &&
                          connection.connectingAddress == address;
                      final isConnectedThis = connection.isConnected &&
                          connection.connectedDeviceAddress == address;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B1B26),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isConnectedThis
                                  ? const Color(0xFF00E5FF)
                                  : Colors.transparent,
                              width: 1,
                            ),
                          ),
                          child: ListTile(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: isLandscape ? 0 : 4,
                            ),
                            title: Text(
                              name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: Colors.white,
                              ),
                            ),
                            subtitle: Text(
                              address,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white30,
                              ),
                            ),
                            trailing: isConnectingThis
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xFF00E5FF),
                                      ),
                                    ),
                                  )
                                : isConnectedThis
                                    ? const Icon(
                                        Icons.check_circle,
                                        color: Color(0xFF0DF5E3),
                                        size: 22,
                                      )
                                    : ElevatedButton(
                                        onPressed: connection.isConnecting
                                            ? null
                                            : () async {
                                                await onConnect(address, name);
                                              },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF00E5FF),
                                          foregroundColor: Colors.black,
                                          minimumSize: Size.zero,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        child: const Text(
                                          "Connect",
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00E5FF),
                      ),
                    ),
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      "Error loading paired devices: $err",
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onOpenBluetoothSettings();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text("Pair New Device"),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1B1B26),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  vertical: isLandscape ? 8 : 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(
                    color: Color(0x18FFFFFF),
                    width: 1,
                  ),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 4 : 10),
          ],
        ),
      ),
    );
  }
}
