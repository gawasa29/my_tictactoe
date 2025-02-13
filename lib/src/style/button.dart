import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../audio/audio_controller.dart';
import '../audio/sounds.dart';
import 'palette.dart';

class Button extends StatelessWidget {
  final Widget child;

  final VoidCallback? onPressed;

  final Color? textColor;

  final double fontSize;

  final SfxType soundEffect;

  const Button({
    super.key,
    required this.child,
    this.onPressed,
    this.textColor,
    this.fontSize = 32,
    this.soundEffect = SfxType.buttonTap,
  });

  void _handleTap(BuildContext context) {
    assert(onPressed != null, "Don't call _handleTap when onTap is null");

    final audioController = context.read<AudioController>();
    audioController.playSfx(soundEffect);

    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return ElevatedButton(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
        ),
        onPressed: onPressed == null ? null : () => _handleTap(context),
        child: DefaultTextStyle(
          style: TextStyle(
            fontFamily: 'Permanent Marker',
            fontSize: fontSize,
            color: onPressed != null ? textColor : palette.ink,
          ),
          child: child,
        ));
  }
}
