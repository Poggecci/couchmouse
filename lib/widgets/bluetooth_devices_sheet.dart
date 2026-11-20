import 'package:flutter/material.dart';
import '../app_theme.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';

class BluetoothDevicesSheet extends ConsumerWidget {
  final bool isRegistered;
  final Future<void> Function(String address, String name) onConnect;
  final Future<void> Function() onDisconnect;
  final VoidCallback onRequestDiscoverable;

  const BluetoothDevicesSheet({
    super.key,
    required this.isRegistered,
    required this.onConnect,
    required this.onDisconnect,
    required this.onRequestDiscoverable,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    final devicesAsync = ref.watch(pairedDevicesProvider);
    final discoverable = ref.watch(discoverableProvider);
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    return Container(
      decoration: BoxDecoration(
        color: context.palette.paper,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  color: context.palette.ink.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 8 : 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.bluetooth,
                      color: context.palette.ink.withValues(alpha: 0.8),
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Bluetooth Connections",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: context.palette.ink,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.refresh,
                    color: context.palette.ink.withValues(alpha: 0.54),
                    size: 20,
                  ),
                  onPressed: () {
                    ref.invalidate(pairedDevicesProvider);
                  },
                ),
              ],
            ),
            Divider(
              color: context.palette.ink.withValues(alpha: 0.08),
              height: isLandscape ? 12 : 24,
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: connection.isConnected
                      ? context.palette.ink.withValues(alpha: 0.15)
                      : context.palette.ink.withValues(alpha: 0.08),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: connection.isConnected
                          ? const Color(0xFF34C759)
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
                            ? const Color(0xFF34C759)
                            : context.palette.ink.withValues(alpha: 0.87),
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
            Text(
              "PAIRED DEVICES",
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: context.palette.ink.withValues(alpha: 0.38),
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
                      child: Text(
                        "No paired devices found.\nMake sure your phone is paired to your computer.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: context.palette.ink.withValues(alpha: 0.38),
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
                      final isConnectingThis =
                          connection.isConnecting &&
                          connection.connectingAddress == address;
                      final isConnectedThis =
                          connection.isConnected &&
                          connection.connectedDeviceAddress == address;

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: context.palette.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isConnectedThis
                                  ? context.palette.ink
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
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: context.palette.ink,
                              ),
                            ),
                            subtitle: Text(
                              address,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.palette.ink.withValues(
                                  alpha: 0.38,
                                ),
                              ),
                            ),
                            trailing: isConnectingThis
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        context.palette.ink,
                                      ),
                                    ),
                                  )
                                : isConnectedThis
                                ? const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF34C759),
                                    size: 22,
                                  )
                                : ElevatedButton(
                                    onPressed: connection.isConnecting
                                        ? null
                                        : () async {
                                            await onConnect(address, name);
                                          },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: context.palette.ink,
                                      foregroundColor: context.palette.paper,
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
                loading: () => Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        context.palette.ink,
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
            PulsatingGlowButton(
              isDiscoverable: discoverable.isDiscoverable,
              remainingSeconds: discoverable.remainingSeconds,
              label: "Make Discoverable",
              isLandscape: isLandscape,
              onPressed: onRequestDiscoverable,
            ),
            SizedBox(height: isLandscape ? 4 : 10),
          ],
        ),
      ),
    );
  }
}

class PulsatingGlowButton extends StatefulWidget {
  final VoidCallback onPressed;
  final String label;
  final bool isDiscoverable;
  final int remainingSeconds;
  final bool isLandscape;

  const PulsatingGlowButton({
    super.key,
    required this.onPressed,
    required this.label,
    required this.isDiscoverable,
    required this.remainingSeconds,
    required this.isLandscape,
  });

  @override
  State<PulsatingGlowButton> createState() => _PulsatingGlowButtonState();
}

class _PulsatingGlowButtonState extends State<PulsatingGlowButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.isDiscoverable) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulsatingGlowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isDiscoverable && !oldWidget.isDiscoverable) {
      _controller.repeat(reverse: true);
    } else if (!widget.isDiscoverable && oldWidget.isDiscoverable) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isDiscoverable) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final glowValue = _controller.value;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: context.palette.ink.withValues(
                    alpha: 0.08 + (glowValue * 0.12),
                  ),
                  blurRadius: 10 + (glowValue * 10),
                  spreadRadius: 1 + (glowValue * 2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: widget.onPressed,
                icon: Icon(
                  CupertinoIcons.antenna_radiowaves_left_right,
                  size: 18,
                  color: Color.lerp(
                    context.palette.paper,
                    context.palette.paper.withValues(alpha: 0.6),
                    glowValue,
                  ),
                ),
                label: Text(
                  "Visible to Hosts (${widget.remainingSeconds}s)",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.palette.ink,
                  foregroundColor: context.palette.paper,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    vertical: widget.isLandscape ? 8 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: Color.lerp(
                        context.palette.paper.withValues(alpha: 0.2),
                        context.palette.paper.withValues(alpha: 0.6),
                        glowValue,
                      )!,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
    } else {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: widget.onPressed,
          icon: Icon(
            CupertinoIcons.search,
            size: 18,
            color: context.palette.paper,
          ),
          label: Text(widget.label),
          style: ElevatedButton.styleFrom(
            backgroundColor: context.palette.ink,
            foregroundColor: context.palette.paper,
            padding: EdgeInsets.symmetric(
              vertical: widget.isLandscape ? 8 : 14,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      );
    }
  }
}
