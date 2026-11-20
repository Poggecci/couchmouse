import 'package:flutter/services.dart';
import 'package:protobuf/protobuf.dart';

import 'generated/couchmouse_settings.pb.dart';

class SettingsStore {
  SettingsStore(PortableSettings initial, this._persist)
    : _snapshot = initial.deepCopy()..freeze();

  static const channel = MethodChannel('com.example.couchmouse/settings');
  // The signature identifies the backup container independently of the schema.
  static const _backupSignature = [0x43, 0x4d, 0x53, 0x00];
  static final _bluetoothAddress = RegExp(r'^(?:[0-9A-F]{2}:){5}[0-9A-F]{2}$');

  final Future<void> Function(Uint8List bytes) _persist;
  PortableSettings _snapshot;
  Future<void> _pendingWrites = Future.value();

  PortableSettings get snapshot => _snapshot;

  static Future<SettingsStore> open() async {
    final bytes = await channel.invokeMethod<Uint8List>('readSettings');
    return SettingsStore(
      bytes == null ? PortableSettings() : _decode(bytes),
      (bytes) => channel.invokeMethod<void>('writeSettings', bytes),
    );
  }

  Future<void> edit(void Function(PortableSettings) edit) => _write(() {
    final updated = _snapshot.deepCopy();
    edit(updated);
    return updated;
  });

  Future<Uint8List> exportBackup() async {
    await _pendingWrites;
    return Uint8List.fromList([
      ..._backupSignature,
      ..._snapshot.writeToBuffer(),
    ]);
  }

  Future<void> importBackup(Uint8List backup) async {
    if (backup.length < _backupSignature.length) {
      throw const FormatException('Invalid CouchMouse backup signature.');
    }
    for (var i = 0; i < _backupSignature.length; i++) {
      if (backup[i] != _backupSignature[i]) {
        throw const FormatException('Invalid CouchMouse backup signature.');
      }
    }
    final settings = _decode(
      Uint8List.sublistView(backup, _backupSignature.length),
    );
    await _write(() => settings);
  }

  Future<void> _write(PortableSettings Function() update) {
    final write = _pendingWrites.then((_) async {
      final updated = update()..freeze();
      await _persist(updated.writeToBuffer());
      _snapshot = updated;
    });
    _pendingWrites = write.then<void>((_) {}, onError: (Object _) {});
    return write;
  }

  static PortableSettings _decode(Uint8List bytes) {
    final PortableSettings settings;
    try {
      settings = PortableSettings.fromBuffer(bytes);
    } on InvalidProtocolBufferException catch (error) {
      throw FormatException('Invalid CouchMouse settings payload: $error');
    }
    final addresses = <String>{};
    for (final device in settings.deviceProfiles) {
      final address = device.bluetoothAddress;
      if (!_bluetoothAddress.hasMatch(address) || !addresses.add(address)) {
        throw const FormatException('Invalid or duplicate Bluetooth address.');
      }
    }
    return settings;
  }
}
