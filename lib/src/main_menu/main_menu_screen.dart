import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../style/button.dart';
import '../style/delayed_appear.dart';
import '../style/palette.dart';
import '../style/responsive_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.watch<Palette>();

    return Scaffold(
      backgroundColor: palette.redPen,
      body: ResponsiveScreen(
        topMessageArea: Center(
          child: Text(
            'Tic Tac Toe',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Permanent Marker',
              fontSize: 55,
              height: 1,
            ),
          ),
        ),
        mainAreaProminence: 0.45,
        squarishMainArea: DelayedAppear(
          ms: 1000,
          child: Center(
            child: Transform.scale(
              scale: 1.2,
              child: Image.asset(
                'assets/images/main-menu.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        rectangularMenuArea: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DelayedAppear(
              ms: 800,
              child: ElevatedButton(
                onPressed: () {
                  GoRouter.of(context).go('/play');
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 60),
                ),
                child: const Text(
                  'Play',
                  style: TextStyle(
                    fontFamily: 'Permanent Marker',
                    fontSize: 35,
                    height: 1,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            DelayedAppear(
              ms: 200,
              child: Button(
                onPressed: () {
                  GoRouter.of(context).go('/settings');
                },
                child: Text('Settings'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
