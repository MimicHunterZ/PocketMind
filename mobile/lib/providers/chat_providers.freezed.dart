// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'chat_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$GlobalAiSessionState {

 String? get currentSessionUuid; List<ChatSession> get sessions; List<String> get sessionUuidsVisibleInDrawer; Map<String, String> get draftBySession; Set<String> get syncedSessionUuids; bool get isOnline; bool get isSyncingCurrentSession; bool get canSendCurrentSession; String? get currentSessionSyncError; bool get isEnsuringActiveSession; bool get isCreatingOrReusingSession; bool get isLoadingMoreInDrawer; bool get hasMoreInDrawer; int get drawerNextPage; String? get errorMessage;
/// Create a copy of GlobalAiSessionState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GlobalAiSessionStateCopyWith<GlobalAiSessionState> get copyWith => _$GlobalAiSessionStateCopyWithImpl<GlobalAiSessionState>(this as GlobalAiSessionState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GlobalAiSessionState&&(identical(other.currentSessionUuid, currentSessionUuid) || other.currentSessionUuid == currentSessionUuid)&&const DeepCollectionEquality().equals(other.sessions, sessions)&&const DeepCollectionEquality().equals(other.sessionUuidsVisibleInDrawer, sessionUuidsVisibleInDrawer)&&const DeepCollectionEquality().equals(other.draftBySession, draftBySession)&&const DeepCollectionEquality().equals(other.syncedSessionUuids, syncedSessionUuids)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.isSyncingCurrentSession, isSyncingCurrentSession) || other.isSyncingCurrentSession == isSyncingCurrentSession)&&(identical(other.canSendCurrentSession, canSendCurrentSession) || other.canSendCurrentSession == canSendCurrentSession)&&(identical(other.currentSessionSyncError, currentSessionSyncError) || other.currentSessionSyncError == currentSessionSyncError)&&(identical(other.isEnsuringActiveSession, isEnsuringActiveSession) || other.isEnsuringActiveSession == isEnsuringActiveSession)&&(identical(other.isCreatingOrReusingSession, isCreatingOrReusingSession) || other.isCreatingOrReusingSession == isCreatingOrReusingSession)&&(identical(other.isLoadingMoreInDrawer, isLoadingMoreInDrawer) || other.isLoadingMoreInDrawer == isLoadingMoreInDrawer)&&(identical(other.hasMoreInDrawer, hasMoreInDrawer) || other.hasMoreInDrawer == hasMoreInDrawer)&&(identical(other.drawerNextPage, drawerNextPage) || other.drawerNextPage == drawerNextPage)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,currentSessionUuid,const DeepCollectionEquality().hash(sessions),const DeepCollectionEquality().hash(sessionUuidsVisibleInDrawer),const DeepCollectionEquality().hash(draftBySession),const DeepCollectionEquality().hash(syncedSessionUuids),isOnline,isSyncingCurrentSession,canSendCurrentSession,currentSessionSyncError,isEnsuringActiveSession,isCreatingOrReusingSession,isLoadingMoreInDrawer,hasMoreInDrawer,drawerNextPage,errorMessage);

