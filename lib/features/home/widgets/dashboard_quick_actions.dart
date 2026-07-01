import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/constants/app_colors.dart';

class DashboardQuickActions extends StatelessWidget {
  const DashboardQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final actions = [
      {'label': 'New Vehicle\nCheck-in', 'icon': Icons.add_circle_outline, 'route': AppRoutes.vehicleCheckin},
      {'label': 'New\nInspection', 'icon': Icons.assignment_outlined, 'route': AppRoutes.inspection},
      {'label': 'View\nApprovals', 'icon': Icons.check_circle_outline, 'route': AppRoutes.approval},
      {'label': 'Record\nPayment', 'icon': Icons.payments, 'route': AppRoutes.payments},
      {'label': 'Contact\nBook', 'icon': Icons.contact_phone_outlined, 'route': AppRoutes.customers},
      {'label': 'Maintenance\nCalendar', 'icon': Icons.calendar_month_outlined, 'route': AppRoutes.maintenance},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Text('Quick Actions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: actions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              return InkWell(
                onTap: () => Navigator.pushNamed(context, actions[index]['route'] as String),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade100),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10
                      )
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(actions[index]['icon'] as IconData, color: AppColors.primary, size: 28),
                      const SizedBox(height: 10),
                      Text(
                        actions[index]['label'] as String,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, height: 1.2),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}