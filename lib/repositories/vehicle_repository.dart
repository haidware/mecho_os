import 'package:supabase_flutter/supabase_flutter.dart';

class VehicleRepository {
  final _supabase = Supabase.instance.client;

  Future<void> registerVehicleCheckin({
    required Map<String, dynamic> vehicleData,
    required Map<String, dynamic> checkinData,
  }) async {
    // 1. Create or Update Vehicle
    final vehicleResponse = await _supabase
        .from('vehicles')
        .upsert(vehicleData)
        .select()
        .single();

    final vehicleId = vehicleResponse['id'];

    // 2. Create Checkin record
    await _supabase.from('checkins').insert({
      ...checkinData,
      'vehicle_id': vehicleId,
    });

    // 3. Log Activity
    await _supabase.from('activities').insert({
      'workshop_id': vehicleData['workshop_id'],
      'description': '${vehicleData['make']} ${vehicleData['model']} • ${vehicleData['customer_name']} - Checked In',
      'metadata': {
        'vehicle_id': vehicleId,
        'plate_number': vehicleData['plate_number'],
        'action': 'checkin',
      },
    });
  }
}
