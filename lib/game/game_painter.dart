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

  void _drawTiles(Canvas canvas, IsometricMap map, Offset origin) {
    for (int r = 0; r < map.rows; r++) {
      for (int c = 0; c < map.cols; c++) {
        final tile = map.tiles[r][c];
        final pos = IsometricMap.gridToScreen(c, r, origin);
        _drawTile(canvas, pos, tile.type);
      }
    }
  }

  void _drawTile(Canvas canvas, Offset topCenter, TileType type) {
    final w = IsometricMap.tileWidth;
    final h = IsometricMap.tileHeight;
    final cx = topCenter.dx + w / 2;
    final cy = topCenter.dy + h / 2;

    Color top, left, right;
    switch (type) {
      case TileType.grass:
        top = const Color(0xFF5D9E35);
        left = const Color(0xFF3D7220);
        right = const Color(0xFF4A8A28);
        break;
      case TileType.dirt:
        top = const Color(0xFFC4933A);
        left = const Color(0xFF8A6020);
        right = const Color(0xFFA07030);
        break;
      case TileType.path:
        top = const Color(0xFFD4B97A);
        left = const Color(0xFF9A7A40);
        right = const Color(0xFFB09050);
        break;
      case TileType.water:
        top = const Color(0xFF4A90C4);
        left = const Color(0xFF2A6090);
        right = const Color(0xFF3A78B0);
        break;
    }

    // Top face
    final topPath = Path()
      ..moveTo(cx, topCenter.dy)
      ..lineTo(cx + w / 2, cy)
      ..lineTo(cx, topCenter.dy + h)
      ..lineTo(cx - w / 2, cy)
      ..close();
    canvas.drawPath(topPath, Paint()..color = top);

    // Left face
    final depth = 8.0;
    final leftPath = Path()
      ..moveTo(cx - w / 2, cy)
      ..lineTo(cx, topCenter.dy + h)
      ..lineTo(cx, topCenter.dy + h + depth)
      ..lineTo(cx - w / 2, cy + depth)
      ..close();
    canvas.drawPath(leftPath, Paint()..color = left);

    // Right face
    final rightPath = Path()
      ..moveTo(cx + w / 2, cy)
      ..lineTo(cx, topCenter.dy + h)
      ..lineTo(cx, topCenter.dy + h + depth)
      ..lineTo(cx + w / 2, cy + depth)
      ..close();
    canvas.drawPath(rightPath, Paint()..color = right);

    // Outline
    canvas.drawPath(
      topPath,
      Paint()
        ..color = Colors.black.withAlpha(30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  void _drawSnails(Canvas canvas) {
    for (final snail in controller.snails) {
      _drawSnail(canvas, snail);
    }
  }

  void _drawSnail(Canvas canvas, Snail snail) {
    final pos = snail.screenPos;
    final cx = pos.dx + IsometricMap.tileWidth / 2;
    final cy = pos.dy + IsometricMap.tileHeight / 2;

    double alpha = 1.0;
    if (snail.isDying) {
      alpha = snail.dyingTimer / Snail.dyingDuration;
    }

    final paint = Paint()..color = Colors.brown.withValues(alpha: alpha);

    // Shell - ellipse
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy - 4), width: 22, height: 16),
      Paint()
        ..color = const Color(0xFF8B4513).withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    // Shell spiral
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + 2, cy - 5), width: 12, height: 9),
      Paint()
        ..color = const Color(0xFFA0522D).withValues(alpha: alpha)
        ..style = PaintingStyle.fill,
    );
    // Body
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 4, cy + 2), width: 18, height: 8),
      paint,
    );
    // Antennae
    final antennaPaint = Paint()
      ..color = Colors.brown.withValues(alpha: alpha)
      ..strokeWidth = 1.5;
    canvas.drawLine(
        Offset(cx - 6, cy - 2), Offset(cx - 9, cy - 8), antennaPaint);
    canvas.drawLine(
        Offset(cx - 4, cy - 2), Offset(cx - 6, cy - 8), antennaPaint);

    // Cry effect
    if (snail.cryTimer > 0) {
      final tearPaint = Paint()
        ..color = Colors.lightBlue.withValues(alpha: snail.cryTimer / 0.3 * alpha);
      canvas.drawCircle(Offset(cx - 9, cy - 5), 2, tearPaint);
      canvas.drawCircle(Offset(cx - 6, cy - 6), 1.5, tearPaint);
    }

    // Dying salt dissolve effect
    if (snail.isDying) {
      final saltPaint = Paint()
        ..color = Colors.white.withValues(alpha: alpha);
      final rand = Random(42);
      for (int i = 0; i < 8; i++) {
        canvas.drawCircle(
          Offset(cx + rand.nextDouble() * 20 - 10,
              cy + rand.nextDouble() * 20 - 10),
          rand.nextDouble() * 3,
          saltPaint,
        );
      }
    }
  }

  void _drawWeapons(Canvas canvas, Offset origin) {
    for (final weapon in controller.weapons) {
      final pos = IsometricMap.gridToScreen(weapon.col, weapon.row, origin);
      final cx = pos.dx + IsometricMap.tileWidth / 2;
      final cy = pos.dy + IsometricMap.tileHeight / 2;
      _drawWeapon(canvas, weapon, Offset(cx, cy));
    }
  }

  void _drawWeapon(Canvas canvas, Weapon weapon, Offset center) {
    switch (weapon.type) {
      case WeaponType.saltGun:
        _drawSaltGun(canvas, center);
        break;
      case WeaponType.saltTrap:
        _drawSaltTrap(canvas, center, weapon.trapKillsRemaining);
        break;
      case WeaponType.cryingEye:
        _drawCryingEye(canvas, center, weapon.eyeTimeRemaining);
        break;
    }
  }

  void _drawSaltGun(Canvas canvas, Offset center) {
    // Base platform
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 20, height: 14),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF607D8B),
    );
    // Barrel
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx, center.dy - 4, 14, 5),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF455A64),
    );
    // Salt crystal on top
    canvas.drawCircle(
        center.translate(0, -8), 4, Paint()..color = Colors.white70);
  }

  void _drawSaltTrap(Canvas canvas, Offset center, int kills) {
    // Spread of salt granules
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.9);
    final rand = Random(center.dx.toInt());
    for (int i = 0; i < 12; i++) {
      canvas.drawCircle(
        Offset(
          center.dx + rand.nextDouble() * 28 - 14,
          center.dy + rand.nextDouble() * 14 - 7,
        ),
        1.5,
        paint,
      );
    }
    // Kills remaining indicator
    final tp = TextPainter(
      text: TextSpan(
        text: '$kills',
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center.translate(-5, -14));
  }

  void _drawCryingEye(Canvas canvas, Offset center, double timeLeft) {
    final pulse = (sin(time * 4) * 0.15 + 0.85);
    final alpha = (timeLeft / 15.0).clamp(0.3, 1.0);

    // White of eye
    canvas.drawOval(
      Rect.fromCenter(
          center: center, width: 22 * pulse, height: 16 * pulse),
      Paint()..color = Colors.white.withValues(alpha: alpha),
    );
    // Iris
    canvas.drawCircle(
      center,
      6 * pulse,
      Paint()..color = Colors.teal.withValues(alpha: alpha),
    );
    // Pupil
    canvas.drawCircle(
      center,
      3 * pulse,
      Paint()..color = Colors.black.withValues(alpha: alpha),
    );
    // Tears
    final tearPaint = Paint()
      ..color = Colors.lightBlue.withValues(alpha: alpha)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final tearY = center.dy + 8 + sin(time * 3) * 4;
    canvas.drawLine(
      center.translate(-4, 8),
      Offset(center.dx - 4, tearY + 4),
      tearPaint,
    );
    canvas.drawLine(
      center.translate(4, 8),
      Offset(center.dx + 4, tearY + 6),
      tearPaint,
    );

    // Timer ring
    canvas.drawArc(
      Rect.fromCenter(center: center, width: 28, height: 28),
      -pi / 2,
      (timeLeft / 15.0) * 2 * pi,
      false,
      Paint()
        ..color = Colors.orange.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
  }

  void _drawProjectiles(Canvas canvas) {
    final paint = Paint()..color = Colors.white;
    for (final p in controller.projectiles) {
      canvas.drawCircle(p.position, 4, paint);
      // Glow
      canvas.drawCircle(
          p.position,
          7,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  void _drawLettuce(Canvas canvas, IsometricMap map, Offset origin) {
    final lp = map.lettucePosition;
    final pos = IsometricMap.gridToScreen(lp[0], lp[1], origin);
    final cx = pos.dx + IsometricMap.tileWidth / 2;
    final cy = pos.dy + IsometricMap.tileHeight / 2;

    // Glow
    canvas.drawCircle(
      Offset(cx, cy - 8),
      20,
      Paint()
        ..color = Colors.green.withValues(alpha: 0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Lettuce leaves (layered circles)
    final greens = [
      const Color(0xFF2E7D32),
      const Color(0xFF388E3C),
      const Color(0xFF43A047),
      const Color(0xFF66BB6A),
    ];
    for (int i = 0; i < greens.length; i++) {
      final r = 14.0 - i * 2;
      canvas.drawCircle(
        Offset(cx + (i % 2 == 0 ? -2.0 : 2.0), cy - 8 - i * 1.5),
        r,
        Paint()..color = greens[i],
      );
    }

    // HP indicator
    final hp = controller.lettuceHp;
    for (int i = 0; i < 5; i++) {
      canvas.drawCircle(
        Offset(cx - 10 + i * 5.0, cy + 10),
        2.5,
        Paint()
          ..color = i < hp ? Colors.red : Colors.grey.withValues(alpha: 0.5),
      );
    }
  }

  @override
  bool shouldRepaint(GamePainter oldDelegate) => true;
}
