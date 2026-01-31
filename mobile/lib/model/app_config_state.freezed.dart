// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'app_config_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AppConfigState {

 bool get proxyEnabled; String get proxyHost; int get proxyPort; int get metaCacheTime; bool get titleEnabled; bool get waterfallLayoutEnabled; bool get syncAutoStart; List<Map<String, String>> get reminderShortcuts; bool get highPrecisionNotification; String get linkPreviewApiKey; String get customDomain; Environment get environment;
/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppConfigStateCopyWith<AppConfigState> get copyWith => _$AppConfigStateCopyWithImpl<AppConfigState>(this as AppConfigState, _$identity);

  /// Serializes this AppConfigState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppConfigState&&(identical(other.proxyEnabled, proxyEnabled) || other.proxyEnabled == proxyEnabled)&&(identical(other.proxyHost, proxyHost) || other.proxyHost == proxyHost)&&(identical(other.proxyPort, proxyPort) || other.proxyPort == proxyPort)&&(identical(other.metaCacheTime, metaCacheTime) || other.metaCacheTime == metaCacheTime)&&(identical(other.titleEnabled, titleEnabled) || other.titleEnabled == titleEnabled)&&(identical(other.waterfallLayoutEnabled, waterfallLayoutEnabled) || other.waterfallLayoutEnabled == waterfallLayoutEnabled)&&(identical(other.syncAutoStart, syncAutoStart) || other.syncAutoStart == syncAutoStart)&&const DeepCollectionEquality().equals(other.reminderShortcuts, reminderShortcuts)&&(identical(other.highPrecisionNotification, highPrecisionNotification) || other.highPrecisionNotification == highPrecisionNotification)&&(identical(other.linkPreviewApiKey, linkPreviewApiKey) || other.linkPreviewApiKey == linkPreviewApiKey)&&(identical(other.customDomain, customDomain) || other.customDomain == customDomain)&&(identical(other.environment, environment) || other.environment == environment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proxyEnabled,proxyHost,proxyPort,metaCacheTime,titleEnabled,waterfallLayoutEnabled,syncAutoStart,const DeepCollectionEquality().hash(reminderShortcuts),highPrecisionNotification,linkPreviewApiKey,customDomain,environment);

@override
String toString() {
  return 'AppConfigState(proxyEnabled: $proxyEnabled, proxyHost: $proxyHost, proxyPort: $proxyPort, metaCacheTime: $metaCacheTime, titleEnabled: $titleEnabled, waterfallLayoutEnabled: $waterfallLayoutEnabled, syncAutoStart: $syncAutoStart, reminderShortcuts: $reminderShortcuts, highPrecisionNotification: $highPrecisionNotification, linkPreviewApiKey: $linkPreviewApiKey, customDomain: $customDomain, environment: $environment)';
}


}

