import 'package:flutter/material.dart';
import '../../../core/constants/app_routes.dart';

class NavigationListScreen extends StatelessWidget {
  const NavigationListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MECHO ARCHITECTURE'),
        centerTitle: true,
        elevation: 0,
      ),
      body: ListView(
        children: [
          _buildModule(context, 'Authentication', Icons.lock_outline, [
            _buildItem(context, 'Login Screen', AppRoutes.login),
            _buildItem(context, 'Register Screen', AppRoutes.register),
          ]),
          _buildModule(context, 'Dashboard', Icons.dashboard_outlined, [
            _buildItem(context, 'Home Dashboard', AppRoutes.home),
          ]),
          _buildModule(context, 'Vehicles', Icons.directions_car_outlined, [
            _buildItem(context, 'Vehicle Check-In', AppRoutes.vehicleCheckin),
            _buildItem(context, 'Vehicle Details', AppRoutes.vehicleDetails),
            _buildItem(context, 'Vehicle History', AppRoutes.vehicleHistory),
            _buildItem(context, 'Active Vehicles', AppRoutes.activeVehicles),
          ]),
          _buildModule(context, 'Customers', Icons.people_outline, [
            _buildItem(context, 'Customers List', AppRoutes.customers),
            _buildItem(context, 'Customer Details', AppRoutes.customerDetails),
            _buildItem(context, 'Add Customer', AppRoutes.addCustomer),
            _buildItem(context, 'Contact Book', AppRoutes.contactBook),
          ]),
          _buildModule(context, 'Inspections', Icons.assignment_outlined, [
            _buildItem(context, 'All Inspections', AppRoutes.inspection),
            _buildItem(context, 'New Inspection', AppRoutes.newInspection),
            _buildItem(context, 'Inspection Details', AppRoutes.inspectionDetails),
            _buildItem(context, 'Inspection Reports', AppRoutes.inspectionReports),
          ]),
          _buildModule(context, 'Approvals', Icons.thumb_up_outlined, [
            _buildItem(context, 'All Approvals', AppRoutes.approval),
            _buildItem(context, 'Approval Details', AppRoutes.approvalDetails),
            _buildItem(context, 'Pending Approvals', AppRoutes.pendingApprovals),
          ]),
          _buildModule(context, 'Quotations', Icons.description_outlined, [
            _buildItem(context, 'All Quotations', AppRoutes.quotation),
            _buildItem(context, 'Quotation Preview', AppRoutes.quotationPreview),
            _buildItem(context, 'Quotation Details', AppRoutes.quotationDetails),
            _buildItem(context, 'Quotation History', AppRoutes.quotationHistory),
          ]),
          _buildModule(context, 'Services', Icons.settings_suggest_outlined, [
            _buildItem(context, 'Service Jobs', AppRoutes.service),
            _buildItem(context, 'Service Details', AppRoutes.serviceJobDetails),
            _buildItem(context, 'Completed Services', AppRoutes.completedServices),
          ]),
          _buildModule(context, 'Payments', Icons.payments_outlined, [
            _buildItem(context, 'Invoices', AppRoutes.invoice),
            _buildItem(context, 'Invoice Preview', AppRoutes.invoicePreview),
            _buildItem(context, 'Receipts', AppRoutes.receipts),
            _buildItem(context, 'Payments History', AppRoutes.payments),
            _buildItem(context, 'Revenue Summary', AppRoutes.revenueSummary),
          ]),
          _buildModule(context, 'Maintenance', Icons.calendar_month_outlined, [
            _buildItem(context, 'Maintenance Screen', AppRoutes.maintenance),
            _buildItem(context, 'Maintenance Details', AppRoutes.maintenanceDetails),
            _buildItem(context, 'Maintenance Calendar', AppRoutes.maintenanceCalendar),
            _buildItem(context, 'Maintenance Records', AppRoutes.maintenanceRecords),
            _buildItem(context, 'Reminder History', AppRoutes.reminderHistory),
          ]),
          _buildModule(context, 'Find A Mech', Icons.search_outlined, [
            _buildItem(context, 'Search Mechanic', AppRoutes.findMech),
            _buildItem(context, 'Garage Profile', AppRoutes.garageProfile),
            _buildItem(context, 'Ratings & Reviews', AppRoutes.ratingsReviews),
          ]),
          _buildModule(context, 'Subscriptions', Icons.card_membership_outlined, [
            _buildItem(context, 'Subscription Screen', AppRoutes.subscription),
            _buildItem(context, 'Current Plan', AppRoutes.currentPlan),
            _buildItem(context, 'Subscription History', AppRoutes.subscriptionHistory),
            _buildItem(context, 'Billing', AppRoutes.billing),
          ]),
          _buildModule(context, 'Profile', Icons.person_outline, [
            _buildItem(context, 'My Profile', AppRoutes.profile),
            _buildItem(context, 'Workshop Profile', AppRoutes.workshopProfile),
            _buildItem(context, 'Staff Management', AppRoutes.staffManagement),
            _buildItem(context, 'Bank Details', AppRoutes.bankDetails),
            _buildItem(context, 'Settings', AppRoutes.settings),
          ]),
          _buildModule(context, 'Notifications', Icons.notifications_none_outlined, [
            _buildItem(context, 'All Notifications', AppRoutes.notifications),
            _buildItem(context, 'Messages', AppRoutes.messages),
            _buildItem(context, 'Chat Screen', AppRoutes.chat),
            _buildItem(context, 'Activity History', AppRoutes.history),
          ]),
          _buildModule(context, 'Reports', Icons.bar_chart_outlined, [
            _buildItem(context, 'Reports Dashboard', AppRoutes.reportsDashboard),
            _buildItem(context, 'Vehicle Reports', AppRoutes.vehicleReports),
            _buildItem(context, 'Revenue Reports', AppRoutes.revenueReports),
          ]),
        ],
      ),
    );
  }

  Widget _buildModule(BuildContext context, String title, IconData icon, List<Widget> items) {
    return ExpansionTile(
      leading: Icon(icon, color: Colors.blueAccent),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      children: items,
    );
  }

  Widget _buildItem(BuildContext context, String title, String route) {
    return ListTile(
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
      onTap: () => Navigator.pushNamed(context, route),
    );
  }
}