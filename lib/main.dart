import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/app_routes.dart';

void main() async {
  // Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) usePathUrlStrategy();

  final browserRoute =
      WidgetsBinding.instance.platformDispatcher.defaultRouteName;
  String initialRoute =
      browserRoute == AppRoutes.root ? AppRoutes.login : browserRoute;

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://wtjzipfgikgawamlgymr.supabase.co',
      anonKey:
          'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0anppcGZnaWtnYXdhbWxneW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2OTM1MzIsImV4cCI6MjA5ODI2OTUzMn0.QbiDDH8KhXGHTCUJlZZLouiD7l7ZvKhTUtbXJCQR0W8',
    ).timeout(const Duration(seconds: 10));

    debugPrint("Supabase ready");

    // Check for existing session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null &&
        !{
          AppRoutes.admin,
          AppRoutes.sparePartsSellerSignup,
          AppRoutes.notifications,
          AppRoutes.partRequestThread,
          AppRoutes.partRequestChat,
        }.contains(browserRoute)) {
      final user = await Supabase.instance.client
          .from('users')
          .select('role,status')
          .eq('id', session.user.id)
          .maybeSingle();
      if (user?['status'] == 'active' && user?['role'] == 'spare_part_seller') {
        initialRoute = AppRoutes.sparePartsSeller;
        debugPrint(
            'Existing seller session found. Routing to seller requests.');
      } else if (user?['status'] == 'active' &&
          {'workshop_owner', 'staff'}.contains(user?['role'])) {
        initialRoute = AppRoutes.home;
        debugPrint('Existing session found. Routing by account role.');
      } else {
        initialRoute = AppRoutes.login;
      }
    }
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }

  runApp(MechoApp(initialRoute: initialRoute));
}