/// @nodoc
abstract mixin class $AppConfigStateCopyWith<$Res>  {
  factory $AppConfigStateCopyWith(AppConfigState value, $Res Function(AppConfigState) _then) = _$AppConfigStateCopyWithImpl;
@useResult
$Res call({
 bool proxyEnabled, String proxyHost, int proxyPort, int metaCacheTime, bool titleEnabled, bool waterfallLayoutEnabled, bool syncAutoStart, List<Map<String, String>> reminderShortcuts, bool highPrecisionNotification, String linkPreviewApiKey, String customDomain, Environment environment
});




}
/// @nodoc
class _$AppConfigStateCopyWithImpl<$Res>
    implements $AppConfigStateCopyWith<$Res> {
  _$AppConfigStateCopyWithImpl(this._self, this._then);

  final AppConfigState _self;
  final $Res Function(AppConfigState) _then;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? proxyEnabled = null,Object? proxyHost = null,Object? proxyPort = null,Object? metaCacheTime = null,Object? titleEnabled = null,Object? waterfallLayoutEnabled = null,Object? syncAutoStart = null,Object? reminderShortcuts = null,Object? highPrecisionNotification = null,Object? linkPreviewApiKey = null,Object? customDomain = null,Object? environment = null,}) {
  return _then(_self.copyWith(
proxyEnabled: null == proxyEnabled ? _self.proxyEnabled : proxyEnabled // ignore: cast_nullable_to_non_nullable
as bool,proxyHost: null == proxyHost ? _self.proxyHost : proxyHost // ignore: cast_nullable_to_non_nullable
as String,proxyPort: null == proxyPort ? _self.proxyPort : proxyPort // ignore: cast_nullable_to_non_nullable
as int,metaCacheTime: null == metaCacheTime ? _self.metaCacheTime : metaCacheTime // ignore: cast_nullable_to_non_nullable
as int,titleEnabled: null == titleEnabled ? _self.titleEnabled : titleEnabled // ignore: cast_nullable_to_non_nullable
as bool,waterfallLayoutEnabled: null == waterfallLayoutEnabled ? _self.waterfallLayoutEnabled : waterfallLayoutEnabled // ignore: cast_nullable_to_non_nullable
as bool,syncAutoStart: null == syncAutoStart ? _self.syncAutoStart : syncAutoStart // ignore: cast_nullable_to_non_nullable
as bool,reminderShortcuts: null == reminderShortcuts ? _self.reminderShortcuts : reminderShortcuts // ignore: cast_nullable_to_non_nullable
as List<Map<String, String>>,highPrecisionNotification: null == highPrecisionNotification ? _self.highPrecisionNotification : highPrecisionNotification // ignore: cast_nullable_to_non_nullable
as bool,linkPreviewApiKey: null == linkPreviewApiKey ? _self.linkPreviewApiKey : linkPreviewApiKey // ignore: cast_nullable_to_non_nullable
as String,customDomain: null == customDomain ? _self.customDomain : customDomain // ignore: cast_nullable_to_non_nullable
as String,environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as Environment,
  ));
}

}


