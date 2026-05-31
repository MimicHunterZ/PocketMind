// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'scrape_attempt.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetScrapeAttemptCollection on Isar {
  IsarCollection<ScrapeAttempt> get scrapeAttempts => this.collection();
}

const ScrapeAttemptSchema = CollectionSchema(
  name: r'ScrapeAttempt',
  id: 8128809898893227954,
  properties: {
    r'attemptNumber': PropertySchema(
      id: 0,
      name: r'attemptNumber',
      type: IsarType.long,
    ),
    r'claimedAt': PropertySchema(
      id: 1,
      name: r'claimedAt',
      type: IsarType.dateTime,
    ),
    r'claimedBy': PropertySchema(
      id: 2,
      name: r'claimedBy',
      type: IsarType.string,
    ),
    r'enqueuedAt': PropertySchema(
      id: 3,
      name: r'enqueuedAt',
      type: IsarType.dateTime,
    ),
    r'errorCode': PropertySchema(
      id: 4,
      name: r'errorCode',
      type: IsarType.string,
    ),
    r'errorMessage': PropertySchema(
      id: 5,
      name: r'errorMessage',
      type: IsarType.string,
    ),
    r'finishedAt': PropertySchema(
      id: 6,
      name: r'finishedAt',
      type: IsarType.dateTime,
    ),
    r'noteUuid': PropertySchema(
      id: 7,
      name: r'noteUuid',
      type: IsarType.string,
    ),
    r'state': PropertySchema(id: 8, name: r'state', type: IsarType.string),
  },

  estimateSize: _scrapeAttemptEstimateSize,
  serialize: _scrapeAttemptSerialize,
  deserialize: _scrapeAttemptDeserialize,
  deserializeProp: _scrapeAttemptDeserializeProp,
  idName: r'id',
  indexes: {
    r'noteUuid': IndexSchema(
      id: -572772332232466329,
      name: r'noteUuid',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'noteUuid',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
    r'state': IndexSchema(
      id: 7917036384617311412,
      name: r'state',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'state',
          type: IndexType.hash,
          caseSensitive: true,
        ),
      ],
    ),
  },
  links: {},
  embeddedSchemas: {},

  getId: _scrapeAttemptGetId,
  getLinks: _scrapeAttemptGetLinks,
  attach: _scrapeAttemptAttach,
  version: '3.3.2',
);

int _scrapeAttemptEstimateSize(
  ScrapeAttempt object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  {
    final value = object.claimedBy;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.errorCode;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  {
    final value = object.errorMessage;
    if (value != null) {
      bytesCount += 3 + value.length * 3;
    }
  }
  bytesCount += 3 + object.noteUuid.length * 3;
  bytesCount += 3 + object.state.length * 3;
  return bytesCount;
}

void _scrapeAttemptSerialize(
  ScrapeAttempt object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.attemptNumber);
  writer.writeDateTime(offsets[1], object.claimedAt);
  writer.writeString(offsets[2], object.claimedBy);
  writer.writeDateTime(offsets[3], object.enqueuedAt);
  writer.writeString(offsets[4], object.errorCode);
  writer.writeString(offsets[5], object.errorMessage);
  writer.writeDateTime(offsets[6], object.finishedAt);
  writer.writeString(offsets[7], object.noteUuid);
  writer.writeString(offsets[8], object.state);
}

ScrapeAttempt _scrapeAttemptDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = ScrapeAttempt();
  object.attemptNumber = reader.readLong(offsets[0]);
  object.claimedAt = reader.readDateTimeOrNull(offsets[1]);
  object.claimedBy = reader.readStringOrNull(offsets[2]);
  object.enqueuedAt = reader.readDateTime(offsets[3]);
  object.errorCode = reader.readStringOrNull(offsets[4]);
  object.errorMessage = reader.readStringOrNull(offsets[5]);
  object.finishedAt = reader.readDateTimeOrNull(offsets[6]);
  object.id = id;
  object.noteUuid = reader.readString(offsets[7]);
  object.state = reader.readString(offsets[8]);
  return object;
}

