import 'package:flutter_test/flutter_test.dart';

import 'package:lifeos_mobile/data/models/task.dart';

void main() {
  test('Priority maps between backend enum and design labels', () {
    expect(Priority.label('HIGH'), 'P1');
    expect(Priority.label('MEDIUM'), 'P2');
    expect(Priority.label('LOW'), 'P3');
    expect(Priority.fromLabel('P1'), Priority.high);
    expect(Priority.fromLabel('P3'), Priority.low);
  });
}
