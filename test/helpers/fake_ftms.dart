import 'dart:async';

import 'package:ridecontroller/core/constants/ftms_constants.dart';
import 'package:ridecontroller/features/ftms/ftms_provider.dart';

/// Trainer double: records the commands instead of writing them over BLE.
class FakeFtms extends FtmsControlNotifier {
  FakeFtms(super.ref, {bool ready = true, super.clock})
      : super(connected: false) {
    state = state.copyWith(isReady: ready, hasControl: ready);
  }

  final commands = <String>[];

  /// When set, commands wait for it (simulates a slow trainer).
  Completer<void>? gate;
  FtmsResponse Function(int opCode) answer = FtmsResponse.success;

  void setReady(bool ready) => state = state.copyWith(isReady: ready);

  Future<FtmsResponse> _record(String command, int opCode) async {
    commands.add(command);
    final pending = gate;
    if (pending != null) await pending.future;
    return answer(opCode);
  }

  @override
  Future<FtmsResponse> setGrade(double grade) =>
      _record('grade $grade', FtmsConstants.opCodeSetSimulationParams);

  @override
  Future<FtmsResponse> setTargetPower(int watts) =>
      _record('power $watts', FtmsConstants.opCodeSetTargetPower);

  @override
  Future<FtmsResponse> setResistance(double level) =>
      _record('resistance $level', FtmsConstants.opCodeSetTargetResistance);

  @override
  Future<FtmsResponse> start() =>
      _record('start', FtmsConstants.opCodeStartOrResume);

  @override
  Future<FtmsResponse> pause() =>
      _record('pause', FtmsConstants.opCodeStopOrPause);

  @override
  Future<FtmsResponse> stop() =>
      _record('stop', FtmsConstants.opCodeStopOrPause);
}
