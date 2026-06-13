import 'circuit_models.dart';
import 'simulation.dart';

class LessonCheck {
  const LessonCheck({
    required this.id,
    required this.title,
    required this.description,
    required this.passed,
  });

  final String id;
  final String title;
  final String description;
  final bool passed;
}

class LessonProgress {
  const LessonProgress({
    required this.lessonId,
    required this.title,
    required this.goal,
    required this.checks,
  });

  final String lessonId;
  final String title;
  final String goal;
  final List<LessonCheck> checks;

  bool get completed => checks.isNotEmpty && checks.every((check) => check.passed);
  int get passedCount => checks.where((check) => check.passed).length;
}

class LessonValidator {
  const LessonValidator._();

  static LessonProgress validate(CircuitProject project, SimulationSnapshot snapshot) {
    switch (project.activeLessonId) {
      case 'lesson-led-current-limit':
      default:
        return _ledCurrentLimit(project, snapshot);
    }
  }

  static LessonProgress _ledCurrentLimit(CircuitProject project, SimulationSnapshot snapshot) {
    final hasBattery = project.components.any((component) => component.type == ComponentType.battery);
    final hasResistor = project.components.any((component) => component.type == ComponentType.resistor);
    final hasLed = project.components.any((component) => component.type == ComponentType.led);
    final hasGround = project.components.any((component) => component.type == ComponentType.ground);

    return LessonProgress(
      lessonId: 'lesson-led-current-limit',
      title: '入门 2：LED 限流',
      goal: '让 LED 正常点亮，并把电流控制在安全范围。',
      checks: <LessonCheck>[
        LessonCheck(
          id: 'required-components',
          title: '放置必要元件',
          description: '电池、电阻、LED 和 GND 都已在画布上。',
          passed: hasBattery && hasResistor && hasLed && hasGround,
        ),
        LessonCheck(
          id: 'closed-loop',
          title: '形成闭合回路',
          description: '端口和导线把电源正端、负载和返回路径连成完整路径。',
          passed: snapshot.loopClosed,
        ),
        LessonCheck(
          id: 'led-lit',
          title: 'LED 正常点亮',
          description: 'LED 有正向电流，亮度由仿真电流驱动。',
          passed: snapshot.ledLit,
        ),
        LessonCheck(
          id: 'safe-current',
          title: '电流低于安全阈值',
          description: 'LED 电流小于或等于 20 mA，没有过流诊断。',
          passed: snapshot.ledLit && snapshot.currentMilliAmps <= 20 && !snapshot.hasError,
        ),
      ],
    );
  }
}
