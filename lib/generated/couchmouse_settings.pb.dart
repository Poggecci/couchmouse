// This is a generated file - do not edit.
//
// Generated from couchmouse_settings.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_relative_imports

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

/// Keep field numbers and value IDs stable. Reserve the name and number of any
/// removed field. Add a new field when the type, units, or meaning changes.
class PortableSettings extends $pb.GeneratedMessage {
  factory PortableSettings({
    InputProfile? globalProfile,
    $core.Iterable<DeviceProfile>? deviceProfiles,
    $core.int? tutorialStatusId,
    $core.bool? gamepadMode,
    $core.int? gamepadReportRateHz,
    $core.bool? darkMode,
  }) {
    final result = create();
    if (globalProfile != null) result.globalProfile = globalProfile;
    if (deviceProfiles != null) result.deviceProfiles.addAll(deviceProfiles);
    if (tutorialStatusId != null) result.tutorialStatusId = tutorialStatusId;
    if (gamepadMode != null) result.gamepadMode = gamepadMode;
    if (gamepadReportRateHz != null)
      result.gamepadReportRateHz = gamepadReportRateHz;
    if (darkMode != null) result.darkMode = darkMode;
    return result;
  }

  PortableSettings._();

  factory PortableSettings.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory PortableSettings.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'PortableSettings',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'couchmouse.settings'),
      createEmptyInstance: create)
    ..aOM<InputProfile>(1, _omitFieldNames ? '' : 'globalProfile',
        subBuilder: InputProfile.create)
    ..pPM<DeviceProfile>(2, _omitFieldNames ? '' : 'deviceProfiles',
        subBuilder: DeviceProfile.create)
    ..aI(3, _omitFieldNames ? '' : 'tutorialStatusId',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(4, _omitFieldNames ? '' : 'gamepadMode')
    ..aI(5, _omitFieldNames ? '' : 'gamepadReportRateHz',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(6, _omitFieldNames ? '' : 'darkMode')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PortableSettings clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  PortableSettings copyWith(void Function(PortableSettings) updates) =>
      super.copyWith((message) => updates(message as PortableSettings))
          as PortableSettings;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static PortableSettings create() => PortableSettings._();
  @$core.override
  PortableSettings createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static PortableSettings getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<PortableSettings>(create);
  static PortableSettings? _defaultInstance;

  @$pb.TagNumber(1)
  InputProfile get globalProfile => $_getN(0);
  @$pb.TagNumber(1)
  set globalProfile(InputProfile value) => $_setField(1, value);
  @$pb.TagNumber(1)
  $core.bool hasGlobalProfile() => $_has(0);
  @$pb.TagNumber(1)
  void clearGlobalProfile() => $_clearField(1);
  @$pb.TagNumber(1)
  InputProfile ensureGlobalProfile() => $_ensure(0);

  @$pb.TagNumber(2)
  $pb.PbList<DeviceProfile> get deviceProfiles => $_getList(1);

  /// 0 = none, 1 = completed, 2 = dismissed. An absent value means none.
  @$pb.TagNumber(3)
  $core.int get tutorialStatusId => $_getIZ(2);
  @$pb.TagNumber(3)
  set tutorialStatusId($core.int value) => $_setUnsignedInt32(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTutorialStatusId() => $_has(2);
  @$pb.TagNumber(3)
  void clearTutorialStatusId() => $_clearField(3);

  @$pb.TagNumber(4)
  $core.bool get gamepadMode => $_getBF(3);
  @$pb.TagNumber(4)
  set gamepadMode($core.bool value) => $_setBool(3, value);
  @$pb.TagNumber(4)
  $core.bool hasGamepadMode() => $_has(3);
  @$pb.TagNumber(4)
  void clearGamepadMode() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.int get gamepadReportRateHz => $_getIZ(4);
  @$pb.TagNumber(5)
  set gamepadReportRateHz($core.int value) => $_setUnsignedInt32(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGamepadReportRateHz() => $_has(4);
  @$pb.TagNumber(5)
  void clearGamepadReportRateHz() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.bool get darkMode => $_getBF(5);
  @$pb.TagNumber(6)
  set darkMode($core.bool value) => $_setBool(5, value);
  @$pb.TagNumber(6)
  $core.bool hasDarkMode() => $_has(5);
  @$pb.TagNumber(6)
  void clearDarkMode() => $_clearField(6);
}

class DeviceProfile extends $pb.GeneratedMessage {
  factory DeviceProfile({
    $core.String? bluetoothAddress,
    InputProfile? inputProfile,
  }) {
    final result = create();
    if (bluetoothAddress != null) result.bluetoothAddress = bluetoothAddress;
    if (inputProfile != null) result.inputProfile = inputProfile;
    return result;
  }

  DeviceProfile._();

  factory DeviceProfile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory DeviceProfile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'DeviceProfile',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'couchmouse.settings'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'bluetoothAddress')
    ..aOM<InputProfile>(2, _omitFieldNames ? '' : 'inputProfile',
        subBuilder: InputProfile.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceProfile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  DeviceProfile copyWith(void Function(DeviceProfile) updates) =>
      super.copyWith((message) => updates(message as DeviceProfile))
          as DeviceProfile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static DeviceProfile create() => DeviceProfile._();
  @$core.override
  DeviceProfile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static DeviceProfile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<DeviceProfile>(create);
  static DeviceProfile? _defaultInstance;

  /// Unique within the document. Use uppercase colon-separated Bluetooth MAC
  /// addresses. This identifies a profile independently of Android pairing.
  @$pb.TagNumber(1)
  $core.String get bluetoothAddress => $_getSZ(0);
  @$pb.TagNumber(1)
  set bluetoothAddress($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasBluetoothAddress() => $_has(0);
  @$pb.TagNumber(1)
  void clearBluetoothAddress() => $_clearField(1);

  @$pb.TagNumber(2)
  InputProfile get inputProfile => $_getN(1);
  @$pb.TagNumber(2)
  set inputProfile(InputProfile value) => $_setField(2, value);
  @$pb.TagNumber(2)
  $core.bool hasInputProfile() => $_has(1);
  @$pb.TagNumber(2)
  void clearInputProfile() => $_clearField(2);
  @$pb.TagNumber(2)
  InputProfile ensureInputProfile() => $_ensure(1);
}

class InputProfile extends $pb.GeneratedMessage {
  factory InputProfile({
    $core.double? sensitivity,
    $core.bool? mouseAcceleration,
    $core.bool? trackpadOnLeft,
    $core.int? keyboardLayoutId,
    $core.bool? invertTwoFingerScroll,
    $core.double? scrollSensitivity,
    $core.double? scrollMomentum,
    $core.bool? trackballEnabled,
    $core.double? trackballFriction,
    $core.bool? typingBox,
  }) {
    final result = create();
    if (sensitivity != null) result.sensitivity = sensitivity;
    if (mouseAcceleration != null) result.mouseAcceleration = mouseAcceleration;
    if (trackpadOnLeft != null) result.trackpadOnLeft = trackpadOnLeft;
    if (keyboardLayoutId != null) result.keyboardLayoutId = keyboardLayoutId;
    if (invertTwoFingerScroll != null)
      result.invertTwoFingerScroll = invertTwoFingerScroll;
    if (scrollSensitivity != null) result.scrollSensitivity = scrollSensitivity;
    if (scrollMomentum != null) result.scrollMomentum = scrollMomentum;
    if (trackballEnabled != null) result.trackballEnabled = trackballEnabled;
    if (trackballFriction != null) result.trackballFriction = trackballFriction;
    if (typingBox != null) result.typingBox = typingBox;
    return result;
  }

  InputProfile._();

  factory InputProfile.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory InputProfile.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'InputProfile',
      package:
          const $pb.PackageName(_omitMessageNames ? '' : 'couchmouse.settings'),
      createEmptyInstance: create)
    ..aD(1, _omitFieldNames ? '' : 'sensitivity')
    ..aOB(2, _omitFieldNames ? '' : 'mouseAcceleration')
    ..aOB(3, _omitFieldNames ? '' : 'trackpadOnLeft')
    ..aI(4, _omitFieldNames ? '' : 'keyboardLayoutId',
        fieldType: $pb.PbFieldType.OU3)
    ..aOB(5, _omitFieldNames ? '' : 'invertTwoFingerScroll')
    ..aD(6, _omitFieldNames ? '' : 'scrollSensitivity')
    ..aD(7, _omitFieldNames ? '' : 'scrollMomentum')
    ..aOB(8, _omitFieldNames ? '' : 'trackballEnabled')
    ..aD(9, _omitFieldNames ? '' : 'trackballFriction')
    ..aOB(10, _omitFieldNames ? '' : 'typingBox')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InputProfile clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  InputProfile copyWith(void Function(InputProfile) updates) =>
      super.copyWith((message) => updates(message as InputProfile))
          as InputProfile;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static InputProfile create() => InputProfile._();
  @$core.override
  InputProfile createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static InputProfile getDefault() => _defaultInstance ??=
      $pb.GeneratedMessage.$_defaultFor<InputProfile>(create);
  static InputProfile? _defaultInstance;

  /// Uses CouchMouse sensitivity units.
  @$pb.TagNumber(1)
  $core.double get sensitivity => $_getN(0);
  @$pb.TagNumber(1)
  set sensitivity($core.double value) => $_setDouble(0, value);
  @$pb.TagNumber(1)
  $core.bool hasSensitivity() => $_has(0);
  @$pb.TagNumber(1)
  void clearSensitivity() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.bool get mouseAcceleration => $_getBF(1);
  @$pb.TagNumber(2)
  set mouseAcceleration($core.bool value) => $_setBool(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMouseAcceleration() => $_has(1);
  @$pb.TagNumber(2)
  void clearMouseAcceleration() => $_clearField(2);

  @$pb.TagNumber(3)
  $core.bool get trackpadOnLeft => $_getBF(2);
  @$pb.TagNumber(3)
  set trackpadOnLeft($core.bool value) => $_setBool(2, value);
  @$pb.TagNumber(3)
  $core.bool hasTrackpadOnLeft() => $_has(2);
  @$pb.TagNumber(3)
  void clearTrackpadOnLeft() => $_clearField(3);

  /// Stable IDs: 0 = full size,
  /// 1 = compact full size, 2 = tenkeyless, 3 = 75%, 4 = 65%, 5 = 60%.
  /// Keep unfamiliar IDs when displaying a fallback layout.
  @$pb.TagNumber(4)
  $core.int get keyboardLayoutId => $_getIZ(3);
  @$pb.TagNumber(4)
  set keyboardLayoutId($core.int value) => $_setUnsignedInt32(3, value);
  @$pb.TagNumber(4)
  $core.bool hasKeyboardLayoutId() => $_has(3);
  @$pb.TagNumber(4)
  void clearKeyboardLayoutId() => $_clearField(4);

  @$pb.TagNumber(5)
  $core.bool get invertTwoFingerScroll => $_getBF(4);
  @$pb.TagNumber(5)
  set invertTwoFingerScroll($core.bool value) => $_setBool(4, value);
  @$pb.TagNumber(5)
  $core.bool hasInvertTwoFingerScroll() => $_has(4);
  @$pb.TagNumber(5)
  void clearInvertTwoFingerScroll() => $_clearField(5);

  @$pb.TagNumber(6)
  $core.double get scrollSensitivity => $_getN(5);
  @$pb.TagNumber(6)
  set scrollSensitivity($core.double value) => $_setDouble(5, value);
  @$pb.TagNumber(6)
  $core.bool hasScrollSensitivity() => $_has(5);
  @$pb.TagNumber(6)
  void clearScrollSensitivity() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.double get scrollMomentum => $_getN(6);
  @$pb.TagNumber(7)
  set scrollMomentum($core.double value) => $_setDouble(6, value);
  @$pb.TagNumber(7)
  $core.bool hasScrollMomentum() => $_has(6);
  @$pb.TagNumber(7)
  void clearScrollMomentum() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.bool get trackballEnabled => $_getBF(7);
  @$pb.TagNumber(8)
  set trackballEnabled($core.bool value) => $_setBool(7, value);
  @$pb.TagNumber(8)
  $core.bool hasTrackballEnabled() => $_has(7);
  @$pb.TagNumber(8)
  void clearTrackballEnabled() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.double get trackballFriction => $_getN(8);
  @$pb.TagNumber(9)
  set trackballFriction($core.double value) => $_setDouble(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTrackballFriction() => $_has(8);
  @$pb.TagNumber(9)
  void clearTrackballFriction() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.bool get typingBox => $_getBF(9);
  @$pb.TagNumber(10)
  set typingBox($core.bool value) => $_setBool(9, value);
  @$pb.TagNumber(10)
  $core.bool hasTypingBox() => $_has(9);
  @$pb.TagNumber(10)
  void clearTypingBox() => $_clearField(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
