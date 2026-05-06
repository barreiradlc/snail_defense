import 'dart:math';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import '../models/iso_map.dart';
import '../models/snail.dart';
import '../models/weapon.dart';

enum GameStatus { playing, victory, defeat }

class GameController extends ChangeNotifier {
  final IsometricMap map;
  final List<Snail> snails = [];
  final List<Weapon> weapons = [];
  final List<SaltProjectile> projectiles = [];

  GameStatus status = GameStatus.playing;
  int wave = 1;
  int score = 0;
  int lettuceHp = 5;

  double _spawnTimer = 0.0;
  double _spawnInterval = 3.0;
  int _snailsToSpawn = 0;
  int _snailsSpawned = 0;

  // The selected weapon type to place
  WeaponType selectedWeapon = WeaponType.saltGun;

  // Offset for rendering origin
  late Offset renderOrigin;

  GameController({required this.map}) {
    _startWave();
  }

  void _startWave() {
    _snailsToSpawn = 5 + (wave - 1) * 3;
    _snailsSpawned = 0;
    _spawnInterval = max(0.8, 3.0 - (wave - 1) * 0.3);
    _spawnTimer = 0.0;
  }

  void update(double dt) {
    if (status != GameStatus.playing) return;

    _handleSpawning(dt);
    _updateSnails(dt);
    _updateWeapons(dt);
    _updateProjectiles(dt);
    _checkWaveComplete();
  }

  void _handleSpawning(double dt) {
    if (_snailsSpawned >= _snailsToSpawn) return;
    _spawnTimer -= dt;
    if (_spawnTimer <= 0) {
      _spawnTimer = _spawnInterval;
      _spawnSnail();
      _snailsSpawned++;
    }
  }

  void _spawnSnail() {
    final speed = 0.04 + Random().nextDouble() * 0.02;
    final spawnPos = map.spawnPosition;
    final screen = IsometricMap.gridToScreen(
      spawnPos[0],
      spawnPos[1],
      renderOrigin,
    );
    snails.add(Snail(pathProgress: 0.0, speed: speed, screenPos: screen));
  }

  void _updateSnails(double dt) {
    final pathLen = map.spawnPath.length - 1;

    for (final snail in snails) {
      if (snail.isDying) {
        snail.dyingTimer -= dt;
        if (snail.dyingTimer <= 0) snail.state = SnailState.dead;
        continue;
      }
      if (!snail.isAlive) continue;

      snail.cryTimer = max(0, snail.cryTimer - dt);
      snail.pathProgress += snail.speed * dt;

      // Update screen position via path interpolation
      if (pathLen > 0) {
        final t = snail.pathProgress.clamp(0.0, 1.0);
        final exactIdx = t * pathLen;
        final idxA = exactIdx.floor().clamp(0, pathLen - 1);
        final idxB = (idxA + 1).clamp(0, pathLen);
        final frac = exactIdx - idxA;
        final wpA = map.spawnPath[idxA];
        final wpB = map.spawnPath[idxB.clamp(0, pathLen)];
        final posA = IsometricMap.gridToScreen(wpA[0], wpA[1], renderOrigin);
        final posB = IsometricMap.gridToScreen(wpB[0], wpB[1], renderOrigin);
        snail.screenPos = Offset(
          lerpDouble(posA.dx, posB.dx, frac)!,
          lerpDouble(posA.dy, posB.dy, frac)!,
        );
      }

      // Reached lettuce
      if (snail.pathProgress >= 1.0) {
        snail.state = SnailState.dead;
        lettuceHp--;
        if (lettuceHp <= 0) {
          status = GameStatus.defeat;
          notifyListeners();
          return;
        }
      }
    }

    snails.removeWhere((s) => s.isDead);
  }

