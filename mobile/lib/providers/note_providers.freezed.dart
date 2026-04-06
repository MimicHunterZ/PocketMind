// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'note_providers.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NoteDetailState implements DiagnosticableTreeMixin {

 Note get note; bool get isLoading; List<String> get tags; bool get isSaving; Object? get error;
/// Create a copy of NoteDetailState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NoteDetailStateCopyWith<NoteDetailState> get copyWith => _$NoteDetailStateCopyWithImpl<NoteDetailState>(this as NoteDetailState, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'NoteDetailState'))
    ..add(DiagnosticsProperty('note', note))..add(DiagnosticsProperty('isLoading', isLoading))..add(DiagnosticsProperty('tags', tags))..add(DiagnosticsProperty('isSaving', isSaving))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NoteDetailState&&(identical(other.note, note) || other.note == note)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other.tags, tags)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,note,isLoading,const DeepCollectionEquality().hash(tags),isSaving,const DeepCollectionEquality().hash(error));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'NoteDetailState(note: $note, isLoading: $isLoading, tags: $tags, isSaving: $isSaving, error: $error)';
}


}

/// @nodoc
abstract mixin class $NoteDetailStateCopyWith<$Res>  {
  factory $NoteDetailStateCopyWith(NoteDetailState value, $Res Function(NoteDetailState) _then) = _$NoteDetailStateCopyWithImpl;
@useResult
$Res call({
 Note note, bool isLoading, List<String> tags, bool isSaving, Object? error
});




}
/// @nodoc
class _$NoteDetailStateCopyWithImpl<$Res>
    implements $NoteDetailStateCopyWith<$Res> {
  _$NoteDetailStateCopyWithImpl(this._self, this._then);

  final NoteDetailState _self;
  final $Res Function(NoteDetailState) _then;

/// Create a copy of NoteDetailState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? note = null,Object? isLoading = null,Object? tags = null,Object? isSaving = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as Note,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self.tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}

}


/// Adds pattern-matching-related methods to [NoteDetailState].
extension NoteDetailStatePatterns on NoteDetailState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NoteDetailState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NoteDetailState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NoteDetailState value)  $default,){
final _that = this;
switch (_that) {
case _NoteDetailState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NoteDetailState value)?  $default,){
final _that = this;
switch (_that) {
case _NoteDetailState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Note note,  bool isLoading,  List<String> tags,  bool isSaving,  Object? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NoteDetailState() when $default != null:
return $default(_that.note,_that.isLoading,_that.tags,_that.isSaving,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Note note,  bool isLoading,  List<String> tags,  bool isSaving,  Object? error)  $default,) {final _that = this;
switch (_that) {
case _NoteDetailState():
return $default(_that.note,_that.isLoading,_that.tags,_that.isSaving,_that.error);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Note note,  bool isLoading,  List<String> tags,  bool isSaving,  Object? error)?  $default,) {final _that = this;
switch (_that) {
case _NoteDetailState() when $default != null:
return $default(_that.note,_that.isLoading,_that.tags,_that.isSaving,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _NoteDetailState with DiagnosticableTreeMixin implements NoteDetailState {
  const _NoteDetailState({required this.note, this.isLoading = false, final  List<String> tags = const [], this.isSaving = false, this.error}): _tags = tags;
  

@override final  Note note;
@override@JsonKey() final  bool isLoading;
 final  List<String> _tags;
@override@JsonKey() List<String> get tags {
  if (_tags is EqualUnmodifiableListView) return _tags;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_tags);
}

@override@JsonKey() final  bool isSaving;
@override final  Object? error;

/// Create a copy of NoteDetailState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NoteDetailStateCopyWith<_NoteDetailState> get copyWith => __$NoteDetailStateCopyWithImpl<_NoteDetailState>(this, _$identity);


@override
void debugFillProperties(DiagnosticPropertiesBuilder properties) {
  properties
    ..add(DiagnosticsProperty('type', 'NoteDetailState'))
    ..add(DiagnosticsProperty('note', note))..add(DiagnosticsProperty('isLoading', isLoading))..add(DiagnosticsProperty('tags', tags))..add(DiagnosticsProperty('isSaving', isSaving))..add(DiagnosticsProperty('error', error));
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _NoteDetailState&&(identical(other.note, note) || other.note == note)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other._tags, _tags)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving)&&const DeepCollectionEquality().equals(other.error, error));
}


@override
int get hashCode => Object.hash(runtimeType,note,isLoading,const DeepCollectionEquality().hash(_tags),isSaving,const DeepCollectionEquality().hash(error));

@override
String toString({ DiagnosticLevel minLevel = DiagnosticLevel.info }) {
  return 'NoteDetailState(note: $note, isLoading: $isLoading, tags: $tags, isSaving: $isSaving, error: $error)';
}


}

/// @nodoc
abstract mixin class _$NoteDetailStateCopyWith<$Res> implements $NoteDetailStateCopyWith<$Res> {
  factory _$NoteDetailStateCopyWith(_NoteDetailState value, $Res Function(_NoteDetailState) _then) = __$NoteDetailStateCopyWithImpl;
@override @useResult
$Res call({
 Note note, bool isLoading, List<String> tags, bool isSaving, Object? error
});




}
/// @nodoc
class __$NoteDetailStateCopyWithImpl<$Res>
    implements _$NoteDetailStateCopyWith<$Res> {
  __$NoteDetailStateCopyWithImpl(this._self, this._then);

  final _NoteDetailState _self;
  final $Res Function(_NoteDetailState) _then;

/// Create a copy of NoteDetailState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? note = null,Object? isLoading = null,Object? tags = null,Object? isSaving = null,Object? error = freezed,}) {
  return _then(_NoteDetailState(
note: null == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as Note,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,tags: null == tags ? _self._tags : tags // ignore: cast_nullable_to_non_nullable
as List<String>,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error ,
  ));
}


}

// dart format on
