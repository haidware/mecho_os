import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../repositories/community_repository.dart';
import '../../../models/community_post_model.dart';

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final CommunityRepository _repository = CommunityRepository();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _postController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  List<CommunityPostModel> _posts = [];
  bool _isLoading = true;
  bool _isPosting = false;
  File? _selectedMedia;
  String? _mediaType;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  @override
  void dispose() {
    _topicController.dispose();
    _postController.dispose();
    super.dispose();
  }

  Future<void> _loadPosts() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final posts = await _repository.getPosts();
      if (mounted) {
        setState(() {
          _posts = posts;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading posts: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickMedia(bool isVideo) async {
    final XFile? media = isVideo 
        ? await _picker.pickVideo(source: ImageSource.gallery)
        : await _picker.pickImage(source: ImageSource.gallery);
        
    if (media != null) {
      setState(() {
        _selectedMedia = File(media.path);
        _mediaType = isVideo ? 'video' : 'image';
      });
    }
  }

  Future<void> _handleCreatePost() async {
    if (_topicController.text.trim().isEmpty || _postController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a topic and message.')));
      return;
    }
    
    setState(() => _isPosting = true);
    
    try {
      String? mediaUrl;
      if (_selectedMedia != null) {
        mediaUrl = await _repository.uploadMedia(_selectedMedia!, _mediaType!);
      }

      await _repository.createPost(
        topic: _topicController.text.trim(),
        content: _postController.text.trim(),
        mediaUrl: mediaUrl,
        mediaType: _mediaType,
      );

      _topicController.clear();
      _postController.clear();
      setState(() {
        _selectedMedia = null;
        _mediaType = null;
        _isPosting = false;
      });
      FocusScope.of(context).unfocus();
      await _loadPosts();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Shared with community!')));
    } catch (e) {
      setState(() => _isPosting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error posting: $e')));
    }
  }

  Future<void> _handleToggleLike(CommunityPostModel post) async {
    final originalLiked = post.isLiked;
    setState(() {
      post.isLiked = !post.isLiked;
      post.likeCount += post.isLiked ? 1 : -1;
    });

    try {
      await _repository.toggleLike(post.id, originalLiked);
    } catch (e) {
      // Revert if failed
      setState(() {
        post.isLiked = originalLiked;
        post.likeCount += originalLiked ? 1 : -1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Mechanic Community', 
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 18)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildPostInput(),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadPosts,
                    child: _posts.isEmpty 
                        ? const Center(child: Text('No posts yet. Be the first!', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _posts.length,
                            itemBuilder: (context, index) => _buildPostCard(_posts[index]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildPostInput() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _topicController,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            decoration: InputDecoration(
              hintText: "Topic (e.g. Engine Issues, Tools...)",
              hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8F9FC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _postController,
            maxLines: 2,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: "Write your message here...",
              hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
              filled: true,
              fillColor: const Color(0xFFF8F9FC),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMediaBtn(Icons.camera_alt_outlined, "Image", () => _pickMedia(false)),
              const SizedBox(width: 8),
              _buildMediaBtn(Icons.videocam_outlined, "Video", () => _pickMedia(true)),
              const Spacer(),
              if (_selectedMedia != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green, size: 16),
                      const SizedBox(width: 4),
                      Text(_mediaType == 'video' ? 'Video' : 'Image', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green)),
                      IconButton(onPressed: () => setState(() => _selectedMedia = null), icon: const Icon(Icons.cancel, size: 16, color: Colors.red)),
                    ],
                  ),
                ),
              ElevatedButton(
                onPressed: _isPosting ? null : _handleCreatePost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1D1DFF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  elevation: 0,
                ),
                child: _isPosting 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Post', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMediaBtn(IconData i, String l, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(color: const Color(0xFFF0F2FF), borderRadius: BorderRadius.circular(8)),
        child: Row(children: [Icon(i, size: 16, color: const Color(0xFF1D1DFF)), const SizedBox(width: 6), Text(l, style: const TextStyle(color: Color(0xFF1D1DFF), fontSize: 11, fontWeight: FontWeight.bold))]),
      ),
    );
  }

  Widget _buildPostCard(CommunityPostModel post) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 15)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: const Color(0xFFF8F9FC),
                child: Text(post.userInitials ?? 'M', style: const TextStyle(color: Color(0xFF1D1DFF), fontSize: 13, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.userName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    Text(DateFormat('MMM d, h:mm a').format(post.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz, color: Colors.grey),
            ],
          ),
          const SizedBox(height: 16),
          Text(post.topic, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1D1DFF))),
          const SizedBox(height: 8),
          Text(post.content, style: const TextStyle(fontSize: 14, height: 1.5, color: Colors.black87, fontWeight: FontWeight.w500)),
          
          if (post.mediaUrl != null) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: post.mediaType == 'image' 
                  ? Image.network(post.mediaUrl!, width: double.infinity, fit: BoxFit.cover)
                  : Container(
                      height: 200, width: double.infinity, color: Colors.black,
                      child: const Center(child: Icon(Icons.play_circle_fill, color: Colors.white, size: 50)),
                    ),
            ),
          ],

          const Divider(height: 32),
          Row(
            children: [
              InkWell(
                onTap: () => _handleToggleLike(post),
                child: Row(
                  children: [
                    Icon(
                      post.isLiked ? Icons.thumb_up : Icons.thumb_up_alt_outlined, 
                      size: 18, 
                      color: post.isLiked ? const Color(0xFF1D1DFF) : Colors.grey
                    ),
                    const SizedBox(width: 6),
                    Text('${post.likeCount}', style: TextStyle(color: post.isLiked ? const Color(0xFF1D1DFF) : Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              InkWell(
                onTap: () => _showComments(post),
                child: Row(
                  children: [
                    const Icon(Icons.chat_bubble_outline, size: 18, color: Colors.grey),
                    const SizedBox(width: 6),
                    Text('${post.commentCount}', style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(Icons.share_outlined, size: 18, color: Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  void _showComments(CommunityPostModel post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(post: post, repository: _repository),
    ).then((_) => _loadPosts());
  }
}

class _CommentsSheet extends StatefulWidget {
  final CommunityPostModel post;
  final CommunityRepository repository;
  const _CommentsSheet({required this.post, required this.repository});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  List<CommunityCommentModel> _comments = [];
  bool _isLoading = true;
  String? _replyingToId;
  String? _replyingToName;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    final allComments = await widget.repository.getComments(widget.post.id);
    
    // Structure comments into parent-child relationships
    Map<String, List<CommunityCommentModel>> repliesMap = {};
    List<CommunityCommentModel> parentComments = [];
    
    for (var c in allComments) {
      if (c.parentId == null) {
        parentComments.add(c);
      } else {
        repliesMap[c.parentId!] ??= [];
        repliesMap[c.parentId!]!.add(c);
      }
    }

    setState(() {
      _comments = parentComments.map((p) => CommunityCommentModel(
        id: p.id,
        postId: p.postId,
        userId: p.userId,
        userName: p.userName,
        userInitials: p.userInitials,
        content: p.content,
        createdAt: p.createdAt,
        replies: repliesMap[p.id] ?? [],
      )).toList();
      _isLoading = false;
    });
  }

  Future<void> _handleSendComment() async {
    if (_commentController.text.trim().isEmpty) return;
    final content = _commentController.text.trim();
    _commentController.clear();
    
    final parentId = _replyingToId;
    setState(() {
      _replyingToId = null;
      _replyingToName = null;
    });

    await widget.repository.createComment(widget.post.id, content, parentId: parentId);
    _loadComments();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              children: [
                const Text('Comments', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _comments.isEmpty 
                    ? const Center(child: Text('No comments yet. Start the dialogue!', style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: _comments.length,
                        itemBuilder: (context, index) => _buildCommentGroup(_comments[index]),
                      ),
          ),
          if (_replyingToId != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFF0F2FF),
              child: Row(
                children: [
                  Text('Replying to $_replyingToName', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D1DFF))),
                  const Spacer(),
                  IconButton(
                    onPressed: () => setState(() { _replyingToId = null; _replyingToName = null; }),
                    icon: const Icon(Icons.cancel, size: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Colors.grey.shade100)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    autofocus: _replyingToId != null,
                    decoration: InputDecoration(
                      hintText: _replyingToId != null ? "Write a reply..." : "Add your professional advice...",
                      hintStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey),
                      filled: true,
                      fillColor: const Color(0xFFF8F9FC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                CircleAvatar(
                  backgroundColor: const Color(0xFF1D1DFF),
                  child: IconButton(
                    onPressed: _handleSendComment,
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentGroup(CommunityCommentModel comment) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(comment, isReply: false),
        ...comment.replies.map((r) => Padding(
          padding: const EdgeInsets.only(left: 32),
          child: _buildCommentItem(r, isReply: true),
        )),
      ],
    );
  }

  Widget _buildCommentItem(CommunityCommentModel comment, {required bool isReply}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: isReply ? 12 : 16,
            backgroundColor: const Color(0xFFF0F2FF),
            child: Text(comment.userInitials ?? 'M', style: TextStyle(color: const Color(0xFF1D1DFF), fontSize: isReply ? 9 : 11, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(comment.userName, style: TextStyle(fontWeight: FontWeight.w900, fontSize: isReply ? 12 : 14)),
                    const SizedBox(width: 8),
                    Text(DateFormat('h:mm a').format(comment.createdAt), style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.content, style: TextStyle(fontSize: isReply ? 12 : 14, height: 1.4, color: Colors.black87, fontWeight: FontWeight.w500)),
                if (!isReply)
                  TextButton(
                    onPressed: () => setState(() {
                      _replyingToId = comment.id;
                      _replyingToName = comment.userName;
                    }),
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 30), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('Reply', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF1D1DFF))),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
