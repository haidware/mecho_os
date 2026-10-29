import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

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
  StreamSubscription<List<Map<String, dynamic>>>? _messagesSubscription;
  Timer? _messagesRefreshTimer;

  Map<String, dynamic>? _request;
  Map<String, dynamic>? _selectedSellerContact;
  List<Map<String, dynamic>> _sellerContacts = [];
  List<Map<String, dynamic>> _messages = [];
  List<String> _requestImageUrls = [];
  bool _loading = true;
  bool _messagesLoading = true;
  bool _contactsLoading = true;
  bool _refreshingMessages = false;
  bool _sending = false;
  bool _savingOffer = false;
  String? _error;
  String? _contactError;

  @override
  void initState() {
    super.initState();
    _startMessageUpdates();
    _loadRequest();
  }

  void _startMessageUpdates() {
    _messagesSubscription = _repository
        .streamRequestMessages(widget.requestId)
        .listen(_setMessages, onError: (Object error, StackTrace stackTrace) {
      debugPrint('Request chat realtime connection failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      unawaited(_refreshMessages(refreshContacts: true));
    });
    _messagesRefreshTimer = Timer.periodic(
      const Duration(seconds: 8),
      (_) => unawaited(_refreshMessages(refreshContacts: true)),
    );
    unawaited(_refreshMessages(refreshContacts: true));
  }

  void _setMessages(List<Map<String, dynamic>> messages) {
    if (!mounted) return;
    setState(() {
      _messages = messages;
      _messagesLoading = false;
    });
  }

  Future<void> _refreshMessages({bool refreshContacts = false}) async {
    if (_refreshingMessages) return;
    _refreshingMessages = true;
    try {
      _setMessages(await _repository.getRequestMessages(widget.requestId));
      if (refreshContacts && !widget.sellerMode && _request != null) {
        await _loadSellerContacts(_request!['status']?.toString());
      }
    } catch (error, stackTrace) {
      debugPrint('Could not refresh request chat messages: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _refreshingMessages = false;
    }
  }

  Future<void> _loadSellerContacts(String? requestStatus) async {
    if (widget.sellerMode) return;
    try {
      final contacts =
          await _repository.getRequestSellerContacts(widget.requestId);
      Map<String, dynamic>? selectedContact;
      if (requestStatus == 'accepted') {
        selectedContact =
            await _repository.getSelectedSellerContact(widget.requestId);
      }
      if (!mounted) return;
      setState(() {
        _sellerContacts = contacts;
        _selectedSellerContact = selectedContact;
        _contactError = null;
        _contactsLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Could not load seller contact details: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) setState(() => _contactsLoading = false);
    }
  }

  @override
  void dispose() {
    unawaited(_messagesSubscription?.cancel());
    _messagesRefreshTimer?.cancel();
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
      final imageUrls = await _repository.getSignedImageUrls(
        request['image_paths'] as List<dynamic>? ?? [],
      );
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
          _requestImageUrls = imageUrls;
          _loading = false;
        });
      }
      await _loadSellerContacts(request['status']?.toString());
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
      unawaited(_refreshMessages());
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
        await _loadSellerContacts(request['status']?.toString());
        _showMessage(
            'Offer accepted. You can call the seller or chat privately.');
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

  Future<void> _callSeller(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showMessage('This seller has not provided a phone number.',
          isError: true);
      return;
    }
    final phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (!await canLaunchUrl(phoneUri) ||
        !await launchUrl(phoneUri, mode: LaunchMode.externalApplication)) {
      _showMessage('Could not open the phone app to call this seller.',
          isError: true);
    }
  }

  Future<void> _copyContactValue(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (mounted) _showMessage('$label copied.');
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
                      child: _messagesLoading
                          ? const Center(
                              child: CircularProgressIndicator(),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.all(14),
                              itemCount: _messages.length + 1,
                              itemBuilder: (context, index) {
                                if (index == _messages.length) {
                                  return _requestPostBubble(_request!);
                                }
                                final message =
                                    _messages[_messages.length - 1 - index];
                                return _messageBubble(message);
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

  Widget _requestPostBubble(Map<String, dynamic> request) {
    final details = <MapEntry<String, String>>[
      MapEntry('Part', request['part_name']?.toString() ?? 'Not specified'),
      MapEntry(
        'Condition',
        request['condition_requested']?.toString() ?? 'Not specified',
      ),
      if ((request['vehicle'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Vehicle', request['vehicle'].toString()),
      if ((request['barcode'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Part number', request['barcode'].toString()),
      if ((request['position'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Position', request['position'].toString()),
      MapEntry(
        'Requested by',
        request['mechanic_name']?.toString() ?? 'Mechanic',
      ),
      if ((request['phone_number'] ?? '').toString().trim().isNotEmpty)
        MapEntry('Contact', request['phone_number'].toString()),
      MapEntry(
        'Location',
        request['location']?.toString() ?? 'Location not provided',
      ),
    ];
    final description = request['description']?.toString().trim() ?? '';

    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.88,
        ),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFDDF8D6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.inventory_2_outlined, size: 17),
                SizedBox(width: 7),
                Text(
                  'PART REQUEST',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Please check availability and reply with your price, part condition, and delivery or pickup details.',
              style: TextStyle(height: 1.35),
            ),
            const SizedBox(height: 10),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '${detail.key}: ${detail.value}',
                  style: const TextStyle(height: 1.3),
                ),
              ),
            ),
            if (description.isNotEmpty) ...[
              const SizedBox(height: 6),
              const Text(
                'Additional details',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              Text(description, style: const TextStyle(height: 1.35)),
            ],
            if (_requestImageUrls.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'Photos (${_requestImageUrls.length})',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _requestImageUrls
                    .map(
                      (url) => ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          url,
                          width: 118,
                          height: 100,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                            width: 118,
                            height: 100,
                            color: Colors.white,
                            alignment: Alignment.center,
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
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
    final offerId = message['offer_id']?.toString();
    final sellerContact =
        _sellerContacts.cast<Map<String, dynamic>?>().firstWhere(
              (contact) => contact?['offer_id']?.toString() == offerId,
              orElse: () => selectedOffer ? _selectedSellerContact : null,
            );
    final sellerPhone = sellerContact?['phone_number']?.toString().trim() ?? '';
    final sellerLocation =
        sellerContact?['location']?.toString().trim().isNotEmpty == true
            ? sellerContact!['location'].toString()
            : senderLocation;
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
              if (!widget.sellerMode) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Location: $sellerLocation',
                        style: const TextStyle(
                          color: AppColors.greyText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy seller location',
                      visualDensity: VisualDensity.compact,
                      onPressed: sellerLocation == 'Location not provided'
                          ? null
                          : () => _copyContactValue(
                                sellerLocation,
                                'Seller location',
                              ),
                      icon: const Icon(Icons.copy, size: 16),
                    ),
                  ],
                ),
                if (_contactsLoading && sellerPhone.isEmpty)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (sellerPhone.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          onPressed: () => _callSeller(sellerPhone),
                          icon: const Icon(Icons.call_outlined, size: 16),
                          label: Text(sellerPhone),
                          style: TextButton.styleFrom(
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.zero,
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Copy seller phone number',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _copyContactValue(
                          sellerPhone,
                          'Seller phone number',
                        ),
                        icon: const Icon(Icons.copy, size: 16),
                      ),
                    ],
                  )
                else if (_contactError != null)
                  const Text(
                    'Seller contact is temporarily unavailable.',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 11,
                    ),
                  )
                else
                  const Text(
                    'Seller has not provided a phone number.',
                    style: TextStyle(
                      color: AppColors.greyText,
                      fontSize: 11,
                    ),
                  ),
              ],
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