@override
String toString() {
  return 'GlobalAiSessionState(currentSessionUuid: $currentSessionUuid, sessions: $sessions, sessionUuidsVisibleInDrawer: $sessionUuidsVisibleInDrawer, draftBySession: $draftBySession, syncedSessionUuids: $syncedSessionUuids, isOnline: $isOnline, isSyncingCurrentSession: $isSyncingCurrentSession, canSendCurrentSession: $canSendCurrentSession, currentSessionSyncError: $currentSessionSyncError, isEnsuringActiveSession: $isEnsuringActiveSession, isCreatingOrReusingSession: $isCreatingOrReusingSession, isLoadingMoreInDrawer: $isLoadingMoreInDrawer, hasMoreInDrawer: $hasMoreInDrawer, drawerNextPage: $drawerNextPage, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $GlobalAiSessionStateCopyWith<$Res>  {
  factory $GlobalAiSessionStateCopyWith(GlobalAiSessionState value, $Res Function(GlobalAiSessionState) _then) = _$GlobalAiSessionStateCopyWithImpl;
@useResult
$Res call({
 String? currentSessionUuid, List<ChatSession> sessions, List<String> sessionUuidsVisibleInDrawer, Map<String, String> draftBySession, Set<String> syncedSessionUuids, bool isOnline, bool isSyncingCurrentSession, bool canSendCurrentSession, String? currentSessionSyncError, bool isEnsuringActiveSession, bool isCreatingOrReusingSession, bool isLoadingMoreInDrawer, bool hasMoreInDrawer, int drawerNextPage, String? errorMessage
});




}
/// @nodoc
class _$GlobalAiSessionStateCopyWithImpl<$Res>
    implements $GlobalAiSessionStateCopyWith<$Res> {
  _$GlobalAiSessionStateCopyWithImpl(this._self, this._then);

  final GlobalAiSessionState _self;
  final $Res Function(GlobalAiSessionState) _then;

/// Create a copy of GlobalAiSessionState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentSessionUuid = freezed,Object? sessions = null,Object? sessionUuidsVisibleInDrawer = null,Object? draftBySession = null,Object? syncedSessionUuids = null,Object? isOnline = null,Object? isSyncingCurrentSession = null,Object? canSendCurrentSession = null,Object? currentSessionSyncError = freezed,Object? isEnsuringActiveSession = null,Object? isCreatingOrReusingSession = null,Object? isLoadingMoreInDrawer = null,Object? hasMoreInDrawer = null,Object? drawerNextPage = null,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
currentSessionUuid: freezed == currentSessionUuid ? _self.currentSessionUuid : currentSessionUuid // ignore: cast_nullable_to_non_nullable
as String?,sessions: null == sessions ? _self.sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<ChatSession>,sessionUuidsVisibleInDrawer: null == sessionUuidsVisibleInDrawer ? _self.sessionUuidsVisibleInDrawer : sessionUuidsVisibleInDrawer // ignore: cast_nullable_to_non_nullable
as List<String>,draftBySession: null == draftBySession ? _self.draftBySession : draftBySession // ignore: cast_nullable_to_non_nullable
as Map<String, String>,syncedSessionUuids: null == syncedSessionUuids ? _self.syncedSessionUuids : syncedSessionUuids // ignore: cast_nullable_to_non_nullable
as Set<String>,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,isSyncingCurrentSession: null == isSyncingCurrentSession ? _self.isSyncingCurrentSession : isSyncingCurrentSession // ignore: cast_nullable_to_non_nullable
as bool,canSendCurrentSession: null == canSendCurrentSession ? _self.canSendCurrentSession : canSendCurrentSession // ignore: cast_nullable_to_non_nullable
as bool,currentSessionSyncError: freezed == currentSessionSyncError ? _self.currentSessionSyncError : currentSessionSyncError // ignore: cast_nullable_to_non_nullable
as String?,isEnsuringActiveSession: null == isEnsuringActiveSession ? _self.isEnsuringActiveSession : isEnsuringActiveSession // ignore: cast_nullable_to_non_nullable
as bool,isCreatingOrReusingSession: null == isCreatingOrReusingSession ? _self.isCreatingOrReusingSession : isCreatingOrReusingSession // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMoreInDrawer: null == isLoadingMoreInDrawer ? _self.isLoadingMoreInDrawer : isLoadingMoreInDrawer // ignore: cast_nullable_to_non_nullable
as bool,hasMoreInDrawer: null == hasMoreInDrawer ? _self.hasMoreInDrawer : hasMoreInDrawer // ignore: cast_nullable_to_non_nullable
as bool,drawerNextPage: null == drawerNextPage ? _self.drawerNextPage : drawerNextPage // ignore: cast_nullable_to_non_nullable
as int,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [GlobalAiSessionState].
extension GlobalAiSessionStatePatterns on GlobalAiSessionState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GlobalAiSessionState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GlobalAiSessionState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GlobalAiSessionState value)  $default,){
final _that = this;
switch (_that) {
case _GlobalAiSessionState():
return $default(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GlobalAiSessionState value)?  $default,){
final _that = this;
switch (_that) {
case _GlobalAiSessionState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? currentSessionUuid,  List<ChatSession> sessions,  List<String> sessionUuidsVisibleInDrawer,  Map<String, String> draftBySession,  Set<String> syncedSessionUuids,  bool isOnline,  bool isSyncingCurrentSession,  bool canSendCurrentSession,  String? currentSessionSyncError,  bool isEnsuringActiveSession,  bool isCreatingOrReusingSession,  bool isLoadingMoreInDrawer,  bool hasMoreInDrawer,  int drawerNextPage,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GlobalAiSessionState() when $default != null:
return $default(_that.currentSessionUuid,_that.sessions,_that.sessionUuidsVisibleInDrawer,_that.draftBySession,_that.syncedSessionUuids,_that.isOnline,_that.isSyncingCurrentSession,_that.canSendCurrentSession,_that.currentSessionSyncError,_that.isEnsuringActiveSession,_that.isCreatingOrReusingSession,_that.isLoadingMoreInDrawer,_that.hasMoreInDrawer,_that.drawerNextPage,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? currentSessionUuid,  List<ChatSession> sessions,  List<String> sessionUuidsVisibleInDrawer,  Map<String, String> draftBySession,  Set<String> syncedSessionUuids,  bool isOnline,  bool isSyncingCurrentSession,  bool canSendCurrentSession,  String? currentSessionSyncError,  bool isEnsuringActiveSession,  bool isCreatingOrReusingSession,  bool isLoadingMoreInDrawer,  bool hasMoreInDrawer,  int drawerNextPage,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _GlobalAiSessionState():
return $default(_that.currentSessionUuid,_that.sessions,_that.sessionUuidsVisibleInDrawer,_that.draftBySession,_that.syncedSessionUuids,_that.isOnline,_that.isSyncingCurrentSession,_that.canSendCurrentSession,_that.currentSessionSyncError,_that.isEnsuringActiveSession,_that.isCreatingOrReusingSession,_that.isLoadingMoreInDrawer,_that.hasMoreInDrawer,_that.drawerNextPage,_that.errorMessage);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? currentSessionUuid,  List<ChatSession> sessions,  List<String> sessionUuidsVisibleInDrawer,  Map<String, String> draftBySession,  Set<String> syncedSessionUuids,  bool isOnline,  bool isSyncingCurrentSession,  bool canSendCurrentSession,  String? currentSessionSyncError,  bool isEnsuringActiveSession,  bool isCreatingOrReusingSession,  bool isLoadingMoreInDrawer,  bool hasMoreInDrawer,  int drawerNextPage,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _GlobalAiSessionState() when $default != null:
return $default(_that.currentSessionUuid,_that.sessions,_that.sessionUuidsVisibleInDrawer,_that.draftBySession,_that.syncedSessionUuids,_that.isOnline,_that.isSyncingCurrentSession,_that.canSendCurrentSession,_that.currentSessionSyncError,_that.isEnsuringActiveSession,_that.isCreatingOrReusingSession,_that.isLoadingMoreInDrawer,_that.hasMoreInDrawer,_that.drawerNextPage,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _GlobalAiSessionState implements GlobalAiSessionState {
  const _GlobalAiSessionState({this.currentSessionUuid, final  List<ChatSession> sessions = const <ChatSession>[], final  List<String> sessionUuidsVisibleInDrawer = const <String>[], final  Map<String, String> draftBySession = const <String, String>{}, final  Set<String> syncedSessionUuids = const <String>{}, this.isOnline = true, this.isSyncingCurrentSession = false, this.canSendCurrentSession = false, this.currentSessionSyncError, this.isEnsuringActiveSession = false, this.isCreatingOrReusingSession = false, this.isLoadingMoreInDrawer = false, this.hasMoreInDrawer = true, this.drawerNextPage = 0, this.errorMessage}): _sessions = sessions,_sessionUuidsVisibleInDrawer = sessionUuidsVisibleInDrawer,_draftBySession = draftBySession,_syncedSessionUuids = syncedSessionUuids;
  

@override final  String? currentSessionUuid;
 final  List<ChatSession> _sessions;
@override@JsonKey() List<ChatSession> get sessions {
  if (_sessions is EqualUnmodifiableListView) return _sessions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessions);
}

 final  List<String> _sessionUuidsVisibleInDrawer;
@override@JsonKey() List<String> get sessionUuidsVisibleInDrawer {
  if (_sessionUuidsVisibleInDrawer is EqualUnmodifiableListView) return _sessionUuidsVisibleInDrawer;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sessionUuidsVisibleInDrawer);
}

 final  Map<String, String> _draftBySession;
@override@JsonKey() Map<String, String> get draftBySession {
  if (_draftBySession is EqualUnmodifiableMapView) return _draftBySession;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_draftBySession);
}

 final  Set<String> _syncedSessionUuids;
@override@JsonKey() Set<String> get syncedSessionUuids {
  if (_syncedSessionUuids is EqualUnmodifiableSetView) return _syncedSessionUuids;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_syncedSessionUuids);
}

@override@JsonKey() final  bool isOnline;
@override@JsonKey() final  bool isSyncingCurrentSession;
@override@JsonKey() final  bool canSendCurrentSession;
@override final  String? currentSessionSyncError;
@override@JsonKey() final  bool isEnsuringActiveSession;
@override@JsonKey() final  bool isCreatingOrReusingSession;
@override@JsonKey() final  bool isLoadingMoreInDrawer;
@override@JsonKey() final  bool hasMoreInDrawer;
@override@JsonKey() final  int drawerNextPage;
@override final  String? errorMessage;

/// Create a copy of GlobalAiSessionState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GlobalAiSessionStateCopyWith<_GlobalAiSessionState> get copyWith => __$GlobalAiSessionStateCopyWithImpl<_GlobalAiSessionState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GlobalAiSessionState&&(identical(other.currentSessionUuid, currentSessionUuid) || other.currentSessionUuid == currentSessionUuid)&&const DeepCollectionEquality().equals(other._sessions, _sessions)&&const DeepCollectionEquality().equals(other._sessionUuidsVisibleInDrawer, _sessionUuidsVisibleInDrawer)&&const DeepCollectionEquality().equals(other._draftBySession, _draftBySession)&&const DeepCollectionEquality().equals(other._syncedSessionUuids, _syncedSessionUuids)&&(identical(other.isOnline, isOnline) || other.isOnline == isOnline)&&(identical(other.isSyncingCurrentSession, isSyncingCurrentSession) || other.isSyncingCurrentSession == isSyncingCurrentSession)&&(identical(other.canSendCurrentSession, canSendCurrentSession) || other.canSendCurrentSession == canSendCurrentSession)&&(identical(other.currentSessionSyncError, currentSessionSyncError) || other.currentSessionSyncError == currentSessionSyncError)&&(identical(other.isEnsuringActiveSession, isEnsuringActiveSession) || other.isEnsuringActiveSession == isEnsuringActiveSession)&&(identical(other.isCreatingOrReusingSession, isCreatingOrReusingSession) || other.isCreatingOrReusingSession == isCreatingOrReusingSession)&&(identical(other.isLoadingMoreInDrawer, isLoadingMoreInDrawer) || other.isLoadingMoreInDrawer == isLoadingMoreInDrawer)&&(identical(other.hasMoreInDrawer, hasMoreInDrawer) || other.hasMoreInDrawer == hasMoreInDrawer)&&(identical(other.drawerNextPage, drawerNextPage) || other.drawerNextPage == drawerNextPage)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,currentSessionUuid,const DeepCollectionEquality().hash(_sessions),const DeepCollectionEquality().hash(_sessionUuidsVisibleInDrawer),const DeepCollectionEquality().hash(_draftBySession),const DeepCollectionEquality().hash(_syncedSessionUuids),isOnline,isSyncingCurrentSession,canSendCurrentSession,currentSessionSyncError,isEnsuringActiveSession,isCreatingOrReusingSession,isLoadingMoreInDrawer,hasMoreInDrawer,drawerNextPage,errorMessage);

@override
String toString() {
  return 'GlobalAiSessionState(currentSessionUuid: $currentSessionUuid, sessions: $sessions, sessionUuidsVisibleInDrawer: $sessionUuidsVisibleInDrawer, draftBySession: $draftBySession, syncedSessionUuids: $syncedSessionUuids, isOnline: $isOnline, isSyncingCurrentSession: $isSyncingCurrentSession, canSendCurrentSession: $canSendCurrentSession, currentSessionSyncError: $currentSessionSyncError, isEnsuringActiveSession: $isEnsuringActiveSession, isCreatingOrReusingSession: $isCreatingOrReusingSession, isLoadingMoreInDrawer: $isLoadingMoreInDrawer, hasMoreInDrawer: $hasMoreInDrawer, drawerNextPage: $drawerNextPage, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$GlobalAiSessionStateCopyWith<$Res> implements $GlobalAiSessionStateCopyWith<$Res> {
  factory _$GlobalAiSessionStateCopyWith(_GlobalAiSessionState value, $Res Function(_GlobalAiSessionState) _then) = __$GlobalAiSessionStateCopyWithImpl;
@override @useResult
$Res call({
 String? currentSessionUuid, List<ChatSession> sessions, List<String> sessionUuidsVisibleInDrawer, Map<String, String> draftBySession, Set<String> syncedSessionUuids, bool isOnline, bool isSyncingCurrentSession, bool canSendCurrentSession, String? currentSessionSyncError, bool isEnsuringActiveSession, bool isCreatingOrReusingSession, bool isLoadingMoreInDrawer, bool hasMoreInDrawer, int drawerNextPage, String? errorMessage
});




}
/// @nodoc
class __$GlobalAiSessionStateCopyWithImpl<$Res>
    implements _$GlobalAiSessionStateCopyWith<$Res> {
  __$GlobalAiSessionStateCopyWithImpl(this._self, this._then);

  final _GlobalAiSessionState _self;
  final $Res Function(_GlobalAiSessionState) _then;

/// Create a copy of GlobalAiSessionState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentSessionUuid = freezed,Object? sessions = null,Object? sessionUuidsVisibleInDrawer = null,Object? draftBySession = null,Object? syncedSessionUuids = null,Object? isOnline = null,Object? isSyncingCurrentSession = null,Object? canSendCurrentSession = null,Object? currentSessionSyncError = freezed,Object? isEnsuringActiveSession = null,Object? isCreatingOrReusingSession = null,Object? isLoadingMoreInDrawer = null,Object? hasMoreInDrawer = null,Object? drawerNextPage = null,Object? errorMessage = freezed,}) {
  return _then(_GlobalAiSessionState(
currentSessionUuid: freezed == currentSessionUuid ? _self.currentSessionUuid : currentSessionUuid // ignore: cast_nullable_to_non_nullable
as String?,sessions: null == sessions ? _self._sessions : sessions // ignore: cast_nullable_to_non_nullable
as List<ChatSession>,sessionUuidsVisibleInDrawer: null == sessionUuidsVisibleInDrawer ? _self._sessionUuidsVisibleInDrawer : sessionUuidsVisibleInDrawer // ignore: cast_nullable_to_non_nullable
as List<String>,draftBySession: null == draftBySession ? _self._draftBySession : draftBySession // ignore: cast_nullable_to_non_nullable
as Map<String, String>,syncedSessionUuids: null == syncedSessionUuids ? _self._syncedSessionUuids : syncedSessionUuids // ignore: cast_nullable_to_non_nullable
as Set<String>,isOnline: null == isOnline ? _self.isOnline : isOnline // ignore: cast_nullable_to_non_nullable
as bool,isSyncingCurrentSession: null == isSyncingCurrentSession ? _self.isSyncingCurrentSession : isSyncingCurrentSession // ignore: cast_nullable_to_non_nullable
as bool,canSendCurrentSession: null == canSendCurrentSession ? _self.canSendCurrentSession : canSendCurrentSession // ignore: cast_nullable_to_non_nullable
as bool,currentSessionSyncError: freezed == currentSessionSyncError ? _self.currentSessionSyncError : currentSessionSyncError // ignore: cast_nullable_to_non_nullable
as String?,isEnsuringActiveSession: null == isEnsuringActiveSession ? _self.isEnsuringActiveSession : isEnsuringActiveSession // ignore: cast_nullable_to_non_nullable
as bool,isCreatingOrReusingSession: null == isCreatingOrReusingSession ? _self.isCreatingOrReusingSession : isCreatingOrReusingSession // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMoreInDrawer: null == isLoadingMoreInDrawer ? _self.isLoadingMoreInDrawer : isLoadingMoreInDrawer // ignore: cast_nullable_to_non_nullable
as bool,hasMoreInDrawer: null == hasMoreInDrawer ? _self.hasMoreInDrawer : hasMoreInDrawer // ignore: cast_nullable_to_non_nullable
as bool,drawerNextPage: null == drawerNextPage ? _self.drawerNextPage : drawerNextPage // ignore: cast_nullable_to_non_nullable
as int,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

/// @nodoc
mixin _$ChatLiveBlock {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatLiveBlock);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatLiveBlock()';
}


}

/// @nodoc
class $ChatLiveBlockCopyWith<$Res>  {
$ChatLiveBlockCopyWith(ChatLiveBlock _, $Res Function(ChatLiveBlock) __);
}


/// Adds pattern-matching-related methods to [ChatLiveBlock].
extension ChatLiveBlockPatterns on ChatLiveBlock {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ChatLiveTextBlock value)?  text,TResult Function( ChatLiveToolCallBlock value)?  toolCall,TResult Function( ChatLiveA2uiBlock value)?  a2ui,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ChatLiveTextBlock() when text != null:
return text(_that);case ChatLiveToolCallBlock() when toolCall != null:
return toolCall(_that);case ChatLiveA2uiBlock() when a2ui != null:
return a2ui(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ChatLiveTextBlock value)  text,required TResult Function( ChatLiveToolCallBlock value)  toolCall,required TResult Function( ChatLiveA2uiBlock value)  a2ui,}){
final _that = this;
switch (_that) {
case ChatLiveTextBlock():
return text(_that);case ChatLiveToolCallBlock():
return toolCall(_that);case ChatLiveA2uiBlock():
return a2ui(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ChatLiveTextBlock value)?  text,TResult? Function( ChatLiveToolCallBlock value)?  toolCall,TResult? Function( ChatLiveA2uiBlock value)?  a2ui,}){
final _that = this;
switch (_that) {
case ChatLiveTextBlock() when text != null:
return text(_that);case ChatLiveToolCallBlock() when toolCall != null:
return toolCall(_that);case ChatLiveA2uiBlock() when a2ui != null:
return a2ui(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String content)?  text,TResult Function( String toolCallId,  String toolName,  bool done)?  toolCall,TResult Function( List<String> chunks)?  a2ui,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChatLiveTextBlock() when text != null:
return text(_that.content);case ChatLiveToolCallBlock() when toolCall != null:
return toolCall(_that.toolCallId,_that.toolName,_that.done);case ChatLiveA2uiBlock() when a2ui != null:
return a2ui(_that.chunks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String content)  text,required TResult Function( String toolCallId,  String toolName,  bool done)  toolCall,required TResult Function( List<String> chunks)  a2ui,}) {final _that = this;
switch (_that) {
case ChatLiveTextBlock():
return text(_that.content);case ChatLiveToolCallBlock():
return toolCall(_that.toolCallId,_that.toolName,_that.done);case ChatLiveA2uiBlock():
return a2ui(_that.chunks);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String content)?  text,TResult? Function( String toolCallId,  String toolName,  bool done)?  toolCall,TResult? Function( List<String> chunks)?  a2ui,}) {final _that = this;
switch (_that) {
case ChatLiveTextBlock() when text != null:
return text(_that.content);case ChatLiveToolCallBlock() when toolCall != null:
return toolCall(_that.toolCallId,_that.toolName,_that.done);case ChatLiveA2uiBlock() when a2ui != null:
return a2ui(_that.chunks);case _:
  return null;

}
}

}

