import 'dart:collection';

import 'circuit_models.dart';

class CircuitNet {
  const CircuitNet({
    required this.id,
    required this.ports,
    this.voltage,
  });

  final String id;
  final List<PortRef> ports;
  final double? voltage;

  bool containsComponent(String componentId) {
    return ports.any((port) => port.componentId == componentId);
  }
}

class GraphBranch {
  const GraphBranch({
    required this.id,
    required this.component,
    required this.from,
    required this.to,
    required this.netA,
    required this.netB,
    required this.role,
  });

  final String id;
  final CircuitComponent component;
  final PortRef from;
  final PortRef to;
  final String netA;
  final String netB;
  final SimulationRole role;

  bool get connectsDifferentNets => netA != netB;

  bool get isLoadBranch {
    switch (role) {
      case SimulationRole.resistor:
      case SimulationRole.variableResistor:
      case SimulationRole.potentiometer:
      case SimulationRole.led:
      case SimulationRole.lamp:
      case SimulationRole.diode:
      case SimulationRole.motor:
      case SimulationRole.meter:
        return true;
      case SimulationRole.conductor:
      case SimulationRole.voltageSource:
      case SimulationRole.currentSource:
      case SimulationRole.reference:
      case SimulationRole.switcher:
      case SimulationRole.capacitor:
      case SimulationRole.inductor:
      case SimulationRole.transistor:
      case SimulationRole.mosfet:
      case SimulationRole.visualizer:
      case SimulationRole.digital:
      case SimulationRole.module:
        return false;
    }
  }
}

class VoltageSourceBranch {
  const VoltageSourceBranch({
    required this.component,
    required this.positiveNet,
    required this.negativeNet,
    required this.voltage,
  });

  final CircuitComponent component;
  final String positiveNet;
  final String negativeNet;
  final double voltage;
}

class CircuitPath {
  const CircuitPath({required this.source, required this.branches});

  final VoltageSourceBranch source;
  final List<GraphBranch> branches;

  bool contains(ComponentType type) {
    return branches.any((branch) => branch.component.type == type);
  }

  Iterable<CircuitComponent> get components => branches.map((branch) => branch.component);
}

class CircuitGraph {
  const CircuitGraph({
    required this.nets,
    required this.netForPort,
    required this.branches,
    required this.voltageSources,
    required this.invalidWireIds,
  });

  final List<CircuitNet> nets;
  final Map<PortRef, String> netForPort;
  final List<GraphBranch> branches;
  final List<VoltageSourceBranch> voltageSources;
  final List<String> invalidWireIds;

  bool get hasGround => nets.any((net) {
        return net.ports.any((port) => port.portId == 'gnd' || port.portId == 'ground');
      });

  bool get hasOpenSwitch => branches.any((branch) {
        return branch.role == SimulationRole.switcher && branch.connectsDifferentNets && !branch.component.enabled;
      });

  String? netFor(PortRef ref) => netForPort[ref];

  CircuitPath? findPrimaryPath() {
    if (voltageSources.isEmpty) {
      return null;
    }
    final source = voltageSources.first;
    final branchesByNet = <String, List<GraphBranch>>{};
    for (final branch in branches) {
      if (!branch.isLoadBranch || !branch.connectsDifferentNets) {
        continue;
      }
      branchesByNet.putIfAbsent(branch.netA, () => <GraphBranch>[]).add(branch);
      branchesByNet.putIfAbsent(branch.netB, () => <GraphBranch>[]).add(branch);
    }

    final queue = Queue<String>()..add(source.positiveNet);
    final visited = <String>{source.positiveNet};
    final previousNet = <String, String>{};
    final previousBranch = <String, GraphBranch>{};

    while (queue.isNotEmpty) {
      final current = queue.removeFirst();
      if (current == source.negativeNet) {
        break;
      }
      for (final branch in branchesByNet[current] ?? const <GraphBranch>[]) {
        final next = branch.netA == current ? branch.netB : branch.netA;
        if (visited.add(next)) {
          previousNet[next] = current;
          previousBranch[next] = branch;
          queue.add(next);
        }
      }
    }

    if (!visited.contains(source.negativeNet)) {
      return null;
    }

    final path = <GraphBranch>[];
    var cursor = source.negativeNet;
    while (cursor != source.positiveNet) {
      final branch = previousBranch[cursor];
      final before = previousNet[cursor];
      if (branch == null || before == null) {
        return null;
      }
      path.insert(0, branch);
      cursor = before;
    }
    return CircuitPath(source: source, branches: path);
  }

