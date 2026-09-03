import 'package:flutter/material.dart';
import 'package:pickles_and_pies/util/images.dart';
import 'package:pickles_and_pies/util/dimensions.dart';

class SplashLoadingWidget extends StatelessWidget {
  const SplashLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF039D55), // Your primary brand color
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(Images.logo, height: 120), // Your app logo
            const SizedBox(height: Dimensions.paddingSizeLarge),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              strokeWidth: 3,
            ),
          ],
        ),
      ),
    );
  }
}