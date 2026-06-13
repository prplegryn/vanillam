import 'package:flutter/material.dart';

import '../domain/circuit_models.dart';
import '../domain/simulation.dart';
import '../i18n/strings.dart';
import 'circuit_painter.dart';

class WorkbenchPage extends StatefulWidget {
  const WorkbenchPage({super.key});

  @override
  State<WorkbenchPage> createState() => _WorkbenchPageState();
}

class _WorkbenchPageState extends State<WorkbenchPage> with SingleTickerProviderStateMixin {
  final _simulator = const CircuitSimulator();
  late AnimationController _animation;
  late CircuitProject _project;
  bool _running = true;
  bool _showParticles = true;
  bool _showHeatmap = true;
  String? _selectedId = 'led-1';
  String _componentFilter = '';
  String? _draggingId;

  SimulationSnapshot get _snapshot => _simulator.solve(_project, running: _running);

  @override
  void initState() {
    super.initState();
    _project = CircuitProject.seed();
    _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat();
  }

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            final content = wide ? _wideLayout(snapshot) : _phoneLayout(snapshot);
            return Semantics(
              label: '${Strings.appName} 电路学习工作台',
              child: content,
            );
          },
        ),
      ),
    );
  }

  Widget _phoneLayout(SimulationSnapshot snapshot) {
    return Column(
      children: <Widget>[
        _TopToolbar(
          running: _running,
          hasDiagnosticIssue: snapshot.hasError || snapshot.hasWarning,
          onToggleRun: _toggleRun,
          onDiagnostics: () => _showDiagnosticsSheet(snapshot),
          onLesson: _showLessonSheet,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
            child: _canvasShell(snapshot: snapshot),
          ),
        ),
        _SelectedComponentPanel(
          component: _selectedComponent,
          snapshot: snapshot,
          onChanged: _updateSelectedComponent,
        ),
        _ComponentDrawer(
          filter: _componentFilter,
          onFilterChanged: (value) => setState(() => _componentFilter = value),
          onAdd: _addComponent,
        ),
      ],
    );
  }

  Widget _wideLayout(SimulationSnapshot snapshot) {
    return Column(
      children: <Widget>[
        _TopToolbar(
          running: _running,
          hasDiagnosticIssue: snapshot.hasError || snapshot.hasWarning,
          onToggleRun: _toggleRun,
          onDiagnostics: () => _showDiagnosticsSheet(snapshot),
          onLesson: _showLessonSheet,
        ),
        Expanded(
          child: Row(
            children: <Widget>[
              SizedBox(
                width: 260,
                child: _ComponentDrawer(
                  filter: _componentFilter,
                  onFilterChanged: (value) => setState(() => _componentFilter = value),
                  onAdd: _addComponent,
                  compact: false,
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 16),
                  child: _canvasShell(snapshot: snapshot),
                ),
              ),
              SizedBox(
                width: 320,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 8, 16, 16),
                  child: _SelectedComponentPanel(
                    component: _selectedComponent,
                    snapshot: snapshot,
                    onChanged: _updateSelectedComponent,
                    expanded: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _canvasShell({required SimulationSnapshot snapshot}) {
    return Material(
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFC9D8EA)),
      ),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.65,
              maxScale: 2.6,
              boundaryMargin: const EdgeInsets.all(160),
              panEnabled: _draggingId == null,
              child: SizedBox(
                width: _project.viewport.width,
                height: _project.viewport.height,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) => _selectNearest(details.localPosition),
                  onPanStart: (details) => _startDrag(details.localPosition),
                  onPanUpdate: (details) => _updateDrag(details.delta),
                  onPanEnd: (_) => setState(() => _draggingId = null),
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: CircuitScenePainter(
                          project: _project,
                          snapshot: snapshot,
                          selectedId: _selectedId,
                          animationValue: _animation.value,
                          showParticles: _showParticles,
                          showHeatmap: _showHeatmap,
                        ),
                        child: const SizedBox.expand(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: _LiveHint(snapshot: snapshot),
          ),
          Positioned(
            top: 14,
            right: 14,
            child: _CanvasToggles(
              showParticles: _showParticles,
              showHeatmap: _showHeatmap,
              onParticlesChanged: (value) => setState(() => _showParticles = value),
              onHeatmapChanged: (value) => setState(() => _showHeatmap = value),
            ),
          ),
        ],
      ),
    );
  }

  CircuitComponent? get _selectedComponent {
    final id = _selectedId;
    return id == null ? null : _project.componentById(id);
  }

  void _toggleRun() {
    setState(() => _running = !_running);
  }

  void _selectNearest(Offset localPosition) {
    CircuitComponent? nearest;
    var nearestDistance = double.infinity;
    for (final component in _project.components) {
      final distance = (component.position - localPosition).distance;
      if (distance < nearestDistance && distance <= 72) {
        nearest = component;
        nearestDistance = distance;
      }
    }
    setState(() => _selectedId = nearest?.id);
  }

  void _startDrag(Offset localPosition) {
    CircuitComponent? nearest;
    var nearestDistance = double.infinity;
    for (final component in _project.components) {
      final distance = (component.position - localPosition).distance;
      if (distance < nearestDistance && distance <= 56) {
        nearest = component;
        nearestDistance = distance;
      }
    }
    if (nearest != null) {
      setState(() {
        _selectedId = nearest!.id;
        _draggingId = nearest.id;
      });
    }
  }

  void _updateDrag(Offset delta) {
    final id = _draggingId;
    if (id == null) {
      return;
    }
    final component = _project.componentById(id);
    if (component == null) {
      return;
    }
    final snapped = _snap(component.position + delta);
    setState(() => _project = _project.replaceComponent(component.copyWith(position: snapped)));
  }

  Offset _snap(Offset position) {
    const step = 7.0;
    return Offset((position.dx / step).round() * step, (position.dy / step).round() * step);
  }

  void _addComponent(ComponentType type) {
    setState(() {
      _project = _project.addComponent(type);
      _selectedId = _project.components.last.id;
    });
  }

  void _updateSelectedComponent(CircuitComponent component) {
    setState(() => _project = _project.replaceComponent(component));
  }

  void _showDiagnosticsSheet(SimulationSnapshot snapshot) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            shrinkWrap: true,
            children: <Widget>[
              const Text('实时诊断', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              for (final diagnostic in snapshot.diagnostics)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    diagnostic.isError
                        ? Icons.error_outline
                        : diagnostic.isWarning
                            ? Icons.warning_amber_rounded
                            : Icons.check_circle_outline,
                    color: diagnostic.isError
                        ? Theme.of(context).colorScheme.error
                        : diagnostic.isWarning
                            ? const Color(0xFFB26A00)
                            : const Color(0xFF1B7F45),
                  ),
                  title: Text(diagnostic.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(diagnostic.description),
                ),
              const SizedBox(height: 8),
              const Text(Strings.teachingDisclaimer, style: TextStyle(color: Color(0xFF52657F))),
            ],
          ),
        );
      },
    );
  }

  void _showLessonSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return const SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(Strings.lessonTitle, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                SizedBox(height: 10),
                Text(Strings.lessonGoal),
                SizedBox(height: 14),
                _LessonStep(index: 1, text: '确认电池、开关、电阻和 LED 组成闭合回路。'),
                _LessonStep(index: 2, text: '运行仿真，观察导线上的电流粒子方向。'),
                _LessonStep(index: 3, text: '调整电阻，让 LED 电流保持在 20 mA 以下。'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopToolbar extends StatelessWidget {
  const _TopToolbar({
    required this.running,
    required this.hasDiagnosticIssue,
    required this.onToggleRun,
    required this.onDiagnostics,
    required this.onLesson,
  });

  final bool running;
  final bool hasDiagnosticIssue;
  final VoidCallback onToggleRun;
  final VoidCallback onDiagnostics;
  final VoidCallback onLesson;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Container(
              height: 44,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE5ECF6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Text(
                Strings.projectTitle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF11243F)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ToolbarButton(label: '撤销', icon: Icons.undo, onPressed: () {}),
          _ToolbarButton(label: '重做', icon: Icons.redo, onPressed: () {}),
          _ToolbarButton(
            label: running ? '暂停' : '运行',
            icon: running ? Icons.pause_rounded : Icons.play_arrow_rounded,
            onPressed: onToggleRun,
            filled: true,
          ),
          _ToolbarButton(
            label: '诊断',
            icon: hasDiagnosticIssue ? Icons.report_problem_outlined : Icons.rule_rounded,
            onPressed: onDiagnostics,
            warn: hasDiagnosticIssue,
          ),
          _ToolbarButton(label: '课程', icon: Icons.school_outlined, onPressed: onLesson),
        ],
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.filled = false,
    this.warn = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool filled;
  final bool warn;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final child = Icon(icon, size: 21);
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Tooltip(
        message: label,
        child: SizedBox.square(
          dimension: 44,
          child: filled
              ? FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                  child: child,
                )
              : OutlinedButton(
                  onPressed: onPressed,
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: warn ? colorScheme.error : const Color(0xFF24405F),
                    side: BorderSide(color: warn ? colorScheme.error : const Color(0xFFC9D8EA)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

class _ComponentDrawer extends StatelessWidget {
  const _ComponentDrawer({
    required this.filter,
    required this.onFilterChanged,
    required this.onAdd,
    this.compact = true,
  });

  final String filter;
  final ValueChanged<String> onFilterChanged;
  final ValueChanged<ComponentType> onAdd;
  final bool compact;

  static const _items = <ComponentType>[
    ComponentType.battery,
    ComponentType.ground,
    ComponentType.wireTool,
    ComponentType.switchSpst,
    ComponentType.resistor,
    ComponentType.led,
    ComponentType.bulb,
    ComponentType.voltageProbe,
    ComponentType.currentProbe,
  ];

  @override
  Widget build(BuildContext context) {
    final query = filter.trim().toLowerCase();
    final items = _items.where((item) {
      return query.isEmpty || item.label.toLowerCase().contains(query) || item.category.toLowerCase().contains(query);
    }).toList(growable: false);

    return Material(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: compact ? const BorderRadius.vertical(top: Radius.circular(24)) : BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFC9D8EA)),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, compact ? 12 : 16, 16, 16),
        child: Column(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Expanded(
                  child: Text('元件抽屉', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                ),
                Text('${items.length} 项', style: const TextStyle(color: Color(0xFF52657F))),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              minLines: 1,
              onChanged: onFilterChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: '搜索元件或分类',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
            const SizedBox(height: 12),
            if (compact)
              SizedBox(
                height: 98,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => _ComponentTile(type: items[index], onAdd: onAdd),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) => _ComponentTile(type: items[index], onAdd: onAdd, wide: true),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ComponentTile extends StatelessWidget {
  const _ComponentTile({required this.type, required this.onAdd, this.wide = false});

  final ComponentType type;
  final ValueChanged<ComponentType> onAdd;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '添加${type.label}',
      child: SizedBox(
        width: wide ? double.infinity : 112,
        height: wide ? 74 : 96,
        child: OutlinedButton(
          onPressed: () => onAdd(type),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            side: const BorderSide(color: Color(0xFFC9D8EA)),
            foregroundColor: const Color(0xFF11243F),
          ),
          child: Row(
            mainAxisAlignment: wide ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: <Widget>[
              Icon(_iconFor(type), size: 24),
              SizedBox(width: wide ? 12 : 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: <Widget>[
                    Text(type.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(type.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF52657F))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconFor(ComponentType type) {
    switch (type) {
      case ComponentType.battery:
        return Icons.battery_charging_full_rounded;
      case ComponentType.ground:
        return Icons.vertical_align_bottom_rounded;
      case ComponentType.wireTool:
        return Icons.timeline_rounded;
      case ComponentType.switchSpst:
        return Icons.toggle_on_rounded;
      case ComponentType.resistor:
        return Icons.ssid_chart_rounded;
      case ComponentType.led:
        return Icons.lightbulb_outline_rounded;
      case ComponentType.bulb:
        return Icons.light_mode_outlined;
      case ComponentType.voltageProbe:
        return Icons.speed_rounded;
      case ComponentType.currentProbe:
        return Icons.electric_bolt_rounded;
    }
  }
}

class _SelectedComponentPanel extends StatelessWidget {
  const _SelectedComponentPanel({
    required this.component,
    required this.snapshot,
    required this.onChanged,
    this.expanded = false,
  });

  final CircuitComponent? component;
  final SimulationSnapshot snapshot;
  final ValueChanged<CircuitComponent> onChanged;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final component = this.component;
    if (component == null) {
      return const SizedBox.shrink();
    }
    final content = _contentFor(context, component);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      constraints: expanded ? const BoxConstraints.expand() : const BoxConstraints(maxHeight: 188),
      margin: EdgeInsets.fromLTRB(expanded ? 0 : 14, 0, expanded ? 0 : 14, expanded ? 0 : 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFC9D8EA)),
      ),
      child: expanded
          ? content
          : SingleChildScrollView(
              child: content,
            ),
    );
  }

  Widget _contentFor(BuildContext context, CircuitComponent component) {
    return Column(
      mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${component.type.label}参数卡片',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ),
            if (component.type == ComponentType.switchSpst)
              Switch(
                value: component.enabled,
                onChanged: (value) => onChanged(component.copyWith(enabled: value)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        _explanationFor(component),
        const SizedBox(height: 12),
        ..._controlsFor(component),
      ],
    );
  }

  Widget _explanationFor(CircuitComponent component) {
    switch (component.type) {
      case ComponentType.battery:
        return const _Explanation(
          what: '提供固定直流电压。',
          state: '正端建立较高电位，负端作为回路返回点。',
          why: '电位差推动电荷在闭合回路中形成电流。',
        );
      case ComponentType.resistor:
        return _Explanation(
          what: '限制电流并消耗功率。',
          state: '当前电流约 ${snapshot.currentMilliAmps.toStringAsFixed(1)} mA。',
          why: '欧姆定律 I=(V-Vf)/R，增大 R 会降低 LED 电流。',
        );
      case ComponentType.led:
        return _Explanation(
          what: '单向导通并把电能转成光。',
          state: snapshot.ledLit ? 'LED 正向导通，亮度随电流变化。' : 'LED 没有达到明显导通条件。',
          why: 'LED 需要正向压降和限流电阻，反接或过流都会触发诊断。',
        );
      case ComponentType.switchSpst:
        return _Explanation(
          what: '控制回路通断。',
          state: component.enabled ? '触点闭合，回路可以通过电流。' : '触点断开，回路没有持续电流。',
          why: '只有闭合回路才能让电源、负载和导线形成完整路径。',
        );
      default:
        return const _Explanation(
          what: '用于搭建或观察电路。',
          state: '点击画布元件可切换参数卡片。',
          why: '测量和连接工具帮助理解节点、电流和回路。',
        );
    }
  }

  List<Widget> _controlsFor(CircuitComponent component) {
    switch (component.type) {
      case ComponentType.battery:
        return <Widget>[
          _NumberSlider(
            label: '电压',
            value: component.param('voltage', 5),
            min: 1.5,
            max: 12,
            divisions: 21,
            unit: 'V',
            onChanged: (value) => onChanged(component.copyWith(params: <String, double>{...component.params, 'voltage': value})),
          ),
        ];
      case ComponentType.resistor:
        return <Widget>[
          _NumberSlider(
            label: '阻值',
            value: component.param('ohms', 220),
            min: 10,
            max: 1000,
            divisions: 99,
            unit: 'Ω',
            onChanged: (value) => onChanged(component.copyWith(params: <String, double>{...component.params, 'ohms': value})),
          ),
        ];
      case ComponentType.led:
        return <Widget>[
          _NumberSlider(
            label: '正向压降',
            value: component.param('vf', 2.1),
            min: 1.6,
            max: 3.4,
            divisions: 18,
            unit: 'V',
            onChanged: (value) => onChanged(component.copyWith(params: <String, double>{...component.params, 'vf': value})),
          ),
        ];
      default:
        return const <Widget>[];
    }
  }
}

class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700))),
            Text('${value.toStringAsFixed(unit == 'Ω' ? 0 : 1)} $unit'),
          ],
        ),
        Slider(
          value: value.clamp(min, max).toDouble(),
          min: min,
          max: max,
          divisions: divisions,
          label: '${value.toStringAsFixed(unit == 'Ω' ? 0 : 1)} $unit',
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.what, required this.state, required this.why});

  final String what;
  final String state;
  final String why;

  @override
  Widget build(BuildContext context) {
    const labelStyle = TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF1F5EFF));
    const bodyStyle = TextStyle(fontSize: 13.5, height: 1.35, color: Color(0xFF24405F));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text('是什么', style: labelStyle),
        Text(what, style: bodyStyle),
        const SizedBox(height: 4),
        const Text('发生了什么', style: labelStyle),
        Text(state, style: bodyStyle),
        const SizedBox(height: 4),
        const Text('为什么这样', style: labelStyle),
        Text(why, style: bodyStyle),
      ],
    );
  }
}