/// Adds pattern-matching-related methods to [AppConfigState].
extension AppConfigStatePatterns on AppConfigState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppConfigState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppConfigState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppConfigState value)  $default,){
final _that = this;
switch (_that) {
case _AppConfigState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppConfigState value)?  $default,){
final _that = this;
switch (_that) {
case _AppConfigState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool proxyEnabled,  String proxyHost,  int proxyPort,  int metaCacheTime,  bool titleEnabled,  bool waterfallLayoutEnabled,  bool syncAutoStart,  List<Map<String, String>> reminderShortcuts,  bool highPrecisionNotification,  String linkPreviewApiKey,  String customDomain,  Environment environment)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppConfigState() when $default != null:
return $default(_that.proxyEnabled,_that.proxyHost,_that.proxyPort,_that.metaCacheTime,_that.titleEnabled,_that.waterfallLayoutEnabled,_that.syncAutoStart,_that.reminderShortcuts,_that.highPrecisionNotification,_that.linkPreviewApiKey,_that.customDomain,_that.environment);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool proxyEnabled,  String proxyHost,  int proxyPort,  int metaCacheTime,  bool titleEnabled,  bool waterfallLayoutEnabled,  bool syncAutoStart,  List<Map<String, String>> reminderShortcuts,  bool highPrecisionNotification,  String linkPreviewApiKey,  String customDomain,  Environment environment)  $default,) {final _that = this;
switch (_that) {
case _AppConfigState():
return $default(_that.proxyEnabled,_that.proxyHost,_that.proxyPort,_that.metaCacheTime,_that.titleEnabled,_that.waterfallLayoutEnabled,_that.syncAutoStart,_that.reminderShortcuts,_that.highPrecisionNotification,_that.linkPreviewApiKey,_that.customDomain,_that.environment);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool proxyEnabled,  String proxyHost,  int proxyPort,  int metaCacheTime,  bool titleEnabled,  bool waterfallLayoutEnabled,  bool syncAutoStart,  List<Map<String, String>> reminderShortcuts,  bool highPrecisionNotification,  String linkPreviewApiKey,  String customDomain,  Environment environment)?  $default,) {final _that = this;
switch (_that) {
case _AppConfigState() when $default != null:
return $default(_that.proxyEnabled,_that.proxyHost,_that.proxyPort,_that.metaCacheTime,_that.titleEnabled,_that.waterfallLayoutEnabled,_that.syncAutoStart,_that.reminderShortcuts,_that.highPrecisionNotification,_that.linkPreviewApiKey,_that.customDomain,_that.environment);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AppConfigState extends AppConfigState {
  const _AppConfigState({this.proxyEnabled = false, this.proxyHost = AppConstants.defaultProxyHost, this.proxyPort = AppConstants.defaultProxyPort, this.metaCacheTime = AppConstants.defaultMetaCacheTimeDays, this.titleEnabled = false, this.waterfallLayoutEnabled = true, this.syncAutoStart = false, final  List<Map<String, String>> reminderShortcuts = const [], this.highPrecisionNotification = false, this.linkPreviewApiKey = '', this.customDomain = '', this.environment = Environment.development}): _reminderShortcuts = reminderShortcuts,super._();
  factory _AppConfigState.fromJson(Map<String, dynamic> json) => _$AppConfigStateFromJson(json);

@override@JsonKey() final  bool proxyEnabled;
@override@JsonKey() final  String proxyHost;
@override@JsonKey() final  int proxyPort;
@override@JsonKey() final  int metaCacheTime;
@override@JsonKey() final  bool titleEnabled;
@override@JsonKey() final  bool waterfallLayoutEnabled;
@override@JsonKey() final  bool syncAutoStart;
 final  List<Map<String, String>> _reminderShortcuts;
@override@JsonKey() List<Map<String, String>> get reminderShortcuts {
  if (_reminderShortcuts is EqualUnmodifiableListView) return _reminderShortcuts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_reminderShortcuts);
}

@override@JsonKey() final  bool highPrecisionNotification;
@override@JsonKey() final  String linkPreviewApiKey;
@override@JsonKey() final  String customDomain;
@override@JsonKey() final  Environment environment;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppConfigStateCopyWith<_AppConfigState> get copyWith => __$AppConfigStateCopyWithImpl<_AppConfigState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AppConfigStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppConfigState&&(identical(other.proxyEnabled, proxyEnabled) || other.proxyEnabled == proxyEnabled)&&(identical(other.proxyHost, proxyHost) || other.proxyHost == proxyHost)&&(identical(other.proxyPort, proxyPort) || other.proxyPort == proxyPort)&&(identical(other.metaCacheTime, metaCacheTime) || other.metaCacheTime == metaCacheTime)&&(identical(other.titleEnabled, titleEnabled) || other.titleEnabled == titleEnabled)&&(identical(other.waterfallLayoutEnabled, waterfallLayoutEnabled) || other.waterfallLayoutEnabled == waterfallLayoutEnabled)&&(identical(other.syncAutoStart, syncAutoStart) || other.syncAutoStart == syncAutoStart)&&const DeepCollectionEquality().equals(other._reminderShortcuts, _reminderShortcuts)&&(identical(other.highPrecisionNotification, highPrecisionNotification) || other.highPrecisionNotification == highPrecisionNotification)&&(identical(other.linkPreviewApiKey, linkPreviewApiKey) || other.linkPreviewApiKey == linkPreviewApiKey)&&(identical(other.customDomain, customDomain) || other.customDomain == customDomain)&&(identical(other.environment, environment) || other.environment == environment));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,proxyEnabled,proxyHost,proxyPort,metaCacheTime,titleEnabled,waterfallLayoutEnabled,syncAutoStart,const DeepCollectionEquality().hash(_reminderShortcuts),highPrecisionNotification,linkPreviewApiKey,customDomain,environment);