/// @nodoc


class ChatLiveTextBlock implements ChatLiveBlock {
  const ChatLiveTextBlock(this.content);
  

 final  String content;

/// Create a copy of ChatLiveBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatLiveTextBlockCopyWith<ChatLiveTextBlock> get copyWith => _$ChatLiveTextBlockCopyWithImpl<ChatLiveTextBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatLiveTextBlock&&(identical(other.content, content) || other.content == content));
}


@override
int get hashCode => Object.hash(runtimeType,content);

@override
String toString() {
  return 'ChatLiveBlock.text(content: $content)';
}


}

/// @nodoc
abstract mixin class $ChatLiveTextBlockCopyWith<$Res> implements $ChatLiveBlockCopyWith<$Res> {
  factory $ChatLiveTextBlockCopyWith(ChatLiveTextBlock value, $Res Function(ChatLiveTextBlock) _then) = _$ChatLiveTextBlockCopyWithImpl;
@useResult
$Res call({
 String content
});




}
/// @nodoc
class _$ChatLiveTextBlockCopyWithImpl<$Res>
    implements $ChatLiveTextBlockCopyWith<$Res> {
  _$ChatLiveTextBlockCopyWithImpl(this._self, this._then);

  final ChatLiveTextBlock _self;
  final $Res Function(ChatLiveTextBlock) _then;

/// Create a copy of ChatLiveBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? content = null,}) {
  return _then(ChatLiveTextBlock(
null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ChatLiveToolCallBlock implements ChatLiveBlock {
  const ChatLiveToolCallBlock({required this.toolCallId, required this.toolName, required this.done});
  

 final  String toolCallId;
 final  String toolName;
 final  bool done;

/// Create a copy of ChatLiveBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatLiveToolCallBlockCopyWith<ChatLiveToolCallBlock> get copyWith => _$ChatLiveToolCallBlockCopyWithImpl<ChatLiveToolCallBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatLiveToolCallBlock&&(identical(other.toolCallId, toolCallId) || other.toolCallId == toolCallId)&&(identical(other.toolName, toolName) || other.toolName == toolName)&&(identical(other.done, done) || other.done == done));
}


@override
int get hashCode => Object.hash(runtimeType,toolCallId,toolName,done);

@override
String toString() {
  return 'ChatLiveBlock.toolCall(toolCallId: $toolCallId, toolName: $toolName, done: $done)';
}


}

/// @nodoc
abstract mixin class $ChatLiveToolCallBlockCopyWith<$Res> implements $ChatLiveBlockCopyWith<$Res> {
  factory $ChatLiveToolCallBlockCopyWith(ChatLiveToolCallBlock value, $Res Function(ChatLiveToolCallBlock) _then) = _$ChatLiveToolCallBlockCopyWithImpl;
@useResult
$Res call({
 String toolCallId, String toolName, bool done
});




}
/// @nodoc
class _$ChatLiveToolCallBlockCopyWithImpl<$Res>
    implements $ChatLiveToolCallBlockCopyWith<$Res> {
  _$ChatLiveToolCallBlockCopyWithImpl(this._self, this._then);

  final ChatLiveToolCallBlock _self;
  final $Res Function(ChatLiveToolCallBlock) _then;

/// Create a copy of ChatLiveBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? toolCallId = null,Object? toolName = null,Object? done = null,}) {
  return _then(ChatLiveToolCallBlock(
toolCallId: null == toolCallId ? _self.toolCallId : toolCallId // ignore: cast_nullable_to_non_nullable
as String,toolName: null == toolName ? _self.toolName : toolName // ignore: cast_nullable_to_non_nullable
as String,done: null == done ? _self.done : done // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc


class ChatLiveA2uiBlock implements ChatLiveBlock {
  const ChatLiveA2uiBlock(final  List<String> chunks): _chunks = chunks;
  

 final  List<String> _chunks;
 List<String> get chunks {
  if (_chunks is EqualUnmodifiableListView) return _chunks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_chunks);
}


/// Create a copy of ChatLiveBlock
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatLiveA2uiBlockCopyWith<ChatLiveA2uiBlock> get copyWith => _$ChatLiveA2uiBlockCopyWithImpl<ChatLiveA2uiBlock>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatLiveA2uiBlock&&const DeepCollectionEquality().equals(other._chunks, _chunks));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_chunks));

@override
String toString() {
  return 'ChatLiveBlock.a2ui(chunks: $chunks)';
}


}

/// @nodoc
abstract mixin class $ChatLiveA2uiBlockCopyWith<$Res> implements $ChatLiveBlockCopyWith<$Res> {
  factory $ChatLiveA2uiBlockCopyWith(ChatLiveA2uiBlock value, $Res Function(ChatLiveA2uiBlock) _then) = _$ChatLiveA2uiBlockCopyWithImpl;
@useResult
$Res call({
 List<String> chunks
});




}
/// @nodoc
class _$ChatLiveA2uiBlockCopyWithImpl<$Res>
    implements $ChatLiveA2uiBlockCopyWith<$Res> {
  _$ChatLiveA2uiBlockCopyWithImpl(this._self, this._then);

  final ChatLiveA2uiBlock _self;
  final $Res Function(ChatLiveA2uiBlock) _then;

/// Create a copy of ChatLiveBlock
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? chunks = null,}) {
  return _then(ChatLiveA2uiBlock(
null == chunks ? _self._chunks : chunks // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}


}

/// @nodoc
mixin _$ChatSendState {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSendState);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatSendState()';
}


}

