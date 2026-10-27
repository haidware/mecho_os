import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/constants/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'shared/placeholder_screen.dart';
import 'shared/widgets/add_to_home_screen_dialog.dart';
import 'features/navigation/screens/navigation_list_screen.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/auth/screens/register_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'features/customers/screens/customers_screen.dart';
import 'features/customers/screens/customer_details_screen.dart';
import 'features/customers/screens/add_customer_screen.dart';
import 'features/vehicles/screens/vehicle_checkin_screen.dart';
import 'features/vehicles/screens/vehicle_details_screen.dart';
import 'features/inspection/screens/inspection_screen.dart';
import 'features/inspection/screens/inspection_details_screen.dart';
import 'features/quotation/screens/quotation_screen.dart';
import 'features/quotation/screens/quotation_preview_screen.dart';
import 'features/approval/screens/approval_screen.dart';
import 'features/approval/screens/pending_approvals_screen.dart';
import 'features/approval/screens/approval_details_screen.dart';
import 'features/service/screens/service_screen.dart';
import 'features/service/screens/service_job_details_screen.dart';
import 'features/service/screens/receipt_preview_screen.dart';
import 'features/invoice/screens/invoice_screen.dart';
import 'features/invoice/screens/invoice_preview_screen.dart';
import 'features/payments/screens/record_payment_screen.dart';
import 'features/maintenance/screens/maintenance_screen.dart';
import 'features/maintenance/screens/maintenance_details_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/messages/screens/messages_screen.dart';
import 'features/messages/screens/chat_screen.dart';
import 'features/profile/screens/profile_screen.dart';
import 'features/profile/screens/bank_details_screen.dart';
import 'features/profile/screens/subscription_screen.dart';
import 'features/profile/screens/workshop_profile_screen.dart';
import 'features/profile/screens/payout_earnings_screen.dart';
import 'features/profile/screens/help_support_screen.dart';
import 'features/find_mech/screens/find_mech_requests_screen.dart';
import 'features/reports/screens/reports_screen.dart';
import 'features/profile/screens/settings_screen.dart';
import 'features/community/screens/community_screen.dart';

final ValueNotifier<Locale> appLocale = ValueNotifier(const Locale('en'));

class MechoApp extends StatefulWidget {
  final String initialRoute;
  const MechoApp({super.key, required this.initialRoute});

  @override
  State<MechoApp> createState() => _MechoAppState();
}

