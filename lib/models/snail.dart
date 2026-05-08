import 'dart:ui';

enum SnailState { moving, dying, dead }

enum SnailType { normal, silver, golden }

/// Extra accessory / immunity class independent of HP tier.
enum SnailTrait {
  none,
  armored,   // helmet  – immune to salt cannons
  runner,    // feet    – immune to salt traps
  sheltered, // umbrella – immune to the crying eye
}

class Snail {
  final SnailType snailType;
  final SnailTrait trait;

  bool get immuneToGun     => trait == SnailTrait.armored;
  bool get immuneToTrap    => trait == SnailTrait.runner;
  bool get immuneToEye     => trait == SnailTrait.sheltered;

  int get maxHp {
    switch (snailType) {
      case SnailType.normal: return 1;
      case SnailType.silver: return 5;
      case SnailType.golden: return 10;
    }
  }

  int get scoreValue {
    switch (snailType) {
      case SnailType.normal: return 10;
      case SnailType.silver: return 20;
      case SnailType.golden: return 40;
    }
  }

  late int hp;

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
    this.snailType = SnailType.normal,
    this.trait = SnailTrait.none,
  })  : state = SnailState.moving,
        dyingTimer = 0.0,
        cryTimer = 0.0 {
    hp = maxHp;
  }

  bool get isDead => state == SnailState.dead;
  bool get isDying => state == SnailState.dying;
  bool get isAlive => state == SnailState.moving;

  void kill() {
    if (state == SnailState.moving) {
      hp = 0;
      state = SnailState.dying;
      dyingTimer = dyingDuration;
    }
  }

  void damage(int amount) {
    if (!isAlive) return;
    hp -= amount;
    if (hp <= 0) kill();
  }
}
