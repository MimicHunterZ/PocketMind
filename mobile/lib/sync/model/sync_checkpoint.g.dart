// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sync_checkpoint.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSyncCheckpointCollection on Isar {
  IsarCollection<SyncCheckpoint> get syncCheckpoints => this.collection();
}

const SyncCheckpointSchema = CollectionSchema(
  name: r'SyncCheckpoint',
  id: -3362950696409054465,
  properties: {
    r'lastPulledVersion': PropertySchema(
      id: 0,
      name: r'lastPulledVersion',
      type: IsarType.long,
    ),
    r'lastSyncedAt': PropertySchema(
      id: 1,
      name: r'lastSyncedAt',
      type: IsarType.long,
    ),
    r'userId': PropertySchema(id: 2, name: r'userId', type: IsarType.string),
  },

  estimateSize: _syncCheckpointEstimateSize,
  serialize: _syncCheckpointSerialize,
  deserialize: _syncCheckpointDeserialize,
  deserializeProp: _syncCheckpointDeserializeProp,
  idName: r'id',
  indexes: {
    r'userId': IndexSchema(
      id: -2005826577402374815,
      name: r'userId',
      unique: true,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'userId',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _syncCheckpointGetId,
  getLinks: _syncCheckpointGetLinks,
  attach: _syncCheckpointAttach,
  version: '3.3.0-dev.3',
);

int _syncCheckpointEstimateSize(
  SyncCheckpoint object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.userId.length * 3;
  return bytesCount;
}

void _syncCheckpointSerialize(
  SyncCheckpoint object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.lastPulledVersion);
  writer.writeLong(offsets[1], object.lastSyncedAt);
  writer.writeString(offsets[2], object.userId);
}

SyncCheckpoint _syncCheckpointDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SyncCheckpoint();
  object.id = id;
  object.lastPulledVersion = reader.readLong(offsets[0]);
  object.lastSyncedAt = reader.readLong(offsets[1]);
  object.userId = reader.readString(offsets[2]);
  return object;
}

P _syncCheckpointDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readLong(offset)) as P;
    case 2:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _syncCheckpointGetId(SyncCheckpoint object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _syncCheckpointGetLinks(SyncCheckpoint object) {
  return [];
}

void _syncCheckpointAttach(
  IsarCollection<dynamic> col,
  Id id,
  SyncCheckpoint object,
) {
  object.id = id;
}

extension SyncCheckpointByIndex on IsarCollection<SyncCheckpoint> {
  Future<SyncCheckpoint?> getByUserId(String userId) {
    return getByIndex(r'userId', [userId]);
  }

  SyncCheckpoint? getByUserIdSync(String userId) {
    return getByIndexSync(r'userId', [userId]);
  }

  Future<bool> deleteByUserId(String userId) {
    return deleteByIndex(r'userId', [userId]);
  }

  bool deleteByUserIdSync(String userId) {
    return deleteByIndexSync(r'userId', [userId]);
  }

  Future<List<SyncCheckpoint?>> getAllByUserId(List<String> userIdValues) {
    final values = userIdValues.map((e) => [e]).toList();
    return getAllByIndex(r'userId', values);
  }

  List<SyncCheckpoint?> getAllByUserIdSync(List<String> userIdValues) {
    final values = userIdValues.map((e) => [e]).toList();
    return getAllByIndexSync(r'userId', values);
  }

  Future<int> deleteAllByUserId(List<String> userIdValues) {
    final values = userIdValues.map((e) => [e]).toList();
    return deleteAllByIndex(r'userId', values);
  }

  int deleteAllByUserIdSync(List<String> userIdValues) {
    final values = userIdValues.map((e) => [e]).toList();
    return deleteAllByIndexSync(r'userId', values);
  }

  Future<Id> putByUserId(SyncCheckpoint object) {
    return putByIndex(r'userId', object);
  }

  Id putByUserIdSync(SyncCheckpoint object, {bool saveLinks = true}) {
    return putByIndexSync(r'userId', object, saveLinks: saveLinks);
  }

  Future<List<Id>> putAllByUserId(List<SyncCheckpoint> objects) {
    return putAllByIndex(r'userId', objects);
  }

  List<Id> putAllByUserIdSync(
    List<SyncCheckpoint> objects, {
    bool saveLinks = true,
  }) {
    return putAllByIndexSync(r'userId', objects, saveLinks: saveLinks);
  }
}

extension SyncCheckpointQueryWhereSort
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QWhere> {
  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SyncCheckpointQueryWhere
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QWhereClause> {
  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause> idNotEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.between(
          lower: lowerId,
          includeLower: includeLower,
          upper: upperId,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause> userIdEqualTo(
    String userId,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'userId', value: [userId]),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterWhereClause>
  userIdNotEqualTo(String userId) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'userId',
                lower: [],
                upper: [userId],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'userId',
                lower: [userId],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'userId',
                lower: [userId],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'userId',
                lower: [],
                upper: [userId],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension SyncCheckpointQueryFilter
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QFilterCondition> {
  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition> idEqualTo(
    Id value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  idGreaterThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  idLessThan(Id value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'id',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'id',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastPulledVersionEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastPulledVersion', value: value),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastPulledVersionGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastPulledVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastPulledVersionLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastPulledVersion',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastPulledVersionBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastPulledVersion',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastSyncedAtEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'lastSyncedAt', value: value),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastSyncedAtGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'lastSyncedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastSyncedAtLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'lastSyncedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  lastSyncedAtBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'lastSyncedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'userId',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'userId',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'userId',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'userId', value: ''),
      );
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterFilterCondition>
  userIdIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'userId', value: ''),
      );
    });
  }
}

extension SyncCheckpointQueryObject
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QFilterCondition> {}

extension SyncCheckpointQueryLinks
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QFilterCondition> {}

extension SyncCheckpointQuerySortBy
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QSortBy> {
  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  sortByLastPulledVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledVersion', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  sortByLastPulledVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledVersion', Sort.desc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  sortByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  sortByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy> sortByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  sortByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension SyncCheckpointQuerySortThenBy
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QSortThenBy> {
  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  thenByLastPulledVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledVersion', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  thenByLastPulledVersionDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastPulledVersion', Sort.desc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  thenByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  thenByLastSyncedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastSyncedAt', Sort.desc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy> thenByUserId() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.asc);
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QAfterSortBy>
  thenByUserIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'userId', Sort.desc);
    });
  }
}

extension SyncCheckpointQueryWhereDistinct
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QDistinct> {
  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QDistinct>
  distinctByLastPulledVersion() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastPulledVersion');
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QDistinct>
  distinctByLastSyncedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastSyncedAt');
    });
  }

  QueryBuilder<SyncCheckpoint, SyncCheckpoint, QDistinct> distinctByUserId({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'userId', caseSensitive: caseSensitive);
    });
  }
}

extension SyncCheckpointQueryProperty
    on QueryBuilder<SyncCheckpoint, SyncCheckpoint, QQueryProperty> {
  QueryBuilder<SyncCheckpoint, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SyncCheckpoint, int, QQueryOperations>
  lastPulledVersionProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastPulledVersion');
    });
  }

  QueryBuilder<SyncCheckpoint, int, QQueryOperations> lastSyncedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastSyncedAt');
    });
  }

  QueryBuilder<SyncCheckpoint, String, QQueryOperations> userIdProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'userId');
    });
  }
}
