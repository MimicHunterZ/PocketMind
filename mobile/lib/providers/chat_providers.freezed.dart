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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function()?  idle,TResult Function( String content,  String pendingUserMessage)?  streaming,TResult Function( String message)?  error,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ChatSendIdle() when idle != null:
return idle();case ChatSendStreaming() when streaming != null:
return streaming(_that.content,_that.pendingUserMessage);case ChatSendError() when error != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function()  idle,required TResult Function( String content,  String pendingUserMessage)  streaming,required TResult Function( String message)  error,}) {final _that = this;
switch (_that) {
case ChatSendIdle():
return idle();case ChatSendStreaming():
return streaming(_that.content,_that.pendingUserMessage);case ChatSendError():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function()?  idle,TResult? Function( String content,  String pendingUserMessage)?  streaming,TResult? Function( String message)?  error,}) {final _that = this;
switch (_that) {
case ChatSendIdle() when idle != null:
return idle();case ChatSendStreaming() when streaming != null:
return streaming(_that.content,_that.pendingUserMessage);case ChatSendError() when error != null:
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
  const ChatSendStreaming({required this.content, required this.pendingUserMessage});
  

 final  String content;
 final  String pendingUserMessage;

/// Create a copy of ChatSendState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ChatSendStreamingCopyWith<ChatSendStreaming> get copyWith => _$ChatSendStreamingCopyWithImpl<ChatSendStreaming>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ChatSendStreaming&&(identical(other.content, content) || other.content == content)&&(identical(other.pendingUserMessage, pendingUserMessage) || other.pendingUserMessage == pendingUserMessage));
}


@override
int get hashCode => Object.hash(runtimeType,content,pendingUserMessage);

@override
String toString() {
  return 'ChatSendState.streaming(content: $content, pendingUserMessage: $pendingUserMessage)';
}


}

/// @nodoc
abstract mixin class $ChatSendStreamingCopyWith<$Res> implements $ChatSendStateCopyWith<$Res> {
  factory $ChatSendStreamingCopyWith(ChatSendStreaming value, $Res Function(ChatSendStreaming) _then) = _$ChatSendStreamingCopyWithImpl;
@useResult
$Res call({
 String content, String pendingUserMessage
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
@pragma('vm:prefer-inline') $Res call({Object? content = null,Object? pendingUserMessage = null,}) {
  return _then(ChatSendStreaming(
content: null == content ? _self.content : content // ignore: cast_nullable_to_non_nullable
as String,pendingUserMessage: null == pendingUserMessage ? _self.pendingUserMessage : pendingUserMessage // ignore: cast_nullable_to_non_nullable
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
