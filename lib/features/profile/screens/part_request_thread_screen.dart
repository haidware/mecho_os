import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../repositories/spare_parts_repository.dart';

class SparePartNotificationsButton extends StatelessWidget {
  const SparePartNotificationsButton({
    super.key,
    required this.repository,
  });

  final SparePartsRepository repository;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: repository.streamUnreadNotifications(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return IconButton(
            tooltip: 'Could not load notifications',
            onPressed: () => Navigator.pushNamed(
              context,
              AppRoutes.notifications,
            ),
            icon: const Icon(Icons.notifications_off_outlined),
          );
        }
        final count = snapshot.data?.length ?? 0;
        return IconButton(
          tooltip: count > 0 ? '$count unread notifications' : 'Notifications',
          onPressed: () => Navigator.pushNamed(
            context,
            AppRoutes.notifications,
          ),
          icon: Badge(
            isLabelVisible: count > 0,
            label: Text(count > 99 ? '99+' : '$count'),
            child: const Icon(Icons.notifications_outlined),
          ),
        );
      },
    );
  }
}

class PartRequestThreadScreen extends StatefulWidget {
  const PartRequestThreadScreen({
    super.key,
    required this.requestId,
    required this.sellerMode,
  });

  final String requestId;
  final bool sellerMode;

  @override
  State<PartRequestThreadScreen> createState() =>
      _PartRequestThreadScreenState();
}

class _PartRequestThreadScreenState extends State<PartRequestThreadScreen> {
  final _repository = SparePartsRepository();
  final _messageController = TextEditingController();
  final _priceController = TextEditingController();
  final _conditionController = TextEditingController();
  final _locationController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  late final Stream<List<Map<String, dynamic>>> _messages;

