import 'dart:math';

import '../game_internals/board_state.dart';
import '../game_internals/tile.dart';
import 'ai_opponent.dart';

class RandomOpponent extends AiOpponent {
  const RandomOpponent(
    super.setting, {
    required this.name,
  });

  static final Random _random = Random();

  @override
  final String name;

  @override
  Tile chooseNextMove(BoardState state) {
    final options = <Tile>[];
    for (var x = 0; x < setting.m; x++) {
      for (var y = 0; y < setting.n; y++) {
        final tile = Tile(x, y);
        if (state.whoIsAt(tile) == Side.none) {
          options.add(tile);
        }
      }
    }

    return options[_random.nextInt(options.length)];
  }
}
