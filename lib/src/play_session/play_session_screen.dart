import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart' hide Level;
import 'package:provider/provider.dart';

import '../ai/ai_opponent.dart';
import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import '../game_internals/board_state.dart';
import '../level_selection/levels.dart';
import '../settings/custom_name_dialog.dart';
import '../settings/settings.dart';
import '../style/confetti.dart';
import '../style/delayed_appear.dart';
import '../style/palette.dart';
import 'game_board.dart';
import 'hint_snackbar.dart';

class PlaySessionScreen extends StatefulWidget {
  final GameLevel level;

  const PlaySessionScreen(this.level, {super.key});

  @override
  State<PlaySessionScreen> createState() => _PlaySessionScreenState();
}

class _PlaySessionScreenState extends State<PlaySessionScreen> {
  static final _log = Logger('PlaySessionScreen');

  static const _celebrationDuration = Duration(milliseconds: 2000);

  static const _preCelebrationDuration = Duration(milliseconds: 500);

  final StreamController<void> _resetHint = StreamController.broadcast();

  final bool _duringCelebration = false;

  late DateTime _startOfPlay;

  late final AiOpponent opponent;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final palette = context.watch<Palette>();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (context) {
            final state = BoardState.clean(
              widget.level.setting,
              opponent,
            );

            Future.delayed(const Duration(milliseconds: 500)).then((_) {
              if (!mounted) return;
              state.initialize();
            });

            state.playerWon.addListener(_playerWon);
            state.aiOpponentWon.addListener(_aiOpponentWon);

            return state;
          },
        ),
      ],
      child: IgnorePointer(
        ignoring: _duringCelebration,
        child: Scaffold(
          backgroundColor: palette.backgroundPlaySession,
          body: Stack(
            children: [
              ValueListenableBuilder<String>(
                valueListenable: settings.playerName,
                builder: (context, playerName, child) {
                  final textStyle = DefaultTextStyle.of(context).style.copyWith(
                        fontFamily: 'Permanent Marker',
                        fontSize: 24,
                        color: palette.redPen,
                      );

                  return _ResponsivePlaySessionScreen(
                    playerName: TextSpan(
                      text: playerName,
                      style: textStyle,
                      recognizer: TapGestureRecognizer()
                        ..onTap = () => showCustomNameDialog(context),
                    ),
                    opponentName: TextSpan(
                      text: opponent.name,
                      style: textStyle,
                      recognizer: TapGestureRecognizer()
                        // TODO: implement
                        //       (except maybe not, because in user testing,
                        //        nobody has ever touched this)
                        ..onTap = () => _log
                            .severe('Tapping opponent name NOT IMPLEMENTED'),
                    ),
                    mainBoardArea: Center(
                      child: DelayedAppear(
                        ms: ScreenDelays.fourth,
                        delayStateCreation: true,
                        onDelayFinished: () {
                          final audioController =
                              context.read<AudioController>();
                          audioController.playSfx(SfxType.swishSwish);
                        },
                        child: Board(
                          key: const Key('main board'),
                          setting: widget.level.setting,
                        ),
                      ),
                    ),
                    restartButtonArea: _RestartButton(
                      _resetHint.stream,
                      onTap: () {
                        final audioController = context.read<AudioController>();
                        audioController.playSfx(SfxType.buttonTap);

                        context.read<BoardState>().clearBoard();
                        _startOfPlay = DateTime.now();

                        Future.delayed(const Duration(milliseconds: 200))
                            .then((_) {
                          if (!mounted) return;
                          context.read<BoardState>().initialize();
                        });

                        Future.delayed(const Duration(milliseconds: 1000))
                            .then((_) {
                          if (!mounted) return;
                          showHintSnackbar(context);
                        });
                      },
                    ),
                    backButtonArea: DelayedAppear(
                      ms: ScreenDelays.first,
                      child: InkResponse(
                        onTap: () {
                          final audioController =
                              context.read<AudioController>();
                          audioController.playSfx(SfxType.buttonTap);

                          GoRouter.of(context).pop();
                        },
                        child: Tooltip(
                          message: 'Back',
                          child: Image.asset('assets/images/back.png'),
                        ),
                      ),
                    ),
                    settingsButtonArea: DelayedAppear(
                      ms: ScreenDelays.third,
                      child: InkResponse(
                        onTap: () {
                          final audioController =
                              context.read<AudioController>();
                          audioController.playSfx(SfxType.buttonTap);

                          GoRouter.of(context).push('/settings');
                        },
                        child: Tooltip(
                          message: 'Settings',
                          child: Image.asset('assets/images/settings.png'),
                        ),
                      ),
                    ),
                  );
                },
              ),
              SizedBox.expand(
                child: Visibility(
                  visible: _duringCelebration,
                  child: IgnorePointer(
                    child: Confetti(
                      isStopped: !_duringCelebration,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();

    opponent = widget.level.aiOpponentBuilder(widget.level.setting);
    _log.info('$opponent enters the fray');

    _startOfPlay = DateTime.now();
  }

  void _aiOpponentWon() {
    // "Pop" the reset button to remind the player what to do next.
    _resetHint.add(null);
  }

  void _playerWon() async {}
}

class _RestartButton extends StatefulWidget {
  final Stream<void> resetHint;

  final VoidCallback onTap;

  const _RestartButton(this.resetHint, {required this.onTap});

  @override
  State<_RestartButton> createState() => _RestartButtonState();
}

class _RestartButtonState extends State<_RestartButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    duration: const Duration(milliseconds: 1500),
    vsync: this,
  );

  StreamSubscription? _subscription;

  static final TweenSequence<double> _bump = TweenSequence([
    // A bit of delay.
    TweenSequenceItem(tween: Tween(begin: 1, end: 1), weight: 10),
    // Enlarge.
    TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.4)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 1),
    // Slowly go back to beginning.
    TweenSequenceItem(
        tween: Tween(begin: 1.4, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 3),
  ]);

  @override
  void initState() {
    super.initState();
    _subscription = widget.resetHint.listen(_handleResetHint);
  }

  @override
  void didUpdateWidget(covariant _RestartButton oldWidget) {
    _subscription?.cancel();
    _subscription = widget.resetHint.listen(_handleResetHint);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DelayedAppear(
      ms: ScreenDelays.fourth,
      child: InkResponse(
        onTap: widget.onTap,
        child: Column(
          children: [
            ScaleTransition(
              scale: _bump.animate(_controller),
              child: Image.asset('assets/images/restart.png'),
            ),
            const Text(
              'Restart',
              style: TextStyle(
                fontFamily: 'Permanent Marker',
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleResetHint(void _) {
    _controller.forward(from: 0);
  }
}

class _ResponsivePlaySessionScreen extends StatelessWidget {
  /// This is the "hero" of the screen. It's more or less square, and will
  /// be placed in the visual "center" of the screen.
  final Widget mainBoardArea;

  final Widget backButtonArea;

  final Widget settingsButtonArea;

  final Widget restartButtonArea;

  final TextSpan playerName;

  final TextSpan opponentName;

  /// How much bigger should the [mainBoardArea] be compared to the other
  /// elements.
  final double mainAreaProminence;

  const _ResponsivePlaySessionScreen({
    required this.mainBoardArea,
    required this.backButtonArea,
    required this.settingsButtonArea,
    required this.restartButtonArea,
    required this.playerName,
    required this.opponentName,
    // ignore: unused_element
    this.mainAreaProminence = 0.8,
  });

  Widget _buildVersusText(BuildContext context, TextAlign textAlign) {
    String versusText;
    switch (textAlign) {
      case TextAlign.start:
      case TextAlign.left:
      case TextAlign.right:
      case TextAlign.end:
        versusText = '\nversus\n';
        break;
      case TextAlign.center:
      case TextAlign.justify:
        versusText = ' versus ';
        break;
    }

    return DelayedAppear(
      ms: ScreenDelays.second,
      child: RichText(
          textAlign: textAlign,
          text: TextSpan(
            children: [
              playerName,
              TextSpan(
                text: versusText,
                style: DefaultTextStyle.of(context)
                    .style
                    .copyWith(fontFamily: 'Permanent Marker', fontSize: 18),
              ),
              opponentName,
            ],
          )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // This widget wants to fill the whole screen.
        final size = constraints.biggest;
        final padding = EdgeInsets.all(size.shortestSide / 30);

        if (size.height >= size.width) {
          // "Portrait" / "mobile" mode.
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: padding,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 45,
                        child: backButtonArea,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(
                            left: 15,
                            right: 15,
                            top: 5,
                          ),
                          child: _buildVersusText(context, TextAlign.center),
                        ),
                      ),
                      SizedBox(
                        width: 45,
                        child: settingsButtonArea,
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: (mainAreaProminence * 100).round(),
                child: SafeArea(
                  top: false,
                  bottom: false,
                  minimum: padding,
                  child: mainBoardArea,
                ),
              ),
              SafeArea(
                top: false,
                maintainBottomViewPadding: true,
                child: Padding(
                  padding: padding,
                  child: restartButtonArea,
                ),
              ),
            ],
          );
        } else {
          // "Landscape" / "tablet" mode.
          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                flex: 3,
                child: SafeArea(
                  right: false,
                  maintainBottomViewPadding: true,
                  child: Padding(
                    padding: padding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        backButtonArea,
                        Expanded(
                          child: _buildVersusText(context, TextAlign.start),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 7,
                child: SafeArea(
                  left: false,
                  right: false,
                  maintainBottomViewPadding: true,
                  minimum: padding,
                  child: mainBoardArea,
                ),
              ),
              Expanded(
                flex: 3,
                child: SafeArea(
                  left: false,
                  maintainBottomViewPadding: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Padding(
                        padding: padding,
                        child: settingsButtonArea,
                      ),
                      const Spacer(),
                      Padding(
                        padding: padding,
                        child: restartButtonArea,
                      )
                    ],
                  ),
                ),
              ),
            ],
          );
        }
      },
    );
  }
}
