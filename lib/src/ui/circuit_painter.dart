import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../domain/circuit_models.dart';
import '../domain/simulation.dart';

class CircuitScenePainter extends CustomPainter {
  const CircuitScenePainter({
    required this.project,
    required this.snapshot,
    required this.selectedId,
    required this.pendingPort,
    required this.animationValue,
    required this.showParticles,
    required this.showHeatmap,
  });

  final CircuitProject project;
  final SimulationSnapshot snapshot;
  final String? selectedId;
  final PortRef? pendingPort;
  final double animationValue;
  final bool showParticles;
  final bool showHeatmap;

  static const _grid = 28.0;
  static const _wireColor = Color(0xFF2446A6);
  static const _ink = Color(0xFF11243F);
  static const _mutedInk = Color(0xFF52657F);
  static const _danger = Color(0xFFE53935);

  @override
  void paint(Canvas canvas, Size size) {
    _paintBackgroundGrid(canvas, size);
    if (showHeatmap && snapshot.running) {
      _paintVoltageHeatmap(canvas);
    }
    _paintWires(canvas);
    _paintComponents(canvas);
    _paintMeasurementLabels(canvas);
    if (showParticles && snapshot.loopClosed && snapshot.currentAmps > 0) {
      _paintCurrentParticles(canvas);
    }
    _paintInteractionLayer(canvas);
  }