  factory CircuitGraph.fromProject(CircuitProject project) {
    final union = _UnionFind();
    final invalidWireIds = <String>[];

    for (final anchor in project.portAnchors()) {
      union.add(anchor.ref.key);
    }

    for (final wire in project.wires) {
      final from = project.portPosition(wire.from);
      final to = project.portPosition(wire.to);
      if (from == null || to == null) {
        invalidWireIds.add(wire.id);
        continue;
      }
      union.union(wire.from.key, wire.to.key);
    }

    for (final component in project.components) {
      final spec = component.spec;
      if (spec.role == SimulationRole.switcher && component.enabled && spec.ports.length >= 2) {
        union.union(
          PortRef(componentId: component.id, portId: spec.ports[0].id).key,
          PortRef(componentId: component.id, portId: spec.ports[1].id).key,
        );
      }
      if (spec.role == SimulationRole.conductor && spec.ports.length >= 2 && component.type != ComponentType.openFault) {
        for (var i = 1; i < spec.ports.length; i++) {
          union.union(
            PortRef(componentId: component.id, portId: spec.ports[0].id).key,
            PortRef(componentId: component.id, portId: spec.ports[i].id).key,
          );
        }
      }
    }

    final rootToPorts = <String, List<PortRef>>{};
    for (final anchor in project.portAnchors()) {
      final root = union.find(anchor.ref.key);
      rootToPorts.putIfAbsent(root, () => <PortRef>[]).add(anchor.ref);
    }

    var netIndex = 0;
    final rootToNetId = <String, String>{};
    final nets = <CircuitNet>[];
    for (final entry in rootToPorts.entries) {
      final id = 'net-${++netIndex}';
      rootToNetId[entry.key] = id;
      nets.add(CircuitNet(id: id, ports: entry.value));
    }

    final netForPort = <PortRef, String>{};
    for (final anchor in project.portAnchors()) {
      final root = union.find(anchor.ref.key);
      final netId = rootToNetId[root];
      if (netId != null) {
        netForPort[anchor.ref] = netId;
      }
    }

    final branches = <GraphBranch>[];
    final voltageSources = <VoltageSourceBranch>[];

    for (final component in project.components) {
      final spec = component.spec;
      if (spec.ports.length < 2) {
        continue;
      }
      final fromPort = _primaryPort(spec, positive: true);
      final toPort = _primaryPort(spec, positive: false);
      if (fromPort == null || toPort == null) {
        continue;
      }
      final fromRef = PortRef(componentId: component.id, portId: fromPort.id);
      final toRef = PortRef(componentId: component.id, portId: toPort.id);
      final netA = netForPort[fromRef];
      final netB = netForPort[toRef];
      if (netA == null || netB == null) {
        continue;
      }

      if (spec.role == SimulationRole.voltageSource) {
        voltageSources.add(
          VoltageSourceBranch(
            component: component,
            positiveNet: netA,
            negativeNet: netB,
            voltage: _sourceVoltage(component),
          ),
        );
        continue;
      }

      branches.add(
        GraphBranch(
          id: 'branch-${component.id}',
          component: component,
          from: fromRef,
          to: toRef,
          netA: netA,
          netB: netB,
          role: spec.role,
        ),
      );
    }

    return CircuitGraph(
      nets: nets,
      netForPort: netForPort,
      branches: branches,
      voltageSources: voltageSources,
      invalidWireIds: invalidWireIds,
    );
  }

  static PortSpec? _primaryPort(ComponentSpec spec, {required bool positive}) {
    if (positive) {
      for (final port in spec.ports) {
        if (port.polarity == PortPolarity.positive || port.polarity == PortPolarity.anode) {
          return port;
        }
      }
      return spec.ports.first;
    }
    for (final port in spec.ports) {
      if (port.polarity == PortPolarity.negative ||
          port.polarity == PortPolarity.cathode ||
          port.polarity == PortPolarity.ground) {
        return port;
      }
    }
    return spec.ports.length > 1 ? spec.ports[1] : null;
  }

  static double _sourceVoltage(CircuitComponent component) {
    switch (component.type) {
      case ComponentType.adjustableDcSupply:
        return component.param('voltage', 5);
      case ComponentType.pwmSource:
        return component.param('highVoltage', 5) * component.param('duty', 0.5);
      case ComponentType.dualSupply:
        return component.param('positiveVoltage', 12) - component.param('negativeVoltage', -12);
      case ComponentType.acSource:
        return component.param('vrms', 6) * 1.414;
      default:
        return component.param('voltage', 5);
    }
  }
}

class _UnionFind {
  final _parent = <String, String>{};

  void add(String item) {
    _parent.putIfAbsent(item, () => item);
  }

  String find(String item) {
    add(item);
    final parent = _parent[item]!;
    if (parent == item) {
      return item;
    }
    final root = find(parent);
    _parent[item] = root;
    return root;
  }

  void union(String a, String b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA != rootB) {
      _parent[rootB] = rootA;
    }
  }
}
