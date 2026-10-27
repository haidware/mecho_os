import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../repositories/spare_parts_repository.dart';

class SparePartsSellerScreen extends StatefulWidget {
  const SparePartsSellerScreen({super.key});

  @override
  State<SparePartsSellerScreen> createState() => _SparePartsSellerScreenState();
}

class _SparePartsSellerScreenState extends State<SparePartsSellerScreen> {
  final _repository = SparePartsRepository();
  Stream<List<Map<String, dynamic>>>? _requests;
  bool _checkingAccess = true;
  String? _accessError;

  @override
  void initState() {
    super.initState();
    _authorize();
  }

  void _reload() {
    if (_checkingAccess) return;
    setState(() => _requests = _repository.streamOpenRequests());
  }

  Future<void> _authorize() async {
    try {
      if (Supabase.instance.client.auth.currentSession == null ||
          !await _repository.hasActiveSellerAccount()) {
        if (mounted) {
          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.sparePartsSellerLogin,
            (_) => false,
          );
        }
        return;
      }
      if (mounted) {
        setState(() {
          _checkingAccess = false;
          _requests = _repository.streamOpenRequests();
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _checkingAccess = false;
          _accessError = error.toString();
        });
      }
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        AppRoutes.sparePartsSellerLogin,
        (_) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('Spare Part Requests'),
        actions: [
          IconButton(
            tooltip: 'My offers and chats',
            onPressed: () =>
                Navigator.pushNamed(context, AppRoutes.mySellerOffers),
            icon: const Icon(Icons.chat_outlined),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: _checkingAccess
          ? const Center(child: CircularProgressIndicator())
          : _accessError != null
              ? _MessageState(
                  message: 'Could not verify seller account: $_accessError',
                  onRetry: _authorize,
                )
              : RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                  },
                  child: StreamBuilder<List<Map<String, dynamic>>>(
                    stream: _requests,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return _MessageState(
                          message: 'Could not load requests: ${snapshot.error}',
                          onRetry: _reload,
                        );
                      }
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final requests = snapshot.data!;
                      if (requests.isEmpty) {
                        return const _MessageState(
                          message: 'There are no open part requests right now.',
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final request = requests[index];
                          final photoCount =
                              (request['image_paths'] as List<dynamic>? ?? [])
                                  .length;
                          return Card(
                            color: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(color: AppColors.border),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Text(
                                request['part_name']?.toString() ??
                                    'Part request',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  [
                                    '${request['condition_requested']} part',
                                    if ((request['vehicle'] ?? '')
                                        .toString()
                                        .isNotEmpty)
                                      request['vehicle'].toString(),
                                    'Requested near ${request['location']}',
                                    '$photoCount photo${photoCount == 1 ? '' : 's'}',
                                  ].join(' • '),
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.pushNamed(
                                context,
                                AppRoutes.partRequestDetail,
                                arguments: {
                                  'requestId': request['id'].toString(),
                                  'sellerMode': true,
                                },
                              ).then((_) => _reload()),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}

class MySellerOffersScreen extends StatefulWidget {
  const MySellerOffersScreen({super.key});

  @override
  State<MySellerOffersScreen> createState() => _MySellerOffersScreenState();
}

class _MySellerOffersScreenState extends State<MySellerOffersScreen> {
  final _repository = SparePartsRepository();
  late Future<List<Map<String, dynamic>>> _offers;

  @override
  void initState() {
    super.initState();
    _offers = _repository.getMyOffers();
  }

  void _reload() => setState(() => _offers = _repository.getMyOffers());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Offers and Chats'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _offers,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _MessageState(
                message: 'Could not load your offers: ${snapshot.error}',
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final offers = snapshot.data!;
            if (offers.isEmpty) {
              return const _MessageState(
                message: 'You have not responded to any requests yet.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final offer = offers[index];
                final request = offer['request'] as Map<String, dynamic>? ?? {};
                final selected = request['selected_offer_id']?.toString() ==
                    offer['id']?.toString();
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: selected ? AppColors.success : AppColors.border,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      request['part_name']?.toString() ?? 'Part request',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '₦${offer['price']} • ${offer['condition']} • ${request['status']}',
                      ),
                    ),
                    trailing: Icon(
                      selected ? Icons.chat_bubble : Icons.chevron_right,
                      color: selected ? AppColors.success : null,
                    ),
                    onTap: request['id'] == null
                        ? null
                        : () => Navigator.pushNamed(
                              context,
                              AppRoutes.partRequestDetail,
                              arguments: {
                                'requestId': request['id'].toString(),
                                'sellerMode': true,
                              },
                            ).then((_) => _reload()),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class MyPartRequestsScreen extends StatefulWidget {
  const MyPartRequestsScreen({super.key});

  @override
  State<MyPartRequestsScreen> createState() => _MyPartRequestsScreenState();
}

class _MyPartRequestsScreenState extends State<MyPartRequestsScreen> {
  final _repository = SparePartsRepository();
  late Future<List<Map<String, dynamic>>> _requests;

  @override
  void initState() {
    super.initState();
    _requests = _repository.getMyRequests();
  }

  void _reload() => setState(() => _requests = _repository.getMyRequests());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: const Text('My Part Requests'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _reload(),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _requests,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return _MessageState(
                message: 'Could not load your requests: ${snapshot.error}',
                onRetry: _reload,
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data!;
            if (requests.isEmpty) {
              return const _MessageState(
                message: 'You have not submitted any part requests yet.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final request = requests[index];
                return Card(
                  color: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.border),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    title: Text(
                      request['part_name']?.toString() ?? 'Part request',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${request['status']} • ${request['condition_requested']} • ${request['location']}',
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pushNamed(
                      context,
                      AppRoutes.partRequestDetail,
                      arguments: {
                        'requestId': request['id'].toString(),
                        'sellerMode': false,
                      },
                    ).then((_) => _reload()),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class PartRequestDetailScreen extends StatefulWidget {
  final String requestId;
  final bool sellerMode;

  const PartRequestDetailScreen({
    super.key,
    required this.requestId,
    required this.sellerMode,
  });

  @override
  State<PartRequestDetailScreen> createState() =>
      _PartRequestDetailScreenState();
}

class _PartRequestDetailScreenState extends State<PartRequestDetailScreen> {
  final _repository = SparePartsRepository();
  final _priceController = TextEditingController();
  final _conditionController = TextEditingController();
  final _locationController = TextEditingController();
  final _sellerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  Map<String, dynamic>? _request;
  Map<String, dynamic>? _myOffer;
  List<Map<String, dynamic>> _offers = [];
  List<String> _imageUrls = [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _priceController.dispose();
    _conditionController.dispose();
    _locationController.dispose();
    _sellerNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final request = await _repository.getRequest(widget.requestId);
      final urls = await _repository
          .getSignedImageUrls(request['image_paths'] as List<dynamic>? ?? []);
      if (widget.sellerMode) {
        final profile = await _repository.getMySellerProfile();
        final offer = await _repository.getMyOffer(widget.requestId);
        _myOffer = offer;
        _sellerNameController.text = offer?['seller_name']?.toString() ??
            profile['full_name']?.toString() ??
            '';
        _phoneController.text = offer?['phone_number']?.toString() ??
            profile['phone_number']?.toString() ??
            '';
        _priceController.text = offer?['price']?.toString() ?? '';
        _conditionController.text = offer?['condition']?.toString() ?? '';
        _locationController.text = offer?['location']?.toString() ?? '';
      } else {
        _myOffer = null;
        _offers = await _repository.getOffers(widget.requestId);
      }
      if (!mounted) return;
      setState(() {
        _request = request;
        _imageUrls = urls;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  Future<void> _submitOffer() async {
    final price = double.tryParse(_priceController.text.trim());
    if (price == null || price <= 0) {
      _showMessage('Enter a valid price greater than zero.', isError: true);
      return;
    }
    if (_conditionController.text.trim().isEmpty ||
        _locationController.text.trim().isEmpty ||
        _sellerNameController.text.trim().isEmpty) {
      _showMessage('Enter the part condition, seller name, and location.',
          isError: true);
      return;
    }
    setState(() => _saving = true);
    try {
      await _repository.submitOffer(
        requestId: widget.requestId,
        price: price,
        condition: _conditionController.text.trim(),
        location: _locationController.text.trim(),
        sellerName: _sellerNameController.text.trim(),
        phoneNumber: _phoneController.text.trim(),
      );
      await _load();
      if (mounted) _showMessage('Your offer has been sent to the mechanic.');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not send your offer: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _acceptOffer(String offerId) async {
    setState(() => _saving = true);
    try {
      await _repository.acceptOffer(
        requestId: widget.requestId,
        offerId: offerId,
      );
      await _load();
      if (mounted) _showMessage('Offer accepted.');
    } catch (error) {
      if (mounted) {
        _showMessage('Could not accept this offer: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(widget.sellerMode ? 'Request Details' : 'Offers'),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _MessageState(
                  message: 'Could not load request: $_error', onRetry: _load)
              : _request == null
                  ? const _MessageState(message: 'Request not found.')
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _requestCard(_request!),
                        if (_imageUrls.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 110,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: _imageUrls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, index) => ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  _imageUrls[index],
                                  width: 110,
                                  height: 110,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 110,
                                    height: 110,
                                    color: AppColors.secondary,
                                    child:
                                        const Icon(Icons.broken_image_outlined),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (widget.sellerMode) ...[
                          const SizedBox(height: 20),
                          _sellerOfferForm(),
                          if (_myOffer != null &&
                              _canSellerChat(_myOffer!, _request!)) ...[
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: () => _openChat(
                                  sellerUserId: _repository.currentUserId,
                                  sellerName:
                                      _myOffer!['seller_name'].toString(),
                                ),
                                icon: const Icon(Icons.chat_bubble_outline),
                                label: const Text('Chat with the mechanic'),
                              ),
                            ),
                          ],
                        ] else ...[
                          const SizedBox(height: 20),
                          Text(
                            'Seller offers (${_offers.length})',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (_offers.isEmpty)
                            const Text('No sellers have responded yet.')
                          else
                            ..._offers.map(_offerCard),
                        ],
                      ],
                    ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    final details = <String>[
      'Condition requested: ${request['condition_requested']}',
      if ((request['vehicle'] ?? '').toString().isNotEmpty)
        'Vehicle: ${request['vehicle']}',
      if ((request['barcode'] ?? '').toString().isNotEmpty)
        'Part number: ${request['barcode']}',
      if ((request['position'] ?? '').toString().isNotEmpty)
        'Position: ${request['position']}',
      'Mechanic location: ${request['location']}',
      if ((request['description'] ?? '').toString().isNotEmpty)
        request['description'].toString(),
    ];
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              request['part_name']?.toString() ?? 'Part request',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            ...details.map(
              (detail) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(detail),
              ),
            ),
            Text('Status: ${request['status']}'),
          ],
        ),
      ),
    );
  }

  Widget _sellerOfferForm() {
    if (_request?['status'] != 'open') {
      return const Text('This request is no longer accepting offers.');
    }
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your offer',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _input(_priceController, 'Price',
                keyboardType: TextInputType.number),
            _input(_conditionController, 'Part condition (e.g. new, used)'),
            _input(_locationController, 'Your part location'),
            _input(_sellerNameController, 'Seller / business name'),
            _input(_phoneController, 'Contact phone (optional)',
                keyboardType: TextInputType.phone),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _submitOffer,
                child: Text(_saving ? 'Sending...' : 'Send offer'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _offerCard(Map<String, dynamic> offer) {
    final accepted =
        _request?['selected_offer_id']?.toString() == offer['id']?.toString();
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: accepted ? AppColors.success : AppColors.border,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    offer['seller_name']?.toString() ?? 'Seller',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '₦${offer['price']}',
                  style: const TextStyle(
                    fontSize: 17,
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text('${offer['condition']} • ${offer['location']}'),
            if ((offer['phone_number'] ?? '').toString().isNotEmpty)
              Text('Contact: ${offer['phone_number']}'),
            if (accepted)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Selected offer',
                  style: TextStyle(
                    color: AppColors.success,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_canChatWithOffer(offer))
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => _openChat(
                      sellerUserId: offer['seller_user_id'].toString(),
                      sellerName: offer['seller_name']?.toString() ?? 'Seller',
                    ),
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Chat'),
                  ),
                  if (_request?['status'] == 'open' && !accepted)
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => _acceptOffer(offer['id'].toString()),
                      child: const Text('Accept offer'),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  bool _canChatWithOffer(Map<String, dynamic> offer) {
    if (_request?['status'] == 'open') return true;
    return _request?['selected_offer_id']?.toString() ==
        offer['id']?.toString();
  }

  bool _canSellerChat(
    Map<String, dynamic> offer,
    Map<String, dynamic> request,
  ) {
    if (request['status'] == 'open') return true;
    return request['selected_offer_id']?.toString() == offer['id']?.toString();
  }

  void _openChat({
    required String sellerUserId,
    required String sellerName,
  }) {
    Navigator.pushNamed(
      context,
      AppRoutes.partRequestChat,
      arguments: {
        'requestId': widget.requestId,
        'sellerUserId': sellerUserId,
        'sellerName': sellerName,
      },
    );
  }

  Widget _input(
    TextEditingController controller,
    String label, {
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _MessageState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 100),
        Center(
            child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        )),
        if (onRetry != null)
          Center(
            child:
                TextButton(onPressed: onRetry, child: const Text('Try again')),
          ),
      ],
    );
  }
}
