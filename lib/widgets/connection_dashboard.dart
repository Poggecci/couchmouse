import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../settings_providers.dart';

class StatusDot extends ConsumerWidget {
  final bool isRegistered;

  const StatusDot({super.key, required this.isRegistered});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connection = ref.watch(connectionStateProvider);
    Color dotColor = const Color(0xFF8E8E93);
    if (connection.isConnected) {
      dotColor = const Color(0xFF34C759);
    } else if (isRegistered) {
      dotColor = const Color(0xFFFF9500);
    }

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: dotColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: dotColor.withValues(alpha: 0.2),
            blurRadius: 4,
            spreadRadius: 1,
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
            color: const Color(0xFFF4F4F6),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
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
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
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
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isConnected
                            ? "Connected to ${connectedDeviceName ?? 'Host Laptop'}"
                            : "Tap to connect or pair a device",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              IconButton(
                onPressed: onTap,
                icon: const Icon(CupertinoIcons.bluetooth),
                color: Colors.black.withValues(alpha: 0.8),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                iconSize: compact ? 18 : 22,
                tooltip: "Bluetooth Connections",
              ),
            ],
          ),
        ),
      ),
    );
  }
}
