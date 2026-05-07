import 'dart:math';
import 'package:flutter/material.dart';
import '../models/iso_map.dart';
import '../models/snail.dart';
import '../models/weapon.dart';
import 'game_controller.dart';

class GamePainter extends CustomPainter {
  final GameController controller;
  final double time;

  GamePainter({required this.controller, required this.time});

  // ── Low-poly polygon helper ──────────────────────────────────
  void _poly(Canvas canvas, List<Offset> pts, Color color) {
    if (pts.length < 2) return;
    final path = Path()..moveTo(pts[0].dx, pts[0].dy);
    for (int i = 1; i < pts.length; i++) {
      path.lineTo(pts[i].dx, pts[i].dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final map = controller.map;
    final origin = controller.renderOrigin;

    _drawTiles(canvas, map, origin);
    _drawWeapons(canvas, origin);
    _drawProjectiles(canvas);
    _drawSnails(canvas);
    _drawLettuce(canvas, map, origin);
  }

  // ═══════════════════════════════════════════════════════════════
  // TERRAIN TILES
  // ═══════════════════════════════════════════════════════════════

  void _drawTiles(Canvas canvas, IsometricMap map, Offset origin) {
    for (int r = 0; r < map.rows; r++) {
      for (int c = 0; c < map.cols; c++) {
        final tile = map.tiles[r][c];
        final pos = IsometricMap.gridToScreen(c, r, origin);
        _drawTile(canvas, pos, tile.type, c, r);
      }
    }
  }

  void _drawTile(
      Canvas canvas, Offset topCenter, TileType type, int col, int row) {
    final w = IsometricMap.tileWidth;
    final h = IsometricMap.tileHeight;
    final cx = topCenter.dx + w / 2;
    final cy = topCenter.dy + h / 2;
    const depth = 8.0;

    // Diamond vertices
    final vTop    = Offset(cx,       topCenter.dy);
    final vRight  = Offset(cx + w/2, cy);
    final vBottom = Offset(cx,       topCenter.dy + h);
    final vLeft   = Offset(cx - w/2, cy);
    // Side-face bottom vertices
    final vBotL   = Offset(cx - w/2, cy + depth);
    final vBotC   = Offset(cx,       topCenter.dy + h + depth);
    final vBotR   = Offset(cx + w/2, cy + depth);

    Color topCol, leftCol, rightCol;
    switch (type) {
      case TileType.grass:
        topCol   = const Color(0xFF5D9E35);
        leftCol  = const Color(0xFF3D7220);
        rightCol = const Color(0xFF4A8A28);
        break;
      case TileType.dirt:
        topCol   = const Color(0xFFC4933A);
        leftCol  = const Color(0xFF8A6020);
        rightCol = const Color(0xFFA07030);
        break;
      case TileType.path:
        topCol   = const Color(0xFFD4B97A);
        leftCol  = const Color(0xFF9A7A40);
        rightCol = const Color(0xFFB09050);
        break;
      case TileType.water:
        final wave = (sin(time * 2.0 + col * 0.5 + row * 0.3) + 1) / 2;
        topCol   = Color.lerp(const Color(0xFF3A80B4), const Color(0xFF5AAAD4), wave)!;
        leftCol  = const Color(0xFF2A6090);
        rightCol = const Color(0xFF3A78B0);
        break;
    }

    // Top face
    _poly(canvas, [vTop, vRight, vBottom, vLeft], topCol);
    // Left face
    _poly(canvas, [vLeft, vBottom, vBotC, vBotL], leftCol);
    // Right face
    _poly(canvas, [vRight, vBotR, vBotC, vBottom], rightCol);

    // Surface decorations
    switch (type) {
      case TileType.grass:
        _decorGrass(canvas, cx, topCenter.dy, col, row);
        break;
      case TileType.dirt:
        _decorDirt(canvas, cx, topCenter.dy, col, row);
        break;
      case TileType.path:
        _decorPath(canvas, cx, cy);
        break;
      case TileType.water:
        _decorWater(canvas, cx, cy, col, row);
        break;
    }

    // Subtle outline on top diamond
    final outline = Path()
      ..moveTo(vTop.dx, vTop.dy)
      ..lineTo(vRight.dx, vRight.dy)
      ..lineTo(vBottom.dx, vBottom.dy)
      ..lineTo(vLeft.dx, vLeft.dy)
      ..close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = Colors.black.withAlpha(20)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _decorGrass(
      Canvas canvas, double cx, double topY, int col, int row) {
    final rand = Random(col * 31 + row * 17);
    for (int i = 0; i < 3; i++) {
      final bx = cx + (rand.nextDouble() - 0.5) * 22;
      final by = topY + 7 + rand.nextDouble() * 13;
      final bh = 3.5 + rand.nextDouble() * 3.5;
      _poly(canvas, [
        Offset(bx,     by - bh),
        Offset(bx + 2, by),
        Offset(bx - 2, by),
      ], const Color(0xFF6EC236));
    }
  }

  void _decorDirt(
      Canvas canvas, double cx, double topY, int col, int row) {
    final rand = Random(col * 23 + row * 41);
    for (int i = 0; i < 2; i++) {
      final px = cx + (rand.nextDouble() - 0.5) * 20;
      final py = topY + 8 + rand.nextDouble() * 12;
      final ps = 2.5 + rand.nextDouble() * 2;
      _poly(canvas, [
        Offset(px,      py - ps * 0.7),
        Offset(px + ps, py),
        Offset(px,      py + ps * 0.45),
        Offset(px - ps, py),
      ], const Color(0xFFB07A35));
    }
  }

  void _decorPath(Canvas canvas, double cx, double cy) {
    // Two isometric stone slabs side-by-side
    _poly(canvas, [
      Offset(cx - 14, cy - 2),
      Offset(cx -  2, cy - 6),
      Offset(cx -  2, cy + 2),
      Offset(cx - 14, cy + 3),
    ], const Color(0xFFBCA87A));
    _poly(canvas, [
      Offset(cx +  2, cy - 6),
      Offset(cx + 14, cy - 2),
      Offset(cx + 14, cy + 3),
      Offset(cx +  2, cy + 2),
    ], const Color(0xFFC8B480));
    // Grout line between slabs
    canvas.drawLine(
      Offset(cx, cy - 7),
      Offset(cx, cy + 4),
      Paint()
        ..color = const Color(0xFF9A8050)
        ..strokeWidth = 1.5,
    );
  }

  void _decorWater(Canvas canvas, double cx, double cy, int col, int row) {
    final w = sin(time * 2.5 + col * 0.7 + row * 0.4) * 2;
    _poly(canvas, [
      Offset(cx - 12, cy + w),
      Offset(cx -  6, cy - 3 + w),
      Offset(cx,      cy + w),
    ], const Color(0xFF7AC4E8).withValues(alpha: 0.55));
    _poly(canvas, [
      Offset(cx +  2, cy + 1 + w),
      Offset(cx +  8, cy - 2 + w),
      Offset(cx + 14, cy + 1 + w),
    ], const Color(0xFF7AC4E8).withValues(alpha: 0.45));
  }

  // ═══════════════════════════════════════════════════════════════
  // SNAILS
  // ═══════════════════════════════════════════════════════════════

  void _drawSnails(Canvas canvas) {
    for (final snail in controller.snails) {
      _drawSnail(canvas, snail);
    }
  }

  void _drawSnail(Canvas canvas, Snail snail) {
    final pos = snail.screenPos;
    final cx = pos.dx + IsometricMap.tileWidth  / 2;
    final cy = pos.dy + IsometricMap.tileHeight / 2;

    final a = snail.isDying
        ? snail.dyingTimer / Snail.dyingDuration
        : 1.0;

    // The sprite faces LEFT by default. Flip it when moving right (dx > 0).
    final flipX = snail.velocity.dx > 0 ? -1.0 : 1.0;

    // Shadow is symmetric – draw it in world space before the transform
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 7), width: 30, height: 9),
      Paint()..color = Colors.black.withValues(alpha: 0.22 * a),
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(flipX, 1.0);

    // ── Body (low-poly trapezoid forms) ──
    _poly(canvas, [
      const Offset(-10, 4), const Offset(8, 3),
      const Offset(8, 7),   const Offset(-10, 7),
    ], const Color(0xFFA07030).withValues(alpha: a));
    _poly(canvas, [
      const Offset(-10, 1), const Offset(8, 0),
      const Offset(8, 3),   const Offset(-10, 4),
    ], const Color(0xFFD4A055).withValues(alpha: a));
    _poly(canvas, [
      const Offset(-10, 1), const Offset(-10, 7),
      const Offset(-13, 5), const Offset(-13, 2),
    ], const Color(0xFFC09040).withValues(alpha: a));

    // ── Head ──
    _poly(canvas, [
      const Offset(-14, 0), const Offset(-9, -3),
      const Offset(-8, 2),  const Offset(-13, 3),
    ], const Color(0xFFC89848).withValues(alpha: a));
    // Eye socket
    _poly(canvas, [
      const Offset(-13, -1), const Offset(-11, -2),
      const Offset(-10, 0),  const Offset(-12, 1),
    ], const Color(0xFF1A1A1A).withValues(alpha: a));
    // Eye shine
    canvas.drawCircle(const Offset(-11.5, -0.5), 1.0,
        Paint()..color = Colors.white.withValues(alpha: a * 0.9));

    // ── Antennae ──
    final antPaint = Paint()
      ..color = const Color(0xFFB88040).withValues(alpha: a)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(-14, 0), const Offset(-17, -7), antPaint);
    canvas.drawLine(
        const Offset(-12, -1), const Offset(-14, -8), antPaint);
    canvas.drawCircle(const Offset(-17, -7), 1.5,
        Paint()..color = const Color(0xFFE0A060).withValues(alpha: a));
    canvas.drawCircle(const Offset(-14, -8), 1.5,
        Paint()..color = const Color(0xFFE0A060).withValues(alpha: a));

    // ── Shell ──
    _drawShellLocal(canvas, 3.0, -5.0, a);

    // Cry tear drop (appears on head side, mirrors correctly after flip)
    if (snail.cryTimer > 0) {
      final ta = (snail.cryTimer / 0.3) * a;
      _poly(canvas, [
        const Offset(-11, -5),
        const Offset(-10, -3),
        const Offset(-12, -3),
      ], Colors.lightBlue.withValues(alpha: ta));
    }

    // Salt dissolve particles
    if (snail.isDying) {
      final rand = Random(42);
      for (int i = 0; i < 10; i++) {
        final sx = rand.nextDouble() * 28 - 14;
        final sy = rand.nextDouble() * 24 - 12;
        final sr = 1.0 + rand.nextDouble() * 2;
        _poly(canvas, [
          Offset(sx,      sy - sr),
          Offset(sx + sr, sy),
          Offset(sx,      sy + sr),
          Offset(sx - sr, sy),
        ], Colors.white.withValues(alpha: a));
      }
    }

    canvas.restore();
  }

