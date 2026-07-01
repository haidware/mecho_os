import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_model.dart';

class DashboardRepository {
  final _supabase = Supabase.instance.client;

  Future<String?> _getWorkshopId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    // 1. Check user profile for direct workshop_id link
    final userResponse = await _supabase
        .from('users')
        .select('workshop_id')
        .eq('id', user.id)
        .maybeSingle();

    if (userResponse != null && userResponse['workshop_id'] != null) {
      return userResponse['workshop_id'];
    }

    // 2. Fallback: Search workshops table where this user is the owner
    final workshopResponse = await _supabase
        .from('workshops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (workshopResponse != null) {
      // Repair the link in users table for future speed
      await _supabase.from('users').update({'workshop_id': workshopResponse['id']}).eq('id', user.id);
      return workshopResponse['id'];
    }

    return null;
  }

  Future<Map<String, dynamic>> getDashboardStats() async {
    final workshopId = await _getWorkshopId();
    if (workshopId == null) return {
      'vehicles_today': 0,
      'active_jobs': 0,
      'pending_approvals': 0,
      'revenue_today': 0.0,
    };

    final today = DateTime.now().toIso8601String().split('T')[0];

    // Vehicles Today
    final vehiclesToday = await _supabase
        .from('checkins')
        .select('id')
        .eq('workshop_id', workshopId)
        .gte('created_at', today);

    // Active Jobs (status != completed)
    final activeJobs = await _supabase
        .from('checkins')
        .select('id')
        .eq('workshop_id', workshopId)
        .neq('status', 'completed');

    // Pending Approvals
    final pendingApprovals = await _supabase
        .from('checkins')
        .select('id')
        .eq('workshop_id', workshopId)
        .eq('status', 'awaiting_approval');

    // Revenue Today
    final revenueToday = await _supabase
        .from('payments')
        .select('amount')
        .eq('workshop_id', workshopId)
        .gte('created_at', today);

    double totalRevenue = 0;
    if (revenueToday is List) {
      for (var row in revenueToday) {
        totalRevenue += (row['amount'] as num).toDouble();
      }
    }

    return {
      'vehicles_today': (vehiclesToday as List).length,
      'active_jobs': (activeJobs as List).length,
      'pending_approvals': (pendingApprovals as List).length,
      'revenue_today': totalRevenue,
    };
  }

  Future<List<Map<String, dynamic>>> getActiveVehicles() async {
    final workshopId = await _getWorkshopId();
    if (workshopId == null) return [];

    final response = await _supabase
        .from('checkins')
        .select('*, vehicles(*)')
        .eq('workshop_id', workshopId)
        .neq('status', 'completed')
        .order('updated_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<ActivityModel>> getRecentActivities() async {
    final workshopId = await _getWorkshopId();
    if (workshopId == null) return [];

    final response = await _supabase
        .from('activities')
        .select()
        .eq('workshop_id', workshopId)
        .order('created_at', ascending: false)
        .limit(10);

    return (response as List).map((json) => ActivityModel.fromJson(json)).toList();
  }
}
