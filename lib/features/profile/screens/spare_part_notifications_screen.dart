import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../repositories/spare_parts_repository.dart';
import '../../../services/web_push_subscription.dart';
import '../../../shared/widgets/add_to_home_screen_dialog.dart';

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
  late Future<bool> _pushEnabled;
  late Future<Map<String, dynamic>> _pushSetupStatus;
  bool _enablingPush = false;
  bool _markingAllRead = false;

  @override
  void initState() {
    super.initState();
    _notifications = _repository.getNotifications();
    _pushEnabled = _isCurrentDeviceSubscribed();
    _pushSetupStatus = getWebPushSetupStatus();
  }

  Future<bool> _isCurrentDeviceSubscribed() async {
    final subscription = await getExistingWebPushSubscription();
    final endpoint = subscription?['endpoint']?.toString();
    if (endpoint == null || endpoint.isEmpty) return false;
    return _repository.hasPushSubscription(endpoint);
  }

  Future<void> _refresh() async {
    final notifications = _repository.getNotifications();
    final pushEnabled = _isCurrentDeviceSubscribed();
    final pushSetupStatus = getWebPushSetupStatus();
    setState(() {
      _notifications = notifications;
      _pushEnabled = pushEnabled;
      _pushSetupStatus = pushSetupStatus;
    });
    await notifications;
    await pushEnabled;
    await pushSetupStatus;
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
      if (mounted) {
        setState(() {
          _pushEnabled = Future.value(true);
          _pushSetupStatus = getWebPushSetupStatus();
        });
      }
      _showMessage(
        'Alerts are enabled on this device. Device notification settings control background sound and vibration.',
      );
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
            return Column(
              children: [
                _pushAlertsCard(),
                Expanded(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Could not load notifications: ${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }
          if (!snapshot.hasData) {
            return Column(
              children: [
                _pushAlertsCard(),
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
            );
          }
          final notifications = snapshot.data!;
          return Column(
            children: [
              _pushAlertsCard(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _refresh,
                  child: notifications.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 140),
                            Center(child: Text('You are all caught up.')),
                          ],
                        )
                      : ListView.separated(
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
                                color: isUnread
                                    ? AppColors.primary
                                    : AppColors.greyText,
                              ),
                              title: Text(
                                notification['title']?.toString() ??
                                    'Marketplace update',
                                style: TextStyle(
                                  fontWeight: isUnread
                                      ? FontWeight.bold
                                      : FontWeight.normal,
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
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _pushAlertsCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: FutureBuilder<bool>(
        future: _pushEnabled,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              'Could not check this device’s alert status: ${snapshot.error}',
              style: const TextStyle(color: AppColors.error),
            );
          }

          final enabled = snapshot.data == true;
          return FutureBuilder<Map<String, dynamic>>(
            future: _pushSetupStatus,
            builder: (context, statusSnapshot) {
              if (statusSnapshot.hasError) {
                return Text(
                  'Could not check notification support: ${statusSnapshot.error}',
                  style: const TextStyle(color: AppColors.error),
                );
              }
              final status = statusSnapshot.data ?? const {};
              final isIos = status['isIOS'] == true;
              final installed = status['standalone'] == true;
              final canEnable = kIsWeb &&
                  _pushPublicKey.isNotEmpty &&
                  status['canRequest'] == true;
              final needsIosInstall = isIos && !installed;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        enabled
                            ? Icons.notifications_active
                            : Icons.notifications_none,
                        color: enabled ? AppColors.success : AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          enabled
                              ? 'Alerts enabled on this device'
                              : 'Get marketplace alerts',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    enabled
                        ? 'This phone is subscribed. On iPhone, Mecho OS should now appear under Settings > Notifications. Turn on Lock Screen, Banners, Sounds, and Badges there.'
                        : needsIosInstall
                            ? 'Mecho OS cannot appear in iPhone Settings > Notifications yet. In Safari, tap Share > Add to Home Screen, open Mecho OS from its new Home Screen icon, then enable alerts here and choose Allow.'
                            : status['permission'] == 'denied'
                                ? 'Notifications were blocked previously. Allow Mecho OS in iPhone Settings > Notifications if listed, then reload this installed Home Screen app.'
                                : canEnable
                                    ? 'Tap Enable alerts and choose Allow in the iPhone prompt. After permission is granted, Mecho OS will appear in Settings > Notifications.'
                                    : kIsWeb
                                        ? status['message']
                                                    ?.toString()
                                                    .isNotEmpty ==
                                                true
                                            ? status['message'].toString()
                                            : 'Browser push has not been configured for this app.'
                                        : 'Browser push alerts are available in the web app.',
                    style: const TextStyle(
                      color: AppColors.greyText,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  if (!enabled && canEnable) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: FilledButton.icon(
                        onPressed: _enablingPush ? null : _enablePush,
                        icon: _enablingPush
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.notifications_active_outlined,
                              ),
                        label: Text(
                          _enablingPush
                              ? 'Enabling...'
                              : 'Enable alerts on device',
                        ),
                      ),
                    ),
                  ],
                  if (!enabled && needsIosInstall) ...[
                    const SizedBox(height: 10),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) => const AddToHomeScreenDialog(),
                        ),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('How to add to Home Screen'),
                      ),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }
}