  /// Low-poly snail shell drawn in LOCAL canvas space (canvas already
  /// translated to the snail centre before this is called).
  void _drawShellLocal(Canvas canvas, double sx, double sy, double alpha) {
    const int n = 8;
    const double r  = 11.5;
    const double ry = 9.0; // vertical squish for isometric feel

    // Outer rim (8 vertices)
    final rim = List<Offset>.generate(n, (i) {
      final angle = (i / n) * 2 * pi - pi / 2;
      return Offset(sx + cos(angle) * r, sy + sin(angle) * ry);
    });

    // Slight spiral offset for visual center
    final center = Offset(sx + 2, sy + 2);

    // Light from upper-left → bright at top, dark at bottom
    const wedgeColors = [
      Color(0xFFE09858), // top         – brightest
      Color(0xFFD08040), // top-right
      Color(0xFFB56A30), // right
      Color(0xFF9B5520), // lower-right
      Color(0xFF7B3B10), // bottom      – darkest
      Color(0xFF8B4520), // lower-left
      Color(0xFFC07030), // left
      Color(0xFFD88848), // top-left
    ];
    for (int i = 0; i < n; i++) {
      _poly(canvas, [center, rim[i], rim[(i + 1) % n]],
          wedgeColors[i].withValues(alpha: alpha));
    }

    // Inner spiral ring (smaller, darker – creates the coil illusion)
    final innerRim = List<Offset>.generate(n, (i) {
      final angle = (i / n) * 2 * pi - pi / 2 + pi / n;
      return Offset(
          sx + cos(angle) * r * 0.46 + 1.5,
          sy + sin(angle) * ry * 0.46 + 1.5);
    });
    final innerCenter = Offset(sx + 3, sy + 3);
    const innerColors = [
      Color(0xFF6B2B05), Color(0xFF5B1B00), Color(0xFF6B2B05),
      Color(0xFF7B3B10), Color(0xFF8B4520), Color(0xFF7B3B10),
      Color(0xFF6B2B05), Color(0xFF5B1B00),
    ];
    for (int i = 0; i < n; i++) {
      _poly(canvas, [innerCenter, innerRim[i], innerRim[(i + 1) % n]],
          innerColors[i].withValues(alpha: alpha));
    }

    // Shell outline
    final outline = Path();
    for (int i = 0; i < n; i++) {
      if (i == 0) {
        outline.moveTo(rim[i].dx, rim[i].dy);
      } else {
        outline.lineTo(rim[i].dx, rim[i].dy);
      }
    }
    outline.close();
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFF3A1A08).withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // WEAPONS
  // ═══════════════════════════════════════════════════════════════

