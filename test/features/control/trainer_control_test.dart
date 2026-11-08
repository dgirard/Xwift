import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/control/trainer_control_provider.dart';
import 'package:ridecontroller/features/ftms/ftms_provider.dart';
import 'package:ridecontroller/models/workout_plan.dart';

import '../../helpers/fake_ftms.dart';

Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

({ProviderContainer container, FakeFtms ftms, TrainerControlNotifier control})
    setUpControl({bool ready = true}) {
  final container = ProviderContainer(overrides: [
    ftmsControlProvider.overrideWith((ref) => FakeFtms(ref, ready: ready)),
  ]);
  addTearDown(container.dispose);
  final control = container.read(trainerControlProvider.notifier);
  final ftms = container.read(ftmsControlProvider.notifier) as FakeFtms;
  return (container: container, ftms: ftms, control: control);
}

void main() {
  test('a setting chosen without trainer is sent once the trainer is ready',
      () async {
    final t = setUpControl(ready: false);
    t.control.setGrade(2);
    await settle();
    expect(t.ftms.commands, isEmpty);
    expect(t.container.read(trainerControlProvider).status,
        ApplyStatus.waitingTrainer);

    t.ftms.setReady(true);
    await settle();
    expect(t.ftms.commands, ['grade 2.0']);
    expect(
        t.container.read(trainerControlProvider).status, ApplyStatus.applied);
  });

  test('changing mode sends the command of the new mode', () async {
    final t = setUpControl();
    await settle();
    t.control.setMode(ControlMode.power);
    await settle();
    t.control.setMode(ControlMode.resistance);
    await settle();
    t.control.setMode(ControlMode.grade);
    await settle();
    expect(t.ftms.commands,
        ['grade 0.0', 'power 150', 'resistance 2.5', 'grade 0.0']);
  });

  test('rapid taps send the first value then only the latest one', () async {
    final t = setUpControl();
    await settle();
    t.ftms.commands.clear();

    final gate = Completer<void>();
    t.ftms.gate = gate;
    for (var i = 0; i < 5; i++) {
      t.control.changePower(1); // +10 W each
    }
    await settle();
    expect(t.ftms.commands, ['power 160'], reason: 'one command in flight');
    expect(t.container.read(trainerControlProvider).targetPower, 200,
        reason: 'the screen shows the requested value at once');

    t.ftms.gate = null;
    gate.complete();
    await settle();
    expect(t.ftms.commands, ['power 160', 'power 200']);
  });

  test('a program sends each new interval target to the trainer', () async {
    final t = setUpControl();
    await settle();
    t.ftms.commands.clear();

    t.control.startProgram(const WorkoutPlan(name: 'Test', intervals: [
      WorkoutInterval(duration: Duration(seconds: 3), targetPower: 100),
      WorkoutInterval(duration: Duration(seconds: 2), targetPower: 200),
      WorkoutInterval(duration: Duration(seconds: 4), targetPower: 150),
    ]));
    await t.control.onRideStarted();
    await settle();
    expect(t.ftms.commands, ['power 100', 'start', 'power 100']);

    t.ftms.commands.clear();
    for (var s = 1; s <= 3; s++) {
      t.control.onRideTick(Duration(seconds: s));
      await settle();
    }
    expect(t.ftms.commands, ['power 200'],
        reason: 'second interval starts at 3 s');

    t.control.onRideTick(const Duration(seconds: 5));
    await settle();
    t.control.changeIntensity(1); // 105 %
    await settle();
    expect(t.ftms.commands, ['power 200', 'power 150', 'power 158']);

    t.control.onRideTick(const Duration(seconds: 9));
    await settle();
    final state = t.container.read(trainerControlProvider);
    expect(state.program, isNull);
    expect(state.programFinished, isTrue);
    expect(state.targetPower, 158, reason: 'the last target is kept');
  });

  test('the program does not advance while the ride is paused', () async {
    final t = setUpControl();
    t.control.startProgram(const WorkoutPlan(name: 'Test', intervals: [
      WorkoutInterval(duration: Duration(seconds: 3), targetPower: 100),
      WorkoutInterval(duration: Duration(seconds: 3), targetPower: 200),
    ]));
    await t.control.onRideStarted();
    t.control.onRideTick(const Duration(seconds: 2));
    await t.control.onRidePaused();
    // While paused, no tick; on resume the ride time continues from 2 s.
    await t.control.onRideResumed(const Duration(seconds: 2));
    t.control.onRideTick(const Duration(seconds: 3));
    await settle();
    final program = t.container.read(trainerControlProvider).program!;
    expect(program.elapsed, const Duration(seconds: 3));
    expect(program.index, 1);
  });

  test('skipping an interval jumps to the next target', () async {
    final t = setUpControl();
    await settle();
    t.ftms.commands.clear();
    t.control.startProgram(const WorkoutPlan(name: 'Test', intervals: [
      WorkoutInterval(duration: Duration(minutes: 10), targetPower: 120),
      WorkoutInterval(duration: Duration(minutes: 5), targetPower: 250),
    ]));
    await settle();
    t.control.skipInterval();
    await settle();
    final program = t.container.read(trainerControlProvider).program!;
    expect(program.index, 1);
    expect(program.elapsed, const Duration(minutes: 10));
    expect(t.ftms.commands, ['power 120', 'power 250']);

    t.control.skipInterval(); // last interval: the program ends
    await settle();
    expect(t.container.read(trainerControlProvider).program, isNull);
    expect(t.container.read(trainerControlProvider).targetPower, 250);
  });

  test('trainer answers are turned into rider-facing statuses', () {
    expect(TrainerControlNotifier.statusOf(const FtmsResponse.success(5)),
        ApplyStatus.applied);
    expect(
        TrainerControlNotifier.statusOf(
            const FtmsResponse.failed(5, FtmsFailure.timeout)),
        ApplyStatus.noResponse);
    expect(
        TrainerControlNotifier.statusOf(
            const FtmsResponse.failed(5, FtmsFailure.notConnected)),
        ApplyStatus.waitingTrainer);
    expect(
        TrainerControlNotifier.statusOf(const FtmsResponse(
            requestOpCode: 0x05, resultCode: 0x02, isSuccess: false)),
        ApplyStatus.notSupported);
    expect(
        TrainerControlNotifier.statusOf(const FtmsResponse(
            requestOpCode: 0x00, resultCode: 0x04, isSuccess: false)),
        ApplyStatus.noControl);
    expect(
        TrainerControlNotifier.statusOf(const FtmsResponse(
            requestOpCode: 0x04, resultCode: 0x03, isSuccess: false)),
        ApplyStatus.rejected);
  });

  test('resistance levels follow the range published by the trainer', () {
    final scale = ResistanceScale.from(null);
    expect(scale.min, 0);
    expect(scale.max, 10);
    expect(scale.step, 0.5);
    expect(scale.snap(3.26), 3.5);
    expect(scale.snap(42), 10);
  });
}
