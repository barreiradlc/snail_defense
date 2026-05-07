import 'dart:math';
import 'package:flutter/material.dart';
import '../models/iso_map.dart';
import '../models/weapon.dart';
import '../game/game_controller.dart';
import '../game/game_painter.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ticker;
  late GameController _controller;
  late IsometricMap _map;
  double _time = 0.0;
  double _lastTime = 0.0;

  static const _toolbarHeight = 80.0;
  static const _panSpeed = 250.0;

  Offset _cameraOffset = Offset.zero;
  Offset _joystickDelta = Offset.zero;

  @override
  void initState() {
    super.initState();
    _map = IsometricMap();
    _controller = GameController(map: _map);

    _ticker = AnimationController(
      vsync: this,
      duration: const Duration(days: 1),
    )..addListener(_onTick)..forward();
  }

  void _onTick() {
    final t = _ticker.lastElapsedDuration?.inMicroseconds.toDouble() ?? 0;
    final now = t / 1000000.0;
    final dt = min(now - _lastTime, 0.05); // cap at 50ms
    _lastTime = now;
    _time = now;

    if (_joystickDelta != Offset.zero) {
      _cameraOffset += _joystickDelta * _panSpeed * dt;
      _cameraOffset = Offset(
        _cameraOffset.dx.clamp(-640.0, 640.0),
        _cameraOffset.dy.clamp(-320.0, 320.0),
      );
    }

    setState(() {
      _controller.update(dt);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details) {
    final pos = details.localPosition;
    // Convert screen pos back to grid
    final origin = _controller.renderOrigin;
    final rx = pos.dx - origin.dx;
    final ry = pos.dy - origin.dy;
    final tw = IsometricMap.tileWidth;
    final th = IsometricMap.tileHeight;
    // Inverse isometric transform
    final col = ((rx / (tw / 2) + ry / (th / 2)) / 2).round();
    final row = ((ry / (th / 2) - rx / (tw / 2)) / 2).round();

    if (col >= 0 && col < _map.cols && row >= 0 && row < _map.rows) {
      _controller.placeWeapon(col, row);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: SafeArea(
        child: Column(
          children: [
            _buildHUD(),
            Expanded(child: _buildGameView()),
            _buildToolbar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHUD() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF16213E),
      child: Row(
        children: [
          _hudItem(Icons.waves, 'Onda', '${_controller.wave}/5'),
          const SizedBox(width: 16),
          _hudItem(Icons.star, 'Pontos', '${_controller.score}'),
          const Spacer(),
          Row(
            children: List.generate(5, (i) {
              return Icon(
                Icons.favorite,
                color: i < _controller.lettuceHp
                    ? Colors.red
                    : Colors.grey.withValues(alpha: 0.4),
                size: 18,
              );
            }),
          ),
          const SizedBox(width: 8),
          const Text('🥬', style: TextStyle(fontSize: 20)),
        ],
      ),
    );
  }

  Widget _hudItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 16),
        const SizedBox(width: 4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(color: Colors.white54, fontSize: 10)),
            Text(value,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildGameView() {
    return LayoutBuilder(builder: (context, constraints) {
      // Center the map
      final mapW = (_map.cols + _map.rows) * (IsometricMap.tileWidth / 2);
      final mapH = (_map.cols + _map.rows) * (IsometricMap.tileHeight / 2);
      final needsJoystick =
          mapW > constraints.maxWidth || mapH > constraints.maxHeight;

      _controller.renderOrigin = Offset(
        (constraints.maxWidth - mapW) / 2 + _map.rows * (IsometricMap.tileWidth / 2),
        20,
      ) + _cameraOffset;

      return Stack(
        children: [
          GestureDetector(
            onTapDown: _handleTap,
            child: ClipRect(
              child: CustomPaint(
                painter: GamePainter(controller: _controller, time: _time),
                size: Size(constraints.maxWidth, constraints.maxHeight),
              ),
            ),
          ),
          if (needsJoystick)
            Positioned(
              left: 16,
              bottom: 16,
              child: _JoystickWidget(
                onMove: (delta) => _joystickDelta = delta,
              ),
            ),
          if (_controller.status == GameStatus.victory)
            _GameOverlay(
              title: '🎉 Vitória!',
              color: Colors.green,
              score: _controller.score,
              onRestart: _restartGame,
              onHome: () => Navigator.pop(context),
            ),
          if (_controller.status == GameStatus.defeat)
            _GameOverlay(
              title: '🐌 Derrota!',
              color: Colors.red,
              score: _controller.score,
              onRestart: _restartGame,
              onHome: () => Navigator.pop(context),
            ),
        ],
      );
    });
  }

  void _restartGame() {
    setState(() {
      _map = IsometricMap();
      _controller = GameController(map: _map);
    });
  }

  Widget _buildToolbar() {
    return Container(
      height: _toolbarHeight,
      color: const Color(0xFF0F3460),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _weaponButton(WeaponType.saltGun, '🔫', 'Arma de Sal', '∞'),
          _weaponButton(WeaponType.saltTrap, '⬜', 'Armadilha', '×5'),
          _weaponButton(WeaponType.cryingEye, '👁️', 'Olho Chorão', '15s'),
          const VerticalDivider(color: Colors.white24),
          _backButton(),
        ],
      ),
    );
  }

  Widget _weaponButton(
      WeaponType type, String emoji, String label, String info) {
    final selected = _controller.selectedWeapon == type;
    return GestureDetector(
      onTap: () => setState(() => _controller.selectedWeapon = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.orangeAccent.withValues(alpha: 0.3)
              : Colors.transparent,
          border: Border.all(
            color: selected ? Colors.orangeAccent : Colors.white24,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            Text(info,
                style: TextStyle(
                    color: selected ? Colors.orangeAccent : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _backButton() {
    return IconButton(
      onPressed: () => Navigator.pop(context),
      icon: const Icon(Icons.home, color: Colors.white70),
      tooltip: 'Menu',
    );
  }
}

class _GameOverlay extends StatelessWidget {
  final String title;
  final Color color;
  final int score;
  final VoidCallback onRestart;
  final VoidCallback onHome;

  const _GameOverlay({
    required this.title,
    required this.color,
    required this.score,
    required this.onRestart,
    required this.onHome,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black54,
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFF16213E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color, width: 2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title,
                  style: TextStyle(
                      color: color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Pontuação: $score',
                  style: const TextStyle(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ElevatedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Jogar Novamente'),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: color.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: onHome,
                    icon: const Icon(Icons.home, color: Colors.white70),
                    label: const Text('Menu',
                        style: TextStyle(color: Colors.white70)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ── Virtual joystick ────────────────────────────────────────────────────────

class _JoystickWidget extends StatefulWidget {
  final ValueChanged<Offset> onMove;
  const _JoystickWidget({required this.onMove});

  @override
  State<_JoystickWidget> createState() => _JoystickWidgetState();
}

class _JoystickWidgetState extends State<_JoystickWidget> {
  static const double _outerR = 38.0;
  static const double _thumbR = 16.0;
  Offset _thumb = Offset.zero;

  void _onPanStart(DragStartDetails d) => _updateThumb(d.localPosition);
  void _onPanUpdate(DragUpdateDetails d) => _updateThumb(d.localPosition);
  void _onPanEnd(DragEndDetails _) {
    setState(() => _thumb = Offset.zero);
    widget.onMove(Offset.zero);
  }

  void _updateThumb(Offset local) {
    final center = Offset(_outerR, _outerR);
    var delta = local - center;
    if (delta.distance > _outerR) delta = delta / delta.distance * _outerR;
    setState(() => _thumb = delta);
    widget.onMove(delta / _outerR);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: _onPanStart,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: CustomPaint(
        size: Size(_outerR * 2, _outerR * 2),
        painter: _JoystickPainter(thumb: _thumb, outerR: _outerR, thumbR: _thumbR),
      ),
    );
  }
}

class _JoystickPainter extends CustomPainter {
  final Offset thumb;
  final double outerR;
  final double thumbR;

  const _JoystickPainter({
    required this.thumb,
    required this.outerR,
    required this.thumbR,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(outerR, outerR);

    // Outer ring fill
    canvas.drawCircle(c, outerR, Paint()..color = const Color(0x26FFFFFF));
    // Outer ring border
    canvas.drawCircle(
      c,
      outerR,
      Paint()
        ..color = const Color(0x88FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    // Thumb drop shadow
    canvas.drawCircle(
      c + thumb + const Offset(1, 2),
      thumbR,
      Paint()..color = const Color(0x44000000),
    );
    // Thumb fill
    canvas.drawCircle(c + thumb, thumbR, Paint()..color = const Color(0x99FFFFFF));
    // Thumb border
    canvas.drawCircle(
      c + thumb,
      thumbR,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_JoystickPainter old) => old.thumb != thumb;
}
