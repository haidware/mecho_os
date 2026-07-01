import 'package:flutter/material.dart';
import '../../../core/constants/app_assets.dart';

class AuthBackground extends StatelessWidget {
  final Widget child;
  const AuthBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: Stack(
        children: [
          IgnorePointer(
            child: Stack(
              children: [
                Positioned(
                  top: 40,
                  left: 0,
                  child: Opacity(
                    opacity: 0.4, // Reduced opacity for smoother rendering
                    child: Image.asset(
                      AppAssets.garageLeft,
                      width: MediaQuery.of(context).size.width * 0.45,
                    ),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 0,
                  child: Opacity(
                    opacity: 0.4,
                    child: Image.asset(
                      AppAssets.garageRight,
                      width: MediaQuery.of(context).size.width * 0.45,
                    ),
                  ),
                ),
                // Optimized Gradient
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.1),
                          Colors.white.withOpacity(0.9),
                          Colors.white,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SafeArea(child: child),
        ],
      ),
    );
  }
}