import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

class MechoLogo extends StatelessWidget {
  final double height;
  const MechoLogo({super.key, this.height = 120});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.logo,
      height: height,
      errorBuilder: (context, error, stackTrace) {
        return Icon(Icons.engineering, size: height * 0.8);
      },
    );
  }
}
