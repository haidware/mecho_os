import 'package:supabase_flutter/supabase_flutter.dart';

class ReportsRepository {
  final _supabase = Supabase.instance.client;

  Future<String?> _getWorkshopId() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;

    final userResponse = await _supabase
        .from('users')
        .select('workshop_id')
        .eq('id', user.id)
        .maybeSingle();

    if (userResponse != null && userResponse['workshop_id'] != null) {
      return userResponse['workshop_id'];
    }

    final workshopResponse = await _supabase
        .from('workshops')
        .select('id')
        .eq('owner_id', user.id)
        .maybeSingle();

    if (workshopResponse != null) {
      await _supabase.from('users').update({'workshop_id': workshopResponse['id']}).eq('id', user.id);
      return workshopResponse['id'];
    }

    return null;
  }

  Future<Map<String, dynamic>> getAnalyticsForDate(DateTime date) async {
    final workshopId = await _getWorkshopId();
    if (workshopId == null) return {};

    final String dateStr = date.toIso8601String().split('T')[0];
    final String tomorrowStr = date.add(const Duration(days: 1)).toIso8601String().split('T')[0];

    // 1. Fetch all payments for the day with their status
    final revenueRes = await _supabase
        .from('payments')
        .select('amount, payment_status')
        .eq('workshop_id', workshopId)
        .gte('created_at', dateStr)
        .lt('created_at', tomorrowStr);

    double totalRevenue = 0;
    double totalDeposits = 0;
    double totalFullPayments = 0;

    if (revenueRes is List) {
      for (var row in revenueRes) {
        double amt = (row['amount'] as num).toDouble();
        totalRevenue += amt;
        
        if (row['payment_status'] == 'deposit') {
          totalDeposits += amt;
        } else {
          totalFullPayments += amt;
        }
      }
    }

    // 2. Vehicles Serviced (Completed jobs on that day)
    final servicedRes = await _supabase
        .from('checkins')
        .select('id')
        .eq('workshop_id', workshopId)
        .eq('status', 'completed')
        .gte('updated_at', dateStr)
        .lt('updated_at', tomorrowStr);

    // 3. Pending Approvals
    final pendingRes = await _supabase
        .from('checkins')
        .select('id')
        .eq('workshop_id', workshopId)
        .eq('status', 'awaiting_approval');

    // 4. Average Order Value
    double avgValue = 0;
    if (revenueRes is List && revenueRes.isNotEmpty) {
      avgValue = totalRevenue / revenueRes.length;
    }

    // 5. Account History for the day
    final historyRes = await _supabase
        .from('activities')
        .select()
        .eq('workshop_id', workshopId)
        .gte('created_at', dateStr)
        .lt('created_at', tomorrowStr)
        .order('created_at', ascending: false);

    return {
      'total_revenue': totalRevenue,
      'total_deposits': totalDeposits,
      'total_full_payments': totalFullPayments,
      'vehicles_serviced': (servicedRes as List).length,
      'pending_approvals': (pendingRes as List).length,
      'avg_order_value': avgValue,
      'history': historyRes,
    };
  }
}