P _scrapeAttemptDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLong(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readStringOrNull(offset)) as P;
    case 3:
      return (reader.readDateTime(offset)) as P;
    case 4:
      return (reader.readStringOrNull(offset)) as P;
    case 5:
      return (reader.readStringOrNull(offset)) as P;
    case 6:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 7:
      return (reader.readString(offset)) as P;
    case 8:
      return (reader.readString(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _scrapeAttemptGetId(ScrapeAttempt object) {
  return object.id ?? Isar.autoIncrement;
}

List<IsarLinkBase<dynamic>> _scrapeAttemptGetLinks(ScrapeAttempt object) {
  return [];
}

void _scrapeAttemptAttach(
  IsarCollection<dynamic> col,
  Id id,
  ScrapeAttempt object,
) {
  object.id = id;
}

extension ScrapeAttemptQueryWhereSort
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QWhere> {
  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension ScrapeAttemptQueryWhere
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QWhereClause> {
  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> idEqualTo(
    Id id,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(lower: id, upper: id));
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> idNotEqualTo(
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

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> idGreaterThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> idLessThan(
    Id id, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> idBetween(
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

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> noteUuidEqualTo(
    String noteUuid,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'noteUuid', value: [noteUuid]),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause>
  noteUuidNotEqualTo(String noteUuid) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteUuid',
                lower: [],
                upper: [noteUuid],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteUuid',
                lower: [noteUuid],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteUuid',
                lower: [noteUuid],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'noteUuid',
                lower: [],
                upper: [noteUuid],
                includeUpper: false,
              ),
            );
      }
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> stateEqualTo(
    String state,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IndexWhereClause.equalTo(indexName: r'state', value: [state]),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterWhereClause> stateNotEqualTo(
    String state,
  ) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            );
      } else {
        return query
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [state],
                includeLower: false,
                upper: [],
              ),
            )
            .addWhereClause(
              IndexWhereClause.between(
                indexName: r'state',
                lower: [],
                upper: [state],
                includeUpper: false,
              ),
            );
      }
    });
  }
}

extension ScrapeAttemptQueryFilter
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QFilterCondition> {
  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  attemptNumberEqualTo(int value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'attemptNumber', value: value),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  attemptNumberGreaterThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'attemptNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  attemptNumberLessThan(int value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'attemptNumber',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  attemptNumberBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'attemptNumber',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'claimedAt'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'claimedAt'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'claimedAt', value: value),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'claimedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'claimedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'claimedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'claimedBy'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'claimedBy'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'claimedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'claimedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'claimedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'claimedBy',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'claimedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'claimedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'claimedBy',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'claimedBy',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'claimedBy', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  claimedByIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'claimedBy', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  enqueuedAtEqualTo(DateTime value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'enqueuedAt', value: value),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  enqueuedAtGreaterThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'enqueuedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  enqueuedAtLessThan(DateTime value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'enqueuedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  enqueuedAtBetween(
    DateTime lower,
    DateTime upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'enqueuedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'errorCode'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'errorCode'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'errorCode',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'errorCode',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'errorCode',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'errorCode', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorCodeIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'errorCode', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'errorMessage'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'errorMessage'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageEqualTo(String? value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'errorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageGreaterThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'errorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageLessThan(
    String? value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'errorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageBetween(
    String? lower,
    String? upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'errorMessage',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'errorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'errorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'errorMessage',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'errorMessage',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'errorMessage', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  errorMessageIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'errorMessage', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  finishedAtIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'finishedAt'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  finishedAtIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'finishedAt'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  finishedAtEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'finishedAt', value: value),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  finishedAtGreaterThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'finishedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  finishedAtLessThan(DateTime? value, {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'finishedAt',
          value: value,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  finishedAtBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'finishedAt',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition> idIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNull(property: r'id'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  idIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        const FilterCondition.isNotNull(property: r'id'),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition> idEqualTo(
    Id? value,
  ) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'id', value: value),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  idGreaterThan(Id? value, {bool include = false}) {
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

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition> idLessThan(
    Id? value, {
    bool include = false,
  }) {
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

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition> idBetween(
    Id? lower,
    Id? upper, {
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

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'noteUuid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'noteUuid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'noteUuid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'noteUuid',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'noteUuid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'noteUuid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'noteUuid',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'noteUuid',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'noteUuid', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  noteUuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'noteUuid', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateEqualTo(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(
          property: r'state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(
          include: include,
          property: r'state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.lessThan(
          include: include,
          property: r'state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.between(
          property: r'state',
          lower: lower,
          includeLower: includeLower,
          upper: upper,
          includeUpper: includeUpper,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateStartsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.startsWith(
          property: r'state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateEndsWith(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.endsWith(
          property: r'state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.contains(
          property: r'state',
          value: value,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.matches(
          property: r'state',
          wildcard: pattern,
          caseSensitive: caseSensitive,
        ),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.equalTo(property: r'state', value: ''),
      );
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterFilterCondition>
  stateIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(
        FilterCondition.greaterThan(property: r'state', value: ''),
      );
    });
  }
}

extension ScrapeAttemptQueryObject
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QFilterCondition> {}

extension ScrapeAttemptQueryLinks
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QFilterCondition> {}

extension ScrapeAttemptQuerySortBy
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QSortBy> {
  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByAttemptNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByAttemptNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByClaimedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedAt', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByClaimedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedAt', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByClaimedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedBy', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByClaimedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedBy', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByEnqueuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByEnqueuedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByFinishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByNoteUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteUuid', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  sortByNoteUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteUuid', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> sortByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }
}

