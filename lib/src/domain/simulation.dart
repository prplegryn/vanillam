import 'dart:math' as math;

import 'circuit_models.dart';

class DiagnosticMessage {
  const DiagnosticMessage({
    required this.code,
    required this.title,
    required this.description,
    this.isError = false,
    this.isWarning = false,
  });

  final String code;
  final String title;
  final String description;
  final bool isError;
  final bool isWarning;
}

class SimulationSnapshot {
  const SimulationSnapshot({
    required this.running,
    required this.loopClosed,
    required this.supplyVoltage,
    required this.totalResistance,
    required this.currentAmps,
    required this.ledForwardVoltage,
    required this.ledLit,
    required this.bulbLit,
    required this.resistorPowerWatts,
    required this.diagnostics,
  });

  final bool running;
  final bool loopClosed;
  final double supplyVoltage;
  final double totalResistance;
  final double currentAmps;
  final double ledForwardVoltage;
  final bool ledLit;
  final bool bulbLit;
  final double resistorPowerWatts;
  final List<DiagnosticMessage> diagnostics;

  double get currentMilliAmps => currentAmps * 1000;
  bool get hasError => diagnostics.any((message) => message.isError);
  bool get hasWarning => diagnostics.any((message) => message.isWarning);
}

class CircuitSimulator {
  const CircuitSimulator();

  SimulationSnapshot solve(CircuitProject project, {required bool running}) {
    final battery = _first(project, ComponentType.battery);
    final resistor = _first(project, ComponentType.resistor);
    final led = _first(project, ComponentType.led);
    final bulb = _first(project, ComponentType.bulb);
    final switchSpst = _first(project, ComponentType.switchSpst);

    final supplyVoltage = battery?.param('voltage', 5) ?? 0;
    final resistance = resistor?.param('ohms', 220) ?? 0;
    final ledVf = led?.param('vf', 2.1) ?? 0;
    final maxLedMilliAmps = led?.param('maxMilliAmps', 20) ?? 20;
    final switchClosed = switchSpst?.enabled ?? true;
    final hasLoad = led != null || bulb != null;
    final loopClosed = running && switchClosed && battery != null && hasLoad;

    var current = 0.0;
    if (loopClosed) {
      if (resistance <= 0.5) {
        current = supplyVoltage / 0.5;
      } else {
        final loadDrop = led == null ? 0 : ledVf;
        current = math.max(0, (supplyVoltage - loadDrop) / resistance);
      }
    }

    final resistorPower = current * current * math.max(resistance, 0);
    final diagnostics = <DiagnosticMessage>[];

    if (!running) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'paused',
          title: '仿真暂停',
          description: '点击运行后会计算节点电压、电流和功率。',
        ),
      );
    } else if (!switchClosed) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'open-switch',
          title: '回路断开',
          description: '开关断开时没有闭合回路，LED 和灯泡都不会有持续电流。',
          isWarning: true,
        ),
      );
    } else if (battery == null) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'missing-source',
          title: '缺少电源',
          description: '电路需要至少一个电源来建立电位差。',
          isError: true,
        ),
      );
    } else if (!hasLoad) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'missing-load',
          title: '缺少负载',
          description: '加入 LED、灯泡或电阻负载后才能观察电能转换。',
          isWarning: true,
        ),
      );
    } else if (resistance <= 0.5) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'short-circuit',
          title: '疑似短路',
          description: '回路电阻过小，电流会急剧升高。请加入限流电阻。',
          isError: true,
        ),
      );
    } else if (led != null && current * 1000 > maxLedMilliAmps) {
      diagnostics.add(
        DiagnosticMessage(
          code: 'led-over-current',
          title: 'LED 过流',
          description:
              '当前约 ${_format(current * 1000)} mA，超过 ${_format(maxLedMilliAmps)} mA。增大限流电阻可以降低电流。',
          isError: true,
        ),
      );
    } else if (current <= 0.0001) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'no-forward-current',
          title: '没有明显电流',
          description: '电源电压不足以让 LED 正向导通，或回路仍未闭合。',
          isWarning: true,
        ),
      );
    } else {
      diagnostics.add(
        DiagnosticMessage(
          code: 'normal',
          title: '限流正常',
          description:
              'LED 电流约 ${_format(current * 1000)} mA，电阻功率约 ${_format(resistorPower * 1000)} mW。',
        ),
      );
    }

    return SimulationSnapshot(
      running: running,
      loopClosed: loopClosed,
      supplyVoltage: supplyVoltage,
      totalResistance: resistance,
      currentAmps: current,
      ledForwardVoltage: ledVf,
      ledLit: led != null && current > 0.002 && !diagnostics.any((d) => d.code == 'short-circuit'),
      bulbLit: bulb != null && current > 0.01,
      resistorPowerWatts: resistorPower,
      diagnostics: diagnostics,
    );
  }

  CircuitComponent? _first(CircuitProject project, ComponentType type) {
    for (final component in project.components) {
      if (component.type == type) {
        return component;
      }
    }
    return null;
  }

  static String _format(double value) {
    if (value.abs() >= 100) {
      return value.toStringAsFixed(0);
    }
    if (value.abs() >= 10) {
      return value.toStringAsFixed(1);
    }
    return value.toStringAsFixed(2);
  }
}
