import 'dart:ui';

enum WeaponType { saltGun, saltTrap, cryingEye }

class Weapon {
  final WeaponType type;
  final int col;
  final int row;

  // Salt trap: kills up to 5 snails
  int trapKillsRemaining;

  // Crying eye: 15s duration
  double eyeTimeRemaining;
  bool get eyeExpired => type == WeaponType.cryingEye && eyeTimeRemaining <= 0;

  // Salt gun: shoots projectiles periodically
  double gunCooldown;
  static const gunFireRate = 1.5; // seconds between shots

  // Tracked snail screen position for aiming (updated every frame)
  Offset? aimTarget;

  // Eye lock-on progress: 0 = just acquired, 1 = fully locked
  double eyeLockProgress = 1.0;

  // Eye lock-on duration in seconds (1–3 s, set when target is acquired)
  double eyeLockDuration = 1.8;

  // Initial distance to target when lock started (for progress calculation)
  double eyeLockDistance = 1.0;

  // Eye floating screen position (null = not yet initialised)
  Offset? eyePos;

  // Eye movement speed in screen px/s (set at acquisition)
  double eyeSpeed = 0.0;

  Weapon({
    required this.type,
    required this.col,
    required this.row,
  })  : trapKillsRemaining = 5,
        eyeTimeRemaining = 15.0,
        gunCooldown = 0.0;

  String get label {
    switch (type) {
      case WeaponType.saltGun:
        return 'Arma de Sal';
      case WeaponType.saltTrap:
        return 'Armadilha de Sal';
      case WeaponType.cryingEye:
        return 'Olho Chorão';
    }
  }

  bool get isExpired {
    if (type == WeaponType.saltTrap) return trapKillsRemaining <= 0;
    if (type == WeaponType.cryingEye) return eyeTimeRemaining <= 0;
    return false;
  }
}

class SaltProjectile {
  Offset position;
  final Offset velocity;
  bool active;

  SaltProjectile({required this.position, required this.velocity})
      : active = true;
}
