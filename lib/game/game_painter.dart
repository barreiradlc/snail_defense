import 'dart:math';
import 'dart:ui' show lerpDouble;
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

    // ── Type-based color palette ──────────────────────────────
    final Color bodyBase, bodyMid, bodySide, headColor, antColor, antTipColor;
    final List<Color> shellWedges, shellInner;
    switch (snail.snailType) {
      case SnailType.silver:
        bodyBase    = const Color(0xFF707070);
        bodyMid     = const Color(0xFFB8B8B8);
        bodySide    = const Color(0xFF909090);
        headColor   = const Color(0xFFAAAAAA);
        antColor    = const Color(0xFF909090);
        antTipColor = const Color(0xFFD0D0D0);
        shellWedges = const [
          Color(0xFFDDDDDD), Color(0xFFC4C4C4), Color(0xFFA0A0A0),
          Color(0xFF808080), Color(0xFF606060), Color(0xFF787878),
          Color(0xFFB0B0B0), Color(0xFFCCCCCC),
        ];
        shellInner = const [
          Color(0xFF555555), Color(0xFF444444), Color(0xFF555555),
          Color(0xFF666666), Color(0xFF707070), Color(0xFF666666),
          Color(0xFF555555), Color(0xFF444444),
        ];
        break;
      case SnailType.golden:
        bodyBase    = const Color(0xFF8B6914);
        bodyMid     = const Color(0xFFDAA520);
        bodySide    = const Color(0xFFC49A28);
        headColor   = const Color(0xFFFFD700);
        antColor    = const Color(0xFFDAA520);
        antTipColor = const Color(0xFFFFE55C);
        shellWedges = const [
          Color(0xFFFFE040), Color(0xFFDAA520), Color(0xFFB8860B),
          Color(0xFF8B6914), Color(0xFF705208), Color(0xFF8B6914),
          Color(0xFFC49A28), Color(0xFFEEC900),
        ];
        shellInner = const [
          Color(0xFF7B4A00), Color(0xFF6B3A00), Color(0xFF7B4A00),
          Color(0xFF8B5A10), Color(0xFF9B6A20), Color(0xFF8B5A10),
          Color(0xFF7B4A00), Color(0xFF6B3A00),
        ];
        break;
      default: // normal
        bodyBase    = const Color(0xFFA07030);
        bodyMid     = const Color(0xFFD4A055);
        bodySide    = const Color(0xFFC09040);
        headColor   = const Color(0xFFC89848);
        antColor    = const Color(0xFFB88040);
        antTipColor = const Color(0xFFE0A060);
        shellWedges = const [
          Color(0xFFE09858), Color(0xFFD08040), Color(0xFFB56A30),
          Color(0xFF9B5520), Color(0xFF7B3B10), Color(0xFF8B4520),
          Color(0xFFC07030), Color(0xFFD88848),
        ];
        shellInner = const [
          Color(0xFF6B2B05), Color(0xFF5B1B00), Color(0xFF6B2B05),
          Color(0xFF7B3B10), Color(0xFF8B4520), Color(0xFF7B3B10),
          Color(0xFF6B2B05), Color(0xFF5B1B00),
        ];
    }

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
    ], bodyBase.withValues(alpha: a));
    _poly(canvas, [
      const Offset(-10, 1), const Offset(8, 0),
      const Offset(8, 3),   const Offset(-10, 4),
    ], bodyMid.withValues(alpha: a));
    _poly(canvas, [
      const Offset(-10, 1), const Offset(-10, 7),
      const Offset(-13, 5), const Offset(-13, 2),
    ], bodySide.withValues(alpha: a));

    // ── Head ──
    _poly(canvas, [
      const Offset(-14, 0), const Offset(-9, -3),
      const Offset(-8, 2),  const Offset(-13, 3),
    ], headColor.withValues(alpha: a));
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
      ..color = antColor.withValues(alpha: a)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
        const Offset(-14, 0), const Offset(-17, -7), antPaint);
    canvas.drawLine(
        const Offset(-12, -1), const Offset(-14, -8), antPaint);
    canvas.drawCircle(const Offset(-17, -7), 1.5,
        Paint()..color = antTipColor.withValues(alpha: a));
    canvas.drawCircle(const Offset(-14, -8), 1.5,
        Paint()..color = antTipColor.withValues(alpha: a));

    // ── Shell ──
    _drawShellLocal(canvas, 3.0, -5.0, a, shellWedges, shellInner);

    // ── Trait accessory ──
    _drawSnailTrait(canvas, snail.trait, a, time);

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

    // ── HP bar (silver / golden only) ────────────────────────
    if (snail.snailType != SnailType.normal) {
      const barW = 28.0;
      const barH = 4.0;
      final barX = cx - barW / 2;
      final barY = cy - 22.0;
      final ratio = snail.hp / snail.maxHp;
      // Dark border
      canvas.drawRect(
        Rect.fromLTWH(barX - 1, barY - 1, barW + 2, barH + 2),
        Paint()..color = Colors.black.withValues(alpha: 0.6 * a),
      );
      // Empty track
      canvas.drawRect(
        Rect.fromLTWH(barX, barY, barW, barH),
        Paint()..color = const Color(0xFF333333).withValues(alpha: a),
      );
      // Filled portion
      if (ratio > 0) {
        final fillColor = snail.snailType == SnailType.golden
            ? const Color(0xFFFFD700)
            : const Color(0xFFC0C0C0);
        canvas.drawRect(
          Rect.fromLTWH(barX, barY, barW * ratio, barH),
          Paint()..color = fillColor.withValues(alpha: a),
        );
      }
    }
  }

  /// Draw the trait-specific accessory in LOCAL snail canvas space.
  void _drawSnailTrait(Canvas canvas, SnailTrait trait, double a, double t) {
    switch (trait) {
      case SnailTrait.none:
        break;

      case SnailTrait.armored:
        // Steel helmet sitting atop the shell (~shell top at y=-14)
        // Brim
        _poly(canvas, [
          const Offset(-1, -13), const Offset(9, -13),
          const Offset(11, -11), const Offset(-3, -11),
        ], Color(0xFF909090).withValues(alpha: a));
        // Dome left face
        _poly(canvas, [
          const Offset(-1, -13), const Offset(4, -20),
          const Offset(4, -13),
        ], Color(0xFFCCCCCC).withValues(alpha: a));
        // Dome right face
        _poly(canvas, [
          const Offset(4, -20), const Offset(9, -13),
          const Offset(4, -13),
        ], Color(0xFFAAAAAA).withValues(alpha: a));
        // Dome top highlight
        _poly(canvas, [
          const Offset(1, -18), const Offset(4, -20),
          const Offset(5, -18),
        ], Color(0xFFEEEEEE).withValues(alpha: a));
        // Visor slit
        canvas.drawLine(
          const Offset(0, -12), const Offset(8, -12),
          Paint()..color = Color(0xFF333333).withValues(alpha: a)
              ..strokeWidth = 1.5,
        );
        // Cheek guard left
        _poly(canvas, [
          const Offset(-3, -11), const Offset(-1, -11),
          const Offset(-1, -8), const Offset(-3, -8),
        ], Color(0xFF888888).withValues(alpha: a));
        break;

      case SnailTrait.runner:
        // Legs extend UPWARD from the body top (y=0).
        // Feet sit above the snail at y≈-20; legs connect down to body top.
        final leftLift  =  sin(t * 7.0) * 5.0; // ±5 px vertical bob
        final rightLift = -sin(t * 7.0) * 5.0; // opposite phase

        // ── Left leg ──
        // Foot anchor sits at lFootY (above body); leg runs down to y=0.
        final lFootY = -20.0 + leftLift;
        // Thigh: foot side → body side
        _poly(canvas, [
          Offset(-9.5, lFootY + 9), Offset(-5.5, lFootY + 9),
          Offset(-5, 0), Offset(-9, 0),
        ], Color(0xFFC4944A).withValues(alpha: a));
        // Shin: foot → knee
        _poly(canvas, [
          Offset(-10.0, lFootY + 1), Offset(-6.0, lFootY + 1),
          Offset(-5.5, lFootY + 9), Offset(-9.5, lFootY + 9),
        ], Color(0xFFB88040).withValues(alpha: a));
        // Left shoe sole
        _poly(canvas, [
          Offset(-13, lFootY + 1), Offset(-3, lFootY + 1),
          Offset(-3,  lFootY - 4), Offset(-13, lFootY - 4),
        ], Color(0xFF8B4513).withValues(alpha: a));
        // Left toe cap
        _poly(canvas, [
          Offset(-3,  lFootY - 4), Offset(0.5, lFootY - 4),
          Offset(0.5, lFootY - 1), Offset(-3,  lFootY - 1),
        ], Color(0xFF8B4513).withValues(alpha: a));
        // Left lace highlight
        canvas.drawLine(
          Offset(-13, lFootY), Offset(-3, lFootY),
          Paint()..color = Color(0xFFFFFFFF).withValues(alpha: a * 0.4)
              ..strokeWidth = 1.0,
        );

        // ── Right leg ──
        final rFootY = -20.0 + rightLift;
        // Thigh
        _poly(canvas, [
          Offset(0.5, rFootY + 9), Offset(4.5, rFootY + 9),
          Offset(5, 0), Offset(1, 0),
        ], Color(0xFFC4944A).withValues(alpha: a));
        // Shin
        _poly(canvas, [
          Offset(1.0, rFootY + 1), Offset(5.0, rFootY + 1),
          Offset(4.5, rFootY + 9), Offset(0.5, rFootY + 9),
        ], Color(0xFFB88040).withValues(alpha: a));
        // Right shoe sole
        _poly(canvas, [
          Offset(-1, rFootY + 1), Offset(9, rFootY + 1),
          Offset(9, rFootY - 4), Offset(-1, rFootY - 4),
        ], Color(0xFF6B3410).withValues(alpha: a));
        // Right toe cap
        _poly(canvas, [
          Offset(9,  rFootY - 4), Offset(12.5, rFootY - 4),
          Offset(12.5, rFootY - 1), Offset(9, rFootY - 1),
        ], Color(0xFF6B3410).withValues(alpha: a));
        // Right lace highlight
        canvas.drawLine(
          Offset(-1, rFootY), Offset(9, rFootY),
          Paint()..color = Color(0xFFFFFFFF).withValues(alpha: a * 0.4)
              ..strokeWidth = 1.0,
        );
        break;

      case SnailTrait.sheltered:
        // Umbrella held above the head (head is around x=-11, y=-2)
        // Handle / stick
        canvas.drawLine(
          const Offset(-11, 0), const Offset(-11, -22),
          Paint()..color = Color(0xFF6B3A10).withValues(alpha: a)
              ..strokeWidth = 2.0
              ..strokeCap = StrokeCap.round,
        );
        // Curved handle hook at bottom
        canvas.drawArc(
          Rect.fromCenter(
              center: const Offset(-8, 1), width: 7, height: 6),
          3.14, 3.14,
          false,
          Paint()..color = Color(0xFF6B3A10).withValues(alpha: a)
              ..strokeWidth = 2.0
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round,
        );
        // Canopy main (3 panels alternating)
        _poly(canvas, [
          const Offset(-23, -21), const Offset(-11, -29),
          const Offset(-11, -21),
        ], Color(0xFFE53030).withValues(alpha: a));
        _poly(canvas, [
          const Offset(-11, -29), const Offset(1, -21),
          const Offset(-11, -21),
        ], Color(0xFFFFFFFF).withValues(alpha: a));
        // Canopy highlight
        _poly(canvas, [
          const Offset(-20, -22), const Offset(-14, -26),
          const Offset(-11, -22),
        ], Color(0xFFFF8080).withValues(alpha: a * 0.5));
        // Scallop edge
        _poly(canvas, [
          const Offset(-23, -21), const Offset(-18, -18),
          const Offset(-14, -21),
        ], Color(0xFFCC2020).withValues(alpha: a));
        _poly(canvas, [
          const Offset(-14, -21), const Offset(-11, -18),
          const Offset(-8, -21),
        ], Color(0xFFDDDDDD).withValues(alpha: a));
        _poly(canvas, [
          const Offset(-8, -21), const Offset(-5, -18),
          const Offset(1, -21),
        ], Color(0xFFCC2020).withValues(alpha: a));
        // Canopy outline
        final canopy = Path()
          ..moveTo(-23, -21)
          ..lineTo(-11, -29)
          ..lineTo(1, -21)
          ..close();
        canvas.drawPath(
          canopy,
          Paint()..color = Color(0xFF991010).withValues(alpha: a)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 0.8,
        );
        break;
    }
  }

  /// Low-poly snail shell drawn in LOCAL canvas space (canvas already
  /// translated to the snail centre before this is called).
  void _drawShellLocal(Canvas canvas, double sx, double sy, double alpha,
      List<Color> wedgeColors, List<Color> innerColors) {
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
        final eyeDrawPos = weapon.eyePos ?? center;
        _drawCryingEye(canvas, eyeDrawPos, weapon.eyeTimeRemaining);
        if (weapon.eyeLockProgress < 1.0) {
          _drawEyeLockOn(canvas, eyeDrawPos, weapon.eyeLockProgress);
        }
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

  // ── Eye lock-on brackets ──────────────────────────────────────
  // progress 0→1 across three phases:
  //   0.00–0.45  scan  : outer ring sweeps in, rotating dashes
  //   0.45–0.80  close : brackets converge, secondary ring
  //   0.80–1.00  lock  : snap + crosshair flash, then fade to idle
  void _drawEyeLockOn(Canvas canvas, Offset c, double progress) {
    final p = progress.clamp(0.0, 1.0);

    // ── helpers ──────────────────────────────────────────────────
    double phase(double start, double end) =>
        ((p - start) / (end - start)).clamp(0.0, 1.0);

    // Phase eased values
    final scanT  = Curves.easeOut.transform(phase(0.00, 0.45));
    final closeT = Curves.easeInOut.transform(phase(0.45, 0.80));
    final lockT  = Curves.easeOutBack.transform(phase(0.80, 1.00));

    // After fully locked, fade everything out gently
    final globalAlpha = p < 0.95 ? 1.0 : (1.0 - p) / 0.05;

    final scanColor  = const Color(0xFFFFDD00);
    final lockColor  = const Color(0xFFFF4400);
    // Lerp from yellow → red as we lock
    final bracketColor = Color.lerp(scanColor, lockColor, closeT)!
        .withValues(alpha: globalAlpha);

    // ── Phase 1: rotating outer scanner ring ─────────────────────
    if (scanT > 0.0) {
      final ringR = lerpDouble(52.0, 26.0, scanT)!;
      final sweepAngle = scanT * 2 * pi; // arc sweeps from 0 → full circle
      final rotAngle   = -pi / 2 + time * 2.8; // slow rotation

      canvas.drawArc(
        Rect.fromCenter(center: c, width: ringR * 2, height: ringR * 2),
        rotAngle,
        sweepAngle,
        false,
        Paint()
          ..color = scanColor.withValues(alpha: scanT * 0.55 * globalAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.8,
      );

      // Counter-rotating short tick marks
      final tickCount = 8;
      for (int i = 0; i < tickCount; i++) {
        final a = -rotAngle + i * 2 * pi / tickCount;
        final inner = ringR - 4.0;
        final outer = ringR + 3.0;
        canvas.drawLine(
          Offset(c.dx + cos(a) * inner, c.dy + sin(a) * inner),
          Offset(c.dx + cos(a) * outer, c.dy + sin(a) * outer),
          Paint()
            ..color = scanColor.withValues(alpha: scanT * 0.45 * globalAlpha)
            ..strokeWidth = 1.2,
        );
      }
    }

    // ── Phase 2: secondary tightening ring ───────────────────────
    if (closeT > 0.0) {
      final ring2R = lerpDouble(24.0, 14.0, closeT)!;
      canvas.drawCircle(
        c,
        ring2R,
        Paint()
          ..color = bracketColor.withValues(alpha: closeT * 0.35 * globalAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // ── Brackets (phases 1–3, converge across close phase) ───────
    {
      final spread = lerpDouble(28.0, 11.0,
          Curves.easeInOut.transform((scanT * 0.4 + closeT * 0.6).clamp(0.0, 1.0)))!;
      // Arms grow in during scan, keep length during close
      final arm = lerpDouble(0.0, 8.0, scanT)!;
      // Stroke thickens at lock
      final strokeW = lerpDouble(1.5, 2.5, lockT)!;

      final bp = Paint()
        ..color = bracketColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeW
        ..strokeCap = StrokeCap.square;

      final corners = [
        Offset(c.dx - spread, c.dy - spread * 0.5),
        Offset(c.dx + spread, c.dy - spread * 0.5),
        Offset(c.dx + spread, c.dy + spread * 0.5),
        Offset(c.dx - spread, c.dy + spread * 0.5),
      ];
      final hDirs = [-1.0,  1.0,  1.0, -1.0];
      final vDirs = [-1.0, -1.0,  1.0,  1.0];

      for (int i = 0; i < 4; i++) {
        final o = corners[i];
        canvas.drawLine(o, Offset(o.dx + hDirs[i] * arm, o.dy), bp);
        canvas.drawLine(o, Offset(o.dx, o.dy + vDirs[i] * arm * 0.5), bp);
      }
    }

    // ── Phase 3: crosshair + final snap ring ─────────────────────
    if (lockT > 0.0) {
      final snapAlpha = (lockT * (1.0 - lockT) * 4.0).clamp(0.0, 1.0); // peaks at 0.5
      // Snap ring (expands outward on lock)
      canvas.drawCircle(
        c,
        lerpDouble(0.0, 20.0, lockT)!,
        Paint()
          ..color = lockColor.withValues(alpha: snapAlpha * 0.6 * globalAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      // Crosshair lines
      final chA = (lockT * globalAlpha).clamp(0.0, 1.0);
      final chP = Paint()
        ..color = lockColor.withValues(alpha: chA * 0.8)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(c.dx - 8, c.dy), Offset(c.dx + 8, c.dy), chP);
      canvas.drawLine(Offset(c.dx, c.dy - 5), Offset(c.dx, c.dy + 5), chP);
    }
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