@override
String toString() {
  return 'AppConfigState(proxyEnabled: $proxyEnabled, proxyHost: $proxyHost, proxyPort: $proxyPort, metaCacheTime: $metaCacheTime, titleEnabled: $titleEnabled, waterfallLayoutEnabled: $waterfallLayoutEnabled, syncAutoStart: $syncAutoStart, reminderShortcuts: $reminderShortcuts, highPrecisionNotification: $highPrecisionNotification, linkPreviewApiKey: $linkPreviewApiKey, customDomain: $customDomain, environment: $environment)';
}


}

/// @nodoc
abstract mixin class _$AppConfigStateCopyWith<$Res> implements $AppConfigStateCopyWith<$Res> {
  factory _$AppConfigStateCopyWith(_AppConfigState value, $Res Function(_AppConfigState) _then) = __$AppConfigStateCopyWithImpl;
@override @useResult
$Res call({
 bool proxyEnabled, String proxyHost, int proxyPort, int metaCacheTime, bool titleEnabled, bool waterfallLayoutEnabled, bool syncAutoStart, List<Map<String, String>> reminderShortcuts, bool highPrecisionNotification, String linkPreviewApiKey, String customDomain, Environment environment
});




}
/// @nodoc
class __$AppConfigStateCopyWithImpl<$Res>
    implements _$AppConfigStateCopyWith<$Res> {
  __$AppConfigStateCopyWithImpl(this._self, this._then);

  final _AppConfigState _self;
  final $Res Function(_AppConfigState) _then;

/// Create a copy of AppConfigState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? proxyEnabled = null,Object? proxyHost = null,Object? proxyPort = null,Object? metaCacheTime = null,Object? titleEnabled = null,Object? waterfallLayoutEnabled = null,Object? syncAutoStart = null,Object? reminderShortcuts = null,Object? highPrecisionNotification = null,Object? linkPreviewApiKey = null,Object? customDomain = null,Object? environment = null,}) {
  return _then(_AppConfigState(
proxyEnabled: null == proxyEnabled ? _self.proxyEnabled : proxyEnabled // ignore: cast_nullable_to_non_nullable
as bool,proxyHost: null == proxyHost ? _self.proxyHost : proxyHost // ignore: cast_nullable_to_non_nullable
as String,proxyPort: null == proxyPort ? _self.proxyPort : proxyPort // ignore: cast_nullable_to_non_nullable
as int,metaCacheTime: null == metaCacheTime ? _self.metaCacheTime : metaCacheTime // ignore: cast_nullable_to_non_nullable
as int,titleEnabled: null == titleEnabled ? _self.titleEnabled : titleEnabled // ignore: cast_nullable_to_non_nullable
as bool,waterfallLayoutEnabled: null == waterfallLayoutEnabled ? _self.waterfallLayoutEnabled : waterfallLayoutEnabled // ignore: cast_nullable_to_non_nullable
as bool,syncAutoStart: null == syncAutoStart ? _self.syncAutoStart : syncAutoStart // ignore: cast_nullable_to_non_nullable
as bool,reminderShortcuts: null == reminderShortcuts ? _self._reminderShortcuts : reminderShortcuts // ignore: cast_nullable_to_non_nullable
as List<Map<String, String>>,highPrecisionNotification: null == highPrecisionNotification ? _self.highPrecisionNotification : highPrecisionNotification // ignore: cast_nullable_to_non_nullable
as bool,linkPreviewApiKey: null == linkPreviewApiKey ? _self.linkPreviewApiKey : linkPreviewApiKey // ignore: cast_nullable_to_non_nullable
as String,customDomain: null == customDomain ? _self.customDomain : customDomain // ignore: cast_nullable_to_non_nullable
as String,environment: null == environment ? _self.environment : environment // ignore: cast_nullable_to_non_nullable
as Environment,
  ));
}


}

// dart format on
