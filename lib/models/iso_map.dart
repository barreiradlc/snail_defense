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
  int cols;
  int rows;
  late List<List<MapTile>> tiles;
  late List<List<int>> spawnPath; // list of [col, row] waypoints

  static const tileWidth = 64.0;
  static const tileHeight = 32.0;

  IsometricMap({this.cols = 6, this.rows = 6}) {
    _generate();
  }

  TileType _randomTileType(Random rand) {
    final noise = rand.nextDouble();
    if (noise < 0.05) return TileType.water;
    if (noise < 0.25) return TileType.dirt;
    return TileType.grass;
  }

  void _generate() {
    final rand = Random();
    tiles = List.generate(
      rows,
      (r) => List.generate(
        cols,
        (c) => MapTile(gridX: c, gridY: r, type: _randomTileType(rand)),
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

  /// Grows the map by one column or one row (random), preserving the existing path.
  /// When a column is added the path is extended to reach the new last column.
  /// When a row is added only terrain expands; the path is unchanged.
  void grow() {
    final rand = Random();

    if (rand.nextBool()) {
      // Add a column on the right
      cols++;
      for (int r = 0; r < rows; r++) {
        tiles[r].add(MapTile(
          gridX: cols - 1,
          gridY: r,
          type: _randomTileType(rand),
        ));
      }
      // Extend the existing path to reach the new last column
      var c = spawnPath.last[0];
      var r = spawnPath.last[1];
      while (c < cols - 1) {
        final move = rand.nextInt(5);
        if (move < 3 || c >= cols - 2) {
          c += 1;
        } else if (move == 3 && r > 1) {
          r -= 1;
        } else if (r < rows - 2) {
          r += 1;
        } else {
          c += 1;
        }
        spawnPath.add([c, r]);
        tiles[r][c] = MapTile(gridX: c, gridY: r, type: TileType.path);
      }
    } else {
      // Add a row at the bottom — terrain only, path stays the same
      rows++;
      tiles.add(List.generate(
        cols,
        (c) => MapTile(gridX: c, gridY: rows - 1, type: _randomTileType(rand)),
      ));
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
