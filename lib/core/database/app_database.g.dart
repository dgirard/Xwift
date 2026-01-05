// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $RidesTable extends Rides with TableInfo<$RidesTable, Ride> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RidesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant(''));
  static const VerificationMeta _startTimeMeta =
      const VerificationMeta('startTime');
  @override
  late final GeneratedColumn<DateTime> startTime = GeneratedColumn<DateTime>(
      'start_time', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _endTimeMeta =
      const VerificationMeta('endTime');
  @override
  late final GeneratedColumn<DateTime> endTime = GeneratedColumn<DateTime>(
      'end_time', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
      'mode', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _durationSecondsMeta =
      const VerificationMeta('durationSeconds');
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
      'duration_seconds', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalDistanceMeta =
      const VerificationMeta('totalDistance');
  @override
  late final GeneratedColumn<int> totalDistance = GeneratedColumn<int>(
      'total_distance', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalCaloriesMeta =
      const VerificationMeta('totalCalories');
  @override
  late final GeneratedColumn<int> totalCalories = GeneratedColumn<int>(
      'total_calories', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _averagePowerMeta =
      const VerificationMeta('averagePower');
  @override
  late final GeneratedColumn<int> averagePower = GeneratedColumn<int>(
      'average_power', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _maxPowerMeta =
      const VerificationMeta('maxPower');
  @override
  late final GeneratedColumn<int> maxPower = GeneratedColumn<int>(
      'max_power', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _averageCadenceMeta =
      const VerificationMeta('averageCadence');
  @override
  late final GeneratedColumn<int> averageCadence = GeneratedColumn<int>(
      'average_cadence', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _averageHeartRateMeta =
      const VerificationMeta('averageHeartRate');
  @override
  late final GeneratedColumn<int> averageHeartRate = GeneratedColumn<int>(
      'average_heart_rate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _averageSpeedMeta =
      const VerificationMeta('averageSpeed');
  @override
  late final GeneratedColumn<double> averageSpeed = GeneratedColumn<double>(
      'average_speed', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _workoutNameMeta =
      const VerificationMeta('workoutName');
  @override
  late final GeneratedColumn<String> workoutName = GeneratedColumn<String>(
      'workout_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _workoutIdMeta =
      const VerificationMeta('workoutId');
  @override
  late final GeneratedColumn<String> workoutId = GeneratedColumn<String>(
      'workout_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        startTime,
        endTime,
        mode,
        durationSeconds,
        totalDistance,
        totalCalories,
        averagePower,
        maxPower,
        averageCadence,
        averageHeartRate,
        averageSpeed,
        workoutName,
        workoutId
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rides';
  @override
  VerificationContext validateIntegrity(Insertable<Ride> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    }
    if (data.containsKey('start_time')) {
      context.handle(_startTimeMeta,
          startTime.isAcceptableOrUnknown(data['start_time']!, _startTimeMeta));
    } else if (isInserting) {
      context.missing(_startTimeMeta);
    }
    if (data.containsKey('end_time')) {
      context.handle(_endTimeMeta,
          endTime.isAcceptableOrUnknown(data['end_time']!, _endTimeMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
          _modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
          _durationSecondsMeta,
          durationSeconds.isAcceptableOrUnknown(
              data['duration_seconds']!, _durationSecondsMeta));
    }
    if (data.containsKey('total_distance')) {
      context.handle(
          _totalDistanceMeta,
          totalDistance.isAcceptableOrUnknown(
              data['total_distance']!, _totalDistanceMeta));
    }
    if (data.containsKey('total_calories')) {
      context.handle(
          _totalCaloriesMeta,
          totalCalories.isAcceptableOrUnknown(
              data['total_calories']!, _totalCaloriesMeta));
    }
    if (data.containsKey('average_power')) {
      context.handle(
          _averagePowerMeta,
          averagePower.isAcceptableOrUnknown(
              data['average_power']!, _averagePowerMeta));
    }
    if (data.containsKey('max_power')) {
      context.handle(_maxPowerMeta,
          maxPower.isAcceptableOrUnknown(data['max_power']!, _maxPowerMeta));
    }
    if (data.containsKey('average_cadence')) {
      context.handle(
          _averageCadenceMeta,
          averageCadence.isAcceptableOrUnknown(
              data['average_cadence']!, _averageCadenceMeta));
    }
    if (data.containsKey('average_heart_rate')) {
      context.handle(
          _averageHeartRateMeta,
          averageHeartRate.isAcceptableOrUnknown(
              data['average_heart_rate']!, _averageHeartRateMeta));
    }
    if (data.containsKey('average_speed')) {
      context.handle(
          _averageSpeedMeta,
          averageSpeed.isAcceptableOrUnknown(
              data['average_speed']!, _averageSpeedMeta));
    }
    if (data.containsKey('workout_name')) {
      context.handle(
          _workoutNameMeta,
          workoutName.isAcceptableOrUnknown(
              data['workout_name']!, _workoutNameMeta));
    }
    if (data.containsKey('workout_id')) {
      context.handle(_workoutIdMeta,
          workoutId.isAcceptableOrUnknown(data['workout_id']!, _workoutIdMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Ride map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Ride(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      startTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}start_time'])!,
      endTime: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}end_time']),
      mode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      durationSeconds: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_seconds'])!,
      totalDistance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_distance'])!,
      totalCalories: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_calories'])!,
      averagePower: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}average_power']),
      maxPower: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_power']),
      averageCadence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}average_cadence']),
      averageHeartRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}average_heart_rate']),
      averageSpeed: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}average_speed']),
      workoutName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workout_name']),
      workoutId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}workout_id']),
    );
  }

  @override
  $RidesTable createAlias(String alias) {
    return $RidesTable(attachedDatabase, alias);
  }
}

class Ride extends DataClass implements Insertable<Ride> {
  final String id;
  final String name;
  final DateTime startTime;
  final DateTime? endTime;
  final String mode;
  final int durationSeconds;
  final int totalDistance;
  final int totalCalories;
  final int? averagePower;
  final int? maxPower;
  final int? averageCadence;
  final int? averageHeartRate;
  final double? averageSpeed;
  final String? workoutName;
  final String? workoutId;
  const Ride(
      {required this.id,
      required this.name,
      required this.startTime,
      this.endTime,
      required this.mode,
      required this.durationSeconds,
      required this.totalDistance,
      required this.totalCalories,
      this.averagePower,
      this.maxPower,
      this.averageCadence,
      this.averageHeartRate,
      this.averageSpeed,
      this.workoutName,
      this.workoutId});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['start_time'] = Variable<DateTime>(startTime);
    if (!nullToAbsent || endTime != null) {
      map['end_time'] = Variable<DateTime>(endTime);
    }
    map['mode'] = Variable<String>(mode);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['total_distance'] = Variable<int>(totalDistance);
    map['total_calories'] = Variable<int>(totalCalories);
    if (!nullToAbsent || averagePower != null) {
      map['average_power'] = Variable<int>(averagePower);
    }
    if (!nullToAbsent || maxPower != null) {
      map['max_power'] = Variable<int>(maxPower);
    }
    if (!nullToAbsent || averageCadence != null) {
      map['average_cadence'] = Variable<int>(averageCadence);
    }
    if (!nullToAbsent || averageHeartRate != null) {
      map['average_heart_rate'] = Variable<int>(averageHeartRate);
    }
    if (!nullToAbsent || averageSpeed != null) {
      map['average_speed'] = Variable<double>(averageSpeed);
    }
    if (!nullToAbsent || workoutName != null) {
      map['workout_name'] = Variable<String>(workoutName);
    }
    if (!nullToAbsent || workoutId != null) {
      map['workout_id'] = Variable<String>(workoutId);
    }
    return map;
  }

  RidesCompanion toCompanion(bool nullToAbsent) {
    return RidesCompanion(
      id: Value(id),
      name: Value(name),
      startTime: Value(startTime),
      endTime: endTime == null && nullToAbsent
          ? const Value.absent()
          : Value(endTime),
      mode: Value(mode),
      durationSeconds: Value(durationSeconds),
      totalDistance: Value(totalDistance),
      totalCalories: Value(totalCalories),
      averagePower: averagePower == null && nullToAbsent
          ? const Value.absent()
          : Value(averagePower),
      maxPower: maxPower == null && nullToAbsent
          ? const Value.absent()
          : Value(maxPower),
      averageCadence: averageCadence == null && nullToAbsent
          ? const Value.absent()
          : Value(averageCadence),
      averageHeartRate: averageHeartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(averageHeartRate),
      averageSpeed: averageSpeed == null && nullToAbsent
          ? const Value.absent()
          : Value(averageSpeed),
      workoutName: workoutName == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutName),
      workoutId: workoutId == null && nullToAbsent
          ? const Value.absent()
          : Value(workoutId),
    );
  }

  factory Ride.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Ride(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      startTime: serializer.fromJson<DateTime>(json['startTime']),
      endTime: serializer.fromJson<DateTime?>(json['endTime']),
      mode: serializer.fromJson<String>(json['mode']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      totalDistance: serializer.fromJson<int>(json['totalDistance']),
      totalCalories: serializer.fromJson<int>(json['totalCalories']),
      averagePower: serializer.fromJson<int?>(json['averagePower']),
      maxPower: serializer.fromJson<int?>(json['maxPower']),
      averageCadence: serializer.fromJson<int?>(json['averageCadence']),
      averageHeartRate: serializer.fromJson<int?>(json['averageHeartRate']),
      averageSpeed: serializer.fromJson<double?>(json['averageSpeed']),
      workoutName: serializer.fromJson<String?>(json['workoutName']),
      workoutId: serializer.fromJson<String?>(json['workoutId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'startTime': serializer.toJson<DateTime>(startTime),
      'endTime': serializer.toJson<DateTime?>(endTime),
      'mode': serializer.toJson<String>(mode),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'totalDistance': serializer.toJson<int>(totalDistance),
      'totalCalories': serializer.toJson<int>(totalCalories),
      'averagePower': serializer.toJson<int?>(averagePower),
      'maxPower': serializer.toJson<int?>(maxPower),
      'averageCadence': serializer.toJson<int?>(averageCadence),
      'averageHeartRate': serializer.toJson<int?>(averageHeartRate),
      'averageSpeed': serializer.toJson<double?>(averageSpeed),
      'workoutName': serializer.toJson<String?>(workoutName),
      'workoutId': serializer.toJson<String?>(workoutId),
    };
  }

  Ride copyWith(
          {String? id,
          String? name,
          DateTime? startTime,
          Value<DateTime?> endTime = const Value.absent(),
          String? mode,
          int? durationSeconds,
          int? totalDistance,
          int? totalCalories,
          Value<int?> averagePower = const Value.absent(),
          Value<int?> maxPower = const Value.absent(),
          Value<int?> averageCadence = const Value.absent(),
          Value<int?> averageHeartRate = const Value.absent(),
          Value<double?> averageSpeed = const Value.absent(),
          Value<String?> workoutName = const Value.absent(),
          Value<String?> workoutId = const Value.absent()}) =>
      Ride(
        id: id ?? this.id,
        name: name ?? this.name,
        startTime: startTime ?? this.startTime,
        endTime: endTime.present ? endTime.value : this.endTime,
        mode: mode ?? this.mode,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        totalDistance: totalDistance ?? this.totalDistance,
        totalCalories: totalCalories ?? this.totalCalories,
        averagePower:
            averagePower.present ? averagePower.value : this.averagePower,
        maxPower: maxPower.present ? maxPower.value : this.maxPower,
        averageCadence:
            averageCadence.present ? averageCadence.value : this.averageCadence,
        averageHeartRate: averageHeartRate.present
            ? averageHeartRate.value
            : this.averageHeartRate,
        averageSpeed:
            averageSpeed.present ? averageSpeed.value : this.averageSpeed,
        workoutName: workoutName.present ? workoutName.value : this.workoutName,
        workoutId: workoutId.present ? workoutId.value : this.workoutId,
      );
  Ride copyWithCompanion(RidesCompanion data) {
    return Ride(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      startTime: data.startTime.present ? data.startTime.value : this.startTime,
      endTime: data.endTime.present ? data.endTime.value : this.endTime,
      mode: data.mode.present ? data.mode.value : this.mode,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      totalDistance: data.totalDistance.present
          ? data.totalDistance.value
          : this.totalDistance,
      totalCalories: data.totalCalories.present
          ? data.totalCalories.value
          : this.totalCalories,
      averagePower: data.averagePower.present
          ? data.averagePower.value
          : this.averagePower,
      maxPower: data.maxPower.present ? data.maxPower.value : this.maxPower,
      averageCadence: data.averageCadence.present
          ? data.averageCadence.value
          : this.averageCadence,
      averageHeartRate: data.averageHeartRate.present
          ? data.averageHeartRate.value
          : this.averageHeartRate,
      averageSpeed: data.averageSpeed.present
          ? data.averageSpeed.value
          : this.averageSpeed,
      workoutName:
          data.workoutName.present ? data.workoutName.value : this.workoutName,
      workoutId: data.workoutId.present ? data.workoutId.value : this.workoutId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Ride(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('mode: $mode, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalDistance: $totalDistance, ')
          ..write('totalCalories: $totalCalories, ')
          ..write('averagePower: $averagePower, ')
          ..write('maxPower: $maxPower, ')
          ..write('averageCadence: $averageCadence, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('averageSpeed: $averageSpeed, ')
          ..write('workoutName: $workoutName, ')
          ..write('workoutId: $workoutId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      startTime,
      endTime,
      mode,
      durationSeconds,
      totalDistance,
      totalCalories,
      averagePower,
      maxPower,
      averageCadence,
      averageHeartRate,
      averageSpeed,
      workoutName,
      workoutId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Ride &&
          other.id == this.id &&
          other.name == this.name &&
          other.startTime == this.startTime &&
          other.endTime == this.endTime &&
          other.mode == this.mode &&
          other.durationSeconds == this.durationSeconds &&
          other.totalDistance == this.totalDistance &&
          other.totalCalories == this.totalCalories &&
          other.averagePower == this.averagePower &&
          other.maxPower == this.maxPower &&
          other.averageCadence == this.averageCadence &&
          other.averageHeartRate == this.averageHeartRate &&
          other.averageSpeed == this.averageSpeed &&
          other.workoutName == this.workoutName &&
          other.workoutId == this.workoutId);
}

class RidesCompanion extends UpdateCompanion<Ride> {
  final Value<String> id;
  final Value<String> name;
  final Value<DateTime> startTime;
  final Value<DateTime?> endTime;
  final Value<String> mode;
  final Value<int> durationSeconds;
  final Value<int> totalDistance;
  final Value<int> totalCalories;
  final Value<int?> averagePower;
  final Value<int?> maxPower;
  final Value<int?> averageCadence;
  final Value<int?> averageHeartRate;
  final Value<double?> averageSpeed;
  final Value<String?> workoutName;
  final Value<String?> workoutId;
  final Value<int> rowid;
  const RidesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.startTime = const Value.absent(),
    this.endTime = const Value.absent(),
    this.mode = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.totalDistance = const Value.absent(),
    this.totalCalories = const Value.absent(),
    this.averagePower = const Value.absent(),
    this.maxPower = const Value.absent(),
    this.averageCadence = const Value.absent(),
    this.averageHeartRate = const Value.absent(),
    this.averageSpeed = const Value.absent(),
    this.workoutName = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RidesCompanion.insert({
    required String id,
    this.name = const Value.absent(),
    required DateTime startTime,
    this.endTime = const Value.absent(),
    required String mode,
    this.durationSeconds = const Value.absent(),
    this.totalDistance = const Value.absent(),
    this.totalCalories = const Value.absent(),
    this.averagePower = const Value.absent(),
    this.maxPower = const Value.absent(),
    this.averageCadence = const Value.absent(),
    this.averageHeartRate = const Value.absent(),
    this.averageSpeed = const Value.absent(),
    this.workoutName = const Value.absent(),
    this.workoutId = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        startTime = Value(startTime),
        mode = Value(mode);
  static Insertable<Ride> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<DateTime>? startTime,
    Expression<DateTime>? endTime,
    Expression<String>? mode,
    Expression<int>? durationSeconds,
    Expression<int>? totalDistance,
    Expression<int>? totalCalories,
    Expression<int>? averagePower,
    Expression<int>? maxPower,
    Expression<int>? averageCadence,
    Expression<int>? averageHeartRate,
    Expression<double>? averageSpeed,
    Expression<String>? workoutName,
    Expression<String>? workoutId,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (startTime != null) 'start_time': startTime,
      if (endTime != null) 'end_time': endTime,
      if (mode != null) 'mode': mode,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (totalDistance != null) 'total_distance': totalDistance,
      if (totalCalories != null) 'total_calories': totalCalories,
      if (averagePower != null) 'average_power': averagePower,
      if (maxPower != null) 'max_power': maxPower,
      if (averageCadence != null) 'average_cadence': averageCadence,
      if (averageHeartRate != null) 'average_heart_rate': averageHeartRate,
      if (averageSpeed != null) 'average_speed': averageSpeed,
      if (workoutName != null) 'workout_name': workoutName,
      if (workoutId != null) 'workout_id': workoutId,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RidesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<DateTime>? startTime,
      Value<DateTime?>? endTime,
      Value<String>? mode,
      Value<int>? durationSeconds,
      Value<int>? totalDistance,
      Value<int>? totalCalories,
      Value<int?>? averagePower,
      Value<int?>? maxPower,
      Value<int?>? averageCadence,
      Value<int?>? averageHeartRate,
      Value<double?>? averageSpeed,
      Value<String?>? workoutName,
      Value<String?>? workoutId,
      Value<int>? rowid}) {
    return RidesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      mode: mode ?? this.mode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      totalDistance: totalDistance ?? this.totalDistance,
      totalCalories: totalCalories ?? this.totalCalories,
      averagePower: averagePower ?? this.averagePower,
      maxPower: maxPower ?? this.maxPower,
      averageCadence: averageCadence ?? this.averageCadence,
      averageHeartRate: averageHeartRate ?? this.averageHeartRate,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      workoutName: workoutName ?? this.workoutName,
      workoutId: workoutId ?? this.workoutId,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (startTime.present) {
      map['start_time'] = Variable<DateTime>(startTime.value);
    }
    if (endTime.present) {
      map['end_time'] = Variable<DateTime>(endTime.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (totalDistance.present) {
      map['total_distance'] = Variable<int>(totalDistance.value);
    }
    if (totalCalories.present) {
      map['total_calories'] = Variable<int>(totalCalories.value);
    }
    if (averagePower.present) {
      map['average_power'] = Variable<int>(averagePower.value);
    }
    if (maxPower.present) {
      map['max_power'] = Variable<int>(maxPower.value);
    }
    if (averageCadence.present) {
      map['average_cadence'] = Variable<int>(averageCadence.value);
    }
    if (averageHeartRate.present) {
      map['average_heart_rate'] = Variable<int>(averageHeartRate.value);
    }
    if (averageSpeed.present) {
      map['average_speed'] = Variable<double>(averageSpeed.value);
    }
    if (workoutName.present) {
      map['workout_name'] = Variable<String>(workoutName.value);
    }
    if (workoutId.present) {
      map['workout_id'] = Variable<String>(workoutId.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RidesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('startTime: $startTime, ')
          ..write('endTime: $endTime, ')
          ..write('mode: $mode, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('totalDistance: $totalDistance, ')
          ..write('totalCalories: $totalCalories, ')
          ..write('averagePower: $averagePower, ')
          ..write('maxPower: $maxPower, ')
          ..write('averageCadence: $averageCadence, ')
          ..write('averageHeartRate: $averageHeartRate, ')
          ..write('averageSpeed: $averageSpeed, ')
          ..write('workoutName: $workoutName, ')
          ..write('workoutId: $workoutId, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RideSamplesTable extends RideSamples
    with TableInfo<$RideSamplesTable, RideSample> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RideSamplesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _rideIdMeta = const VerificationMeta('rideId');
  @override
  late final GeneratedColumn<String> rideId = GeneratedColumn<String>(
      'ride_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES rides (id)'));
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _powerMeta = const VerificationMeta('power');
  @override
  late final GeneratedColumn<int> power = GeneratedColumn<int>(
      'power', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _cadenceMeta =
      const VerificationMeta('cadence');
  @override
  late final GeneratedColumn<int> cadence = GeneratedColumn<int>(
      'cadence', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _speedMeta = const VerificationMeta('speed');
  @override
  late final GeneratedColumn<double> speed = GeneratedColumn<double>(
      'speed', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _heartRateMeta =
      const VerificationMeta('heartRate');
  @override
  late final GeneratedColumn<int> heartRate = GeneratedColumn<int>(
      'heart_rate', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _distanceMeta =
      const VerificationMeta('distance');
  @override
  late final GeneratedColumn<int> distance = GeneratedColumn<int>(
      'distance', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _caloriesMeta =
      const VerificationMeta('calories');
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
      'calories', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        rideId,
        timestamp,
        power,
        cadence,
        speed,
        heartRate,
        distance,
        calories
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'ride_samples';
  @override
  VerificationContext validateIntegrity(Insertable<RideSample> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('ride_id')) {
      context.handle(_rideIdMeta,
          rideId.isAcceptableOrUnknown(data['ride_id']!, _rideIdMeta));
    } else if (isInserting) {
      context.missing(_rideIdMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    } else if (isInserting) {
      context.missing(_timestampMeta);
    }
    if (data.containsKey('power')) {
      context.handle(
          _powerMeta, power.isAcceptableOrUnknown(data['power']!, _powerMeta));
    }
    if (data.containsKey('cadence')) {
      context.handle(_cadenceMeta,
          cadence.isAcceptableOrUnknown(data['cadence']!, _cadenceMeta));
    }
    if (data.containsKey('speed')) {
      context.handle(
          _speedMeta, speed.isAcceptableOrUnknown(data['speed']!, _speedMeta));
    }
    if (data.containsKey('heart_rate')) {
      context.handle(_heartRateMeta,
          heartRate.isAcceptableOrUnknown(data['heart_rate']!, _heartRateMeta));
    }
    if (data.containsKey('distance')) {
      context.handle(_distanceMeta,
          distance.isAcceptableOrUnknown(data['distance']!, _distanceMeta));
    }
    if (data.containsKey('calories')) {
      context.handle(_caloriesMeta,
          calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RideSample map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RideSample(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      rideId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}ride_id'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
      power: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}power']),
      cadence: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}cadence']),
      speed: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}speed']),
      heartRate: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}heart_rate']),
      distance: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}distance']),
      calories: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}calories']),
    );
  }

  @override
  $RideSamplesTable createAlias(String alias) {
    return $RideSamplesTable(attachedDatabase, alias);
  }
}

class RideSample extends DataClass implements Insertable<RideSample> {
  final int id;
  final String rideId;
  final DateTime timestamp;
  final int? power;
  final int? cadence;
  final double? speed;
  final int? heartRate;
  final int? distance;
  final int? calories;
  const RideSample(
      {required this.id,
      required this.rideId,
      required this.timestamp,
      this.power,
      this.cadence,
      this.speed,
      this.heartRate,
      this.distance,
      this.calories});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['ride_id'] = Variable<String>(rideId);
    map['timestamp'] = Variable<DateTime>(timestamp);
    if (!nullToAbsent || power != null) {
      map['power'] = Variable<int>(power);
    }
    if (!nullToAbsent || cadence != null) {
      map['cadence'] = Variable<int>(cadence);
    }
    if (!nullToAbsent || speed != null) {
      map['speed'] = Variable<double>(speed);
    }
    if (!nullToAbsent || heartRate != null) {
      map['heart_rate'] = Variable<int>(heartRate);
    }
    if (!nullToAbsent || distance != null) {
      map['distance'] = Variable<int>(distance);
    }
    if (!nullToAbsent || calories != null) {
      map['calories'] = Variable<int>(calories);
    }
    return map;
  }

  RideSamplesCompanion toCompanion(bool nullToAbsent) {
    return RideSamplesCompanion(
      id: Value(id),
      rideId: Value(rideId),
      timestamp: Value(timestamp),
      power:
          power == null && nullToAbsent ? const Value.absent() : Value(power),
      cadence: cadence == null && nullToAbsent
          ? const Value.absent()
          : Value(cadence),
      speed:
          speed == null && nullToAbsent ? const Value.absent() : Value(speed),
      heartRate: heartRate == null && nullToAbsent
          ? const Value.absent()
          : Value(heartRate),
      distance: distance == null && nullToAbsent
          ? const Value.absent()
          : Value(distance),
      calories: calories == null && nullToAbsent
          ? const Value.absent()
          : Value(calories),
    );
  }

  factory RideSample.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RideSample(
      id: serializer.fromJson<int>(json['id']),
      rideId: serializer.fromJson<String>(json['rideId']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
      power: serializer.fromJson<int?>(json['power']),
      cadence: serializer.fromJson<int?>(json['cadence']),
      speed: serializer.fromJson<double?>(json['speed']),
      heartRate: serializer.fromJson<int?>(json['heartRate']),
      distance: serializer.fromJson<int?>(json['distance']),
      calories: serializer.fromJson<int?>(json['calories']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'rideId': serializer.toJson<String>(rideId),
      'timestamp': serializer.toJson<DateTime>(timestamp),
      'power': serializer.toJson<int?>(power),
      'cadence': serializer.toJson<int?>(cadence),
      'speed': serializer.toJson<double?>(speed),
      'heartRate': serializer.toJson<int?>(heartRate),
      'distance': serializer.toJson<int?>(distance),
      'calories': serializer.toJson<int?>(calories),
    };
  }

  RideSample copyWith(
          {int? id,
          String? rideId,
          DateTime? timestamp,
          Value<int?> power = const Value.absent(),
          Value<int?> cadence = const Value.absent(),
          Value<double?> speed = const Value.absent(),
          Value<int?> heartRate = const Value.absent(),
          Value<int?> distance = const Value.absent(),
          Value<int?> calories = const Value.absent()}) =>
      RideSample(
        id: id ?? this.id,
        rideId: rideId ?? this.rideId,
        timestamp: timestamp ?? this.timestamp,
        power: power.present ? power.value : this.power,
        cadence: cadence.present ? cadence.value : this.cadence,
        speed: speed.present ? speed.value : this.speed,
        heartRate: heartRate.present ? heartRate.value : this.heartRate,
        distance: distance.present ? distance.value : this.distance,
        calories: calories.present ? calories.value : this.calories,
      );
  RideSample copyWithCompanion(RideSamplesCompanion data) {
    return RideSample(
      id: data.id.present ? data.id.value : this.id,
      rideId: data.rideId.present ? data.rideId.value : this.rideId,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
      power: data.power.present ? data.power.value : this.power,
      cadence: data.cadence.present ? data.cadence.value : this.cadence,
      speed: data.speed.present ? data.speed.value : this.speed,
      heartRate: data.heartRate.present ? data.heartRate.value : this.heartRate,
      distance: data.distance.present ? data.distance.value : this.distance,
      calories: data.calories.present ? data.calories.value : this.calories,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RideSample(')
          ..write('id: $id, ')
          ..write('rideId: $rideId, ')
          ..write('timestamp: $timestamp, ')
          ..write('power: $power, ')
          ..write('cadence: $cadence, ')
          ..write('speed: $speed, ')
          ..write('heartRate: $heartRate, ')
          ..write('distance: $distance, ')
          ..write('calories: $calories')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, rideId, timestamp, power, cadence, speed,
      heartRate, distance, calories);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RideSample &&
          other.id == this.id &&
          other.rideId == this.rideId &&
          other.timestamp == this.timestamp &&
          other.power == this.power &&
          other.cadence == this.cadence &&
          other.speed == this.speed &&
          other.heartRate == this.heartRate &&
          other.distance == this.distance &&
          other.calories == this.calories);
}

class RideSamplesCompanion extends UpdateCompanion<RideSample> {
  final Value<int> id;
  final Value<String> rideId;
  final Value<DateTime> timestamp;
  final Value<int?> power;
  final Value<int?> cadence;
  final Value<double?> speed;
  final Value<int?> heartRate;
  final Value<int?> distance;
  final Value<int?> calories;
  const RideSamplesCompanion({
    this.id = const Value.absent(),
    this.rideId = const Value.absent(),
    this.timestamp = const Value.absent(),
    this.power = const Value.absent(),
    this.cadence = const Value.absent(),
    this.speed = const Value.absent(),
    this.heartRate = const Value.absent(),
    this.distance = const Value.absent(),
    this.calories = const Value.absent(),
  });
  RideSamplesCompanion.insert({
    this.id = const Value.absent(),
    required String rideId,
    required DateTime timestamp,
    this.power = const Value.absent(),
    this.cadence = const Value.absent(),
    this.speed = const Value.absent(),
    this.heartRate = const Value.absent(),
    this.distance = const Value.absent(),
    this.calories = const Value.absent(),
  })  : rideId = Value(rideId),
        timestamp = Value(timestamp);
  static Insertable<RideSample> custom({
    Expression<int>? id,
    Expression<String>? rideId,
    Expression<DateTime>? timestamp,
    Expression<int>? power,
    Expression<int>? cadence,
    Expression<double>? speed,
    Expression<int>? heartRate,
    Expression<int>? distance,
    Expression<int>? calories,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (rideId != null) 'ride_id': rideId,
      if (timestamp != null) 'timestamp': timestamp,
      if (power != null) 'power': power,
      if (cadence != null) 'cadence': cadence,
      if (speed != null) 'speed': speed,
      if (heartRate != null) 'heart_rate': heartRate,
      if (distance != null) 'distance': distance,
      if (calories != null) 'calories': calories,
    });
  }

  RideSamplesCompanion copyWith(
      {Value<int>? id,
      Value<String>? rideId,
      Value<DateTime>? timestamp,
      Value<int?>? power,
      Value<int?>? cadence,
      Value<double?>? speed,
      Value<int?>? heartRate,
      Value<int?>? distance,
      Value<int?>? calories}) {
    return RideSamplesCompanion(
      id: id ?? this.id,
      rideId: rideId ?? this.rideId,
      timestamp: timestamp ?? this.timestamp,
      power: power ?? this.power,
      cadence: cadence ?? this.cadence,
      speed: speed ?? this.speed,
      heartRate: heartRate ?? this.heartRate,
      distance: distance ?? this.distance,
      calories: calories ?? this.calories,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (rideId.present) {
      map['ride_id'] = Variable<String>(rideId.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    if (power.present) {
      map['power'] = Variable<int>(power.value);
    }
    if (cadence.present) {
      map['cadence'] = Variable<int>(cadence.value);
    }
    if (speed.present) {
      map['speed'] = Variable<double>(speed.value);
    }
    if (heartRate.present) {
      map['heart_rate'] = Variable<int>(heartRate.value);
    }
    if (distance.present) {
      map['distance'] = Variable<int>(distance.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RideSamplesCompanion(')
          ..write('id: $id, ')
          ..write('rideId: $rideId, ')
          ..write('timestamp: $timestamp, ')
          ..write('power: $power, ')
          ..write('cadence: $cadence, ')
          ..write('speed: $speed, ')
          ..write('heartRate: $heartRate, ')
          ..write('distance: $distance, ')
          ..write('calories: $calories')
          ..write(')'))
        .toString();
  }
}

class $WorkoutsTable extends Workouts with TableInfo<$WorkoutsTable, Workout> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WorkoutsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _descriptionMeta =
      const VerificationMeta('description');
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
      'description', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
      'author', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _ftpMeta = const VerificationMeta('ftp');
  @override
  late final GeneratedColumn<int> ftp = GeneratedColumn<int>(
      'ftp', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _intervalsJsonMeta =
      const VerificationMeta('intervalsJson');
  @override
  late final GeneratedColumn<String> intervalsJson = GeneratedColumn<String>(
      'intervals_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastUsedAtMeta =
      const VerificationMeta('lastUsedAt');
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
      'last_used_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _useCountMeta =
      const VerificationMeta('useCount');
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
      'use_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        description,
        author,
        ftp,
        intervalsJson,
        createdAt,
        lastUsedAt,
        useCount
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'workouts';
  @override
  VerificationContext validateIntegrity(Insertable<Workout> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
          _descriptionMeta,
          description.isAcceptableOrUnknown(
              data['description']!, _descriptionMeta));
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta,
          author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('ftp')) {
      context.handle(
          _ftpMeta, ftp.isAcceptableOrUnknown(data['ftp']!, _ftpMeta));
    }
    if (data.containsKey('intervals_json')) {
      context.handle(
          _intervalsJsonMeta,
          intervalsJson.isAcceptableOrUnknown(
              data['intervals_json']!, _intervalsJsonMeta));
    } else if (isInserting) {
      context.missing(_intervalsJsonMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
          _lastUsedAtMeta,
          lastUsedAt.isAcceptableOrUnknown(
              data['last_used_at']!, _lastUsedAtMeta));
    }
    if (data.containsKey('use_count')) {
      context.handle(_useCountMeta,
          useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Workout map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Workout(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      description: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}description']),
      author: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}author']),
      ftp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}ftp']),
      intervalsJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}intervals_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastUsedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}last_used_at']),
      useCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}use_count'])!,
    );
  }

  @override
  $WorkoutsTable createAlias(String alias) {
    return $WorkoutsTable(attachedDatabase, alias);
  }
}

class Workout extends DataClass implements Insertable<Workout> {
  final String id;
  final String name;
  final String? description;
  final String? author;
  final int? ftp;
  final String intervalsJson;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final int useCount;
  const Workout(
      {required this.id,
      required this.name,
      this.description,
      this.author,
      this.ftp,
      required this.intervalsJson,
      required this.createdAt,
      this.lastUsedAt,
      required this.useCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || ftp != null) {
      map['ftp'] = Variable<int>(ftp);
    }
    map['intervals_json'] = Variable<String>(intervalsJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastUsedAt != null) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    }
    map['use_count'] = Variable<int>(useCount);
    return map;
  }

  WorkoutsCompanion toCompanion(bool nullToAbsent) {
    return WorkoutsCompanion(
      id: Value(id),
      name: Value(name),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      author:
          author == null && nullToAbsent ? const Value.absent() : Value(author),
      ftp: ftp == null && nullToAbsent ? const Value.absent() : Value(ftp),
      intervalsJson: Value(intervalsJson),
      createdAt: Value(createdAt),
      lastUsedAt: lastUsedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastUsedAt),
      useCount: Value(useCount),
    );
  }

  factory Workout.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Workout(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      description: serializer.fromJson<String?>(json['description']),
      author: serializer.fromJson<String?>(json['author']),
      ftp: serializer.fromJson<int?>(json['ftp']),
      intervalsJson: serializer.fromJson<String>(json['intervalsJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastUsedAt: serializer.fromJson<DateTime?>(json['lastUsedAt']),
      useCount: serializer.fromJson<int>(json['useCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'description': serializer.toJson<String?>(description),
      'author': serializer.toJson<String?>(author),
      'ftp': serializer.toJson<int?>(ftp),
      'intervalsJson': serializer.toJson<String>(intervalsJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastUsedAt': serializer.toJson<DateTime?>(lastUsedAt),
      'useCount': serializer.toJson<int>(useCount),
    };
  }

  Workout copyWith(
          {String? id,
          String? name,
          Value<String?> description = const Value.absent(),
          Value<String?> author = const Value.absent(),
          Value<int?> ftp = const Value.absent(),
          String? intervalsJson,
          DateTime? createdAt,
          Value<DateTime?> lastUsedAt = const Value.absent(),
          int? useCount}) =>
      Workout(
        id: id ?? this.id,
        name: name ?? this.name,
        description: description.present ? description.value : this.description,
        author: author.present ? author.value : this.author,
        ftp: ftp.present ? ftp.value : this.ftp,
        intervalsJson: intervalsJson ?? this.intervalsJson,
        createdAt: createdAt ?? this.createdAt,
        lastUsedAt: lastUsedAt.present ? lastUsedAt.value : this.lastUsedAt,
        useCount: useCount ?? this.useCount,
      );
  Workout copyWithCompanion(WorkoutsCompanion data) {
    return Workout(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      description:
          data.description.present ? data.description.value : this.description,
      author: data.author.present ? data.author.value : this.author,
      ftp: data.ftp.present ? data.ftp.value : this.ftp,
      intervalsJson: data.intervalsJson.present
          ? data.intervalsJson.value
          : this.intervalsJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastUsedAt:
          data.lastUsedAt.present ? data.lastUsedAt.value : this.lastUsedAt,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Workout(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('ftp: $ftp, ')
          ..write('intervalsJson: $intervalsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('useCount: $useCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, description, author, ftp,
      intervalsJson, createdAt, lastUsedAt, useCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Workout &&
          other.id == this.id &&
          other.name == this.name &&
          other.description == this.description &&
          other.author == this.author &&
          other.ftp == this.ftp &&
          other.intervalsJson == this.intervalsJson &&
          other.createdAt == this.createdAt &&
          other.lastUsedAt == this.lastUsedAt &&
          other.useCount == this.useCount);
}

class WorkoutsCompanion extends UpdateCompanion<Workout> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> description;
  final Value<String?> author;
  final Value<int?> ftp;
  final Value<String> intervalsJson;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastUsedAt;
  final Value<int> useCount;
  final Value<int> rowid;
  const WorkoutsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.ftp = const Value.absent(),
    this.intervalsJson = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.useCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  WorkoutsCompanion.insert({
    required String id,
    required String name,
    this.description = const Value.absent(),
    this.author = const Value.absent(),
    this.ftp = const Value.absent(),
    required String intervalsJson,
    required DateTime createdAt,
    this.lastUsedAt = const Value.absent(),
    this.useCount = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name),
        intervalsJson = Value(intervalsJson),
        createdAt = Value(createdAt);
  static Insertable<Workout> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? description,
    Expression<String>? author,
    Expression<int>? ftp,
    Expression<String>? intervalsJson,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? useCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (description != null) 'description': description,
      if (author != null) 'author': author,
      if (ftp != null) 'ftp': ftp,
      if (intervalsJson != null) 'intervals_json': intervalsJson,
      if (createdAt != null) 'created_at': createdAt,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (useCount != null) 'use_count': useCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  WorkoutsCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? description,
      Value<String?>? author,
      Value<int?>? ftp,
      Value<String>? intervalsJson,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastUsedAt,
      Value<int>? useCount,
      Value<int>? rowid}) {
    return WorkoutsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      author: author ?? this.author,
      ftp: ftp ?? this.ftp,
      intervalsJson: intervalsJson ?? this.intervalsJson,
      createdAt: createdAt ?? this.createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (ftp.present) {
      map['ftp'] = Variable<int>(ftp.value);
    }
    if (intervalsJson.present) {
      map['intervals_json'] = Variable<String>(intervalsJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WorkoutsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('description: $description, ')
          ..write('author: $author, ')
          ..write('ftp: $ftp, ')
          ..write('intervalsJson: $intervalsJson, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('useCount: $useCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $RidesTable rides = $RidesTable(this);
  late final $RideSamplesTable rideSamples = $RideSamplesTable(this);
  late final $WorkoutsTable workouts = $WorkoutsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [rides, rideSamples, workouts];
}

typedef $$RidesTableCreateCompanionBuilder = RidesCompanion Function({
  required String id,
  Value<String> name,
  required DateTime startTime,
  Value<DateTime?> endTime,
  required String mode,
  Value<int> durationSeconds,
  Value<int> totalDistance,
  Value<int> totalCalories,
  Value<int?> averagePower,
  Value<int?> maxPower,
  Value<int?> averageCadence,
  Value<int?> averageHeartRate,
  Value<double?> averageSpeed,
  Value<String?> workoutName,
  Value<String?> workoutId,
  Value<int> rowid,
});
typedef $$RidesTableUpdateCompanionBuilder = RidesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<DateTime> startTime,
  Value<DateTime?> endTime,
  Value<String> mode,
  Value<int> durationSeconds,
  Value<int> totalDistance,
  Value<int> totalCalories,
  Value<int?> averagePower,
  Value<int?> maxPower,
  Value<int?> averageCadence,
  Value<int?> averageHeartRate,
  Value<double?> averageSpeed,
  Value<String?> workoutName,
  Value<String?> workoutId,
  Value<int> rowid,
});

final class $$RidesTableReferences
    extends BaseReferences<_$AppDatabase, $RidesTable, Ride> {
  $$RidesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$RideSamplesTable, List<RideSample>>
      _rideSamplesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.rideSamples,
          aliasName: $_aliasNameGenerator(db.rides.id, db.rideSamples.rideId));

  $$RideSamplesTableProcessedTableManager get rideSamplesRefs {
    final manager = $$RideSamplesTableTableManager($_db, $_db.rideSamples)
        .filter((f) => f.rideId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_rideSamplesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$RidesTableFilterComposer extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalDistance => $composableBuilder(
      column: $table.totalDistance, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalCalories => $composableBuilder(
      column: $table.totalCalories, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get averagePower => $composableBuilder(
      column: $table.averagePower, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxPower => $composableBuilder(
      column: $table.maxPower, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get averageCadence => $composableBuilder(
      column: $table.averageCadence,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get averageHeartRate => $composableBuilder(
      column: $table.averageHeartRate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get averageSpeed => $composableBuilder(
      column: $table.averageSpeed, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workoutName => $composableBuilder(
      column: $table.workoutName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get workoutId => $composableBuilder(
      column: $table.workoutId, builder: (column) => ColumnFilters(column));

  Expression<bool> rideSamplesRefs(
      Expression<bool> Function($$RideSamplesTableFilterComposer f) f) {
    final $$RideSamplesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rideSamples,
        getReferencedColumn: (t) => t.rideId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RideSamplesTableFilterComposer(
              $db: $db,
              $table: $db.rideSamples,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RidesTableOrderingComposer
    extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startTime => $composableBuilder(
      column: $table.startTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endTime => $composableBuilder(
      column: $table.endTime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode => $composableBuilder(
      column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalDistance => $composableBuilder(
      column: $table.totalDistance,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalCalories => $composableBuilder(
      column: $table.totalCalories,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get averagePower => $composableBuilder(
      column: $table.averagePower,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxPower => $composableBuilder(
      column: $table.maxPower, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get averageCadence => $composableBuilder(
      column: $table.averageCadence,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get averageHeartRate => $composableBuilder(
      column: $table.averageHeartRate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get averageSpeed => $composableBuilder(
      column: $table.averageSpeed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workoutName => $composableBuilder(
      column: $table.workoutName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get workoutId => $composableBuilder(
      column: $table.workoutId, builder: (column) => ColumnOrderings(column));
}

class $$RidesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RidesTable> {
  $$RidesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get startTime =>
      $composableBuilder(column: $table.startTime, builder: (column) => column);

  GeneratedColumn<DateTime> get endTime =>
      $composableBuilder(column: $table.endTime, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
      column: $table.durationSeconds, builder: (column) => column);

  GeneratedColumn<int> get totalDistance => $composableBuilder(
      column: $table.totalDistance, builder: (column) => column);

  GeneratedColumn<int> get totalCalories => $composableBuilder(
      column: $table.totalCalories, builder: (column) => column);

  GeneratedColumn<int> get averagePower => $composableBuilder(
      column: $table.averagePower, builder: (column) => column);

  GeneratedColumn<int> get maxPower =>
      $composableBuilder(column: $table.maxPower, builder: (column) => column);

  GeneratedColumn<int> get averageCadence => $composableBuilder(
      column: $table.averageCadence, builder: (column) => column);

  GeneratedColumn<int> get averageHeartRate => $composableBuilder(
      column: $table.averageHeartRate, builder: (column) => column);

  GeneratedColumn<double> get averageSpeed => $composableBuilder(
      column: $table.averageSpeed, builder: (column) => column);

  GeneratedColumn<String> get workoutName => $composableBuilder(
      column: $table.workoutName, builder: (column) => column);

  GeneratedColumn<String> get workoutId =>
      $composableBuilder(column: $table.workoutId, builder: (column) => column);

  Expression<T> rideSamplesRefs<T extends Object>(
      Expression<T> Function($$RideSamplesTableAnnotationComposer a) f) {
    final $$RideSamplesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.rideSamples,
        getReferencedColumn: (t) => t.rideId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RideSamplesTableAnnotationComposer(
              $db: $db,
              $table: $db.rideSamples,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$RidesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RidesTable,
    Ride,
    $$RidesTableFilterComposer,
    $$RidesTableOrderingComposer,
    $$RidesTableAnnotationComposer,
    $$RidesTableCreateCompanionBuilder,
    $$RidesTableUpdateCompanionBuilder,
    (Ride, $$RidesTableReferences),
    Ride,
    PrefetchHooks Function({bool rideSamplesRefs})> {
  $$RidesTableTableManager(_$AppDatabase db, $RidesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RidesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RidesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RidesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> startTime = const Value.absent(),
            Value<DateTime?> endTime = const Value.absent(),
            Value<String> mode = const Value.absent(),
            Value<int> durationSeconds = const Value.absent(),
            Value<int> totalDistance = const Value.absent(),
            Value<int> totalCalories = const Value.absent(),
            Value<int?> averagePower = const Value.absent(),
            Value<int?> maxPower = const Value.absent(),
            Value<int?> averageCadence = const Value.absent(),
            Value<int?> averageHeartRate = const Value.absent(),
            Value<double?> averageSpeed = const Value.absent(),
            Value<String?> workoutName = const Value.absent(),
            Value<String?> workoutId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RidesCompanion(
            id: id,
            name: name,
            startTime: startTime,
            endTime: endTime,
            mode: mode,
            durationSeconds: durationSeconds,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            averagePower: averagePower,
            maxPower: maxPower,
            averageCadence: averageCadence,
            averageHeartRate: averageHeartRate,
            averageSpeed: averageSpeed,
            workoutName: workoutName,
            workoutId: workoutId,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            Value<String> name = const Value.absent(),
            required DateTime startTime,
            Value<DateTime?> endTime = const Value.absent(),
            required String mode,
            Value<int> durationSeconds = const Value.absent(),
            Value<int> totalDistance = const Value.absent(),
            Value<int> totalCalories = const Value.absent(),
            Value<int?> averagePower = const Value.absent(),
            Value<int?> maxPower = const Value.absent(),
            Value<int?> averageCadence = const Value.absent(),
            Value<int?> averageHeartRate = const Value.absent(),
            Value<double?> averageSpeed = const Value.absent(),
            Value<String?> workoutName = const Value.absent(),
            Value<String?> workoutId = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RidesCompanion.insert(
            id: id,
            name: name,
            startTime: startTime,
            endTime: endTime,
            mode: mode,
            durationSeconds: durationSeconds,
            totalDistance: totalDistance,
            totalCalories: totalCalories,
            averagePower: averagePower,
            maxPower: maxPower,
            averageCadence: averageCadence,
            averageHeartRate: averageHeartRate,
            averageSpeed: averageSpeed,
            workoutName: workoutName,
            workoutId: workoutId,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$RidesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({rideSamplesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (rideSamplesRefs) db.rideSamples],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (rideSamplesRefs)
                    await $_getPrefetchedData<Ride, $RidesTable, RideSample>(
                        currentTable: table,
                        referencedTable:
                            $$RidesTableReferences._rideSamplesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$RidesTableReferences(db, table, p0)
                                .rideSamplesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.rideId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$RidesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RidesTable,
    Ride,
    $$RidesTableFilterComposer,
    $$RidesTableOrderingComposer,
    $$RidesTableAnnotationComposer,
    $$RidesTableCreateCompanionBuilder,
    $$RidesTableUpdateCompanionBuilder,
    (Ride, $$RidesTableReferences),
    Ride,
    PrefetchHooks Function({bool rideSamplesRefs})>;
typedef $$RideSamplesTableCreateCompanionBuilder = RideSamplesCompanion
    Function({
  Value<int> id,
  required String rideId,
  required DateTime timestamp,
  Value<int?> power,
  Value<int?> cadence,
  Value<double?> speed,
  Value<int?> heartRate,
  Value<int?> distance,
  Value<int?> calories,
});
typedef $$RideSamplesTableUpdateCompanionBuilder = RideSamplesCompanion
    Function({
  Value<int> id,
  Value<String> rideId,
  Value<DateTime> timestamp,
  Value<int?> power,
  Value<int?> cadence,
  Value<double?> speed,
  Value<int?> heartRate,
  Value<int?> distance,
  Value<int?> calories,
});

final class $$RideSamplesTableReferences
    extends BaseReferences<_$AppDatabase, $RideSamplesTable, RideSample> {
  $$RideSamplesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $RidesTable _rideIdTable(_$AppDatabase db) => db.rides
      .createAlias($_aliasNameGenerator(db.rideSamples.rideId, db.rides.id));

  $$RidesTableProcessedTableManager get rideId {
    final $_column = $_itemColumn<String>('ride_id')!;

    final manager = $$RidesTableTableManager($_db, $_db.rides)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_rideIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$RideSamplesTableFilterComposer
    extends Composer<_$AppDatabase, $RideSamplesTable> {
  $$RideSamplesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get power => $composableBuilder(
      column: $table.power, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get cadence => $composableBuilder(
      column: $table.cadence, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get heartRate => $composableBuilder(
      column: $table.heartRate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get distance => $composableBuilder(
      column: $table.distance, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get calories => $composableBuilder(
      column: $table.calories, builder: (column) => ColumnFilters(column));

  $$RidesTableFilterComposer get rideId {
    final $$RidesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.rideId,
        referencedTable: $db.rides,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RidesTableFilterComposer(
              $db: $db,
              $table: $db.rides,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RideSamplesTableOrderingComposer
    extends Composer<_$AppDatabase, $RideSamplesTable> {
  $$RideSamplesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get power => $composableBuilder(
      column: $table.power, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get cadence => $composableBuilder(
      column: $table.cadence, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get speed => $composableBuilder(
      column: $table.speed, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get heartRate => $composableBuilder(
      column: $table.heartRate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get distance => $composableBuilder(
      column: $table.distance, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get calories => $composableBuilder(
      column: $table.calories, builder: (column) => ColumnOrderings(column));

  $$RidesTableOrderingComposer get rideId {
    final $$RidesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.rideId,
        referencedTable: $db.rides,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RidesTableOrderingComposer(
              $db: $db,
              $table: $db.rides,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RideSamplesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RideSamplesTable> {
  $$RideSamplesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);

  GeneratedColumn<int> get power =>
      $composableBuilder(column: $table.power, builder: (column) => column);

  GeneratedColumn<int> get cadence =>
      $composableBuilder(column: $table.cadence, builder: (column) => column);

  GeneratedColumn<double> get speed =>
      $composableBuilder(column: $table.speed, builder: (column) => column);

  GeneratedColumn<int> get heartRate =>
      $composableBuilder(column: $table.heartRate, builder: (column) => column);

  GeneratedColumn<int> get distance =>
      $composableBuilder(column: $table.distance, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  $$RidesTableAnnotationComposer get rideId {
    final $$RidesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.rideId,
        referencedTable: $db.rides,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$RidesTableAnnotationComposer(
              $db: $db,
              $table: $db.rides,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$RideSamplesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $RideSamplesTable,
    RideSample,
    $$RideSamplesTableFilterComposer,
    $$RideSamplesTableOrderingComposer,
    $$RideSamplesTableAnnotationComposer,
    $$RideSamplesTableCreateCompanionBuilder,
    $$RideSamplesTableUpdateCompanionBuilder,
    (RideSample, $$RideSamplesTableReferences),
    RideSample,
    PrefetchHooks Function({bool rideId})> {
  $$RideSamplesTableTableManager(_$AppDatabase db, $RideSamplesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RideSamplesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RideSamplesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RideSamplesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> rideId = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
            Value<int?> power = const Value.absent(),
            Value<int?> cadence = const Value.absent(),
            Value<double?> speed = const Value.absent(),
            Value<int?> heartRate = const Value.absent(),
            Value<int?> distance = const Value.absent(),
            Value<int?> calories = const Value.absent(),
          }) =>
              RideSamplesCompanion(
            id: id,
            rideId: rideId,
            timestamp: timestamp,
            power: power,
            cadence: cadence,
            speed: speed,
            heartRate: heartRate,
            distance: distance,
            calories: calories,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String rideId,
            required DateTime timestamp,
            Value<int?> power = const Value.absent(),
            Value<int?> cadence = const Value.absent(),
            Value<double?> speed = const Value.absent(),
            Value<int?> heartRate = const Value.absent(),
            Value<int?> distance = const Value.absent(),
            Value<int?> calories = const Value.absent(),
          }) =>
              RideSamplesCompanion.insert(
            id: id,
            rideId: rideId,
            timestamp: timestamp,
            power: power,
            cadence: cadence,
            speed: speed,
            heartRate: heartRate,
            distance: distance,
            calories: calories,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$RideSamplesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({rideId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (rideId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.rideId,
                    referencedTable:
                        $$RideSamplesTableReferences._rideIdTable(db),
                    referencedColumn:
                        $$RideSamplesTableReferences._rideIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$RideSamplesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $RideSamplesTable,
    RideSample,
    $$RideSamplesTableFilterComposer,
    $$RideSamplesTableOrderingComposer,
    $$RideSamplesTableAnnotationComposer,
    $$RideSamplesTableCreateCompanionBuilder,
    $$RideSamplesTableUpdateCompanionBuilder,
    (RideSample, $$RideSamplesTableReferences),
    RideSample,
    PrefetchHooks Function({bool rideId})>;
typedef $$WorkoutsTableCreateCompanionBuilder = WorkoutsCompanion Function({
  required String id,
  required String name,
  Value<String?> description,
  Value<String?> author,
  Value<int?> ftp,
  required String intervalsJson,
  required DateTime createdAt,
  Value<DateTime?> lastUsedAt,
  Value<int> useCount,
  Value<int> rowid,
});
typedef $$WorkoutsTableUpdateCompanionBuilder = WorkoutsCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> description,
  Value<String?> author,
  Value<int?> ftp,
  Value<String> intervalsJson,
  Value<DateTime> createdAt,
  Value<DateTime?> lastUsedAt,
  Value<int> useCount,
  Value<int> rowid,
});

class $$WorkoutsTableFilterComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ftp => $composableBuilder(
      column: $table.ftp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get intervalsJson => $composableBuilder(
      column: $table.intervalsJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get useCount => $composableBuilder(
      column: $table.useCount, builder: (column) => ColumnFilters(column));
}

class $$WorkoutsTableOrderingComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author => $composableBuilder(
      column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ftp => $composableBuilder(
      column: $table.ftp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get intervalsJson => $composableBuilder(
      column: $table.intervalsJson,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get useCount => $composableBuilder(
      column: $table.useCount, builder: (column) => ColumnOrderings(column));
}

class $$WorkoutsTableAnnotationComposer
    extends Composer<_$AppDatabase, $WorkoutsTable> {
  $$WorkoutsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
      column: $table.description, builder: (column) => column);

  GeneratedColumn<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get ftp =>
      $composableBuilder(column: $table.ftp, builder: (column) => column);

  GeneratedColumn<String> get intervalsJson => $composableBuilder(
      column: $table.intervalsJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
      column: $table.lastUsedAt, builder: (column) => column);

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);
}

class $$WorkoutsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $WorkoutsTable,
    Workout,
    $$WorkoutsTableFilterComposer,
    $$WorkoutsTableOrderingComposer,
    $$WorkoutsTableAnnotationComposer,
    $$WorkoutsTableCreateCompanionBuilder,
    $$WorkoutsTableUpdateCompanionBuilder,
    (Workout, BaseReferences<_$AppDatabase, $WorkoutsTable, Workout>),
    Workout,
    PrefetchHooks Function()> {
  $$WorkoutsTableTableManager(_$AppDatabase db, $WorkoutsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WorkoutsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WorkoutsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WorkoutsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> description = const Value.absent(),
            Value<String?> author = const Value.absent(),
            Value<int?> ftp = const Value.absent(),
            Value<String> intervalsJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<int> useCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutsCompanion(
            id: id,
            name: name,
            description: description,
            author: author,
            ftp: ftp,
            intervalsJson: intervalsJson,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            useCount: useCount,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> description = const Value.absent(),
            Value<String?> author = const Value.absent(),
            Value<int?> ftp = const Value.absent(),
            required String intervalsJson,
            required DateTime createdAt,
            Value<DateTime?> lastUsedAt = const Value.absent(),
            Value<int> useCount = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              WorkoutsCompanion.insert(
            id: id,
            name: name,
            description: description,
            author: author,
            ftp: ftp,
            intervalsJson: intervalsJson,
            createdAt: createdAt,
            lastUsedAt: lastUsedAt,
            useCount: useCount,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WorkoutsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $WorkoutsTable,
    Workout,
    $$WorkoutsTableFilterComposer,
    $$WorkoutsTableOrderingComposer,
    $$WorkoutsTableAnnotationComposer,
    $$WorkoutsTableCreateCompanionBuilder,
    $$WorkoutsTableUpdateCompanionBuilder,
    (Workout, BaseReferences<_$AppDatabase, $WorkoutsTable, Workout>),
    Workout,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$RidesTableTableManager get rides =>
      $$RidesTableTableManager(_db, _db.rides);
  $$RideSamplesTableTableManager get rideSamples =>
      $$RideSamplesTableTableManager(_db, _db.rideSamples);
  $$WorkoutsTableTableManager get workouts =>
      $$WorkoutsTableTableManager(_db, _db.workouts);
}
