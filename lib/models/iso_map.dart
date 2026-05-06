import 'dart:math';
import 'dart:ui';

enum TileType { grass, dirt, path, water }

class MapTile {
  final int gridX;
  final int gridY;
  final TileType type;

  MapTile({required this.gridX, required this.gridY, required this.type});
}

class IsometricMap {
  final int cols;
  final int rows;
  late List<List<MapTile>> tiles;
  late List<List<int>> spawnPath; // list of [col, row] waypoints

  static const tileWidth = 64.0;
  static const tileHeight = 32.0;

  IsometricMap({this.cols = 20, this.rows = 20}) {
    _generate();
  }

  void _generate() {
    final rand = Random();
    tiles = List.generate(
      rows,
      (r) => List.generate(
        cols,
        (c) {
          final noise = rand.nextDouble();
          TileType t;
          if (noise < 0.05) {
            t = TileType.water;
          } else if (noise < 0.25) {
            t = TileType.dirt;
          } else {
            t = TileType.grass;
          }
          return MapTile(gridX: c, gridY: r, type: t);
        },
      ),
    );

    // Build a simple winding path from left edge to center (lettuce position)
    spawnPath = _buildPath();

    // Stamp path tiles
    for (final wp in spawnPath) {
      final c = wp[0].clamp(0, cols - 1);
      final r = wp[1].clamp(0, rows - 1);
      tiles[r][c] = MapTile(gridX: c, gridY: r, type: TileType.path);
    }
  }

  List<List<int>> _buildPath() {
    final rand = Random();
    final path = <List<int>>[];
    int c = 0;
    int r = rows ~/ 2;
    path.add([c, r]);

    while (c < cols - 2) {
      // Move mostly right, sometimes up/down
      final move = rand.nextInt(5);
      if (move < 3) {
        c += 1;
      } else if (move == 3 && r > 1) {
        r -= 1;
      } else if (r < rows - 2) {
        r += 1;
      } else {
        c += 1;
      }
      path.add([c, r]);
    }
    // End at lettuce position
    while (c < cols - 1) {
      c++;
      path.add([c, r]);
    }
    return path;
  }

  /// Convert grid position to isometric screen position (top-left of tile)
  static Offset gridToScreen(int col, int row, Offset origin) {
    final x = origin.dx + (col - row) * (tileWidth / 2);
    final y = origin.dy + (col + row) * (tileHeight / 2);
    return Offset(x, y);
  }

  /// Lettuce is at the end of the path
  List<int> get lettucePosition => spawnPath.last;

  /// Spawn position is the start of the path
  List<int> get spawnPosition => spawnPath.first;
}