/// @nodoc
class $ChatSendStateCopyWith<$Res>  {
$ChatSendStateCopyWith(ChatSendState _, $Res Function(ChatSendState) __);
}


/// Adds pattern-matching-related methods to [ChatSendState].
extension ChatSendStatePatterns on ChatSendState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ChatSendIdle value)?  idle,TResult Function( ChatSendStreaming value)?  streaming,TResult Function( ChatSendError value)?  error,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ChatSendIdle() when idle != null:
return idle(_that);case ChatSendStreaming() when streaming != null:
return streaming(_that);case ChatSendError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ChatSendIdle value)  idle,required TResult Function( ChatSendStreaming value)  streaming,required TResult Function( ChatSendError value)  error,}){
final _that = this;
switch (_that) {
case ChatSendIdle():
return idle(_that);case ChatSendStreaming():
return streaming(_that);case ChatSendError():
return error(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ChatSendIdle value)?  idle,TResult? Function( ChatSendStreaming value)?  streaming,TResult? Function( ChatSendError value)?  error,}){
final _that = this;
switch (_that) {
case ChatSendIdle() when idle != null:
return idle(_that);case ChatSendStreaming() when streaming != null:
return streaming(_that);case ChatSendError() when error != null:
return error(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( List<ChatLiveBlock> blocks,  String pendingUserMessage)?  streaming,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChatSendIdle() when idle != null:
return idle();case ChatSendStreaming() when streaming != null:
return streaming(_that.blocks,_that.pendingUserMessage);case ChatSendError() when error != null:
return error(_that.message);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( List<ChatLiveBlock> blocks,  String pendingUserMessage)  streaming,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case ChatSendIdle():
return idle();case ChatSendStreaming():
return streaming(_that.blocks,_that.pendingUserMessage);case ChatSendError():
return error(_that.message);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( List<ChatLiveBlock> blocks,  String pendingUserMessage)?  streaming,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case ChatSendIdle() when idle != null:
return idle();case ChatSendStreaming() when streaming != null:
return streaming(_that.blocks,_that.pendingUserMessage);case ChatSendError() when error != null:
return error(_that.message);case _:
  return null;

}
}

}

