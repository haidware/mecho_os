import 'package:supabase_flutter/supabase_flutter.dart';

class ApprovalRepository {
  final _supabase = Supabase.instance.client;

  Future<void> saveApprovalData({
    required String checkinId,
    required String workshopId,
    required String activityDescription,
    required List<Map<String, dynamic>> items,
  }) async {
    // 1. Update checkin status and save approval items
    await _supabase.from('checkins').update({
      'status': 'approved',
      'approval_items': items,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', checkinId);

    // 2. Log Activity
    await _supabase.from('activities').insert({
      'workshop_id': workshopId,
      'description': activityDescription,
      'metadata': {
        'checkin_id': checkinId,
        'action': 'approval',
      },
    });
  }
}