  void _drawWeapons(Canvas canvas, Offset origin) {
    for (final weapon in controller.weapons) {
      final pos = IsometricMap.gridToScreen(weapon.col, weapon.row, origin);
      final cx = pos.dx + IsometricMap.tileWidth  / 2;
      final cy = pos.dy + IsometricMap.tileHeight / 2;
      _drawWeapon(canvas, weapon, Offset(cx, cy));
    }
  }

  void _drawWeapon(Canvas canvas, Weapon weapon, Offset center) {
    switch (weapon.type) {
      case WeaponType.saltGun:
        // Compute barrel aim angle toward the tracked target
        double aimAngle = 0.0;
        if (weapon.aimTarget != null) {
          final pivot = Offset(center.dx, center.dy - 7);
          final diff  = weapon.aimTarget! - pivot;
          if (diff.distance > 1) aimAngle = atan2(diff.dy, diff.dx);
        }
        _drawSaltGun(canvas, center, aimAngle);
        break;
      case WeaponType.saltTrap:
        _drawSaltTrap(canvas, center, weapon.trapKillsRemaining);
        break;
      case WeaponType.cryingEye:
        _drawCryingEye(canvas, center, weapon.eyeTimeRemaining);
        break;
    }
  }

  // ── Salt Gun ─────────────────────────────────────────────────
  void _drawSaltGun(Canvas canvas, Offset c, double aimAngle) {
    // Fixed isometric platform – 3 visible faces
    _poly(canvas, [
      Offset(c.dx,      c.dy - 10),
      Offset(c.dx + 12, c.dy -  4),
      Offset(c.dx,      c.dy +  2),
      Offset(c.dx - 12, c.dy -  4),
    ], const Color(0xFF546E7A));
    _poly(canvas, [
      Offset(c.dx - 12, c.dy - 4),
      Offset(c.dx,      c.dy + 2),
      Offset(c.dx,      c.dy + 7),
      Offset(c.dx - 12, c.dy + 1),
    ], const Color(0xFF37474F));
    _poly(canvas, [
      Offset(c.dx + 12, c.dy - 4),
      Offset(c.dx,      c.dy + 2),
      Offset(c.dx,      c.dy + 7),
      Offset(c.dx + 12, c.dy + 1),
    ], const Color(0xFF455A64));

    // Rotating turret + barrel – pivot at turret centre
    canvas.save();
    canvas.translate(c.dx, c.dy - 7);
    canvas.rotate(aimAngle);

    // Turret hexagon (6 facets)
    final turret = List<Offset>.generate(6, (i) {
      final angle = i * pi / 3;
      return Offset(cos(angle) * 8, sin(angle) * 6);
    });
    _poly(canvas, turret, const Color(0xFF78909C));
    // Highlight wedge
    _poly(canvas, [
      const Offset(0, -6),
      const Offset(8,  0),
      const Offset(0,  0),
    ], const Color(0xFF90A4AE));

    // Barrel pointing in +x direction (rotated by aimAngle)
    _poly(canvas, [
      const Offset(1, -3), const Offset(18, -5),
      const Offset(18, -1), const Offset(1, 1),
    ], const Color(0xFF455A64));
    _poly(canvas, [
      const Offset(1, -3), const Offset(18, -5),
      const Offset(18, -3), const Offset(1, -1),
    ], const Color(0xFF607D8B));
    // Muzzle accent
    _poly(canvas, [
      const Offset(16, -5), const Offset(20, -3), const Offset(16, -1),
    ], const Color(0xFFECEFF1));

    canvas.restore();

    // Salt crystal decoration – fixed, always upright
    _poly(canvas, [
      Offset(c.dx,     c.dy - 17),
      Offset(c.dx + 5, c.dy - 12),
      Offset(c.dx,     c.dy - 10),
      Offset(c.dx - 5, c.dy - 12),
    ], const Color(0xFFECEFF1));
    _poly(canvas, [
      Offset(c.dx,     c.dy - 17),
      Offset(c.dx + 5, c.dy - 12),
      Offset(c.dx,     c.dy - 13),
    ], Colors.white.withValues(alpha: 0.85));
  }

