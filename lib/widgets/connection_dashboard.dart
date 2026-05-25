import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';

class StatusDot extends ConsumerWidget {
  final bool isRegistered;

  const StatusDot({super.key, required this.isRegistered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    Color dotColor = Colors.red;
    if (connection.isConnected) {
      dotColor = const Color(0xFF0DF5E3);
    } else if (isRegistered) {
      dotColor = Colors.amber;
    }

    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.6),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
    );
  }
}

class ConnectionDashboard extends ConsumerWidget {
  final bool compact;
  final bool isRegistered;
  final VoidCallback onTap;

  const ConnectionDashboard({
    super.key,
    this.compact = false,
    required this.isRegistered,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    final isConnected = connection.isConnected;
    final connectedDeviceName = connection.connectedDeviceName;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(2, 2, 2, 8)
            : const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Container(
          padding: compact
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 1)
              : const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF13131B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isConnected
                  ? const Color(0x330DF5E3)
                  : const Color(0x1AFFFFFF),
              width: 1.5,
            ),
            boxShadow: [
              if (isConnected)
                const BoxShadow(
                  color: Color(0x1A0DF5E3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
            ],
          ),
          child: Row(
            children: [
              if (compact) const SizedBox(width: 4),
              StatusDot(isRegistered: isRegistered),
              if (compact) ...[
                const SizedBox(width: 8),
                Text(
                  isConnected ? "Connected" : "Disconnected",
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
              ] else ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isConnected ? "Connected" : "Not Connected",
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? "Connected to ${connectedDeviceName ?? 'Host Laptop'}"
                            : "Tap to connect or pair a device",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.white54,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              IconButton(
                onPressed: onTap,
                icon: const Icon(Icons.settings_bluetooth),
                color: const Color(0xFF00E5FF),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: compact ? 20 : 26,
                tooltip: "Bluetooth Connections",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
