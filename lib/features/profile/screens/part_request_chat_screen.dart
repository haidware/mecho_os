import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../repositories/spare_parts_repository.dart';

class PartRequestChatScreen extends StatefulWidget {
  final String requestId;
  final String sellerUserId;
  final String sellerName;

  const PartRequestChatScreen({
    super.key,
    required this.requestId,
    required this.sellerUserId,
    required this.sellerName,
  });

  @override
  State<PartRequestChatScreen> createState() => _PartRequestChatScreenState();
}

class _PartRequestChatScreenState extends State<PartRequestChatScreen> {
  final _repository = SparePartsRepository();
  final _messageController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _messages;
  bool _sending = false;
  String? _requestPartName;

  @override
  void initState() {
    super.initState();
    _messages = _repository.streamChatMessages(
      requestId: widget.requestId,
      sellerUserId: widget.sellerUserId,
    );
    _loadRequestName();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _loadRequestName() async {
    try {
      final request = await _repository.getRequest(widget.requestId);
      if (mounted) {
        setState(() => _requestPartName = request['part_name']?.toString());
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load request details: $error')),
        );
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    if (message.length > 4000) {
      _showError('Messages can be up to 4,000 characters.');
      return;
    }

    setState(() => _sending = true);
    try {
      await _repository.sendChatMessage(
        requestId: widget.requestId,
        sellerUserId: widget.sellerUserId,
        message: message,
      );
      _messageController.clear();
    } catch (error) {
      if (mounted) _showError('Could not send message: $error');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_requestPartName ?? 'Part request chat'),
            Text(
              widget.sellerName,
              style: const TextStyle(fontSize: 12, color: AppColors.greyText),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load chat messages: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Start the conversation about this part request.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[messages.length - 1 - index];
                    return _messageBubble(message);
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              color: Colors.white,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 5,
                      maxLength: 4000,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Write a message',
                        counterText: '',
                        border: OutlineInputBorder(),
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Send message',
                    onPressed: _sending ? null : _sendMessage,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final isMine =
        message['sender_user_id']?.toString() == _repository.currentUserId;
    final timestamp =
        DateTime.tryParse(message['created_at']?.toString() ?? '')?.toLocal();
    final time = timestamp == null
        ? ''
        : '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.78,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMine ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: isMine ? null : Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                message['message']?.toString() ?? '',
                style: TextStyle(color: isMine ? Colors.white : Colors.black87),
              ),
            ),
            if (time.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                time,
                style: TextStyle(
                  color: isMine ? Colors.white70 : AppColors.greyText,
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