  // ── Salt Trap ────────────────────────────────────────────────
  void _drawSaltTrap(Canvas canvas, Offset c, int kills) {
    // Elliptical ground ring
    final ringPath = Path();
    const rr = 15.0;
    for (int i = 0; i <= 12; i++) {
      final angle = i * pi / 6;
      final pt = Offset(c.dx + cos(angle) * rr, c.dy + sin(angle) * rr * 0.5);
      if (i == 0) ringPath.moveTo(pt.dx, pt.dy);
      else ringPath.lineTo(pt.dx, pt.dy);
    }
    ringPath.close();
    canvas.drawPath(ringPath, Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // Salt crystal cluster
    final rand = Random(c.dx.toInt() + 7);
    const crystalPalette = [
      Color(0xFFFFFFFF), Color(0xFFECEFF1), Color(0xFFCFD8DC),
      Color(0xFFB0BEC5), Color(0xFFE3F2FD), Color(0xFFDDEEFF),
    ];
    for (int i = 0; i < 9; i++) {
      final angle = i * pi / 4.5 + 0.3;
      final dist  = 4.0 + rand.nextDouble() * 9;
      final px    = c.dx + cos(angle) * dist;
      final py    = c.dy + sin(angle) * dist * 0.5;
      final sz    = 2.5 + rand.nextDouble() * 2;
      final color = crystalPalette[i % crystalPalette.length];
      // Crystal body
      _poly(canvas, [
        Offset(px,           py - sz),
        Offset(px + sz * 0.6, py),
        Offset(px,           py + sz * 0.5),
        Offset(px - sz * 0.6, py),
      ], color);
      // Crystal highlight facet
      _poly(canvas, [
        Offset(px,           py - sz),
        Offset(px + sz * 0.6, py),
        Offset(px,           py - sz * 0.25),
      ], Colors.white.withValues(alpha: 0.55));
    }

    // Kills indicator
    final tp = TextPainter(
      text: TextSpan(
        text: '$kills',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black, blurRadius: 2)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c.translate(-5, -20));
  }

  // ── Crying Eye ───────────────────────────────────────────────
  void _drawCryingEye(Canvas canvas, Offset c, double timeLeft) {
    final pulse = sin(time * 4) * 0.12 + 0.88;
    final alpha = (timeLeft / 15.0).clamp(0.3, 1.0);

    // Helper: scaled offset from center
    Offset s(double dx, double dy) =>
        Offset(c.dx + dx * pulse, c.dy + dy * pulse);

    // Sclera – upper lid
    _poly(canvas, [s(-13, 0), s(-7, -9), s(0, -11), s(7, -9), s(13, 0)],
        Colors.white.withValues(alpha: alpha));
    // Sclera – lower lid
    _poly(canvas, [s(-13, 0), s(-6, 5), s(0, 6), s(6, 5), s(13, 0)],
        const Color(0xFFF5F5F5).withValues(alpha: alpha * 0.9));

    // Iris – 6 triangular facets (pie slices)
    const irisColors = [
      Color(0xFF00695C), Color(0xFF00796B), Color(0xFF00897B),
      Color(0xFF00796B), Color(0xFF00695C), Color(0xFF004D40),
    ];
    for (int seg = 0; seg < 6; seg++) {
      final a1 = seg * pi / 3;
      final a2 = (seg + 1) * pi / 3;
      final ir = 6.5 * pulse;
      _poly(canvas, [
        c,
        Offset(c.dx + cos(a1) * ir, c.dy + sin(a1) * ir),
        Offset(c.dx + cos(a2) * ir, c.dy + sin(a2) * ir),
      ], irisColors[seg].withValues(alpha: alpha));
    }

    // Pupil (diamond)
    _poly(canvas, [s(0, -4), s(4, 0), s(0, 4), s(-4, 0)],
        Colors.black.withValues(alpha: alpha));
    // Shine spot
    canvas.drawCircle(s(-2, -2), 1.5,
        Paint()..color = Colors.white.withValues(alpha: alpha));

    // Tear drops (animated triangle polygons)
    final ta = (sin(time * 2.5) * 0.2 + 0.7) * alpha;
    final td = sin(time * 3) * 3;
    _poly(canvas, [s(-5, 6), s(-3, 14 + td), s(-7, 14 + td)],
        Colors.lightBlue.withValues(alpha: ta));
    _poly(canvas, [s(5, 6), s(7, 16 + td), s(3, 16 + td)],
        Colors.lightBlue.withValues(alpha: ta * 0.8));

    // Timer arc
    canvas.drawArc(
      Rect.fromCenter(center: c, width: 30, height: 30),
      -pi / 2,
      (timeLeft / 15.0) * 2 * pi,
      false,
      Paint()
        ..color = Colors.orange.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  // PROJECTILES
  // ═══════════════════════════════════════════════════════════════

  void _drawProjectiles(Canvas canvas) {
    for (final p in controller.projectiles) {
      // Low-poly salt crystal (diamond)
      _poly(canvas, [
        p.position.translate(0, -5),
        p.position.translate(4,  0),
        p.position.translate(0,  5),
        p.position.translate(-4, 0),
      ], Colors.white);
      // Highlight facet
      _poly(canvas, [
        p.position.translate(0,  -5),
        p.position.translate(4,   0),
        p.position.translate(0,  -1),
      ], Colors.white.withValues(alpha: 0.5));
      // Soft glow
      canvas.drawCircle(
        p.position,
        7,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.25)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // LETTUCE
  // ═══════════════════════════════════════════════════════════════

  void _drawLettuce(Canvas canvas, IsometricMap map, Offset origin) {
    final lp  = map.lettucePosition;
    final pos = IsometricMap.gridToScreen(lp[0], lp[1], origin);
    final cx  = pos.dx + IsometricMap.tileWidth  / 2;
    final cy  = pos.dy + IsometricMap.tileHeight / 2 - 4;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + 13), width: 40, height: 11),
      Paint()..color = Colors.black.withValues(alpha: 0.28),
    );
    // Ambient glow
    canvas.drawCircle(
      Offset(cx, cy - 2),
      28,
      Paint()
        ..color = Colors.green.withValues(alpha: 0.20)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Stem
    _poly(canvas, [
      Offset(cx - 2, cy + 8),
      Offset(cx + 2, cy + 8),
      Offset(cx + 1, cy + 15),
      Offset(cx - 1, cy + 15),
    ], const Color(0xFF4CAF50));

    // ── Round cabbage head ──
    // Outer ruffled ring: 8 overlapping lobes
    for (int i = 0; i < 8; i++) {
      final angle = i * pi / 4 + pi / 8;
      canvas.drawCircle(
        Offset(cx + cos(angle) * 14, (cy - 3) + sin(angle) * 10),
        8.5,
        Paint()..color = const Color(0xFF2E7D32),
      );
    }
    // Mid layer: 5 lobes
    for (int i = 0; i < 5; i++) {
      final angle = i * 2 * pi / 5 + pi / 5;
      canvas.drawCircle(
        Offset(cx + cos(angle) * 9, (cy - 4) + sin(angle) * 6.5),
        7.5,
        Paint()..color = const Color(0xFF388E3C),
      );
    }
    // Main centre circle
    canvas.drawCircle(
      Offset(cx, cy - 4),
      11,
      Paint()..color = const Color(0xFF43A047),
    );
    // Inner bright spot
    canvas.drawCircle(
      Offset(cx - 1, cy - 7),
      6,
      Paint()..color = const Color(0xFF66BB6A),
    );
    // Specular highlight
    canvas.drawCircle(
      Offset(cx - 2, cy - 9),
      2.5,
      Paint()..color = Colors.white.withValues(alpha: 0.30),
    );

    // HP indicator – hearts
    final hp = controller.lettuceHp;
    for (int i = 0; i < 5; i++) {
      final hx = cx - 20.0 + i * 10.0;
      _drawHeart(
        canvas,
        Offset(hx, cy + 20),
        5.0,
        i < hp ? Colors.red.withValues(alpha: 0.9) : Colors.grey.withValues(alpha: 0.35),
      );
    }
  }

  /// Draws a heart centred at [center] with overall size [size] in [color].
  /// The heart points downward (classic orientation).
  void _drawHeart(Canvas canvas, Offset center, double size, Color color) {
    final paint = Paint()..color = color;
    final r = size * 0.38;
    // Two top bumps
    canvas.drawCircle(Offset(center.dx - r, center.dy - r * 0.25), r, paint);
    canvas.drawCircle(Offset(center.dx + r, center.dy - r * 0.25), r, paint);
    // Bottom pointed triangle connecting the bumps into a classic heart shape
    _poly(canvas, [
      Offset(center.dx - size * 0.76, center.dy + r * 0.05),
      Offset(center.dx + size * 0.76, center.dy + r * 0.05),
      Offset(center.dx,               center.dy + size * 0.72),
    ], color);
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
