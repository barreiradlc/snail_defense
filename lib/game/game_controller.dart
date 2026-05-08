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
  bool waveTransitioning = false;

  double _spawnTimer = 0.0;
  double _spawnInterval = 3.0;
  int _snailsToSpawn = 0;
  int _snailsSpawned = 0;

  // The selected weapon type to place
  WeaponType selectedWeapon = WeaponType.saltGun;

  // Offset for rendering origin
  Offset renderOrigin = Offset.zero;
  Offset _prevRenderOrigin = Offset.zero;

  // Per-eye tracking: which snail each eye is chasing
  final Map<Weapon, Snail> _eyeTargets = {};
  final Map<Weapon, double> _eyeHoverTimers = {};
  final Map<Weapon, Offset> _eyeWanderTargets = {};

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

    // Shift floating eye positions when renderOrigin changes (camera pan)
    final originDelta = renderOrigin - _prevRenderOrigin;
    if (originDelta.distance > 0.01) {
      for (final w in weapons) {
        if (w.type == WeaponType.cryingEye && w.eyePos != null) {
          w.eyePos = w.eyePos! + originDelta;
        }
      }
      _prevRenderOrigin = renderOrigin;
    }

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

    SnailType type = SnailType.normal;
    final r = Random().nextDouble();
    if (wave >= 6) {
      if (r < 0.30)      type = SnailType.golden;
      else if (r < 0.70) type = SnailType.silver;
    } else if (wave >= 4) {
      if (r < 0.20)      type = SnailType.golden;
      else if (r < 0.50) type = SnailType.silver;
    } else if (wave >= 2) {
      if (r < 0.30)      type = SnailType.silver;
    }

    SnailTrait trait = SnailTrait.none;
    if (wave >= 3) {
      final t = Random().nextDouble();
      final chance = wave >= 5 ? 0.25 : 0.15;
      if (t < chance)           trait = SnailTrait.armored;
      else if (t < chance * 2)  trait = SnailTrait.runner;
      else if (t < chance * 3)  trait = SnailTrait.sheltered;
    }

    snails.add(Snail(
      pathProgress: 0.0,
      speed: speed,
      screenPos: screen,
      snailType: type,
      trait: trait,
    ));
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
        // Track movement direction so the painter can flip the sprite
        final vel = posB - posA;
        if (vel.distance > 0.01) snail.velocity = vel;
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
          _trackGunTarget(weapon);
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
    for (final w in toRemove) {
      _eyeTargets.remove(w);
      _eyeHoverTimers.remove(w);
      _eyeWanderTargets.remove(w);
    }
    weapons.removeWhere((w) => toRemove.contains(w));
  }

  void _processCryingEye(Weapon eye, double dt) {
    final pathLen = map.spawnPath.length - 1;
    if (pathLen <= 0) return;

    // Home tile centre in screen space
    final homeScreen = IsometricMap.gridToScreen(eye.col, eye.row, renderOrigin);
    final home = homeScreen +
        const Offset(IsometricMap.tileWidth / 2, IsometricMap.tileHeight / 2);
    eye.eyePos ??= home;

    // Find eye's nearest path index for range
    int eyeIdx = -1;
    for (int i = 0; i < map.spawnPath.length; i++) {
      if (map.spawnPath[i][0] == eye.col && map.spawnPath[i][1] == eye.row) {
        eyeIdx = i;
        break;
      }
    }
    if (eyeIdx < 0) {
      double best = double.infinity;
      for (int i = 0; i < map.spawnPath.length; i++) {
        final s = IsometricMap.gridToScreen(
            map.spawnPath[i][0], map.spawnPath[i][1], renderOrigin);
        if ((s - home).distance < best) {
          best = (s - home).distance;
          eyeIdx = i;
        }
      }
    }
    final eyeT = eyeIdx / pathLen;
    const window = 3.0;
    final rangeWindow = window / pathLen;

    // Drop target if dead or out of range
    Snail? target = _eyeTargets[eye];
    if (target != null &&
        (!target.isAlive ||
            (target.pathProgress - eyeT).abs() > rangeWindow)) {
      target = null;
      _eyeTargets.remove(eye);
      _eyeHoverTimers.remove(eye);
    }

    // Snails already claimed by another eye
    final claimedSnails = _eyeTargets.entries
        .where((e) => e.key != eye)
        .map((e) => e.value)
        .toSet();

    // Acquire new target
    if (target == null) {
      target = snails
          .where((s) =>
              s.isAlive &&
              !s.immuneToEye &&
              !claimedSnails.contains(s) &&
              (s.pathProgress - eyeT).abs() <= rangeWindow)
          .fold<Snail?>(null, (best, s) =>
              best == null || s.pathProgress > best.pathProgress ? s : best);
      if (target != null) {
        _eyeTargets[eye] = target;
        final initialDist = max((eye.eyePos! - _snailAbovePos(target)).distance, 1.0);
        final pathDist = (target.pathProgress - eyeT).abs() * pathLen;
        eye.eyeLockDuration = (1.0 + pathDist / window * 2.0).clamp(1.0, 3.0);
        eye.eyeLockDistance = initialDist;
        // Speed ensures eye arrives in ~eyeLockDuration seconds
        eye.eyeSpeed = initialDist / eye.eyeLockDuration * 1.2; // 1.2× to catch moving snail
        eye.eyeLockProgress = 0.0;
      }
    }

    if (target == null) {
      // Wander slowly around home
      _wanderEye(eye, home, dt);
      eye.aimTarget = null;
      return;
    }

    // Move toward above-center of the snail
    final toTarget = _snailAbovePos(target) - eye.eyePos!;
    final dist = toTarget.distance;
    if (dist > 1.0) {
      final step = min(eye.eyeSpeed * dt, dist);
      eye.eyePos = eye.eyePos! + toTarget / dist * step;
    }

    // Lock progress advances as distance shrinks (never goes backwards)
    final newProg = (1.0 - dist / eye.eyeLockDistance).clamp(0.0, 1.0);
    eye.eyeLockProgress = max(eye.eyeLockProgress, newProg);

    eye.aimTarget = null; // not used for eye drawing

    // Slow effect
    target.cryTimer = 0.4;
    target.speed = max(target.speed - 0.006 * dt, 0.005);

    // Kill on contact
    if (dist < 16.0) {
      target.kill();
      score += target.scoreValue;
      _eyeTargets.remove(eye);
      _eyeHoverTimers.remove(eye);
      eye.eyeLockProgress = 1.0;
    }
  }

  /// Screen position just above the snail's visual centre.
  Offset _snailAbovePos(Snail snail) => snail.screenPos +
      const Offset(IsometricMap.tileWidth / 2, IsometricMap.tileHeight / 2 - 20);

  void _wanderEye(Weapon eye, Offset home, double dt) {
    final wTarget = _eyeWanderTargets[eye] ?? home;
    if ((wTarget - eye.eyePos!).distance < 6.0) {
      final rand = Random();
      final angle = rand.nextDouble() * 2 * pi;
      final radius = 8.0 + rand.nextDouble() * 16.0;
      _eyeWanderTargets[eye] = home +
          Offset(cos(angle) * radius, sin(angle) * radius * 0.5);
    } else {
      _eyeWanderTargets[eye] = wTarget;
    }
    final toWander = (_eyeWanderTargets[eye]! - eye.eyePos!);
    const wanderSpeed = 22.0;
    if (toWander.distance > 0.1) {
      final step = min(wanderSpeed * dt, toWander.distance);
      eye.eyePos = eye.eyePos! + toWander / toWander.distance * step;
    }
    eye.eyeLockProgress = 1.0;
  }

  /// Finds the closest living snail within range and stores its screen centre
  /// in [gun.aimTarget] so the painter can rotate the barrel toward it.
  void _trackGunTarget(Weapon gun) {
    final gunScreen = IsometricMap.gridToScreen(gun.col, gun.row, renderOrigin);
    Snail? target;
    double minDist = double.infinity;
    for (final snail in snails) {
      if (!snail.isAlive || snail.immuneToGun) continue;
      final d = (snail.screenPos - gunScreen).distance;
      if (d < minDist) {
        minDist = d;
        target = snail;
      }
    }
    gun.aimTarget = (target != null && minDist <= 200)
        ? target.screenPos +
            const Offset(IsometricMap.tileWidth / 2, IsometricMap.tileHeight / 2)
        : null;
  }

  void _fireGun(Weapon gun) {
    if (gun.aimTarget == null) return;
    final gunScreen = IsometricMap.gridToScreen(gun.col, gun.row, renderOrigin);
    final dir = gun.aimTarget! - gunScreen;
    if (dir.distance < 1) return;
    final norm = dir / dir.distance;
    projectiles.add(SaltProjectile(
      position: gunScreen,
      velocity: norm * 180,
    ));
  }

  void _processTrap(Weapon trap) {
    if (trap.trapKillsRemaining <= 0) return;

    // Find where this trap sits on the path (by grid coords)
    final pathLen = map.spawnPath.length - 1;
    int trapIdx = -1;
    for (int i = 0; i < map.spawnPath.length; i++) {
      if (map.spawnPath[i][0] == trap.col && map.spawnPath[i][1] == trap.row) {
        trapIdx = i;
        break;
      }
    }
    if (trapIdx < 0 || pathLen <= 0) return;

    // Progress value that corresponds to the trap tile
    final trapT = trapIdx / pathLen;
    // Window = 1 tile's worth of progress on either side
    final window = 1.0 / pathLen;

    for (final snail in snails) {
      if (!snail.isAlive) continue;
      if (snail.immuneToTrap) continue;
      if ((snail.pathProgress - trapT).abs() <= window) {
        snail.kill();
        score += snail.scoreValue;
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
          if (snail.immuneToGun) {
            // Projectile deflected – passes through without damage
            break;
          }
          final wasAlive = snail.isAlive;
          snail.damage(1);
          if (wasAlive && !snail.isAlive) score += snail.scoreValue;
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
    if (!waveTransitioning && _snailsSpawned >= _snailsToSpawn && snails.isEmpty) {
      wave++;
      score += 50;
      lettuceHp = min(lettuceHp + 1, 5); // restore 1 HP per wave
      // Grow the map by one column or row
      map.grow();
      waveTransitioning = true;
      notifyListeners();
    }
  }

  /// Called by the UI after the wave transition animation completes.
  void beginWave() {
    waveTransitioning = false;
    _startWave();
    notifyListeners();
  }

  /// Called when user taps on a grid tile to place a weapon
  void placeWeapon(int col, int row) {
    if (status != GameStatus.playing) return;

    if (selectedWeapon == WeaponType.saltTrap) {
      // Snap to the nearest path tile so inverse-isometric rounding can't miss
      List<int>? nearest;
      double nearestDist = double.infinity;
      for (final wp in map.spawnPath) {
        final d = ((wp[0] - col) * (wp[0] - col) + (wp[1] - row) * (wp[1] - row)).toDouble();
        if (d < nearestDist) {
          nearestDist = d;
          nearest = wp;
        }
      }
      if (nearest == null) return;
      col = nearest[0];
      row = nearest[1];
    } else {
      // Guns / eye go on non-path tiles only
      final isPath = map.spawnPath.any((wp) => wp[0] == col && wp[1] == row);
      if (isPath) return;
    }

    // Don't stack
    final exists = weapons.any((w) => w.col == col && w.row == row);
    if (exists) return;

    weapons.add(Weapon(type: selectedWeapon, col: col, row: row));
    notifyListeners();
  }
}
