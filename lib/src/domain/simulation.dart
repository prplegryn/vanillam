import 'dart:math' as math;

import 'circuit_graph.dart';
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
    required this.netCount,
    required this.branchCount,
    required this.energizedComponentIds,
    required this.branchCurrents,
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
  final int netCount;
  final int branchCount;
  final Set<String> energizedComponentIds;
  final Map<String, double> branchCurrents;
  final List<DiagnosticMessage> diagnostics;

  double get currentMilliAmps => currentAmps * 1000;
  bool get hasError => diagnostics.any((message) => message.isError);
  bool get hasWarning => diagnostics.any((message) => message.isWarning);
}

class CircuitSimulator {
  const CircuitSimulator();

  SimulationSnapshot solve(CircuitProject project, {required bool running}) {
    final graph = CircuitGraph.fromProject(project);
    final diagnostics = <DiagnosticMessage>[];

    if (!running) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'paused',
          title: '仿真暂停',
          description: '点击运行后会根据端口、导线和网络重新计算电压、电流和功率。',
        ),
      );
      return _snapshot(
        running: running,
        graph: graph,
        diagnostics: diagnostics,
      );
    }

    if (graph.invalidWireIds.isNotEmpty) {
      diagnostics.add(
        DiagnosticMessage(
          code: 'invalid-wire',
          title: '导线端点失效',
          description: '有 ${graph.invalidWireIds.length} 根导线指向不存在的端口，请删除或重新连接。',
          isError: true,
        ),
      );
    }

    if (graph.voltageSources.isEmpty) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'missing-source',
          title: '缺少电源',
          description: '电路需要至少一个电压源来建立电位差。',
          isError: true,
        ),
      );
      return _snapshot(running: running, graph: graph, diagnostics: diagnostics);
    }

    final source = graph.voltageSources.first;
    if (source.positiveNet == source.negativeNet) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'source-short',
          title: '电源短路',
          description: '电源正负端处在同一网络，电流会急剧升高。请检查导线连接。',
          isError: true,
        ),
      );
      return _snapshot(
        running: running,
        graph: graph,
        diagnostics: diagnostics,
        supplyVoltage: source.voltage,
      );
    }

    final path = graph.findPrimaryPath();
    if (path == null) {
      final hasOpenSwitch = project.components.any((component) {
        return component.spec.role == SimulationRole.switcher && !component.enabled;
      });
      diagnostics.add(
        DiagnosticMessage(
          code: hasOpenSwitch ? 'open-switch' : 'open-circuit',
          title: hasOpenSwitch ? '回路被开关断开' : '没有闭合回路',
          description: hasOpenSwitch
              ? '至少一个开关处于断开状态，电流无法从电源正端回到负端。'
              : '导线尚未把电源、负载和返回路径连接成完整回路。',
          isWarning: true,
        ),
      );
      if (!graph.hasGround) {
        diagnostics.add(
          const DiagnosticMessage(
            code: 'missing-ground',
            title: '缺少参考地',
            description: '加入 GND 后，节点电压和探针读数会更容易解释。',
            isWarning: true,
          ),
        );
      }
      return _snapshot(
        running: running,
        graph: graph,
        diagnostics: diagnostics,
        supplyVoltage: source.voltage,
      );
    }

    final resistance = _pathResistance(path);
    final fixedDrop = _pathForwardDrop(path);
    final double current =
        resistance <= 0.5 ? source.voltage / 0.5 : math.max(0.0, (source.voltage - fixedDrop) / resistance);
    final energized = path.components.map((component) => component.id).toSet();
    final branchCurrents = <String, double>{
      for (final branch in path.branches) branch.component.id: current,
    };
    final led = _first(path, ComponentType.led);
    final resistor = _first(path, ComponentType.resistor) ?? _first(path, ComponentType.variableResistor);
    final bulb = _first(path, ComponentType.bulb);
    final double resistorPower = resistor == null ? 0.0 : current * current * _componentResistance(resistor);

    if (resistance <= 0.5) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'short-circuit',
          title: '疑似短路',
          description: '闭合路径里的等效电阻过小，电流会急剧升高。请加入限流电阻或负载。',
          isError: true,
        ),
      );
    }

    if (led != null && current * 1000 > led.param('maxMilliAmps', 20)) {
      diagnostics.add(
        DiagnosticMessage(
          code: 'led-over-current',
          title: 'LED 过流',
          description:
              '当前约 ${_format(current * 1000)} mA，超过 ${_format(led.param('maxMilliAmps', 20))} mA。增大限流电阻可以降低电流。',
          isError: true,
        ),
      );
    }

    if (!graph.hasGround) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'missing-ground',
          title: '缺少参考地',
          description: '电路能计算电流，但节点电压缺少明确的 0V 参考。',
          isWarning: true,
        ),
      );
    }

    if (current <= 0.0001 && diagnostics.every((message) => !message.isError)) {
      diagnostics.add(
        const DiagnosticMessage(
          code: 'no-forward-current',
          title: '没有明显电流',
          description: '负载压降高于电源电压，或当前连接方向不满足导通条件。',
          isWarning: true,
        ),
      );
    }

    if (diagnostics.isEmpty || diagnostics.every((message) => message.isWarning)) {
      diagnostics.insert(
        0,
        DiagnosticMessage(
          code: 'normal',
          title: '限流正常',
          description:
              '闭合路径包含 ${path.branches.length} 个支路，LED 电流约 ${_format(current * 1000)} mA，电阻功率约 ${_format(resistorPower * 1000)} mW。',
        ),
      );
    }

    return SimulationSnapshot(
      running: running,
      loopClosed: true,
      supplyVoltage: source.voltage,
      totalResistance: resistance,
      currentAmps: current,
      ledForwardVoltage: led?.param('vf', 2.1) ?? 0,
      ledLit: led != null && current > 0.002 && diagnostics.every((message) => message.code != 'short-circuit'),
      bulbLit: bulb != null && current > 0.01,
      resistorPowerWatts: resistorPower,
      netCount: graph.nets.length,
      branchCount: graph.branches.length,
      energizedComponentIds: energized,
      branchCurrents: branchCurrents,
      diagnostics: diagnostics,
    );
  }

  SimulationSnapshot _snapshot({
    required bool running,
    required CircuitGraph graph,
    required List<DiagnosticMessage> diagnostics,
    double supplyVoltage = 0,
  }) {
    return SimulationSnapshot(
      running: running,
      loopClosed: false,
      supplyVoltage: supplyVoltage,
      totalResistance: 0,
      currentAmps: 0,
      ledForwardVoltage: 0,
      ledLit: false,
      bulbLit: false,
      resistorPowerWatts: 0,
      netCount: graph.nets.length,
      branchCount: graph.branches.length,
      energizedComponentIds: const <String>{},
      branchCurrents: const <String, double>{},
      diagnostics: diagnostics,
    );
  }

  double _pathResistance(CircuitPath path) {
    var resistance = 0.0;
    for (final branch in path.branches) {
      resistance += _branchResistance(branch);
    }
    return resistance;
  }

  double _branchResistance(GraphBranch branch) {
    return _componentResistance(branch.component);
  }

  double _componentResistance(CircuitComponent component) {
    switch (component.type) {
      case ComponentType.resistor:
      case ComponentType.variableResistor:
      case ComponentType.ldr:
      case ComponentType.ntc:
        return component.param('ohms', component.param('r25', 220));
      case ComponentType.potentiometer:
        return component.param('ohms', 10000) * math.max(0.05, component.param('position', 0.5));
      case ComponentType.bulb:
      case ComponentType.buzzer:
        final voltage = component.param('ratedVoltage', 5);
        final watts = math.max(component.param('watts', 0.5), 0.01);
        return voltage * voltage / watts;
      case ComponentType.dcMotor:
        return component.param('coilOhms', 20);
      case ComponentType.currentProbe:
        return component.param('burdenOhms', 0.05);
      case ComponentType.led:
      case ComponentType.diode:
      case ComponentType.zenerDiode:
        return 0.1;
      default:
        return 0;
    }
  }

  double _pathForwardDrop(CircuitPath path) {
    var drop = 0.0;
    for (final component in path.components) {
      switch (component.type) {
        case ComponentType.led:
          drop += component.param('vf', 2.1);
        case ComponentType.diode:
          drop += component.param('vf', 0.7);
        default:
          break;
      }
    }
    return drop;
  }

  CircuitComponent? _first(CircuitPath path, ComponentType type) {
    for (final component in path.components) {
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