class _LiveHint extends StatelessWidget {
  const _LiveHint({required this.snapshot});

  final SimulationSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final diagnostic = snapshot.diagnostics.first;
    final color = diagnostic.isError
        ? Theme.of(context).colorScheme.error
        : diagnostic.isWarning
            ? const Color(0xFFB26A00)
            : const Color(0xFF1F5EFF);
    return Material(
      color: Colors.white.withValues(alpha: 0.94),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: <Widget>[
            Icon(
              diagnostic.isError
                  ? Icons.error_outline
                  : diagnostic.isWarning
                      ? Icons.warning_amber_rounded
                      : Icons.tips_and_updates_outlined,
              color: color,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${diagnostic.title}：${diagnostic.description}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: color, fontWeight: FontWeight.w700, height: 1.28),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CanvasToggles extends StatelessWidget {
  const _CanvasToggles({
    required this.showParticles,
    required this.showHeatmap,
    required this.onParticlesChanged,
    required this.onHeatmapChanged,
  });

  final bool showParticles;
  final bool showHeatmap;
  final ValueChanged<bool> onParticlesChanged;
  final ValueChanged<bool> onHeatmapChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.96),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFFC9D8EA))),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Tooltip(
              message: '电流粒子',
              child: IconButton(
                isSelected: showParticles,
                onPressed: () => onParticlesChanged(!showParticles),
                icon: const Icon(Icons.electric_bolt_outlined),
                selectedIcon: const Icon(Icons.electric_bolt_rounded),
              ),
            ),
            Tooltip(
              message: '电压热力图',
              child: IconButton(
                isSelected: showHeatmap,
                onPressed: () => onHeatmapChanged(!showHeatmap),
                icon: const Icon(Icons.thermostat_outlined),
                selectedIcon: const Icon(Icons.thermostat),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonStep extends StatelessWidget {
  const _LessonStep({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CircleAvatar(
            radius: 13,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text('$index', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
