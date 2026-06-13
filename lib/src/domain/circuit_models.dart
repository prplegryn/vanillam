import 'dart:ui';

enum ComponentType {
  battery,
  adjustableDcSupply,
  acSource,
  ground,
  currentSource,
  dualSupply,
  wireTool,
  node,
  openFault,
  netLabel,
  breadboard,
  switchSpst,
  pushButtonNo,
  pushButtonNc,
  switchSpdt,
  resistor,
  variableResistor,
  potentiometer,
  ldr,
  ntc,
  fuse,
  capacitor,
  electrolyticCapacitor,
  inductor,
  bulb,
  led,
  rgbLed,
  buzzer,
  dcMotor,
  diode,
  zenerDiode,
  bridgeRectifier,
  transistorNpn,
  mosfetN,
  voltageProbe,
  currentProbe,
  multimeter,
  powerMeter,
  oscilloscope,
  voltageHeatmap,
  currentArrows,
  pwmSource,
  logicAnd,
  opAmp,
  comparator,
  timer555,
}

enum PortKind { electrical, logic, measurement }

enum PortPolarity { none, positive, negative, anode, cathode, ground, input, output }

enum SimulationRole {
  conductor,
  voltageSource,
  currentSource,
  reference,
  switcher,
  resistor,
  variableResistor,
  potentiometer,
  capacitor,
  inductor,
  led,
  lamp,
  diode,
  transistor,
  mosfet,
  motor,
  meter,
  visualizer,
  digital,
  module,
}

enum ComponentStage { mvp, advanced, later }

extension ComponentTypeLabel on ComponentType {
  String get label => ComponentCatalog.specFor(this).name;
  String get category => ComponentCatalog.specFor(this).category;
  ComponentStage get stage => ComponentCatalog.specFor(this).stage;
}

class PortSpec {
  const PortSpec({
    required this.id,
    required this.name,
    required this.localPosition,
    this.kind = PortKind.electrical,
    this.polarity = PortPolarity.none,
  });

  final String id;
  final String name;
  final Offset localPosition;
  final PortKind kind;
  final PortPolarity polarity;
}

class ComponentSpec {
  const ComponentSpec({
    required this.type,
    required this.name,
    required this.category,
    required this.stage,
    required this.role,
    required this.ports,
    required this.defaultParams,
    required this.teaching,
  });

  final ComponentType type;
  final String name;
  final String category;
  final ComponentStage stage;
  final SimulationRole role;
  final List<PortSpec> ports;
  final Map<String, double> defaultParams;
  final String teaching;

  PortSpec? portById(String portId) {
    for (final port in ports) {
      if (port.id == portId) {
        return port;
      }
    }
    return null;
  }
}

class ComponentCatalog {
  const ComponentCatalog._();

  static const _twoTerminal = <PortSpec>[
    PortSpec(id: 'a', name: 'A', localPosition: Offset(-48, 0)),
    PortSpec(id: 'b', name: 'B', localPosition: Offset(48, 0)),
  ];

  static const _supplyPorts = <PortSpec>[
    PortSpec(id: 'positive', name: '+', localPosition: Offset(42, 0), polarity: PortPolarity.positive),
    PortSpec(id: 'negative', name: '-', localPosition: Offset(-42, 0), polarity: PortPolarity.negative),
  ];

