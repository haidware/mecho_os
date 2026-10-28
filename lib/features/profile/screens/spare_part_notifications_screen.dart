import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../repositories/spare_parts_repository.dart';
import '../../../services/web_push_subscription.dart';

class SparePartNotificationsScreen extends StatefulWidget {
  const SparePartNotificationsScreen({super.key});

  @override
  State<SparePartNotificationsScreen> createState() =>
      _SparePartNotificationsScreenState();
}

class _SparePartNotificationsScreenState
    extends State<SparePartNotificationsScreen> {
  static const _pushPublicKey = String.fromEnvironment(
    'WEB_PUSH_VAPID_PUBLIC_KEY',
  );

  final _repository = SparePartsRepository();
  late Future<List<Map<String, dynamic>>> _notifications;
  bool _enablingPush = false;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    _notifications = _repository.getNotifications();
  }

  Future<void> _refresh() async {
    final notifications = _repository.getNotifications();
    setState(() => _notifications = notifications);
    await notifications;
  }

  Future<void> _enablePush() async {
    if (_pushPublicKey.isEmpty) {
      _showMessage('Push notifications have not been configured yet.',
          error: true);
      return;
    }

    setState(() => _enablingPush = true);
    try {
      final subscription = await createWebPushSubscription(_pushPublicKey);
      await _repository.savePushSubscription(subscription);
      _showMessage('Push notifications are enabled on this device.');
    } catch (error) {
      _showMessage('Could not enable push notifications: $error', error: true);
    } finally {
      if (mounted) setState(() => _enablingPush = false);
    }
  }

  Future<void> _markAllRead() async {
    setState(() => _markingAllRead = true);
    try {
      await _repository.markAllNotificationsRead();
      await _refresh();
    } catch (error) {
      _showMessage('Could not mark notifications as read: $error', error: true);
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    try {
      final id = notification['id']?.toString();
      if (id != null && notification['read_at'] == null) {
        await _repository.markNotificationRead(id);
      }
      await _refresh();

      final requestId = notification['request_id']?.toString();
      if (requestId == null || requestId.isEmpty || !mounted) return;
      final type = notification['notification_type']?.toString();
      if (type == 'private_message' || type == 'offer_accepted') {
        final sellerId = notification['seller_user_id']?.toString();
        if (sellerId == null || sellerId.isEmpty) {
          _showMessage('The private conversation could not be opened.',
              error: true);
          return;
        }
        final sellerMode = await _repository.isCurrentUserSeller();
        final request = await _repository.getRequest(requestId);
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          AppRoutes.partRequestChat,
          arguments: {
            'requestId': requestId,
            'sellerUserId': sellerId,
            'sellerName': sellerMode
                ? request['mechanic_name']?.toString() ?? 'Mechanic'
                : 'Seller',
          },
        );
        return;
      }

      final sellerMode = await _repository.isCurrentUserSeller();
      if (!mounted) return;
      Navigator.pushNamed(
        context,
        AppRoutes.partRequestThread,
        arguments: {
          'requestId': requestId,
          'sellerMode': sellerMode,
        },
      );
    } catch (error) {
      _showMessage('Could not open notification: $error', error: true);
    }
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (kIsWeb && _pushPublicKey.isNotEmpty)
            IconButton(
              tooltip: 'Enable push notifications',
              onPressed: _enablingPush ? null : _enablePush,
              icon: _enablingPush
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.notifications_active_outlined),
            ),
          IconButton(
            tooltip: 'Mark all as read',
            onPressed: _markingAllRead ? null : _markAllRead,
            icon: const Icon(Icons.done_all),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _notifications,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Could not load notifications: ${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final notifications = snapshot.data!;
          if (notifications.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 180),
                  Center(child: Text('You are all caught up.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final notification = notifications[index];
                final isUnread = notification['read_at'] == null;
                return ListTile(
                  leading: Icon(
                    isUnread
                        ? Icons.markunread_outlined
                        : Icons.drafts_outlined,
                    color: isUnread ? AppColors.primary : AppColors.greyText,
                  ),
                  title: Text(
                    notification['title']?.toString() ?? 'Marketplace update',
                    style: TextStyle(
                      fontWeight:
                          isUnread ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    notification['body']?.toString() ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isUnread
                      ? const Icon(Icons.circle,
                          size: 9, color: AppColors.primary)
                      : null,
                  onTap: () => _openNotification(notification),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
