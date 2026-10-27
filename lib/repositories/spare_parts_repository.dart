import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SparePartsRepository {
  static const _bucket = 'spare-part-requests';
  final _supabase = Supabase.instance.client;

  String get _userId {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw StateError('Please sign in to continue.');
    return userId;
  }

  String get currentUserId => _userId;

  Future<bool> hasActiveSellerAccount() async {
    final response = await _supabase
        .from('users')
        .select('role,status')
        .eq('id', _userId)
        .maybeSingle();
    return response?['role'] == 'spare_part_seller' &&
        response?['status'] == 'active';
  }

  Future<String> createRequest({
    required String partName,
    required String condition,
    required String barcode,
    required String vehicle,
    required String position,
    required String description,
    required String mechanicName,
    required String phoneNumber,
    required String location,
    required List<XFile> images,
  }) async {
    final userId = _userId;
    final profile = await _supabase
        .from('users')
        .select('workshop_id,role,status')
        .eq('id', userId)
        .maybeSingle();
    if (profile?['status'] != 'active' ||
        !{'workshop_owner', 'staff'}.contains(profile?['role'])) {
      throw StateError('An active workshop account is required to submit a request.');
    }

    var workshopId = profile?['workshop_id']?.toString();
    if (workshopId == null || workshopId.isEmpty) {
      final ownedWorkshop = await _supabase
          .from('workshops')
          .select('id')
          .eq('owner_id', userId)
          .maybeSingle();
      workshopId = ownedWorkshop?['id']?.toString();
    }
    if (workshopId == null || workshopId.isEmpty) {
      throw StateError('No workshop is linked to this account.');
    }

    final request = await _supabase
        .from('spare_part_requests')
        .insert({
          'workshop_id': workshopId,
          'mechanic_user_id': userId,
          'part_name': partName,
          'condition_requested': condition,
          'barcode': barcode.isEmpty ? null : barcode,
          'vehicle': vehicle.isEmpty ? null : vehicle,
          'position': position.isEmpty ? null : position,
          'description': description.isEmpty ? null : description,
          'mechanic_name': mechanicName,
          'phone_number': phoneNumber,
          'location': location,
          'status': 'draft',
          'image_paths': <String>[],
        })
        .select('id')
        .single();
    final requestId = request['id'].toString();
    final uploadedPaths = <String>[];

    try {
      for (var index = 0; index < images.length; index++) {
        final image = images[index];
        final imageBytes = await image.readAsBytes();
        final extension = _extensionFor(image);
        final path =
            '$workshopId/$requestId/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
        await _supabase.storage.from(_bucket).uploadBinary(
              path,
              imageBytes,
              fileOptions: FileOptions(
                contentType: image.mimeType ?? _mimeTypeFor(extension),
                upsert: false,
              ),
            );
        uploadedPaths.add(path);
      }

      await _supabase
          .from('spare_part_requests')
          .update({
            'image_paths': uploadedPaths,
            'status': 'open',
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', requestId)
          .select('id')
          .single();
      return requestId;
    } catch (error) {
      if (uploadedPaths.isNotEmpty) {
        try {
          await _supabase.storage.from(_bucket).remove(uploadedPaths);
        } catch (cleanupError) {
          debugPrint(
              'Could not remove incomplete request photos: $cleanupError');
        }
      }
      try {
        await _supabase
            .from('spare_part_requests')
            .delete()
            .eq('id', requestId);
      } catch (cleanupError) {
        debugPrint('Could not remove incomplete part request: $cleanupError');
      }
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMyRequests() async {
    final response = await _supabase
        .from('spare_part_requests')
        .select()
        .eq('mechanic_user_id', _userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Stream<List<Map<String, dynamic>>> streamOpenRequests() {
    return _supabase
        .from('spare_part_requests')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map(
          (requests) => List<Map<String, dynamic>>.from(
            requests.where((request) => request['status'] == 'open'),
          ),
        );
  }

  Future<Map<String, dynamic>> getRequest(String requestId) async {
    final response = await _supabase
        .from('spare_part_requests')
        .select()
        .eq('id', requestId)
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getOffers(String requestId) async {
    final response = await _supabase
        .from('spare_part_offers')
        .select()
        .eq('request_id', requestId)
        .order('price', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getMyOffer(String requestId) async {
    final response = await _supabase
        .from('spare_part_offers')
        .select()
        .eq('request_id', requestId)
        .eq('seller_user_id', _userId)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>> getMySellerProfile() async {
    final response = await _supabase
        .from('users')
        .select('full_name,phone_number')
        .eq('id', _userId)
        .single();
    return Map<String, dynamic>.from(response);
  }

  Future<List<Map<String, dynamic>>> getMyOffers() async {
    final response = await _supabase
        .from('spare_part_offers')
        .select(
          'id,price,condition,location,seller_name,request:spare_part_requests!inner(id,part_name,status,selected_offer_id,location,condition_requested)',
        )
        .eq('seller_user_id', _userId)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> submitOffer({
    required String requestId,
    required double price,
    required String condition,
    required String location,
    required String sellerName,
    required String phoneNumber,
  }) async {
    await _supabase.from('spare_part_offers').upsert(
      {
        'request_id': requestId,
        'seller_user_id': _userId,
        'price': price,
        'condition': condition,
        'location': location,
        'seller_name': sellerName,
        'phone_number': phoneNumber,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'request_id,seller_user_id',
    );
  }

  Future<void> acceptOffer({
    required String requestId,
    required String offerId,
  }) async {
    await _supabase.rpc('accept_spare_part_offer', params: {
      'p_request_id': requestId,
      'p_offer_id': offerId,
    });
  }

  Stream<List<Map<String, dynamic>>> streamChatMessages({
    required String requestId,
    required String sellerUserId,
  }) {
    return _supabase
        .from('spare_part_chat_messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map(
          (messages) => List<Map<String, dynamic>>.from(
            messages.where(
              (message) => message['seller_user_id'] == sellerUserId,
            ),
          ),
        );
  }

  Future<void> sendChatMessage({
    required String requestId,
    required String sellerUserId,
    required String message,
  }) async {
    await _supabase.from('spare_part_chat_messages').insert({
      'request_id': requestId,
      'seller_user_id': sellerUserId,
      'sender_user_id': _userId,
      'message': message,
    });
  }

  Future<List<String>> getSignedImageUrls(List<dynamic> paths) async {
    final urls = <String>[];
    for (final path in paths) {
      final response = await _supabase.storage
          .from(_bucket)
          .createSignedUrl(path.toString(), 3600);
      urls.add(response);
    }
    return urls;
  }

  String _extensionFor(XFile file) {
    final name = file.name;
    final dot = name.lastIndexOf('.');
    if (dot >= 0 && dot < name.length - 1) {
      return name.substring(dot + 1).toLowerCase();
    }
    return switch (file.mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      _ => 'jpg',
    };
  }

  String _mimeTypeFor(String extension) {
    return switch (extension) {
      'png' => 'image/png',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'gif' => 'image/gif',
      _ => 'image/jpeg',
    };
  }
}