  static const specs = <ComponentType, ComponentSpec>{
    ComponentType.battery: ComponentSpec(
      type: ComponentType.battery,
      name: '电池',
      category: '电源',
      stage: ComponentStage.mvp,
      role: SimulationRole.voltageSource,
      ports: _supplyPorts,
      defaultParams: <String, double>{'voltage': 5, 'internalOhms': 0.2},
      teaching: '固定直流电压源，真实模式可加入内阻和电量衰减。',
    ),
    ComponentType.adjustableDcSupply: ComponentSpec(
      type: ComponentType.adjustableDcSupply,
      name: '可调直流电源',
      category: '电源',
      stage: ComponentStage.mvp,
      role: SimulationRole.voltageSource,
      ports: _supplyPorts,
      defaultParams: <String, double>{'voltage': 5, 'currentLimit': 0.5, 'internalOhms': 0.1},
      teaching: '稳压源带限流，用于解释恒压、恒流和安全供电。',
    ),
    ComponentType.acSource: ComponentSpec(
      type: ComponentType.acSource,
      name: '交流电源',
      category: '电源',
      stage: ComponentStage.advanced,
      role: SimulationRole.voltageSource,
      ports: _twoTerminal,
      defaultParams: <String, double>{'vrms': 6, 'frequency': 50},
      teaching: '正弦交流源，用于整流、滤波和波形实验。',
    ),
    ComponentType.ground: ComponentSpec(
      type: ComponentType.ground,
      name: 'GND',
      category: '电源',
      stage: ComponentStage.mvp,
      role: SimulationRole.reference,
      ports: <PortSpec>[
        PortSpec(id: 'gnd', name: '0V', localPosition: Offset(0, -24), polarity: PortPolarity.ground),
      ],
      defaultParams: <String, double>{},
      teaching: '参考电位点，同名地自动视为同一参考网络。',
    ),
    ComponentType.currentSource: ComponentSpec(
      type: ComponentType.currentSource,
      name: '电流源',
      category: '电源',
      stage: ComponentStage.later,
      role: SimulationRole.currentSource,
      ports: _twoTerminal,
      defaultParams: <String, double>{'current': 0.01, 'maxVoltage': 12},
      teaching: '恒流源，用于理解负载线和电源输出能力。',
    ),
    ComponentType.dualSupply: ComponentSpec(
      type: ComponentType.dualSupply,
      name: '双电源',
      category: '电源',
      stage: ComponentStage.later,
      role: SimulationRole.voltageSource,
      ports: <PortSpec>[
        PortSpec(id: 'positive', name: '+V', localPosition: Offset(-42, -20), polarity: PortPolarity.positive),
        PortSpec(id: 'ground', name: 'GND', localPosition: Offset(-42, 0), polarity: PortPolarity.ground),
        PortSpec(id: 'negative', name: '-V', localPosition: Offset(-42, 20), polarity: PortPolarity.negative),
      ],
      defaultParams: <String, double>{'positiveVoltage': 12, 'negativeVoltage': -12},
      teaching: '为运放和模拟电路提供正负电源轨。',
    ),
    ComponentType.wireTool: ComponentSpec(
      type: ComponentType.wireTool,
      name: '导线',
      category: '连接',
      stage: ComponentStage.mvp,
      role: SimulationRole.conductor,
      ports: <PortSpec>[],
      defaultParams: <String, double>{'ohms': 0},
      teaching: '连接端口并形成节点，电流粒子沿导线显示回路方向。',
    ),
    ComponentType.node: ComponentSpec(
      type: ComponentType.node,
      name: '节点/焊点',
      category: '连接',
      stage: ComponentStage.mvp,
      role: SimulationRole.conductor,
      ports: <PortSpec>[
        PortSpec(id: 'node', name: '节点', localPosition: Offset.zero),
      ],
      defaultParams: <String, double>{},
      teaching: '同一节点等电位，可显示节点电压和网络名称。',
    ),
    ComponentType.openFault: ComponentSpec(
      type: ComponentType.openFault,
      name: '断路点',
      category: '连接',
      stage: ComponentStage.mvp,
      role: SimulationRole.conductor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'enabled': 1},
      teaching: '用于故障教学，断开回路并触发开路诊断。',
    ),
    ComponentType.netLabel: ComponentSpec(
      type: ComponentType.netLabel,
      name: '网络标签',
      category: '连接',
      stage: ComponentStage.advanced,
      role: SimulationRole.conductor,
      ports: <PortSpec>[
        PortSpec(id: 'net', name: 'NET', localPosition: Offset(-40, 0)),
      ],
      defaultParams: <String, double>{},
      teaching: '同名网络标签逻辑连接，简化复杂图纸。',
    ),
    ComponentType.breadboard: ComponentSpec(
      type: ComponentType.breadboard,
      name: '面包板',
      category: '连接',
      stage: ComponentStage.advanced,
      role: SimulationRole.module,
      ports: <PortSpec>[],
      defaultParams: <String, double>{'rows': 30},
      teaching: '按真实面包板孔位规则建图，适合原型搭建课程。',
    ),
    ComponentType.switchSpst: ComponentSpec(
      type: ComponentType.switchSpst,
      name: 'SPST 开关',
      category: '控制',
      stage: ComponentStage.mvp,
      role: SimulationRole.switcher,
      ports: _twoTerminal,
      defaultParams: <String, double>{'closed': 1, 'contactOhms': 0.05},
      teaching: '闭合时近似导线，断开时阻断电流。',
    ),
    ComponentType.pushButtonNo: ComponentSpec(
      type: ComponentType.pushButtonNo,
      name: '按钮 NO',
      category: '控制',
      stage: ComponentStage.mvp,
      role: SimulationRole.switcher,
      ports: _twoTerminal,
      defaultParams: <String, double>{'closed': 0},
      teaching: '常开瞬时按钮，按住才导通。',
    ),
    ComponentType.pushButtonNc: ComponentSpec(
      type: ComponentType.pushButtonNc,
      name: '按钮 NC',
      category: '控制',
      stage: ComponentStage.advanced,
      role: SimulationRole.switcher,
      ports: _twoTerminal,
      defaultParams: <String, double>{'closed': 1},
      teaching: '常闭按钮，按下时断开，可解释安全回路。',
    ),
    ComponentType.switchSpdt: ComponentSpec(
      type: ComponentType.switchSpdt,
      name: 'SPDT 选择开关',
      category: '控制',
      stage: ComponentStage.advanced,
      role: SimulationRole.switcher,
      ports: <PortSpec>[
        PortSpec(id: 'common', name: 'COM', localPosition: Offset(-48, 0)),
        PortSpec(id: 'a', name: 'A', localPosition: Offset(48, -18)),
        PortSpec(id: 'b', name: 'B', localPosition: Offset(48, 18)),
      ],
      defaultParams: <String, double>{'position': 0},
      teaching: '公共端在 A/B 两路之间切换，用于选择电路。',
    ),
    ComponentType.resistor: ComponentSpec(
      type: ComponentType.resistor,
      name: '电阻',
      category: '电阻',
      stage: ComponentStage.mvp,
      role: SimulationRole.resistor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'ohms': 220, 'watts': 0.25, 'tolerance': 5},
      teaching: '线性电阻，用于限流、分压、串并联和功率计算。',
    ),
    ComponentType.variableResistor: ComponentSpec(
      type: ComponentType.variableResistor,
      name: '可变电阻',
      category: '电阻',
      stage: ComponentStage.mvp,
      role: SimulationRole.variableResistor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'ohms': 500, 'maxOhms': 1000},
      teaching: '双端可调电阻，观察阻值变化如何改变电流。',
    ),
    ComponentType.potentiometer: ComponentSpec(
      type: ComponentType.potentiometer,
      name: '电位器',
      category: '电阻',
      stage: ComponentStage.mvp,
      role: SimulationRole.potentiometer,
      ports: <PortSpec>[
        PortSpec(id: 'a', name: 'A', localPosition: Offset(-48, 18)),
        PortSpec(id: 'wiper', name: 'W', localPosition: Offset(0, -32), polarity: PortPolarity.output),
        PortSpec(id: 'b', name: 'B', localPosition: Offset(48, 18)),
      ],
      defaultParams: <String, double>{'ohms': 10000, 'position': 0.5},
      teaching: '三端分压器，用滑臂位置解释模拟输入。',
    ),
    ComponentType.ldr: ComponentSpec(
      type: ComponentType.ldr,
      name: '光敏电阻 LDR',
      category: '电阻',
      stage: ComponentStage.advanced,
      role: SimulationRole.variableResistor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'darkOhms': 100000, 'lightOhms': 1000, 'illumination': 0.5},
      teaching: '光照越强阻值越低，适合自动夜灯实验。',
    ),
    ComponentType.ntc: ComponentSpec(
      type: ComponentType.ntc,
      name: '热敏电阻 NTC',
      category: '电阻',
      stage: ComponentStage.advanced,
      role: SimulationRole.variableResistor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'r25': 10000, 'temperature': 25},
      teaching: '温度升高阻值下降，用于温控课程。',
    ),
    ComponentType.fuse: ComponentSpec(
      type: ComponentType.fuse,
      name: '保险丝',
      category: '保护',
      stage: ComponentStage.advanced,
      role: SimulationRole.switcher,
      ports: _twoTerminal,
      defaultParams: <String, double>{'ratedCurrent': 0.5, 'closed': 1},
      teaching: '过流持续超过阈值后开路，用于短路保护。',
    ),
    ComponentType.capacitor: ComponentSpec(
      type: ComponentType.capacitor,
      name: '普通电容',
      category: '储能',
      stage: ComponentStage.advanced,
      role: SimulationRole.capacitor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'farads': 0.000001, 'initialVoltage': 0},
      teaching: '电压不能突变，适合 RC 充放电和滤波实验。',
    ),
    ComponentType.electrolyticCapacitor: ComponentSpec(
      type: ComponentType.electrolyticCapacitor,
      name: '电解电容',
      category: '储能',
      stage: ComponentStage.advanced,
      role: SimulationRole.capacitor,
      ports: <PortSpec>[
        PortSpec(id: 'positive', name: '+', localPosition: Offset(-48, 0), polarity: PortPolarity.positive),
        PortSpec(id: 'negative', name: '-', localPosition: Offset(48, 0), polarity: PortPolarity.negative),
      ],
      defaultParams: <String, double>{'farads': 0.0001, 'voltageLimit': 16, 'esr': 0.2},
      teaching: '有极性和耐压限制，反接或过压触发警告。',
    ),
    ComponentType.inductor: ComponentSpec(
      type: ComponentType.inductor,
      name: '电感',
      category: '储能',
      stage: ComponentStage.advanced,
      role: SimulationRole.inductor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'henrys': 0.001, 'seriesOhms': 0.2},
      teaching: '电流不能突变，能量存储在磁场中。',
    ),
    ComponentType.bulb: ComponentSpec(
      type: ComponentType.bulb,
      name: '灯泡',
      category: '输出',
      stage: ComponentStage.mvp,
      role: SimulationRole.lamp,
      ports: _twoTerminal,
      defaultParams: <String, double>{'ratedVoltage': 5, 'watts': 0.5},
      teaching: '近似电阻负载，亮度随功率变化。',
    ),
    ComponentType.led: ComponentSpec(
      type: ComponentType.led,
      name: 'LED',
      category: '输出',
      stage: ComponentStage.mvp,
      role: SimulationRole.led,
      ports: <PortSpec>[
        PortSpec(id: 'anode', name: 'A', localPosition: Offset(-52, 0), polarity: PortPolarity.anode),
        PortSpec(id: 'cathode', name: 'K', localPosition: Offset(52, 0), polarity: PortPolarity.cathode),
      ],
      defaultParams: <String, double>{'vf': 2.1, 'maxMilliAmps': 20},
      teaching: '单向导通，必须限流，反接或过流都应解释原因。',
    ),
    ComponentType.rgbLed: ComponentSpec(
      type: ComponentType.rgbLed,
      name: 'RGB LED',
      category: '输出',
      stage: ComponentStage.advanced,
      role: SimulationRole.led,
      ports: <PortSpec>[
        PortSpec(id: 'common', name: 'COM', localPosition: Offset(-48, 0)),
        PortSpec(id: 'r', name: 'R', localPosition: Offset(48, -20)),
        PortSpec(id: 'g', name: 'G', localPosition: Offset(48, 0)),
        PortSpec(id: 'b', name: 'B', localPosition: Offset(48, 20)),
      ],
      defaultParams: <String, double>{'commonAnode': 0, 'maxMilliAmps': 20},
      teaching: '三通道 LED 混色，适合 PWM 调光课程。',
    ),
    ComponentType.buzzer: ComponentSpec(
      type: ComponentType.buzzer,
      name: '蜂鸣器',
      category: '输出',
      stage: ComponentStage.mvp,
      role: SimulationRole.lamp,
      ports: _twoTerminal,
      defaultParams: <String, double>{'ratedVoltage': 5, 'active': 1},
      teaching: '有源通电响，无源需要方波或 PWM。',
    ),
    ComponentType.dcMotor: ComponentSpec(
      type: ComponentType.dcMotor,
      name: '直流电机',
      category: '输出',
      stage: ComponentStage.mvp,
      role: SimulationRole.motor,
      ports: _twoTerminal,
      defaultParams: <String, double>{'ratedVoltage': 5, 'coilOhms': 20, 'kv': 1200},
      teaching: '转速随电压变化，反接反转，堵转时电流升高。',
    ),
    ComponentType.diode: ComponentSpec(
      type: ComponentType.diode,
      name: '普通二极管',
      category: '半导体',
      stage: ComponentStage.mvp,
      role: SimulationRole.diode,
      ports: <PortSpec>[
        PortSpec(id: 'anode', name: 'A', localPosition: Offset(-48, 0), polarity: PortPolarity.anode),
        PortSpec(id: 'cathode', name: 'K', localPosition: Offset(48, 0), polarity: PortPolarity.cathode),
      ],
      defaultParams: <String, double>{'vf': 0.7, 'maxMilliAmps': 100},
      teaching: '单向导电，适合理解整流和保护。',
    ),
    ComponentType.zenerDiode: ComponentSpec(
      type: ComponentType.zenerDiode,
      name: '稳压二极管',
      category: '半导体',
      stage: ComponentStage.advanced,
      role: SimulationRole.diode,
      ports: _twoTerminal,
      defaultParams: <String, double>{'zenerVoltage': 5.1, 'watts': 0.5},
      teaching: '反向击穿后近似稳压，用于钳位和参考电压。',
    ),
    ComponentType.bridgeRectifier: ComponentSpec(
      type: ComponentType.bridgeRectifier,
      name: '整流桥',
      category: '半导体',
      stage: ComponentStage.advanced,
      role: SimulationRole.module,
      ports: <PortSpec>[
        PortSpec(id: 'ac1', name: '~', localPosition: Offset(-48, -18)),
        PortSpec(id: 'ac2', name: '~', localPosition: Offset(-48, 18)),
        PortSpec(id: 'positive', name: '+', localPosition: Offset(48, -18), polarity: PortPolarity.positive),
        PortSpec(id: 'negative', name: '-', localPosition: Offset(48, 18), polarity: PortPolarity.negative),
      ],
      defaultParams: <String, double>{'vf': 1.4},
      teaching: '四个二极管把交流变为单向脉动直流。',
    ),
    ComponentType.transistorNpn: ComponentSpec(
      type: ComponentType.transistorNpn,
      name: 'NPN 三极管',
      category: '半导体',
      stage: ComponentStage.mvp,
      role: SimulationRole.transistor,
      ports: <PortSpec>[
        PortSpec(id: 'collector', name: 'C', localPosition: Offset(42, -24)),
        PortSpec(id: 'base', name: 'B', localPosition: Offset(-48, 0), polarity: PortPolarity.input),
        PortSpec(id: 'emitter', name: 'E', localPosition: Offset(42, 24)),
      ],
      defaultParams: <String, double>{'beta': 100, 'vbe': 0.7, 'maxCurrent': 0.2},
      teaching: '小基极电流控制较大集电极电流，用于低边开关。',
    ),
    ComponentType.mosfetN: ComponentSpec(
      type: ComponentType.mosfetN,
      name: 'N-MOSFET',
      category: '半导体',
      stage: ComponentStage.advanced,
      role: SimulationRole.mosfet,
      ports: <PortSpec>[
        PortSpec(id: 'drain', name: 'D', localPosition: Offset(44, -24)),
        PortSpec(id: 'gate', name: 'G', localPosition: Offset(-48, 0), polarity: PortPolarity.input),
        PortSpec(id: 'source', name: 'S', localPosition: Offset(44, 24)),
      ],
      defaultParams: <String, double>{'vth': 2.5, 'rdsOn': 0.08, 'maxCurrent': 2},
      teaching: '电压控制功率开关，适合电机和 PWM 调速。',
    ),
    ComponentType.voltageProbe: ComponentSpec(
      type: ComponentType.voltageProbe,
      name: '电压探针',
      category: '测量',
      stage: ComponentStage.mvp,
      role: SimulationRole.meter,
      ports: <PortSpec>[
        PortSpec(id: 'probe', name: 'V', localPosition: Offset.zero, kind: PortKind.measurement),
      ],
      defaultParams: <String, double>{'range': 20},
      teaching: '读取节点相对 GND 的电压。',
    ),
    ComponentType.currentProbe: ComponentSpec(
      type: ComponentType.currentProbe,
      name: '电流探针',
      category: '测量',
      stage: ComponentStage.mvp,
      role: SimulationRole.meter,
      ports: _twoTerminal,
      defaultParams: <String, double>{'range': 0.2, 'burdenOhms': 0.05},
      teaching: '串联测量支路电流，误并联会触发教学提示。',
    ),
    ComponentType.multimeter: ComponentSpec(
      type: ComponentType.multimeter,
      name: '万用表',
      category: '测量',
      stage: ComponentStage.mvp,
      role: SimulationRole.meter,
      ports: <PortSpec>[
        PortSpec(id: 'common', name: 'COM', localPosition: Offset(-42, 18), kind: PortKind.measurement),
        PortSpec(id: 'probe', name: 'VΩA', localPosition: Offset(42, 18), kind: PortKind.measurement),
      ],
      defaultParams: <String, double>{'mode': 0},
      teaching: '综合测量工具，包含档位和接法提示。',
    ),
    ComponentType.powerMeter: ComponentSpec(
      type: ComponentType.powerMeter,
      name: '功率计',
      category: '测量',
      stage: ComponentStage.mvp,
      role: SimulationRole.meter,
      ports: <PortSpec>[
        PortSpec(id: 'sense', name: 'W', localPosition: Offset.zero, kind: PortKind.measurement),
      ],
      defaultParams: <String, double>{},
      teaching: '计算 P=VI 或 I²R，显示过载风险。',
    ),
    ComponentType.oscilloscope: ComponentSpec(
      type: ComponentType.oscilloscope,
      name: '示波器',
      category: '测量',
      stage: ComponentStage.advanced,
      role: SimulationRole.meter,
      ports: <PortSpec>[
        PortSpec(id: 'ch1', name: 'CH1', localPosition: Offset(-48, -14), kind: PortKind.measurement),
        PortSpec(id: 'ch2', name: 'CH2', localPosition: Offset(-48, 14), kind: PortKind.measurement),
      ],
      defaultParams: <String, double>{'timebaseMs': 1, 'voltsPerDiv': 1},
      teaching: '采样节点随时间变化的电压，用于交流、PWM 和瞬态。',
    ),
    ComponentType.voltageHeatmap: ComponentSpec(
      type: ComponentType.voltageHeatmap,
      name: '电压热力图',
      category: '测量',
      stage: ComponentStage.mvp,
      role: SimulationRole.visualizer,
      ports: <PortSpec>[],
      defaultParams: <String, double>{},
      teaching: '把节点电压映射为暖/冷色，理解电位差。',
    ),
    ComponentType.currentArrows: ComponentSpec(
      type: ComponentType.currentArrows,
      name: '电流方向箭头',
      category: '测量',
      stage: ComponentStage.mvp,
      role: SimulationRole.visualizer,
      ports: <PortSpec>[],
      defaultParams: <String, double>{'conventional': 1},
      teaching: '在导线上显示电流方向和相对大小。',
    ),
    ComponentType.pwmSource: ComponentSpec(
      type: ComponentType.pwmSource,
      name: '方波/PWM 源',
      category: '信号',
      stage: ComponentStage.advanced,
      role: SimulationRole.voltageSource,
      ports: _twoTerminal,
      defaultParams: <String, double>{'frequency': 1000, 'duty': 0.5, 'highVoltage': 5},
      teaching: '周期高低电平输出，用于调光和调速。',
    ),
    ComponentType.logicAnd: ComponentSpec(
      type: ComponentType.logicAnd,
      name: 'AND 逻辑门',
      category: '数字',
      stage: ComponentStage.advanced,
      role: SimulationRole.digital,
      ports: <PortSpec>[
        PortSpec(id: 'a', name: 'A', localPosition: Offset(-48, -16), kind: PortKind.logic, polarity: PortPolarity.input),
        PortSpec(id: 'b', name: 'B', localPosition: Offset(-48, 16), kind: PortKind.logic, polarity: PortPolarity.input),
        PortSpec(id: 'out', name: 'Y', localPosition: Offset(48, 0), kind: PortKind.logic, polarity: PortPolarity.output),
      ],
      defaultParams: <String, double>{},
      teaching: '布尔逻辑运算，适合组合逻辑入门。',
    ),
    ComponentType.opAmp: ComponentSpec(
      type: ComponentType.opAmp,
      name: '运算放大器',
      category: '集成模块',
      stage: ComponentStage.advanced,
      role: SimulationRole.module,
      ports: <PortSpec>[
        PortSpec(id: 'nonInverting', name: '+', localPosition: Offset(-48, -16), polarity: PortPolarity.input),
        PortSpec(id: 'inverting', name: '-', localPosition: Offset(-48, 16), polarity: PortPolarity.input),
        PortSpec(id: 'out', name: 'OUT', localPosition: Offset(48, 0), polarity: PortPolarity.output),
      ],
      defaultParams: <String, double>{'gain': 100000},
      teaching: '差分输入放大，输出受电源限制，适合反馈教学。',
    ),
    ComponentType.comparator: ComponentSpec(
      type: ComponentType.comparator,
      name: '比较器',
      category: '集成模块',
      stage: ComponentStage.advanced,
      role: SimulationRole.module,
      ports: <PortSpec>[
        PortSpec(id: 'positive', name: '+', localPosition: Offset(-48, -16), polarity: PortPolarity.input),
        PortSpec(id: 'negative', name: '-', localPosition: Offset(-48, 16), polarity: PortPolarity.input),
        PortSpec(id: 'out', name: 'OUT', localPosition: Offset(48, 0), polarity: PortPolarity.output),
      ],
      defaultParams: <String, double>{'hysteresis': 0},
      teaching: '比较两个输入电压并输出高低电平。',
    ),
    ComponentType.timer555: ComponentSpec(
      type: ComponentType.timer555,
      name: '555 定时器',
      category: '集成模块',
      stage: ComponentStage.advanced,
      role: SimulationRole.module,
      ports: <PortSpec>[
        PortSpec(id: 'vcc', name: 'VCC', localPosition: Offset(-48, -24), polarity: PortPolarity.positive),
        PortSpec(id: 'gnd', name: 'GND', localPosition: Offset(-48, 24), polarity: PortPolarity.ground),
        PortSpec(id: 'out', name: 'OUT', localPosition: Offset(48, 0), polarity: PortPolarity.output),
      ],
      defaultParams: <String, double>{'mode': 0},
      teaching: 'RC 定时、振荡和 PWM 课程模块。',
    ),
  };

  static List<ComponentSpec> get library => ComponentType.values.map(specFor).toList(growable: false);

  static ComponentSpec specFor(ComponentType type) {
    final spec = specs[type];
    if (spec == null) {
      throw StateError('Missing component spec for $type');
    }
    return spec;
  }
}

