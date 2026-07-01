import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageRepository {
  final _supabase = Supabase.instance.client;

  Future<String?> uploadVehiclePhoto(File file, String path) async {
    try {
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String fullPath = 'vehicle_photos/$path/$fileName';

      await _supabase.storage.from('mecho_assets').upload(
        fullPath,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      return _supabase.storage.from('mecho_assets').getPublicUrl(fullPath);
    } catch (e) {
      print('Error uploading photo: $e');
      return null;
    }
  }
}