  // Layer 0: static grid and workbench coordinates.
  void _paintBackgroundGrid(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFF8FBFF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(22)),
      background,
    );

    final minor = Paint()
      ..color = const Color(0xFFDDE7F5)
      ..strokeWidth = 1;
    final major = Paint()
      ..color = const Color(0xFFC8D8EC)
      ..strokeWidth = 1.2;

    for (double x = 0; x <= size.width; x += _grid) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), x % (_grid * 4) == 0 ? major : minor);
    }
    for (double y = 0; y <= size.height; y += _grid) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), y % (_grid * 4) == 0 ? major : minor);
    }
  }

  // Layer 2: state overlay. Kept separate from structure so it can be refreshed independently.
  void _paintVoltageHeatmap(Canvas canvas) {
    final battery = _component(ComponentType.battery);
    final ground = _component(ComponentType.ground);
    if (battery == null || ground == null) {
      return;
    }

    final highPaint = Paint()
      ..shader = ui.Gradient.radial(
        battery.position,
        150,
        <Color>[const Color(0x40FF7043), const Color(0x00FF7043)],
      );
    final lowPaint = Paint()
      ..shader = ui.Gradient.radial(
        ground.position,
        150,
        <Color>[const Color(0x403E8BFF), const Color(0x003E8BFF)],
      );

    canvas.drawCircle(battery.position, 150, highPaint);
    canvas.drawCircle(ground.position, 150, lowPaint);
  }

  // Layer 1: circuit topology.
  void _paintWires(Canvas canvas) {
    final wirePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 5
      ..color = snapshot.hasError ? _danger : _wireColor;

    final shadow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 8
      ..color = const Color(0x172446A6);

    for (final wire in project.wires) {
      final points = project.resolvedWirePoints(wire);
      if (points.length < 2) {
        continue;
      }
      final path = _pathFor(points);
      canvas.drawPath(path, shadow);
      canvas.drawPath(path, wirePaint);
    }
  }

  void _paintComponents(Canvas canvas) {
    for (final component in project.components) {
      switch (component.type) {
        case ComponentType.battery:
          _paintBattery(canvas, component);
        case ComponentType.ground:
          _paintGround(canvas, component);
        case ComponentType.switchSpst:
        case ComponentType.pushButtonNo:
        case ComponentType.pushButtonNc:
          _paintSwitch(canvas, component);
        case ComponentType.resistor:
        case ComponentType.variableResistor:
        case ComponentType.ldr:
        case ComponentType.ntc:
          _paintResistor(canvas, component);
        case ComponentType.led:
          _paintLed(canvas, component);
        case ComponentType.bulb:
          _paintBulb(canvas, component);
        case ComponentType.voltageProbe:
          _paintProbe(canvas, component, 'V');
        case ComponentType.currentProbe:
          _paintProbe(canvas, component, 'A');
        default:
          _paintGenericComponent(canvas, component);
      }
    }
  }

  void _paintBattery(Canvas canvas, CircuitComponent component) {
    final rect = Rect.fromCenter(center: component.position, width: 78, height: 48);
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFFF4242);

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), fill);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(12)), stroke);
    _drawText(
      canvas,
      '+${component.param('voltage', 5).toStringAsFixed(0)}V',
      component.position,
      color: const Color(0xFFC62828),
      weight: FontWeight.w800,
      size: 16,
      align: TextAlign.center,
    );
    _drawTerminalDots(
      canvas,
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    );
  }

  void _paintGround(Canvas canvas, CircuitComponent component) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = _mutedInk;
    final c = component.position;
    canvas.drawLine(c.translate(0, -18), c.translate(0, -3), p);
    canvas.drawLine(c.translate(-25, -3), c.translate(25, -3), p);
    canvas.drawLine(c.translate(-17, 8), c.translate(17, 8), p);
    canvas.drawLine(c.translate(-9, 19), c.translate(9, 19), p);
    _drawText(canvas, '0V', c.translate(0, 39), color: _mutedInk, size: 13, align: TextAlign.center);
  }

  void _paintSwitch(Canvas canvas, CircuitComponent component) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..color = component.enabled ? _wireColor : _mutedInk;
    final c = component.position;
    final left = c.translate(-48, 0);
    final right = c.translate(48, 0);
    canvas.drawCircle(left, 6, Paint()..color = _wireColor);
    canvas.drawCircle(right, 6, Paint()..color = _wireColor);
    canvas.drawLine(left, component.enabled ? right : c.translate(18, -27), p);
    _drawText(
      canvas,
      component.enabled ? 'ON' : 'OFF',
      c.translate(0, 28),
      color: component.enabled ? _wireColor : _mutedInk,
      weight: FontWeight.w700,
      size: 12,
      align: TextAlign.center,
    );
  }

  void _paintResistor(Canvas canvas, CircuitComponent component) {
    final rect = Rect.fromCenter(center: component.position, width: 92, height: 46);
    final body = Paint()..color = const Color(0xFFFFF6EC);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = const Color(0xFFE36C0A);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(13)), body);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(13)), stroke);
    _drawText(canvas, 'R', component.position.translate(0, -2), color: const Color(0xFF9A4300), weight: FontWeight.w800, size: 24, align: TextAlign.center);
    _drawText(
      canvas,
      '${component.param('ohms', 220).toStringAsFixed(0)} Ω',
      component.position.translate(0, 33),
      color: _mutedInk,
      size: 12,
      align: TextAlign.center,
    );
    _drawTerminalDots(
      canvas,
      Offset(rect.left, rect.center.dy),
      Offset(rect.right, rect.center.dy),
    );
  }

  void _paintLed(Canvas canvas, CircuitComponent component) {
    final c = component.position;
    if (snapshot.ledLit) {
      final glow = Paint()
        ..shader = ui.Gradient.radial(
          c,
          64,
          <Color>[const Color(0x55FF3D45), const Color(0x00FF3D45)],
        );
      canvas.drawCircle(c, 64, glow);
    }

    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = snapshot.hasError ? _danger : const Color(0xFFE53935);
    final fill = Paint()..color = snapshot.ledLit ? const Color(0xFFFF6F75) : const Color(0xFFFFE9EA);

    final path = Path()
      ..moveTo(c.dx - 30, c.dy - 28)
      ..lineTo(c.dx - 30, c.dy + 28)
      ..lineTo(c.dx + 18, c.dy)
      ..close();
    canvas.drawPath(path, fill);
    canvas.drawPath(path, p);
    canvas.drawLine(c.translate(23, -32), c.translate(23, 32), p);
    canvas.drawLine(c.translate(-50, 0), c.translate(-30, 0), p);
    canvas.drawLine(c.translate(23, 0), c.translate(50, 0), p);

    final rayPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = snapshot.ledLit ? const Color(0xFFFF3D45) : const Color(0x99E53935);
    canvas.drawLine(c.translate(46, -38), c.translate(67, -59), rayPaint);
    canvas.drawLine(c.translate(62, -24), c.translate(84, -44), rayPaint);
    _drawText(canvas, 'LED', c.translate(0, 48), color: _mutedInk, size: 12, align: TextAlign.center);
  }

  void _paintBulb(Canvas canvas, CircuitComponent component) {
    final c = component.position;
    if (snapshot.bulbLit) {
      canvas.drawCircle(
        c,
        56,
        Paint()
          ..shader = ui.Gradient.radial(
            c,
            56,
            <Color>[const Color(0x66FFC857), const Color(0x00FFC857)],
          ),
      );
    }
    final glass = Paint()..color = snapshot.bulbLit ? const Color(0xFFFFF1B8) : const Color(0xFFFFFFFF);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = const Color(0xFF9A6A00);
    canvas.drawCircle(c, 30, glass);
    canvas.drawCircle(c, 30, stroke);
    canvas.drawArc(Rect.fromCenter(center: c, width: 34, height: 20), math.pi, math.pi, false, stroke);
    _drawText(canvas, '灯泡', c.translate(0, 47), color: _mutedInk, size: 12, align: TextAlign.center);
  }

  void _paintProbe(Canvas canvas, CircuitComponent component, String label) {
    final c = component.position;
    final fill = Paint()..color = const Color(0xFFFFFFFF);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xFF1F5EFF);
    canvas.drawCircle(c, 22, fill);
    canvas.drawCircle(c, 22, stroke);
    _drawText(canvas, label, c.translate(0, -1), color: const Color(0xFF1F5EFF), weight: FontWeight.w800, size: 17, align: TextAlign.center);
  }

  void _paintGenericComponent(Canvas canvas, CircuitComponent component) {
    if (component.type == ComponentType.wireTool ||
        component.type == ComponentType.voltageHeatmap ||
        component.type == ComponentType.currentArrows) {
      return;
    }
    final rect = Rect.fromCenter(center: component.position, width: 96, height: 56);
    final roleColor = _roleColor(component.spec.role);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()..color = roleColor.withValues(alpha: 0.09),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(14)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = roleColor,
    );
    _drawText(
      canvas,
      component.type.label,
      component.position,
      color: _ink,
      weight: FontWeight.w800,
      size: 13,
      align: TextAlign.center,
    );
    for (final port in component.spec.ports) {
      _drawPort(canvas, component.position + port.localPosition);
    }
  }

  void _paintMeasurementLabels(Canvas canvas) {
    if (!snapshot.running) {
      return;
    }
    final led = _component(ComponentType.led);
    final resistor = _component(ComponentType.resistor);
    if (led != null) {
      _paintValueBubble(
        canvas,
        led.position.translate(6, 76),
        '${snapshot.currentMilliAmps.toStringAsFixed(1)} mA',
        snapshot.hasError ? _danger : const Color(0xFF1F5EFF),
      );
    }
    if (resistor != null) {
      _paintValueBubble(
        canvas,
        resistor.position.translate(0, -50),
        '${(snapshot.resistorPowerWatts * 1000).toStringAsFixed(0)} mW',
        const Color(0xFF9A4300),
      );
    }
  }

  void _paintValueBubble(Canvas canvas, Offset center, String text, Color color) {
    final tp = _textPainter(text, color: color, size: 12, weight: FontWeight.w700);
    final rect = Rect.fromCenter(center: center, width: tp.width + 24, height: 32);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()..color = Colors.white.withValues(alpha: 0.94),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.38),
    );
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }

  // Layer 3: animated state. It can be turned off without changing topology.
  void _paintCurrentParticles(Canvas canvas) {
    final particlePaint = Paint()..color = snapshot.hasError ? const Color(0xFFFFCDD2) : const Color(0xFFFFC857);
    final count = (snapshot.currentMilliAmps / 3).clamp(3, 10).round();
    for (final wire in project.wires) {
      final points = project.resolvedWirePoints(wire);
      for (var i = 0; i < count; i++) {
        final t = (animationValue + i / count) % 1;
        final pos = _pointAlongPolyline(points, t);
        canvas.drawCircle(pos, 4.2, particlePaint);
      }
    }
  }

  // Layer 4: interaction aids, selection, and snap/port affordances.
  void _paintInteractionLayer(Canvas canvas) {
    final selected = selectedId == null ? null : project.componentById(selectedId!);
    if (selected != null) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1F5EFF);
      final rect = Rect.fromCenter(center: selected.position, width: 122, height: 92);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(18)), paint);
      for (final port in selected.spec.ports) {
        _drawPort(canvas, selected.position + port.localPosition);
      }
    }

    final pending = pendingPort == null ? null : project.portPosition(pendingPort!);
    if (pending != null) {
      canvas.drawCircle(pending, 14, Paint()..color = const Color(0x331F5EFF));
      canvas.drawCircle(
        pending,
        14,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const Color(0xFF1F5EFF),
      );
    }
  }

  void _drawTerminalDots(Canvas canvas, Offset a, Offset b) {
    _drawPort(canvas, a);
    _drawPort(canvas, b);
  }

  void _drawPort(Canvas canvas, Offset p) {
    canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
    canvas.drawCircle(
      p,
      5.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF1F5EFF),
    );
  }

  Path _pathFor(List<Offset> points) {
    final path = Path();
    if (points.isEmpty) {
      return path;
    }
    path.moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  Offset _pointAlongPolyline(List<Offset> points, double t) {
    if (points.length < 2) {
      return points.isEmpty ? Offset.zero : points.first;
    }
    final lengths = <double>[];
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      final length = (points[i + 1] - points[i]).distance;
      lengths.add(length);
      total += length;
    }
    var target = total * t;
    for (var i = 0; i < lengths.length; i++) {
      if (target <= lengths[i]) {
        final localT = lengths[i] == 0 ? 0.0 : target / lengths[i];
        return Offset.lerp(points[i], points[i + 1], localT) ?? points[i];
      }
      target -= lengths[i];
    }
    return points.last;
  }

  CircuitComponent? _component(ComponentType type) {
    for (final component in project.components) {
      if (component.type == type) {
        return component;
      }
    }
    return null;
  }

  Color _roleColor(SimulationRole role) {
    switch (role) {
      case SimulationRole.voltageSource:
      case SimulationRole.currentSource:
        return const Color(0xFFE53935);
      case SimulationRole.resistor:
      case SimulationRole.variableResistor:
      case SimulationRole.potentiometer:
        return const Color(0xFFE36C0A);
      case SimulationRole.led:
      case SimulationRole.lamp:
      case SimulationRole.motor:
        return const Color(0xFF1B7F45);
      case SimulationRole.meter:
      case SimulationRole.visualizer:
        return const Color(0xFF1F5EFF);
      case SimulationRole.digital:
      case SimulationRole.module:
      case SimulationRole.transistor:
      case SimulationRole.mosfet:
        return const Color(0xFF6F42C1);
      case SimulationRole.conductor:
      case SimulationRole.reference:
      case SimulationRole.switcher:
      case SimulationRole.capacitor:
      case SimulationRole.inductor:
      case SimulationRole.diode:
        return const Color(0xFF52657F);
    }
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset position, {
    Color color = _ink,
    FontWeight weight = FontWeight.w600,
    double size = 14,
    TextAlign align = TextAlign.left,
  }) {
    final painter = _textPainter(text, color: color, weight: weight, size: size, align: align);
    painter.paint(canvas, Offset(position.dx - painter.width / 2, position.dy - painter.height / 2));
  }

  TextPainter _textPainter(
    String text, {
    required Color color,
    FontWeight weight = FontWeight.w500,
    double size = 14,
    TextAlign align = TextAlign.left,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          height: 1.1,
          fontWeight: weight,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
  }

  @override
  bool shouldRepaint(covariant CircuitScenePainter oldDelegate) {
    return oldDelegate.project != project ||
        oldDelegate.snapshot != snapshot ||
        oldDelegate.selectedId != selectedId ||
        oldDelegate.pendingPort != pendingPort ||
        oldDelegate.animationValue != animationValue ||
        oldDelegate.showParticles != showParticles ||
        oldDelegate.showHeatmap != showHeatmap;
  }
}