extension ScrapeAttemptQuerySortThenBy
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QSortThenBy> {
  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByAttemptNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByAttemptNumberDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'attemptNumber', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByClaimedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedAt', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByClaimedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedAt', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByClaimedBy() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedBy', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByClaimedByDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'claimedBy', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByEnqueuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByEnqueuedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'enqueuedAt', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByErrorCode() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByErrorCodeDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorCode', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByErrorMessage() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByErrorMessageDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'errorMessage', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByFinishedAtDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'finishedAt', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByNoteUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteUuid', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy>
  thenByNoteUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'noteUuid', Sort.desc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByState() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.asc);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QAfterSortBy> thenByStateDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'state', Sort.desc);
    });
  }
}

extension ScrapeAttemptQueryWhereDistinct
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> {
  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct>
  distinctByAttemptNumber() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'attemptNumber');
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByClaimedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'claimedAt');
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByClaimedBy({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'claimedBy', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByEnqueuedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'enqueuedAt');
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByErrorCode({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorCode', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByErrorMessage({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'errorMessage', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByFinishedAt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'finishedAt');
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByNoteUuid({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'noteUuid', caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<ScrapeAttempt, ScrapeAttempt, QDistinct> distinctByState({
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'state', caseSensitive: caseSensitive);
    });
  }
}

extension ScrapeAttemptQueryProperty
    on QueryBuilder<ScrapeAttempt, ScrapeAttempt, QQueryProperty> {
  QueryBuilder<ScrapeAttempt, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<ScrapeAttempt, int, QQueryOperations> attemptNumberProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'attemptNumber');
    });
  }

  QueryBuilder<ScrapeAttempt, DateTime?, QQueryOperations> claimedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'claimedAt');
    });
  }

  QueryBuilder<ScrapeAttempt, String?, QQueryOperations> claimedByProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'claimedBy');
    });
  }

  QueryBuilder<ScrapeAttempt, DateTime, QQueryOperations> enqueuedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'enqueuedAt');
    });
  }

  QueryBuilder<ScrapeAttempt, String?, QQueryOperations> errorCodeProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorCode');
    });
  }

  QueryBuilder<ScrapeAttempt, String?, QQueryOperations>
  errorMessageProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'errorMessage');
    });
  }

  QueryBuilder<ScrapeAttempt, DateTime?, QQueryOperations>
  finishedAtProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'finishedAt');
    });
  }

  QueryBuilder<ScrapeAttempt, String, QQueryOperations> noteUuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'noteUuid');
    });
  }

  QueryBuilder<ScrapeAttempt, String, QQueryOperations> stateProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'state');
    });
  }
}
