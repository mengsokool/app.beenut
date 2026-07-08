import 'package:flutter/material.dart';

class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: Image.asset(
          'assets/images/logo.png',
          width: 132,
          height: 132,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
