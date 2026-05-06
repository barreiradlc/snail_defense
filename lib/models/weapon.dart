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
