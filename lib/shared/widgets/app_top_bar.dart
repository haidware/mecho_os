import 'package:flutter/material.dart';
import 'mecho_logo.dart';

class AppTopBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool showLogo;
  const AppTopBar({super.key, this.title, this.showLogo = false});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: showLogo ? const MechoLogo(height: 40) : (title != null ? Text(title!) : null),
      centerTitle: true,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
