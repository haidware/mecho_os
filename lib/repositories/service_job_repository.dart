import 'package:supabase_flutter/supabase_flutter.dart';

class ServiceJobRepository {
  final _supabase = Supabase.instance.client;

  Future<void> updateJobStatus({
    required String checkinId,
    required String workshopId,
    required String status,
    required String vehicleInfo,
  }) async {
    await _supabase.from('checkins').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', checkinId);

    await _supabase.from('activities').insert({
      'workshop_id': workshopId,
      'description': '$vehicleInfo - $status',
      'metadata': {
        'checkin_id': checkinId,
        'action': 'status_update',
        'status': status,
      },
    });
  }

  Future<void> saveServiceJobData({
    required String checkinId,
    required String workshopId,
    required String activityDescription,
    required String status,
    required List<Map<String, dynamic>> serviceItems,
  }) async {
    await _supabase.from('checkins').update({
      'status': status,
      'service_items': serviceItems,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', checkinId);

    await _supabase.from('activities').insert({
      'workshop_id': workshopId,
      'description': activityDescription,
      'metadata': {
        'checkin_id': checkinId,
        'action': 'service_update',
        'status': status,
      },
    });
  }
}
