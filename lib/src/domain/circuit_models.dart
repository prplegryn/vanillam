import 'dart:ui';

enum ComponentType {
  battery,
  ground,
  wireTool,
  switchSpst,
  resistor,
  led,
  bulb,
  voltageProbe,
  currentProbe,
}

extension ComponentTypeLabel on ComponentType {
  String get label {
    switch (this) {
      case ComponentType.battery:
        return '电池';
      case ComponentType.ground:
        return 'GND';
      case ComponentType.wireTool:
        return '导线';
      case ComponentType.switchSpst:
        return '开关';
      case ComponentType.resistor:
        return '电阻';
      case ComponentType.led:
        return 'LED';
      case ComponentType.bulb:
        return '灯泡';
      case ComponentType.voltageProbe:
        return '电压探针';
      case ComponentType.currentProbe:
        return '电流探针';
    }
  }

  String get category {
    switch (this) {
      case ComponentType.battery:
      case ComponentType.ground:
        return '电源';
      case ComponentType.wireTool:
        return '连接';
      case ComponentType.switchSpst:
        return '控制';
      case ComponentType.resistor:
        return '电阻';
      case ComponentType.led:
      case ComponentType.bulb:
        return '输出';
      case ComponentType.voltageProbe:
      case ComponentType.currentProbe:
        return '测量';
    }
  }
}

class CircuitComponent {
  const CircuitComponent({
    required this.id,
    required this.type,
    required this.position,
    this.rotation = 0,
    this.params = const <String, double>{},
    this.enabled = true,
  });

  final String id;
  final ComponentType type;
  final Offset position;
  final double rotation;
  final Map<String, double> params;
  final bool enabled;

  CircuitComponent copyWith({
    String? id,
    ComponentType? type,
    Offset? position,
    double? rotation,
    Map<String, double>? params,
    bool? enabled,
  }) {
    return CircuitComponent(
      id: id ?? this.id,
      type: type ?? this.type,
      position: position ?? this.position,
      rotation: rotation ?? this.rotation,
      params: params ?? this.params,
      enabled: enabled ?? this.enabled,
    );
  }

  double param(String name, double fallback) => params[name] ?? fallback;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'type': type.name,
      'position': <String, double>{'x': position.dx, 'y': position.dy},
      'rotation': rotation,
      'params': params,
      'enabled': enabled,
    };
  }
}

class WirePath {
  const WirePath({
    required this.id,
    required this.points,
    this.netId = 'main',
  });

  final String id;
  final List<Offset> points;
  final String netId;

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'netId': netId,
      'points': points.map((p) => <String, double>{'x': p.dx, 'y': p.dy}).toList(),
    };
  }
}

class CircuitProject {
  const CircuitProject({
    required this.id,
    required this.name,
    required this.version,
    required this.components,
    required this.wires,
    required this.viewport,
  });

  final String id;
  final String name;
  final int version;
  final List<CircuitComponent> components;
  final List<WirePath> wires;
  final Rect viewport;

  factory CircuitProject.seed() {
    return const CircuitProject(
      id: 'lesson-led-current-limit',
      name: 'LED 限流实验',
      version: 1,
      viewport: Rect.fromLTWH(0, 0, 720, 520),
      components: <CircuitComponent>[
        CircuitComponent(
          id: 'battery-1',
          type: ComponentType.battery,
          position: Offset(118, 154),
          params: <String, double>{'voltage': 5},
        ),
        CircuitComponent(
          id: 'switch-1',
          type: ComponentType.switchSpst,
          position: Offset(118, 328),
          enabled: true,
        ),
        CircuitComponent(
          id: 'resistor-1',
          type: ComponentType.resistor,
          position: Offset(315, 154),
          params: <String, double>{'ohms': 220, 'watts': 0.25},
        ),
        CircuitComponent(
          id: 'led-1',
          type: ComponentType.led,
          position: Offset(520, 328),
          params: <String, double>{'vf': 2.1, 'maxMilliAmps': 20},
        ),
        CircuitComponent(
          id: 'ground-1',
          type: ComponentType.ground,
          position: Offset(360, 414),
        ),
        CircuitComponent(
          id: 'v-probe-1',
          type: ComponentType.voltageProbe,
          position: Offset(525, 205),
        ),
        CircuitComponent(
          id: 'a-probe-1',
          type: ComponentType.currentProbe,
          position: Offset(226, 328),
        ),
      ],
      wires: <WirePath>[
        WirePath(
          id: 'wire-top-left',
          points: <Offset>[Offset(150, 154), Offset(248, 154)],
        ),
        WirePath(
          id: 'wire-top-right',
          points: <Offset>[Offset(382, 154), Offset(520, 154), Offset(520, 288)],
        ),
        WirePath(
          id: 'wire-bottom',
          points: <Offset>[Offset(520, 365), Offset(118, 365), Offset(118, 188)],
        ),
        WirePath(
          id: 'wire-switch',
          points: <Offset>[Offset(118, 328), Offset(118, 365)],
        ),
      ],
    );
  }

  CircuitProject copyWith({
    String? id,
    String? name,
    int? version,
    List<CircuitComponent>? components,
    List<WirePath>? wires,
    Rect? viewport,
  }) {
    return CircuitProject(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      components: components ?? this.components,
      wires: wires ?? this.wires,
      viewport: viewport ?? this.viewport,
    );
  }

  CircuitComponent? componentById(String id) {
    for (final component in components) {
      if (component.id == id) {
        return component;
      }
    }
    return null;
  }

  CircuitProject replaceComponent(CircuitComponent updated) {
    return copyWith(
      components: components.map((component) {
        return component.id == updated.id ? updated : component;
      }).toList(growable: false),
    );
  }

  CircuitProject addComponent(ComponentType type) {
    final index = components.length + 1;
    final defaults = <ComponentType, Map<String, double>>{
      ComponentType.battery: <String, double>{'voltage': 5},
      ComponentType.resistor: <String, double>{'ohms': 220, 'watts': 0.25},
      ComponentType.led: <String, double>{'vf': 2.1, 'maxMilliAmps': 20},
      ComponentType.bulb: <String, double>{'ratedVoltage': 5, 'watts': 0.5},
    };

    return copyWith(
      components: <CircuitComponent>[
        ...components,
        CircuitComponent(
          id: '${type.name}-$index',
          type: type,
          position: Offset(180 + (index % 6) * 64, 210 + (index % 4) * 52),
          params: defaults[type] ?? const <String, double>{},
        ),
      ],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'version': version,
      'viewport': <String, double>{
        'left': viewport.left,
        'top': viewport.top,
        'width': viewport.width,
        'height': viewport.height,
      },
      'components': components.map((c) => c.toJson()).toList(),
      'wires': wires.map((w) => w.toJson()).toList(),
    };
  }
}
