import 'package:flutter_test/flutter_test.dart';
import 'package:vanilla/src/domain/circuit_models.dart';
import 'package:vanilla/src/domain/simulation.dart';

void main() {
  const simulator = CircuitSimulator();

  test('seed LED limiter computes a safe current', () {
    final project = CircuitProject.seed();
    final snapshot = simulator.solve(project, running: true);

    expect(snapshot.loopClosed, isTrue);
    expect(snapshot.ledLit, isTrue);
    expect(snapshot.currentMilliAmps, closeTo(13.18, 0.2));
    expect(snapshot.hasError, isFalse);
  });

  test('open switch reports an open circuit', () {
    final project = CircuitProject.seed();
    final switcher = project.componentById('switch-1')!;
    final snapshot = simulator.solve(
      project.replaceComponent(switcher.copyWith(enabled: false)),
      running: true,
    );

    expect(snapshot.loopClosed, isFalse);
    expect(snapshot.currentAmps, 0);
    expect(snapshot.diagnostics.first.code, 'open-switch');
  });

  test('too small resistance reports LED over-current or short circuit', () {
    final project = CircuitProject.seed();
    final resistor = project.componentById('resistor-1')!;
    final snapshot = simulator.solve(
      project.replaceComponent(
        resistor.copyWith(params: <String, double>{...resistor.params, 'ohms': 22}),
      ),
      running: true,
    );

    expect(snapshot.hasError, isTrue);
    expect(snapshot.diagnostics.first.code, 'led-over-current');
  });
}
