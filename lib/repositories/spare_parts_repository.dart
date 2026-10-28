import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SparePartRequesterDetails {
  const SparePartRequesterDetails({
    required this.name,
    required this.phoneNumber,
    required this.location,
    required this.workshopId,
  });

  final String name;
  final String phoneNumber;
  final String location;
  final String? workshopId;
}

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

  Future<bool> isCurrentUserSeller() async {
    return hasActiveSellerAccount();
  }

  Future<SparePartRequesterDetails> getRequesterDetails() async {
    final userId = _userId;
    final profile = await _supabase
        .from('users')
        .select('full_name,phone_number,workshop_id,status')
        .eq('id', userId)
        .maybeSingle();
    if (profile?['status'] != 'active') {
      throw StateError(
        'An active mechanic account is required to submit a part request.',
      );
    }

    Map<String, dynamic>? workshop;
    final workshopId = profile?['workshop_id']?.toString();
    if (workshopId != null && workshopId.isNotEmpty) {
      workshop = await _supabase
          .from('workshops')
          .select('id,garage_name,phone_number,garage_address')
          .eq('id', workshopId)
          .maybeSingle();
    }
    workshop ??= await _supabase
        .from('workshops')
        .select('id,garage_name,phone_number,garage_address')
        .eq('owner_id', userId)
        .maybeSingle();

    final metadata = _supabase.auth.currentUser?.userMetadata ?? const {};
    String firstNonEmpty(Iterable<Object?> values, {String fallback = ''}) {
      for (final value in values) {
        final text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return fallback;
    }

    return SparePartRequesterDetails(
      name: firstNonEmpty([
        workshop?['garage_name'],
        profile?['full_name'],
      ]),
      phoneNumber: firstNonEmpty([
        workshop?['phone_number'],
        profile?['phone_number'],
      ]),
      location: firstNonEmpty([
        workshop?['garage_address'],
        metadata['garage_address'],
        metadata['location'],
        metadata['city'],
      ], fallback: 'Location not provided'),
      workshopId: workshop?['id']?.toString() ??
          (workshopId == null || workshopId.isEmpty ? null : workshopId),
    );
  }

  Future<String> createRequest({
    required String partName,
    required String condition,
    required String barcode,
    required String vehicle,
    required String position,
    required String description,
    required List<XFile> images,
  }) async {
    final userId = _userId;
    final requester = await getRequesterDetails();
    final workshopId = requester.workshopId;
    final request = await _supabase
        .from('spare_part_requests')
        .insert({
          'workshop_id':
              workshopId == null || workshopId.isEmpty ? null : workshopId,
          'mechanic_user_id': userId,
          'part_name': partName,
          'condition_requested': condition,
          'barcode': barcode.isEmpty ? null : barcode,
          'vehicle': vehicle.isEmpty ? null : vehicle,
          'position': position.isEmpty ? null : position,
          'description': description.isEmpty ? null : description,
          'mechanic_name': requester.name,
          'phone_number': requester.phoneNumber,
          'location': requester.location,
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
        final requestFolder = workshopId == null || workshopId.isEmpty
            ? requestId
            : '$workshopId/$requestId';
        final path =
            '$requestFolder/${DateTime.now().microsecondsSinceEpoch}_$index.$extension';
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
        .select(
          'id,request_id,seller_user_id,price,condition,location,seller_name,created_at,updated_at',
        )
        .eq('request_id', requestId)
        .order('price', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getMyOffer(String requestId) async {
    final response = await _supabase
        .from('spare_part_offers')
        .select(
          'id,request_id,seller_user_id,price,condition,location,seller_name,created_at,updated_at',
        )
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

  Stream<List<Map<String, dynamic>>> streamRequestMessages(String requestId) {
    return _supabase
        .from('spare_part_request_messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map((messages) => List<Map<String, dynamic>>.from(messages));
  }

  Future<void> sendRequestMessage({
    required String requestId,
    required String message,
  }) async {
    await _supabase.from('spare_part_request_messages').insert({
      'request_id': requestId,
      'sender_user_id': _userId,
      'message': message,
    });
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

  Stream<List<Map<String, dynamic>>> streamUnreadNotifications() {
    return _supabase
        .from('spare_part_notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', _userId)
        .map(
          (notifications) => List<Map<String, dynamic>>.from(
            notifications.where(
              (notification) => notification['read_at'] == null,
            ),
          ),
        );
  }

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final response = await _supabase
        .from('spare_part_notifications')
        .select(
          'id,request_id,seller_user_id,notification_type,title,body,created_at,read_at',
        )
        .eq('user_id', _userId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> markNotificationRead(String notificationId) async {
    await _supabase
        .from('spare_part_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId)
        .eq('user_id', _userId);
  }

  Future<void> markAllNotificationsRead() async {
    await _supabase
        .from('spare_part_notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('user_id', _userId)
        .isFilter('read_at', null);
  }

  Future<void> savePushSubscription(Map<String, dynamic> subscription) async {
    final endpoint = subscription['endpoint']?.toString();
    final keys = subscription['keys'];
    if (endpoint == null || endpoint.isEmpty || keys is! Map) {
      throw const FormatException(
          'The browser returned an incomplete push subscription.');
    }
    final p256dh = keys['p256dh']?.toString();
    final auth = keys['auth']?.toString();
    if (p256dh == null || p256dh.isEmpty || auth == null || auth.isEmpty) {
      throw const FormatException(
          'The browser returned an incomplete push subscription.');
    }

    await _supabase.from('spare_part_push_subscriptions').upsert(
      {
        'user_id': _userId,
        'endpoint': endpoint,
        'p256dh': p256dh,
        'auth': auth,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'endpoint',
    );
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
