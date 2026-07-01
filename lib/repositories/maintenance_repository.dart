import 'package:supabase_flutter/supabase_flutter.dart';

class MaintenanceRepository {
  final _supabase = Supabase.instance.client;

  Future<void> scheduleMaintenance({
    required String checkinId,
    required String vehicleId,
    required String workshopId,
    required String partName,
    required int intervalMileage,
    required DateTime dueDate,
  }) async {
    // 1. Create maintenance record
    await _supabase.from('maintenance_schedules').insert({
      'checkin_id': checkinId,
      'vehicle_id': vehicleId,
      'workshop_id': workshopId,
      'service_item': partName,
      'interval_km': intervalMileage,
      'due_date': dueDate.toIso8601String(),
      'status': 'scheduled',
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Log Activity
    await _supabase.from('activities').insert({
      'workshop_id': workshopId,
      'description': 'Maintenance Scheduled: $partName',
      'metadata': {
        'vehicle_id': vehicleId,
        'action': 'maintenance_scheduled',
      },
    });
  }

  Future<List<Map<String, dynamic>>> getMaintenanceForCalendar(String workshopId) async {
    final response = await _supabase
        .from('maintenance_schedules')
        .select('*, vehicles(*)')
        .eq('workshop_id', workshopId)
        .order('due_date', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }
}
