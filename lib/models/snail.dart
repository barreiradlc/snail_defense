import 'dart:ui';

enum SnailState { moving, dying, dead }

class Snail {
  // Position along the path (0.0 = start, 1.0 = end)
  double pathProgress;
  double speed; // progress units per second
  SnailState state;
  double dyingTimer;
  static const dyingDuration = 0.5;

  // Current screen position (computed from path)
  Offset screenPos;

  // Crying effect: position where eye is targeting
  double cryTimer; // remaining cry time for visual effect

  // Screen-space movement direction (updated each frame by the controller)
  Offset velocity = Offset.zero;

  Snail({
    required this.pathProgress,
    required this.speed,
    required this.screenPos,
  })  : state = SnailState.moving,
        dyingTimer = 0.0,
        cryTimer = 0.0;

  bool get isDead => state == SnailState.dead;
  bool get isDying => state == SnailState.dying;
  bool get isAlive => state == SnailState.moving;

  void kill() {
    if (state == SnailState.moving) {
      state = SnailState.dying;
      dyingTimer = dyingDuration;
    }
  }
}
