import 'package:supabase_flutter/supabase_flutter.dart';

class InspectionRepository {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> findActiveCheckin(String query) async {
    // 1. Search vehicles table for the plate/vin and include their checkins
    // Handling multiple possible search formats (abd-454, abd_454)
    final sanitizedQuery = query.replaceAll('_', '-').trim();
    
    // Simplifed query to avoid 'foreignTable' which is causing SDK version issues
    final vehicleResult = await _supabase
        .from('vehicles')
        .select('*, checkins(*)')
        .or('plate_number.ilike.%$query%,vin.ilike.%$query%,plate_number.ilike.%$sanitizedQuery%')
        .maybeSingle();

    if (vehicleResult != null) {
      final List checkins = vehicleResult['checkins'] ?? [];
      
      if (checkins.isEmpty) return null;

      // Manually sort checkins by created_at descending to get the latest
      checkins.sort((a, b) {
        DateTime dateA = DateTime.parse(a['created_at']);
        DateTime dateB = DateTime.parse(b['created_at']);
        return dateB.compareTo(dateA);
      });

      // Find the latest active (not completed) checkin
      final activeCheckin = checkins.firstWhere(
        (c) => c['status'] != 'completed',
        orElse: () => checkins.first,
      );

      return {
        ...activeCheckin,
        'vehicles': vehicleResult,
      };
    }
    return null;
  }

  Future<void> saveInspectionData({
    required String checkinId,
    required String workshopId,
    required String activityDescription,
    required List<Map<String, dynamic>> items,
    String? estimatedMonthlyUsage,
  }) async {
    // 1. Update checkin status and save the checklist items
    await _supabase.from('checkins').update({
      'status': 'inspecting',
      'inspection_items': items,
      'estimated_monthly_usage': estimatedMonthlyUsage,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', checkinId);

    // 2. Log Activity for the dashboard feed
    await _supabase.from('activities').insert({
      'workshop_id': workshopId,
      'description': activityDescription,
      'metadata': {
        'checkin_id': checkinId,
        'action': 'inspection',
      },
    });
  }
}
