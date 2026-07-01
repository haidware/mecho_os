import 'package:flutter/material.dart';
import '../../core/constants/app_routes.dart';

class BottomNav extends StatelessWidget {
  final int currentIndex;
  const BottomNav({super.key, required this.currentIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFF1D1DFF),
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedFontSize: 10,
        unselectedFontSize: 10,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, height: 1.5),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, height: 1.5),
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == currentIndex) return;
          final routes = [
            AppRoutes.home,
            AppRoutes.vehicleCheckin,
            AppRoutes.inspection,
            AppRoutes.approval,
            AppRoutes.service
          ];
          Navigator.pushReplacementNamed(context, routes[index]);
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined, size: 24),
            activeIcon: Icon(Icons.home, size: 24),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.directions_car_outlined, size: 24),
            activeIcon: Icon(Icons.directions_car, size: 24),
            label: 'Check-In',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_outlined, size: 24),
            activeIcon: Icon(Icons.assignment, size: 24),
            label: 'Inspect',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.thumb_up_outlined, size: 24),
            activeIcon: Icon(Icons.thumb_up, size: 24),
            label: 'Approval',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_suggest_outlined, size: 24),
            activeIcon: Icon(Icons.settings_suggest, size: 24),
            label: 'Services',
          ),
        ],
      ),
    );
  }
}