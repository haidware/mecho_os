import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'core/constants/app_routes.dart';

void main() async {
  // Ensure Flutter is ready
  WidgetsFlutterBinding.ensureInitialized();

  String initialRoute = AppRoutes.login;

  try {
    // Initialize Supabase
    await Supabase.initialize(
      url: 'https://wtjzipfgikgawamlgymr.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0anppcGZnaWtnYXdhbWxneW1yIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI2OTM1MzIsImV4cCI6MjA5ODI2OTUzMn0.QbiDDH8KhXGHTCUJlZZLouiD7l7ZvKhTUtbXJCQR0W8',
    ).timeout(const Duration(seconds: 10));
    
    debugPrint("Supabase ready");

    // Check for existing session
    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      initialRoute = AppRoutes.home;
      debugPrint("Existing session found. Routing to Home.");
    }
  } catch (e) {
    debugPrint("Supabase initialization error: $e");
  }

  runApp(MechoApp(initialRoute: initialRoute));
}
