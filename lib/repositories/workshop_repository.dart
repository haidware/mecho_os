import 'package:supabase_flutter/supabase_flutter.dart';

class WorkshopRepository {
  final _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> getWorkshopDetails(String userId) async {
    try {
      // 1. Get user profile
      final userDoc = await _supabase.from('users').select().eq('id', userId).maybeSingle();
      if (userDoc == null) return null;

      // 2. Try to get workshop_id from profile
      dynamic workshopId = userDoc['workshop_id'];

      // 3. Robust fallback: Search workshops table by owner_id if link is missing or if the linked workshop doesn't exist
      Map<String, dynamic>? workshopDoc;
      
      if (workshopId != null) {
        workshopDoc = await _supabase.from('workshops').select().eq('id', workshopId).maybeSingle();
      }

      if (workshopDoc == null) {
        workshopDoc = await _supabase.from('workshops').select().eq('owner_id', userId).maybeSingle();
        
        if (workshopDoc != null) {
          // Repair the link in the users table for future speed
          await _supabase.from('users').update({'workshop_id': workshopDoc['id']}).eq('id', userId);
        }
      }

      return {
        'user': userDoc,
        'workshop': workshopDoc,
      };
    } catch (e) {
      print('Workshop Repository Error: $e');
      return null;
    }
  }
}
