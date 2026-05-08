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
      final maxPanX = (_map.cols * IsometricMap.tileWidth);
      final maxPanY = (_map.rows * IsometricMap.tileHeight);
      _cameraOffset = Offset(
        _cameraOffset.dx.clamp(-maxPanX, maxPanX),
        _cameraOffset.dy.clamp(-maxPanY, maxPanY),
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
          _hudItem(Icons.waves, 'Onda', '${_controller.wave}'),
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
          if (_controller.waveTransitioning)
            _WaveTransitionOverlay(
              wave: _controller.wave,
              onComplete: _controller.beginWave,
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

// ── Wave transition (fighting-game style) ───────────────────────────────────

class _WaveTransitionOverlay extends StatefulWidget {
  final int wave;
  final VoidCallback onComplete;
  const _WaveTransitionOverlay({required this.wave, required this.onComplete});

  @override
  State<_WaveTransitionOverlay> createState() => _WaveTransitionOverlayState();
}

class _WaveTransitionOverlayState extends State<_WaveTransitionOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  static double _c(double v) => v.clamp(0.0, 1.0);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )
      ..forward()
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) widget.onComplete();
      });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    final sh = MediaQuery.of(context).size.height;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        final t = _ctrl.value;

        // Banners slide in 0→0.28, hold, slide out 0.73→1.00
        final inF  = Curves.easeOutBack.transform(_c(t / 0.28));
        final outF = Curves.easeIn.transform(_c((t - 0.73) / 0.27));
        final leftX  = sw * (-1.0 + inF - outF);
        final rightX = sw * ( 1.0 - inF + outF);

        // White flash peaks at impact (t ≈ 0.28)
        final flashRaw = _c(1.0 - ((t - 0.28) / 0.09).abs());
        final flashA   = flashRaw * flashRaw; // sharper peak

        // "LUTA!" elastic scale-in at t=0.37, fade out at t=0.64
        final fightIn    = Curves.elasticOut.transform(_c((t - 0.37) / 0.24));
        final fightAlpha = _c(1.0 - (t - 0.64) / 0.13);
        final fightOpacity = (fightIn * fightAlpha).clamp(0.0, 1.0);

        return Stack(
          fit: StackFit.expand,
          children: [
            // Dark backdrop
            const ColoredBox(color: Color(0x99000000)),

            // "ONDA" banner — slides from left
            Positioned(
              top: sh / 2 - 90,
              left: 0,
              right: 0,
              child: Transform.translate(
                offset: Offset(leftX, 0),
                child: _buildBanner(
                  label: 'ONDA',
                  color: const Color(0xFFBB1100),
                  mirror: false,
                  width: sw,
                ),
              ),
            ),

            // Wave-number banner — slides from right
            Positioned(
              top: sh / 2 + 18,
              left: 0,
              right: 0,
              child: Transform.translate(
                offset: Offset(rightX, 0),
                child: _buildBanner(
                  label: '${widget.wave}',
                  color: const Color(0xFF001188),
                  mirror: true,
                  width: sw,
                  large: true,
                ),
              ),
            ),

            // Impact flash
            if (flashA > 0.01)
              ColoredBox(
                color: Color.fromARGB(
                    (flashA * 200).round(), 255, 255, 220)),

            // "LUTA!" punch-in
            if (fightOpacity > 0.01)
              Center(
                child: Opacity(
                  opacity: fightOpacity,
                  child: Transform.scale(
                    scale: fightIn.clamp(0.01, 1.18),
                    child: const Text(
                      'SAL NELES!',
                      style: TextStyle(
                        fontSize: 74,
                        fontWeight: FontWeight.w900,
                        color: Colors.yellow,
                        letterSpacing: 10,
                        shadows: [
                          Shadow(
                              color: Color(0xFFFF2200), blurRadius: 28),
                          Shadow(
                              color: Color(0xFFFF8800),
                              blurRadius: 56,
                              offset: Offset(0, 6)),
                          Shadow(color: Colors.black, blurRadius: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildBanner({
    required String label,
    required Color color,
    required bool mirror,
    required double width,
    bool large = false,
  }) {
    return CustomPaint(
      painter: _WaveBannerPainter(color: color, mirror: mirror),
      child: SizedBox(
        width: width,
        height: 72,
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: large ? 54 : 38,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: large ? 4 : 18,
              shadows: const [
                Shadow(color: Colors.black, blurRadius: 8),
                Shadow(
                    color: Colors.black,
                    blurRadius: 2,
                    offset: Offset(2, 2)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WaveBannerPainter extends CustomPainter {
  final Color color;
  final bool mirror;
  const _WaveBannerPainter({required this.color, required this.mirror});

  @override
  void paint(Canvas canvas, Size size) {
    const skew = 30.0;
    final w = size.width;
    final h = size.height;

    final path = mirror
        ? (Path()
          ..moveTo(0, 0)
          ..lineTo(w - skew, 0)
          ..lineTo(w, h)
          ..lineTo(skew, h)
          ..close())
        : (Path()
          ..moveTo(skew, 0)
          ..lineTo(w, 0)
          ..lineTo(w - skew, h)
          ..lineTo(0, h)
          ..close());

    // Gradient fill
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          colors: [color, Color.lerp(color, Colors.black, 0.45)!],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );

    // Bright edge
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white.withOpacity(0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
  }

  @override
  bool shouldRepaint(_WaveBannerPainter old) =>
      old.color != color || old.mirror != mirror;
}