class PortRef {
  const PortRef({required this.componentId, required this.portId});

  final String componentId;
  final String portId;

  factory PortRef.fromJson(Map<String, Object?> json) {
    return PortRef(
      componentId: json['componentId']! as String,
      portId: json['portId']! as String,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'componentId': componentId,
      'portId': portId,
    };
  }

  String get key => '$componentId.$portId';

  @override
  bool operator ==(Object other) {
    return other is PortRef && other.componentId == componentId && other.portId == portId;
  }

  @override
  int get hashCode => Object.hash(componentId, portId);

  @override
  String toString() => key;
}

class PortAnchor {
  const PortAnchor({
    required this.ref,
    required this.component,
    required this.spec,
    required this.position,
  });

  final PortRef ref;
  final CircuitComponent component;
  final PortSpec spec;
  final Offset position;
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

  ComponentSpec get spec => ComponentCatalog.specFor(type);

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

  double param(String name, double fallback) => params[name] ?? spec.defaultParams[name] ?? fallback;

  factory CircuitComponent.fromJson(Map<String, Object?> json) {
    final position = json['position']! as Map<String, Object?>;
    final rawParams = json['params'] as Map<String, Object?>? ?? const <String, Object?>{};
    return CircuitComponent(
      id: json['id']! as String,
      type: ComponentType.values.byName(json['type']! as String),
      position: Offset((position['x']! as num).toDouble(), (position['y']! as num).toDouble()),
      rotation: ((json['rotation'] as num?) ?? 0).toDouble(),
      params: rawParams.map((key, value) => MapEntry(key, (value as num).toDouble())),
      enabled: json['enabled'] as bool? ?? true,
    );
  }

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
    required this.from,
    required this.to,
    this.points = const <Offset>[],
    this.netId,
  });

  final String id;
  final PortRef from;
  final PortRef to;
  final List<Offset> points;
  final String? netId;

  WirePath copyWith({
    String? id,
    PortRef? from,
    PortRef? to,
    List<Offset>? points,
    String? netId,
  }) {
    return WirePath(
      id: id ?? this.id,
      from: from ?? this.from,
      to: to ?? this.to,
      points: points ?? this.points,
      netId: netId ?? this.netId,
    );
  }

  factory WirePath.fromJson(Map<String, Object?> json) {
    final rawPoints = json['points'] as List<Object?>? ?? const <Object?>[];
    return WirePath(
      id: json['id']! as String,
      from: PortRef.fromJson(json['from']! as Map<String, Object?>),
      to: PortRef.fromJson(json['to']! as Map<String, Object?>),
      points: rawPoints.map((raw) {
        final point = raw! as Map<String, Object?>;
        return Offset((point['x']! as num).toDouble(), (point['y']! as num).toDouble());
      }).toList(growable: false),
      netId: json['netId'] as String?,
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'id': id,
      'from': from.toJson(),
      'to': to.toJson(),
      if (netId != null) 'netId': netId,
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
    this.activeLessonId = 'lesson-led-current-limit',
  });

  final String id;
  final String name;
  final int version;
  final List<CircuitComponent> components;
  final List<WirePath> wires;
  final Rect viewport;
  final String activeLessonId;

  factory CircuitProject.seed() {
    return const CircuitProject(
      id: 'lesson-led-current-limit',
      name: 'LED 限流实验',
      version: 2,
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
          id: 'wire-battery-resistor',
          from: PortRef(componentId: 'battery-1', portId: 'positive'),
          to: PortRef(componentId: 'resistor-1', portId: 'a'),
          points: <Offset>[Offset(202, 154)],
        ),
        WirePath(
          id: 'wire-resistor-led',
          from: PortRef(componentId: 'resistor-1', portId: 'b'),
          to: PortRef(componentId: 'led-1', portId: 'anode'),
          points: <Offset>[Offset(470, 154), Offset(470, 328)],
        ),
        WirePath(
          id: 'wire-led-switch',
          from: PortRef(componentId: 'led-1', portId: 'cathode'),
          to: PortRef(componentId: 'switch-1', portId: 'b'),
          points: <Offset>[Offset(572, 365), Offset(166, 365)],
        ),
        WirePath(
          id: 'wire-switch-battery',
          from: PortRef(componentId: 'switch-1', portId: 'a'),
          to: PortRef(componentId: 'battery-1', portId: 'negative'),
          points: <Offset>[Offset(76, 328), Offset(76, 154)],
        ),
        WirePath(
          id: 'wire-ground-reference',
          from: PortRef(componentId: 'ground-1', portId: 'gnd'),
          to: PortRef(componentId: 'battery-1', portId: 'negative'),
          points: <Offset>[Offset(360, 390), Offset(76, 390), Offset(76, 154)],
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
    String? activeLessonId,
  }) {
    return CircuitProject(
      id: id ?? this.id,
      name: name ?? this.name,
      version: version ?? this.version,
      components: components ?? this.components,
      wires: wires ?? this.wires,
      viewport: viewport ?? this.viewport,
      activeLessonId: activeLessonId ?? this.activeLessonId,
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

  PortSpec? portSpec(PortRef ref) {
    return componentById(ref.componentId)?.spec.portById(ref.portId);
  }

  Offset? portPosition(PortRef ref) {
    final component = componentById(ref.componentId);
    if (component == null) {
      return null;
    }
    final port = component.spec.portById(ref.portId);
    if (port == null) {
      return null;
    }
    return component.position + port.localPosition;
  }

  List<PortAnchor> portAnchors() {
    final anchors = <PortAnchor>[];
    for (final component in components) {
      for (final port in component.spec.ports) {
        anchors.add(
          PortAnchor(
            ref: PortRef(componentId: component.id, portId: port.id),
            component: component,
            spec: port,
            position: component.position + port.localPosition,
          ),
        );
      }
    }
    return anchors;
  }

  PortAnchor? nearestPort(Offset position, {double maxDistance = 26}) {
    PortAnchor? nearest;
    var bestDistance = maxDistance;
    for (final anchor in portAnchors()) {
      final distance = (anchor.position - position).distance;
      if (distance <= bestDistance) {
        nearest = anchor;
        bestDistance = distance;
      }
    }
    return nearest;
  }

  List<Offset> resolvedWirePoints(WirePath wire) {
    final fromPosition = portPosition(wire.from);
    final toPosition = portPosition(wire.to);
    if (fromPosition == null || toPosition == null) {
      return const <Offset>[];
    }
    if (wire.points.isNotEmpty) {
      return <Offset>[fromPosition, ...wire.points, toPosition];
    }
    final midX = (fromPosition.dx + toPosition.dx) / 2;
    return <Offset>[
      fromPosition,
      Offset(midX, fromPosition.dy),
      Offset(midX, toPosition.dy),
      toPosition,
    ];
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
    final spec = ComponentCatalog.specFor(type);

    return copyWith(
      components: <CircuitComponent>[
        ...components,
        CircuitComponent(
          id: '${type.name}-$index',
          type: type,
          position: Offset(180 + (index % 6) * 64, 210 + (index % 4) * 52),
          params: spec.defaultParams,
        ),
      ],
    );
  }

  CircuitProject addWire(PortRef from, PortRef to) {
    if (from == to) {
      return this;
    }
    for (final wire in wires) {
      final sameDirection = wire.from == from && wire.to == to;
      final reverseDirection = wire.from == to && wire.to == from;
      if (sameDirection || reverseDirection) {
        return this;
      }
    }
    final fromPosition = portPosition(from);
    final toPosition = portPosition(to);
    final bends = <Offset>[];
    if (fromPosition != null && toPosition != null) {
      final midX = (fromPosition.dx + toPosition.dx) / 2;
      bends.addAll(<Offset>[Offset(midX, fromPosition.dy), Offset(midX, toPosition.dy)]);
    }
    return copyWith(
      wires: <WirePath>[
        ...wires,
        WirePath(
          id: 'wire-${wires.length + 1}',
          from: from,
          to: to,
          points: bends,
        ),
      ],
    );
  }

  factory CircuitProject.fromJson(Map<String, Object?> json) {
    final viewport = json['viewport']! as Map<String, Object?>;
    final rawComponents = json['components']! as List<Object?>;
    final rawWires = json['wires']! as List<Object?>;
    return CircuitProject(
      id: json['id']! as String,
      name: json['name']! as String,
      version: (json['version']! as num).toInt(),
      activeLessonId: json['activeLessonId'] as String? ?? 'lesson-led-current-limit',
      viewport: Rect.fromLTWH(
        (viewport['left']! as num).toDouble(),
        (viewport['top']! as num).toDouble(),
        (viewport['width']! as num).toDouble(),
        (viewport['height']! as num).toDouble(),
      ),
      components: rawComponents
          .map((raw) => CircuitComponent.fromJson(raw! as Map<String, Object?>))
          .toList(growable: false),
      wires: rawWires.map((raw) => WirePath.fromJson(raw! as Map<String, Object?>)).toList(growable: false),
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schema': 'vanilla.circuit.project',
      'id': id,
      'name': name,
      'version': version,
      'activeLessonId': activeLessonId,
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
