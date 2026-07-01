import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_post_model.dart';

class CommunityRepository {
  final _supabase = Supabase.instance.client;

  Future<List<CommunityPostModel>> getPosts() async {
    final currentUserId = _supabase.auth.currentUser?.id ?? '';
    final response = await _supabase
        .from('community_posts')
        .select('*, users(full_name), community_comments(id), community_likes(user_id)')
        .order('created_at', ascending: false);

    return (response as List).map((json) => CommunityPostModel.fromJson(json, currentUserId)).toList();
  }

  Future<String?> uploadMedia(File file, String type) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$type';
      final path = 'community/$fileName';
      
      await _supabase.storage.from('mecho_assets').upload(
        path,
        file,
        fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
      );

      return _supabase.storage.from('mecho_assets').getPublicUrl(path);
    } catch (e) {
      print('Community Media Upload Error: $e');
      return null;
    }
  }

  Future<void> createPost({
    required String topic,
    required String content,
    String? mediaUrl,
    String? mediaType,
  }) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('community_posts').insert({
      'user_id': user.id,
      'topic': topic,
      'content': content,
      'media_url': mediaUrl,
      'media_type': mediaType,
    });
  }

  Future<void> toggleLike(String postId, bool currentlyLiked) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    if (currentlyLiked) {
      await _supabase
          .from('community_likes')
          .delete()
          .match({'post_id': postId, 'user_id': user.id});
    } else {
      await _supabase.from('community_likes').insert({
        'post_id': postId,
        'user_id': user.id,
      });
    }
  }

  Future<List<CommunityCommentModel>> getComments(String postId) async {
    final response = await _supabase
        .from('community_comments')
        .select('*, users(full_name)')
        .eq('post_id', postId)
        .order('created_at', ascending: true);

    return (response as List).map((json) => CommunityCommentModel.fromJson(json)).toList();
  }

  Future<void> createComment(String postId, String content, {String? parentId}) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    await _supabase.from('community_comments').insert({
      'post_id': postId,
      'user_id': user.id,
      'content': content,
      'parent_id': parentId,
    });
  }
}
