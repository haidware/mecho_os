class CommunityPostModel {
  final String id;
  final String userId;
  final String userName;
  final String? userInitials;
  final String topic;
  final String content;
  final String? mediaUrl;
  final String? mediaType;
  final DateTime createdAt;
  final int commentCount;
  int likeCount;
  bool isLiked;

  CommunityPostModel({
    required this.id,
    required this.userId,
    required this.userName,
    this.userInitials,
    required this.topic,
    required this.content,
    this.mediaUrl,
    this.mediaType,
    required this.createdAt,
    this.commentCount = 0,
    this.likeCount = 0,
    this.isLiked = false,
  });

  factory CommunityPostModel.fromJson(Map<String, dynamic> json, String currentUserId) {
    final user = json['users'];
    String name = 'Unknown Mechanic';
    String initials = 'M';
    if (user != null) {
      name = user['full_name'] ?? 'Unknown Mechanic';
      initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase();
    }

    final likes = json['community_likes'] as List? ?? [];
    bool likedByMe = likes.any((l) => l['user_id'] == currentUserId);

    return CommunityPostModel(
      id: json['id'],
      userId: json['user_id'],
      userName: name,
      userInitials: initials,
      topic: json['topic'] ?? 'General Discussion',
      content: json['content'],
      mediaUrl: json['media_url'],
      mediaType: json['media_type'],
      createdAt: DateTime.parse(json['created_at']),
      commentCount: json['community_comments'] != null ? (json['community_comments'] as List).length : 0,
      likeCount: likes.length,
      isLiked: likedByMe,
    );
  }
}

class CommunityCommentModel {
  final String id;
  final String postId;
  final String userId;
  final String userName;
  final String? userInitials;
  final String content;
  final DateTime createdAt;
  final String? parentId;
  final List<CommunityCommentModel> replies;

  CommunityCommentModel({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.userInitials,
    required this.content,
    required this.createdAt,
    this.parentId,
    this.replies = const [],
  });

  factory CommunityCommentModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'];
    String name = 'Unknown Mechanic';
    String initials = 'M';
    if (user != null) {
      name = user['full_name'] ?? 'Unknown Mechanic';
      initials = name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join('').toUpperCase();
    }

    return CommunityCommentModel(
      id: json['id'],
      postId: json['post_id'],
      userId: json['user_id'],
      userName: name,
      userInitials: initials,
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      parentId: json['parent_id'],
    );
  }
}