/// @nodoc


class ChatSendIdle implements ChatSendState {
  const ChatSendIdle();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSendIdle);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ChatSendState.idle()';
}


}




/// @nodoc


class ChatSendStreaming implements ChatSendState {
  const ChatSendStreaming({required final  List<ChatLiveBlock> blocks, required this.pendingUserMessage}): _blocks = blocks;
  

 final  List<ChatLiveBlock> _blocks;
 List<ChatLiveBlock> get blocks {
  if (_blocks is EqualUnmodifiableListView) return _blocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_blocks);
}

 final  String pendingUserMessage;

/// Create a copy of ChatSendState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSendStreamingCopyWith<ChatSendStreaming> get copyWith => _$ChatSendStreamingCopyWithImpl<ChatSendStreaming>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSendStreaming&&const DeepCollectionEquality().equals(other._blocks, _blocks)&&(identical(other.pendingUserMessage, pendingUserMessage) || other.pendingUserMessage == pendingUserMessage));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_blocks),pendingUserMessage);

@override
String toString() {
  return 'ChatSendState.streaming(blocks: $blocks, pendingUserMessage: $pendingUserMessage)';
}


}

/// @nodoc
abstract mixin class $ChatSendStreamingCopyWith<$Res> implements $ChatSendStateCopyWith<$Res> {
  factory $ChatSendStreamingCopyWith(ChatSendStreaming value, $Res Function(ChatSendStreaming) _then) = _$ChatSendStreamingCopyWithImpl;
@useResult
$Res call({
 List<ChatLiveBlock> blocks, String pendingUserMessage
});




}
/// @nodoc
class _$ChatSendStreamingCopyWithImpl<$Res>
    implements $ChatSendStreamingCopyWith<$Res> {
  _$ChatSendStreamingCopyWithImpl(this._self, this._then);

  final ChatSendStreaming _self;
  final $Res Function(ChatSendStreaming) _then;

/// Create a copy of ChatSendState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? blocks = null,Object? pendingUserMessage = null,}) {
  return _then(ChatSendStreaming(
blocks: null == blocks ? _self._blocks : blocks // ignore: cast_nullable_to_non_nullable
as List<ChatLiveBlock>,pendingUserMessage: null == pendingUserMessage ? _self.pendingUserMessage : pendingUserMessage // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ChatSendError implements ChatSendState {
  const ChatSendError({required this.message});
  

 final  String message;

/// Create a copy of ChatSendState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSendErrorCopyWith<ChatSendError> get copyWith => _$ChatSendErrorCopyWithImpl<ChatSendError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSendError&&(identical(other.message, message) || other.message == message));
}


@override
int get hashCode => Object.hash(runtimeType,message);

@override
String toString() {
  return 'ChatSendState.error(message: $message)';
}


}

/// @nodoc
abstract mixin class $ChatSendErrorCopyWith<$Res> implements $ChatSendStateCopyWith<$Res> {
  factory $ChatSendErrorCopyWith(ChatSendError value, $Res Function(ChatSendError) _then) = _$ChatSendErrorCopyWithImpl;
@useResult
$Res call({
 String message
});




}
/// @nodoc
class _$ChatSendErrorCopyWithImpl<$Res>
    implements $ChatSendErrorCopyWith<$Res> {
  _$ChatSendErrorCopyWithImpl(this._self, this._then);

  final ChatSendError _self;
  final $Res Function(ChatSendError) _then;

/// Create a copy of ChatSendState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? message = null,}) {
  return _then(ChatSendError(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
