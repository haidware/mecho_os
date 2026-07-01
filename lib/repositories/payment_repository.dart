import 'package:supabase_flutter/supabase_flutter.dart';

class PaymentRepository {
  final _supabase = Supabase.instance.client;

  Future<void> recordPayment({
    required String checkinId,
    required String workshopId,
    required String activityDescription,
    required double amount,
    bool markCompleted = true,
    String paymentStatus = 'full',
  }) async {
    // 1. Record payment
    await _supabase.from('payments').insert({
      'checkin_id': checkinId,
      'workshop_id': workshopId,
      'amount': amount,
      'payment_status': paymentStatus,
      'created_at': DateTime.now().toIso8601String(),
    });

    // 2. Update checkin status only if markCompleted is true
    if (markCompleted) {
      await _supabase.from('checkins').update({
        'status': 'completed',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', checkinId);
    }

    // 3. Log Activity
    await _supabase.from('activities').insert({
      'workshop_id': workshopId,
      'description': activityDescription,
      'metadata': {
        'checkin_id': checkinId,
        'action': 'payment',
        'amount': amount,
        'type': paymentStatus,
      },
    });
  }
}