class _MechoAppState extends State<MechoApp> {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showAddToHomeScreenPrompt();
    });
  }

  Future<void> _showAddToHomeScreenPrompt() async {
    if (!kIsWeb) return;

    await WidgetsBinding.instance.endOfFrame;

    const promptAcknowledgedKey = 'add_to_home_screen_prompt_acknowledged';
    late final SharedPreferences preferences;
    try {
      preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(promptAcknowledgedKey) ?? false) return;
    } catch (error, stackTrace) {
      debugPrint('Could not read the home screen prompt preference: $error');
      debugPrintStack(stackTrace: stackTrace);
      return;
    }

    final promptContext = _navigatorKey.currentContext;
    if (promptContext == null || !mounted) return;

    if (!mounted || !promptContext.mounted) return;

    final acknowledged = await showDialog<bool>(
      context: promptContext,
      builder: (context) => const AddToHomeScreenDialog(),
    );

    if (acknowledged != true || !mounted) return;

    try {
      await preferences.setBool(promptAcknowledgedKey, true);
    } catch (error, stackTrace) {
      debugPrint('Could not save the home screen prompt preference: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale>(
      valueListenable: appLocale,
      builder: (context, locale, child) {
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Mecho OS',
          theme: AppTheme.lightTheme,
          initialRoute: widget.initialRoute,
          locale: locale,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en'),
            Locale('es'),
            Locale('el'),
            Locale('tr'),
          ],
          routes: {
            AppRoutes.login: (context) => const LoginScreen(),
            AppRoutes.register: (context) => const RegisterScreen(),
            AppRoutes.home: (context) => const HomeScreen(),
            AppRoutes.navigationList: (context) => const NavigationListScreen(),

            // Vehicles Module
            AppRoutes.vehicleCheckin: (context) => const VehicleCheckinScreen(),
            AppRoutes.vehicleDetails: (context) => const VehicleDetailsScreen(),
            AppRoutes.activeVehicles: (context) => const PlaceholderScreen(title: 'Active Vehicles'),
            AppRoutes.vehicleHistory: (context) => const PlaceholderScreen(title: 'Vehicle History'),

            // Inspection Module
            AppRoutes.inspection: (context) => const InspectionScreen(),
            AppRoutes.inspectionDetails: (context) => const InspectionDetailsScreen(),
            AppRoutes.newInspection: (context) => const PlaceholderScreen(title: 'New Inspection'),
            AppRoutes.inspectionReports: (context) => const PlaceholderScreen(title: 'Inspection Reports'),

            // Quotation Module
            AppRoutes.quotation: (context) => const QuotationScreen(),
            AppRoutes.quotationPreview: (context) => const QuotationPreviewScreen(),
            AppRoutes.quotationDetails: (context) => const PlaceholderScreen(title: 'Quotation Details'),
            AppRoutes.quotationHistory: (context) => const PlaceholderScreen(title: 'Quotation History'),

            // Approval Module
            AppRoutes.approval: (context) => const ApprovalScreen(),
            AppRoutes.approvalDetails: (context) => const ApprovalDetailsScreen(),
            AppRoutes.pendingApprovals: (context) => const NewApprovalsScreen(),

            // Service Module
            AppRoutes.service: (context) {
              final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
              final tabIndex = args?['tabIndex'] ?? 0;
              return ServiceScreen(initialTabIndex: tabIndex);
            },
            AppRoutes.serviceJobDetails: (context) => const ServiceJobDetailsScreen(),
            AppRoutes.completedServices: (context) => const PlaceholderScreen(title: 'Completed Services'),

            // Payments Module
            AppRoutes.invoice: (context) => const InvoiceScreen(),
            AppRoutes.invoicePreview: (context) => const InvoicePreviewScreen(),
            AppRoutes.receipts: (context) => const ReceiptPreviewScreen(),
            AppRoutes.payments: (context) => const RecordPaymentScreen(),
            AppRoutes.revenueSummary: (context) => const PayoutEarningsScreen(),

            // Customers Module
            AppRoutes.customers: (context) => const CustomersScreen(),
            AppRoutes.customerDetails: (context) => const CustomerDetailsScreen(),
            AppRoutes.addCustomer: (context) => const AddCustomerScreen(),
            AppRoutes.contactBook: (context) => const HelpSupportScreen(),

            // Maintenance Module
            AppRoutes.maintenance: (context) => const MaintenanceScreen(),
            AppRoutes.maintenanceDetails: (context) => const MaintenanceDetailsScreen(),
            AppRoutes.maintenanceCalendar: (context) => const PlaceholderScreen(title: 'Maintenance Calendar'),
            AppRoutes.maintenanceRecords: (context) => const PlaceholderScreen(title: 'Maintenance Records'),
            AppRoutes.reminderHistory: (context) => const PlaceholderScreen(title: 'Reminder History'),

            // Find A Mech Module
            AppRoutes.findMech: (context) => const FindMechRequestsScreen(),
            AppRoutes.garageProfile: (context) => const PlaceholderScreen(title: 'Garage Profile'),
            AppRoutes.ratingsReviews: (context) => const PlaceholderScreen(title: 'Ratings & Reviews'),

            // Subscriptions Module
            AppRoutes.subscription: (context) => const SubscriptionScreen(),
            AppRoutes.currentPlan: (context) => const PlaceholderScreen(title: 'Current Plan'),
            AppRoutes.subscriptionHistory: (context) => const PlaceholderScreen(title: 'Subscription History'),
            AppRoutes.billing: (context) => const PlaceholderScreen(title: 'Billing'),

            // Profile & Settings
            AppRoutes.profile: (context) => const ProfileScreen(),
            AppRoutes.workshopProfile: (context) => const WorkshopProfileScreen(),
            AppRoutes.staffManagement: (context) => const PlaceholderScreen(title: 'Staff Management'),
            AppRoutes.bankDetails: (context) => const BankDetailsScreen(),
            AppRoutes.settings: (context) => const SettingsScreen(),
            AppRoutes.community: (context) => const CommunityScreen(),

            // Reports
            AppRoutes.reportsDashboard: (context) => const ReportsScreen(),
            AppRoutes.vehicleReports: (context) => const PlaceholderScreen(title: 'Vehicle Reports'),
            AppRoutes.revenueReports: (context) => const PlaceholderScreen(title: 'Revenue Reports'),

            // Notifications & Chat
            AppRoutes.history: (context) => const HistoryScreen(),
            AppRoutes.notifications: (context) => const PlaceholderScreen(title: 'Notifications'),
            AppRoutes.messages: (context) => const MessagesScreen(),
            AppRoutes.chat: (context) => const ChatScreen(),
          },
        );
      },
    );
  }
}
