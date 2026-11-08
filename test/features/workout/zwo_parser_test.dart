import 'package:flutter_test/flutter_test.dart';
import 'package:ridecontroller/features/workout/parsers/zwo_parser.dart';

void main() {
  const ftp = 200;

  test('decimal durations are read, not replaced by 60 s', () {
    final plan = ZwoParser().parse('''
<workout_file>
  <name>Décimales</name>
  <workout>
    <SteadyState Duration="300.4" Power="0.75"/>
    <IntervalsT Repeat="2" OnDuration="30.6" OffDuration="29.5" OnPower="1.2" OffPower="0.5"/>
  </workout>
</workout_file>''', ftp: ftp);
    expect(plan.intervals.first.duration, const Duration(seconds: 300));
    expect(plan.intervals.first.targetPower, 150);
    expect(plan.intervals[1].duration, const Duration(seconds: 31));
    expect(plan.intervals[2].duration, const Duration(seconds: 30));
  });

  test('ramps keep their total duration', () {
    final plan = ZwoParser().parse('''
<workout_file>
  <workout>
    <Warmup Duration="303" PowerLow="0.5" PowerHigh="0.75"/>
    <Ramp Duration="125" PowerLow="0.6" PowerHigh="1.0"/>
  </workout>
</workout_file>''', ftp: ftp);
    expect(plan.totalDuration, const Duration(seconds: 303 + 125));
    expect(plan.intervals.first.targetPower, 100);
    expect(plan.intervals[4].targetPower, 150);
  });
}
