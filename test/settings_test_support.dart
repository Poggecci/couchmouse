import 'dart:typed_data';

import 'package:couchmouse/generated/couchmouse_settings.pb.dart';
import 'package:couchmouse/settings_store.dart';

export 'package:couchmouse/generated/couchmouse_settings.pb.dart';
export 'package:couchmouse/settings_store.dart';

SettingsStore memorySettings([PortableSettings? initial]) =>
    SettingsStore(initial ?? PortableSettings(), (_) async {});

Future<Uint8List> backupFor(PortableSettings settings) =>
    memorySettings(settings).exportBackup();