  Map<String, dynamic>? _request;
  bool _loading = true;
  bool _sending = false;
  bool _savingOffer = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _messages = _repository.streamRequestMessages(widget.requestId);
    _loadRequest();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _priceController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _sellerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _loadRequest() async {
    try {
      final request = await _repository.getRequest(widget.requestId);
      if (widget.sellerMode) {
        final profile = await _repository.getMySellerProfile();
        final offer = await _repository.getMyOffer(widget.requestId);
        _sellerNameController.text = offer?['seller_name']?.toString() ??
            profile['full_name']?.toString() ??
            '';
        _phoneController.text = profile['phone_number']?.toString() ?? '';
        _priceController.text = offer?['price']?.toString() ?? '';
        _conditionController.text = offer?['condition']?.toString() ?? '';
        _locationController.text = offer?['location']?.toString() ?? '';
      }
      if (mounted) {
        setState(() {
          _request = request;
          _loading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _loading = false;
        });
      }
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || _sending) return;
    if (message.length > 4000) {
      _showMessage('Messages can be up to 4,000 characters.', isError: true);
      return;
    }
    setState(() => _sending = true);
    try {
      await _repository.sendRequestMessage(
        requestId: widget.requestId,
        message: message,
      );
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        _showMessage('Could not send message: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitOffer(BuildContext sheetContext) async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showMessage('Enter a valid price greater than zero.', isError: true);
      return;
    }
    if (_conditionController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _sellerNameController.text.trim().isEmpty) {
      _showMessage(
        'Enter your offer condition, seller name, and location.',
        isError: true,
      );
      return;
    }
    setState(() => _savingOffer = true);
    try {
      await _repository.submitOffer(
        requestId: widget.requestId,
        price: price,
        condition: _conditionController.text.trim(),
        location: _locationController.text.trim(),
        sellerName: _sellerNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      if (mounted && sheetContext.mounted) {
        Navigator.pop(sheetContext);
        _showMessage('Your offer was posted to the request chat.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not send offer: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _savingOffer = false);
    }
  }

  Future<void> _showOfferForm() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Text(
              'Post your offer to the group',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _offerInput(_priceController, 'Price', number: true),
            _offerInput(_conditionController, 'Condition (e.g. new, used)'),
            _offerInput(_locationController, 'Seller location'),
            _offerInput(_sellerNameController, 'Seller / business name'),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingOffer ? null : () => _submitOffer(context),
                child: Text(_savingOffer ? 'Posting...' : 'Post offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _acceptOffer(Map<String, dynamic> message) async {
    final offerId = message['offer_id']?.toString();
    if (offerId == null) return;
    setState(() => _sending = true);
    try {
      await _repository.acceptOffer(
        requestId: widget.requestId,
        offerId: offerId,
      );
      final request = await _repository.getRequest(widget.requestId);
      if (mounted) {
        setState(() => _request = request);
        _showMessage('Offer accepted. You can now chat privately.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not accept offer: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _openPrivateChat(Map<String, dynamic> message) {
    final sellerId = message['sender_user_id']?.toString();
    if (sellerId == null) return;
    Navigator.pushNamed(
      context,
      AppRoutes.partRequestChat,
      arguments: {
        'requestId': widget.requestId,
        'sellerUserId': sellerId,
        'sellerName': message['sender_name']?.toString() ?? 'Seller',
      },
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F8),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_request?['part_name']?.toString() ?? 'Part request chat'),
            const Text(
              'Shared seller conversation',
              style: TextStyle(fontSize: 12, color: AppColors.greyText),
            ),
          ],
        ),
        actions: [
          SparePartNotificationsButton(repository: _repository),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text('Could not load request: $_error'))
              : Column(
                  children: [
                    if (_request != null) _requestSummary(_request!),
                    Expanded(
                      child: StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _messages,
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Could not load chat: ${snapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final messages = snapshot.data!;
                          if (messages.isEmpty) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(24),
                                child: Text(
                                  'The request is posted. Sellers can reply here, and all sellers can see the shared conversation.',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }
                          return ListView.builder(
                            reverse: true,
                            padding: const EdgeInsets.all(14),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final message =
                                  messages[messages.length - 1 - index];
                              return _messageBubble(message);
                            },
                          );
                        },
                      ),
                    ),
                    _composer(),
                  ],
                ),
    );
  }

  Widget _requestSummary(Map<String, dynamic> request) {
    final details = [
      '${request['condition_requested']} part',
      if ((request['vehicle'] ?? '').toString().isNotEmpty)
        request['vehicle'].toString(),
      if ((request['barcode'] ?? '').toString().isNotEmpty)
        'Part number ${request['barcode']}',
      'Near ${request['location']}',
    ];
    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request['part_name']?.toString() ?? 'Part request',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            details.join(' • '),
            style: const TextStyle(color: AppColors.greyText, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final isMine =
        message['sender_user_id']?.toString() == _repository.currentUserId;
    final isOffer = message['message_type'] == 'offer';
    final senderName = message['sender_name']?.toString() ?? 'Marketplace user';
    final senderLocation =
        message['sender_location']?.toString() ?? 'Location not provided';
    final selectedOffer = _request?['selected_offer_id']?.toString() ==
        message['offer_id']?.toString();
    final time = _formatTime(message['created_at']?.toString());

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.84,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine ? const Color(0xFFDDF8D6) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selectedOffer ? AppColors.success : AppColors.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              senderName,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              senderLocation,
              style: const TextStyle(color: AppColors.greyText, fontSize: 11),
            ),
            const SizedBox(height: 7),
            if (isOffer) ...[
              const Text(
                'SELLER OFFER',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '₦${message['offer_price']} • ${message['offer_condition']}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ] else
              Text(message['message']?.toString() ?? ''),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedOffer)
                  const Text(
                    'Selected',
                    style: TextStyle(
                      color: AppColors.success,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                if (isOffer &&
                    !widget.sellerMode &&
                    _request?['status'] == 'open') ...[
                  TextButton(
                    onPressed: _sending ? null : () => _acceptOffer(message),
                    child: const Text('Choose this seller'),
                  ),
                ],
                if (isOffer && selectedOffer && !widget.sellerMode)
                  TextButton(
                    onPressed: () => _openPrivateChat(message),
                    child: const Text('Private chat'),
                  ),
                if (time.isNotEmpty)
                  Text(
                    time,
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 10,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    final isOpen = _request?['status'] == 'open';
    return SafeArea(
      top: false,
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          children: [
            if (widget.sellerMode && isOpen)
              IconButton(
                tooltip: 'Post an offer',
                onPressed: _savingOffer ? null : _showOfferForm,
                icon: const Icon(Icons.sell_outlined),
              ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: isOpen && !_sending,
                minLines: 1,
                maxLines: 4,
                maxLength: 4000,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: isOpen
                      ? 'Message the request group'
                      : 'The shared conversation is closed',
                  counterText: '',
                  filled: true,
                  fillColor: const Color(0xFFF3F4F8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              tooltip: 'Send message',
              onPressed: !isOpen || _sending ? null : _sendMessage,
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
    );
  }

  Widget _offerInput(
    TextEditingController controller,
    String label, {
    bool number = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  String _formatTime(String? rawTimestamp) {
    final timestamp = DateTime.tryParse(rawTimestamp ?? '')?.toLocal();
    if (timestamp == null) return '';
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
  }
}