  void _updateWeapons(double dt) {
    final toRemove = <Weapon>[];

    for (final weapon in weapons) {
      if (weapon.isExpired) {
        toRemove.add(weapon);
        continue;
      }

      switch (weapon.type) {
        case WeaponType.cryingEye:
          weapon.eyeTimeRemaining -= dt;
          _processCryingEye(weapon, dt);
          break;
        case WeaponType.saltGun:
          weapon.gunCooldown -= dt;
          if (weapon.gunCooldown <= 0) {
            _fireGun(weapon);
            weapon.gunCooldown = Weapon.gunFireRate;
          }
          break;
        case WeaponType.saltTrap:
          _processTrap(weapon);
          break;
      }
    }
    weapons.removeWhere((w) => toRemove.contains(w));
  }

  void _processCryingEye(Weapon eye, double dt) {
    final eyeScreen = IsometricMap.gridToScreen(eye.col, eye.row, renderOrigin);
    const range = 120.0;
    for (final snail in snails) {
      if (!snail.isAlive) continue;
      final dist = (snail.screenPos - eyeScreen).distance;
      if (dist <= range) {
        snail.cryTimer = 0.3; // visual sob effect
        snail.speed = max(snail.speed - 0.005 * dt, 0.01); // slow snail with tears
        // Actually kill if eye is directly on snail tile
        if (dist < 20) {
          snail.kill();
          score += 10;
        }
      }
    }
  }

  void _fireGun(Weapon gun) {
    final gunScreen = IsometricMap.gridToScreen(gun.col, gun.row, renderOrigin);
    // Find closest snail
    Snail? target;
    double minDist = double.infinity;
    for (final snail in snails) {
      if (!snail.isAlive) continue;
      final d = (snail.screenPos - gunScreen).distance;
      if (d < minDist) {
        minDist = d;
        target = snail;
      }
    }
    if (target == null || minDist > 200) return;
    final dir = (target.screenPos - gunScreen);
    final norm = dir / dir.distance;
    projectiles.add(SaltProjectile(
      position: gunScreen,
      velocity: norm * 180,
    ));
  }

  void _processTrap(Weapon trap) {
    if (trap.trapKillsRemaining <= 0) return;
    final trapScreen =
        IsometricMap.gridToScreen(trap.col, trap.row, renderOrigin);
    for (final snail in snails) {
      if (!snail.isAlive) continue;
      final dist = (snail.screenPos - trapScreen).distance;
      if (dist < 24) {
        snail.kill();
        score += 10;
        trap.trapKillsRemaining--;
        if (trap.trapKillsRemaining <= 0) break;
      }
    }
  }

  void _updateProjectiles(double dt) {
    for (final p in projectiles) {
      if (!p.active) continue;
      p.position = p.position + p.velocity * dt;

      // Check hit
      for (final snail in snails) {
        if (!snail.isAlive) continue;
        final dist = (snail.screenPos - p.position).distance;
        if (dist < 16) {
          snail.kill();
          score += 10;
          p.active = false;
          break;
        }
      }

      // Remove if off screen (simple bounds)
      if (p.position.dx < -200 ||
          p.position.dx > 2000 ||
          p.position.dy < -200 ||
          p.position.dy > 2000) {
        p.active = false;
      }
    }
    projectiles.removeWhere((p) => !p.active);
  }

  void _checkWaveComplete() {
    if (_snailsSpawned >= _snailsToSpawn && snails.isEmpty) {
      if (wave >= 5) {
        status = GameStatus.victory;
      } else {
        wave++;
        score += 50;
        lettuceHp = min(lettuceHp + 1, 5); // restore 1 HP per wave
        _startWave();
      }
      notifyListeners();
    }
  }

  /// Called when user taps on a grid tile to place a weapon
  void placeWeapon(int col, int row) {
    if (status != GameStatus.playing) return;
    // Don't place on path or lettuce
    final isPath =
        map.spawnPath.any((wp) => wp[0] == col && wp[1] == row);
    if (isPath) return;
    // Don't stack
    final exists = weapons.any((w) => w.col == col && w.row == row);
    if (exists) return;

    weapons.add(Weapon(type: selectedWeapon, col: col, row: row));
    notifyListeners();
  }
}
